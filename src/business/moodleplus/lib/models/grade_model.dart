// lib/models/grade_model.dart
import 'package:flutter/material.dart';

class GradeModel {
  final String courseId;
  final String courseName;
  final double? grade;
  final String gradeDisplay;
  final String? letterGrade;
  final double weight;
  final String gradeType;
  final List<CategoryGrade> categoryGrades;
  final DateTime lastUpdated;

  GradeModel({
    required this.courseId,
    required this.courseName,
    this.grade,
    required this.gradeDisplay,
    this.letterGrade,
    required this.weight,
    required this.gradeType,
    this.categoryGrades = const [],
    required this.lastUpdated,
  });

  factory GradeModel.fromJson(Map<String, dynamic> json) {
    return GradeModel(
      courseId: json['courseId'] ?? '',
      courseName: json['courseName'] ?? '',
      grade: json['grade'] != null ? (json['grade'] is int ? json['grade'].toDouble() : json['grade']) : null,
      gradeDisplay: json['gradeDisplay'] ?? 'N/A',
      letterGrade: json['letterGrade'],
      weight: (json['weight'] ?? 3.0).toDouble(),
      gradeType: json['gradeType'] ?? 'unknown',
      categoryGrades: json['categoryGrades'] != null
          ? (json['categoryGrades'] as List).map((c) => CategoryGrade.fromJson(c)).toList()
          : [],
      lastUpdated: DateTime.parse(json['lastUpdated'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'courseId': courseId,
      'courseName': courseName,
      'grade': grade,
      'gradeDisplay': gradeDisplay,
      'letterGrade': letterGrade,
      'weight': weight,
      'gradeType': gradeType,
      'categoryGrades': categoryGrades.map((c) => c.toJson()).toList(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  String get formattedGrade {
    if (grade != null) {
      return '${grade!.toStringAsFixed(1)}%';
    }
    return gradeDisplay;
  }

  Color get gradeColor {
    if (grade == null) return Colors.grey;
    if (grade! >= 90) return Colors.green;
    if (grade! >= 80) return Colors.lightGreen;
    if (grade! >= 75) return Colors.lightGreen.shade700;
    if (grade! >= 70) return Colors.amber;
    if (grade! >= 60) return Colors.orange;
    return Colors.red;
  }

  IconData get gradeIcon {
    if (grade == null) return Icons.help_outline;
    if (grade! >= 90) return Icons.emoji_events;
    if (grade! >= 80) return Icons.thumb_up;
    if (grade! >= 70) return Icons.trending_up;
    if (grade! >= 60) return Icons.warning;
    return Icons.error_outline;
  }

  String get gradeStatus {
    if (grade == null) return 'No Grade';
    if (grade! >= 90) return 'Excellent';
    if (grade! >= 80) return 'Very Good';
    if (grade! >= 75) return 'Good';
    if (grade! >= 70) return 'Satisfactory';
    if (grade! >= 60) return 'Passing';
    return 'Needs Improvement';
  }
}

class CategoryGrade {
  final String name;
  final double grade;

  CategoryGrade({
    required this.name,
    required this.grade,
  });

  factory CategoryGrade.fromJson(Map<String, dynamic> json) {
    return CategoryGrade(
      name: json['name'] ?? '',
      grade: (json['grade'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'grade': grade,
    };
  }

  String get formattedGrade => '${grade.toStringAsFixed(1)}%';
}

class GradeSummary {
  final double gwa;
  final int totalCourses;
  final int gradedCourses;
  final double highestGrade;
  final double lowestGrade;
  final String highestCourse;
  final String lowestCourse;
  final Map<String, int> gradeDistribution;
  final DateTime lastUpdated;

  GradeSummary({
    required this.gwa,
    required this.totalCourses,
    required this.gradedCourses,
    required this.highestGrade,
    required this.lowestGrade,
    required this.highestCourse,
    required this.lowestCourse,
    required this.gradeDistribution,
    required this.lastUpdated,
  });

  double get completionRate => totalCourses > 0 ? gradedCourses / totalCourses : 0;

  String get formattedGwa => gwa.toStringAsFixed(2);

  String get gwaStatus {
    if (gwa >= 90) return 'Excellent';
    if (gwa >= 85) return 'Very Good';
    if (gwa >= 80) return 'Good';
    if (gwa >= 75) return 'Satisfactory';
    if (gwa >= 70) return 'Passing';
    return 'Needs Improvement';
  }

  Color get gwaColor {
    if (gwa >= 90) return Colors.green;
    if (gwa >= 80) return Colors.lightGreen;
    if (gwa >= 70) return Colors.amber;
    return Colors.orange;
  }
}