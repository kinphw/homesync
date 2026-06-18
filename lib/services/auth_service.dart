import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import 'firestore_service.dart';

/// 회원가입·로그인·로그아웃 담당.
///
/// 가입 시 **이메일을 권장**한다(이메일이 있어야 비밀번호 찾기가 가능).
/// 다만 이메일이 없는 어린이 등을 위해 "아이디"로도 가입할 수 있게,
/// 아이디는 내부적으로 `아이디@homesync.app` 형태의 가짜 이메일로 변환해
/// Firebase Auth에 넘긴다. (이 주소로 실제 메일이 가지는 않는다 = 복구 불가)
class AuthService {
  AuthService(this._auth, this._firestore);

  final FirebaseAuth _auth;
  final FirestoreService _firestore;

  /// 이메일 없는 아이디 가입에 쓰는 내부 도메인.
  static const String _internalDomain = 'homesync.app';

  /// 입력값이 이메일인지(@ 포함) 판단.
  static bool looksLikeEmail(String account) => account.contains('@');

  /// 로그인 계정값(이메일/아이디)을 Firebase 이메일로 변환.
  static String firebaseEmailFor(String account) {
    final a = account.trim().toLowerCase();
    return looksLikeEmail(a) ? a : '$a@$_internalDomain';
  }

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// 회원가입. account 는 이메일 또는 아이디.
  Future<void> signUp({
    required String name,
    required String account,
    required String password,
    required int colorValue,
  }) async {
    final isEmail = looksLikeEmail(account);
    final cred = await _auth.createUserWithEmailAndPassword(
      email: firebaseEmailFor(account),
      password: password,
    );
    final uid = cred.user!.uid;
    await _firestore.createUser(
      AppUser(
        uid: uid,
        name: name.trim(),
        loginId: account.trim().toLowerCase(),
        isEmailAccount: isEmail,
        colorValue: colorValue,
        groupId: null,
      ),
    );
  }

  Future<void> signIn({
    required String account,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: firebaseEmailFor(account),
      password: password,
    );
  }

  /// 비밀번호 재설정 메일 발송(이메일 가입자만 의미 있음).
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// 비밀번호 변경: 현재 비밀번호로 재인증 후 새 비밀번호로 교체.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw FirebaseAuthException(
          code: 'no-current-user', message: '로그인 상태가 아닙니다.');
    }
    final cred = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(cred);
    await user.updatePassword(newPassword);
  }

  Future<void> signOut() => _auth.signOut();
}
