/// Runtime config for Supabase (auth + future backend).
///
/// Keys load from (in order):
/// 1. `--dart-define=SUPABASE_URL=…` / `SUPABASE_ANON_KEY=…`
/// 2. `.env` in the app root
class SupabaseConfig {
  SupabaseConfig._();

  static String _url = const String.fromEnvironment('SUPABASE_URL');
  static String _anonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get url => _url.trim();
  static String get anonKey => _anonKey.trim();

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  static void applyDotenv(Map<String, String> env) {
    if (_url.trim().isEmpty) {
      _url = (env['SUPABASE_URL'] ?? '').trim();
    }
    if (_anonKey.trim().isEmpty) {
      _anonKey = (env['SUPABASE_ANON_KEY'] ?? '').trim();
    }
  }
}
