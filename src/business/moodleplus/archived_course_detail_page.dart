// lib/archived_course_detail_page.dart
import 'package:flutter/material.dart';
import 'services/archive_service.dart';

class ArchivedCourseDetailPage extends StatelessWidget {
  final ArchivedCourse course;

  const ArchivedCourseDetailPage({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          course.courseName,
          style: const TextStyle(fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: const Color(0xFF9D2BD1),
        foregroundColor: Colors.white,
        actions: [
          // Legacy badge in app bar
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'ARCHIVED',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final sections = course.contents['sections'] as List? ?? [];

    if (sections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.archive_outlined,
                size: 60,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Content Available',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'This archived course has no saved content',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9D2BD1),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Info banner - US-04-T-04: Reference Mode indicator
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.orange[50],
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.orange, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'This course is in Reference Mode. Content is view-only from archive.',
                  style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                ),
              ),
            ],
          ),
        ),

        // Statistics banner
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[50],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.calendar_today,
                label: 'Archived',
                value: _formatDate(course.archivedAt),
              ),
              Container(height: 30, width: 1, color: Colors.grey[300]),
              _buildStatItem(
                icon: Icons.assignment,
                label: 'Activities',
                value: '${course.totalActivities}',
              ),
              Container(height: 30, width: 1, color: Colors.grey[300]),
              _buildStatItem(
                icon: Icons.check_circle,
                label: 'Completed',
                value: '${course.completedActivities}',
              ),
            ],
          ),
        ),

        // Sections list (view-only)
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: sections.length,
            itemBuilder: (context, index) {
              final section = sections[index];
              return _buildSectionCard(context, section);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildSectionCard(BuildContext context, Map<String, dynamic> section) {
    final activities = List<Map<String, dynamic>>.from(
      section['activities'] ?? [],
    );
    if (activities.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                section['number']?.toString() ?? '?',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          title: Text(
            section['name'] ?? 'Untitled Section',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${activities.length} items • View only',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          children: activities.map((activity) {
            return _buildActivityTile(activity);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildActivityTile(Map<String, dynamic> activity) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 72, right: 16),
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _getActivityColor(activity['type']).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          _getActivityIcon(activity['type']),
          color: _getActivityColor(activity['type']),
          size: 18,
        ),
      ),
      title: Text(
        activity['name'] ?? 'Unnamed Activity',
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        activity['type']?.toUpperCase() ?? 'UNKNOWN',
        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
      ),
      trailing: activity['completionStatus'] == 'done'
          ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
          : const Icon(
              Icons.radio_button_unchecked,
              color: Colors.grey,
              size: 20,
            ),
      onTap: null, // No tap action in reference mode
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
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
