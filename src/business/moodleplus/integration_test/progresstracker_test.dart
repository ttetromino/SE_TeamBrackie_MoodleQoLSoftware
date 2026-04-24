import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../lib/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Progress Tracker Integration Tests', () {

    // Helper to get us logged in and on the My Courses tab
    Future<void> loginAndNavigateToMyCourses(WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      final emailField = find.byType(TextField).at(0);
      final passwordField = find.byType(TextField).at(1);

      await tester.enterText(emailField, 'wilmartest1@gmail.com');
      await tester.enterText(passwordField, '123');

      // Tap login and wait for the Dashboard/Home to load
      await tester.tap(find.widgetWithText(ElevatedButton, 'Log In'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Navigate to My Courses
      final myCoursesTab = find.text('My Courses');
      expect(myCoursesTab, findsOneWidget, reason: "Could not find 'My Courses' tab.");
      await tester.tap(myCoursesTab);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    testWidgets('TC35 - Progress Tracker: Happy Path (Instant UI Sync)', (tester) async {
      try {
        await loginAndNavigateToMyCourses(tester);

        // 1. Verify we aren't already at 100% before doing anything
        expect(find.text('100%'), findsNothing,
            reason: "Setup Error: Tracker is already at 100% before test started.");

        // 2. NEW STEP: Navigate to the Backlog to find the tasks
        final backlogTab = find.text('Backlog');
        expect(backlogTab, findsOneWidget, reason: "Could not find 'Backlog' tab to navigate to.");
        await tester.tap(backlogTab);

        // Wait for backlog to load
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // 3. Complete the task in the Backlog
        final taskCheckboxes = find.byType(Checkbox);
        expect(taskCheckboxes, findsWidgets,
            reason: "DEFECT/SETUP: No pending tasks (checkboxes) found in the Backlog.");

        await tester.tap(taskCheckboxes.first);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // 4. NEW STEP: Navigate back to My Courses to check the Progress Tracker
        await tester.tap(find.text('My Courses'));
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // 5. Verify the updates on the Progress Tracker
        expect(find.text('100%'), findsOneWidget,
            reason: "DEFECT: Percentage did not sync to 100% after completing task in backlog.");

        // Check that the counter reset to exactly 0
        final zeroCounter = find.textContaining(RegExp(r'\b0\b'));
        expect(zeroCounter, findsWidgets,
            reason: "DEFECT: The 'Quizzes Left' counter did not reset to 0.");

        // Check that the visual bar is full (1.0)
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

    testWidgets('TC36 - Progress: Integer Display', (tester) async {
      try {
        await loginAndNavigateToMyCourses(tester);

        // Find the text widget that contains the percentage sign
        final percentageTextFinder = find.textContaining('%');
        expect(percentageTextFinder, findsWidgets, reason: "No percentage text found on the tracker.");

        // Grab the actual string (e.g., "33%")
        final textWidget = tester.widget<Text>(percentageTextFinder.first);
        final progressString = textWidget.data!;

        // Verify it does NOT contain a decimal point
        expect(progressString.contains('.'), isFalse,
            reason: "DEFECT: Progress is displaying as a decimal ($progressString) instead of a rounded integer.");

        debugPrint('TC36 - Progress: Integer Display - PASSED ✅');
      } catch (e) {
        debugPrint('TC36 - Progress: Integer Display - FAILED ❌');
        rethrow;
      }
    });

    testWidgets('TC39 - Progress: Task Completion (Counter Update)', (tester) async {
      try {
        await loginAndNavigateToMyCourses(tester);

        // Find a pending task checkbox
        final pendingTask = find.byType(Checkbox).first;
        expect(pendingTask, findsOneWidget, reason: "No pending tasks found to complete.");

        // 1. Get the initial state (Before click)
        // We look for the word "Quiz" or "Assignment" to find the counter
        final counterFinder = find.textContaining(RegExp(r'(Quiz|Assignment)'));
        final initialText = tester.widget<Text>(counterFinder.first).data!;

        // 2. Click the task to complete it
        await tester.tap(pendingTask);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // 3. Get the new state (After click)
        final updatedText = tester.widget<Text>(counterFinder.first).data!;

        // Verify the text actually changed
        expect(initialText != updatedText, isTrue,
            reason: "DEFECT: The counter string ($initialText) did not update after completing a task.");

        debugPrint('TC39 - Progress: Task Completion - PASSED ✅');
      } catch (e) {
        debugPrint('TC39 - Progress: Task Completion - FAILED ❌');
        rethrow;
      }
    });

    testWidgets('TC42 - Progress: Zero State', (tester) async {
      try {
        // QA Note: For this to truly pass, you must log in with an account that has 0 progress.
        await loginAndNavigateToMyCourses(tester);

        // 1. Check for exactly "0%"
        final zeroPercentText = find.text('0%');
        expect(zeroPercentText, findsOneWidget,
            reason: "DEFECT: Zero state percentage is not displaying as exactly '0%'.");

        // 2. Check the Progress Bar value is exactly 0.0
        final progressBar = find.byType(LinearProgressIndicator);
        if (progressBar.evaluate().isNotEmpty) {
          final indicator = tester.widget<LinearProgressIndicator>(progressBar.first);
          expect(indicator.value, equals(0.0),
              reason: "DEFECT: The Progress Bar still has color/width filled on a 0% state.");
        }

        debugPrint('TC42 - Progress: Zero State - PASSED ✅');
      } catch (e) {
        debugPrint('TC42 - Progress: Zero State - FAILED ❌');
        rethrow;
      }
    });

  });
}