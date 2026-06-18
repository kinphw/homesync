import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/family_group.dart';

/// 운영자 관제용 데이터 접근 계층. 전체 회원/그룹을 가로질러 읽는다.
/// (firestore.rules 의 isAdmin() 권한이 있는 계정에서만 동작한다.)
class AdminService {
  AdminService(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('groups');
  CollectionReference<Map<String, dynamic>> get _admins =>
      _db.collection('admins');

  /// 현재 사용자가 운영자인지 실시간 확인. admins/{uid} 문서 존재 여부로 판단한다.
  /// (실제 권한 경계는 firestore.rules 의 isAdmin() 이며, 이건 화면 분기용이다.)
  Stream<bool> watchIsAdmin(String uid) {
    return _admins.doc(uid).snapshots().map((doc) => doc.exists);
  }

  /// 회원의 로그인 차단 여부를 설정한다(true=차단, false=해제).
  /// 차단된 회원은 일반 앱이 로그인 직후 내보낸다(auth_gate 의 banned 분기).
  Future<void> setUserBanned(String uid, bool banned) async {
    await _users.doc(uid).update({'banned': banned});
  }

  /// 회원 가입내역(프로필 문서)을 삭제하고, 소속 그룹 구성원 목록에서도 뺀다.
  /// 단 로그인 계정(Firebase Auth) 자체는 서버가 없어 지우지 못한다
  /// (해당 계정으로 재로그인하면 프로필 없는 빈 상태가 되며, 앱이 안내 화면을 띄운다).
  Future<void> deleteUserAccount(String uid, String? groupId) async {
    if (groupId != null) {
      await _groups.doc(groupId).update({
        'memberUids': FieldValue.arrayRemove([uid]),
      });
    }
    await _users.doc(uid).delete();
  }

  /// 상단 요약 카드용 집계.
  /// count() 집계 쿼리는 문서를 전부 내려받지 않고 개수만 세므로 저렴하다.
  /// 한 집계가 실패(권한 등)해도 나머지는 보이도록 각각 독립적으로 센다.
  Future<AdminStats> fetchStats() async {
    final userCount = await _safeCount(_users);

    // 그룹 목록을 한 번 읽어 그룹 수와 그룹별 일정 수 합산에 함께 쓴다.
    // (collectionGroup 전체 집계는 보안 규칙에서 막히기 쉬워, 그룹별로 센다.)
    List<String>? groupIds;
    try {
      final snap = await _groups.get();
      groupIds = snap.docs.map((d) => d.id).toList();
    } catch (_) {
      groupIds = null;
    }

    return AdminStats(
      userCount: userCount,
      groupCount: groupIds?.length,
      eventCount: groupIds == null ? null : await _sumEventCounts(groupIds),
    );
  }

  /// 집계 1건. 실패하면 null(화면에 '—'로 표시)을 돌려주고 예외를 삼킨다.
  Future<int?> _safeCount(Query<Map<String, dynamic>> query) async {
    try {
      final snap = await query.count().get();
      return snap.count;
    } catch (_) {
      return null;
    }
  }

  /// 그룹별 일정 수를 각각 세어 합산한다(단일 경로 count라 규칙을 통과한다).
  /// 한 그룹이라도 실패하면 전체를 null로 둔다.
  Future<int?> _sumEventCounts(List<String> groupIds) async {
    try {
      var total = 0;
      for (final gid in groupIds) {
        final snap = await _groups.doc(gid).collection('events').count().get();
        total += snap.count ?? 0;
      }
      return total;
    } catch (_) {
      return null;
    }
  }

  /// 전체 회원 실시간 목록(가입 최신순).
  /// createdAt 이 없는 구버전 문서도 누락되지 않도록 정렬은 클라이언트에서 한다.
  Stream<List<AppUser>> watchAllUsers() {
    return _users.snapshots().map((snap) {
      final list = snap.docs.map(AppUser.fromDoc).toList();
      list.sort((a, b) => _byCreatedDesc(a.createdAt, b.createdAt));
      return list;
    });
  }

  /// 전체 그룹 실시간 목록(생성 최신순).
  Stream<List<FamilyGroup>> watchAllGroups() {
    return _groups.snapshots().map((snap) {
      final list = snap.docs.map(FamilyGroup.fromDoc).toList();
      list.sort((a, b) => _byCreatedDesc(a.createdAt, b.createdAt));
      return list;
    });
  }

  /// 최신순 정렬 비교자(날짜 없는 문서는 뒤로 보낸다).
  int _byCreatedDesc(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return b.compareTo(a);
  }
}

/// 관제 대시보드 상단 요약 수치.
class AdminStats {
  const AdminStats({
    this.userCount,
    this.groupCount,
    this.eventCount,
  });

  /// 각 값은 집계 실패(권한 거부 등) 시 null.
  final int? userCount;
  final int? groupCount;
  final int? eventCount;
}
