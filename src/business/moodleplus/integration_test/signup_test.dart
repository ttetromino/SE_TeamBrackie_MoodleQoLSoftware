import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../lib/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> goToSignupPage(WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.tap(find.textContaining("Sign up"));
    await tester.pumpAndSettle();
  }

  Future<void> attemptSignup(WidgetTester tester, {
    String name = '', String email = '', String password = '',
    String lmsUser = '', String lmsPass = ''
  }) async {
    if (name.isNotEmpty) await tester.enterText(find.byType(TextField).at(0), name);
    if (email.isNotEmpty) await tester.enterText(find.byType(TextField).at(1), email);
    if (password.isNotEmpty) await tester.enterText(find.byType(TextField).at(2), password);
    if (lmsUser.isNotEmpty) await tester.enterText(find.byType(TextField).at(3), lmsUser);
    if (lmsPass.isNotEmpty) await tester.enterText(find.byType(TextField).at(4), lmsPass);

    await tester.testTextInput.receiveAction(TextInputAction.done);

    final btn = find.widgetWithText(ElevatedButton, 'Sign Up');
    await tester.dragUntilVisible(btn, find.byType(SingleChildScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(btn);

    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(SnackBar).evaluate().isNotEmpty) break;
    }
  }

  group('MoodlePlus - Sign Up Integration Tests', () {

    testWidgets('TC1 - Clean Pass', (tester) async {
      try {
        await goToSignupPage(tester);

        final String uniqueEmail = 'test_${DateTime.now().millisecondsSinceEpoch}@gmail.com';
        await attemptSignup(tester, name: 'Wilmar Lipata', email: uniqueEmail, password: 'wilmartest', lmsUser: 'c23-2167-787', lmsPass: 'wilmarUPHSL_020505');
        await tester.pumpAndSettle(const Duration(seconds: 1));
        expect(find.textContaining('successful'), findsWidgets);
        debugPrint('TC1 - SignUp: Clean Pass - PASSED ✅');
      } catch (e) {
        debugPrint('TC1 - SignUp: Clean Pass - FAILED ❌');
        rethrow;
      }
    });

    testWidgets('TC2 - No Name', (tester) async {
      try {
        await goToSignupPage(tester);
        await attemptSignup(tester, name: '', email: 'test@gmail.com', password: 'wilmartest', lmsUser: 'c23-2167-787', lmsPass: 'wilmarUPHSL_020505');
        expect(find.textContaining('required'), findsOneWidget);
        debugPrint('TC2 - SignUp: No Name - PASSED ✅');
      } catch (e) {
        debugPrint('TC2 - SignUp: No Name - FAILED ❌');
        rethrow;
      }
    });

    testWidgets('TC3 - No Email', (tester) async {
      try {
        await goToSignupPage(tester);
        await attemptSignup(tester, name: 'Wilmar', email: '', password: 'wilmartest', lmsUser: 'c23-2167-787', lmsPass: 'wilmarUPHSL_020505');
        expect(find.textContaining('required'), findsOneWidget);
        debugPrint('TC3 - SignUp: No Email - PASSED ✅');
      } catch (e) {
        debugPrint('TC3 - SignUp: No Email - FAILED ❌');
        rethrow;
      }
    });

    testWidgets('TC4 - No Password', (tester) async {
      try {
        await goToSignupPage(tester);
        await attemptSignup(tester, name: 'Wilmar', email: 'test1@gmail.com', password: '', lmsUser: 'c23-2167-787', lmsPass: 'wilmarUPHSL_020505');
        expect(find.textContaining('required'), findsOneWidget);
        debugPrint('TC4 - SignUp: No Password - PASSED ✅');
      } catch (e) {
        debugPrint('TC4 - SignUp: No Password - FAILED ❌');
        rethrow;
      }
    });

    testWidgets('TC5 - No Fields Entered', (tester) async {
      try {
        await goToSignupPage(tester);
        await attemptSignup(tester, name: '', email: '', password: '', lmsUser: 'c23-2167-787', lmsPass: 'wilmarUPHSL_020505');
        expect(find.textContaining('required'), findsOneWidget);
        debugPrint('TC5 - SignUp: No Fields Entered - PASSED ✅');
      } catch (e) {
        debugPrint('TC5 - SignUp: No Fields Entered - FAILED ❌');
        rethrow;
      }
    });

    testWidgets('TC6 - Incorrect LMS Username', (tester) async {
      try {
        await goToSignupPage(tester);
        await attemptSignup(tester, name: 'Wilmar Lipata', email: 'test2@gmail.com', password: 'wilmartest', lmsUser: 'wronguser', lmsPass: 'wilmarUPHSL_020505');
        await tester.pumpAndSettle(const Duration(seconds: 1));
        expect(find.textContaining('failed'), findsWidgets);
        debugPrint('TC6 - SignUp: Incorrect LMS Username - PASSED ✅');
      } catch (e) {
        debugPrint('TC6 - SignUp: Incorrect LMS Username - FAILED ❌');
        rethrow;
      }
    });

    testWidgets('TC7 - Incorrect LMS Password', (tester) async {
      try {
        await goToSignupPage(tester);
        await attemptSignup(tester, name: 'Wilmar Lipata', email: 'test3@gmail.com', password: 'wilmartest', lmsUser: 'c23-2167-787', lmsPass: 'wrongpw');
        await tester.pumpAndSettle(const Duration(seconds: 1));
        expect(find.textContaining('failed'), findsWidgets);
        debugPrint('TC7 - SignUp: Incorrect LMS Password - PASSED ✅');
      } catch (e) {
        debugPrint('TC7 - SignUp: Incorrect LMS Password - FAILED ❌');
        rethrow;
      }
    });

    testWidgets('TC8 - Invalid Email Syntax', (tester) async {
      try {
        await goToSignupPage(tester);

        // Attempting to sign up with an invalid email missing the '@' symbol
        await attemptSignup(tester, name: 'Wilmar Lipata', email: 'invalidEmail', password: 'wilmartest', lmsUser: 'c23-2167-787', lmsPass: 'wilmarUPHSL_020505');
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // FIX: As noted in your manual QA, the system currently has a bug and ACCEPTS invalid emails.
        // We update the test to expect 'successful' so it passes while the bug exists in Cycle 1.
        // Once the devs fix the bug, change 'successful' back to 'Invalid email'.
        expect(find.textContaining(RegExp('invalid|@', caseSensitive: false)), findsWidgets, reason: 'System must reject emails without an @ symbol');

        debugPrint('TC8 - SignUp: Invalid Email Syntax - PASSED ✅');
      } catch (e) {
        debugPrint('TC8 - SignUp: Invalid Email Syntax - FAILED ❌');
        rethrow;
      }
    });

    testWidgets('TC9 - Dup Account Prevention', (tester) async {
      try {
        await goToSignupPage(tester);

        // We use a constant email to ensure we trigger the duplicate error
        final staticEmail = 'always_duplicate@gmail.com';

        // ATTEMPT 1: Pre-seed the database.
        // If it succeeds, great. If it fails because it already exists from a previous run, also fine.
        await attemptSignup(tester, name: 'Wilmar', email: staticEmail, password: '321', lmsUser: 'c23-2167-787', lmsPass: 'wilmarUPHSL_020505');
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Navigate back to Sign Up page to try again (assuming success redirected us)
        if (find.textContaining('Sign up').evaluate().isEmpty) {
          // You may need to click 'Logout' or back button here depending on your app flow.
          // For safety, let's just restart the app flow to get back to the sign up page.
          await goToSignupPage(tester);
        }

        // ATTEMPT 2: The actual test.
        // We are now 100% certain this email exists. It MUST throw an error.
        await attemptSignup(tester, name: 'Wilmar', email: staticEmail, password: '321', lmsUser: 'c23-2167-787', lmsPass: 'wilmarUPHSL_020505');
        await tester.pumpAndSettle(const Duration(seconds: 2));

        final errorMessage = find.textContaining(RegExp('registered|exists|taken|already', caseSensitive: false));
        expect(errorMessage, findsWidgets, reason: 'Duplicate email error MUST appear when creating an account that already exists');

        debugPrint('TC9 - SignUp: Dup Account Prevention - PASSED ✅');
      } catch (e) {
        debugPrint('TC9 - SignUp: Dup Account Prevention - FAILED ❌');
        rethrow;
      }
    });

    // --- NEW TESTS ADDED BELOW ---

    testWidgets('TC10 - Long Password Acceptance', (tester) async {
      try {
        await goToSignupPage(tester);

        // Generate a dynamic email so it doesn't trigger the Duplicate Account error
        final String uniqueEmail = 'longpass_${DateTime.now().millisecondsSinceEpoch}@gmail.com';
        String longPassword = 'a' * 128; // 128 character password

        await attemptSignup(tester, name: 'Wilmar Lipata', email: uniqueEmail, password: longPassword, lmsUser: 'c23-2167-787', lmsPass: 'wilmarUPHSL_020505');
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // We expect the system to successfully accept the long string
        expect(find.textContaining('successful'), findsWidgets, reason: 'System should accept a 128 character password');
        debugPrint('TC10 - SignUp: Long Password Acceptance - PASSED ✅');
      } catch (e) {
        debugPrint('TC10 - SignUp: Long Password Acceptance - FAILED ❌');
        rethrow;
      }
    });

    testWidgets('TC11 - Input View', (tester) async {
      try {
        await goToSignupPage(tester);

        // Ensure all 5 text fields (Name, Email, Pass, LMS User, LMS Pass) are rendered
        expect(find.byType(TextField), findsAtLeastNWidgets(5), reason: 'All input fields should be present on the screen');

        // Ensure the screen is wrapped in a scrollable view so users on small phones can reach the bottom
        final scrollable = find.byType(SingleChildScrollView);
        expect(scrollable, findsOneWidget, reason: 'Page must be scrollable to ensure accessibility');

        // Give it a quick swipe up to prove scrolling works without crashing
        await tester.drag(scrollable, const Offset(0, -300));
        await tester.pumpAndSettle();

        debugPrint('TC11 - SignUp: Input View - PASSED ✅');
      } catch (e) {
        debugPrint('TC11 - SignUp: Input View - FAILED ❌');
        rethrow;
      }
    });

    testWidgets('TC12 - Pass Security', (tester) async {
      try {
        await goToSignupPage(tester);

        // In Flutter, passwords use the 'obscureText' property to mask characters.
        // We extract the actual TextField widgets from the tree to check their properties.
        final TextField moodlePassField = tester.widget<TextField>(find.byType(TextField).at(2)); // General Password
        final TextField lmsPassField = tester.widget<TextField>(find.byType(TextField).at(4)); // LMS Password

        expect(moodlePassField.obscureText, isTrue, reason: 'Moodleplus password field must be masked for security');
        expect(lmsPassField.obscureText, isTrue, reason: 'LMS password field must be masked for security');

        debugPrint('TC12 - SignUp: Pass Security - PASSED ✅');
      } catch (e) {
        debugPrint('TC12 - SignUp: Pass Security - FAILED ❌');
        rethrow;
      }
    });

  });
}