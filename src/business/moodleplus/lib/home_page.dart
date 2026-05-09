// /lib/home_page.dart

import 'package:flutter/material.dart';
import 'dart:convert'; // US-03: Add this for jsonEncode
import 'package:shared_preferences/shared_preferences.dart'; // US-03: Add this
import 'services/lms_service.dart';
import 'course_contents_page.dart';
import 'services/biometric_service.dart';
import 'change_lms_password_page.dart';
import 'edit_profile_page.dart';
import 'archived_courses_page.dart';
import 'services/archive_service.dart';
import 'backlog_page.dart';
import 'gradebook_page.dart';
import 'calendar_page.dart';
import 'services/course_service.dart';
import 'package:http/http.dart' as http;
import 'services/notification_service.dart';
import 'services/backlog_service.dart';
import 'services/admin_service.dart';
import 'admin_dashboard_page.dart';
import 'config/api_config.dart';

class HomePage extends StatefulWidget {
  final Map<String, dynamic> user;

  const HomePage({super.key, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late LMSService _lmsService;
  late ArchiveService _archiveService;
  late CourseService _courseService;
  late BacklogService _backlogService;

  final NotificationService _notificationService = NotificationService();

  bool _notificationsEnabled = true;
  bool _isAdmin = false;
  bool _isCheckingAdmin = true;
  List<ArchivedCourse> _archivedCourses = [];

  // LMS State
  bool _isLMSLoggedIn = false;
  bool _lmsLoading = false;
  bool _isSyncing = false;
  List<LmsCourse> _courses = [];
  String? _lmsErrorMessage;

  // US-07: Course Stats
  CourseStats _stats = CourseStats();

  final BiometricService _biometricService = BiometricService();
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;

  // Constants
  static const String baseUrl = ApiConfig.baseUrl;

  // Flag to prevent duplicate auto-login
  bool _isAutoLoggingIn = false;
  bool _hasCheckedSession = false;

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _courseService = CourseService();
    _backlogService = BacklogService();
    _tabController = TabController(length: 5, vsync: this);
    _lmsService = LMSService(userId: widget.user['email']);
    _archiveService = ArchiveService();
    _checkAdminStatus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoLoginToLMS();
      _loadArchivedCourses();
    });
    _checkBiometricStatus();
  }

  Future<void> _checkAdminStatus() async {
    print('🔐🔐🔐 CHECKING ADMIN STATUS for: ${widget.user['email']}');
    final adminService = AdminService();
    final isAdmin = await adminService.isAdmin(widget.user['email']);
    print('🔐🔐🔐 RESULT: isAdmin = $isAdmin');
    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
        _isCheckingAdmin = false;
      });
      print('🔐🔐🔐 _isAdmin set to: $_isAdmin');
    }
  }

  Future<void> _refreshStatsFromBacklog() async {
    if (!_isLMSLoggedIn) return;
    if (!mounted) return;

    print('🔄 Refreshing stats from backlog...');

    try {
      // First, sync backlog to get latest data
      await _backlogService.syncBacklog(widget.user['email']);

      // Then get backlog items
      final response = await http.get(
        Uri.parse('$baseUrl/api/backlog/items/${widget.user['email']}?showCompleted=true'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> allItems = data['items'] ?? [];

        int totalQuizzes = 0;
        int completedQuizzes = 0;
        int totalAssignments = 0;
        int completedAssignments = 0;

        for (final item in allItems) {
          final type = item['activityType'];
          final isCompleted = item['isCompleted'] ?? false;

          if (type == 'quiz') {
            totalQuizzes++;
            if (isCompleted) completedQuizzes++;
          } else if (type == 'assign') {
            totalAssignments++;
            if (isCompleted) completedAssignments++;
          }
        }

        final totalTasks = totalQuizzes + totalAssignments;
        final completedTasks = completedQuizzes + completedAssignments;

        print('📊 BACKLOG STATS:');
        print('   Total: $completedTasks/$totalTasks');
        print('   Quizzes: $completedQuizzes/$totalQuizzes');
        print('   Assignments: $completedAssignments/$totalAssignments');

        if (mounted) {
          setState(() {
            _stats = CourseStats(
              totalTasks: 0,
              completedTasks: 0,
              totalQuizzes: totalQuizzes,
              completedQuizzes: completedQuizzes,
              totalAssignments: totalAssignments,
              completedAssignments: completedAssignments,
            );
          });
        }
      } else if (response.statusCode == 404) {
        print('⚠️ No backlog found for user');
      }
    } catch (e) {
      print('Refresh stats from backlog error: $e');
    }
  }

  Future<void> _refreshCourseStats() async {
    if (!_isLMSLoggedIn) return;
    if (!mounted) return;

    await _refreshStatsFromBacklog();
  }

  Future<void> _initNotifications() async {
    await _notificationService.initialize();

    // Set deep linking callback
    _notificationService.onNotificationTap = (courseId, activityId, activityUrl) {
      _navigateToTask(courseId, activityId, activityUrl);
    };

    // Load preferences and start polling
    final prefs = await _notificationService.getPreferences(widget.user['email']);
    _notificationsEnabled = prefs['enabled24h'] ?? true;

    if (_notificationsEnabled) {
      _notificationService.startPolling(widget.user['email']);
    }
  }

  void _navigateToTask(String courseId, String activityId, String activityUrl) {
    // Navigate to the specific task/course
    // Find course by ID and navigate to its contents
    final course = _courses.firstWhere(
          (c) => c.id == courseId,
      orElse: () => LmsCourse(id: '', name: '', link: ''),
    );

    if (course.id.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CourseContentsPage(
            courseName: course.name,
            courseId: course.id,
            email: widget.user['email'],
          ),
        ),
      );
    }
  }

  Future<void> _manualSyncCourses() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
      _lmsErrorMessage = null;
    });

    // Show loading dialog for first-time sync
    if (_courses.isEmpty) {
      _showSyncProgressDialog();
    }

    try {
      print('🔄 Manual sync triggered for ${widget.user['email']}');

      final response = await http.post(
        Uri.parse('$baseUrl/api/course/sync-all'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.user['email']}),
      );

      final data = jsonDecode(response.body);
      print('📥 Sync response: ${response.statusCode}');

      // Close dialog if it was shown
      if (_courses.isEmpty && mounted) {
        Navigator.pop(context);
      }

      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Sync started! Loading courses...'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );

        // AUTO-REFRESH - Poll for courses to appear
        await _waitForCoursesAndRefresh();

      } else {
        throw Exception(data['error'] ?? 'Sync failed');
      }
    } catch (e) {
      print('Sync error: $e');
      if (_courses.isEmpty && mounted) {
        Navigator.pop(context);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

// New method: Wait for courses and auto-refresh
  Future<void> _waitForCoursesAndRefresh() async {
    int attempts = 0;
    const maxAttempts = 30; // 30 seconds max

    print('⏳ Waiting for courses to sync...');

    while (attempts < maxAttempts && mounted) {
      await Future.delayed(const Duration(seconds: 2));

      // Try to load courses from database
      final storedCourses = await _courseService.getStoredCourses(widget.user['email']);

      if (storedCourses.isNotEmpty) {
        // Courses found! Refresh the UI
        print('✅ Found ${storedCourses.length} courses, refreshing UI...');

        await _loadCourses();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully loaded ${storedCourses.length} courses!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      attempts++;
      print('⏳ Waiting for courses... attempt $attempts/$maxAttempts');
    }

    // Timeout - courses didn't appear
    if (mounted) {
      print('⚠️ Timeout waiting for courses');
      await _loadCourses(); // Try one final refresh

      final finalCheck = await _courseService.getStoredCourses(widget.user['email']);
      if (finalCheck.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync completed but no courses found. Try refreshing manually.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

// Add this method for showing sync progress dialog
  void _showSyncProgressDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9D2BD1)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Syncing Your Courses',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This may take a moment...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your courses are being loaded from LMS. You will be notified when complete.',
                      style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

// Poll for courses to appear after sync
  Future<void> _pollForCourses() async {
    int attempts = 0;
    const maxAttempts = 30; // 30 seconds max

    while (attempts < maxAttempts && mounted) {
      await Future.delayed(const Duration(seconds: 2));

      final storedCourses = await _courseService.getStoredCourses(widget.user['email']);

      if (storedCourses.isNotEmpty) {
        await _loadCourses();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully loaded ${storedCourses.length} courses!'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      attempts++;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sync taking longer than expected. Try refreshing manually.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _forceSyncCourses() async {
    if (!_isLMSLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to LMS first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _lmsLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/course/sync-all'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.user['email']}),
      );

      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Synced ${data['coursesCount']} courses!'),
            backgroundColor: Colors.green,
          ),
        );
        // Reload courses
        await _loadCourses();
      } else {
        throw Exception('Sync failed');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _lmsLoading = false;
        });
      }
    }
  }

  // Load archived courses for count display
  Future<void> _loadArchivedCourses() async {
    final courses = await _archiveService.getArchivedCourses(
      widget.user['email'],
    );
    if (mounted) {
      setState(() {
        _archivedCourses = courses;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // US-03: Navigate to Edit Profile
  Future<void> _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfilePage(
          user: widget.user,
          onProfileUpdated: (updatedUser) {
            setState(() {
              widget.user['name'] = updatedUser['name'];
              widget.user['email'] = updatedUser['email'];
              widget.user['lmsUsername'] = updatedUser['lmsUsername'];
              if (updatedUser['profilePicture'] != null) {
                widget.user['profilePicture'] = updatedUser['profilePicture'];
              }
            });

            _updateStoredUser(widget.user);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile updated successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
      ),
    );

    if (result == true) {
      _loadCourses();
    }
  }

  // US-03: Update stored user data
  Future<void> _updateStoredUser(Map<String, dynamic> updatedUser) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(updatedUser));
  }

  // Auto-login to LMS - FIXED to prevent duplicate calls
  Future<void> _autoLoginToLMS() async {
    // PREVENT duplicate calls
    if (_isAutoLoggingIn) {
      print('⚠️ Auto-login already in progress, skipping...');
      return;
    }

    // Check if we already have a valid session from biometric login
    final prefs = await SharedPreferences.getInstance();
    final hasLmsSession = prefs.getString('lms_session_${widget.user['email']}') != null;

    if (hasLmsSession && !_hasCheckedSession) {
      print('✅ Existing LMS session found from biometric login, skipping auto-login');
      _hasCheckedSession = true;
      setState(() {
        _isLMSLoggedIn = true;
        _lmsLoading = false;
      });
      _loadCourses();
      return;
    }

    setState(() {
      _lmsLoading = true;
      _lmsErrorMessage = null;
      _isAutoLoggingIn = true;
    });

    print('🔄 Attempting auto-login...');
    bool success = await _lmsService.autoLoginLMS();
    print('Auto-login result: $success');

    if (success) {
      print('✅ Auto-login successful - session exists');
      await prefs.setString('lms_session_${widget.user['email']}', DateTime.now().toIso8601String());
      setState(() {
        _isLMSLoggedIn = true;
        _lmsLoading = false;
        _isAutoLoggingIn = false;
      });
      _loadCourses();
    } else {
      print('⚠️ Auto-login failed - no valid session');
      await Future.delayed(const Duration(seconds: 1));
      print('🔄 Retrying auto-login...');
      bool retrySuccess = await _lmsService.autoLoginLMS();

      if (retrySuccess) {
        print('✅ Auto-login successful on retry');
        await prefs.setString('lms_session_${widget.user['email']}', DateTime.now().toIso8601String());
        setState(() {
          _isLMSLoggedIn = true;
          _lmsLoading = false;
          _isAutoLoggingIn = false;
        });
        _loadCourses();
      } else {
        print('❌ Auto-login failed on retry');
        setState(() {
          _isLMSLoggedIn = false;
          _lmsLoading = false;
          _isAutoLoggingIn = false;
        });
      }
    }
  }

  Future<void> _loadCourses() async {
    if (!mounted) return;

    setState(() {
      _lmsLoading = true;
      _lmsErrorMessage = null;
    });

    try {
      List<StoredCourse> storedCourses = await _courseService.getStoredCourses(widget.user['email']);

      if (storedCourses.isNotEmpty) {
        _courses = storedCourses.map((c) => LmsCourse(
          id: c.courseId,
          name: c.courseName,
          link: c.courseUrl,
        )).toList();

        print('✅ Loaded ${_courses.length} courses from database');

        // CRITICAL: Use backlog stats for accurate counts
        await _refreshStatsFromBacklog();

        print('✅ Stats loaded - Total: ${_stats.totalQuizzes + _stats.totalAssignments}');
      } else {
        _courses = [];
        print('⚠️ No courses found in database');
      }

      if (mounted) {
        setState(() {
          _lmsLoading = false;
        });
      }
    } catch (e) {
      print('Load courses error: $e');
      if (mounted) {
        setState(() {
          _lmsLoading = false;
          _lmsErrorMessage = 'Failed to load courses: $e';
        });
      }
    }
  }


  // Background sync for fresh data
  Future<void> _syncFreshCourseData() async {
    // Sync each course to get latest completion status
    for (final course in _courses) {
      await _courseService.syncCourse(
        email: widget.user['email'],
        courseId: course.id,
        courseName: course.name,
        courseUrl: course.link,
        forceRefresh: false, // Only sync if cache is old
      );
    }

    // Refresh stats
    final statsData = await _courseService.getCourseStats(widget.user['email']);
    if (mounted) {
      setState(() {
        _stats = CourseStats(
          totalTasks: statsData.totalTasks,
          completedTasks: statsData.completedTasks,
          totalQuizzes: statsData.totalQuizzes,
          completedQuizzes: statsData.completedQuizzes,
          totalAssignments: statsData.totalAssignments,
          completedAssignments: statsData.completedAssignments,
        );
      });
    }
  }

  Future<void> _manualLMSLogin() async {
    _promptForLMSPassword();
  }

  void _promptForLMSPassword() {
    String lmsPassword = '';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('LMS Login Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please enter your LMS password to access your courses:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Color(0xFF9D2BD1)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.user['lmsUsername'],
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'LMS Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              onChanged: (value) => lmsPassword = value,
              autofocus: true,
            ),
          ],
        ),

        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showLogoutConfirmation();
            },
            child: const Text('Logout from App'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (lmsPassword.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password is required'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              setState(() {
                _lmsLoading = true;
                _lmsErrorMessage = null;
              });

              bool success = await _lmsService.loginToLMS(
                widget.user['lmsUsername'],
                lmsPassword,
              );

              if (success && mounted) {
                // Store session flag
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('lms_session_${widget.user['email']}', DateTime.now().toIso8601String());

                setState(() {
                  _isLMSLoggedIn = true;
                  _lmsLoading = false;
                });
                _loadCourses();
              } else if (mounted) {
                setState(() {
                  _lmsLoading = false;
                  _lmsErrorMessage = 'Login failed. Please try again.';
                });
                _showErrorDialog(
                  'Login Failed',
                  'Invalid LMS credentials. Please try again.',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9D2BD1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Login to LMS'),
          ),
        ],

      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout from the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Clear LMS session flag on logout
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('lms_session_${widget.user['email']}');

              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9D2BD1),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }



  Future<void> _checkBiometricStatus() async {
    final available = await _biometricService.isBiometricAvailable();
    final enabled = await _biometricService.isBiometricEnabledForUser(
      widget.user['email'],
    );
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled;
      });
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      final enabled = await _biometricService.enableBiometric(
        widget.user['email'],
      );
      if (enabled && mounted) {
        setState(() => _biometricEnabled = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric login enabled!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to enable biometric login'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      final disabled = await _biometricService.disableBiometric(
        widget.user['email'],
      );
      if (disabled && mounted) {
        setState(() => _biometricEnabled = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric login disabled'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }



  // Navigate to archived courses

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moodle+'),
        backgroundColor: const Color(0xFF9D2BD1),
        foregroundColor: Colors.white,
        actions: [
          if (!_isCheckingAdmin && _isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminDashboardPage(
                      adminEmail: widget.user['email'],
                    ),
                  ),
                );
              },
              tooltip: 'Admin Dashboard',
            ),
          // Sync/Update button
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.cloud_sync),
            onPressed: _isSyncing ? null : _manualSyncCourses,
            tooltip: 'Sync/Update Courses',
          ),
          // Archive button
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.archive),
                onPressed: _navigateToArchivedCourses,
                tooltip: 'Archived Records',
              ),
              if (_archivedCourses.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${_archivedCourses.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _navigateToEditProfile,
            tooltip: 'Edit Profile',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _showLogoutConfirmation,
            tooltip: 'Logout',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            key: const Key('home_tab_bar'),
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(text: 'Profile', icon: Icon(Icons.person)),
              Tab(text: 'My Courses', icon: Icon(Icons.school)),
              Tab(text: 'Backlog', icon: Icon(Icons.task)),
              Tab(text: 'Gradebook', icon: Icon(Icons.grade)),
              Tab(text: 'Calendar', icon: Icon(Icons.calendar_month)),
            ],
          ),
        ),
      ),
      body: TabBarView(
        key: const Key('home_tab_view'),
        controller: _tabController,
        children: [
          _buildProfileTab(),
          _buildCoursesTab(),
          BacklogPage(email: widget.user['email'], onTaskCompleted: _refreshCourseStats),
          GradebookPage(email: widget.user['email']),
          CalendarPage(email: widget.user['email']),
        ],
      ),
    );
  }
  Future<void> _navigateToArchivedCourses() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArchivedCoursesPage(
          email: widget.user['email'],
          lmsService: _lmsService,
        ),
      ),
    );
    _loadArchivedCourses();
  }

  Widget _buildProfileTab() {
    // Calculate total tasks (quizzes + assignments) for display
    int totalTasks = _stats.totalQuizzes + _stats.totalAssignments;
    int completedTasks = _stats.completedQuizzes + _stats.completedAssignments;
    int remainingTasks = totalTasks - completedTasks;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9D2BD1), Color(0xFF6B1B9A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    widget.user['name'][0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 50,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              if (_isLMSLoggedIn)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            widget.user['name'],
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.user['email'],
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ),
          const SizedBox(height: 32),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Account Information',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    icon: Icons.person_outline,
                    label: 'Full Name',
                    value: widget.user['name'],
                  ),
                  const Divider(height: 24),
                  _buildInfoRow(
                    icon: Icons.email_outlined,
                    label: 'Email Address',
                    value: widget.user['email'],
                  ),
                  const Divider(height: 24),
                  _buildInfoRow(
                    icon: Icons.school_outlined,
                    label: 'LMS Username',
                    value: widget.user['lmsUsername'],
                  ),
                  const Divider(height: 24),
                  _buildInfoRow(
                    icon: Icons.check_circle_outline,
                    label: 'LMS Status',
                    value: _isLMSLoggedIn ? 'Connected' : 'Disconnected',
                    valueColor: _isLMSLoggedIn ? Colors.green : Colors.orange,
                  ),
                  if (_biometricAvailable) ...[
                    const Divider(height: 24),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9D2BD1).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.fingerprint,
                            size: 20,
                            color: Color(0xFF9D2BD1),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Biometric Login',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'Use fingerprint or face ID to login',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _biometricEnabled,
                          onChanged: _toggleBiometric,
                          activeColor: const Color(0xFF9D2BD1),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF9D2BD1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 20,
                  color: Color(0xFF9D2BD1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LMS Password',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Change your uphslms.com password',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChangeLMSPasswordPage(
                        lmsService: _lmsService,
                        email: widget.user['email'],
                      ),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF9D2BD1),
                ),
                child: const Text('Change'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Course Statistics',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        icon: Icons.menu_book,
                        value: _courses.length.toString(),
                        label: 'Courses',
                        color: const Color(0xFF9D2BD1),
                      ),
                      Container(height: 40, width: 1, color: Colors.grey[300]),
                      _buildStatItem(
                        icon: Icons.assignment,
                        value: totalTasks.toString(),
                        label: 'Total Tasks',
                        color: Colors.blue,
                      ),
                      Container(height: 40, width: 1, color: Colors.grey[300]),
                      _buildStatItem(
                        icon: Icons.check_circle,
                        value: remainingTasks.toString(),
                        label: 'Remaining',
                        color: Colors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: totalTasks > 0 ? completedTasks / totalTasks : 0,
                    backgroundColor: Colors.grey[200],
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(8),
                    minHeight: 8,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$completedTasks of $totalTasks completed',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF9D2BD1).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF9D2BD1)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildCoursesTab() {
    if (_lmsLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9D2BD1)),
            ),
            SizedBox(height: 16),
            Text('Loading your courses...'),
          ],
        ),
      );
    }

    if (!_isLMSLoggedIn) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.school, size: 60, color: Colors.orange),
              ),
              const SizedBox(height: 24),
              const Text(
                'Not Connected to LMS',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Username: ${widget.user['lmsUsername']}',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              if (_lmsErrorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _lmsErrorMessage!,
                  style: const TextStyle(fontSize: 14, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _manualLMSLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9D2BD1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Login to LMS',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _autoLoginToLMS,
                child: const Text('Retry Auto-Connect'),
              ),
            ],
          ),
        ),
      );
    }

    // Show sync button prominently if no courses
    if (_courses.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9D2BD1).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_sync,
                    size: 60,
                    color: Color(0xFF9D2BD1),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'No Courses Found',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your LMS courses haven\'t been synced yet.',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'What happens when you sync?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Your enrolled courses will appear here\n'
                            '• Course activities will be cached locally\n'
                            '• You can track your progress\n'
                            '• You only need to do this once',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'First sync may take 30-60 seconds depending on your courses',
                        style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 250,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isSyncing ? null : _manualSyncCourses,
                    icon: _isSyncing
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.cloud_sync, size: 28),
                    label: Text(
                      _isSyncing ? 'SYNCING...' : 'SYNC COURSES NOW',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9D2BD1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _loadCourses,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _refreshStatsFromBacklog();
        await _loadCourses();
      },
      color: const Color(0xFF9D2BD1),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _courses.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            // Add a small update button above progress widget
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: _isSyncing ? null : _manualSyncCourses,
                        icon: _isSyncing
                            ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF9D2BD1),
                          ),
                        )
                            : const Icon(Icons.cloud_sync, size: 16),
                        label: Text(
                          _isSyncing ? 'Syncing...' : 'Update Courses',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF9D2BD1),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildProgressWidget(
                  totalTasks: _stats.totalTasks,
                  completedTasks: _stats.completedTasks,
                  totalQuizzes: _stats.totalQuizzes,
                  completedQuizzes: _stats.completedQuizzes,
                  totalAssignments: _stats.totalAssignments,
                  completedAssignments: _stats.completedAssignments,
                ),
              ],
            );
          }
          final course = _courses[index - 1];
          return _buildCourseCard(course);
        },
      ),
    );
  }

  Widget _buildCourseCard(LmsCourse course) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CourseContentsPage(
                courseName: course.name,
                courseId: course.id,  // Changed: use courseId instead of courseUrl
                email: widget.user['email'],
                onActivityCompleted: _refreshCourseStats,// Changed: pass email
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9D2BD1), Color(0xFF6B1B9A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.menu_book,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.folder, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          'Tap to view contents',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showArchiveConfirmation(course),
                icon: const Icon(Icons.archive_outlined, color: Colors.orange),
                tooltip: 'Archive Course',
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF9D2BD1).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Color(0xFF9D2BD1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showArchiveConfirmation(LmsCourse course) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.archive, color: Colors.orange),
            SizedBox(width: 8),
            Text('Archive Course'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to archive "${course.name}"?',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Archived courses can be viewed later in the Archive tab and will no longer appear in your active courses list.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This action can be undone.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _lmsLoading = true);

      final result = await _archiveService.archiveCourse(
        email: widget.user['email'],
        courseId: course.id,
        courseName: course.name,
        courseUrl: course.link,
      );

      setState(() => _lmsLoading = false);

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${course.name}" has been archived'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
        _loadCourses();
        _loadArchivedCourses();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to archive course'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildProgressWidget({
    required int totalTasks,
    required int completedTasks,
    required int totalQuizzes,
    required int completedQuizzes,
    required int totalAssignments,
    required int completedAssignments,
  }) {
    // Calculate remaining tasks
    int total = totalQuizzes + totalAssignments;
    int completed = completedQuizzes + completedAssignments;
    int remaining = total - completed;
    double percent = total == 0 ? 0 : completed / total;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress percentage
          Row(
            children: [
              Container(
                width: 70,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    "${(percent * 100).toInt()}%",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProgressRow(
                      "Remaining Tasks",
                      remaining,
                      Colors.red,
                    ),
                    _buildProgressRow(
                      "Quizzes Remaining",
                      totalQuizzes - completedQuizzes,
                      Colors.orange,
                    ),
                    _buildProgressRow(
                      "Assignments Remaining",
                      totalAssignments - completedAssignments,
                      Colors.purple,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Container(height: 10, color: Colors.grey.shade300),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: percent,
                    child: Container(
                      height: 10,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF9D2BD1), Color(0xFF6B1B9A)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$completed of $total tasks completed',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRow(String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            "$count ",
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
          Text(title),
        ],
      ),
    );
  }


  Widget _buildNotificationSettingsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9D2BD1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.notifications_active, size: 20, color: Color(0xFF9D2BD1)),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Notification Settings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('24-hour reminders'),
              subtitle: const Text('Get notified 24 hours before deadline'),
              value: _notificationsEnabled,
              onChanged: (value) async {
                setState(() => _notificationsEnabled = value);
                await _notificationService.savePreferences(
                  widget.user['email'],
                  value,
                  true, // Keep 3-hour as true for now
                );
                if (value) {
                  _notificationService.startPolling(widget.user['email']);
                } else {
                  _notificationService.stopPolling();
                }
              },
              activeColor: const Color(0xFF9D2BD1),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Notifications will appear even when the app is closed. '
                          'Tap a notification to go directly to the task.',
                      style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}