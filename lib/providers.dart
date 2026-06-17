import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/app_user.dart';
import 'models/calendar_event.dart';
import 'models/family_group.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';

// ---------------- 기반 인스턴스 ----------------

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final firestoreServiceProvider = Provider<FirestoreService>(
  (ref) => FirestoreService(ref.watch(firestoreProvider)),
);

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreServiceProvider),
  ),
);

// ---------------- 인증 / 사용자 ----------------

/// 로그인 상태(파이어베이스 Auth 사용자) 스트림.
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authServiceProvider).authStateChanges(),
);

/// 현재 로그인 사용자의 프로필 문서(이름·색상·groupId 포함).
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null) return Stream.value(null);
  return ref.watch(firestoreServiceProvider).watchUser(auth.uid);
});

// ---------------- 그룹 ----------------

/// 현재 사용자가 속한 그룹.
final currentGroupProvider = StreamProvider<FamilyGroup?>((ref) {
  final user = ref.watch(currentUserProvider).value;
  final groupId = user?.groupId;
  if (groupId == null) return Stream.value(null);
  return ref.watch(firestoreServiceProvider).watchGroup(groupId);
});

/// 그룹 구성원 프로필 목록(필터 칩·색상에 사용).
final groupMembersProvider = StreamProvider<List<AppUser>>((ref) {
  final group = ref.watch(currentGroupProvider).value;
  if (group == null) return Stream.value(const []);
  return ref.watch(firestoreServiceProvider).watchMembers(group.memberUids);
});

// ---------------- 캘린더 상태 ----------------

/// 현재 보고 있는 달(1일 자정 기준).
class FocusedMonth extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  void setMonth(DateTime anyDayInMonth) {
    state = DateTime(anyDayInMonth.year, anyDayInMonth.month, 1);
  }
}

final focusedMonthProvider =
    NotifierProvider<FocusedMonth, DateTime>(FocusedMonth.new);

/// 상단 필터에서 "숨긴" 회원 uid 집합. (아웃룩식 개별 on/off 토글)
/// 비어 있으면 전원 표시. 회원 uid가 들어있으면 그 회원 일정은 가려진다.
class HiddenMembers extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  /// 한 회원의 표시/숨김을 토글.
  void toggle(String uid) {
    final next = {...state};
    if (!next.remove(uid)) next.add(uid);
    state = next;
  }

  /// 전원 표시(숨김 해제).
  void showAll() => state = <String>{};

  /// 전원 숨김.
  void hideAll(Iterable<String> uids) => state = {...uids};
}

final hiddenMembersProvider =
    NotifierProvider<HiddenMembers, Set<String>>(HiddenMembers.new);

/// 그룹의 전체 일정 목록(실시간). 월 필터링·반복 펼치기·회원 필터는 화면단에서.
final groupEventsProvider = StreamProvider<List<CalendarEvent>>((ref) {
  final group = ref.watch(currentGroupProvider).value;
  if (group == null) return Stream.value(const []);
  return ref.watch(firestoreServiceProvider).watchAllEvents(group.id);
});
