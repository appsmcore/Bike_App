import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pacematch/app.dart';
import 'package:pacematch/core/router/app_router.dart';
import 'package:pacematch/data/app_state.dart';

void main() {
  testWidgets('Login screen shows PaceMatch', (tester) async {
    final state = AppState();
    await state.initAuth();
    final router = AppRouter.create(state);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: PaceMatchApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PaceMatch'), findsWidgets);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
