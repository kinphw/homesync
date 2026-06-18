import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'admin/admin_app.dart';

/// 관리자 웹 진입점. 일반 앱(main.dart)과 완전히 별개로 빌드한다.
///
/// 로컬 실행:   flutter run -d chrome -t lib/main_admin.dart
/// 웹 빌드:     flutter build web -t lib/main_admin.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting('ko_KR', null);

  runApp(const ProviderScope(child: AdminApp()));
}
