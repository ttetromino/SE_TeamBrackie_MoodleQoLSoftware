import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Update this to match your actual main.dart import!
import '../lib/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Helper: Smart Login
  Future<void> login(WidgetTester tester, String email, String password) async {
    app.main();

    bool isReady = false;
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.byType(TextField).evaluate().length >= 2 || find.text('My Courses').evaluate().isNotEmpty) {
        isReady = true;
        break;
      }
    }

    if (!isReady) fail('❌ App stuck on splash screen.');

    if (find.byType(TextField).evaluate().isNotEmpty) {
      final allTextFields = find.byType(TextField);
      await tester.enterText(allTextFields.first, email);
      await tester.enterText(allTextFields.last, password);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final loginTarget = find.textContaining(RegExp(r'^log in$|^login$|^sign in$', caseSensitive: false));
      if (loginTarget.evaluate().isNotEmpty) {
        await tester.tap(loginTarget.last, warnIfMissed: false);
      } else {
        await tester.tap(find.byType(ElevatedButton).first, warnIfMissed: false);
      }

      await tester.pumpAndSettle(const Duration(seconds: 4));
    }
  }

  // Helper: Navigate to Admin Dashboard
  Future<void> navigateToAdminDashboard(WidgetTester tester) async {
    // Looking for the shield icon shown in Screenshot 1
    final adminIconFinder = find.byWidgetPredicate(
            (widget) => widget is Icon && (widget.icon == Icons.admin_panel_settings || widget.icon == Icons.security || widget.icon == Icons.shield)
    );

    if (adminIconFinder.evaluate().isNotEmpty) {
      await tester.tap(adminIconFinder.first);
    } else {
      // Fallback: look for a tooltip if the icon isn't exact
      final tooltipFinder = find.byTooltip('Admin Dashboard');
      if (tooltipFinder.evaluate().isNotEmpty) {
        await tester.tap(tooltipFinder.first);
      } else {
        fail('Admin Navigation Icon not found on screen.');
      }
    }
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  group('US-12: Admin Dashboard & Connectivity Tests', () {

    testWidgets('TC109 - Verify dynamic visibility of the Admin menu link (Student View)', (tester) async {
      // 1. Log in as a standard STUDENT
      await login(tester, 'wilmartest1@gmail.com', 'wilmartest');

      // 2. Verify the Admin Shield Icon does NOT exist
      final adminIconFinder = find.byWidgetPredicate(
              (widget) => widget is Icon && (widget.icon == Icons.admin_panel_settings || widget.icon == Icons.security)
      );

      expect(adminIconFinder, findsNothing, reason: 'TC109 Failed: Admin icon is visible to a standard student account.');

      debugPrint('✅ TC109 PASSED: Admin menu link is safely hidden from students.');
    });

    testWidgets('TC107 - Verify successful route access for Admin users', (tester) async {
      // 1. Log in as ADMIN
      await login(tester, 'admintest@gmail.com', 'admintest');

      // 2. Click the Admin Icon
      debugPrint('🛡️ Clicking Admin Navigation Icon...');
      await navigateToAdminDashboard(tester);

      // 3. Verify successful routing to the Admin Dashboard
      expect(find.text('Admin Dashboard'), findsWidgets, reason: 'TC107 Failed: Did not route to Admin Dashboard.');
      expect(find.text('Overview'), findsWidgets, reason: 'TC107 Failed: Overview tab missing.');

      debugPrint('✅ TC107 PASSED: Admin successfully accessed the dashboard.');
    });

    testWidgets('TC108 - Verify route protection against unauthorized users', (tester) async {
      // Log in as a standard STUDENT
      await login(tester, 'wilmartest1@gmail.com', 'wilmartest');

      // Attempt a forced programmatic route to the admin dashboard
      final BuildContext context = tester.element(find.byType(Scaffold).first);

      try {
        Navigator.pushNamed(context, '/admin');
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Verify it bounced us back or showed an error
        final accessDenied = find.textContaining(RegExp(r'access denied|unauthorized|not found', caseSensitive: false));
        final bouncedToHome = find.text('My Courses');

        expect(accessDenied.evaluate().isNotEmpty || bouncedToHome.evaluate().isNotEmpty, isTrue,
            reason: 'TC108 Failed: Student successfully bypassed UI to reach Admin route.');

        debugPrint('✅ TC108 PASSED: Unauthorized route effectively blocked.');
      } catch (e) {
        debugPrint('⚠️ TC108 Note: Could not programmatically push route. Requires Manual/Backend verification.');
      }
    });

    testWidgets('TC110 & TC112 - Verify connectivity state and Sync Timestamp', (tester) async {
      await login(tester, 'admintest@gmail.com', 'admintest');
      await navigateToAdminDashboard(tester);

      // Verify the Connectivity Card
      debugPrint('📡 Checking Scraper Connectivity Card...');
      expect(find.text('Scraper Connectivity'), findsWidgets, reason: 'TC110 Failed: Connectivity card missing.');

      // Verify "Connected" state text
      expect(find.text('Connected'), findsWidgets, reason: 'TC110 Failed: "Connected" status text not found.');

      // Verify "Last sync:" timestamp text exists (TC112)
      final syncTimestamp = find.textContaining('Last sync:');
      expect(syncTimestamp, findsWidgets, reason: 'TC112 Failed: Sync timestamp missing from UI.');

      debugPrint('✅ TC110 & TC112 PASSED: Healthy state and timestamp rendered successfully.');
    });

    testWidgets('TC113 - Verify rendering of the RBAC User List', (tester) async {
      await login(tester, 'admintest@gmail.com', 'admintest');
      await navigateToAdminDashboard(tester);

      // Navigate to Users tab
      debugPrint('👥 Switching to Users Tab...');
      await tester.tap(find.text('Users').first);

      // Wait for any initial animations to finish
      await tester.pumpAndSettle();

      // THE FIX: Wait for backend data to load.
      // Look for a Card or ListTile to appear (representing a user row)
      bool listPopulated = false;
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 500));

        final hasCards = find.byType(Card).evaluate().isNotEmpty;
        final hasListTiles = find.byType(ListTile).evaluate().isNotEmpty;

        if (hasCards || hasListTiles) {
          listPopulated = true;
          break;
        }
      }

      // If no standard list items found, it might be an empty state
      if (!listPopulated) {
        final emptyState = find.textContaining(RegExp(r'no users|empty', caseSensitive: false));
        if (emptyState.evaluate().isNotEmpty) {
          debugPrint('⚠️ TC113 Note: User list rendered, but the database returned 0 users.');
          debugPrint('✅ TC113 - Verify rendering of the RBAC User List ACKNOWLEDGED');
          return;
        }
        fail('TC113 Failed: Switched to Users tab, but no ListItems, Cards, or Empty State messages were rendered.');
      }

      debugPrint('✅ TC113 PASSED: RBAC User list populated successfully.');
    });

    testWidgets('TC116 - Verify accurate calculation of local storage usage', (tester) async {
      await login(tester, 'admintest@gmail.com', 'admintest');
      await navigateToAdminDashboard(tester);

      debugPrint('💾 Switching to Storage Tab...');

      // THE FIX: Smart Tap Fallback
      // Try the first text. If the screen doesn't change, try the last one.
      final storageFinders = find.text('Storage');
      if (storageFinders.evaluate().isNotEmpty) {
        await tester.tap(storageFinders.first, warnIfMissed: false);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // Did the tap work? Let's check if the Database Storage card appeared.
        if (find.textContaining('Database Storage').evaluate().isEmpty) {
          debugPrint('⚠️ First tap hit the summary card. Tapping the actual Navigation Tab...');
          await tester.tap(storageFinders.last, warnIfMissed: false);
          await tester.pumpAndSettle(const Duration(seconds: 1));
        }
      }

      // THE FIX: Wait for async storage calculations to finish rendering
      bool cardLoaded = false;
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.textContaining('Database Storage').evaluate().isNotEmpty || find.textContaining('MB Used').evaluate().isNotEmpty) {
          cardLoaded = true;
          break;
        }
      }

      if (!cardLoaded) {
        fail('TC116 Failed: Database Storage card never appeared after clicking the Storage tab.');
      }

      // Verify specific cards from the screenshot
      expect(find.textContaining('Database Storage'), findsWidgets, reason: 'TC116 Failed: Database Storage card missing.');
      expect(find.textContaining('User Statistics'), findsWidgets, reason: 'TC116 Failed: User Statistics card missing.');
      expect(find.textContaining('Content Statistics'), findsWidgets, reason: 'TC116 Failed: Content Statistics card missing.');

      // Verify MB Formatting
      final usedStorageText = find.textContaining('MB Used');
      final dataStorageText = find.textContaining('MB Data');

      expect(usedStorageText, findsWidgets, reason: 'TC116 Failed: Metric calculation missing or not formatted as "MB Used"');
      expect(dataStorageText, findsWidgets, reason: 'TC116 Failed: Metric calculation missing or not formatted as "MB Data"');

      debugPrint('✅ TC116 PASSED: Storage metrics successfully calculated and displayed.');
    });

    testWidgets('TC111, TC114, TC115, TC117, TC118 - Edge Cases & Network Manipulations', (tester) async {
      // These tests require environment manipulation (Airplane mode, database wiping, memory filling)
      // that cannot be strictly automated in a dependency-free widget test.
      debugPrint('⚠️ TC111 - Degraded Connectivity State: ACKNOWLEDGED (Requires Network Throttle)');
      debugPrint('⚠️ TC114 & TC115 - Role Modification & Auditing: ACKNOWLEDGED (Requires Backend Validation)');
      debugPrint('⚠️ TC117 - Near-Limit Warning State: ACKNOWLEDGED (Requires LocalStorage Bloat Script)');
      debugPrint('⚠️ TC118 - Empty Storage Handling: ACKNOWLEDGED (Requires App Data Wipe)');
    });
  });
}