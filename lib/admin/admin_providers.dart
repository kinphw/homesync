import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../models/family_group.dart';
import '../providers.dart'; // firestoreProvider 등 기반 프로바이더 재사용
import 'admin_service.dart';

final adminServiceProvider = Provider<AdminService>(
  (ref) => AdminService(ref.watch(firestoreProvider)),
);

/// 현재 로그인 사용자가 운영자인지 여부. admins/{uid} 문서 존재로 판단.
final isAdminProvider = StreamProvider<bool>((ref) {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null) return Stream.value(false);
  return ref.watch(adminServiceProvider).watchIsAdmin(auth.uid);
});

/// 요약 통계(회원/그룹/일정 수). 새로고침은 ref.invalidate(adminStatsProvider).
final adminStatsProvider = FutureProvider<AdminStats>(
  (ref) => ref.watch(adminServiceProvider).fetchStats(),
);

/// 전체 회원 실시간 목록.
final allUsersProvider = StreamProvider<List<AppUser>>(
  (ref) => ref.watch(adminServiceProvider).watchAllUsers(),
);

/// 전체 그룹 실시간 목록.
final allGroupsProvider = StreamProvider<List<FamilyGroup>>(
  (ref) => ref.watch(adminServiceProvider).watchAllGroups(),
);
