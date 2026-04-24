import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../lib/main.dart' as app;
import '../lib/backlog_item_card.dart'; // Add this line!

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Helper function: Steps 1 through 5 (Login and Navigate)
  Future<void> loginAndNavigateToBacklog(WidgetTester tester) async {
    // 1. Open Moodleplus
    app.main();
    await tester.pumpAndSettle();

    // 2. Enter verified email
    await tester.enterText(find.byType(TextField).at(0), 'wilmartest1@gmail.com');

    // 3. Enter verified password
    await tester.enterText(find.byType(TextField).at(1), '123');
    await tester.testTextInput.receiveAction(TextInputAction.done);

    // 4. Click on the Log In button
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log In'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 5. Navigate to Backlog Page
    // Assuming 'Backlog' is a tab in a BottomNavigationBar or a Drawer item
    await tester.tap(find.text('Backlog'));
    await tester.pumpAndSettle();
  }

  group('MoodlePlus - Backlog Integration Tests', () {

    testWidgets('TC22 - Backlog: Happy Path (Toggle & Filter)', (tester) async {
      try {
        // Executes Steps 1-5
        await loginAndNavigateToBacklog(tester);

        // 6. Click on the Toggle View Button twice
        // The developer used view_module (compact) and view_agenda (expanded) icons
        final viewToggleBtn = find.byIcon(Icons.view_module);

        if (viewToggleBtn.evaluate().isNotEmpty) {
          // First click: Switches from Compact to Expanded
          await tester.tap(viewToggleBtn);
          await tester.pumpAndSettle(const Duration(milliseconds: 500));

          // The icon changed! Now we must find the new icon to click it again
          final viewToggleBtnExpanded = find.byIcon(Icons.view_agenda);

          // Second click: Switches back from Expanded to Compact
          await tester.tap(viewToggleBtnExpanded);
          await tester.pumpAndSettle(const Duration(milliseconds: 500));
        }

        // 7. Click on Filter button
        await tester.tap(find.byIcon(Icons.filter_list));
        await tester.pumpAndSettle();

        // 8. Click Sort By as "Deadline"
        await tester.tap(find.text('Deadline'));
        await tester.pumpAndSettle();

        // 9. Click Priority as "Low"
        await tester.tap(find.text('Low'));
        await tester.pumpAndSettle();

        // 10. Click Apply Filters
        await tester.tap(find.widgetWithText(ElevatedButton, 'Apply Filters'));
        await tester.pumpAndSettle();

        // 11. Verify subjects are listed according to the filter
        // Since we don't know the exact database items, we check that the list is visible
        // and that the filter drawer has successfully closed.
        expect(find.text('Apply Filters'), findsNothing); // Ensures drawer closed
        expect(find.byType(BacklogItemCard), findsWidgets); // Ensures the list loads tasks correctly

        debugPrint('TC22 - Backlog: Happy Path - PASSED ✅');
      } catch (e) {
        debugPrint('TC22 - Backlog: Happy Path - FAILED ❌');
        rethrow;
      }
    });

    testWidgets('TC23 - Backlog: Layout Toggle (Compact vs Expanded)', (tester) async {
      try {
        // We reuse the same helper function from TC22 to get to the Backlog
        await loginAndNavigateToBacklog(tester);

        // 1. Verify the app starts in Compact mode (Icon should be view_module)
        final viewToggleBtn = find.byIcon(Icons.view_module);
        expect(viewToggleBtn, findsOneWidget, reason: "Initial layout should be compact");

        // 2. First Click: Switch to Expanded view
        await tester.tap(viewToggleBtn);
        await tester.pumpAndSettle(const Duration(milliseconds: 500));

        // 3. Verify it changed to Expanded view (Icon should now be view_agenda)
        final viewToggleBtnExpanded = find.byIcon(Icons.view_agenda);
        expect(viewToggleBtnExpanded, findsOneWidget, reason: "Layout failed to switch to expanded");

        // 4. Second Click: Switch back to Compact view
        await tester.tap(viewToggleBtnExpanded);
        await tester.pumpAndSettle(const Duration(milliseconds: 500));

        // 5. Verify it successfully returned to Compact view
        expect(find.byIcon(Icons.view_module), findsOneWidget, reason: "Layout failed to return to compact");

        debugPrint('TC23 - Backlog: Layout Toggle - PASSED ✅');
      } catch (e) {
        debugPrint('TC23 - Backlog: Layout Toggle - FAILED ❌');
        rethrow;
      }
    });

    testWidgets('TC24 - Backlog: View Persistence (LocalStorage)', (tester) async {
      try {
        // 1. Initial login and navigate to Backlog
        await loginAndNavigateToBacklog(tester);

        // 2. The app defaults to compact. Let's switch it to Expanded.
        final compactIcon = find.byIcon(Icons.view_module);
        if (compactIcon.evaluate().isNotEmpty) {
          await tester.tap(compactIcon);
          await tester.pumpAndSettle(const Duration(milliseconds: 500));
        }

        // 3. Verify it is currently in Expanded mode (view_agenda)
        expect(find.byIcon(Icons.view_agenda), findsOneWidget,
            reason: "Failed to switch to expanded view before logout");

        // ---------------------------------------------------------
        // 4. LOG OUT FLOW
        // Step 4a: Tap the button that opens the logout dialog
        // (QA Note: Change Icons.logout to whatever icon/button actually opens your menu!)
        await tester.tap(find.byIcon(Icons.logout));
        await tester.pumpAndSettle();

        // Step 4b: Tap the 'Logout' button inside the confirmation dialog you just showed me
        await tester.tap(find.widgetWithText(ElevatedButton, 'Logout'));
        await tester.pumpAndSettle(const Duration(seconds: 1));
        // ---------------------------------------------------------

        // 5. Log back in
        await tester.enterText(find.byType(TextField).at(0), 'wilmartest1@gmail.com');
        await tester.enterText(find.byType(TextField).at(1), '123');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.tap(find.widgetWithText(ElevatedButton, 'Log In'));
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // 6. Navigate back to the Backlog Page
        await tester.tap(find.text('Backlog'));
        await tester.pumpAndSettle();

        // 7. Verify layout persisted! It should STILL be Expanded (view_agenda)
        expect(find.byIcon(Icons.view_agenda), findsOneWidget,
            reason: "Layout preference did not persist after logout");

        debugPrint('TC24 - Backlog: View Persistence - PASSED ✅');
      } catch (e) {
        debugPrint('TC24 - Backlog: View Persistence - FAILED ❌');
        rethrow;
      }
    });

    testWidgets('TC25 - Backlog: Compact Content (AC Verification)', (tester) async {
      try {
        //  1. Initial login and navigate to Backlog
        await loginAndNavigateToBacklog(tester);

        // 2. Ensure we are starting in Compact view (Icon should be view_module)
        expect(find.byIcon(Icons.view_module), findsOneWidget,
            reason: "App did not default to compact view");

        // 3. Ensure at least one task card is on the screen so we can inspect it
        final hasList = find.byType(CustomScrollView).evaluate().isNotEmpty;
        expect(hasList, isTrue, reason: "No tasks loaded to inspect.");

        // 4. AC STRICT CHECK: The Timer icon should NOT exist in Compact view
        // In Flutter tests, findsNothing is how we verify an element is successfully hidden
        expect(find.byIcon(Icons.timer), findsNothing,
            reason: "DEFECT: Timer icon is visible in Compact view, violating AC.");

        debugPrint('TC25 - Backlog: Compact Content - PASSED ✅');
      } catch (e) {
        debugPrint('TC25 - Backlog: Compact Content - FAILED ❌');
        rethrow;
      }
    });

    testWidgets('TC26 - Backlog: Filter Drawer Accessibility', (tester) async {
      try {
        // 1. Initial login and navigate to Backlog
        await loginAndNavigateToBacklog(tester);

        // 2. Find and tap the Filter button
        // QA Note: If your filter button is an icon instead of text, change this to:
        // final filterBtn = find.byIcon(Icons.filter_list);
        final filterBtn = find.text('Filter');

        expect(filterBtn, findsOneWidget, reason: "Filter button is missing from the screen");
        await tester.tap(filterBtn);

        // Wait for the drawer sliding animation to finish
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // 3. Verify the Drawer opened by checking for standard Filter UI elements
        // Looking for Radio buttons (used for single-select like "Sort By")
        expect(find.byType(Radio<dynamic>), findsWidgets,
            reason: "Drawer did not open or is missing Radio options");

        // Looking for Checkboxes (used for multi-select like "Priority" or "Status")
        expect(find.byType(Checkbox), findsWidgets,
            reason: "Drawer did not open or is missing Multi-select checkbox options");

        debugPrint('TC26 - Backlog: Filter Drawer Accessibility - PASSED ✅');
      } catch (e) {
        debugPrint('TC26 - Backlog: Filter Drawer Accessibility - FAILED ❌');
        rethrow;
      }
    });

    testWidgets('TC27 - Backlog: Radio Filter (By Course)', (tester) async {
      try {
        // 1. Initial login and navigate to Backlog
        await loginAndNavigateToBacklog(tester);

        // 2. Open the Filter Drawer
        await tester.tap(find.text('Filter'));
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // 3. Find and select the "By Course" radio option
        final byCourseOption = find.text('By Course');
        expect(byCourseOption, findsOneWidget,
            reason: "'By Course' option is missing from the filter drawer");

        await tester.tap(byCourseOption);
        await tester.pumpAndSettle(const Duration(milliseconds: 500));

        // 4. Click Apply Filters
        final applyBtn = find.text('Apply Filters');
        expect(applyBtn, findsOneWidget, reason: "'Apply Filters' button is missing");
        await tester.tap(applyBtn);

        // Wait for the drawer to close and the list to re-render
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // 5. Verify the screen actually rendered a list of items after filtering
        // We check for CustomScrollView because that is what your developer used for the list
        expect(find.byType(CustomScrollView), findsOneWidget,
            reason: "Task list failed to render after applying the 'By Course' filter");

        debugPrint('TC27 - Backlog: Radio Filter - PASSED ✅');
      } catch (e) {
        debugPrint('TC27 - Backlog: Radio Filter - FAILED ❌');
        rethrow;
      }
    });

    testWidgets('TC28 - Backlog: Timer Format (HH:MM)', (tester) async {
      try {
        // 1. Initial login and navigate to Backlog
        await loginAndNavigateToBacklog(tester);

        // 2. Ensure we are in Expanded view (where the timer should be visible)
        final expandedIcon = find.byIcon(Icons.view_agenda);
        if (expandedIcon.evaluate().isEmpty) {
          // If it's not expanded, tap the toggle button to make it expanded
          await tester.tap(find.byIcon(Icons.view_module));
          await tester.pumpAndSettle(const Duration(milliseconds: 500));
        }

        // 3. Verify at least one task card is present
        expect(find.byType(CustomScrollView), findsOneWidget,
            reason: "No tasks loaded to inspect.");

        // 4. Use Regex to verify that at least one widget contains the HH:MM format
        // This regex looks for: 2 digits, a colon, 2 digits (e.g., 02:30 or 12:45)
        final RegExp timeFormatRegExp = RegExp(r'^\d{2}:\d{2}$');

        // Find any Text widget on the screen that matches this exact pattern
        final timerText = find.byWidgetPredicate((widget) {
          if (widget is Text && widget.data != null) {
            return timeFormatRegExp.hasMatch(widget.data!);
          }
          return false;
        });

        // 5. Assert that we found the properly formatted timer
        expect(timerText, findsWidgets,
            reason: "DEFECT: Timer format is incorrect. Could not find text matching HH:MM.");

        debugPrint('TC28 - Backlog: Timer Format - PASSED ✅');
      } catch (e) {
        debugPrint('TC28 - Backlog: Timer Format - FAILED ❌');
        rethrow;
      }
    });

    testWidgets('TC29 - Backlog: Priority Styling (Urgent)', (tester) async {
      try {
        // 1. Initial login and navigate to Backlog
        await loginAndNavigateToBacklog(tester);

        // 2. Wait for the list to load
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // 3. Find a task that is explicitly labeled "Urgent"
        final urgentTaskText = find.textContaining('Urgent', caseSensitive: false);

        // If there are no urgent tasks in the test data, the test can't proceed
        expect(urgentTaskText, findsWidgets,
            reason: "Cannot verify styling: No 'Urgent' tasks loaded in the test data.");

        // 4. Use a custom predicate to search the screen for Red or Orange styling
        // We check Icons, Text, Cards, and Containers for those specific color properties
        final urgentColorFound = find.byWidgetPredicate((widget) {
          // Check if an Icon is red/orange
          if (widget is Icon && (widget.color == Colors.red || widget.color == Colors.orange)) return true;
          // Check if Text is red/orange
          if (widget is Text && (widget.style?.color == Colors.red || widget.style?.color == Colors.orange)) return true;
          // Check if a Container background or border is red/orange
          if (widget is Container && widget.decoration is BoxDecoration) {
            final boxDecoration = widget.decoration as BoxDecoration;
            if (boxDecoration.color == Colors.red || boxDecoration.color == Colors.orange) return true;
            if (boxDecoration.border?.top.color == Colors.red) return true;
          }
          return false;
        });

        // 5. Assert that the styling exists
        expect(urgentColorFound, findsWidgets,
            reason: "DEFECT: 'Urgent' task found, but no Red or Orange styling indicator was detected.");

        debugPrint('TC29 - Backlog: Priority Styling - PASSED ✅');
      } catch (e) {
        debugPrint('TC29 - Backlog: Priority Styling - FAILED ❌');
        rethrow;
      }
    });

    testWidgets('TC30 - Backlog: Expired Deadline (Edge Case)', (tester) async {
      try {
        await loginAndNavigateToBacklog(tester);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // Search the screen for either "00:00" or the word "Overdue"
        final overdueText = find.byWidgetPredicate((widget) {
          if (widget is Text && widget.data != null) {
            final text = widget.data!.toLowerCase();
            return text.contains('00:00') || text.contains('overdue');
          }
          return false;
        });

        expect(overdueText, findsWidgets,
            reason: "Could not find any tasks properly marked as 00:00 or Overdue");

        debugPrint('TC30 - Backlog: Expired Deadline - PASSED ✅');
      } catch (e) {
        debugPrint('TC30 - Backlog: Expired Deadline - FAILED ❌');
        rethrow;
      }
    });

    testWidgets('TC33 - Backlog: Empty List State (Edge Case)', (tester) async {
      try {
        await loginAndNavigateToBacklog(tester);

        // 1. Open Filter Drawer
        await tester.tap(find.text('Filter'));
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // 2. Select a highly restrictive filter (Assuming there is a "Completed" option)
        // QA Note: Change 'Completed' to whatever filter guarantees 0 results
        final filterOption = find.text('Completed');
        if (filterOption.evaluate().isNotEmpty) {
          await tester.tap(filterOption);
        }

        await tester.tap(find.text('Apply Filters'));
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // 3. Verify the "No tasks found" message appears
        final emptyStateMessage = find.textContaining('No tasks found', caseSensitive: false);
        expect(emptyStateMessage, findsOneWidget,
            reason: "Empty state message did not appear when 0 tasks matched the filter");

        debugPrint('TC33 - Backlog: Empty List State - PASSED ✅');
      } catch (e) {
        debugPrint('TC33 - Backlog: Empty List State - FAILED ❌');
        rethrow;
      }
    });

  });
}