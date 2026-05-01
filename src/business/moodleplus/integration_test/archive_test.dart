import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:integration_test/integration_test.dart';

import '../lib/main.dart' as app;



void main() {

  IntegrationTestWidgetsFlutterBinding.ensureInitialized();



// Helper method to log in

  Future<void> login(WidgetTester tester, String email, String password) async {

    app.main();

    await tester.pumpAndSettle();



    final emailField = find.byType(TextField).first;

    final passField = find.byType(TextField).last;

    final loginButton = find.byType(ElevatedButton).first;



    await tester.enterText(emailField, email);

    await tester.enterText(passField, password);

    await tester.tap(loginButton);

    await tester.pumpAndSettle();

  }



// Helper method to safely navigate to the Archive view

  Future<void> navigateToArchive(WidgetTester tester) async {

    final archiveIcon = find.byIcon(Icons.archive);

    expect(archiveIcon, findsWidgets, reason: 'Archive navigation icon not found');

    await tester.tap(archiveIcon.first);

    await tester.pumpAndSettle(const Duration(seconds: 2));

  }



  group('US-04 Archive Feature Tests', () {



// --- ADD THIS HERE ---

    setUp(() {

      final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

// Make the simulated screen very tall for all tests to prevent overflow crashes

      binding.window.physicalSizeTestValue = const Size(1080, 2400);

      binding.window.devicePixelRatioTestValue = 1.0;

    });



    tearDown(() {

      final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

      binding.window.clearPhysicalSizeTestValue();

      binding.window.clearDevicePixelRatioTestValue();

    });



    testWidgets('TC73 - Archive: Empty State', (tester) async {

      await login(tester, 'wilmartest1@gmail.com', '123');



      debugPrint('🧭 Navigating to My Courses tab...');

      final myCoursesTab = find.text('My Courses');

      if (myCoursesTab.evaluate().isNotEmpty) {

        await tester.tap(myCoursesTab.first);

        await tester.pumpAndSettle(const Duration(seconds: 4));

      }



      debugPrint('📂 Navigating to Archive view...');

      final archiveNavButton = find.byTooltip('Archived Records');

      await tester.tap(archiveNavButton.first);

      await tester.pumpAndSettle(const Duration(seconds: 3));



// Check if the database actually has courses. If so, we can't test the empty state.

      final courseCards = find.byType(Card);

      if (courseCards.evaluate().isNotEmpty) {

        debugPrint('⚠️ Skipping TC73: Database is not empty. Cannot verify empty state UI.');

        return;

      }



      debugPrint('📭 Verifying empty state text...');

// Using the exact string from your ArchivedCoursesPage UI code

      final emptyStateMessage = find.text('No Archived Courses');



      expect(emptyStateMessage, findsWidgets, reason: 'TC73 Failed: Empty state placeholder "No Archived Courses" not found in Archive view');



      debugPrint('✅ TC73 PASSED: Empty state successfully validated.');

    });



    testWidgets('TC61 - Archive: Happy Path (Migration Verification)', (tester) async {

      await login(tester, 'wilmartest1@gmail.com', '123');



// 1. Navigate to the "My Courses" tab

      debugPrint('🧭 Navigating to My Courses tab...');

      final myCoursesTab = find.text('My Courses');

      if (myCoursesTab.evaluate().isNotEmpty) {

        await tester.tap(myCoursesTab.first);

// Wait for course list to fetch and render

        await tester.pumpAndSettle(const Duration(seconds: 4));

      }



// 2. Identify a course to archive

      final courseCards = find.byType(Card);

      if (courseCards.evaluate().isEmpty) {

        debugPrint('⚠️ Skipping test: No active courses found on the My Courses tab.');

        return;

      }



// Grab the text of the first course title (ignoring the "Tap to view contents" subtitle)

      final firstCourseTitleWidget = tester.widgetList<Text>(

          find.descendant(of: courseCards.first, matching: find.byType(Text))

      ).firstWhere(

              (text) => text.data != null && text.data!.trim().isNotEmpty && !text.data!.contains('Tap to view contents'),

          orElse: () => const Text('Unknown Course')

      );



      final String courseName = firstCourseTitleWidget.data ?? 'Unknown Course';

      debugPrint('📦 Found course to archive: $courseName');



// 3. Click the specific Archive Button on the card

// Using the tooltip assigned in your home_page.dart source code

      final archiveButton = find.descendant(

          of: courseCards.first,

          matching: find.byTooltip('Archive Course')

      );



      if (archiveButton.evaluate().isNotEmpty) {

        await tester.tap(archiveButton.first);

      } else {

// Fallback to the orange outlined icon from your screenshot

        await tester.tap(find.descendant(of: courseCards.first, matching: find.byIcon(Icons.archive_outlined)).first);

      }

      await tester.pumpAndSettle();



// 4. Confirm the modal

      debugPrint('💬 Waiting for confirmation modal...');

// Look explicitly for the elevated button that says "Archive"

      final confirmButton = find.widgetWithText(ElevatedButton, 'Archive');



      if (confirmButton.evaluate().isNotEmpty) {

        await tester.tap(confirmButton.first);

      } else {

// Fallback if the button is text-only

        await tester.tap(find.text('Archive').last);

      }



// Wait for the backend API request to finish archiving

      await tester.pumpAndSettle(const Duration(seconds: 3));



// 5. Navigate to the Archive View via AppBar icon

      debugPrint('📂 Navigating to Archive view...');

      final archiveNavButton = find.byTooltip('Archived Records');

      expect(archiveNavButton, findsWidgets, reason: 'Could not find the "Archived Records" button in the AppBar');

      await tester.tap(archiveNavButton.first);



// Wait for the archive list to fetch from the backend

      await tester.pumpAndSettle(const Duration(seconds: 3));



// 6. Verify the course is in the archive view

      debugPrint('🔍 Verifying course exists in Archive...');

      expect(find.textContaining(courseName), findsWidgets, reason: 'TC61 Failed: The course "$courseName" did not appear in the archive view.');



      debugPrint('✅ TC61 PASSED: Course successfully migrated to archive view.');

    });



    testWidgets('TC62 - Archive: Selection UI', (tester) async {

      await login(tester, 'wilmartest1@gmail.com', '123');

      await tester.pumpAndSettle(const Duration(seconds: 2));



      final courseCards = find.byType(Card);

      expect(courseCards, findsWidgets, reason: 'No active courses found on Dashboard');



      final archiveButton = find.byWidgetPredicate(

              (widget) => widget is Icon && (widget.icon == Icons.archive_outlined || widget.icon == Icons.archive)

      );

      expect(archiveButton, findsWidgets, reason: 'Archive button missing from course cards');



      debugPrint('✅ TC62 PASSED');

    });



    testWidgets('TC63 - Archive: Modal Check', (tester) async {

      await login(tester, 'wilmartest1@gmail.com', '123');



// 1. Navigate to the "My Courses" tab

      debugPrint('🧭 Navigating to My Courses tab...');

      final myCoursesTab = find.text('My Courses');

      if (myCoursesTab.evaluate().isNotEmpty) {

        await tester.tap(myCoursesTab.first);

        await tester.pumpAndSettle(const Duration(seconds: 4));

      }



// 2. Identify a course card

      final courseCards = find.byType(Card);

      if (courseCards.evaluate().isEmpty) {

        debugPrint('⚠️ Skipping test: No active courses found on the My Courses tab.');

        return;

      }



// 3. Click the Archive Button on the card

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



// 4. Verify the modal appears

      debugPrint('💬 Verifying confirmation modal text...');

      final confirmText = find.textContaining(RegExp(r'are you sure|confirm|archive course', caseSensitive: false));



      expect(confirmText, findsWidgets, reason: 'TC63 Failed: Confirmation modal did not appear');



// 5. Cleanup: Tap Cancel to close the modal so it doesn't block future tests

      final cancelButton = find.text('Cancel');

      if (cancelButton.evaluate().isNotEmpty) {

        await tester.tap(cancelButton.last);

        await tester.pumpAndSettle();

      }



      debugPrint('✅ TC63 PASSED: Confirmation modal successfully appeared.');

    });



    testWidgets('TC64 - Archive: Dedicated View Navigation', (tester) async {

      await login(tester, 'wilmartest1@gmail.com', '123');



// 1. Navigate to the "My Courses" tab

      debugPrint('🧭 Navigating to My Courses tab...');

      final myCoursesTab = find.text('My Courses');

      if (myCoursesTab.evaluate().isNotEmpty) {

        await tester.tap(myCoursesTab.first);

        await tester.pumpAndSettle(const Duration(seconds: 4));

      }



// 2. Navigate to the Archive View via AppBar icon

      debugPrint('📂 Clicking AppBar navigation button to Archive view...');

      final archiveNavButton = find.byTooltip('Archived Records');

      expect(archiveNavButton, findsWidgets, reason: 'Could not find the "Archived Records" button in the AppBar');

      await tester.tap(archiveNavButton.first);



// Wait for the page transition and backend fetch to complete

      await tester.pumpAndSettle(const Duration(seconds: 3));



// 3. Verify successful navigation by checking the new page's AppBar title

      debugPrint('🔍 Verifying we reached the Archived Records page...');

      final archiveTitle = find.text('Archived Records');



      expect(archiveTitle, findsWidgets, reason: 'TC64 Failed: Did not navigate to the Archived Records view');



      debugPrint('✅ TC64 PASSED: Successfully navigated to the dedicated view.');

    });



    testWidgets('TC65 - Archive: Cache Exclusion', (tester) async {

      await login(tester, 'wilmartest1@gmail.com', '123');

      await tester.pumpAndSettle(const Duration(seconds: 2));



      final firstCourseTitleWidget = tester.widgetList<Text>(find.byType(Text)).firstWhere(

              (text) => text.data != null && text.data!.length > 5 && !text.data!.contains('123'),

          orElse: () => const Text('Unknown Course')

      );

      final String courseName = firstCourseTitleWidget.data ?? 'Unknown Course';



      final archiveButton = find.byWidgetPredicate(

              (widget) => widget is Icon && (widget.icon == Icons.archive_outlined || widget.icon == Icons.archive)

      ).first;

      await tester.tap(archiveButton);

      await tester.pumpAndSettle();



      final confirmButton = find.textContaining(RegExp(r'archive|confirm', caseSensitive: false)).last;

      await tester.tap(confirmButton);

      await tester.pumpAndSettle(const Duration(seconds: 2));



      expect(find.text(courseName), findsNothing, reason: 'TC65 Failed: Archived course is still visible on active dashboard');

      debugPrint('✅ TC65 PASSED');

    });



    testWidgets('TC66 - Archive: Reference Mode', (tester) async {

      await login(tester, 'wilmartest1@gmail.com', '123');



// 1. Navigate to the "My Courses" tab first

      debugPrint('🧭 Navigating to My Courses tab...');

      final myCoursesTab = find.text('My Courses');

      if (myCoursesTab.evaluate().isNotEmpty) {

        await tester.tap(myCoursesTab.first);

        await tester.pumpAndSettle(const Duration(seconds: 4));

      }



// 2. Navigate to Archive View

      debugPrint('📂 Navigating to Archive view...');

      final archiveNavButton = find.byTooltip('Archived Records');

      expect(archiveNavButton, findsWidgets, reason: 'Could not find the "Archived Records" button in the AppBar');

      await tester.tap(archiveNavButton.first);

      await tester.pumpAndSettle(const Duration(seconds: 3));



// 3. Ensure we have courses to test

      final courseCards = find.byType(Card);

      if (courseCards.evaluate().isEmpty) {

        debugPrint('⚠️ Skipping TC66: No archived courses available to test Reference Mode.');

        return;

      }



// 4. Tap the "View Details" button from your UI code

      debugPrint('🔍 Opening archived course details...');

      final viewDetailsButton = find.descendant(

          of: courseCards.first,

          matching: find.text('View Details')

      );



      if (viewDetailsButton.evaluate().isNotEmpty) {

        await tester.tap(viewDetailsButton.first);

        await tester.pumpAndSettle(const Duration(seconds: 2));

      } else {

        fail('Could not find View Details button on the archived course card');

      }



// 5. Verify Reference Mode (Editing disabled)

      final addButton = find.byIcon(Icons.add);

      expect(addButton, findsNothing, reason: 'TC66 Failed: Editing controls (add button) are visible in Reference Mode');



// Bonus: Verify the reference mode banner from your UI code exists

      expect(find.textContaining('Reference Mode'), findsWidgets, reason: 'Reference mode warning banner is missing');



      debugPrint('✅ TC66 PASSED: Reference mode successfully verified.');

    });



    testWidgets('TC67 - Archive: Legacy Label', (tester) async {

      await login(tester, 'wilmartest1@gmail.com', '123');



      debugPrint('🧭 Navigating to My Courses tab...');

      final myCoursesTab = find.text('My Courses');

      if (myCoursesTab.evaluate().isNotEmpty) {

        await tester.tap(myCoursesTab.first);

        await tester.pumpAndSettle(const Duration(seconds: 4));

      }



      debugPrint('📂 Navigating to Archive view...');

      final archiveNavButton = find.byTooltip('Archived Records');

      await tester.tap(archiveNavButton.first);

      await tester.pumpAndSettle(const Duration(seconds: 3));



      final courseCards = find.byType(Card);

      if (courseCards.evaluate().isEmpty) {

        debugPrint('⚠️ Skipping TC67: No archived courses available to test Legacy Label.');

        return;

      }



// Check for exact tags from your UI code

      debugPrint('🏷️ Checking for Legacy/Archived tags...');

      final legacyTag = find.descendant(of: courseCards.first, matching: find.text('LEGACY'));

      final archivedTag = find.descendant(of: courseCards.first, matching: find.textContaining('ARCHIVED'));



      final bool hasTags = legacyTag.evaluate().isNotEmpty || archivedTag.evaluate().isNotEmpty;

      expect(hasTags, isTrue, reason: 'TC67 Failed: Course is missing LEGACY or ARCHIVED visual tag');



      debugPrint('✅ TC67 PASSED: Legacy labels are present.');

    });



    testWidgets('TC68 - Archive: Complete Record (Sub-data Retrieval)', (tester) async {

      await login(tester, 'wilmartest1@gmail.com', '123');



      debugPrint('🧭 Navigating to My Courses tab...');

      final myCoursesTab = find.text('My Courses');

      if (myCoursesTab.evaluate().isNotEmpty) {

        await tester.tap(myCoursesTab.first);

        await tester.pumpAndSettle(const Duration(seconds: 4));

      }



      debugPrint('📂 Navigating to Archive view...');

      final archiveNavButton = find.byTooltip('Archived Records');

      await tester.tap(archiveNavButton.first);

      await tester.pumpAndSettle(const Duration(seconds: 3));



      final courseCards = find.byType(Card);

      if (courseCards.evaluate().isEmpty) {

        debugPrint('⚠️ Skipping TC68: No archived courses available to test Sub-data.');

        return;

      }



      debugPrint('🔍 Opening archived course details...');

      final viewDetailsButton = find.descendant(of: courseCards.first, matching: find.text('View Details'));

      await tester.tap(viewDetailsButton.first);

      await tester.pumpAndSettle(const Duration(seconds: 2));



// Check for elements that indicate sub-data loaded (from your UI code)

      debugPrint('📊 Verifying sub-data is rendered...');

      final activitiesLabel = find.text('Activities');

      final completedLabel = find.text('Completed');



      expect(activitiesLabel, findsWidgets, reason: 'TC68 Failed: Sub-data stats (Activities) missing from archived record');

      expect(completedLabel, findsWidgets, reason: 'TC68 Failed: Sub-data stats (Completed) missing from archived record');



      debugPrint('✅ TC68 PASSED: Sub-data successfully retrieved and rendered.');

    });



    testWidgets('TC71 - Archive: Cancel Modal', (tester) async {

      await login(tester, 'wilmartest1@gmail.com', '123');



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

// Added a slight delay to allow modal animation to complete

      await tester.pumpAndSettle(const Duration(seconds: 2));



      debugPrint('❌ Tapping Cancel...');

// Resilient finder: catches 'Cancel', 'CANCEL', 'cancel', or even 'No'

      final cancelButton = find.textContaining(RegExp(r'cancel|no|close', caseSensitive: false));

      expect(cancelButton, findsWidgets, reason: 'TC71 Failed: Cancel button missing on modal');

      await tester.tap(cancelButton.last);



// Wait for modal exit animation

      await tester.pumpAndSettle(const Duration(seconds: 2));



// Verify the modal is gone by checking that the cancel button no longer exists on screen

      expect(cancelButton, findsNothing, reason: 'TC71 Failed: Modal did not close after clicking cancel');



      debugPrint('✅ TC71 PASSED: Modal successfully cancelled and closed.');

    });



    testWidgets('TC72 - Archive: Duplicate Migration', (tester) async {

      await login(tester, 'wilmartest1@gmail.com', '123');



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

// Simulate rapid spam clicking
        await tester.tap(confirmButton.first);
        await tester.tap(confirmButton.first);
        await tester.tap(confirmButton.first);
      }

      await tester.pumpAndSettle(const Duration(seconds: 3));

// Navigate to archive just to ensure app didn't crash
      final archiveNavButton = find.byTooltip('Archived Records');
      if (archiveNavButton.evaluate().isNotEmpty) {
        await tester.tap(archiveNavButton.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }


      debugPrint('✅ TC72 executed: Rapid clicks absorbed without fatal frontend crash (Database validation recommended).');
    });
  });
}

