import 'package:cloud_firestore/cloud_firestore.dart';

/// 가족 그룹 1개. Firestore `groups/{groupId}` 문서와 매핑된다.
class FamilyGroup {
  final String id;
  final String name;
  final String ownerUid;

  /// 그룹에 속한 회원 uid 목록.
  final List<String> memberUids;

  /// 가족이 참여할 때 입력하는 6자리 초대 코드.
  final String inviteCode;

  final DateTime? createdAt;

  const FamilyGroup({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.memberUids,
    required this.inviteCode,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'ownerUid': ownerUid,
      'memberUids': memberUids,
      'inviteCode': inviteCode,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory FamilyGroup.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return FamilyGroup(
      id: doc.id,
      name: (data['name'] ?? '') as String,
      ownerUid: (data['ownerUid'] ?? '') as String,
      memberUids: List<String>.from(data['memberUids'] ?? const []),
      inviteCode: (data['inviteCode'] ?? '') as String,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
