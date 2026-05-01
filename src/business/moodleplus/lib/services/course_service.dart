// lib/services/course_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class CourseService {
  static const String baseUrl = 'http://10.0.2.2:5000';

  // Get all stored courses from database
  Future<List<StoredCourse>> getStoredCourses(String email) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/course/stored/$email'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> courses = data['courses'] ?? [];
        return courses.map((c) => StoredCourse.fromJson(c)).toList();
      }
      return [];
    } catch (e) {
      print('Get stored courses error: $e');
      return [];
    }
  }

  // Get single stored course
  Future<StoredCourse?> getStoredCourse(String email, String courseId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/course/stored/$email/$courseId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return StoredCourse.fromJson(data['course']);
      }
      return null;
    } catch (e) {
      print('Get stored course error: $e');
      return null;
    }
  }

  // Get course contents from database
  Future<Map<String, dynamic>> getCourseContentsFromDB(String email, String courseId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/course/contents/$email/$courseId'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'sections': []};
    } catch (e) {
      print('Get course contents error: $e');
      return {'success': false, 'sections': []};
    }
  }

  // Sync a single course to database
  Future<Map<String, dynamic>> syncCourse({
    required String email,
    required String courseId,
    required String courseName,
    required String courseUrl,
    bool forceRefresh = false,
  }) async {
    try {
      print('🔄 Syncing course: $courseName');

      final response = await http.post(
        Uri.parse('$baseUrl/api/course/sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'courseId': courseId,
          'courseName': courseName,
          'courseUrl': courseUrl,
          'forceRefresh': forceRefresh,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('Sync course error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // NEW: Sync backlog after completing an activity
  Future<void> syncBacklogAfterCompletion(String email) async {
    try {
      print('🔄 Syncing backlog after activity completion...');
      final response = await http.post(
        Uri.parse('$baseUrl/api/backlog/sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        print('✅ Backlog synced successfully, ${data['count']} items updated');
      } else {
        print('⚠️ Backlog sync returned: ${response.statusCode}');
      }
    } catch (e) {
      print('Backlog sync error: $e');
    }
  }

  // Mark activity complete by ID (used by Course Contents page)
  Future<Map<String, dynamic>> markActivityComplete({
    required String email,
    required String courseId,
    required String activityId,
    required bool isCompleted,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/course/activity-complete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'courseId': courseId,
          'activityId': activityId,
          'isCompleted': isCompleted,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('Mark activity complete error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // NEW: Mark activity complete by URL (used by Backlog page)
  Future<Map<String, dynamic>> markActivityCompleteByUrl({
    required String email,
    required String courseId,
    required String activityUrl,
    required bool isCompleted,
  }) async {
    try {
      // Clean the URL before sending
      var cleanUrl = activityUrl;
      cleanUrl = cleanUrl.replaceAll('https://uphslms.comhttps://uphslms.com', 'https://uphslms.com');
      cleanUrl = cleanUrl.replaceAll('https://uphslms.comhttps://', 'https://');

      print('🔍 Marking activity complete by URL: $cleanUrl');

      final response = await http.put(
        Uri.parse('$baseUrl/api/course/activity-complete-by-url'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'courseId': courseId,
          'activityUrl': cleanUrl,
          'isCompleted': isCompleted,
        }),
      );

      final result = jsonDecode(response.body);
      print('📥 Response: ${result['success']}');
      return result;
    } catch (e) {
      print('Mark activity complete by URL error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Get course stats
  Future<CourseStatsData> getCourseStats(String email) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/course/stats/$email'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return CourseStatsData.fromJson(data['stats']);
      }
      return CourseStatsData();
    } catch (e) {
      print('Get course stats error: $e');
      return CourseStatsData();
    }
  }

  // Start background sync
  Future<void> startBackgroundSync(String email, List<Map<String, dynamic>> courses) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/course/sync-background'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'courses': courses,
        }),
      );
      print('📡 Background sync triggered');
    } catch (e) {
      print('Trigger background sync error: $e');
    }
  }
}

// Models remain the same...
class StoredCourse {
  final String courseId;
  final String courseName;
  final String courseUrl;
  final String courseTitle;
  final List<StoredSection> sections;
  final bool isArchived;
  final int totalActivities;
  final int completedActivities;
  final DateTime lastSynced;

  StoredCourse({
    required this.courseId,
    required this.courseName,
    required this.courseUrl,
    required this.courseTitle,
    required this.sections,
    required this.isArchived,
    required this.totalActivities,
    required this.completedActivities,
    required this.lastSynced,
  });

  factory StoredCourse.fromJson(Map<String, dynamic> json) {
    return StoredCourse(
      courseId: json['courseId'] ?? '',
      courseName: json['courseName'] ?? '',
      courseUrl: json['courseUrl'] ?? '',
      courseTitle: json['courseTitle'] ?? '',
      sections: (json['sections'] as List?)
          ?.map((s) => StoredSection.fromJson(s))
          .toList() ?? [],
      isArchived: json['isArchived'] ?? false,
      totalActivities: json['totalActivities'] ?? 0,
      completedActivities: json['completedActivities'] ?? 0,
      lastSynced: DateTime.tryParse(json['lastSynced'] ?? '') ?? DateTime.now(),
    );
  }
}

class StoredSection {
  final String id;
  final String number;
  final String name;
  final String? link;
  final List<StoredActivity> activities;

  StoredSection({
    required this.id,
    required this.number,
    required this.name,
    this.link,
    required this.activities,
  });

  factory StoredSection.fromJson(Map<String, dynamic> json) {
    return StoredSection(
      id: json['id'] ?? '',
      number: json['number'] ?? '',
      name: json['name'] ?? '',
      link: json['link'],
      activities: (json['activities'] as List?)
          ?.map((a) => StoredActivity.fromJson(a))
          .toList() ?? [],
    );
  }
}

class StoredActivity {
  final String id;
  final String name;
  final String type;
  final String? url;
  final String? badge;
  final bool isIndented;
  final String completionStatus;
  final List<String> dates;
  final DateTime? dueDate;

  StoredActivity({
    required this.id,
    required this.name,
    required this.type,
    this.url,
    this.badge,
    required this.isIndented,
    required this.completionStatus,
    required this.dates,
    this.dueDate,
  });

  factory StoredActivity.fromJson(Map<String, dynamic> json) {
    return StoredActivity(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 'unknown',
      url: json['url'],
      badge: json['badge'],
      isIndented: json['isIndented'] ?? false,
      completionStatus: json['completionStatus'] ?? 'todo',
      dates: List<String>.from(json['dates'] ?? []),
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
    );
  }

  bool get isCompleted => completionStatus == 'done';
}

class CourseStatsData {
  final int totalTasks;
  final int completedTasks;
  final int totalQuizzes;
  final int completedQuizzes;
  final int totalAssignments;
  final int completedAssignments;
  final DateTime? lastUpdated;

  CourseStatsData({
    this.totalTasks = 0,
    this.completedTasks = 0,
    this.totalQuizzes = 0,
    this.completedQuizzes = 0,
    this.totalAssignments = 0,
    this.completedAssignments = 0,
    this.lastUpdated,
  });

  factory CourseStatsData.fromJson(Map<String, dynamic> json) {
    return CourseStatsData(
      totalTasks: json['totalTasks'] ?? 0,
      completedTasks: json['completedTasks'] ?? 0,
      totalQuizzes: json['totalQuizzes'] ?? 0,
      completedQuizzes: json['completedQuizzes'] ?? 0,
      totalAssignments: json['totalAssignments'] ?? 0,
      completedAssignments: json['completedAssignments'] ?? 0,
      lastUpdated: json['lastUpdated'] != null ? DateTime.parse(json['lastUpdated']) : null,
    );
  }

  double get completionPercentage {
    final total = totalTasks + totalQuizzes + totalAssignments;
    final completed = completedTasks + completedQuizzes + completedAssignments;
    return total == 0 ? 0 : completed / total;
  }
}