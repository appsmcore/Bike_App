import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pacematch/data/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('initAuth marks authReady without waiting on a backend', () async {
    final state = AppState();
    expect(state.authReady, isFalse);

    // Without Supabase keys the app uses local demo auth. initAuth must
    // flip authReady immediately so the splash screen can dismiss.
    await state.initAuth().timeout(const Duration(seconds: 2));

    expect(state.authReady, isTrue);
    expect(state.usesBackendAuth, isFalse);
  });
}
