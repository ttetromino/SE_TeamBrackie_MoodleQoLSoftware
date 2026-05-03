// integration_test/login_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Helper to ensure we always start on a clean Login screen
  Future<void> startCleanLoginScreen(WidgetTester tester) async {
    // 1. Wipe any saved sessions so auto-login doesn't trigger
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // 2. Boot the app
    app.main();

    // 3. Wait for the splash screen to pass and the login screen to render
    debugPrint('⏳ Waiting for Splash Screen to complete...');
    bool loginScreenReady = false;

    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.byType(TextField).evaluate().isNotEmpty) {
        loginScreenReady = true;
        break;
      }
    }

    if (!loginScreenReady) {
      fail('❌ App failed to load the Login screen. Is the splash screen stuck?');
    }
  }

  group('US-01: Login Integration Tests', () {

    // ============================================================
    // TC13: Login - Happy Path
    // ============================================================
    testWidgets('TC13 - Login: Happy Path (Valid Credentials)', (tester) async {
      await startCleanLoginScreen(tester);

      final emailField = find.byType(TextField).first;
      final passField = find.byType(TextField).last;

      final loginButtonFinder = find.widgetWithText(ElevatedButton, 'Log In');
      final loginButton = loginButtonFinder.evaluate().isNotEmpty
          ? loginButtonFinder.first
          : find.byType(ElevatedButton).first;

      // 2. Enter verified email
      await tester.enterText(emailField, 'wilmartest1@gmail.com');

      // 3. Enter verified password
      await tester.enterText(passField, 'wilmartest');
      await tester.testTextInput.receiveAction(TextInputAction.done);

      // 4. Click Log In
      await tester.tap(loginButton);
      debugPrint('🔄 Logging in...');

      // Wait for authentication and navigation to Dashboard
      bool dashboardAppeared = false;
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 500));

        if (find.text('My Courses').evaluate().isNotEmpty ||
            find.byType(BottomNavigationBar).evaluate().isNotEmpty) {
          dashboardAppeared = true;
          break;
        }
      }

      expect(dashboardAppeared, true, reason: 'TC13 Failed: Did not redirect to Dashboard after valid login.');

      // THE FIX: The Cool-Down Period
      // Keep the test alive long enough for the app's background LMS sync to finish.
      // This prevents the "setState after dispose" crash when we cannot modify the app code.
      debugPrint('⏳ Waiting for background LMS sync to complete...');
      await tester.pump();
      await Future.delayed(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      debugPrint('✅ TC13 - Login: Happy Path PASSED');
    });

    // ============================================================
    // TC14: Login - Field Presence
    // ============================================================
    testWidgets('TC14 - Login: Field Presence', (tester) async {
      await startCleanLoginScreen(tester);

      // Verify at least two text fields exist (Email and Password)
      final textFields = find.byType(TextField);
      expect(textFields, findsAtLeastNWidgets(2), reason: 'TC14 Failed: Missing input fields.');

      // Verify specific Hint Text or Labels exist
      final emailHint = find.textContaining(RegExp(r'Email|Username', caseSensitive: false));
      final passHint = find.textContaining(RegExp(r'Password', caseSensitive: false));

      expect(emailHint.evaluate().isNotEmpty, true, reason: 'TC14 Failed: Email label/hint is missing.');
      expect(passHint.evaluate().isNotEmpty, true, reason: 'TC14 Failed: Password label/hint is missing.');

      debugPrint('✅ TC14 - Login: Field Presence PASSED');
    });

    // ============================================================
    // TC15: Login - Input Privacy (Password Masking)
    // ============================================================
    testWidgets('TC15 - Login: Input Privacy', (tester) async {
      await startCleanLoginScreen(tester);

      final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();

      // The second text field is usually the password field
      final passwordField = textFields.last;

      // Verify 'obscureText' is true by default
      expect(passwordField.obscureText, true, reason: 'TC15 Failed: Password field does not mask input by default.');

      // Look for the visibility toggle icon (usually the eye icon)
      final visibilityToggle = find.byIcon(Icons.visibility).evaluate().isNotEmpty
          ? find.byIcon(Icons.visibility)
          : find.byIcon(Icons.visibility_off);

      if (visibilityToggle.evaluate().isNotEmpty) {
        // Tap the icon to toggle privacy
        await tester.tap(visibilityToggle.first);
        await tester.pumpAndSettle();

        // Re-evaluate the widget tree after the tap
        final updatedPasswordField = tester.widget<TextField>(find.byType(TextField).last);
        expect(updatedPasswordField.obscureText, false, reason: 'TC15 Failed: Toggling the eye icon did not reveal the password.');

        debugPrint('✅ TC15 - Login: Input Privacy PASSED (Masking & Toggle confirmed)');
      } else {
        debugPrint('⚠️ TC15 Note: Password is masked, but no visibility toggle icon (eye) was found in the UI. Test passed partially.');
      }
    });

    // ============================================================
    // TC16: Login - Blank Fields Validation
    // ============================================================
    testWidgets('TC16 - Login: Blank Fields', (tester) async {
      await startCleanLoginScreen(tester);

      final loginButtonFinder = find.widgetWithText(ElevatedButton, 'Log In');
      final loginButton = loginButtonFinder.evaluate().isNotEmpty
          ? loginButtonFinder.first
          : find.byType(ElevatedButton).first;

      // Ensure fields are empty
      await tester.enterText(find.byType(TextField).first, '');
      await tester.enterText(find.byType(TextField).last, '');

      // Attempt to login
      await tester.tap(loginButton);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Verify error messages appear (e.g., "Required", "Cannot be empty", "Please enter")
      final validationError = find.textContaining(RegExp(r'Required|Empty|Please enter|Invalid', caseSensitive: false));

      expect(validationError.evaluate().isNotEmpty, true, reason: 'TC16 Failed: System allowed blank submission without showing error text.');

      debugPrint('✅ TC16 - Login: Blank Fields PASSED');
    });

    // ============================================================
    // TC17: Login - Invalid Credentials
    // ============================================================
    testWidgets('TC17 - Login: Invalid Credentials', (tester) async {
      await startCleanLoginScreen(tester);

      final emailField = find.byType(TextField).first;
      final passField = find.byType(TextField).last;

      final loginButtonFinder = find.widgetWithText(ElevatedButton, 'Log In');
      final loginButton = loginButtonFinder.evaluate().isNotEmpty
          ? loginButtonFinder.first
          : find.byType(ElevatedButton).first;

      // Enter fake credentials
      await tester.enterText(emailField, 'fake@account.com');
      await tester.enterText(passField, 'fakepassword');
      await tester.testTextInput.receiveAction(TextInputAction.done);

      // Click Log In
      await tester.tap(loginButton);

      // Wait for the backend rejection
      await tester.pump();
      await Future.delayed(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Look for a snackbar or text error indicating failure
      final authError = find.textContaining(RegExp(r'Invalid|Incorrect|Not found|Error', caseSensitive: false));

      expect(authError.evaluate().isNotEmpty, true, reason: 'TC17 Failed: System did not display an error message for invalid credentials.');

      // Ensure we are still on the login screen, not the dashboard
      expect(find.text('My Courses'), findsNothing, reason: 'TC17 Failed: System bypassed security and loaded the Dashboard with fake credentials.');

      debugPrint('✅ TC17 - Login: Invalid Credentials PASSED');
    });

  });
}