import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/app_theme.dart';
import 'admin_dashboard.dart';
import 'admin_providers.dart';

/// 관리자 웹 루트 위젯. 일반 앱(HomeSyncApp)과 별개의 진입점이다.
class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '우리집일정표 관리자',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('ko', 'KR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      home: const AdminGate(),
    );
  }
}

/// 로그인 여부와 운영자 권한에 따라 화면을 분기한다.
///
/// 비로그인 → 로그인 화면
/// 로그인 + 운영자 아님 → 접근 거부(UID 안내)
/// 로그인 + 운영자 → 관제 대시보드
class AdminGate extends ConsumerWidget {
  const AdminGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const _Centered(child: CircularProgressIndicator()),
      error: (e, _) => _Centered(child: Text('인증 상태를 불러오지 못했습니다.\n$e')),
      data: (user) {
        if (user == null) return const AdminLoginScreen();
        // 운영자 여부는 admins/{uid} 문서 존재로 판단(DB 기반).
        final isAdmin = ref.watch(isAdminProvider);
        return isAdmin.when(
          loading: () => const _Centered(child: CircularProgressIndicator()),
          error: (e, _) => _Centered(child: Text('권한 확인에 실패했습니다.\n$e')),
          data: (ok) =>
              ok ? const AdminDashboard() : _AccessDenied(uid: user.uid),
        );
      },
    );
  }
}

/// 운영자 로그인 화면. 기존 AuthService.signIn 을 그대로 재사용한다.
class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _account = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _account.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).signIn(
            account: _account.text.trim(),
            password: _password.text,
          );
      // 성공 시 authStateProvider 가 갱신되어 AdminGate 가 다시 분기한다.
    } catch (_) {
      setState(() => _error = '로그인에 실패했습니다. 계정/비밀번호를 확인하세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.admin_panel_settings,
                      size: 56, color: Color(0xFF1565C0)),
                  const SizedBox(height: 12),
                  const Text('관리자 콘솔',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _account,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(
                      labelText: '운영자 계정(이메일)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(
                      labelText: '비밀번호',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _signIn(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy ? null : _signIn,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: _busy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('로그인'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 운영자가 아닌 계정으로 로그인했을 때. 본인 UID를 보여줘 등록을 돕는다.
class _AccessDenied extends ConsumerWidget {
  const _AccessDenied({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block, size: 56, color: Colors.red),
              const SizedBox(height: 12),
              const Text('관리자 권한이 없는 계정입니다.',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('아래 UID로 운영자 문서를 만들면 접근할 수 있어요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, fontSize: 13)),
              const SizedBox(height: 8),
              SelectableText(uid,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 13)),
              const SizedBox(height: 4),
              const Text(
                'Firebase 콘솔 > Firestore Database 에서\n'
                'admins 컬렉션에 위 UID를 "문서 ID"로 추가하세요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => ref.read(authServiceProvider).signOut(),
                child: const Text('로그아웃'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: child));
}
