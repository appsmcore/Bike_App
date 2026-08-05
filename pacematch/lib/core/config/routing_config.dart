/// Runtime config for routing / external APIs.
///
/// Keys load from (in order):
/// 1. `--dart-define=GH_API_KEY=…` / `ORS_API_KEY=…`
/// 2. `.env` in the app root (`GH_API_KEY`, `ORS_API_KEY`, or `VITE_*` aliases)
///
/// For local dev, put keys in `pacematch/.env` (see `.env.example`), then:
/// ```
/// flutter run -d chrome
/// ```
class RoutingConfig {
  RoutingConfig._();

  static String _ghApiKey = const String.fromEnvironment('GH_API_KEY');
  static String _orsApiKey = const String.fromEnvironment('ORS_API_KEY');
  static bool _envLoaded = false;

  static String get ghApiKey => _ghApiKey.trim();
  static String get orsApiKey => _orsApiKey.trim();

  static bool get hasGhApiKey => ghApiKey.isNotEmpty;
  static bool get hasOrsApiKey => orsApiKey.isNotEmpty;
  static bool get hasAnyRoutingKey => hasGhApiKey || hasOrsApiKey;

  /// Apply values discovered from flutter_dotenv (call after [dotenv.load]).
  static void applyDotenv(Map<String, String> env) {
    if (_ghApiKey.trim().isEmpty) {
      _ghApiKey = (env['GH_API_KEY'] ?? env['VITE_GH_API_KEY'] ?? '').trim();
    }
    if (_orsApiKey.trim().isEmpty) {
      _orsApiKey = (env['ORS_API_KEY'] ?? env['VITE_ORS_API_KEY'] ?? '').trim();
    }
    _envLoaded = true;
  }

  static bool get envLoaded => _envLoaded;
}
