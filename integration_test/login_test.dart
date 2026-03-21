import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // --- HELPER FUNCTION ---
  // This does the repetitive typing and clicking for us
  Future<void> attemptLogin(WidgetTester tester, String email, String password) async {
    final Finder emailField = find.byType(TextField).at(0);
    final Finder passwordField = find.byType(TextField).at(1);
    final Finder loginButton = find.widgetWithText(ElevatedButton, 'Log In');

    await tester.enterText(emailField, email);
    await tester.enterText(passwordField, password);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.tap(loginButton);
    // Wait for your VS Code backend to respond
    await tester.pumpAndSettle(const Duration(seconds: 3));


  }

  group('Moodle QoL - Login Feature Tests', () {

    // ---------------------------------------------------------
    // TEST CASE 1: Login: Clean Pass
    // ---------------------------------------------------------
    testWidgets('1. Clean Pass - Valid Credentials', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await attemptLogin(tester, 'wilmar.mg.lipata@gmail.com', '123');

      // Verify we reached the homepage
      expect(find.text('MoodlePlus Home'), findsOneWidget);
      print('✅ Case 1 Passed: Clean Pass');
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });

    // ---------------------------------------------------------
    // TEST CASE 2: Login: Long Password
    // ---------------------------------------------------------
    testWidgets('2. Boundary Test - Extremely Long Password', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await attemptLogin(tester, 'along', 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');

      // We check that we did reach the homepage
      expect(find.text('MoodlePlus Home'), findsOneWidget);

      print('✅ Case 2 Passed: Long Password properly handled');
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });

    // ---------------------------------------------------------
    // TEST CASE 3: Login: Logout
    // ---------------------------------------------------------
    testWidgets('3. Flow Test - Login and Logout', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await attemptLogin(tester, 'test@gmail.com', '123');

      // 1. Verify we reached the homepage
      expect(find.text('MoodlePlus Home'), findsOneWidget);

      // 2. Perform the Logout
      final Finder logoutButton = find.byIcon(Icons.logout);
      await tester.tap(logoutButton);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 3. Verify we are back on the Login Page (The large title text)
      expect(find.text('Log In'), findsWidgets);
      print('✅ Case 3 Passed: Successfully logged out');
    });


  });
}