// lib/backlog_item_card.dart
import 'package:flutter/material.dart';
import 'services/backlog_service.dart';

class BacklogItemCard extends StatelessWidget {
  final BacklogItem item;
  final String layoutMode;
  final VoidCallback onTogglePin;
  final VoidCallback onComplete;
  final bool isSelected;
  final VoidCallback? onSelect;

  const BacklogItemCard({
    super.key,
    required this.item,
    required this.layoutMode,
    required this.onTogglePin,
    required this.onComplete,
    this.isSelected = false,
    this.onSelect,
  });

  String _getPastDueMessage(DateTime dueDate) {
    final now = DateTime.now();
    final daysPast = now.difference(dueDate).inDays;
    if (daysPast == 0) {
      final hoursPast = now.difference(dueDate).inHours;
      return 'This activity was due ${hoursPast} hour${hoursPast != 1 ? 's' : ''} ago';
    }
    return 'This activity has been due for $daysPast day${daysPast != 1 ? 's' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? const Color(0xFF9D2BD1)
              : item.urgencyColor.withValues(alpha: 0.3),
          width: isSelected ? 2 : 1.5,
        ),
      ),
      child: layoutMode == 'expanded'
          ? _buildExpandedCard(context)
          : _buildCompactCard(context),
    );
  }

  // US-13-T-01: Expanded Card Layout
  Widget _buildExpandedCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with checkbox, type icon and course code
          Row(
            children: [
              // Select checkbox
              if (onSelect != null)
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => onSelect?.call(),
                  activeColor: const Color(0xFF9D2BD1),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: item.urgencyColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getActivityIcon(item.activityType),
                  size: 20,
                  color: item.urgencyColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.courseCode,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: item.urgencyColor,
                        overflow: TextOverflow.ellipsis,
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.activityName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Priority badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: item.urgencyColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: item.urgencyColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  _getPriorityDisplay(item.priority),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: item.urgencyColor,
                  ),
                  maxLines: 1,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Course info
          Row(
            children: [
              Icon(Icons.school, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  item.courseName,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Section/Week info
          if (item.sectionName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.folder, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.sectionName,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          // Activity type badge
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getActivityColor(item.activityType).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _getActivityTypeDisplay(item.activityType),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: _getActivityColor(item.activityType),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Deadline countdown (US-13-T-03)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: item.urgencyColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, size: 18, color: item.urgencyColor),
                const SizedBox(width: 8),
                Text(
                  item.formattedTimeRemaining,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: item.urgencyColor,
                  ),
                ),
                if (item.dueDate != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '• Due: ${_formatDate(item.dueDate!)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
          if (item.priority == 'past_due' && item.dueDate != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, size: 16, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getPastDueMessage(item.dueDate!),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],


          const SizedBox(height: 12),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Pin button
              TextButton.icon(
                onPressed: onTogglePin,
                icon: Icon(
                  item.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  size: 18,
                  color: item.isPinned ? Colors.blue : Colors.grey,
                ),
                label: Text(
                  item.isPinned ? 'Pinned' : 'Pin',
                  style: TextStyle(
                    color: item.isPinned ? Colors.blue : Colors.grey,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Details button
              TextButton.icon(
                onPressed: () => _showDetailsDialog(context),
                icon: const Icon(Icons.info_outline, size: 18),
                label: const Text('Details'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF9D2BD1),
                ),
              ),
              const SizedBox(width: 8),
              // Complete button
              ElevatedButton.icon(
                onPressed: onComplete,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Complete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // US-13-T-01: Compact Card Layout
  Widget _buildCompactCard(BuildContext context) {
    return InkWell(
      onTap: () => _showQuickActions(context),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Select checkbox
            if (onSelect != null)
              Checkbox(
                value: isSelected,
                onChanged: (_) => onSelect?.call(),
                activeColor: const Color(0xFF9D2BD1),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            // Status indicator (color-coded border left)
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: item.urgencyColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),

            // Checkbox for completion (Status indicator)
            Checkbox(
              value: false,
              onChanged: (_) => onComplete(),
              activeColor: Colors.green,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),

            const SizedBox(width: 4),

            // Activity type icon
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _getActivityColor(item.activityType).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getActivityIcon(item.activityType),
                size: 18,
                color: _getActivityColor(item.activityType),
              ),
            ),

            const SizedBox(width: 12),

            // Task info - TITLE and TYPE
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.activityName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getActivityTypeDisplay(item.activityType),
                    style: TextStyle(
                      fontSize: 10,
                      color: _getActivityColor(item.activityType),
                    ),
                  ),
                ],
              ),
            ),

            // Pin button
            IconButton(
              onPressed: onTogglePin,
              icon: Icon(
                item.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                size: 18,
                color: item.isPinned ? Colors.blue : Colors.grey,
              ),
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getActivityColor(item.activityType).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getActivityIcon(item.activityType),
                color: _getActivityColor(item.activityType),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.activityName,
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
            _buildDetailRow(Icons.school, 'Course', item.courseName),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.code, 'Course Code', item.courseCode),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.folder, 'Week/Section', item.sectionName.isEmpty ? 'Not specified' : item.sectionName),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.category, 'Type', _getActivityTypeDisplay(item.activityType)),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.priority_high, 'Priority', item.priorityText),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.calendar_today, 'Due Date',
                item.dueDate != null ? _formatDate(item.dueDate!) : 'No deadline'),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.timer, 'Time Remaining', item.formattedTimeRemaining),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              onComplete();
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 12),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  void _showQuickActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.info_outline, color: item.urgencyColor),
              title: const Text('Task Details'),
              subtitle: Text(item.activityName),
              onTap: () {
                Navigator.pop(sheetContext);
                _showDetailsDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer, color: Colors.orange),
              title: const Text('Due Date'),
              subtitle: Text(item.formattedTimeRemaining),
              onTap: () => Navigator.pop(sheetContext),
            ),
            ListTile(
              leading: Icon(
                item.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: Colors.blue,
              ),
              title: Text(item.isPinned ? 'Unpin Task' : 'Pin Task'),
              onTap: () {
                Navigator.pop(sheetContext);
                onTogglePin();
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text('Mark as Complete'),
              onTap: () {
                Navigator.pop(sheetContext);
                onComplete();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getActivityTypeDisplay(String type) {
    switch (type) {
      case 'assign':
        return '📝 Assignment';
      case 'quiz':
        return '📝 Quiz';
      case 'forum':
        return '💬 Discussion';
      case 'resource':
        return '📄 Resource';
      case 'page':
        return '📄 Page';
      default:
        return '📋 Task';
    }
  }

  String _getPriorityDisplay(String priority) {
    switch (priority) {
      case 'urgent':
        return 'URGENT';
      case 'high':
        return 'HIGH';
      case 'medium':
        return 'MEDIUM';
      case 'low':
        return 'LOW';
      case 'past_due':
        return 'PAST DUE';
      default:
        return 'NO DEADLINE';
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'assign':
        return Icons.assignment;
      case 'quiz':
        return Icons.quiz;
      case 'forum':
        return Icons.forum;
      case 'resource':
        return Icons.insert_drive_file;
      case 'page':
        return Icons.web;
      default:
        return Icons.task;
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'assign':
        return Colors.green;
      case 'quiz':
        return Colors.amber;
      case 'forum':
        return Colors.blue;
      case 'resource':
        return Colors.purple;
      case 'page':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}