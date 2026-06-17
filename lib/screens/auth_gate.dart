import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'auth/login_screen.dart';
import 'calendar/calendar_screen.dart';
import 'group/group_setup_screen.dart';

/// 로그인/그룹 상태에 따라 보여줄 화면을 결정하는 진입 분기.
///
/// 비로그인 → 로그인 화면
/// 로그인 + 그룹 없음 → 그룹 설정 화면
/// 로그인 + 그룹 있음 → 캘린더(메인)
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const _Splash(),
      error: (e, _) => _ErrorView(message: '인증 상태를 불러오지 못했습니다.\n$e'),
      data: (user) {
        if (user == null) return const LoginScreen();

        // 로그인됨 → 프로필 문서 로딩
        final profile = ref.watch(currentUserProvider);
        return profile.when(
          loading: () => const _Splash(),
          error: (e, _) => _ErrorView(message: '프로필을 불러오지 못했습니다.\n$e'),
          data: (appUser) {
            if (appUser == null) return const _Splash();
            if (appUser.groupId == null) return const GroupSetupScreen();
            return const CalendarScreen();
          },
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month, size: 64, color: Color(0xFF1565C0)),
            SizedBox(height: 16),
            Text('우리집일정표',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
