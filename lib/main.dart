import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/navigation/platform_navigation.dart';
import 'core/tdlib/tdlib_json.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    tdlibDebugLog(
      'debug build: TDLib int64 string coercion + parse error logs enabled',
    );
  }

  await initializeDateFormatting('ru');
  await PlatformNavigation.configure();
  final config = await AppConfig.load();
  runApp(RioGramApp(config: config));
}
