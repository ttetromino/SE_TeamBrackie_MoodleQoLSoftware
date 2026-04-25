// lib/backlog_filter_drawer.dart
import 'package:flutter/material.dart';

class BacklogFilterDrawer extends StatefulWidget {
  final String currentFilterBy;
  final String currentPriority;
  final String currentCourseCode;
  final bool showPinnedOnly;
  final List<String> availableCourseCodes;
  final Function({
    String? filterBy,
    String? priority,
    String? courseCode,
    bool? showPinnedOnly,
  })
  onApply;

  const BacklogFilterDrawer({
    super.key,
    required this.currentFilterBy,
    required this.currentPriority,
    required this.currentCourseCode,
    required this.showPinnedOnly,
    required this.availableCourseCodes,
    required this.onApply,
  });

  @override
  State<BacklogFilterDrawer> createState() => _BacklogFilterDrawerState();
}

class _BacklogFilterDrawerState extends State<BacklogFilterDrawer> {
  late String _filterBy;
  late String _priority;
  late String _courseCode;
  late bool _showPinnedOnly;

  @override
  void initState() {
    super.initState();
    _filterBy = widget.currentFilterBy;
    _priority = widget.currentPriority;
    _courseCode = widget.currentCourseCode;
    _showPinnedOnly = widget.showPinnedOnly;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filter Tasks',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: _resetFilters,
                child: const Text('Reset All'),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // US-13-T-02: Sort By section
          const Text(
            'Sort By',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildRadioOption(
                value: 'none',
                groupValue: _filterBy,
                label: 'No Filter',
                onChanged: (v) => setState(() => _filterBy = v),
              ),
              const SizedBox(width: 16),
              _buildRadioOption(
                value: 'deadline',
                groupValue: _filterBy,
                label: 'Deadline',
                onChanged: (v) => setState(() => _filterBy = v),
              ),
              const SizedBox(width: 16),
              _buildRadioOption(
                value: 'course',
                groupValue: _filterBy,
                label: 'Course',
                onChanged: (v) => setState(() => _filterBy = v),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // US-13-T-02: Priority Section (Urgent, High, etc.)
          const Text(
            'Priority',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildChipOption(
                'all',
                'All',
                _priority,
                (v) => setState(() => _priority = v),
              ),
              _buildChipOption(
                'urgent',
                'Urgent',
                _priority,
                (v) => setState(() => _priority = v),
                color: Colors.red,
              ),
              _buildChipOption(
                'high',
                'High',
                _priority,
                (v) => setState(() => _priority = v),
                color: Colors.orange,
              ),
              _buildChipOption(
                'medium',
                'Medium',
                _priority,
                (v) => setState(() => _priority = v),
                color: Colors.amber,
              ),
              _buildChipOption(
                'low',
                'Low',
                _priority,
                (v) => setState(() => _priority = v),
                color: Colors.green,
              ),
              _buildChipOption(
                'no_deadline',
                'No Deadline',
                _priority,
                (v) => setState(() => _priority = v),
                color: Colors.grey,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Course filter (only show if courses available)
          if (widget.availableCourseCodes.isNotEmpty) ...[
            const Text(
              'Course',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildChipOption(
                    'all',
                    'All Courses',
                    _courseCode,
                    (v) => setState(() => _courseCode = v),
                  ),
                  ...widget.availableCourseCodes.map(
                    (code) => _buildChipOption(
                      code,
                      code,
                      _courseCode,
                      (v) => setState(() => _courseCode = v),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Show Pinned Only toggle
          Row(
            children: [
              Checkbox(
                value: _showPinnedOnly,
                onChanged: (v) => setState(() => _showPinnedOnly = v ?? false),
                activeColor: const Color(0xFF9D2BD1),
              ),
              const Text('Show pinned items only'),
            ],
          ),

          const SizedBox(height: 24),

          // Apply button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(
                  filterBy: _filterBy,
                  priority: _priority,
                  courseCode: _courseCode,
                  showPinnedOnly: _showPinnedOnly,
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9D2BD1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Apply Filters',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildRadioOption({
    required String value,
    required String groupValue,
    required String label,
    required Function(String) onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio<String>(
          value: value,
          groupValue: groupValue,
          onChanged: (v) => onChanged(v ?? value),
          activeColor: const Color(0xFF9D2BD1),
        ),
        Text(label),
      ],
    );
  }

  Widget _buildChipOption(
    String value,
    String label,
    String selectedValue,
    Function(String) onSelected, {
    Color? color,
  }) {
    final isSelected = selectedValue == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onSelected(value),
        backgroundColor: Colors.grey[100],
        selectedColor:
            color?.withOpacity(0.2) ?? const Color(0xFF9D2BD1).withOpacity(0.2),
        checkmarkColor: color ?? const Color(0xFF9D2BD1),
        labelStyle: TextStyle(
          color: isSelected
              ? (color ?? const Color(0xFF9D2BD1))
              : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _filterBy = 'none';
      _priority = 'all';
      _courseCode = 'all';
      _showPinnedOnly = false;
    });
  }
}
