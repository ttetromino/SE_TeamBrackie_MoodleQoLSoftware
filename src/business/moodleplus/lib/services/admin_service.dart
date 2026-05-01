// lib/services/admin_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class AdminService {
  static const String baseUrl = 'http://10.0.2.2:5000';

  // Check if user is admin
  Future<bool> isAdmin(String email) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/verify/$email'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['isAdmin'] == true;
      }
      return false;
    } catch (e) {
      print('Check admin error: $e');
      return false;
    }
  }

  // Get scraper connectivity status
  Future<ScraperStatus> getScraperStatus(String adminEmail) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/scraper-status?email=$adminEmail'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ScraperStatus.fromJson(data);
      }
      return ScraperStatus.disconnected();
    } catch (e) {
      print('Get scraper status error: $e');
      return ScraperStatus.disconnected();
    }
  }

  // Get storage statistics
  Future<StorageStats> getStorageStats(String adminEmail) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/storage-stats?email=$adminEmail'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return StorageStats.fromJson(data);
      }
      return StorageStats.empty();
    } catch (e) {
      print('Get storage stats error: $e');
      return StorageStats.empty();
    }
  }

  // Get all users
  Future<List<AdminUser>> getAllUsers(String adminEmail) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/users?email=$adminEmail'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> users = data['users'] ?? [];
        return users.map((u) => AdminUser.fromJson(u)).toList();
      }
      return [];
    } catch (e) {
      print('Get all users error: $e');
      return [];
    }
  }

  // Get user details
  Future<AdminUser?> getUserDetails(String adminEmail, String userEmail) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/users/$userEmail?email=$adminEmail'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AdminUser.fromJson(data['user']);
      }
      return null;
    } catch (e) {
      print('Get user details error: $e');
      return null;
    }
  }

  // Get user courses
  Future<List<UserCourse>> getUserCourses(String adminEmail, String userEmail) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/users/$userEmail/courses?email=$adminEmail'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> courses = data['courses'] ?? [];
        return courses.map((c) => UserCourse.fromJson(c)).toList();
      }
      return [];
    } catch (e) {
      print('Get user courses error: $e');
      return [];
    }
  }

  // Get user backlog
  Future<List<dynamic>> getUserBacklog(String adminEmail, String userEmail, {bool showCompleted = false}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/users/$userEmail/backlog?email=$adminEmail&showCompleted=$showCompleted'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['backlog'] ?? [];
      }
      return [];
    } catch (e) {
      print('Get user backlog error: $e');
      return [];
    }
  }

  // Force sync for a user
  Future<bool> forceUserSync(String adminEmail, String userEmail) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/admin/force-sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': userEmail, 'adminEmail': adminEmail}),
      );

      final data = jsonDecode(response.body);
      return response.statusCode == 200 && data['success'] == true;
    } catch (e) {
      print('Force user sync error: $e');
      return false;
    }
  }

  // Remove user
  Future<bool> removeUser(String adminEmail, String userEmail) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/admin/users'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': userEmail, 'adminEmail': adminEmail}),
      );

      final data = jsonDecode(response.body);
      return response.statusCode == 200 && data['success'] == true;
    } catch (e) {
      print('Remove user error: $e');
      return false;
    }
  }
}

// Models (no Flutter dependencies)
class ScraperStatus {
  final String status; // 'connected', 'degraded', 'disconnected'
  final int? responseTime;
  final DateTime? lastSuccessfulSync;
  final DateTime timestamp;

  ScraperStatus({
    required this.status,
    this.responseTime,
    this.lastSuccessfulSync,
    required this.timestamp,
  });

