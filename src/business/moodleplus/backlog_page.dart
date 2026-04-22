// lib/backlog_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/backlog_service.dart';
import 'backlog_filter_drawer.dart';
import 'backlog_item_card.dart';

class BacklogPage extends StatefulWidget {
  final String email;

  const BacklogPage({super.key, required this.email});

  @override
  State<BacklogPage> createState() => _BacklogPageState();
}

class _BacklogPageState extends State<BacklogPage> {
  final BacklogService _backlogService = BacklogService();

  List<BacklogItem> _items = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  String _layoutMode = 'compact';

  // Filter state
  String _currentFilterBy = 'none';
  String _currentPriority = 'all';
  String _currentCourseCode = 'all';
  List<String> _availableCourseCodes = [];
  bool _showPinnedOnly = false;

  // Sync timer
  static const int syncIntervalMinutes = 60;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadBacklogItems();
    _checkAndSync();
  }

  Future<void> _loadPreferences() async {
    final layout = await _backlogService.getLayoutPreference(widget.email);
    final filters = await _backlogService.getFilterPreferences(widget.email);

    setState(() {
      _layoutMode = layout;
      _currentFilterBy = filters['filterBy'];
      _currentPriority = filters['priority'];
      _currentCourseCode = filters['courseCode'];
    });
  }

  Future<void> _loadBacklogItems() async {
    setState(() => _isLoading = true);

    final items = await _backlogService.getBacklogItems(
      email: widget.email,
      filterBy: _currentFilterBy == 'none' ? null : _currentFilterBy,
      priority: _currentPriority,
      courseCode: _currentCourseCode == 'all' ? null : _currentCourseCode,
      showPinnedOnly: _showPinnedOnly,
    );

    // Extract unique course codes for filter
    final courseCodes = items.map((i) => i.courseCode).toSet().toList();
    courseCodes.sort();

    setState(() {
      _items = items;
      _availableCourseCodes = courseCodes;
      _isLoading = false;
    });
  }

  Future<void> _checkAndSync() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString('last_backlog_sync_${widget.email}');
    final shouldSync =
        lastSync == null ||
        DateTime.now().difference(DateTime.parse(lastSync)).inMinutes >
            syncIntervalMinutes;

    if (shouldSync) {
      await _syncBacklog();
    }
  }

  Future<void> _syncBacklog() async {
    setState(() => _isSyncing = true);

    final count = await _backlogService.syncBacklog(widget.email);

    if (count > 0) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'last_backlog_sync_${widget.email}',
        DateTime.now().toIso8601String(),
      );
      await _loadBacklogItems();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Synced $count new tasks'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }

    setState(() => _isSyncing = false);
  }

  Future<void> _togglePin(BacklogItem item) async {
    final success = await _backlogService.togglePin(item.id, widget.email);
    if (success) {
      await _loadBacklogItems();
    }
  }

  Future<void> _completeTask(BacklogItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Task'),
        content: Text('Mark "${item.activityName}" as completed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _backlogService.completeItem(item.id, widget.email);
      if (success) {
        await _loadBacklogItems();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Task completed!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  void _toggleLayout() {
    final newMode = _layoutMode == 'compact' ? 'expanded' : 'compact';
    setState(() => _layoutMode = newMode);
    _backlogService.saveLayoutPreference(widget.email, newMode);
  }

  void _applyFilters({
    String? filterBy,
    String? priority,
    String? courseCode,
    bool? showPinnedOnly,
  }) async {
    setState(() {
      _currentFilterBy = filterBy ?? _currentFilterBy;
      _currentPriority = priority ?? _currentPriority;
      _currentCourseCode = courseCode ?? _currentCourseCode;
      _showPinnedOnly = showPinnedOnly ?? _showPinnedOnly;
    });

    await _backlogService.saveFilterPreferences(widget.email, {
      'filterBy': _currentFilterBy,
      'priority': _currentPriority,
      'courseCode': _currentCourseCode,
    });

    await _loadBacklogItems();
  }

  int get _pinnedCount => _items.where((i) => i.isPinned).length;
  int get _urgentCount => _items.where((i) => i.priority == 'urgent').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Backlog'),
        backgroundColor: const Color(0xFF9D2BD1),
        foregroundColor: Colors.white,
        actions: [
          // Layout toggle button
          IconButton(
            icon: Icon(
              _layoutMode == 'compact' ? Icons.view_module : Icons.view_agenda,
            ),
            onPressed: _toggleLayout,
            tooltip: _layoutMode == 'compact'
                ? 'Switch to expanded view'
                : 'Switch to compact view',
          ),
          // Sync button
          Stack(
            children: [
              IconButton(
                icon: _isSyncing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sync),
                onPressed: _isSyncing ? null : _syncBacklog,
                tooltip: 'Sync with LMS',
              ),
            ],
          ),
          // Filter button
          IconButton(
            icon: Badge(
              isLabelVisible:
                  _currentFilterBy != 'none' ||
                  _currentPriority != 'all' ||
                  _showPinnedOnly,
              child: const Icon(Icons.filter_list),
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) => BacklogFilterDrawer(
                  currentFilterBy: _currentFilterBy,
                  currentPriority: _currentPriority,
                  currentCourseCode: _currentCourseCode,
                  showPinnedOnly: _showPinnedOnly,
                  availableCourseCodes: _availableCourseCodes,
                  onApply: _applyFilters,
                ),
              );
            },
            tooltip: 'Filter tasks',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9D2BD1)),
            ),
            SizedBox(height: 16),
            Text('Loading your tasks...'),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
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
                Icons.check_circle_outline,
                size: 60,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Tasks',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'All caught up! No pending tasks.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _syncBacklog,
              icon: const Icon(Icons.sync),
              label: const Text('Sync with LMS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9D2BD1),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    // Separate pinned and unpinned items
    final pinnedItems = _items.where((i) => i.isPinned).toList();
    final unpinnedItems = _items.where((i) => !i.isPinned).toList();

    return RefreshIndicator(
      onRefresh: _loadBacklogItems,
      color: const Color(0xFF9D2BD1),
      child: CustomScrollView(
        slivers: [
          // Stats header
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[50],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatChip(
                    icon: Icons.task,
                    label: 'Total',
                    value: '${_items.length}',
                    color: const Color(0xFF9D2BD1),
                  ),
                  Container(height: 30, width: 1, color: Colors.grey[300]),
                  _buildStatChip(
                    icon: Icons.push_pin,
                    label: 'Pinned',
                    value: '$_pinnedCount',
                    color: Colors.blue,
                  ),
                  Container(height: 30, width: 1, color: Colors.grey[300]),
                  _buildStatChip(
                    icon: Icons.warning,
                    label: 'Urgent',
                    value: '$_urgentCount',
                    color: Colors.red,
                  ),
                ],
              ),
            ),
          ),

          // Pinned section
          if (pinnedItems.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.push_pin, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text(
                      'PINNED',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${pinnedItems.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Pinned items
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => BacklogItemCard(
                item: pinnedItems[index],
                layoutMode: _layoutMode,
                onTogglePin: () => _togglePin(pinnedItems[index]),
                onComplete: () => _completeTask(pinnedItems[index]),
              ),
              childCount: pinnedItems.length,
            ),
          ),

          // All tasks section
          if (unpinnedItems.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.list_alt, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text(
                      'ALL TASKS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${unpinnedItems.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Unpinned items
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => BacklogItemCard(
                item: unpinnedItems[index],
                layoutMode: _layoutMode,
                onTogglePin: () => _togglePin(unpinnedItems[index]),
                onComplete: () => _completeTask(unpinnedItems[index]),
              ),
              childCount: unpinnedItems.length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
}
