// lib/backlog_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/backlog_service.dart';
import 'services/course_service.dart';
import 'backlog_filter_drawer.dart';
import 'backlog_item_card.dart';

class BacklogPage extends StatefulWidget {
  final String email;
  final VoidCallback? onTaskCompleted;

  const BacklogPage({super.key, required this.email, this.onTaskCompleted});

  @override
  State<BacklogPage> createState() => _BacklogPageState();
}

class _BacklogPageState extends State<BacklogPage> {
  final BacklogService _backlogService = BacklogService();
  final CourseService _courseService = CourseService();

  List<BacklogItem> _items = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  String _layoutMode = 'compact';
  String? _errorMessage;

  // Selection state for bulk operations
  Set<String> _selectedItemIds = {};
  bool get _isAllSelected => _selectedItemIds.length == _items.length && _items.isNotEmpty;
  bool get _hasSelection => _selectedItemIds.isNotEmpty;

  // Filter state
  String _currentFilterBy = 'none';
  String _currentPriority = 'all';
  String _currentCourseCode = 'all';
  List<String> _availableCourseCodes = [];
  bool _showPinnedOnly = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadBacklogItems();
  }

  Future<void> _loadPreferences() async {
    final layout = await _backlogService.getLayoutPreference(widget.email);
    final filters = await _backlogService.getFilterPreferences(widget.email);

    if (mounted) {
      setState(() {
        _layoutMode = layout;
        _currentFilterBy = filters['filterBy'];
        _currentPriority = filters['priority'];
        _currentCourseCode = filters['courseCode'];
      });
    }
  }

  Future<void> _loadBacklogItems() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedItemIds.clear(); // Clear selection when loading new items
    });

    try {
      final items = await _backlogService.getBacklogItems(
        email: widget.email,
        filterBy: _currentFilterBy == 'none' ? null : _currentFilterBy,
        priority: _currentPriority,
        courseCode: _currentCourseCode == 'all' ? null : _currentCourseCode,
        showPinnedOnly: _showPinnedOnly,
      );

      final courseCodes = items.map((i) => i.courseCode).toSet().toList();
      courseCodes.sort();

      if (mounted) {
        setState(() {
          _items = items;
          _availableCourseCodes = courseCodes;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading backlog items: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load tasks';
        });
      }
    }
  }

  Future<void> _syncBacklog() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
      _errorMessage = null;
    });

    try {
      final count = await _backlogService.syncBacklog(widget.email);

      if (mounted) {
        if (count > 0) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'last_backlog_sync_${widget.email}',
            DateTime.now().toIso8601String(),
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Synced $count new tasks'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          await _loadBacklogItems();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No new tasks found'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Sync error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _togglePin(BacklogItem item) async {
    try {
      final success = await _backlogService.togglePin(item.id, widget.email);
      if (success && mounted) {
        await _loadBacklogItems();
      }
    } catch (e) {
      print('Toggle pin error: $e');
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

    if (confirmed != true) return;

    // Remove from UI immediately for better UX
    setState(() {
      _items.removeWhere((i) => i.id == item.id);
      _selectedItemIds.remove(item.id);
    });

    setState(() => _isLoading = true);

    try {
      final success = await _backlogService.completeItem(
        item.id,
        widget.email,
        item: item,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task completed! Progress updated.'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onTaskCompleted?.call();
      } else {
        // If failed, add the item back
        setState(() {
          _items.add(item);
          _items.sort((a, b) => a.dueDate?.compareTo(b.dueDate ?? DateTime.now()) ?? 0);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to complete task'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _items.add(item);
        _items.sort((a, b) => a.dueDate?.compareTo(b.dueDate ?? DateTime.now()) ?? 0);
      });
      print('Complete task error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to complete task: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Select/Deselect all items
  void _toggleSelectAll() {
    setState(() {
      if (_isAllSelected) {
        _selectedItemIds.clear();
      } else {
        _selectedItemIds = _items.map((item) => item.id).toSet();
      }
    });
  }

  // Bulk complete selected tasks
  Future<void> _completeSelectedTasks() async {
    if (_selectedItemIds.isEmpty) return;

    final selectedItems = _items.where((item) => _selectedItemIds.contains(item.id)).toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Selected Tasks'),
        content: Text('Are you sure you want to mark ${_selectedItemIds.length} task(s) as completed?'),
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
            child: const Text('Complete All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Remove selected items from UI immediately
    if (mounted) {
      setState(() {
        _items.removeWhere((item) => _selectedItemIds.contains(item.id));
        _selectedItemIds.clear();
      });
    }

    if (mounted) {
      setState(() => _isLoading = true);
    }

    int completedCount = 0;
    int failedCount = 0;
    final failedItems = <BacklogItem>[];

    for (final item in selectedItems) {
      final success = await _backlogService.completeItem(
        item.id,
        widget.email,
        item: item,
      );

      if (success) {
        completedCount++;
      } else {
        failedCount++;
        failedItems.add(item);
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Add back any failed items
    if (failedItems.isNotEmpty && mounted) {
      setState(() {
        _items.addAll(failedItems);
        _items.sort((a, b) => a.dueDate?.compareTo(b.dueDate ?? DateTime.now()) ?? 0);
      });
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }

    if (mounted) {
      if (failedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $completedCount tasks completed!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ $completedCount completed, $failedCount failed'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      widget.onTaskCompleted?.call();
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
    // Clear selection when applying filters
    _selectedItemIds.clear();

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
          // Select All button
          if (_items.isNotEmpty)
            IconButton(
              icon: Icon(
                _isAllSelected ? Icons.deselect : Icons.select_all,
                color: Colors.white,
              ),
              onPressed: _toggleSelectAll,
              tooltip: _isAllSelected ? 'Deselect All' : 'Select All',
            ),
          // Bulk Complete button with badge
          if (_hasSelection)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.done_all, color: Colors.green),
                  onPressed: _completeSelectedTasks,
                  tooltip: 'Complete Selected (${_selectedItemIds.length})',
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                    child: Text(
                      '${_selectedItemIds.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
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
          // Filter button with badge
          IconButton(
            icon: Badge(
              isLabelVisible:
              _currentFilterBy != 'none' ||
                  _currentPriority != 'all' ||
                  _showPinnedOnly,
              child: const Icon(Icons.filter_list),
            ),
            onPressed: () {
              // Clear selection when opening filter
              _selectedItemIds.clear();
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
              'No Tasks Found',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Try changing your filters or sync with LMS',
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
            TextButton(
              onPressed: () {
                _applyFilters(
                  filterBy: 'none',
                  priority: 'all',
                  courseCode: 'all',
                  showPinnedOnly: false,
                );
              },
              child: const Text('Clear All Filters'),
            ),
          ],
        ),
      );
    }

    final pinnedItems = _items.where((i) => i.isPinned).toList();
    final unpinnedItems = _items.where((i) => !i.isPinned).toList();

    return RefreshIndicator(
      onRefresh: () async {
        _selectedItemIds.clear();
        await _loadBacklogItems();
      },
      color: const Color(0xFF9D2BD1),
      child: CustomScrollView(
        slivers: [
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
          if (pinnedItems.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.push_pin, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text('PINNED', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: Text('${pinnedItems.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ),
                  ],
                ),
              ),
            ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) => BacklogItemCard(
                item: pinnedItems[index],
                layoutMode: _layoutMode,
                isSelected: _selectedItemIds.contains(pinnedItems[index].id),
                onSelect: () {
                  setState(() {
                    if (_selectedItemIds.contains(pinnedItems[index].id)) {
                      _selectedItemIds.remove(pinnedItems[index].id);
                    } else {
                      _selectedItemIds.add(pinnedItems[index].id);
                    }
                  });
                },
                onTogglePin: () => _togglePin(pinnedItems[index]),
                onComplete: () => _completeTask(pinnedItems[index]),
              ),
              childCount: pinnedItems.length,
            ),
          ),
          if (unpinnedItems.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.list_alt, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text('ALL TASKS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.grey.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                      child: Text('${unpinnedItems.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ),
                  ],
                ),
              ),
            ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) => BacklogItemCard(
                item: unpinnedItems[index],
                layoutMode: _layoutMode,
                isSelected: _selectedItemIds.contains(unpinnedItems[index].id),
                onSelect: () {
                  setState(() {
                    if (_selectedItemIds.contains(unpinnedItems[index].id)) {
                      _selectedItemIds.remove(unpinnedItems[index].id);
                    } else {
                      _selectedItemIds.add(unpinnedItems[index].id);
                    }
                  });
                },
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
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ],
    );
  }
}