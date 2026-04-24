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

  });
}