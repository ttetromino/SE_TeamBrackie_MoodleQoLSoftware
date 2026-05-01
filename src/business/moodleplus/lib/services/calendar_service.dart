// lib/services/calendar_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/calendar_event_model.dart';

class CalendarService {
  static const String baseUrl = 'http://10.0.2.2:5000';
  static const String cachedEventsKey = 'cached_calendar_events';
  static const String personalEventsKey = 'personal_calendar_events';
  static const String lastSyncKey = 'calendar_last_sync';

  // ============================================================
  // DATABASE METHODS (Backend API calls)
  // ============================================================

  // Add personal event to database
  Future<bool> addPersonalEventToDB(String email, CalendarEvent event) async {
    try {
      print('📝 Saving personal event to database: ${event.title}');

      final response = await http.post(
        Uri.parse('$baseUrl/api/user/personal-event'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'event': {
            'id': event.id,
            'title': event.title,
            'description': event.description,
            'date': event.date.toIso8601String(),
            'timeHour': event.time?.hour,
            'timeMinute': event.time?.minute,
            'isAllDay': event.time == null,
            'courseName': event.courseName,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Personal event saved to database');
        return true;
      }
      print('❌ Failed to save to database: ${response.statusCode}');
      return false;
    } catch (e) {
      print('Add personal event to DB error: $e');
      return false;
    }
  }

  // Fetch personal events from database
  Future<List<CalendarEvent>> fetchPersonalEventsFromDB(String email) async {
    try {
      print('📋 Fetching personal events from database for: $email');

      final response = await http.get(
        Uri.parse('$baseUrl/api/user/personal-events/$email'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> eventsJson = data['events'] ?? [];

        final events = eventsJson.map((json) => CalendarEvent(
          id: json['id'],
          title: json['title'],
          description: json['description'] ?? '',
          date: DateTime.parse(json['date']),
          time: json['timeHour'] != null && json['timeMinute'] != null
              ? TimeOfDay(hour: json['timeHour'], minute: json['timeMinute'])
              : null,
          type: EventType.personal,
          courseName: json['courseName'],
          isCompleted: false,
        )).toList();

        print('✅ Fetched ${events.length} personal events from database');
        return events;
      }
      return [];
    } catch (e) {
      print('Fetch personal events from DB error: $e');
      return [];
    }
  }

  // Delete personal event from database
  Future<bool> deletePersonalEventFromDB(String email, String eventId) async {
    try {
      print('🗑️ Deleting personal event from database: $eventId');

      final response = await http.delete(
        Uri.parse('$baseUrl/api/user/personal-event/$eventId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        print('✅ Personal event deleted from database');
        return true;
      }
      print('❌ Failed to delete from database: ${response.statusCode}');
      return false;
    } catch (e) {
      print('Delete personal event from DB error: $e');
      return false;
    }
  }

  // ============================================================
  // LOCAL CACHE METHODS (SharedPreferences)
  // ============================================================

  // Add personal event to local cache (legacy method - kept for compatibility)
  Future<bool> addPersonalEventToCache(CalendarEvent event) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingJson = prefs.getString(personalEventsKey);

      List<CalendarEvent> personalEvents = [];
      if (existingJson != null) {
        final List<dynamic> decoded = jsonDecode(existingJson);
        personalEvents = decoded.map((e) => CalendarEvent.fromJson(e)).toList();
      }

      personalEvents.add(event);

      final eventsJson = jsonEncode(personalEvents.map((e) => e.toJson()).toList());
      await prefs.setString(personalEventsKey, eventsJson);

      print('✅ Added personal event to cache: ${event.title}');
      return true;
    } catch (e) {
      print('Add personal event to cache error: $e');
      return false;
    }
  }

  // Get all personal events from local cache
  Future<List<CalendarEvent>> getPersonalEventsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(personalEventsKey);

      if (cachedJson != null) {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        return decoded.map((e) => CalendarEvent.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('Get personal events from cache error: $e');
      return [];
    }
  }

  // Delete personal event from local cache
  Future<bool> deletePersonalEventFromCache(String eventId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingJson = prefs.getString(personalEventsKey);

      if (existingJson != null) {
        final List<dynamic> decoded = jsonDecode(existingJson);
        final personalEvents = decoded.map((e) => CalendarEvent.fromJson(e)).toList();

        personalEvents.removeWhere((e) => e.id == eventId);

        final eventsJson = jsonEncode(personalEvents.map((e) => e.toJson()).toList());
        await prefs.setString(personalEventsKey, eventsJson);

        print('✅ Deleted personal event from cache: $eventId');
        return true;
      }
      return false;
    } catch (e) {
      print('Delete personal event from cache error: $e');
      return false;
    }
  }

  // ============================================================
  // COMBINED METHODS (Database + Cache sync)
  // ============================================================

  // Add personal event (saves to both database and cache)
  Future<bool> addPersonalEvent(String email, CalendarEvent event) async {
    try {
      // Save to database first
      final dbSuccess = await addPersonalEventToDB(email, event);

      if (dbSuccess) {
        // Also save to local cache
        await addPersonalEventToCache(event);
        print('✅ Personal event saved to both database and cache');
        return true;
      }
      return false;
    } catch (e) {
      print('Add personal event error: $e');
      return false;
    }
  }

  // Get all personal events (from cache, with option to refresh from DB)
  Future<List<CalendarEvent>> getPersonalEvents({bool refreshFromDB = false, String? email}) async {
    if (refreshFromDB && email != null) {
      final dbEvents = await fetchPersonalEventsFromDB(email);
      // Update cache with DB events
      final prefs = await SharedPreferences.getInstance();
      final eventsJson = jsonEncode(dbEvents.map((e) => e.toJson()).toList());
      await prefs.setString(personalEventsKey, eventsJson);
      return dbEvents;
    }
    return await getPersonalEventsFromCache();
  }

  // Delete personal event (from both database and cache)
  Future<bool> deletePersonalEvent(String email, String eventId) async {
    try {
      // Delete from database first
      final dbSuccess = await deletePersonalEventFromDB(email, eventId);

      if (dbSuccess) {
        // Also delete from local cache
        await deletePersonalEventFromCache(eventId);
        print('✅ Personal event deleted from both database and cache');
        return true;
      }
      return false;
    } catch (e) {
      print('Delete personal event error: $e');
      return false;
    }
  }

  // ============================================================
  // ACADEMIC EVENTS METHODS (LMS sync)
  // ============================================================

  // Fetch calendar events from LMS
  Future<List<CalendarEvent>> fetchEventsFromLMS(String userId) async {
    try {
      print('📅 Fetching calendar events from LMS for: $userId');

      final response = await http.post(
        Uri.parse('$baseUrl/api/lms/calendar'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId}),
      );

      print('📥 Calendar response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<CalendarEvent> events = [];

        if (data['events'] != null && data['events'] is List) {
          for (final eventData in data['events']) {
            if (eventData['date'] != null) {
              DateTime date;
              if (eventData['timestamp'] != null) {
                date = DateTime.fromMillisecondsSinceEpoch(eventData['timestamp']);
              } else if (eventData['date'] is String) {
                date = DateTime.parse(eventData['date']);
              } else {
                continue;
              }

              events.add(CalendarEvent(
                id: eventData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                title: eventData['name'] ?? 'Untitled Event',
                description: 'Moodle assignment/quiz deadline',
                date: date,
                type: EventType.academic,
                courseName: _extractCourseName(eventData['name'] ?? ''),
                eventUrl: eventData['url'],
              ));
            }
          }
        } else if (data['eventsByDate'] != null) {
          final eventsByDate = data['eventsByDate'] as Map<String, dynamic>;
          for (final entry in eventsByDate.entries) {
            final dateParts = entry.key.split('-');
            if (dateParts.length == 3) {
              final date = DateTime(
                int.parse(dateParts[0]),
                int.parse(dateParts[1]),
                int.parse(dateParts[2]),
              );

              for (final eventData in entry.value) {
                events.add(CalendarEvent(
                  id: eventData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  title: eventData['name'] ?? 'Untitled Event',
                  description: 'Moodle assignment/quiz deadline',
                  date: date,
                  type: EventType.academic,
                  courseName: _extractCourseName(eventData['name'] ?? ''),
                  eventUrl: eventData['url'],
                ));
              }
            }
          }
        }

        print('✅ Parsed ${events.length} calendar events');

        // Cache academic events
        await cacheAcademicEvents(events);
        await updateLastSync();

        return events;
      }
      return [];
    } catch (e) {
      print('Fetch calendar events error: $e');
      return [];
    }
  }

