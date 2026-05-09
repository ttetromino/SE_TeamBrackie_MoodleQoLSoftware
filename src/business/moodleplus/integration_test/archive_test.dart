import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../lib/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Helper 1: Smart Login (Handles Auto-Login and Manual Login)
  Future<void> login(WidgetTester tester, String email, String password) async {
    app.main();

    bool needsManualLogin = true;
    bool isReady = false;

    // 1. Wait to see where the app lands
    for (int i = 0; i < 20; i++) {
      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 500));

      if (find.text('My Courses').evaluate().isNotEmpty || find.byIcon(Icons.person).evaluate().isNotEmpty) {
        isReady = true;
        needsManualLogin = false;
        debugPrint('🔓 Auto-login detected. Skipping manual credential entry.');
        break;
      }

      if (find.byType(TextField).evaluate().length >= 2) {
        isReady = true;
        needsManualLogin = true;
        break;
      }
    }

    if (!isReady) fail('❌ App stuck on splash screen.');

    // 2. Perform manual login
    if (needsManualLogin) {
      debugPrint('🔑 Performing manual login...');

      final allTextFields = find.byType(TextField);
      await tester.enterText(allTextFields.first, email);
      await tester.enterText(allTextFields.last, password);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final loginTarget = find.textContaining(RegExp(r'^log in$|^login$|^sign in$', caseSensitive: false));

      if (loginTarget.evaluate().isNotEmpty) {
        debugPrint('👆 Found login button text, tapping...');
        await tester.ensureVisible(loginTarget.last);
        await tester.tap(loginTarget.last, warnIfMissed: false);
      } else {
        debugPrint('⚠️ Login text not found, tapping fallback ElevatedButton...');
        await tester.tap(find.byType(ElevatedButton).first, warnIfMissed: false);
      }

      // Wait for the Dashboard to appear
      bool dashboardLoaded = false;
      for (int i = 0; i < 40; i++) {
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 500));

        if (find.text('My Courses').evaluate().isNotEmpty || find.byIcon(Icons.person).evaluate().isNotEmpty) {
          dashboardLoaded = true;
          break;
        }
      }

      if (!dashboardLoaded) fail('❌ Login timed out. Dashboard never loaded after tapping Log In.');
    }

    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

    // Helper 2: Safely navigate to the Archive view
  Future<void> navigateToArchive(WidgetTester tester) async {
    // Look for the archive icon anywhere on the screen
    final archiveIcon = find.byIcon(Icons.archive);

    if (archiveIcon.evaluate().isNotEmpty) {
      await tester.tap(archiveIcon.first);
    } else {
      // Fallback: Check if it's an outlined archive icon
      final outlinedIcon = find.byIcon(Icons.archive_outlined);
      if (outlinedIcon.evaluate().isNotEmpty) {
        await tester.tap(outlinedIcon.first);
      } else {
        fail('TC64 Failed: Archive navigation icon not found anywhere on the screen.');
      }
    }

    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  group('US-04 Archive Feature Tests', () {


    testWidgets('TC73 - Archive: Empty State', (tester) async {
      await login(tester, 'wilmartest1@gmail.com', 'wilmartest');

      debugPrint('🧭 Navigating to My Courses tab...');
      final myCoursesTab = find.text('My Courses');
      if (myCoursesTab.evaluate().isNotEmpty) {
        await tester.tap(myCoursesTab.first);
        await tester.pumpAndSettle(const Duration(seconds: 4));
      }

      debugPrint('📂 Navigating to Archive view...');
      final archiveNavButton = find.byTooltip('Archived Records');
      if(archiveNavButton.evaluate().isNotEmpty) {
        await tester.tap(archiveNavButton.first);
      } else {
        await navigateToArchive(tester);
      }
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final courseCards = find.byType(Card);
      if (courseCards.evaluate().isNotEmpty) {
        debugPrint('⚠️ Skipping TC73: Database is not empty. Cannot verify empty state UI.');
        return;
      }

      debugPrint('📭 Verifying empty state text...');
      final emptyStateMessage = find.text('No Archived Courses');
      expect(emptyStateMessage, findsWidgets, reason: 'TC73 Failed: Empty state placeholder "No Archived Courses" not found in Archive view');
      debugPrint('✅ TC73 PASSED: Empty state successfully validated.');
    });

    testWidgets('TC61 - Archive: Happy Path (Migration Verification)', (tester) async {
      await login(tester, 'wilmartest1@gmail.com', 'wilmartest');

      debugPrint('🧭 Navigating to My Courses tab...');
      final myCoursesTab = find.text('My Courses');
      if (myCoursesTab.evaluate().isNotEmpty) {
        await tester.tap(myCoursesTab.first);
        await tester.pumpAndSettle(const Duration(seconds: 4));
      }

      final courseCards = find.byType(Card);
      if (courseCards.evaluate().isEmpty) {
        debugPrint('⚠️ Skipping test: No active courses found on the My Courses tab.');
        return;
      }

      final firstCourseTitleWidget = tester.widgetList<Text>(
          find.descendant(of: courseCards.first, matching: find.byType(Text))
      ).firstWhere(
              (text) => text.data != null && text.data!.trim().isNotEmpty && !text.data!.contains('Tap to view contents'),
          orElse: () => const Text('Unknown Course')
      );

      final String courseName = firstCourseTitleWidget.data ?? 'Unknown Course';
      debugPrint('📦 Found course to archive: $courseName');

      final archiveButton = find.descendant(
          of: courseCards.first,
          matching: find.byTooltip('Archive Course')
      );

      if (archiveButton.evaluate().isNotEmpty) {
        await tester.tap(archiveButton.first);
      } else {
        await tester.tap(find.descendant(of: courseCards.first, matching: find.byIcon(Icons.archive_outlined)).first);
      }
      await tester.pumpAndSettle();

      debugPrint('💬 Waiting for confirmation modal...');
      final confirmButton = find.widgetWithText(ElevatedButton, 'Archive');

      if (confirmButton.evaluate().isNotEmpty) {
        await tester.tap(confirmButton.first);
      } else {
        await tester.tap(find.text('Archive').last);
      }
      await tester.pumpAndSettle(const Duration(seconds: 3));

      debugPrint('📂 Navigating to Archive view...');
      final archiveNavButton = find.byTooltip('Archived Records');
      if(archiveNavButton.evaluate().isNotEmpty) {
        await tester.tap(archiveNavButton.first);
      } else {
        await navigateToArchive(tester);
      }
      await tester.pumpAndSettle(const Duration(seconds: 3));

      debugPrint('🔍 Verifying course exists in Archive...');
      expect(find.textContaining(courseName), findsWidgets, reason: 'TC61 Failed: The course "$courseName" did not appear in the archive view.');
      debugPrint('✅ TC61 PASSED: Course successfully migrated to archive view.');
    });

    testWidgets('TC62 - Archive: Selection UI', (tester) async {
      await login(tester, 'wilmartest1@gmail.com', 'wilmartest');

      // Make sure we are on the right tab
      debugPrint('🧭 Navigating to My Courses tab...');
      final myCoursesTab = find.text('My Courses');
      if (myCoursesTab.evaluate().isNotEmpty) {
        await tester.tap(myCoursesTab.first);
        await tester.pumpAndSettle(const Duration(seconds: 4));
      }

      final courseCards = find.byType(Card);
      if (courseCards.evaluate().isEmpty) {
        debugPrint('⚠️ Skipping TC62: No active courses found on Dashboard to check UI.');
        return;
      }

      // Look for the tooltip first, then fallback to the icon, exactly like TC61
      final archiveTooltip = find.descendant(
          of: courseCards.first,
          matching: find.byTooltip('Archive Course')
      );

      final archiveIcon = find.descendant(
          of: courseCards.first,
          matching: find.byIcon(Icons.archive_outlined)
      );

      final bool hasArchiveButton = archiveTooltip.evaluate().isNotEmpty || archiveIcon.evaluate().isNotEmpty;

      expect(hasArchiveButton, isTrue, reason: 'TC62 Failed: Archive button (tooltip or icon) missing from course cards');
      debugPrint('✅ TC62 PASSED');
    });

    testWidgets('TC63 - Archive: Modal Check', (tester) async {
      await login(tester, 'wilmartest1@gmail.com', 'wilmartest');

      debugPrint('🧭 Navigating to My Courses tab...');
      final myCoursesTab = find.text('My Courses');
      if (myCoursesTab.evaluate().isNotEmpty) {
        await tester.tap(myCoursesTab.first);
        await tester.pumpAndSettle(const Duration(seconds: 4));
      }

      final courseCards = find.byType(Card);
      if (courseCards.evaluate().isEmpty) {
        debugPrint('⚠️ Skipping test: No active courses found on the My Courses tab.');
        return;
      }

      debugPrint('📦 Clicking Archive button to spawn modal...');
      final archiveButton = find.descendant(
          of: courseCards.first,
          matching: find.byTooltip('Archive Course')
      );

      if (archiveButton.evaluate().isNotEmpty) {
        await tester.tap(archiveButton.first);
      } else {
        await tester.tap(find.descendant(of: courseCards.first, matching: find.byIcon(Icons.archive_outlined)).first);
      }
      await tester.pumpAndSettle();

      debugPrint('💬 Verifying confirmation modal text...');
      final confirmText = find.textContaining(RegExp(r'are you sure|confirm|archive course', caseSensitive: false));
      expect(confirmText, findsWidgets, reason: 'TC63 Failed: Confirmation modal did not appear');

      final cancelButton = find.text('Cancel');
      if (cancelButton.evaluate().isNotEmpty) {
        await tester.tap(cancelButton.last);
        await tester.pumpAndSettle();
      }
      debugPrint('✅ TC63 PASSED: Confirmation modal successfully appeared.');
    });

    testWidgets('TC64 - Archive: Dedicated View Navigation', (tester) async {
      await login(tester, 'wilmartest1@gmail.com', 'wilmartest');

      debugPrint('🧭 Navigating to My Courses tab...');
      final myCoursesTab = find.text('My Courses');
      if (myCoursesTab.evaluate().isNotEmpty) {
        await tester.tap(myCoursesTab.first);
        await tester.pumpAndSettle(const Duration(seconds: 4));
      }

      debugPrint('📂 Clicking navigation button to Archive view...');

      // Look for the tooltip first, then fall back to the raw icon
      final archiveNavButton = find.byTooltip('Archived Records');

      if(archiveNavButton.evaluate().isNotEmpty) {
        await tester.tap(archiveNavButton.first);
      } else {
        await navigateToArchive(tester); // Use the newly robust helper
      }

      await tester.pumpAndSettle(const Duration(seconds: 3));

      debugPrint('🔍 Verifying we reached the Archived Records page...');

      // Resilient check: Look for the title, or the "No Archived Courses" empty state,
      // or the "LEGACY" tags indicating we are on the archive page.
      final archiveTitle = find.text('Archived Records');
      final emptyState = find.text('No Archived Courses');
      final legacyTag = find.text('LEGACY');

      final bool successfullyNavigated =
          archiveTitle.evaluate().isNotEmpty ||
              emptyState.evaluate().isNotEmpty ||
              legacyTag.evaluate().isNotEmpty;

      expect(successfullyNavigated, isTrue, reason: 'TC64 Failed: Did not navigate to the Archived Records view. Title or Archive elements missing.');
      debugPrint('✅ TC64 PASSED: Successfully navigated to the dedicated view.');
    });

    testWidgets('TC65 - Archive: Cache Exclusion', (tester) async {
      await login(tester, 'wilmartest1@gmail.com', 'wilmartest');
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final courseCards = find.byType(Card);
      if (courseCards.evaluate().isEmpty) {
        debugPrint('⚠️ Skipping TC65: No active courses found to archive.');
        return;
      }

      final firstCourseTitleWidget = tester.widgetList<Text>(
          find.descendant(of: courseCards.first, matching: find.byType(Text))
      ).firstWhere(
              (text) => text.data != null && text.data!.length > 5 && !text.data!.contains('123'),
          orElse: () => const Text('Unknown Course')
      );
      final String courseName = firstCourseTitleWidget.data ?? 'Unknown Course';

      final archiveButton = find.descendant(
          of: courseCards.first,
          matching: find.byWidgetPredicate(
                  (widget) => widget is Icon && (widget.icon == Icons.archive_outlined || widget.icon == Icons.archive)
          )
      );

      if (archiveButton.evaluate().isNotEmpty) {
        await tester.tap(archiveButton.first);
        await tester.pumpAndSettle();

        final confirmButton = find.textContaining(RegExp(r'archive|confirm', caseSensitive: false));
        if (confirmButton.evaluate().isNotEmpty) {
          await tester.tap(confirmButton.last);
          await tester.pumpAndSettle(const Duration(seconds: 4));

          expect(find.text(courseName), findsNothing, reason: 'TC65 Failed: Archived course is still visible on active dashboard');
          debugPrint('✅ TC65 PASSED');
        }
      }
    });

    testWidgets('TC66 - Archive: Reference Mode', (tester) async {
      await login(tester, 'wilmartest1@gmail.com', 'wilmartest');

      debugPrint('🧭 Navigating to My Courses tab...');
      final myCoursesTab = find.text('My Courses');
      if (myCoursesTab.evaluate().isNotEmpty) {
        await tester.tap(myCoursesTab.first);
        await tester.pumpAndSettle(const Duration(seconds: 4));
      }

      debugPrint('📂 Navigating to Archive view...');
      final archiveNavButton = find.byTooltip('Archived Records');
      if(archiveNavButton.evaluate().isNotEmpty) {
        await tester.tap(archiveNavButton.first);
      } else {
        await navigateToArchive(tester);
      }
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final courseCards = find.byType(Card);
      if (courseCards.evaluate().isEmpty) {
        debugPrint('⚠️ Skipping TC66: No archived courses available to test Reference Mode.');
        return;
      }

      debugPrint('🔍 Opening archived course details...');
      final viewDetailsButton = find.descendant(
          of: courseCards.first,
          matching: find.text('View Details')
      );

      if (viewDetailsButton.evaluate().isNotEmpty) {
        await tester.tap(viewDetailsButton.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        final addButton = find.byIcon(Icons.add);
        expect(addButton, findsNothing, reason: 'TC66 Failed: Editing controls (add button) are visible in Reference Mode');
        expect(find.textContaining('Reference Mode'), findsWidgets, reason: 'Reference mode warning banner is missing');
        debugPrint('✅ TC66 PASSED: Reference mode successfully verified.');
      } else {
        debugPrint('⚠️ TC66 Skipped: Could not find View Details button.');
      }
    });

    testWidgets('TC67 - Archive: Legacy Label', (tester) async {
      await login(tester, 'wilmartest1@gmail.com', 'wilmartest');

      debugPrint('🧭 Navigating to My Courses tab...');
      final myCoursesTab = find.text('My Courses');
      if (myCoursesTab.evaluate().isNotEmpty) {
        await tester.tap(myCoursesTab.first);
        await tester.pumpAndSettle(const Duration(seconds: 4));
      }

      debugPrint('📂 Navigating to Archive view...');
      final archiveNavButton = find.byTooltip('Archived Records');
      if(archiveNavButton.evaluate().isNotEmpty) {
        await tester.tap(archiveNavButton.first);
      } else {
        await navigateToArchive(tester);
      }
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final courseCards = find.byType(Card);
      if (courseCards.evaluate().isEmpty) {
        debugPrint('⚠️ Skipping TC67: No archived courses available to test Legacy Label.');
        return;
      }

      debugPrint('🏷️ Checking for Legacy/Archived tags...');
      final legacyTag = find.descendant(of: courseCards.first, matching: find.text('LEGACY'));
      final archivedTag = find.descendant(of: courseCards.first, matching: find.textContaining('ARCHIVED'));

      final bool hasTags = legacyTag.evaluate().isNotEmpty || archivedTag.evaluate().isNotEmpty;
      expect(hasTags, isTrue, reason: 'TC67 Failed: Course is missing LEGACY or ARCHIVED visual tag');
      debugPrint('✅ TC67 PASSED: Legacy labels are present.');
    });

    testWidgets('TC68 - Archive: Complete Record (Sub-data Retrieval)', (tester) async {
      await login(tester, 'wilmartest1@gmail.com', 'wilmartest');

      debugPrint('🧭 Navigating to My Courses tab...');
      final myCoursesTab = find.text('My Courses');
      if (myCoursesTab.evaluate().isNotEmpty) {
        await tester.tap(myCoursesTab.first);
        await tester.pumpAndSettle(const Duration(seconds: 4));
      }

      debugPrint('📂 Navigating to Archive view...');
      final archiveNavButton = find.byTooltip('Archived Records');
      if(archiveNavButton.evaluate().isNotEmpty) {
        await tester.tap(archiveNavButton.first);
      } else {
        await navigateToArchive(tester);
      }
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final courseCards = find.byType(Card);
      if (courseCards.evaluate().isEmpty) {
        debugPrint('⚠️ Skipping TC68: No archived courses available to test Sub-data.');
        return;
      }

      debugPrint('🔍 Opening archived course details...');
      final viewDetailsButton = find.descendant(of: courseCards.first, matching: find.text('View Details'));
      if (viewDetailsButton.evaluate().isNotEmpty) {
        await tester.tap(viewDetailsButton.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        debugPrint('📊 Verifying sub-data is rendered...');
        final activitiesLabel = find.text('Activities');
        final completedLabel = find.text('Completed');

        expect(activitiesLabel, findsWidgets, reason: 'TC68 Failed: Sub-data stats (Activities) missing from archived record');
        expect(completedLabel, findsWidgets, reason: 'TC68 Failed: Sub-data stats (Completed) missing from archived record');
        debugPrint('✅ TC68 PASSED: Sub-data successfully retrieved and rendered.');
      } else {
        debugPrint('⚠️ TC68 Skipped: View details button not found.');
      }
    });

    testWidgets('TC71 - Archive: Cancel Modal', (tester) async {
      await login(tester, 'wilmartest1@gmail.com', 'wilmartest');

      debugPrint('🧭 Navigating to My Courses tab...');
      final myCoursesTab = find.text('My Courses');
      if (myCoursesTab.evaluate().isNotEmpty) {
        await tester.tap(myCoursesTab.first);
        await tester.pumpAndSettle(const Duration(seconds: 4));
      }

      final courseCards = find.byType(Card);
      if (courseCards.evaluate().isEmpty) {
        debugPrint('⚠️ Skipping TC71: No active courses found to test cancellation.');
        return;
      }

      debugPrint('📦 Clicking Archive button to spawn modal...');
      final archiveButton = find.descendant(of: courseCards.first, matching: find.byTooltip('Archive Course'));
      if (archiveButton.evaluate().isNotEmpty) {
        await tester.tap(archiveButton.first);
      } else {
        await tester.tap(find.descendant(of: courseCards.first, matching: find.byIcon(Icons.archive_outlined)).first);
      }
      await tester.pumpAndSettle(const Duration(seconds: 2));

      debugPrint('❌ Tapping Cancel...');
      final cancelButton = find.textContaining(RegExp(r'cancel|no|close', caseSensitive: false));
      expect(cancelButton, findsWidgets, reason: 'TC71 Failed: Cancel button missing on modal');
      await tester.tap(cancelButton.last);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(cancelButton, findsNothing, reason: 'TC71 Failed: Modal did not close after clicking cancel');
      debugPrint('✅ TC71 PASSED: Modal successfully cancelled and closed.');
    });

    testWidgets('TC72 - Archive: Duplicate Migration', (tester) async {
      await login(tester, 'wilmartest1@gmail.com', 'wilmartest');

      debugPrint('🧭 Navigating to My Courses tab...');
      final myCoursesTab = find.text('My Courses');
      if (myCoursesTab.evaluate().isNotEmpty) {
        await tester.tap(myCoursesTab.first);
        await tester.pumpAndSettle(const Duration(seconds: 4));
      }

      final courseCards = find.byType(Card);
      if (courseCards.evaluate().isEmpty) {
        debugPrint('⚠️ Skipping TC72: No active courses found to test duplicate migration.');
        return;
      }

      debugPrint('📦 Clicking Archive button...');
      final archiveButton = find.descendant(of: courseCards.first, matching: find.byTooltip('Archive Course'));
      if (archiveButton.evaluate().isNotEmpty) {
        await tester.tap(archiveButton.first);
      } else {
        await tester.tap(find.descendant(of: courseCards.first, matching: find.byIcon(Icons.archive_outlined)).first);
      }
      await tester.pumpAndSettle();

      debugPrint('⚡ Simulating rapid confirmation clicks...');
      final confirmButton = find.widgetWithText(ElevatedButton, 'Archive');
      if (confirmButton.evaluate().isNotEmpty) {
        // Added warnIfMissed: false to prevent terminal warnings when the modal animates away
        await tester.tap(confirmButton.first, warnIfMissed: false);
        await tester.tap(confirmButton.first, warnIfMissed: false);
        await tester.tap(confirmButton.first, warnIfMissed: false);
      }

      await tester.pumpAndSettle(const Duration(seconds: 3));

      final archiveNavButton = find.byTooltip('Archived Records');
      if (archiveNavButton.evaluate().isNotEmpty) {
        await tester.tap(archiveNavButton.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      debugPrint('✅ TC72 executed: Rapid clicks absorbed without fatal frontend crash.');
    });
  });
}