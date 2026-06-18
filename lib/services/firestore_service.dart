import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/calendar_event.dart';
import '../models/family_group.dart';

/// Firestore 데이터 접근 계층. users / groups / events 컬렉션을 다룬다.
class FirestoreService {
  FirestoreService(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('groups');
  CollectionReference<Map<String, dynamic>> _events(String groupId) =>
      _groups.doc(groupId).collection('events');

  // ---------------- 사용자 ----------------

  Future<void> createUser(AppUser user) async {
    await _users.doc(user.uid).set(user.toMap());
  }

  Stream<AppUser?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map(
          (doc) => doc.exists ? AppUser.fromDoc(doc) : null,
        );
  }

  Future<void> setUserGroup(String uid, String? groupId) async {
    await _users.doc(uid).update({'groupId': groupId});
  }

  /// 프로필(이름·색상) 변경. 그룹이 있으면 본인 일정의 비정규화 필드도 동기화.
  Future<void> updateProfile({
    required String uid,
    required String name,
    required int colorValue,
    String? groupId,
  }) async {
    await _users.doc(uid).update({
      'name': name.trim(),
      'colorValue': colorValue,
    });
    if (groupId != null) {
      final mine =
          await _events(groupId).where('ownerUid', isEqualTo: uid).get();
      for (var i = 0; i < mine.docs.length; i += 400) {
        final batch = _db.batch();
        for (final d in mine.docs.skip(i).take(400)) {
          batch.update(d.reference,
              {'ownerName': name.trim(), 'colorValue': colorValue});
        }
        await batch.commit();
      }
    }
  }

  /// 그룹 구성원들의 프로필을 실시간으로 가져온다.
  Stream<List<AppUser>> watchMembers(List<String> uids) {
    if (uids.isEmpty) return Stream.value(const []);
    // Firestore whereIn 은 최대 30개까지. 가족 규모에서는 충분.
    return _users
        .where(FieldPath.documentId, whereIn: uids)
        .snapshots()
        .map((snap) => snap.docs.map(AppUser.fromDoc).toList());
  }

  // ---------------- 그룹 ----------------

  Stream<FamilyGroup?> watchGroup(String groupId) {
    return _groups.doc(groupId).snapshots().map(
          (doc) => doc.exists ? FamilyGroup.fromDoc(doc) : null,
        );
  }

  /// 그룹 생성 후 생성한 그룹 id 반환. 생성자를 첫 멤버로 등록한다.
  Future<String> createGroup({
    required String name,
    required String ownerUid,
  }) async {
    final code = _generateInviteCode();
    final ref = await _groups.add({
      'name': name.trim(),
      'ownerUid': ownerUid,
      'memberUids': [ownerUid],
      'inviteCode': code,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await setUserGroup(ownerUid, ref.id);
    return ref.id;
  }

  /// 초대 코드로 그룹을 찾는다(없으면 null).
  Future<FamilyGroup?> findGroupByInviteCode(String code) async {
    final snap = await _groups
        .where('inviteCode', isEqualTo: code.trim().toUpperCase())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return FamilyGroup.fromDoc(snap.docs.first);
  }

  /// 그룹 참여: 멤버 목록에 추가하고 사용자 프로필의 groupId 설정.
  Future<void> joinGroup({
    required String groupId,
    required String uid,
  }) async {
    await _groups.doc(groupId).update({
      'memberUids': FieldValue.arrayUnion([uid]),
    });
    await setUserGroup(uid, groupId);
  }

  /// 그룹 나가기: 구성원 목록에서 본인을 빼고 groupId 해제.
  Future<void> leaveGroup({
    required String groupId,
    required String uid,
  }) async {
    await _groups.doc(groupId).update({
      'memberUids': FieldValue.arrayRemove([uid]),
    });
    await setUserGroup(uid, null);
  }

  /// 구성원 강퇴(방장): 구성원 목록에서 제거. 강퇴된 사용자는 자기 앱에서
  /// 더 이상 멤버가 아님을 감지하고 그룹 설정 화면으로 이동된다.
  Future<void> kickMember({
    required String groupId,
    required String uid,
  }) async {
    await _groups.doc(groupId).update({
      'memberUids': FieldValue.arrayRemove([uid]),
    });
  }

  /// 방장 위임: 그룹의 ownerUid를 다른 구성원으로 변경.
  Future<void> transferOwnership({
    required String groupId,
    required String newOwnerUid,
  }) async {
    await _groups.doc(groupId).update({'ownerUid': newOwnerUid});
  }

  /// 그룹 삭제(방장 전용): 모든 일정과 그룹 문서를 삭제하고 방장 groupId 해제.
  /// 다른 구성원은 그룹이 사라지면 각자 앱이 그룹 설정 화면으로 보낸다.
  Future<void> deleteGroup({
    required String groupId,
    required String ownerUid,
  }) async {
    // 1) 일정 전부 삭제 (배치, 500개 제한이라 안전하게 400씩)
    final events = await _events(groupId).get();
    for (var i = 0; i < events.docs.length; i += 400) {
      final batch = _db.batch();
      for (final d in events.docs.skip(i).take(400)) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
    // 2) 그룹 문서 삭제
    await _groups.doc(groupId).delete();
    // 3) 방장 본인 groupId 해제
    await setUserGroup(ownerUid, null);
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // 헷갈리는 0/O/1/I 제외
    final rnd = Random.secure();
    return List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  // ---------------- 일정 ----------------

  /// 그룹의 모든 일정을 실시간 구독.
  /// (반복 일정은 앵커가 과거일 수 있어 월 범위로 거르지 않고 전체를 받아
  ///  화면단에서 보이는 달에 맞춰 펼친다. 가족 규모에서는 데이터가 작아 가볍다.)
  Stream<List<CalendarEvent>> watchAllEvents(String groupId) {
    return _events(groupId)
        .snapshots()
        .map((snap) => snap.docs.map(CalendarEvent.fromDoc).toList());
  }

  Future<void> addEvent(String groupId, CalendarEvent event) async {
    await _events(groupId).add(event.toMap());
  }

  Future<void> updateEvent(String groupId, CalendarEvent event) async {
    await _events(groupId).doc(event.id).update(event.toMap());
  }

  Future<void> deleteEvent(String groupId, String eventId) async {
    await _events(groupId).doc(eventId).delete();
  }
}
