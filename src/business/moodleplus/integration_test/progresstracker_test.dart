import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
// Note: using package import is usually safer than relative '../lib/main.dart'
import 'package:moodleplus/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Progress Tracker Integration Tests', () {

    Future<void> login(WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      final emailField = find.byType(TextField).at(0);
      final passwordField = find.byType(TextField).at(1);

      await tester.enterText(emailField, 'wilmartest1@gmail.com');
      await tester.enterText(passwordField, '123');

      // Click the button using our robust widget finder
      await tester.tap(find.widgetWithText(ElevatedButton, 'Log In'));

      // Wait for login to process and navigate to Home
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    testWidgets('TC35 - Progress Tracker: Happy Path (Instant UI Sync)', (tester) async {
      try {
        await login(tester);

        expect(find.text('100%'), findsNothing,
            reason: "Setup Error: Tracker is already at 100% before test started.");

        final taskItem = find.byType(Checkbox).first;
        expect(taskItem, findsOneWidget, reason: "No pending tasks found to complete.");

        await tester.tap(taskItem);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        expect(find.text('100%'), findsOneWidget,
            reason: "DEFECT: Percentage did not sync to 100% after completion.");

        final zeroCounter = find.textContaining(RegExp(r'\b0\b'));
        expect(zeroCounter, findsWidgets,
            reason: "DEFECT: The 'Quizzes Left' counter did not reset to 0.");

        final progressBar = find.byType(LinearProgressIndicator);
        if (progressBar.evaluate().isNotEmpty) {
          final indicator = tester.widget<LinearProgressIndicator>(progressBar.first);
          expect(indicator.value, equals(1.0),
              reason: "DEFECT: The Progress Bar is not visually filled (value is not 1.0).");
        }

        debugPrint('TC35 - Progress Tracker: Happy Path - PASSED ✅');
      } catch (e) {
        debugPrint('TC35 - Progress Tracker: Happy Path - FAILED ❌');
        rethrow;
      }
    });
  });
}