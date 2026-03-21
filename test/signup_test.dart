import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../main.dart' as app;

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
        await attemptSignup(tester, name: 'Wilmar Lipata', email: uniqueEmail, password: '123', lmsUser: 'c23-2167-787', lmsPass: 'wilmarUPHSL_020505');
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
        await attemptSignup(tester, name: '', email: 'test@gmail.com', password: '123', lmsUser: 'c23-2167-787', lmsPass: 'wilmarUPHSL_020505');
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
        await attemptSignup(tester, name: 'Wilmar', email: '', password: '123', lmsUser: 'c23-2167-787', lmsPass: 'wilmarUPHSL_020505');
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
        await attemptSignup(tester, name: 'Wilmar Lipata', email: 'test2@gmail.com', password: '123', lmsUser: 'wronguser', lmsPass: 'wilmarUPHSL_020505');
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
        await attemptSignup(tester, name: 'Wilmar Lipata', email: 'test3@gmail.com', password: '123', lmsUser: 'c23-2167-787', lmsPass: 'wrongpw');
        await tester.pumpAndSettle(const Duration(seconds: 1));
        expect(find.textContaining('failed'), findsWidgets);
        debugPrint('TC7 - SignUp: Incorrect LMS Password - PASSED ✅');
      } catch (e) {
        debugPrint('TC7 - SignUp: Incorrect LMS Password - FAILED ❌');
        rethrow;
      }
    });

    testWidgets('TC8 - SignUp: Invalid Email Syntax', (tester) async {
      try {
        await goToSignupPage(tester);
        await attemptSignup(tester, name: 'Wilmar Lipata', email: 'invalidEmail', password: '123', lmsUser: 'c23-2167-787', lmsPass: 'wilmarUPHSL_020505');
        await tester.pumpAndSettle();
        expect(find.textContaining('Invalid email'), findsOneWidget);
        expect(find.text('Create Account'), findsOneWidget);
        debugPrint('TC8 - SignUp: Invalid Email Syntax - PASSED ✅');
      } catch (e) {
        debugPrint('TC8 - SignUp: Invalid Email Syntax - FAILED ❌');
        rethrow;
      }
    });

    testWidgets('TC9 - Dup Account Prevention', (tester) async {
      try {
        await goToSignupPage(tester);
        await attemptSignup(tester, name: 'Wilmar', email: 'test@gmail.com', password: '321', lmsUser: 'c23-2167-787', lmsPass: 'wilmarUPHSL_020505');
        await tester.pumpAndSettle(const Duration(seconds: 2));
        expect(find.textContaining('registered'), findsWidgets);
        debugPrint('TC9 - SignUp: Dup Account Prevention - PASSED ✅');
      } catch (e) {
        debugPrint('TC9 - SignUp: Dup Account Prevention - FAILED ❌');
        rethrow;
      }
    });
  });
}