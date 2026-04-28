// lib/services/backlog_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'course_service.dart';

class BacklogService {
  static const String baseUrl = 'http://10.0.2.2:5000';

  // Sync backlog from LMS
  Future<int> syncBacklog(String email) async {
    try {
      print('🔄 Syncing backlog for: $email');

      final response = await http.post(
        Uri.parse('$baseUrl/api/backlog/sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        print('✅ Synced ${data['count']} backlog items');
        return data['count'];
      }
      return 0;
    } catch (e) {
      print('Sync backlog error: $e');
      return 0;
    }
  }

  // Get backlog items with filters
  Future<List<BacklogItem>> getBacklogItems({
    required String email,
    String? filterBy,
    String? priority,
    String? courseCode,
    bool showPinnedOnly = false,
  }) async {
    try {
      final queryParams = [];
      if (filterBy != null) queryParams.add('filterBy=$filterBy');
      if (priority != null && priority != 'all')
        queryParams.add('priority=$priority');
      if (courseCode != null && courseCode != 'all')
        queryParams.add('courseCode=$courseCode');
      if (showPinnedOnly) queryParams.add('showPinnedOnly=true');

      String url = '$baseUrl/api/backlog/items/$email';
      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> items = data['items'] ?? [];
        return items.map((i) => BacklogItem.fromJson(i)).toList();
      }
      return [];
    } catch (e) {
      print('Get backlog items error: $e');
      return [];
    }
  }

  // Toggle pin status
  Future<bool> togglePin(String itemId, String email) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/backlog/pin/$itemId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      final data = jsonDecode(response.body);
      return response.statusCode == 200 && data['success'] == true;
    } catch (e) {
      print('Toggle pin error: $e');
      return false;
    }
  }

  // Mark item as completed
  Future<bool> completeItem(String itemId, String email, {BacklogItem? item}) async {
    try {
      // If item is provided, use it directly
      if (item == null) {
        print('❌ No item data provided, cannot complete');
        return false;
      }

      print('📝 Marking backlog item complete: ${item.activityName}');

      // Use the SAME course service endpoint that works in Course Contents
      final courseService = CourseService();
      final result = await courseService.markActivityComplete(
        email: email,
        courseId: item.courseId,
        activityId: item.activityId,
        isCompleted: true,
      );

      if (result['success'] == true) {
        // Also mark the backlog item as completed in backlog collection
        final response = await http.put(
          Uri.parse('$baseUrl/api/backlog/complete/$itemId'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email}),
        );

        print('✅ Backlog item completed and course activity updated');
        return true;
      }

      return false;
    } catch (e) {
      print('Complete item error: $e');
      return false;
    }
  }

// Add this helper method to get a single backlog item
  Future<BacklogItem?> getBacklogItem(String itemId, String email) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/backlog/item/$itemId?email=$email'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return BacklogItem.fromJson(data['item']);
      }
      return null;
    } catch (e) {
      print('Get backlog item error: $e');
      return null;
    }
  }

  // Mark backlog item as complete by activity ID and course ID
  Future<bool> completeBacklogItemByActivity(String email, String courseId, String activityId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/backlog/complete-by-activity'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'courseId': courseId,
          'activityId': activityId,
        }),
      );

      final data = jsonDecode(response.body);
      return response.statusCode == 200 && data['success'] == true;
    } catch (e) {
      print('Complete backlog item by activity error: $e');
      return false;
    }
  }



  // Save layout preference
  Future<bool> saveLayoutPreference(String email, String layoutMode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('backlog_layout_$email', layoutMode);
      return true;
    } catch (e) {
      print('Save layout preference error: $e');
      return false;
    }
  }

  // Get layout preference
  Future<String> getLayoutPreference(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('backlog_layout_$email') ?? 'compact';
    } catch (e) {
      return 'compact';
    }
  }

  // Get filter preferences
  Future<Map<String, dynamic>> getFilterPreferences(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'filterBy': prefs.getString('backlog_filter_by_$email') ?? 'none',
        'priority': prefs.getString('backlog_priority_$email') ?? 'all',
        'courseCode': prefs.getString('backlog_course_$email') ?? 'all',
      };
    } catch (e) {
      return {'filterBy': 'none', 'priority': 'all', 'courseCode': 'all'};
    }
  }

  // Save filter preferences
  Future<void> saveFilterPreferences(
    String email,
    Map<String, dynamic> filters,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (filters.containsKey('filterBy')) {
        await prefs.setString('backlog_filter_by_$email', filters['filterBy']);
      }
      if (filters.containsKey('priority')) {
        await prefs.setString('backlog_priority_$email', filters['priority']);
      }
      if (filters.containsKey('courseCode')) {
        await prefs.setString('backlog_course_$email', filters['courseCode']);
      }
    } catch (e) {
      print('Save filter preferences error: $e');
    }
  }
}

// US-13: Backlog Item Model
class BacklogItem {
  final String id;
  final String courseId;
  final String courseName;
  final String courseCode;
  final String activityId;
  final String activityName;
  final String activityType;
  final DateTime? dueDate;
  final String priority;
  final bool isPinned;
  final bool isCompleted;
  final String sectionName;
  final String? activityUrl;

  BacklogItem({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.courseCode,
    required this.activityId,
    required this.activityName,
    required this.activityType,
    this.dueDate,
    required this.priority,
    required this.isPinned,
    required this.isCompleted,
    required this.sectionName,
    this.activityUrl,
  });

  factory BacklogItem.fromJson(Map<String, dynamic> json) {
    return BacklogItem(
      id: json['_id'] ?? '',
      courseId: json['courseId'] ?? '',
      courseName: json['courseName'] ?? '',
      courseCode: json['courseCode'] ?? '',
      activityId: json['activityId'] ?? '',
      activityName: json['activityName'] ?? '',
      activityType: json['activityType'] ?? 'unknown',
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      priority: json['priority'] ?? 'medium',
      isPinned: json['isPinned'] ?? false,
      isCompleted: json['isCompleted'] ?? false,
      sectionName: json['sectionName'] ?? '',
      activityUrl: json['activityUrl'],

    );
  }

  // Calculate time remaining
  Duration? get timeRemaining {
    if (dueDate == null) return null;
    final now = DateTime.now();
    if (dueDate!.isBefore(now)) return Duration.zero;
    return dueDate!.difference(now);
  }

  // Format time remaining as HH:MM
  String get formattedTimeRemaining {
    if (dueDate == null) return 'No deadline';
    final remaining = timeRemaining;
    if (remaining == null) return 'Past due';
    if (remaining.isNegative) return 'Past due';

    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}'; // HH:MM
  }

  // Get urgency color based on priority and time remaining
  Color get urgencyColor {
    if (isCompleted) return Colors.grey;

    switch (priority) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.amber;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // Get priority display text
  String get priorityText {
    switch (priority) {
      case 'urgent':
        return 'Urgent';
      case 'high':
        return 'High Priority';
      case 'medium':
        return 'Medium Priority';
      case 'low':
        return 'Low Priority';
      default:
        return 'No Deadline';
    }
  }

  // Get icon for activity type
  IconData get activityIcon {
    switch (activityType) {
      case 'assign':
        return Icons.assignment;
      case 'quiz':
        return Icons.quiz;
      case 'forum':
        return Icons.forum;
      case 'resource':
        return Icons.insert_drive_file;
      default:
        return Icons.task;
    }
  }
}
