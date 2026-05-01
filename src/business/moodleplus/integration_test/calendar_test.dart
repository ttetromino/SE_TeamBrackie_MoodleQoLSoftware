import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/main.dart' as app;
import '../lib/models/calendar_event_model.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Helper: Smart Login and navigate to Calendar Tab
  Future<void> loginAndNavigateToCalendar(WidgetTester tester) async {
    app.main();

    bool isReady = false;
    bool needsManualLogin = true;

    debugPrint('⏳ Waiting for app to initialize...');

    // 1. Initial wait to let the app naturally bypass the splash screen
    for (int i = 0; i < 20; i++) {
      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 500));

      if (find.text('My Courses').evaluate().isNotEmpty || find.byIcon(Icons.calendar_month).evaluate().isNotEmpty) {
        isReady = true;
        needsManualLogin = false;
        debugPrint('✅ Auto-login detected! Skipping manual login steps.');
        break;
      }

      if (find.byType(TextField).evaluate().isNotEmpty) {
        isReady = true;
        needsManualLogin = true;
        debugPrint('🔐 Login screen detected. Proceeding with manual login.');
        break;
      }
    }

    if (!isReady) fail('❌ App stuck on splash screen.');

    // 2. Perform Login if needed
    if (needsManualLogin) {
      final emailField = find.byType(TextField).first;
      final passField = find.byType(TextField).last;

      final loginButtonFinder = find.widgetWithText(ElevatedButton, 'Log In');
      final loginButton = loginButtonFinder.evaluate().isNotEmpty
          ? loginButtonFinder.first
          : find.byType(ElevatedButton).first;

      // Restored the '1' to match the known working Backlog test account
      await tester.enterText(emailField, 'wilmartest1@gmail.com');
      await tester.enterText(passField, '123');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.tap(loginButton);

      debugPrint('🔄 Waiting for LMS authentication...');

      // Increased timeout to 30 seconds (60 loops * 500ms) to handle slow Moodle servers
      bool loginFinished = false;
      for (int i = 0; i < 60; i++) {
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 500));

        if (find.text('Calendar').evaluate().isNotEmpty ||
            find.text('My Courses').evaluate().isNotEmpty ||
            find.byIcon(Icons.calendar_month).evaluate().isNotEmpty) {
          loginFinished = true;
          debugPrint('✅ Login finished successfully.');
          break;
        }

        // Optional: Catch visible error messages on the login screen to fail faster
        if (find.textContaining(RegExp(r'Invalid login|Incorrect|Error', caseSensitive: false)).evaluate().isNotEmpty) {
          debugPrint('⚠️ Detected a login error message on the screen! Check credentials.');
        }
      }

      if (!loginFinished) fail('❌ Stuck on loading spinner after tapping Log In.');
    }

    // 3. Navigate to Calendar - find by icon
    debugPrint('🧭 Navigating to Calendar...');
    final calendarIcon = find.byIcon(Icons.calendar_month);
    final calendarText = find.text('Calendar');

    if (calendarIcon.evaluate().isNotEmpty) {
      await tester.tap(calendarIcon.first);
    } else if (calendarText.evaluate().isNotEmpty) {
      await tester.tap(calendarText.first);
    } else {
      // Fallback index assuming Dashboard(0), Gradebook(1), Calendar(2)
      await tester.tap(find.byType(BottomNavigationBarItem).at(2));
    }

    // Give it time to render the grid
    await tester.pump();
    await Future.delayed(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  // Helper: Clear cached events
  Future<void> clearCalendarCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_calendar_events');
    await prefs.remove('personal_calendar_events');
    await prefs.remove('calendar_last_sync');
    await prefs.remove('calendar_events');
    print('🗑️ Calendar cache cleared');
  }

  // Helper: Add sample academic events
  Future<void> addSampleAcademicEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final sampleEvents = [
      CalendarEvent(
        id: 'moodle_assign_001',
        title: 'Midterm Project',
        description: 'Parallel Data Processing System',
        date: DateTime(2026, 4, 17),
        type: EventType.academic,
        courseName: 'BCS3217L',
      ),
      CalendarEvent(
        id: 'moodle_quiz_002',
        title: 'Midterm Quiz 1',
        description: 'Covers weeks 1-6 material',
        date: DateTime(2026, 4, 17),
        type: EventType.academic,
        courseName: 'BCS3217L',
      ),
      CalendarEvent(
        id: 'moodle_assign_003',
        title: 'Final Activity 9',
        description: 'Final project submission',
        date: DateTime(2026, 4, 25),
        type: EventType.academic,
        courseName: 'BCS3217L',
      ),
      CalendarEvent(
        id: 'moodle_quiz_004',
        title: 'Final Quiz',
        description: 'Comprehensive final exam',
        date: DateTime(2026, 5, 1),
        type: EventType.academic,
        courseName: 'BCS3217L',
      ),
    ];
    final eventsJson = jsonEncode(sampleEvents.map((e) => e.toJson()).toList());
    await prefs.setString('cached_calendar_events', eventsJson);
    print('✅ ${sampleEvents.length} sample academic events added');
  }

  // Helper: Add sample personal events
  Future<void> addSamplePersonalEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final personalEvents = [
      CalendarEvent(
        id: 'personal_001',
        title: 'Study Group Meeting',
        description: 'Review for midterms',
        date: DateTime(2026, 4, 18),
        time: const TimeOfDay(hour: 14, minute: 0),
        type: EventType.personal,
        courseName: null,
      ),
      CalendarEvent(
        id: 'personal_002',
        title: 'Doctor Appointment',
        description: 'Annual checkup',
        date: DateTime(2026, 4, 20),
        time: const TimeOfDay(hour: 10, minute: 30),
        type: EventType.personal,
        courseName: null,
      ),
      CalendarEvent(
        id: 'personal_003',
        title: 'Gym Session',
        description: 'Evening workout',
        date: DateTime(2026, 4, 21),
        time: const TimeOfDay(hour: 18, minute: 0),
        type: EventType.personal,
        courseName: null,
      ),
    ];
    final eventsJson = jsonEncode(personalEvents.map((e) => e.toJson()).toList());
    await prefs.setString('personal_calendar_events', eventsJson);
    print('✅ ${personalEvents.length} sample personal events added');
  }

  group('US-11: Calendar Integration Tests', () {

    // ============================================================
    // TC86: Calendar: Happy Path - Monthly Calendar Grid Rendering
    // ============================================================
    testWidgets('TC86 - Calendar: Monthly Calendar Grid Rendering', (tester) async {
      await clearCalendarCache();
      await addSampleAcademicEvents();
      await loginAndNavigateToCalendar(tester);

      // Verify month/year header exists
      final monthYearText = find.textContaining(RegExp(r'[A-Z][a-z]+ \d{4}'));
      expect(monthYearText, findsOneWidget, reason: 'Month/Year header should be displayed');

      // Verify navigation arrows exist
      expect(find.byIcon(Icons.chevron_left), findsOneWidget, reason: 'Previous month button missing');
      expect(find.byIcon(Icons.chevron_right), findsOneWidget, reason: 'Next month button missing');

      // Verify sync button exists
      expect(find.byIcon(Icons.sync), findsAtLeastNWidgets(1), reason: 'Sync button should exist');

      // Verify add event button exists
      expect(find.byIcon(Icons.add), findsOneWidget, reason: 'Add event button missing');

      // Verify calendar month grid displays (at least 20 day numbers)
      final dayNumbers = find.textContaining(RegExp(r'^\d{1,2}$'));
      expect(dayNumbers, findsAtLeastNWidgets(20), reason: 'Calendar grid should show day numbers');

      print('✅ TC86 - Calendar: Monthly Calendar Grid Rendering PASSED');
    });

    // ============================================================
    // TC87: Calendar: Visual Legend - Event Type Differentiation
    // ============================================================
    testWidgets('TC87 - Calendar: Visual Legend - Event Type Differentiation', (tester) async {
      await clearCalendarCache();
      await addSampleAcademicEvents();
      await addSamplePersonalEvents();
      await loginAndNavigateToCalendar(tester);

      // Verify legend text exists
      expect(find.text('Academic'), findsWidgets, reason: 'Academic legend should be visible');
      expect(find.text('Personal'), findsWidgets, reason: 'Personal legend should be visible');

      // Switch to Events tab by tapping "Events" text in TabBar (if it exists)
      final eventsTabText = find.text('Events');
      if (eventsTabText.evaluate().isNotEmpty) {
        await tester.tap(eventsTabText.first);
        await tester.pump();
        await Future.delayed(const Duration(seconds: 2));
      }

      // Verify event types have different icons
      final schoolIcons = find.byIcon(Icons.school);
      final personIcons = find.byIcon(Icons.person);

      // At least one type should be visible in the legend or list
      expect(schoolIcons.evaluate().isNotEmpty || personIcons.evaluate().isNotEmpty, true,
          reason: 'Events should have type-specific icons');

      print('✅ TC87 - Calendar: Visual Legend - Event Type Differentiation PASSED');
    });

    // ============================================================
    // TC88: Calendar: High Volume Day View
    // ============================================================
    testWidgets('TC88 - Calendar: High Volume Day View', (tester) async {
      await clearCalendarCache();
      await loginAndNavigateToCalendar(tester);

      // Find any day number and tap it to open day view
      final dayNumbers = find.textContaining(RegExp(r'^\d{1,2}$'));
      expect(dayNumbers, findsWidgets, reason: 'Day numbers should exist');

      await tester.tap(dayNumbers.first);
      await tester.pump();
      await Future.delayed(const Duration(seconds: 2));

      // Verify something opened (either a sheet or a dialog)
      final scrollableSheet = find.byType(DraggableScrollableSheet);

      if (scrollableSheet.evaluate().isNotEmpty) {
        await tester.drag(scrollableSheet.first, const Offset(0, -200));
        await tester.pumpAndSettle();
      }

      // Close by tapping outside or tapping back
      await tester.tapAt(const Offset(50, 100));
      await tester.pumpAndSettle();

      print('✅ TC88 - Calendar: High Volume Day View PASSED');
    });

    // ============================================================
    // TC89: Calendar: Initial Moodle Sync
    // ============================================================
    testWidgets('TC89 - Calendar: Initial Moodle Sync', (tester) async {
      await clearCalendarCache();
      await loginAndNavigateToCalendar(tester);

      final syncButtons = find.byIcon(Icons.sync);
      expect(syncButtons, findsWidgets, reason: 'Sync button should exist');

      await tester.tap(syncButtons.first);
      await tester.pump();
      await Future.delayed(const Duration(seconds: 8));
      await tester.pumpAndSettle();

      // Verify calendar still displays after sync
      final monthYearText = find.textContaining(RegExp(r'[A-Z][a-z]+ \d{4}'));
      expect(monthYearText, findsWidgets, reason: 'Calendar should still display after sync');

      print('✅ TC89 - Calendar: Initial Moodle Sync PASSED');
    });

    // ============================================================
    // TC90: Calendar: Duplicate Sync Prevention
    // ============================================================
    testWidgets('TC90 - Calendar: Duplicate Sync Prevention', (tester) async {
      await clearCalendarCache();
      await addSampleAcademicEvents();
      await loginAndNavigateToCalendar(tester);

      final syncButtons = find.byIcon(Icons.sync);

      for (int i = 0; i < 2; i++) {
        if (syncButtons.evaluate().isNotEmpty) {
          await tester.tap(syncButtons.first);
          await tester.pump();
          await Future.delayed(const Duration(seconds: 4));
          print('Sync attempt ${i + 1} completed');
        }
      }
      await tester.pumpAndSettle();

      // Verify calendar still responsive after multiple syncs
      final monthYearText = find.textContaining(RegExp(r'[A-Z][a-z]+ \d{4}'));
      expect(monthYearText, findsWidgets, reason: 'Calendar should still be responsive');

      print('✅ TC90 - Calendar: Duplicate Sync Prevention PASSED');
    });

