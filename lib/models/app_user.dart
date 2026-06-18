import 'package:cloud_firestore/cloud_firestore.dart';

/// 앱 회원 1명을 나타내는 모델. Firestore `users/{uid}` 문서와 매핑된다.
class AppUser {
  final String uid;
  final String name;

  /// 로그인에 쓰는 값(이메일 또는 아이디). 화면에도 표시된다.
  final String loginId;

  /// 이메일로 가입했는지 여부. true면 비밀번호 찾기(재설정 메일)가 가능하다.
  final bool isEmailAccount;

  /// 캘린더에서 이 회원을 구분하는 색상값(ARGB int).
  final int colorValue;

  /// 소속된 그룹 id. 아직 그룹이 없으면 null.
  final String? groupId;

  /// 운영자가 로그인을 차단한 회원인지. true면 일반 앱이 로그인 시 내보낸다.
  final bool banned;

  final DateTime? createdAt;

  const AppUser({
    required this.uid,
    required this.name,
    required this.loginId,
    required this.isEmailAccount,
    required this.colorValue,
    this.groupId,
    this.banned = false,
    this.createdAt,
  });

  AppUser copyWith({
    String? name,
    String? loginId,
    int? colorValue,
    String? groupId,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      loginId: loginId ?? this.loginId,
      isEmailAccount: isEmailAccount,
      colorValue: colorValue ?? this.colorValue,
      groupId: groupId ?? this.groupId,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'loginId': loginId,
      'isEmailAccount': isEmailAccount,
      'colorValue': colorValue,
      'groupId': groupId,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    // 구버전 호환: loginId가 없으면 예전 email 필드를 사용하고,
    // isEmailAccount 필드가 없으면 로그인값에 '@'가 있는지로 추론한다.
    final rawLoginId = (data['loginId'] ?? '') as String;
    final legacyEmail = (data['email'] ?? '') as String;
    final loginId = rawLoginId.isNotEmpty ? rawLoginId : legacyEmail;
    final isEmailAccount = data.containsKey('isEmailAccount')
        ? (data['isEmailAccount'] ?? false) as bool
        : loginId.contains('@');
    return AppUser(
      uid: doc.id,
      name: (data['name'] ?? '') as String,
      loginId: loginId,
      isEmailAccount: isEmailAccount,
      colorValue: (data['colorValue'] ?? 0xFF1565C0) as int,
      groupId: data['groupId'] as String?,
      banned: data['banned'] == true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
