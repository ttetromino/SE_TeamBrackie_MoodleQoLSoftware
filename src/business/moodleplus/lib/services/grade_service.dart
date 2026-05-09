// lib/services/grade_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/grade_model.dart';
import '../config/api_config.dart';
class GradeService {

  static const String baseUrl = ApiConfig.baseUrl;
  static const String cachedGradesKey = 'cached_grades';
  static const String cachedSummaryKey = 'cached_grade_summary';
  static const String lastUpdatedKey = 'grades_last_updated';

  // Fetch grades from LMS
  Future<List<GradeModel>> fetchGradesFromLMS(String userId) async {
    try {
      print('📊 Fetching grades from LMS for: $userId');

      final response = await http.post(
        Uri.parse('$baseUrl/api/lms/grades'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> gradesJson = data['grades'] ?? [];
        final grades = gradesJson.map((g) => GradeModel.fromJson(g)).toList();

        // Create summary
        final summary = GradeSummary(
          gwa: (data['gwa'] ?? 0).toDouble(),
          totalCourses: data['totalCourses'] ?? 0,
          gradedCourses: data['gradedCourses'] ?? 0,
          highestGrade: _calculateHighestGrade(grades),
          lowestGrade: _calculateLowestGrade(grades),
          highestCourse: _getHighestCourseName(grades),
          lowestCourse: _getLowestCourseName(grades),
          gradeDistribution: _calculateGradeDistribution(grades),
          lastUpdated: DateTime.now(),
        );

        // Cache grades and summary
        await _cacheGrades(grades);
        await _cacheSummary(summary);
        await _saveLastUpdated(DateTime.now());

        print('✅ Fetched ${grades.length} grades, GWA: ${summary.formattedGwa}%');
        return grades;
      }
      return [];
    } catch (e) {
      print('Fetch grades error: $e');
      return [];
    }
  }

  // Get cached grades (US-05-T-04)
  Future<List<GradeModel>> getCachedGrades() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(cachedGradesKey);

      if (cachedJson != null) {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        return decoded.map((g) => GradeModel.fromJson(g)).toList();
      }
      return [];
    } catch (e) {
      print('Get cached grades error: $e');
      return [];
    }
  }

  // Get cached summary
  Future<GradeSummary?> getCachedSummary() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(cachedSummaryKey);

      if (cachedJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(cachedJson);
        return GradeSummary(
          gwa: decoded['gwa'] ?? 0,
          totalCourses: decoded['totalCourses'] ?? 0,
          gradedCourses: decoded['gradedCourses'] ?? 0,
          highestGrade: decoded['highestGrade'] ?? 0,
          lowestGrade: decoded['lowestGrade'] ?? 0,
          highestCourse: decoded['highestCourse'] ?? '',
          lowestCourse: decoded['lowestCourse'] ?? '',
          gradeDistribution: Map<String, int>.from(decoded['gradeDistribution'] ?? {}),
          lastUpdated: DateTime.parse(decoded['lastUpdated'] ?? DateTime.now().toIso8601String()),
        );
      }
      return null;
    } catch (e) {
      print('Get cached summary error: $e');
      return null;
    }
  }

  // Cache grades locally
  Future<void> _cacheGrades(List<GradeModel> grades) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gradesJson = jsonEncode(grades.map((g) => g.toJson()).toList());
      await prefs.setString(cachedGradesKey, gradesJson);
      print('✅ Cached ${grades.length} grades locally');
    } catch (e) {
      print('Cache grades error: $e');
    }
  }

  // Cache summary
  Future<void> _cacheSummary(GradeSummary summary) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final summaryJson = jsonEncode({
        'gwa': summary.gwa,
        'totalCourses': summary.totalCourses,
        'gradedCourses': summary.gradedCourses,
        'highestGrade': summary.highestGrade,
        'lowestGrade': summary.lowestGrade,
        'highestCourse': summary.highestCourse,
        'lowestCourse': summary.lowestCourse,
        'gradeDistribution': summary.gradeDistribution,
        'lastUpdated': summary.lastUpdated.toIso8601String(),
      });
      await prefs.setString(cachedSummaryKey, summaryJson);
    } catch (e) {
      print('Cache summary error: $e');
    }
  }

  // Save last updated timestamp
  Future<void> _saveLastUpdated(DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(lastUpdatedKey, timestamp.toIso8601String());
  }

  // Get last updated timestamp
  Future<DateTime?> getLastUpdated() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString(lastUpdatedKey);
    if (timestamp != null) {
      return DateTime.parse(timestamp);
    }
    return null;
  }

  // Clear cached grades
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(cachedGradesKey);
    await prefs.remove(cachedSummaryKey);
    await prefs.remove(lastUpdatedKey);
    print('🗑️ Grade cache cleared');
  }

  // Helper methods
  double _calculateHighestGrade(List<GradeModel> grades) {
    final validGrades = grades.where((g) => g.grade != null).map((g) => g.grade!).toList();
    if (validGrades.isEmpty) return 0;
    return validGrades.reduce((a, b) => a > b ? a : b);
  }

  double _calculateLowestGrade(List<GradeModel> grades) {
    final validGrades = grades.where((g) => g.grade != null).map((g) => g.grade!).toList();
    if (validGrades.isEmpty) return 0;
    return validGrades.reduce((a, b) => a < b ? a : b);
  }

  String _getHighestCourseName(List<GradeModel> grades) {
    final validGrades = grades.where((g) => g.grade != null).toList();
    if (validGrades.isEmpty) return '';
    final highest = validGrades.reduce((a, b) => a.grade! > b.grade! ? a : b);
    return highest.courseName;
  }

  String _getLowestCourseName(List<GradeModel> grades) {
    final validGrades = grades.where((g) => g.grade != null).toList();
    if (validGrades.isEmpty) return '';
    final lowest = validGrades.reduce((a, b) => a.grade! < b.grade! ? a : b);
    return lowest.courseName;
  }

  Map<String, int> _calculateGradeDistribution(List<GradeModel> grades) {
    final distribution = {
      '90-100': 0,
      '80-89': 0,
      '75-79': 0,
      '70-74': 0,
      '60-69': 0,
      'Below 60': 0,
      'No Grade': 0,
    };

    for (final grade in grades) {
      if (grade.grade == null) {
        distribution['No Grade'] = distribution['No Grade']! + 1;
      } else if (grade.grade! >= 90) {
        distribution['90-100'] = distribution['90-100']! + 1;
      } else if (grade.grade! >= 80) {
        distribution['80-89'] = distribution['80-89']! + 1;
      } else if (grade.grade! >= 75) {
        distribution['75-79'] = distribution['75-79']! + 1;
      } else if (grade.grade! >= 70) {
        distribution['70-74'] = distribution['70-74']! + 1;
      } else if (grade.grade! >= 60) {
        distribution['60-69'] = distribution['60-69']! + 1;
      } else {
        distribution['Below 60'] = distribution['Below 60']! + 1;
      }
    }

    return distribution;
  }
}