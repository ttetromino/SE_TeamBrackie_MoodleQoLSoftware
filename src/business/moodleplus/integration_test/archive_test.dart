import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../lib/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Archive Integration Tests', () {

    // Helper: Log in and stay on the Dashboard where active courses live
    Future<void> loginToDashboard(WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      final emailField = find.byType(TextField).at(0);
      final passwordField = find.byType(TextField).at(1);

      await tester.enterText(emailField, 'wilmartest1@gmail.com');
      await tester.enterText(passwordField, '123');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Log In'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    testWidgets('TC62 - Archive: Selection UI', (tester) async {
      try {
        await loginToDashboard(tester);

        final archiveIcon = find.byIcon(Icons.archive);
        expect(archiveIcon, findsWidgets, reason: "TC62 FAILED: Archive icon missing from active courses.");

        debugPrint('TC62 - Archive: Selection UI - PASSED ✅');
      } catch (e) {
        debugPrint('TC62 - Archive: Selection UI - FAILED ❌');
        rethrow;
      }
    });

  });
}