  // Get cached academic events
  Future<List<CalendarEvent>> getCachedAcademicEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(cachedEventsKey);

      if (cachedJson != null) {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        return decoded.map((e) => CalendarEvent.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('Get cached academic events error: $e');
      return [];
    }
  }

  // Cache academic events
  Future<void> cacheAcademicEvents(List<CalendarEvent> events) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final eventsJson = jsonEncode(events.map((e) => e.toJson()).toList());
      await prefs.setString(cachedEventsKey, eventsJson);
      print('✅ Cached ${events.length} calendar events');
    } catch (e) {
      print('Cache academic events error: $e');
    }
  }

  // Helper to extract course name from event name
  String _extractCourseName(String eventName) {
    final patterns = [
      RegExp(r'[A-Z]{2,4}-\d{3,}[A-Z]?'),
      RegExp(r'[A-Z]{3,5}\d{3,4}'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(eventName);
      if (match != null) {
        return match.group(0) ?? '';
      }
    }
    return 'Course';
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  // Get all events (academic + personal)
  Future<List<CalendarEvent>> getAllEvents(String userId) async {
    final academicEvents = await getCachedAcademicEvents();
    final personalEvents = await getPersonalEvents();

    return [...academicEvents, ...personalEvents];
  }

  // Get events for a specific date
  Future<List<CalendarEvent>> getEventsForDate(DateTime date, String userId) async {
    final allEvents = await getAllEvents(userId);

    return allEvents.where((event) =>
    event.date.year == date.year &&
        event.date.month == date.month &&
        event.date.day == date.day
    ).toList();
  }

  // Update last sync timestamp
  Future<void> updateLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(lastSyncKey, DateTime.now().toIso8601String());
  }

  // Get last sync timestamp
  Future<DateTime?> getLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString(lastSyncKey);
    return timestamp != null ? DateTime.parse(timestamp) : null;
  }

  // Clear all cached events
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(cachedEventsKey);
    await prefs.remove(personalEventsKey);
    await prefs.remove(lastSyncKey);
    print('🗑️ Calendar cache cleared');
  }
}