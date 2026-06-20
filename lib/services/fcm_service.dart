import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'notification_service.dart';

/// FCM(서버 푸시) 담당. 로그인한 사용자의 토큰을 Firestore에 저장하고,
/// 포그라운드 수신 시 로컬 알림으로 띄운다.
/// (백그라운드·종료 상태에서는 OS가 알림 트레이에 자동 표시)
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final _messaging = FirebaseMessaging.instance;
  final _db = FirebaseFirestore.instance;
  bool _foregroundSet = false;

  /// 로그인 후 호출: 권한 요청 + 토큰 저장 + 수신 핸들러 설정.
  Future<void> register(String uid) async {
    try {
      await _messaging.requestPermission();
      _setupForeground();
      final token = await _messaging.getToken();
      if (token != null) {
        await _db.collection('users').doc(uid).update({
          'fcmTokens': FieldValue.arrayUnion([token]),
        });
      }
      _messaging.onTokenRefresh.listen((t) {
        _db.collection('users').doc(uid).update({
          'fcmTokens': FieldValue.arrayUnion([t]),
        });
      });
    } catch (_) {
      // 권한 거부/네트워크 오류 등은 무시(앱 동작엔 지장 없음)
    }
  }

  /// 로그아웃 시 호출: 이 기기 토큰 제거.
  Future<void> unregister(String uid) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _db.collection('users').doc(uid).update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        });
      }
    } catch (_) {}
  }

  void _setupForeground() {
    if (_foregroundSet) return;
    _foregroundSet = true;
    FirebaseMessaging.onMessage.listen((message) {
      final n = message.notification;
      if (n != null) {
        NotificationService.instance.show(n.title ?? '새 알림', n.body ?? '');
      }
    });
  }
}
