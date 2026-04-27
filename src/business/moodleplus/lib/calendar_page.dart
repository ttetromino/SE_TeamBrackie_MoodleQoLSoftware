// lib/calendar_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/calendar_event_model.dart';
import 'services/calendar_service.dart';

class CalendarPage extends StatefulWidget {
  final String email;

  const CalendarPage({super.key, required this.email});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage>
    with SingleTickerProviderStateMixin {
  late CalendarService _calendarService;
  late TabController _tabController;

  List<CalendarEvent> _allEvents = [];
  List<CalendarEvent> _eventsForSelectedDate = [];
  DateTime _currentMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  bool _isSyncing = false;
  String _viewMode = 'month';
  DateTime? _lastSync;

  static const List<String> _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _calendarService = CalendarService();
    _loadEvents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);

    final academicEvents = await _calendarService.getCachedAcademicEvents();
    final personalEvents = await _calendarService.getPersonalEvents();
    _lastSync = await _calendarService.getLastSync();

    setState(() {
      _allEvents = [...academicEvents, ...personalEvents];
      _isLoading = false;
    });

    await _syncCalendar();
  }

  Future<void> _syncCalendar() async {
    setState(() => _isSyncing = true);

    final events = await _calendarService.fetchEventsFromLMS(widget.email);
    final personalEvents = await _calendarService.getPersonalEvents();

    setState(() {
      _allEvents = [...events, ...personalEvents];
      _lastSync = DateTime.now();
      _isSyncing = false;
    });
  }

  Future<void> _addPersonalEvent() async {
    final result = await showDialog<CalendarEvent>(
      context: context,
      builder: (context) => EventCreationDialog(selectedDate: _selectedDate),
    );

    if (result != null) {
      setState(() => _isSyncing = true);

      final success = await _calendarService.addPersonalEvent(widget.email, result);

      if (success) {
        await _loadEvents();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Personal event added!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to add event'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

      setState(() => _isSyncing = false);
    }
  }

  Future<void> _deletePersonalEvent(String eventId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text('Are you sure you want to delete this event?'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isSyncing = true);

      // FIXED: Pass email as first parameter
      final success = await _calendarService.deletePersonalEvent(widget.email, eventId);

      if (success) {
        await _loadEvents();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Event deleted'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      setState(() => _isSyncing = false);
    }
  }

  Future<void> _viewDayEvents(DateTime date) async {
    final events = await _calendarService.getEventsForDate(date, widget.email);

    setState(() {
      _selectedDate = date;
      _eventsForSelectedDate = events;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DayEventsSheet(
        date: _selectedDate,
        events: _eventsForSelectedDate,
        onEventDeleted: () => _loadEvents(),
        onAddEvent: () async {
          Navigator.pop(context);
          await _addPersonalEvent();
        },
        onDeleteEvent: (eventId) => _deletePersonalEvent(eventId), // Add this
        email: widget.email, // Add this
      ),
    );
  }

  String _formatLastSync() {
    if (_lastSync == null) return 'Never synced';
    final diff = DateTime.now().difference(_lastSync!);
    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) return 'Just now';
        return '${diff.inMinutes} min ago';
      }
      return '${diff.inHours} hours ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    }
    return '${diff.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        backgroundColor: const Color(0xFF9D2BD1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.sync),
            onPressed: _isSyncing ? null : _syncCalendar,
            tooltip: 'Sync with LMS',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addPersonalEvent,
            tooltip: 'Add personal event',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Calendar', icon: Icon(Icons.calendar_month)),
            Tab(text: 'Events', icon: Icon(Icons.list_alt)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCalendarTab(),
          _buildEventsListTab(),
        ],
      ),
    );
  }

  Widget _buildCalendarTab() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9D2BD1)),
            ),
            SizedBox(height: 16),
            Text('Loading calendar...'),
          ],
        ),
      );
    }

    if (_allEvents.isEmpty && !_isSyncing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No Calendar Events',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Sync with Moodle to see your deadlines',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _syncCalendar,
              icon: const Icon(Icons.sync),
              label: const Text('Sync Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9D2BD1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey[100],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.update, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Last synced: ${_formatLastSync()}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9D2BD1),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('Academic', style: TextStyle(fontSize: 11)),
                  const SizedBox(width: 12),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('Personal', style: TextStyle(fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _currentMonth = DateTime(
                      _currentMonth.year,
                      _currentMonth.month - 1,
                      1,
                    );
                  });
                },
              ),
              Text(
                '${_monthNames[_currentMonth.month - 1]} ${_currentMonth.year}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _currentMonth = DateTime(
                      _currentMonth.year,
                      _currentMonth.month + 1,
                      1,
                    );
                  });
                },
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _weekdayNames.map((day) {
            return Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        Expanded(
          child: _buildCalendarGrid(),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final startingWeekday = firstDayOfMonth.weekday % 7;
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;

    final List<DateTime?> days = [];

    for (int i = 0; i < startingWeekday; i++) {
      days.add(null);
    }

    for (int i = 1; i <= daysInMonth; i++) {
      days.add(DateTime(_currentMonth.year, _currentMonth.month, i));
    }

    final rows = (days.length / 7).ceil();
    final gridDays = List<DateTime?>.from(days);
    while (gridDays.length < rows * 7) {
      gridDays.add(null);
    }

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.2,
      ),
      itemCount: gridDays.length,
      itemBuilder: (context, index) {
        final date = gridDays[index];
        if (date == null) {
          return Container();
        }

        final dayEvents = _allEvents.where((event) =>
        event.date.year == date.year &&
            event.date.month == date.month &&
            event.date.day == date.day
        ).toList();

        final isToday = date.year == DateTime.now().year &&
            date.month == DateTime.now().month &&
            date.day == DateTime.now().day;

        return GestureDetector(
          onTap: () => _viewDayEvents(date),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isToday ? const Color(0xFF9D2BD1).withOpacity(0.1) : null,
              borderRadius: BorderRadius.circular(8),
              border: isToday
                  ? Border.all(color: const Color(0xFF9D2BD1), width: 2)
                  : null,
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 4,
                  right: 4,
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      color: isToday ? const Color(0xFF9D2BD1) : Colors.black87,
                    ),
                  ),
                ),
                if (dayEvents.isNotEmpty)
                  Positioned(
                    bottom: 4,
                    left: 4,
                    right: 4,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ...dayEvents.take(3).map((event) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: event.type == EventType.academic
                                ? const Color(0xFF9D2BD1)
                                : Colors.green,
                            shape: BoxShape.circle,
                          ),
                        )),
                        if (dayEvents.length > 3)
                          Text(
                            '+${dayEvents.length - 3}',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEventsListTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final Map<DateTime, List<CalendarEvent>> groupedEvents = {};
    for (final event in _allEvents) {
      final dateKey = DateTime(event.date.year, event.date.month, event.date.day);
      if (!groupedEvents.containsKey(dateKey)) {
        groupedEvents[dateKey] = [];
      }
      groupedEvents[dateKey]!.add(event);
    }

    final sortedDates = groupedEvents.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    if (sortedDates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No Events',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Sync with LMS or add personal events',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _syncCalendar,
              icon: const Icon(Icons.sync),
              label: const Text('Sync Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9D2BD1),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final events = groupedEvents[date]!;
        events.sort((a, b) => (a.time?.hour ?? 0).compareTo(b.time?.hour ?? 0));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _formatDateHeader(date),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...events.map((event) => _buildEventCard(event)),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildEventCard(CalendarEvent event) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: event.eventColor.withOpacity(0.3), width: 1),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: event.eventColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(event.eventIcon, color: event.eventColor),
        ),
        title: Text(
          event.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.timeString),
            if (event.courseName != null)
              Text(
                event.courseName!,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
        trailing: event.type == EventType.personal
            ? IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _deletePersonalEvent(event.id), // FIXED: Pass event.id only
        )
            : null,
        onTap: event.eventUrl != null
            ? () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Opening: ${event.title}'),
              backgroundColor: const Color(0xFF9D2BD1),
            ),
          );
        }
            : null,
      ),
    );
  }

  String _formatDateHeader(DateTime date) {
    final today = DateTime.now();
    final tomorrow = DateTime(today.year, today.month, today.day + 1);

    if (date.year == today.year && date.month == today.month && date.day == today.day) {
      return 'Today, ${_monthNames[date.month - 1]} ${date.day}';
    } else if (date.year == tomorrow.year && date.month == tomorrow.month && date.day == tomorrow.day) {
      return 'Tomorrow, ${_monthNames[date.month - 1]} ${date.day}';
    } else {
      return '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';
    }
  }
}

