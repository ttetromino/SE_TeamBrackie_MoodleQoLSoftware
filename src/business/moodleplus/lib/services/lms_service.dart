import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class LMSService {
  static const String baseUrl = 'http://10.0.2.2:5000';

  final String userId;

  LMSService({required this.userId});


  Future<Map<String, dynamic>> changeLMSPasswordWithDetails(
      String email,
      String currentPassword,
      String newPassword,
      ) async {
    try {
      print('Changing LMS password for: $email');
      print('Current password length: ${currentPassword.length}');
      print('New password length: ${newPassword.length}');

      final response = await http.post(
        Uri.parse('$baseUrl/api/lms/change-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'email': email,
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      final data = jsonDecode(response.body);
      print('Change password response status: ${response.statusCode}');
      print('Change password response: ${response.body}');

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Password changed',
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to change password',
        };
      }
    } catch (e) {
      debugPrint('Change LMS password error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> changeLMSPassword(String email, String currentPassword, String newPassword) async {
    final result = await changeLMSPasswordWithDetails(email, currentPassword, newPassword);
    return result['success'] == true;
  }

  // Login to uphslms.com
  Future<bool> loginToLMS(String lmsUsername, String lmsPassword) async {
    try {
      print('🔐 Attempting LMS login for: $lmsUsername');
      final response = await http.post(
        Uri.parse('$baseUrl/api/lms/login'),
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': userId,
        },
        body: jsonEncode({
          'username': lmsUsername,
          'password': lmsPassword,
        }),
      );

      print('📥 LMS login response: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('LMS login error: $e');
      return false;
    }
  }

  // Auto-login - check if session exists and is valid
  Future<bool> autoLoginLMS() async {
    try {
      print('Attempting auto-login for user: $userId');
      final response = await http.post(
        Uri.parse('$baseUrl/api/lms/auto-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId}),
      );

      print('Auto-login response: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('Auto-login error: $e');
      return false;
    }
  }

  // Get courses from LMS
  Future<List<LmsCourse>> getCourses() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/lms/courses'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<LmsCourse> courses = [];
        for (var course in data['courses']) {
          courses.add(LmsCourse.fromJson(course));
        }
        return courses;
      }
      return [];
    } catch (e) {
      debugPrint('Get courses error: $e');
      return [];
    }
  }

  // Get course contents (sections and activities)
  Future<CourseContents> getCourseContents(String courseUrl) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/lms/course-contents'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'courseUrl': courseUrl,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return CourseContents.fromJson(data);
      }
      return CourseContents(courseTitle: '', sections: []);
    } catch (e) {
      debugPrint('Get course contents error: $e');
      return CourseContents(courseTitle: '', sections: []);
    }
  }

  // US-07: Getting the course stats from the contents of the student's Moodle, including completed tasks
  Future<CourseStats> getCourseStatsFromContents(String courseUrl) async {
    CourseStats stats = CourseStats();

    try {
      final contents = await getCourseContents(courseUrl);

      for (var section in contents.sections) {
        for (var activity in section.activities) {
          final type = activity.type.toLowerCase();
          final status = activity.completionStatus.toLowerCase();
          final badge = (activity.badge ?? '').toLowerCase();

          final isCompleted =
              status.contains('complete') ||
                  status.contains('done') ||
                  status.contains('pass') ||
                  status.contains('submitted') ||
                  badge.contains('submitted');

          if (type.contains('assign')) {
            stats.totalAssignments++;
            if (isCompleted) stats.completedAssignments++;
          } else if (type.contains('quiz')) {
            stats.totalQuizzes++;
            if (isCompleted) stats.completedQuizzes++;
          } else {
            stats.totalTasks++;
            if (isCompleted) stats.completedTasks++;
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing course stats: $e');
    }

    return stats;
  }

  // US-07: Aggregates all number of tasks
  Future<CourseStats> getAllCoursesStats(List<LmsCourse> courses) async {
    CourseStats totalStats = CourseStats();

    for (var course in courses) {
      try {
        final stats = await getCourseStatsFromContents(course.link);
        totalStats.merge(stats);
      } catch (e) {
        debugPrint('Error with course ${course.name}: $e');
      }
    }

    return totalStats;
  }
}

// Course Models
class LmsCourse {
  final String id;
  final String name;
  final String link;
  final String? thumbnail;

  LmsCourse({
    required this.id,
    required this.name,
    required this.link,
    this.thumbnail,
  });

  factory LmsCourse.fromJson(Map<String, dynamic> json) {
    return LmsCourse(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      link: json['link'] ?? '',
      thumbnail: json['thumbnail'],
    );
  }
}

class CourseContents {
  final String courseTitle;
  final List<CourseSection> sections;

  CourseContents({
    required this.courseTitle,
    required this.sections,
  });

  factory CourseContents.fromJson(Map<String, dynamic> json) {
    return CourseContents(
      courseTitle: json['courseTitle'] ?? '',
      sections: (json['sections'] as List)
          .map((s) => CourseSection.fromJson(s))
          .toList(),
    );
  }
}

class CourseSection {
  final String id;
  final String number;
  final String name;
  final String? link;
  final List<CourseActivity> activities;

  CourseSection({
    required this.id,
    required this.number,
    required this.name,
    this.link,
    required this.activities,
  });

  factory CourseSection.fromJson(Map<String, dynamic> json) {
    return CourseSection(
      id: json['id']?.toString() ?? '',
      number: json['number']?.toString() ?? '',
      name: json['name'] ?? '',
      link: json['link'],
      activities: (json['activities'] as List)
          .map((a) => CourseActivity.fromJson(a))
          .toList(),
    );
  }
}

class CourseActivity {
  final String id;
  final String name;
  final String type;
  final String? url;
  final String? icon;
  final String? badge;
  final bool isIndented;
  final String completionStatus;
  final List<String> dates;

  CourseActivity({
    required this.id,
    required this.name,
    required this.type,
    this.url,
    this.icon,
    this.badge,
    required this.isIndented,
    required this.completionStatus,
    required this.dates,
  });

  factory CourseActivity.fromJson(Map<String, dynamic> json) {
    return CourseActivity(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 'unknown',
      url: json['url'],
      icon: json['icon'],
      badge: json['badge'],
      isIndented: json['isIndented'] ?? false,
      completionStatus: json['completionStatus'] ?? 'unknown',
      dates: List<String>.from(json['dates'] ?? []),
    );
  }
}

// US-07: Initial course stats (Tasks, Assignments, Quizzes)
class CourseStats {
  int totalTasks;
  int completedTasks;
  int totalQuizzes;
  int completedQuizzes;
  int totalAssignments;
  int completedAssignments;

  CourseStats({
    this.totalTasks = 0,
    this.completedTasks = 0,
    this.totalQuizzes = 0,
    this.completedQuizzes = 0,
    this.totalAssignments = 0,
    this.completedAssignments = 0,
  });

  void merge(CourseStats other) {
    totalTasks += other.totalTasks;
    completedTasks += other.completedTasks;
    totalQuizzes += other.totalQuizzes;
    completedQuizzes += other.completedQuizzes;
    totalAssignments += other.totalAssignments;
    completedAssignments += other.completedAssignments;
  }
}