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

  /// 상단 요약 카드용 집계.
  /// count() 집계 쿼리는 문서를 전부 내려받지 않고 개수만 세므로 저렴하다.
  Future<AdminStats> fetchStats() async {
    final results = await Future.wait([
      _users.count().get(),
      _groups.count().get(),
      _db.collectionGroup('events').count().get(),
    ]);
    return AdminStats(
      userCount: results[0].count ?? 0,
      groupCount: results[1].count ?? 0,
      eventCount: results[2].count ?? 0,
    );
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
    required this.userCount,
    required this.groupCount,
    required this.eventCount,
  });

  final int userCount;
  final int groupCount;
  final int eventCount;
}