// Event Creation Dialog (US-11-T-03)
class EventCreationDialog extends StatefulWidget {
  final DateTime selectedDate;

  const EventCreationDialog({super.key, required this.selectedDate});

  @override
  State<EventCreationDialog> createState() => _EventCreationDialogState();
}

class _EventCreationDialogState extends State<EventCreationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  late DateTime _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isAllDay = true;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Personal Event'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Event Title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Enter title' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Date'),
                subtitle: Text('${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
              ),
              SwitchListTile(
                title: const Text('All day event'),
                value: _isAllDay,
                onChanged: (value) {
                  setState(() {
                    _isAllDay = value;
                    if (!_isAllDay && _selectedTime == null) {
                      _selectedTime = TimeOfDay.now();
                    }
                  });
                },
              ),
              if (!_isAllDay)
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: const Text('Time'),
                  subtitle: Text(_selectedTime?.format(context) ?? 'Select time'),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _selectedTime ?? TimeOfDay.now(),
                    );
                    if (picked != null) {
                      setState(() => _selectedTime = picked);
                    }
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final event = CalendarEvent(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: _titleController.text,
                description: _descriptionController.text.isNotEmpty
                    ? _descriptionController.text
                    : 'Personal event',
                date: _selectedDate,
                time: _isAllDay ? null : _selectedTime,
                type: EventType.personal,
                courseName: null,
              );
              Navigator.pop(context, event);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF9D2BD1),
            foregroundColor: Colors.white,
          ),
          child: const Text('Add Event'),
        ),
      ],
    );
  }
}

// Day Events Bottom Sheet
class DayEventsSheet extends StatelessWidget {
  final DateTime date;
  final List<CalendarEvent> events;
  final VoidCallback onEventDeleted;
  final VoidCallback onAddEvent;
  final Function(String) onDeleteEvent;
  final String email;

  const DayEventsSheet({
    super.key,
    required this.date,
    required this.events,
    required this.onEventDeleted,
    required this.onAddEvent,
    required this.onDeleteEvent,
    required this.email,
  });

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
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
                    Text(
                      '${_monthNames[date.month - 1]} ${date.day}, ${date.year}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${events.length} event${events.length != 1 ? 's' : ''}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: events.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        'No events for this day',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: onAddEvent,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Event'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9D2BD1),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return _buildEventCard(context, event);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEventCard(BuildContext context, CalendarEvent event) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: event.eventColor.withOpacity(0.3), width: 1),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: event.eventColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(event.eventIcon, color: event.eventColor),
        ),
        title: Text(
          event.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(event.timeString),
        trailing: event.type == EventType.personal
            ? IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => onDeleteEvent(event.id),
        )
            : null,
      ),
    );
  }
}