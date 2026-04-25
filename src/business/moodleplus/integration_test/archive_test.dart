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

    testWidgets('TC63 - Archive: Modal Check', (tester) async {
      try {
        await loginToDashboard(tester);

        // Tap the first archive icon
        final archiveIcon = find.byIcon(Icons.archive);
        expect(archiveIcon, findsWidgets, reason: "Setup: No courses to archive.");
        await tester.tap(archiveIcon.first);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // Verify Modal appears with Confirmation text
        final confirmBtn = find.textContaining(RegExp(r'Confirm|Archive|Yes', caseSensitive: false));
        expect(confirmBtn, findsOneWidget, reason: "TC63 FAILED: Confirmation modal did not appear.");

        debugPrint('TC63 - Archive: Modal Check - PASSED ✅');
      } catch (e) {
        debugPrint('TC63 - Archive: Modal Check - FAILED ❌');
        rethrow;
      }
    });

    testWidgets('TC71 - Archive: Cancel Modal', (tester) async {
      try {
        await loginToDashboard(tester);

        // Open the modal
        await tester.tap(find.byIcon(Icons.archive).first);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // Tap Cancel
        final cancelBtn = find.textContaining(RegExp(r'Cancel', caseSensitive: false));
        expect(cancelBtn, findsOneWidget, reason: "Setup: Modal did not appear or missing Cancel button.");

        await tester.tap(cancelBtn);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // Verify the modal is gone
        expect(cancelBtn, findsNothing, reason: "TC71 FAILED: Modal did not close after tapping Cancel.");

        debugPrint('TC71 - Archive: Cancel Modal - PASSED ✅');
      } catch (e) {
        debugPrint('TC71 - Archive: Cancel Modal - FAILED ❌');
        rethrow;
      }
    });

    testWidgets('TC65 - Archive: Cache Exclusion', (tester) async {
      try {
        await loginToDashboard(tester);

        final archiveIcons = find.byIcon(Icons.archive);
        expect(archiveIcons, findsWidgets, reason: "Setup: No courses available to archive.");

        // Count how many courses there are initially
        final initialCount = archiveIcons.evaluate().length;

        // Archive the first one
        await tester.tap(archiveIcons.first);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        final confirmBtn = find.textContaining(RegExp(r'Confirm|Archive|Yes', caseSensitive: false));
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Verify the count dropped by 1, meaning it was excluded from the active view
        final newCount = find.byIcon(Icons.archive).evaluate().length;
        expect(newCount, lessThan(initialCount), reason: "TC65 FAILED: Course remained in active view after archiving.");

        debugPrint('TC65 - Archive: Cache Exclusion - PASSED ✅');
      } catch (e) {
        debugPrint('TC65 - Archive: Cache Exclusion - FAILED ❌');
        rethrow;
      }
    });

    testWidgets('TC67 - Archive: Legacy Label', (tester) async {
      try {
        await loginToDashboard(tester);

        // Go to Archive Tab
        final archiveTab = find.textContaining(RegExp(r'Archive', caseSensitive: false));
        await tester.tap(archiveTab.last);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Look for the visual legacy label on the items
        final legacyLabel = find.textContaining(RegExp(r'Legacy|Archived', caseSensitive: false));
        expect(legacyLabel, findsWidgets, reason: "TC67 FAILED: Archived items are missing the 'Legacy' visual tag.");

        debugPrint('TC67 - Archive: Legacy Label - PASSED ✅');
      } catch (e) {
        debugPrint('TC67 - Archive: Legacy Label - FAILED ❌');
        rethrow;
      }
    });

    testWidgets('TC73 - Archive: Empty State', (tester) async {
      try {
        await loginToDashboard(tester);

        // Navigate directly to Archive View
        final archiveTab = find.textContaining(RegExp(r'Archive', caseSensitive: false));
        await tester.tap(archiveTab.last);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Look for empty state placeholder text
        final emptyState = find.textContaining(RegExp(r'No.*Archived', caseSensitive: false));

        expect(emptyState, findsOneWidget,
            reason: "TC73 FAILED: Empty state text not found. The account likely has archived items in it already.");

        debugPrint('TC73 - Archive: Empty State - PASSED ✅');
      } catch (e) {
        debugPrint('TC73 - Archive: Empty State - FAILED ❌');
        rethrow;
      }
    });

  });
}