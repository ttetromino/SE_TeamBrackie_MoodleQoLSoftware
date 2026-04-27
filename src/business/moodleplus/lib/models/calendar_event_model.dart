// lib/models/calendar_event_model.dart
import 'package:flutter/material.dart';

enum EventType {
  academic,   // Moodle-synced events (assignments, quizzes, etc.)
  personal,   // Manually added personal tasks
}

class CalendarEvent {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final TimeOfDay? time;
  final EventType type;
  final String? courseName;
  final String? eventUrl;
  final bool isCompleted;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    this.time,
    required this.type,
    this.courseName,
    this.eventUrl,
    this.isCompleted = false,
  });

  // Get display time string
  String get timeString {
    if (time == null) return 'All day';
    return '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}';
  }

  // Get color based on event type
  Color get eventColor {
    return type == EventType.academic ? const Color(0xFF9D2BD1) : Colors.green;
  }

  // Get icon based on event type
  IconData get eventIcon {
    return type == EventType.academic ? Icons.school : Icons.person;
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'timeHour': time?.hour,
      'timeMinute': time?.minute,
      'type': type == EventType.academic ? 'academic' : 'personal',
      'courseName': courseName,
      'eventUrl': eventUrl,
      'isCompleted': isCompleted,
    };
  }

  // Create from JSON
  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      date: DateTime.parse(json['date']),
      time: json['timeHour'] != null && json['timeMinute'] != null
          ? TimeOfDay(hour: json['timeHour'], minute: json['timeMinute'])
          : null,
      type: json['type'] == 'academic' ? EventType.academic : EventType.personal,
      courseName: json['courseName'],
      eventUrl: json['eventUrl'],
      isCompleted: json['isCompleted'] ?? false,
    );
  }
}

class CalendarDay {
  final DateTime date;
  final List<CalendarEvent> events;
  final bool isCurrentMonth;

  CalendarDay({
    required this.date,
    required this.events,
    this.isCurrentMonth = true,
  });

  bool get hasEvents => events.isNotEmpty;
}