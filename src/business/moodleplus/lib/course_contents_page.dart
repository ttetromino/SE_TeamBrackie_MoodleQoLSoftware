// lib/course_contents_page.dart
import 'package:flutter/material.dart';
import 'services/course_service.dart';

class CourseContentsPage extends StatefulWidget {
  final String courseName;
  final String courseId;
  final String email;
  final VoidCallback? onActivityCompleted;

  const CourseContentsPage({
    super.key,
    required this.courseName,
    required this.courseId,
    required this.email,
    this.onActivityCompleted,
  });

  @override
  State<CourseContentsPage> createState() => _CourseContentsPageState();
}

class _CourseContentsPageState extends State<CourseContentsPage> {
  final CourseService _courseService = CourseService();
  bool _loading = true;
  Map<String, dynamic>? _courseData;
  String? _errorMessage;
  final Set<String> _expandedSections = {};

  @override
  void initState() {
    super.initState();
    _loadContents();
  }

  Future<void> _loadContents() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // FIRST: Try to get from database cache
      Map<String, dynamic> data = await _courseService.getCourseContentsFromDB(
        widget.email,
        widget.courseId,
      );

      // If no cached data or cache is old, sync fresh
      if (data['sections'] == null || (data['sections'] as List).isEmpty) {
        print('🔄 No cached data, syncing course...');

        // Sync this specific course
        final syncResult = await _courseService.syncCourse(
          email: widget.email,
          courseId: widget.courseId,
          courseName: widget.courseName,
          courseUrl: '', // We don't have URL, but we can get from cache or pass empty
          forceRefresh: true,
        );

        if (syncResult['success'] == true) {
          // Reload from database after sync
          data = await _courseService.getCourseContentsFromDB(
            widget.email,
            widget.courseId,
          );
        }
      }

