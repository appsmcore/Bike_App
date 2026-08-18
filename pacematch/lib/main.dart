import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/config/routing_config.dart';
import 'core/config/supabase_config.dart';
import 'core/router/app_router.dart';
import 'data/app_state.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  await _loadEnv();
  await AuthService.initialize();

  final appState = AppState();
  await appState.initAuth();
  final router = AppRouter.create(appState);

  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: PaceMatchApp(router: router),
    ),
  );
}

Future<void> _loadEnv() async {
  try {
    await dotenv.load(fileName: '.env');
    final env = Map<String, String>.from(dotenv.env);
    RoutingConfig.applyDotenv(env);
    SupabaseConfig.applyDotenv(env);
  } catch (e) {
    // Missing .env is fine when keys come from --dart-define.
    if (kDebugMode) {
      debugPrint('Env not loaded ($e). Using dart-define if set.');
    }
  }
}
