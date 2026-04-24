import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../lib/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Profile Integration Tests', () {

    // ---------------------------------------------------------
    // HELPER: Log In & Navigate to Profile Tab
    // ---------------------------------------------------------
    Future<void> loginAndGoToProfile(WidgetTester tester, {String email = 'wilmartest1@gmail.com', String pass = '123'}) async {
      app.main();
      await tester.pumpAndSettle();

      final emailField = find.byType(TextField).at(0);
      final passwordField = find.byType(TextField).at(1);

      await tester.enterText(emailField, email);
      await tester.enterText(passwordField, pass);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Log In'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final profileTab = find.text('Profile');
      expect(profileTab, findsOneWidget, reason: "Could not find 'Profile' tab.");
      await tester.tap(profileTab);
      await tester.pumpAndSettle(const Duration(seconds: 1));
    }

    // ---------------------------------------------------------
    // TC49 & TC50: Access & Field Presence
    // ---------------------------------------------------------
    testWidgets('TC49 & TC50 - Access Edit Page & Verify Fields', (tester) async {
      try {
        await loginAndGoToProfile(tester);

        await tester.tap(find.byIcon(Icons.edit));
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // Check that at least 3 TextFields exist (Email, Password, Confirm)
        expect(find.byType(TextField), findsAtLeastNWidgets(3),
            reason: "Missing mandatory text fields on the Edit Profile page.");

       // expect(find.byType(CircleAvatar), findsWidgets,
         //   reason: "Profile Picture UI element is missing.");

        debugPrint('TC49 & TC50 - Edit Access & Fields - PASSED ✅');
      } catch (e) {
        debugPrint('TC49 & TC50 - Edit Access & Fields - FAILED ❌');
        rethrow;
      }
    });

    testWidgets('TC53 - Profile: Password Mismatch', (tester) async {
      try {
        await loginAndGoToProfile(tester);
        await tester.tap(find.byIcon(Icons.edit));
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // Note to QA: Adjust these indexes based on your app's actual layout!
        // Assuming: 0=Email, 1=Old Pass, 2=New Pass, 3=Confirm Pass
        final newPassField = find.byType(TextField).at(2);
        final confirmPassField = find.byType(TextField).at(3);

        await tester.enterText(newPassField, 'NewPass123');
        await tester.enterText(confirmPassField, 'DifferentPass456');

        await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
        await tester.pumpAndSettle(const Duration(milliseconds: 500));

        // Ensure we are still on the edit page (error caught it)
        expect(find.byType(TextField), findsWidgets,
            reason: "DEFECT: System allowed mismatched passwords to be saved.");

        debugPrint('TC53 - Profile: Password Mismatch - PASSED ✅');
      } catch (e) {
        debugPrint('TC53 - Profile: Password Mismatch - FAILED ❌');
        rethrow;
      }
    });



    testWidgets('TC60 - Profile: Empty Field Validation', (tester) async {
      try {
        await loginAndGoToProfile(tester);
        await tester.tap(find.byIcon(Icons.edit));
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // Clear the first field (Assuming Email is at index 0)
        await tester.enterText(find.byType(TextField).at(0), '');

        await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
        await tester.pumpAndSettle(const Duration(milliseconds: 500));

        // Verify it did not save and navigate back
        expect(find.byType(TextField), findsWidgets,
            reason: "DEFECT: Allowed saving an empty mandatory field.");

        debugPrint('TC60 - Profile: Empty Field - PASSED ✅');
      } catch (e) {
        debugPrint('TC60 - Profile: Empty Field - FAILED ❌');
        rethrow;
      }
    });

  });
}