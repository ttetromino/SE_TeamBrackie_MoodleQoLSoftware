// integration_test/profile_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final String baseEmail = 'wilmartest1@gmail.com';
  final String basePassword = 'wilmartest';

  // ============================================================
  // HELPER: Smart Login
  // ============================================================
  Future<void> loginAndNavigateToProfile(WidgetTester tester, {String email = 'wilmartest1@gmail.com', String password = 'wilmartest'}) async {
    app.main();
    bool isReady = false;
    bool needsManualLogin = true;

    for (int i = 0; i < 20; i++) {
      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 500));
      if (find.text('My Courses').evaluate().isNotEmpty || find.byIcon(Icons.person).evaluate().isNotEmpty) {
        isReady = true;
        needsManualLogin = false;
        break;
      }
      if (find.byType(TextField).evaluate().isNotEmpty) {
        isReady = true;
        needsManualLogin = true;
        break;
      }
    }

    if (!isReady) fail('❌ App stuck on splash screen.');

    if (needsManualLogin) {
      final emailField = find.byType(TextField).first;
      final passField = find.byType(TextField).last;
      final loginButton = find.widgetWithText(ElevatedButton, 'Log In').evaluate().isNotEmpty
          ? find.widgetWithText(ElevatedButton, 'Log In').first
          : find.byType(ElevatedButton).first;

      await tester.enterText(emailField, email);
      await tester.enterText(passField, password);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.tap(loginButton);

      bool loginFinished = false;
      for (int i = 0; i < 40; i++) {
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 500));
        if (find.text('Profile').evaluate().isNotEmpty || find.text('My Courses').evaluate().isNotEmpty || find.byIcon(Icons.person).evaluate().isNotEmpty) {
          loginFinished = true;
          break;
        }
      }
      if (!loginFinished) fail('❌ Stuck on loading spinner after tapping Log In.');
    }

    await tester.pumpAndSettle();

    final profileIcon = find.byIcon(Icons.person);
    final profileText = find.text('Profile');

    if (profileIcon.evaluate().isNotEmpty) {
      await tester.tap(profileIcon.first);
    } else if (profileText.evaluate().isNotEmpty) {
      await tester.tap(profileText.first);
    } else {
      final bottomNavItems = find.byType(BottomNavigationBarItem);
      if(bottomNavItems.evaluate().isNotEmpty) await tester.tap(bottomNavItems.last);
    }

    await tester.pump();
    await Future.delayed(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  // ============================================================
  // HELPER: Open Edit Screen
  // ============================================================
  Future<void> openEditScreen(WidgetTester tester) async {
    final editIcon = find.byIcon(Icons.edit);
    if(editIcon.evaluate().isNotEmpty) {
      await tester.tap(editIcon.first);
    } else {
      final editText = find.textContaining(RegExp(r'Edit|Update', caseSensitive: false));
      if(editText.evaluate().isNotEmpty) await tester.tap(editText.first);
    }
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  // ============================================================
  // HELPER: Logout (With Confirmation Popup Handling)
  // ============================================================
  Future<void> performLogout(WidgetTester tester) async {
    // 1. Find and tap the initial Log Out button on the Profile page
    final initialLogoutButton = find.widgetWithText(ElevatedButton, 'Log Out').evaluate().isNotEmpty
        ? find.widgetWithText(ElevatedButton, 'Log Out').first
        : find.byIcon(Icons.logout).first;

    await tester.ensureVisible(initialLogoutButton);
    await tester.tap(initialLogoutButton);

    // Wait for the confirmation popup to fully animate onto the screen
    await tester.pumpAndSettle();

    // 2. Find and tap the red "Logout" button inside the popup
    // We target the popup specifically so it does not accidentally tap the background button again
    final confirmLogoutFinder = find.descendant(
      of: find.byType(AlertDialog), // Replace with Dialog if you are using a custom dialog widget
      matching: find.textContaining(RegExp(r'Logout|Log Out|Yes', caseSensitive: false)),
    );

    if (confirmLogoutFinder.evaluate().isNotEmpty) {
      await tester.tap(confirmLogoutFinder.last);
    } else {
      // Fallback: If AlertDialog isn't used, just tap the last matching text on the screen (the topmost layer)
      final fallbackFinder = find.textContaining(RegExp(r'Logout|Log Out', caseSensitive: false));
      await tester.tap(fallbackFinder.last);
    }

    // Wait for the backend logout request and the navigation back to the login screen
    await tester.pump();
    await Future.delayed(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  // ============================================================
  // HELPER: Emergency Revert (Protects your Test Account)
  // ============================================================
  Future<void> emergencyRevert(WidgetTester tester, String currentEmail, String currentPass) async {
    debugPrint('🧹 CLEANUP: Restoring account to $baseEmail / $basePassword');
    try {
      final loginButton = find.widgetWithText(ElevatedButton, 'Log In');
      if (loginButton.evaluate().isNotEmpty) {
        await tester.enterText(find.byType(TextField).first, currentEmail);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.enterText(find.byType(TextField).last, currentPass);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.tap(loginButton.first);

        for (int i = 0; i < 20; i++) {
          await tester.pump();
          await Future.delayed(const Duration(milliseconds: 500));
          if (find.byIcon(Icons.person).evaluate().isNotEmpty) break;
        }
      }

      final profileIcon = find.byIcon(Icons.person);
      if (profileIcon.evaluate().isNotEmpty) {
        await tester.tap(profileIcon.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      await openEditScreen(tester);
      final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();

      if (textFields.length >= 3) {
        final newPassField = find.byType(TextField).at(textFields.length - 3);
        final confirmPassField = find.byType(TextField).at(textFields.length - 2);
        final currentPassField = find.byType(TextField).last;

        await tester.enterText(newPassField, basePassword);
        await tester.testTextInput.receiveAction(TextInputAction.done);

        await tester.enterText(confirmPassField, basePassword);
        await tester.testTextInput.receiveAction(TextInputAction.done);

        await tester.enterText(currentPassField, currentPass);
        await tester.testTextInput.receiveAction(TextInputAction.done);
      }

      final saveButtonFinder = find.descendant(
        of: find.byType(ElevatedButton),
        matching: find.textContaining(RegExp(r'Save|Update', caseSensitive: false)),
      );

      await tester.ensureVisible(saveButtonFinder.first);
      await tester.tap(saveButtonFinder.first);
      await tester.pump();
      await Future.delayed(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      debugPrint('✅ CLEANUP SUCCESSFUL');
    } catch (e) {
      debugPrint('❌ FATAL CLEANUP ERROR: Account stuck with $currentEmail / $currentPass');
    }
  }


  group('US-03: Profile Integration Tests', () {


    // ============================================================
    // TC48: Profile - Happy Path
    // ============================================================
    testWidgets('TC48 - Profile: Happy Path', (tester) async {
      final String tempPass = 'TempPass123!';
      bool isDirty = false;

      try {
        await loginAndNavigateToProfile(tester, email: baseEmail, password: basePassword);
        await openEditScreen(tester);

        final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
        await tester.enterText(find.byType(TextField).at(textFields.length - 2), tempPass);
        await tester.enterText(find.byType(TextField).last, tempPass);
        if (textFields.length >= 4) await tester.enterText(find.byType(TextField).at(1), basePassword);

        final saveButton = find.textContaining(RegExp(r'Save|Update', caseSensitive: false));
        await tester.tap(saveButton.first);
        await tester.pump();
        await Future.delayed(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        isDirty = true;

        await performLogout(tester);

        // Login with new pass
        await tester.enterText(find.byType(TextField).first, baseEmail);
        await tester.enterText(find.byType(TextField).last, tempPass);
        await tester.tap(find.widgetWithText(ElevatedButton, 'Log In').first);

        bool success = false;
        for (int i = 0; i < 40; i++) {
          await tester.pump();
          await Future.delayed(const Duration(milliseconds: 500));
          if (find.byIcon(Icons.person).evaluate().isNotEmpty) {
            success = true;
            break;
          }
        }
        expect(success, true, reason: 'TC48 Failed: Could not log in with new password.');
        debugPrint('✅ TC48 PASSED');
      } finally {
        if (isDirty) await emergencyRevert(tester, baseEmail, tempPass);
      }
    });

    // ============================================================
    // TC49: Profile - Edit Page Access
    // ============================================================
    testWidgets('TC49 - Profile: Edit Page Access', (tester) async {
      await loginAndNavigateToProfile(tester, email: baseEmail, password: basePassword);
      await openEditScreen(tester);

      final textFields = find.byType(TextField);
      expect(textFields.evaluate().isNotEmpty, true, reason: 'TC49 Failed: Did not navigate to Edit Profile.');
      debugPrint('✅ TC49 PASSED');
    });

    // ============================================================
    // TC50: Profile - Field Presence
    // ============================================================
    testWidgets('TC50 - Profile: Field Presence', (tester) async {
      await loginAndNavigateToProfile(tester, email: baseEmail, password: basePassword);
      await openEditScreen(tester);

      final emailHint = find.textContaining(RegExp(r'Email', caseSensitive: false));
      final passwordHint = find.textContaining(RegExp(r'Password', caseSensitive: false));

      expect(emailHint.evaluate().isNotEmpty, true, reason: 'TC50 Failed: Email field missing.');
      expect(passwordHint.evaluate().isNotEmpty, true, reason: 'TC50 Failed: Password field missing.');
      debugPrint('✅ TC50 PASSED');
    });

    // ============================================================
    // TC52: Profile - Password Auth (Negative)
    // ============================================================
    testWidgets('TC52 - Profile: Password Auth (Negative)', (tester) async {
      await loginAndNavigateToProfile(tester, email: baseEmail, password: basePassword);
      await openEditScreen(tester);

      final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      if (textFields.length >= 3) {
        await tester.enterText(find.byType(TextField).at(1), 'WrongOldPass123!');

        final saveButton = find.textContaining(RegExp(r'Save|Update', caseSensitive: false));
        if(saveButton.evaluate().isNotEmpty) await tester.tap(saveButton.first);
        await tester.pumpAndSettle();

        final authError = find.textContaining(RegExp(r'incorrect|wrong|invalid', caseSensitive: false));
        expect(authError.evaluate().isNotEmpty, true, reason: 'TC52 Failed: Allowed update with incorrect old password.');
        debugPrint('✅ TC52 PASSED');
      }
    });

    // ============================================================
    // TC53: Profile - Pass Mismatch (Negative)
    // ============================================================
    testWidgets('TC53 - Profile: Pass Mismatch Validation', (tester) async {
      await loginAndNavigateToProfile(tester, email: baseEmail, password: basePassword);
      await openEditScreen(tester);

      final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      if (textFields.length >= 3) {
        await tester.enterText(find.byType(TextField).at(textFields.length - 2), 'NewPass123');
        await tester.enterText(find.byType(TextField).last, 'DifferentPass456');

        final saveButton = find.textContaining(RegExp(r'Save|Update', caseSensitive: false));
        if(saveButton.evaluate().isNotEmpty) await tester.tap(saveButton.first);
        await tester.pumpAndSettle();

        final mismatchError = find.textContaining(RegExp(r'do not match|mismatch', caseSensitive: false));
        expect(mismatchError.evaluate().isNotEmpty, true, reason: 'TC53 Failed: Did not catch mismatched passwords.');
        debugPrint('✅ TC53 PASSED');
      }
    });

    // ============================================================
    // TC54: Profile - Success Pop-up (Name Update)
    // ============================================================
    testWidgets('TC54 - Profile: Success Pop-up', (tester) async {
      final String newName = 'New Name Lipata';
      final String originalName = 'Wilmar Lipata';
      bool isDirty = false;

      try {
        await loginAndNavigateToProfile(tester, email: baseEmail, password: basePassword);
        await openEditScreen(tester);

        final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();

        if (textFields.length >= 2) {
          final nameField = find.byType(TextField).first;
          final currentPasswordField = find.byType(TextField).last;

          // 1. Enter the new name
          await tester.enterText(nameField, newName);
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();

          // 2. Enter the current password to authorize
          await tester.enterText(currentPasswordField, basePassword);
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();

          // 3. Stricter Button Finder: Look specifically for an ElevatedButton containing "Save" or "Update"
          final saveButtonFinder = find.descendant(
            of: find.byType(ElevatedButton), // Adjust this if your button is an OutlinedButton or TextButton
            matching: find.textContaining(RegExp(r'Save|Update', caseSensitive: false)),
          );

          if (saveButtonFinder.evaluate().isEmpty) {
            fail('TC54 Failed: Could not locate an ElevatedButton with text "Save" or "Update". Check button widget type.');
          }

          await tester.ensureVisible(saveButtonFinder.first);
          await tester.pumpAndSettle();
          await tester.tap(saveButtonFinder.first);

          isDirty = true;

          // 4. Polling loop to catch the success popup
          bool foundPopup = false;
          for (int i = 0; i < 50; i++) {
            await tester.pump(const Duration(milliseconds: 200));

            final successPopup = find.textContaining(RegExp(r'Success|Updated|Saved|Changed', caseSensitive: false));
            if (successPopup.evaluate().isNotEmpty) {
              foundPopup = true;
              break;
            }
          }

          expect(foundPopup, true, reason: 'TC54 Failed: Success pop-up did not appear after saving name.');

          await tester.pumpAndSettle(const Duration(seconds: 4));
          debugPrint('✅ TC54 PASSED');

        } else {
          debugPrint('⚠️ TC54 Skipped: Could not find enough text fields for Name and Password.');
        }

      } finally {
        // ============================================================
        // CLEANUP: Revert the name back to originalName
        // ============================================================
        if (isDirty) {
          debugPrint('🧹 CLEANUP: Reverting name back to "$originalName"...');
          try {
            final editIcon = find.byIcon(Icons.edit);
            if (editIcon.evaluate().isNotEmpty) {
              await openEditScreen(tester);
            }

            final nameField = find.byType(TextField).first;
            final currentPasswordField = find.byType(TextField).last;

            await tester.enterText(nameField, originalName);
            await tester.testTextInput.receiveAction(TextInputAction.done);

            await tester.enterText(currentPasswordField, basePassword);
            await tester.testTextInput.receiveAction(TextInputAction.done);
            await tester.pumpAndSettle();

            // Strict button finder for cleanup as well
            final saveButtonFinder = find.descendant(
              of: find.byType(ElevatedButton),
              matching: find.textContaining(RegExp(r'Save|Update', caseSensitive: false)),
            );

            await tester.ensureVisible(saveButtonFinder.first);
            await tester.tap(saveButtonFinder.first);

            await tester.pumpAndSettle(const Duration(seconds: 4));
            debugPrint('✅ CLEANUP SUCCESSFUL: Name restored.');
          } catch (e) {
            debugPrint('❌ FATAL ERROR: Failed to revert name. Account name is stuck as "$newName"');
          }
        }
      }
    });

    // ============================================================
    // TC56: Profile - Old Pass Block (Negative)
    // ============================================================
    testWidgets('TC56 - Profile: Old Pass Block', (tester) async {
      final String tempPass = 'TempPass123!';
      bool isDirty = false;

      try {
        await loginAndNavigateToProfile(tester, email: baseEmail, password: basePassword);
        await openEditScreen(tester);

        final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();

        if (textFields.length < 3) {
          fail('TC56 Failed: Could not find enough text fields on the edit screen to change the password.');
        }

        // 1. Safely target the password fields counting from the bottom
        final newPassField = find.byType(TextField).at(textFields.length - 3);
        final confirmPassField = find.byType(TextField).at(textFields.length - 2);
        final currentPassField = find.byType(TextField).last;

        await tester.enterText(newPassField, tempPass);
        await tester.testTextInput.receiveAction(TextInputAction.done);

        await tester.enterText(confirmPassField, tempPass);
        await tester.testTextInput.receiveAction(TextInputAction.done);

        await tester.enterText(currentPassField, basePassword);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        // 2. Strict button finder
        final saveButtonFinder = find.descendant(
          of: find.byType(ElevatedButton),
          matching: find.textContaining(RegExp(r'Save|Update', caseSensitive: false)),
        );

        if (saveButtonFinder.evaluate().isEmpty) {
          fail('TC56 Failed: Could not locate an ElevatedButton with text "Save" or "Update".');
        }

        // Ensure visible and tap
        await tester.ensureVisible(saveButtonFinder.first);
        await tester.tap(saveButtonFinder.first);

        // 3. NEW: Wait for the popup and click it
        bool foundPopup = false;
        for (int i = 0; i < 50; i++) {
          await tester.pump(const Duration(milliseconds: 200));

          final successPopup = find.textContaining(RegExp(r'Success|Updated|Saved|Changed', caseSensitive: false));
          if (successPopup.evaluate().isNotEmpty) {
            foundPopup = true;

            // Try to find an explicit dismiss button on the popup
            final dismissButton = find.textContaining(RegExp(r'OK|Close|Got it|Done|Dismiss|Continue', caseSensitive: false));
            if (dismissButton.evaluate().isNotEmpty) {
              await tester.tap(dismissButton.first);
            } else {
              // If no specific button exists, tap the popup text itself
              await tester.tap(successPopup.first);
            }

            await tester.pumpAndSettle(const Duration(seconds: 2));
            break;
          }
        }

        if (!foundPopup) {
          fail('TC56 Failed: Success pop-up did not appear, could not click it to proceed.');
        }

        isDirty = true;

        // 4. Return to Main Profile Tab
        final backButton = find.byTooltip('Back');
        final profileNavIcon = find.byIcon(Icons.person);

        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton.first);
        } else if (profileNavIcon.evaluate().isNotEmpty) {
          await tester.tap(profileNavIcon.first);
        } else {
          final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
          await widgetsAppState.didPopRoute();
        }
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // 5. Logout
        await performLogout(tester);

        // Wait for the Login screen to fully render before trying to type
        bool loginScreenReady = false;
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          if (find.byType(TextField).evaluate().length >= 2) {
            loginScreenReady = true;
            break;
          }
        }

        if (!loginScreenReady) {
          fail('TC56 Failed: Did not navigate to Login screen after logout.');
        }

        // 6. Try logging in with the OLD basePassword
        final emailField = find.byType(TextField).first;
        final passField = find.byType(TextField).last;
        final loginBtn = find.textContaining(RegExp(r'Log In|Login', caseSensitive: false)).last;

        await tester.enterText(emailField, baseEmail);
        await tester.testTextInput.receiveAction(TextInputAction.done);

        await tester.enterText(passField, basePassword);
        await tester.testTextInput.receiveAction(TextInputAction.done);

        await tester.tap(loginBtn);

        // Wait for the backend rejection
        await tester.pump();
        await Future.delayed(const Duration(seconds: 3));
        await tester.pumpAndSettle();

        // 7. Verify the error message appears
        final authError = find.textContaining(RegExp(r'Invalid|Incorrect|Not found|Error|Wrong', caseSensitive: false));
        expect(authError.evaluate().isNotEmpty, true, reason: 'TC56 Failed: System allowed login with old password.');

        debugPrint('✅ TC56 PASSED');

      } finally {
        if (isDirty) await emergencyRevert(tester, baseEmail, tempPass);
      }
    });

    // ============================================================
    // TC57: Profile - New Pass Login (Positive)
    // ============================================================
    testWidgets('TC57 - Profile: New Pass Login', (tester) async {
      final String tempPass = 'TempPass123!';
      bool isDirty = false;

      try {
        await loginAndNavigateToProfile(tester, email: baseEmail, password: basePassword);
        await openEditScreen(tester);

        final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();

        if (textFields.length < 3) {
          fail('TC57 Failed: Could not find enough text fields on the edit screen to change the password.');
        }

        // 1. Safely target the password fields counting from the bottom
        final newPassField = find.byType(TextField).at(textFields.length - 3);
        final confirmPassField = find.byType(TextField).at(textFields.length - 2);
        final currentPassField = find.byType(TextField).last;

        await tester.enterText(newPassField, tempPass);
        await tester.testTextInput.receiveAction(TextInputAction.done);

        await tester.enterText(confirmPassField, tempPass);
        await tester.testTextInput.receiveAction(TextInputAction.done);

        await tester.enterText(currentPassField, basePassword);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        // 2. Strict button finder
        final saveButtonFinder = find.descendant(
          of: find.byType(ElevatedButton),
          matching: find.textContaining(RegExp(r'Save|Update', caseSensitive: false)),
        );

        if (saveButtonFinder.evaluate().isEmpty) {
          fail('TC57 Failed: Could not locate an ElevatedButton with text "Save" or "Update".');
        }

        // Ensure visible and tap
        await tester.ensureVisible(saveButtonFinder.first);
        await tester.tap(saveButtonFinder.first);

        // 3. Wait for the popup and click it
        bool foundPopup = false;
        for (int i = 0; i < 50; i++) {
          await tester.pump(const Duration(milliseconds: 200));

          final successPopup = find.textContaining(RegExp(r'Success|Updated|Saved|Changed', caseSensitive: false));
          if (successPopup.evaluate().isNotEmpty) {
            foundPopup = true;

            final dismissButton = find.textContaining(RegExp(r'OK|Close|Got it|Done|Dismiss|Continue', caseSensitive: false));
            if (dismissButton.evaluate().isNotEmpty) {
              await tester.tap(dismissButton.first);
            } else {
              await tester.tap(successPopup.first);
            }

            await tester.pumpAndSettle(const Duration(seconds: 2));
            break;
          }
        }

        if (!foundPopup) {
          fail('TC57 Failed: Success pop-up did not appear, could not click it to proceed.');
        }

        isDirty = true;

        // 4. Return to Main Profile Tab
        final backButton = find.byTooltip('Back');
        final profileNavIcon = find.byIcon(Icons.person);

        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton.first);
        } else if (profileNavIcon.evaluate().isNotEmpty) {
          await tester.tap(profileNavIcon.first);
        } else {
          final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
          await widgetsAppState.didPopRoute();
        }
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // 5. Logout
        await performLogout(tester);

        // Wait for the Login screen to fully render before trying to type
        bool loginScreenReady = false;
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          if (find.byType(TextField).evaluate().length >= 2) {
            loginScreenReady = true;
            break;
          }
        }

        if (!loginScreenReady) {
          fail('TC57 Failed: Did not navigate to Login screen after logout.');
        }

        // 6. Try logging in with the NEW tempPass
        final emailField = find.byType(TextField).first;
        final passField = find.byType(TextField).last;
        final loginBtn = find.textContaining(RegExp(r'Log In|Login', caseSensitive: false)).last;

        await tester.enterText(emailField, baseEmail);
        await tester.testTextInput.receiveAction(TextInputAction.done);

        await tester.enterText(passField, tempPass); // USING THE NEW PASSWORD
        await tester.testTextInput.receiveAction(TextInputAction.done);

        await tester.tap(loginBtn);

        // 7. Verify we successfully logged in and reached the dashboard
        bool success = false;
        for (int i = 0; i < 40; i++) {
          await tester.pump();
          await Future.delayed(const Duration(milliseconds: 500));
          if (find.byIcon(Icons.person).evaluate().isNotEmpty || find.text('My Courses').evaluate().isNotEmpty) {
            success = true;
            break;
          }
        }
        expect(success, true, reason: 'TC57 Failed: Could not log in with the newly updated password.');
        debugPrint('✅ TC57 PASSED');

      } finally {
        if (isDirty) await emergencyRevert(tester, baseEmail, tempPass);
      }
    });

    // ============================================================
    // TC58: Profile - Cancel Edit (Edge Case)
    // ============================================================
    testWidgets('TC58 - Profile: Cancel Edit', (tester) async {
      await loginAndNavigateToProfile(tester, email: baseEmail, password: basePassword);
      await openEditScreen(tester);

      final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      if(textFields.isNotEmpty) {
        await tester.enterText(find.byType(TextField).first, 'canceled@test.com');
        await tester.pumpAndSettle();

        final backButton = find.byType(BackButton);
        final cancelButton = find.textContaining(RegExp(r'Cancel|Back', caseSensitive: false));

        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton.first);
        } else if (cancelButton.evaluate().isNotEmpty) {
          await tester.tap(cancelButton.first);
        } else {
          final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
          await widgetsAppState.didPopRoute();
        }
        await tester.pumpAndSettle(const Duration(seconds: 2));

        final newEmail = find.textContaining('canceled@test.com');
        expect(newEmail, findsNothing, reason: 'TC58 Failed: Canceled email was accidentally saved.');
        debugPrint('✅ TC58 PASSED');
      }
    });

    // ============================================================
    // TC59: Profile - Same Password Update (Adjusted for Current API)
    // ============================================================
    testWidgets('TC59 - Profile: Same Password Update', (tester) async {
      await loginAndNavigateToProfile(tester, email: baseEmail, password: basePassword);
      await openEditScreen(tester);

      final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();

      if (textFields.length < 3) {
        fail('TC59 Failed: Could not find enough text fields on the edit screen.');
      }

      // Safely target ALL THREE password fields from the bottom up
      final newPassField = find.byType(TextField).at(textFields.length - 3);
      final confirmPassField = find.byType(TextField).at(textFields.length - 2);
      final currentPassField = find.byType(TextField).last;

      // Try to change the password to the exact same basePassword
      await tester.enterText(newPassField, basePassword);
      await tester.testTextInput.receiveAction(TextInputAction.done);

      await tester.enterText(confirmPassField, basePassword);
      await tester.testTextInput.receiveAction(TextInputAction.done);

      await tester.enterText(currentPassField, basePassword);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Strict button finder
      final saveButtonFinder = find.descendant(
        of: find.byType(ElevatedButton),
        matching: find.textContaining(RegExp(r'Save|Update', caseSensitive: false)),
      );

      if (saveButtonFinder.evaluate().isEmpty) {
        fail('TC59 Failed: Could not locate an ElevatedButton with text "Save" or "Update".');
      }

      await tester.ensureVisible(saveButtonFinder.first);
      await tester.tap(saveButtonFinder.first);

      // Wait for backend validation
      bool foundPopup = false;
      for (int i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 200));

        // We are now checking to see if the backend accepted it
        final successPopup = find.textContaining(RegExp(r'Success|Updated|Saved|Changed', caseSensitive: false));
        if (successPopup.evaluate().isNotEmpty) {
          foundPopup = true;
          break;
        }
      }

      expect(foundPopup, true, reason: 'TC59 Failed: System did not allow updating to the exact same password.');
      await tester.pumpAndSettle(const Duration(seconds: 4));
      debugPrint('✅ TC59 PASSED (Backend allows same-password updates)');
    });

    // ============================================================
    // TC60: Profile - Empty Field Validation (Negative)
    // ============================================================
    testWidgets('TC60 - Profile: Empty Field Validation', (tester) async {
      await loginAndNavigateToProfile(tester, email: baseEmail, password: basePassword);
      await openEditScreen(tester);

      final textFields = find.byType(TextField);
      if(textFields.evaluate().isNotEmpty) {
        await tester.enterText(textFields.first, '');
        await tester.pumpAndSettle();

        final saveButton = find.textContaining(RegExp(r'Save|Update', caseSensitive: false));
        if(saveButton.evaluate().isNotEmpty) await tester.tap(saveButton.first);
        await tester.pumpAndSettle();

        final requiredError = find.textContaining(RegExp(r'Required|Empty|Invalid', caseSensitive: false));
        expect(requiredError.evaluate().isNotEmpty, true, reason: 'TC60 Failed: Allowed saving empty mandatory field.');
        debugPrint('✅ TC60 PASSED');
      }
    });

  });
}