      if (mounted) {
        setState(() {
          _courseData = data;
          _loading = false;

          final sections = data['sections'] as List? ?? [];
          if (sections.isNotEmpty) {
            final firstSection = sections.first as Map;
            final activities = firstSection['activities'] as List?;
            if (activities != null && activities.isNotEmpty) {
              _expandedSections.add(firstSection['id'].toString());
            }
          }
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = 'Failed to load course contents: $e';
      });
    }
  }

  void _toggleSection(String sectionId) {
    setState(() {
      if (_expandedSections.contains(sectionId)) {
        _expandedSections.remove(sectionId);
      } else {
        _expandedSections.add(sectionId);
      }
    });
  }

  void _expandAllSections() {
    setState(() {
      final sections = _courseData?['sections'] as List? ?? [];
      for (var section in sections) {
        final activities = section['activities'] as List?;
        if (activities != null && activities.isNotEmpty) {
          _expandedSections.add(section['id'].toString());
        }
      }
    });
  }

  void _collapseAllSections() {
    setState(() {
      _expandedSections.clear();
    });
  }

  // Show activity details in a dialog - NO EXTERNAL NAVIGATION
  void _showActivityDetails(Map<String, dynamic> activity) {
    final activityName = activity['name'] ?? 'Unnamed Activity';
    final activityType = activity['type'] ?? 'unknown';
    final activityStatus = activity['completionStatus'] ?? 'todo';
    final isCompleted = activityStatus == 'done';
    final dates = activity['dates'] as List? ?? [];
    final description = activity['description'] ?? 'No description available';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getActivityColor(activityType).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getActivityIcon(activityType),
                color: _getActivityColor(activityType),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                activityName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getActivityColor(activityType).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                activityType.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _getActivityColor(activityType),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Status
            Row(
              children: [
                Icon(
                  isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isCompleted ? Colors.green : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isCompleted ? 'Completed' : 'Not yet completed',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isCompleted ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),

            if (dates.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const Text(
                'Dates',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              ...dates.map((date) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        date,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )),
            ],

            const SizedBox(height: 12),
            const Divider(),
            const Text(
              'Description',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (!isCompleted)
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await _markAsCompleted(activity);
              },
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Mark Complete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _markAsCompleted(Map<String, dynamic> activity) async {
    setState(() => _loading = true);

    final result = await _courseService.markActivityComplete(
      email: widget.email,
      courseId: widget.courseId,
      activityId: activity['id'].toString(),
      isCompleted: true,
    );

    if (result['success'] == true) {
      // SYNC BACKLOG AFTER COMPLETING ACTIVITY
      await _courseService.syncBacklogAfterCompletion(widget.email);

      await _loadContents();

      // NOTIFY BACKLOG - Call the callback to refresh backlog
      widget.onActivityCompleted?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activity marked as complete! Backlog updated.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to mark as complete'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.courseName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (!_loading &&
                _courseData != null &&
                _courseData!['courseTitle'] != null &&
                _courseData!['courseTitle'].toString().isNotEmpty)
              Text(
                _courseData!['courseTitle'].toString(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        backgroundColor: const Color(0xFF9D2BD1),
        foregroundColor: Colors.white,
        actions: [
          if (!_loading &&
              _courseData != null &&
              (_courseData!['sections'] as List?)?.isNotEmpty == true)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'expand') {
                  _expandAllSections();
                } else if (value == 'collapse') {
                  _collapseAllSections();
                } else if (value == 'refresh') {
                  _loadContents();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'expand',
                  child: Row(
                    children: [
                      Icon(Icons.expand_more, size: 20),
                      SizedBox(width: 8),
                      Text('Expand All'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'collapse',
                  child: Row(
                    children: [
                      Icon(Icons.expand_less, size: 20),
                      SizedBox(width: 8),
                      Text('Collapse All'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, size: 20),
                      SizedBox(width: 8),
                      Text('Refresh'),
                    ],
                  ),
                ),
              ],
            ),
        ],
        bottom: _loading
            ? const PreferredSize(
          preferredSize: Size.fromHeight(2),
          child: LinearProgressIndicator(
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9D2BD1)),
            ),
            SizedBox(height: 16),
            Text('Loading course contents...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadContents,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9D2BD1),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    final sections = _courseData?['sections'] as List? ?? [];

    if (sections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No Content Available',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'This course has no sections or activities',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadContents,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9D2BD1),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    // Calculate statistics
    int totalActivities = 0;
    int completedActivities = 0;

    for (var section in sections) {
      final activities = section['activities'] as List? ?? [];
      totalActivities += activities.length;
      for (var activity in activities) {
        if (activity['completionStatus'] == 'done') {
          completedActivities++;
        }
      }
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[50],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatChip(
                icon: Icons.assignment,
                label: 'Activities',
                value: '$totalActivities',
                color: Colors.blue,
              ),
              Container(height: 30, width: 1, color: Colors.grey[300]),
              _buildStatChip(
                icon: Icons.check_circle,
                label: 'Completed',
                value: '$completedActivities',
                color: Colors.green,
              ),
              Container(height: 30, width: 1, color: Colors.grey[300]),
              _buildStatChip(
                icon: Icons.folder,
                label: 'Sections',
                value: '${sections.length}',
                color: Colors.orange,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: sections.length,
            itemBuilder: (context, index) {
              final section = sections[index];
              return _buildSectionCard(section);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionCard(Map<String, dynamic> section) {
    final activities = List<Map<String, dynamic>>.from(section['activities'] ?? []);
    final activitiesWithName = activities.where((a) => a['name'].toString().isNotEmpty).toList();

    if (activitiesWithName.isEmpty) return const SizedBox.shrink();

    final isExpanded = _expandedSections.contains(section['id'].toString());
    final completedInSection = activitiesWithName
        .where((a) => a['completionStatus'] == 'done')
        .length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleSection(section['id'].toString()),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9D2BD1).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        section['number']?.toString() ?? '?',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF9D2BD1),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section['name'] ?? 'Untitled Section',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${activitiesWithName.length} items',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (completedInSection > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey[400],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$completedInSection completed',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: activitiesWithName.length,
              itemBuilder: (context, index) {
                final activity = activitiesWithName[index];
                return _buildActivityTile(activity, index < activitiesWithName.length - 1);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildActivityTile(Map<String, dynamic> activity, bool showDivider) {
    final activityName = activity['name']?.toString() ?? 'Unnamed Activity';
    final activityType = activity['type']?.toString() ?? 'unknown';
    final isCompleted = activity['completionStatus'] == 'done';

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getActivityColor(activityType).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getActivityIcon(activityType),
                color: _getActivityColor(activityType),
                size: 20,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    activityName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (activity['badge'] != null && activity['badge'].toString().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getActivityColor(activityType).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      activity['badge'].toString(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getActivityColor(activityType),
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      activityType.toUpperCase(),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    if (activity['isIndented'] == true) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: const Text(
                          'INDENTED',
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                if (activity['dates'] != null && (activity['dates'] as List).isNotEmpty)
                  ...(activity['dates'] as List).take(1).map(
                        (date) => Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        date.toString(),
                        style: const TextStyle(fontSize: 11, color: Colors.orange),
                      ),
                    ),
                  ),
              ],
            ),
            trailing: isCompleted
                ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                : const Icon(Icons.radio_button_unchecked, color: Colors.orange, size: 20),
            onTap: () => _showActivityDetails(activity),
          ),
          if (showDivider) const Divider(indent: 56),
        ],
      ),
    );
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'forum':
        return Icons.forum;
      case 'assign':
        return Icons.assignment;
      case 'resource':
        return Icons.insert_drive_file;
      case 'quiz':
        return Icons.quiz;
      case 'url':
        return Icons.link;
      case 'page':
        return Icons.web;
      case 'folder':
        return Icons.folder;
      case 'glossary':
        return Icons.menu_book;
      default:
        return Icons.help_outline;
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'forum':
        return Colors.blue;
      case 'assign':
        return Colors.green;
      case 'resource':
        return Colors.purple;
      case 'quiz':
        return Colors.amber;
      case 'url':
        return Colors.teal;
      case 'page':
        return Colors.brown;
      case 'folder':
        return Colors.indigo;
      case 'glossary':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }
}