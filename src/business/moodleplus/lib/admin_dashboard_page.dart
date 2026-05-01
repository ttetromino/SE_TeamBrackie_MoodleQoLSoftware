// lib/admin_dashboard_page.dart
import 'package:flutter/material.dart';
import 'services/admin_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminDashboardPage extends StatefulWidget {
  final String adminEmail;

  const AdminDashboardPage({super.key, required this.adminEmail});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  late AdminService _adminService;
  late TabController _tabController;

  bool _isLoading = true;
  ScraperStatus? _scraperStatus;
  StorageStats? _storageStats;
  List<AdminUser> _users = [];
  AdminUser? _selectedUser;
  List<UserCourse> _selectedUserCourses = [];
  List<dynamic> _selectedUserBacklog = [];
  bool _isRefreshing = false;

  Color _getStatusColor(String? statusHex) {
    if (statusHex == null) return Colors.grey;
    String hex = statusHex;
    if (hex.startsWith('#')) {
      hex = hex.substring(1);
    }
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  void initState() {
    super.initState();
    _adminService = AdminService();
    _tabController = TabController(length: 3, vsync: this);
    _loadDashboard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);

    await Future.wait([
      _loadScraperStatus(),
      _loadStorageStats(),
      _loadUsers(),
    ]);

    setState(() => _isLoading = false);
  }

  Future<void> _loadScraperStatus() async {
    final status = await _adminService.getScraperStatus(widget.adminEmail);
    if (mounted) {
      setState(() => _scraperStatus = status);
    }
  }

  Future<void> _loadStorageStats() async {
    final stats = await _adminService.getStorageStats(widget.adminEmail);
    if (mounted) {
      setState(() => _storageStats = stats);
    }
  }

  Future<void> _loadUsers() async {
    final users = await _adminService.getAllUsers(widget.adminEmail);
    if (mounted) {
      setState(() => _users = users);
    }
  }

  Future<void> _refreshDashboard() async {
    setState(() => _isRefreshing = true);
    await _loadDashboard();
    setState(() => _isRefreshing = false);
  }

  Future<void> _viewUserDetails(AdminUser user) async {
    setState(() {
      _selectedUser = user;
    });

    // Load user courses and backlog
    final courses = await _adminService.getUserCourses(widget.adminEmail, user.email);
    final backlog = await _adminService.getUserBacklog(widget.adminEmail, user.email);

    setState(() {
      _selectedUserCourses = courses;
      _selectedUserBacklog = backlog;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return _buildUserDetailsSheet(scrollController);
        },
      ),
    );
  }

  Future<void> _forceUserSync(AdminUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Force Sync'),
        content: Text('Trigger a full sync for ${user.name}?'),
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
            child: const Text('Sync Now'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isRefreshing = true);

      final success = await _adminService.forceUserSync(widget.adminEmail, user.email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Sync triggered for ${user.name}' : 'Sync failed'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        await _loadUsers();
      }

      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _removeUser(AdminUser user) async {
    if (user.email == widget.adminEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot remove your own admin account'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove User'),
        content: Text('Are you sure you want to remove ${user.name}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isRefreshing = true);

      final success = await _adminService.removeUser(widget.adminEmail, user.email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '${user.name} removed' : 'Failed to remove user'),
            backgroundColor: success ? Colors.orange : Colors.red,
          ),
        );
        await _loadUsers();
      }

      setState(() => _isRefreshing = false);
    }
  }

  Widget _buildUserDetailsSheet(ScrollController scrollController) {
    if (_selectedUser == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final user = _selectedUser!;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF9D2BD1).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          user.name[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF9D2BD1),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            user.email,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: user.role == 'admin'
                                  ? Colors.purple.withOpacity(0.1)
                                  : Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              user.role.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: user.role == 'admin' ? Colors.purple : Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          // Tabs
          Expanded(
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Stats', icon: Icon(Icons.bar_chart)),
                      Tab(text: 'Courses', icon: Icon(Icons.school)),
                      Tab(text: 'Backlog', icon: Icon(Icons.task)),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildUserStatsTab(user),
                        _buildUserCoursesTab(),
                        _buildUserBacklogTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _forceUserSync(user),
                    icon: const Icon(Icons.sync),
                    label: const Text('Force Sync'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _removeUser(user),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserStatsTab(AdminUser user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildStatsCard(
            title: 'Course Progress',
            children: [
              _buildStatRow('Active Courses', user.courseCount),
              _buildStatRow('Archived Courses', user.archivedCount),
              const Divider(),
              _buildStatRow('Tasks Completed', '${user.completedTasks}/${user.totalTasks}'),
              LinearProgressIndicator(
                value: user.totalTasks > 0 ? user.completedTasks / user.totalTasks : 0,
                backgroundColor: Colors.grey[200],
                color: Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatsCard(
            title: 'Backlog Stats',
            children: [
              _buildStatRow('Total Backlog Items', user.backlogCount),
              _buildStatRow('Completed', user.completedBacklogCount),
              _buildStatRow('Pending', user.backlogCount - user.completedBacklogCount),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatsCard(
            title: 'Account Info',
            children: [
              _buildStatRow('LMS Username', user.lmsUsername),
              _buildStatRow(
                'Last LMS Login',
                user.lmsLastLogin != null
                    ? '${user.lmsLastLogin!.day}/${user.lmsLastLogin!.month}/${user.lmsLastLogin!.year}'
                    : 'Never',
              ),
              _buildStatRow(
                'Account Created',
                '${user.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserCoursesTab() {
    if (_selectedUserCourses.isEmpty) {
      return const Center(
        child: Text('No courses found for this user'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _selectedUserCourses.length,
      itemBuilder: (context, index) {
        final course = _selectedUserCourses[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              course.isArchived ? Icons.archive : Icons.school,
              color: course.isArchived ? Colors.orange : const Color(0xFF9D2BD1),
            ),
            title: Text(
              course.courseName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${course.completedActivities}/${course.totalActivities} completed',
            ),
            trailing: course.isArchived
                ? const Icon(Icons.archive_outlined, color: Colors.grey)
                : null,
          ),
        );
      },
    );
  }

  Widget _buildUserBacklogTab() {
    if (_selectedUserBacklog.isEmpty) {
      return const Center(
        child: Text('No backlog items for this user'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _selectedUserBacklog.length,
      itemBuilder: (context, index) {
        final item = _selectedUserBacklog[index];
        final isCompleted = item['isCompleted'] ?? false;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              item['activityType'] == 'quiz' ? Icons.quiz : Icons.assignment,
              color: isCompleted ? Colors.green : Colors.orange,
            ),
            title: Text(
              item['activityName'] ?? 'Unknown',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${item['courseCode'] ?? 'Unknown'} • ${item['priority'] ?? 'medium'}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            trailing: isCompleted
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
          ),
        );
      },
    );
  }

  Widget _buildStatsCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(
            value.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: const Color(0xFF9D2BD1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshDashboard,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Users', icon: Icon(Icons.people)),
            Tab(text: 'Storage', icon: Icon(Icons.storage)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildUsersTab(),
          _buildStorageTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _refreshDashboard,
      color: const Color(0xFF9D2BD1),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Scraper Status Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Scraper Connectivity',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: _getStatusColor(_scraperStatus?.statusColorHex),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _scraperStatus?.statusText ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: _getStatusColor(_scraperStatus?.statusColorHex),
                          ),
                        ),
                        const Spacer(),
                        if (_scraperStatus?.responseTime != null)
                          Text(
                            '${_scraperStatus!.responseTime}ms',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.update, size: 14, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          'Last sync: ${_formatDate(_scraperStatus?.lastSuccessfulSync)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Quick Stats
            Row(
              children: [
                Expanded(
                  child: _buildQuickStatCard(
                    title: 'Users',
                    value: '${_storageStats?.users['total'] ?? 0}',
                    icon: Icons.people,
                    color: const Color(0xFF9D2BD1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickStatCard(
                    title: 'Courses',
                    value: '${_storageStats?.courses['total'] ?? 0}',
                    icon: Icons.school,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuickStatCard(
                    title: 'Backlog Items',
                    value: '${_storageStats?.backlog['total'] ?? 0}',
                    icon: Icons.task,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickStatCard(
                    title: 'Storage',
                    value: '${_storageStats?.database['storageSizeMB'] ?? 0} MB',
                    icon: Icons.storage,
                    color: _storageStats?.isNearLimit == true
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
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
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_users.isEmpty) {
      return const Center(child: Text('No users found'));
    }

    return RefreshIndicator(
      onRefresh: _refreshDashboard,
      color: const Color(0xFF9D2BD1),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          return _buildUserCard(user);
        },
      ),
    );
  }

  Widget _buildUserCard(AdminUser user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _viewUserDetails(user),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: user.role == 'admin'
                      ? Colors.purple.withOpacity(0.1)
                      : const Color(0xFF9D2BD1).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    user.name[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: user.role == 'admin' ? Colors.purple : const Color(0xFF9D2BD1),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      user.email,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: user.role == 'admin'
                                ? Colors.purple.withOpacity(0.1)
                                : Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            user.role.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: user.role == 'admin' ? Colors.purple : Colors.blue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${user.courseCount} courses',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${user.backlogCount} tasks',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                user.completedTasks == user.totalTasks && user.totalTasks > 0
                    ? Icons.check_circle
                    : Icons.arrow_forward_ios,
                size: 18,
                color: user.completedTasks == user.totalTasks && user.totalTasks > 0
                    ? Colors.green
                    : Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStorageTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final storage = _storageStats;
    if (storage == null) {
      return const Center(child: Text('Failed to load storage stats'));
    }

    final usagePercent = storage.usagePercentage;
    final isNearLimit = storage.isNearLimit;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Database Storage Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Database Storage',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '${storage.database['storageSizeMB']}',
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                            ),
                            Text('MB Used', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                      Container(height: 40, width: 1, color: Colors.grey[300]),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '${storage.database['dataSizeMB']}',
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                            ),
                            Text('MB Data', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                      Container(height: 40, width: 1, color: Colors.grey[300]),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '${storage.database['indexSizeMB']}',
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                            ),
                            Text('MB Indexes', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: usagePercent / 100,
                    backgroundColor: Colors.grey[200],
                    color: isNearLimit ? Colors.orange : Colors.green,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${usagePercent.toStringAsFixed(1)}% of 512MB limit',
                        style: TextStyle(
                          fontSize: 12,
                          color: isNearLimit ? Colors.orange : Colors.grey[600],
                        ),
                      ),
                      if (isNearLimit)
                        const Text(
                          'Near Limit!',
                          style: TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // User Stats Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'User Statistics',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow('Total Users', storage.users['total'] ?? 0),
                  _buildStatRow('Admin Users', storage.users['admin'] ?? 0),
                  _buildStatRow('Student Users', storage.users['student'] ?? 0),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Content Stats Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Content Statistics',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow('Active Courses', storage.courses['active'] ?? 0),
                  _buildStatRow('Archived Courses', storage.courses['archived'] ?? 0),
                  _buildStatRow('Total Backlog Items', storage.backlog['total'] ?? 0),
                  _buildStatRow('Completed Tasks', storage.backlog['completed'] ?? 0),
                  _buildStatRow('Pending Tasks', storage.backlog['pending'] ?? 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Never';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) return 'Just now';
        return '${diff.inMinutes} min ago';
      }
      return '${diff.inHours} hours ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    }
    return '${date.day}/${date.month}/${date.year}';
  }
}