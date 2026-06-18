import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/calendar_event.dart';
import 'providers.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'screens/auth_gate.dart';

/// 앱 루트 위젯. 테마·로케일·진입점(AuthGate)을 설정한다.
class HomeSyncApp extends StatelessWidget {
  const HomeSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '우리집일정표',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('ko', 'KR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      home: const _NotificationSync(child: AuthGate()),
    );
  }
}

/// 일정 변경 시 로컬 알림을 자동 재예약하고, 시작 시 권한을 요청한다.
class _NotificationSync extends ConsumerStatefulWidget {
  const _NotificationSync({required this.child});
  final Widget child;

  @override
  ConsumerState<_NotificationSync> createState() => _NotificationSyncState();
}

class _NotificationSyncState extends ConsumerState<_NotificationSync> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotificationService.instance.init();
      if (ref.read(notificationsEnabledProvider)) {
        await NotificationService.instance.requestPermissions();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 일정 목록이 바뀌면 재예약
    ref.listen(groupEventsProvider, (_, next) {
      NotificationService.instance.rescheduleAll(
        next.value ?? const <CalendarEvent>[],
        enabled: ref.read(notificationsEnabledProvider),
      );
    });
    // 알림 on/off 토글 시 재예약(켤 때는 권한도 요청)
    ref.listen(notificationsEnabledProvider, (_, enabled) {
      if (enabled) NotificationService.instance.requestPermissions();
      NotificationService.instance.rescheduleAll(
        ref.read(groupEventsProvider).value ?? const <CalendarEvent>[],
        enabled: enabled,
      );
    });
    return widget.child;
  }
}
