// /lib/home_page.dart

import 'package:flutter/material.dart';
import 'dart:convert'; // US-03: Add this for jsonEncode
import 'package:shared_preferences/shared_preferences.dart'; // US-03: Add this
import 'services/lms_service.dart';
import 'course_contents_page.dart';
import 'services/biometric_service.dart';
import 'change_lms_password_page.dart';
import 'edit_profile_page.dart';

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

  // LMS State
  bool _isLMSLoggedIn = false;
  bool _lmsLoading = false;
  List<LmsCourse> _courses = [];
  String? _lmsErrorMessage;

  // US-07: Course Stats
  CourseStats _stats = CourseStats();

  final BiometricService _biometricService = BiometricService();
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;

  // Constants
  static const String baseUrl = 'http://10.0.2.2:5000';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _lmsService = LMSService(userId: widget.user['email']);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoLoginToLMS();
    });
    _checkBiometricStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // US-03: Navigate to Edit Profile
  // US-03: Navigate to Edit Profile
  Future<void> _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfilePage(
          user: widget.user,
          onProfileUpdated: (updatedUser) {
            // COMPLETELY REPLACE the user object with the updated one
            setState(() {
              widget.user['name'] = updatedUser['name'];
              widget.user['email'] = updatedUser['email'];
              widget.user['lmsUsername'] = updatedUser['lmsUsername'];
              if (updatedUser['profilePicture'] != null) {
                widget.user['profilePicture'] = updatedUser['profilePicture'];
              }
            });

            // Also update stored user data
            _updateStoredUser(widget.user);

            // Show a snackbar confirming the update
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

  // US-03: Update stored user data (ONLY ONE METHOD - remove the duplicate)
  Future<void> _updateStoredUser(Map<String, dynamic> updatedUser) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(updatedUser));
  }

  // Auto-login to LMS
  Future<void> _autoLoginToLMS() async {
    setState(() {
      _lmsLoading = true;
      _lmsErrorMessage = null;
    });

    print('🔄 Attempting auto-login...');
    bool success = await _lmsService.autoLoginLMS();
    print('Auto-login result: $success');

    if (success) {
      print('✅ Auto-login successful - session exists');
      setState(() {
        _isLMSLoggedIn = true;
        _lmsLoading = false;
      });
      _loadCourses();
    } else {
      print('⚠️ Auto-login failed - no valid session');
      await Future.delayed(const Duration(seconds: 1));
      print('🔄 Retrying auto-login...');
      bool retrySuccess = await _lmsService.autoLoginLMS();

      if (retrySuccess) {
        print('✅ Auto-login successful on retry');
        setState(() {
          _isLMSLoggedIn = true;
          _lmsLoading = false;
        });
        _loadCourses();
      } else {
        print('❌ Auto-login failed on retry');
        setState(() {
          _isLMSLoggedIn = false;
          _lmsLoading = false;
        });
      }
    }
  }

  Future<void> _loadCourses() async {
    setState(() {
      _lmsLoading = true;
      _lmsErrorMessage = null;
    });

    List<LmsCourse> courses = await _lmsService.getCourses();

    CourseStats stats = await _lmsService.getAllCoursesStats(courses);

    setState(() {
      _courses = courses;
      _stats = stats;
      _lmsLoading = false;
    });

    if (courses.isEmpty) {
      setState(() {
        _lmsErrorMessage = 'No courses found';
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

              if (success) {
                setState(() {
                  _isLMSLoggedIn = true;
                  _lmsLoading = false;
                });
                _loadCourses();
              } else {
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
            onPressed: () {
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
    setState(() {
      _biometricAvailable = available;
      _biometricEnabled = enabled;
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MoodlePlus Home'),
        backgroundColor: const Color(0xFF9D2BD1),
        foregroundColor: Colors.white,
        actions: [
          // US-03: Edit Profile button
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Profile', icon: Icon(Icons.person)),
            Tab(text: 'My Courses', icon: Icon(Icons.school)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildProfileTab(), _buildCoursesTab()],
      ),
    );
  }

  Widget _buildProfileTab() {
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
                        value: _courses.isEmpty ? '0' : 'Available',
                        label: 'Contents',
                        color: Colors.green,
                      ),
                    ],
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9D2BD1)),
            ),
            const SizedBox(height: 16),
            Text(
              _isLMSLoggedIn
                  ? 'Loading your courses...'
                  : 'Connecting to LMS...',
              style: const TextStyle(fontSize: 16),
            ),
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

    if (_courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No Courses Found',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'You are not enrolled in any courses yet',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadCourses,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9D2BD1),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCourses,
      color: const Color(0xFF9D2BD1),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _courses.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildProgressWidget(
              totalTasks: _stats.totalTasks,
              completedTasks: _stats.completedTasks,
              totalQuizzes: _stats.totalQuizzes,
              completedQuizzes: _stats.completedQuizzes,
              totalAssignments: _stats.totalAssignments,
              completedAssignments: _stats.completedAssignments,
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
                courseUrl: course.link,
                lmsService: _lmsService,
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

  // US-07: Progress Tracker
  Widget _buildProgressWidget({
    required int totalTasks,
    required int completedTasks,
    required int totalQuizzes,
    required int completedQuizzes,
    required int totalAssignments,
    required int completedAssignments,
  }) {
    int total = totalTasks + totalQuizzes + totalAssignments;
    int completed = completedTasks + completedQuizzes + completedAssignments;

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
      child: Row(
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
                  "New Tasks Today",
                  totalTasks - completedTasks,
                  Colors.red,
                ),
                _buildProgressRow(
                  "Upcoming Quiz",
                  totalQuizzes - completedQuizzes,
                  Colors.orange,
                ),
                _buildProgressRow(
                  "Assignments",
                  totalAssignments - completedAssignments,
                  Colors.purple,
                ),
                const SizedBox(height: 8),

                // US-07: PROGRESS BAR
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        Container(
                          height: 10,
                          color: const Color(0xFF9D2BD1),
                        ),

                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: percent,
                          child: Container(
                            height: 10,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.red,
                                  Colors.orange,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
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
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(title),
        ],
      ),
    );
  }
}