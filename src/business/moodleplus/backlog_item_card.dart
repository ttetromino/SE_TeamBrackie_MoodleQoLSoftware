// lib/backlog_item_card.dart
import 'package:flutter/material.dart';
import 'services/backlog_service.dart';

class BacklogItemCard extends StatelessWidget {
  final BacklogItem item;
  final String layoutMode;
  final VoidCallback onTogglePin;
  final VoidCallback onComplete;

  const BacklogItemCard({
    super.key,
    required this.item,
    required this.layoutMode,
    required this.onTogglePin,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: item.urgencyColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: layoutMode == 'expanded'
          ? _buildExpandedCard()
          : _buildCompactCard(context), // Pass context here
    );
  }

  // US-13-T-01: Expanded Card Layout
  Widget _buildExpandedCard() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with type icon and course code
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: item.urgencyColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  item.activityIcon,
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
                      ),
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
                  item.priorityText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: item.urgencyColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Course and section info
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
    // Add context parameter here
    return InkWell(
      onTap: () => _showQuickActions(context),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
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

            // Checkbox for completion
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
                color: item.urgencyColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                item.activityIcon,
                size: 18,
                color: item.urgencyColor,
              ),
            ),

            const SizedBox(width: 12),

            // Task info
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
                  Row(
                    children: [
                      Text(
                        item.courseCode,
                        style: TextStyle(
                          fontSize: 11,
                          color: item.urgencyColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.timer, size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 2),
                      Text(
                        item.formattedTimeRemaining,
                        style: TextStyle(
                          fontSize: 11,
                          color: item.urgencyColor,
                        ),
                      ),
                    ],
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
              onTap: () => Navigator.pop(sheetContext),
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
}
