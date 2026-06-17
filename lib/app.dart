import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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
      home: const AuthGate(),
    );
  }
}
