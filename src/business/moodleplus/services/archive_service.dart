// lib/services/archive_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ArchiveService {
  static const String baseUrl = 'http://10.0.2.2:5000';

  // US-04-T-02: Archive a course
  Future<Map<String, dynamic>?> archiveCourse({
    required String email,
    required String courseId,
    required String courseName,
    required String courseUrl,
  }) async {
    try {
      print('📦 Archiving course: $courseName');

      final response = await http.post(
        Uri.parse('$baseUrl/api/archive/course'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'courseId': courseId,
          'courseName': courseName,
          'courseUrl': courseUrl,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        print('✅ Course archived successfully');
        return data['archivedCourse'];
      } else {
        print('❌ Archive failed: ${data['error']}');
        return null;
      }
    } catch (e) {
      print('Archive course error: $e');
      return null;
    }
  }

  // US-04-T-04: Get all archived courses
  Future<List<ArchivedCourse>> getArchivedCourses(String email) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/archive/courses/$email'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> courses = data['archivedCourses'] ?? [];
        return courses.map((c) => ArchivedCourse.fromJson(c)).toList();
      }
      return [];
    } catch (e) {
      print('Get archived courses error: $e');
      return [];
    }
  }

  // US-04-T-04: Get single archived course details
  Future<ArchivedCourse?> getArchivedCourseDetails(String email, String courseId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/archive/course/$email/$courseId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ArchivedCourse.fromJson(data['archivedCourse']);
      }
      return null;
    } catch (e) {
      print('Get archived course details error: $e');
      return null;
    }
  }

  // US-04-T-04: Restore course from archive
  Future<bool> restoreArchivedCourse(String email, String courseId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/archive/restore'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'courseId': courseId,
        }),
      );

      final data = jsonDecode(response.body);
      return response.statusCode == 200 && data['success'] == true;
    } catch (e) {
      print('Restore archived course error: $e');
      return false;
    }
  }

  // Delete archived course permanently
  Future<bool> deleteArchivedCourse(String email, String courseId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/archive/course'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'courseId': courseId,
        }),
      );

      final data = jsonDecode(response.body);
      return response.statusCode == 200 && data['success'] == true;
    } catch (e) {
      print('Delete archived course error: $e');
      return false;
    }
  }
}

// US-04-T-03: Archived Course Model for Local Storage
class ArchivedCourse {
  final String courseId;
  final String courseName;
  final String courseUrl;
  final DateTime archivedAt;
  final Map<String, dynamic> contents;
  final String? thumbnail;
  final Map<String, dynamic> metadata;

  ArchivedCourse({
    required this.courseId,
    required this.courseName,
    required this.courseUrl,
    required this.archivedAt,
    required this.contents,
    this.thumbnail,
    required this.metadata,
  });

  factory ArchivedCourse.fromJson(Map<String, dynamic> json) {
    return ArchivedCourse(
      courseId: json['courseId'] ?? '',
      courseName: json['courseName'] ?? '',
      courseUrl: json['courseUrl'] ?? '',
      archivedAt: DateTime.parse(json['archivedAt'] ?? DateTime.now().toIso8601String()),
      contents: json['contents'] ?? {},
      thumbnail: json['thumbnail'],
      metadata: json['metadata'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'courseId': courseId,
      'courseName': courseName,
      'courseUrl': courseUrl,
      'archivedAt': archivedAt.toIso8601String(),
      'contents': contents,
      'thumbnail': thumbnail,
      'metadata': metadata,
    };
  }

  int get totalActivities => metadata['totalActivities'] ?? 0;
  int get completedActivities => metadata['completedActivities'] ?? 0;
  double get completionPercentage => totalActivities > 0
      ? (completedActivities / totalActivities) * 100
      : 0;
}