  factory ScraperStatus.fromJson(Map<String, dynamic> json) {
    return ScraperStatus(
      status: json['status'] ?? 'disconnected',
      responseTime: json['responseTime'],
      lastSuccessfulSync: json['lastSuccessfulSync'] != null
          ? DateTime.parse(json['lastSuccessfulSync'])
          : null,
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }

  factory ScraperStatus.disconnected() {
    return ScraperStatus(
      status: 'disconnected',
      timestamp: DateTime.now(),
    );
  }

  // These return Strings instead of Colors for service layer
  String get statusColorHex {
    switch (status) {
      case 'connected':
        return '#4CAF50'; // Green
      case 'degraded':
        return '#FF9800'; // Orange
      default:
        return '#F44336'; // Red
    }
  }

  String get statusText {
    switch (status) {
      case 'connected':
        return 'Connected';
      case 'degraded':
        return 'Degraded';
      default:
        return 'Disconnected';
    }
  }
}

class StorageStats {
  final Map<String, dynamic> database;
  final Map<String, dynamic> users;
  final Map<String, dynamic> courses;
  final Map<String, dynamic> backlog;
  final DateTime timestamp;

  StorageStats({
    required this.database,
    required this.users,
    required this.courses,
    required this.backlog,
    required this.timestamp,
  });

  factory StorageStats.fromJson(Map<String, dynamic> json) {
    return StorageStats(
      database: json['database'] ?? {},
      users: json['users'] ?? {},
      courses: json['courses'] ?? {},
      backlog: json['backlog'] ?? {},
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }

  factory StorageStats.empty() {
    return StorageStats(
      database: {},
      users: {},
      courses: {},
      backlog: {},
      timestamp: DateTime.now(),
    );
  }

  double get usagePercentage {
    final value = database['usagePercentage'];
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
  bool get isNearLimit {
    final value = database['isNearLimit'];
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }
}

class AdminUser {
  final String email;
  final String name;
  final String role;
  final String lmsUsername;
  final DateTime? lmsLastLogin;
  final DateTime createdAt;
  final int courseCount;
  final int archivedCount;
  final int backlogCount;
  final int completedBacklogCount;
  final Map<String, dynamic> courseStats;

  AdminUser({
    required this.email,
    required this.name,
    required this.role,
    required this.lmsUsername,
    this.lmsLastLogin,
    required this.createdAt,
    required this.courseCount,
    required this.archivedCount,
    required this.backlogCount,
    required this.completedBacklogCount,
    required this.courseStats,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? 'student',
      lmsUsername: json['lmsUsername'] ?? '',
      lmsLastLogin: json['lmsLastLogin'] != null
          ? DateTime.parse(json['lmsLastLogin'])
          : null,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      courseCount: json['courseCount'] ?? 0,
      archivedCount: json['archivedCount'] ?? 0,
      backlogCount: json['backlogCount'] ?? 0,
      completedBacklogCount: json['completedBacklogCount'] ?? 0,
      courseStats: json['courseStats'] ?? {},
    );
  }

  int get totalTasks {
    final stats = courseStats;
    return (stats['totalQuizzes'] ?? 0) + (stats['totalAssignments'] ?? 0);
  }

  int get completedTasks {
    final stats = courseStats;
    return (stats['completedQuizzes'] ?? 0) + (stats['completedAssignments'] ?? 0);
  }
}

class UserCourse {
  final String courseId;
  final String courseName;
  final int totalActivities;
  final int completedActivities;
  final bool isArchived;
  final DateTime? archivedAt;
  final DateTime? lastSynced;

  UserCourse({
    required this.courseId,
    required this.courseName,
    required this.totalActivities,
    required this.completedActivities,
    required this.isArchived,
    this.archivedAt,
    this.lastSynced,
  });

  factory UserCourse.fromJson(Map<String, dynamic> json) {
    return UserCourse(
      courseId: json['courseId'] ?? '',
      courseName: json['courseName'] ?? '',
      totalActivities: json['totalActivities'] ?? 0,
      completedActivities: json['completedActivities'] ?? 0,
      isArchived: json['isArchived'] ?? false,
      archivedAt: json['archivedAt'] != null
          ? DateTime.parse(json['archivedAt'])
          : null,
      lastSynced: json['lastSynced'] != null
          ? DateTime.parse(json['lastSynced'])
          : null,
    );
  }
}