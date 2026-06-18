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
            // 운영자가 로그인을 차단한 회원이면 차단 안내 화면으로.
            if (appUser.banned) return const _BannedView();
            if (appUser.groupId == null) return const GroupSetupScreen();
            // groupId가 있어도 그룹이 실제로 존재하는지 확인(방장이 삭제한 경우 대비)
            final groupAsync = ref.watch(currentGroupProvider);
            return groupAsync.when(
              loading: () => const _Splash(),
              error: (e, _) => _ErrorView(message: '그룹을 불러오지 못했습니다.\n$e'),
              data: (group) {
                // 그룹이 삭제됐거나(=null), 내가 강퇴되어 구성원이 아니면 그룹 설정으로.
                if (group == null ||
                    !group.memberUids.contains(appUser.uid)) {
                  if (group != null) {
                    // 강퇴: 내 groupId 정리(본인 문서라 수정 가능)
                    Future.microtask(() => ref
                        .read(firestoreServiceProvider)
                        .setUserGroup(appUser.uid, null));
                  }
                  return const GroupSetupScreen();
                }
                return const CalendarScreen();
              },
            );
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

/// 운영자가 로그인을 차단한 계정에 보여주는 안내 화면.
class _BannedView extends ConsumerWidget {
  const _BannedView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('이용이 정지된 계정입니다',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('자세한 내용은 관리자에게 문의해 주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => ref.read(authServiceProvider).signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('로그아웃'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
