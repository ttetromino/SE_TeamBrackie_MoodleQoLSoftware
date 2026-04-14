import 'package:flutter/material.dart';
import 'services/lms_service.dart';

class CourseContentsPage extends StatefulWidget {
  final String courseName;
  final String courseUrl;
  final LMSService lmsService;

  const CourseContentsPage({
    super.key,
    required this.courseName,
    required this.courseUrl,
    required this.lmsService,
  });

  @override
  State<CourseContentsPage> createState() => _CourseContentsPageState();
}

class _CourseContentsPageState extends State<CourseContentsPage> {
  bool _loading = true;
  CourseContents? _courseContents;
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
      final contents = await widget.lmsService.getCourseContents(
        widget.courseUrl,
      );

      setState(() {
        _courseContents = contents;
        _loading = false;

        // Auto-expand first section if available
        if (contents.sections.isNotEmpty &&
            contents.sections.first.activities.isNotEmpty) {
          _expandedSections.add(contents.sections.first.id);
        }
      });
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
      if (_courseContents != null) {
        for (var section in _courseContents!.sections) {
          if (section.activities.isNotEmpty) {
            _expandedSections.add(section.id);
          }
        }
      }
    });
  }

  void _collapseAllSections() {
    setState(() {
      _expandedSections.clear();
    });
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
                _courseContents != null &&
                _courseContents!.courseTitle.isNotEmpty)
              Text(
                _courseContents!.courseTitle,
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
              _courseContents != null &&
              _courseContents!.sections.isNotEmpty)
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

    if (_courseContents == null || _courseContents!.sections.isEmpty) {
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
    int totalActivities = _courseContents!.sections.fold(
      0,
      (sum, section) => sum + section.activities.length,
    );
    int completedActivities = _courseContents!.sections.fold(
      0,
      (sum, section) =>
          sum +
          section.activities.where((a) => a.completionStatus == 'done').length,
    );

    return Column(
      children: [
        // Statistics Header
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
                value: '${_courseContents!.sections.length}',
                color: Colors.orange,
              ),
            ],
          ),
        ),

        // Sections List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _courseContents!.sections.length,
            itemBuilder: (context, index) {
              final section = _courseContents!.sections[index];
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

  Widget _buildSectionCard(CourseSection section) {
    // Filter out activities with no name
    final activities = section.activities
        .where((a) => a.name.isNotEmpty)
        .toList();
    if (activities.isEmpty) return const SizedBox.shrink();

    final isExpanded = _expandedSections.contains(section.id);
    final completedInSection = activities
        .where((a) => a.completionStatus == 'done')
        .length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Section Header
          InkWell(
            onTap: () => _toggleSection(section.id),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
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
                        section.number,
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
                          section.name,
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
                              '${activities.length} items',
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

          // Activities List (if expanded)
          if (isExpanded)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: activities.length,
              itemBuilder: (context, index) {
                final activity = activities[index];
                return _buildActivityTile(
                  activity,
                  index < activities.length - 1,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildActivityTile(CourseActivity activity, bool showDivider) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getActivityColor(
                  activity.type,
                  activity.badge,
                ).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getActivityIcon(activity.type, activity.badge),
                color: _getActivityColor(activity.type, activity.badge),
                size: 20,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    activity.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (activity.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _getActivityColor(
                        activity.type,
                        activity.badge,
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      activity.badge!,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getActivityColor(activity.type, activity.badge),
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
                      activity.type.toUpperCase(),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    if (activity.isIndented) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: const Text(
                          'INDENTED',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (activity.dates.isNotEmpty)
                  ...activity.dates.map(
                    (date) => Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        date,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            trailing: _buildCompletionIndicator(activity.completionStatus),
            onTap: activity.url != null
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Opening ${activity.type}...'),
                        duration: const Duration(seconds: 1),
                        backgroundColor: const Color(0xFF9D2BD1),
                      ),
                    );
                    // Here you can add navigation to open the activity URL
                    // You might want to open it in a WebView or browser
                  }
                : null,
          ),
          if (showDivider) const Divider(indent: 56),
        ],
      ),
    );
  }

  Widget _buildCompletionIndicator(String status) {
    switch (status) {
      case 'done':
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle, color: Colors.green, size: 20),
        );
      case 'todo':
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.radio_button_unchecked,
            color: Colors.orange,
            size: 20,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  IconData _getActivityIcon(String type, String? badge) {
    switch (type) {
      case 'forum':
        return Icons.forum;
      case 'assign':
        return Icons.assignment;
      case 'resource':
        if (badge?.toLowerCase() == 'pdf') return Icons.picture_as_pdf;
        if (badge?.toLowerCase() == 'html') return Icons.html;
        if (badge?.toLowerCase() == 'video') return Icons.video_library;
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

  Color _getActivityColor(String type, String? badge) {
    switch (type) {
      case 'forum':
        return Colors.blue;
      case 'assign':
        return Colors.green;
      case 'resource':
        if (badge?.toLowerCase() == 'pdf') return Colors.red;
        if (badge?.toLowerCase() == 'html') return Colors.orange;
        if (badge?.toLowerCase() == 'video') return Colors.purple;
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
