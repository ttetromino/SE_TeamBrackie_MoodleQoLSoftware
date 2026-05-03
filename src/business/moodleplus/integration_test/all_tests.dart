// integration_test/all_tests.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Import all test files based on the project structure
import 'signup_test.dart' as signup;
import 'login_test.dart' as login;
import 'profile_test.dart' as profile;
import 'backlog_test.dart' as backlog;
import 'calendar_test.dart' as calendar;
import 'gradebook_test.dart' as gradebook;
import 'progresstracker_test.dart' as progresstracker;
import 'archive_test.dart' as archive;

void main() {
  // Initialize the binding exactly once for the entire suite
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Run all test files in a logical sequence
  group('Full MoodlePlus Integration Suite', () {

    // 1. Authentication & Onboarding
    signup.main();
    login.main();

    // 2. Core User Features
    profile.main();

    // 3. Primary Academic Tools
    backlog.main();
    calendar.main();
    gradebook.main();

    // 4. Secondary/Long-Term Features
    progresstracker.main();
    archive.main();

  });
}