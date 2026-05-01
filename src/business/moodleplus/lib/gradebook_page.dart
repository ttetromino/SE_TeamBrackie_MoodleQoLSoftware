// lib/gradebook_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/grade_model.dart';
import 'services/grade_service.dart';

class GradebookPage extends StatefulWidget {
  final String email;

  const GradebookPage({super.key, required this.email});

  @override
  State<GradebookPage> createState() => _GradebookPageState();
}

class _GradebookPageState extends State<GradebookPage>
    with SingleTickerProviderStateMixin {
  late GradeService _gradeService;
  late TabController _tabController;

  List<GradeModel> _grades = [];
  GradeSummary? _summary;
  bool _isLoading = true;
  bool _isRefreshing = false;
  DateTime? _lastUpdated;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _gradeService = GradeService();
    _loadGrades();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGrades() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // First try to load cached data (US-05-T-04)
    final cachedGrades = await _gradeService.getCachedGrades();
    final cachedSummary = await _gradeService.getCachedSummary();
    _lastUpdated = await _gradeService.getLastUpdated();

    if (cachedGrades.isNotEmpty && cachedSummary != null) {
      setState(() {
        _grades = cachedGrades;
        _summary = cachedSummary;
        _isLoading = false;
      });
    }

    // Then fetch fresh data from LMS
    await _refreshGrades();
  }

  Future<void> _refreshGrades() async {
    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });

    try {
      final grades = await _gradeService.fetchGradesFromLMS(widget.email);
      final summary = await _gradeService.getCachedSummary();
      _lastUpdated = await _gradeService.getLastUpdated();

      if (mounted) {
        setState(() {
          _grades = grades;
          _summary = summary;
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load grades: $e';
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  String _formatLastUpdated() {
    if (_lastUpdated == null) return 'Never updated';
    final now = DateTime.now();
    final diff = now.difference(_lastUpdated!);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) return 'Just now';
        return '${diff.inMinutes} minutes ago';
      }
      return '${diff.inHours} hours ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${diff.inDays} days ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gradebook'),
        backgroundColor: const Color(0xFF9D2BD1),
        foregroundColor: Colors.white,
        actions: [
          // Refresh button
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshGrades,
            tooltip: 'Refresh grades',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Grades', icon: Icon(Icons.grade)),
            Tab(text: 'Statistics', icon: Icon(Icons.bar_chart)),
          ],
        ),
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
            Text('Loading gradebook...'),
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
              onPressed: _refreshGrades,
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

    if (_grades.isEmpty) {
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
                Icons.grade,
                size: 60,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Grades Available',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Your grades will appear here once available',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshGrades,
              icon: const Icon(Icons.refresh),
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

    return Column(
      children: [
        // Last updated status
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
                    'Last updated: ${_formatLastUpdated()}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              if (_summary != null)
                Row(
                  children: [
                    Icon(Icons.school, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${_summary!.gradedCourses}/${_summary!.totalCourses} courses graded',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
            ],
          ),
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(),
              _buildGradesTab(),
              _buildStatisticsTab(),
            ],
          ),
        ),
      ],
    );
  }

  // US-05-T-03: Overview Tab with GWA
  Widget _buildOverviewTab() {
    if (_summary == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // GWA Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF9D2BD1), const Color(0xFF6B1B9A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'General Weighted Average',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _summary!.formattedGwa,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _summary!.gwaColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _summary!.gwaStatus,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Stats Row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.menu_book,
                  label: 'Total Courses',
                  value: '${_summary!.totalCourses}',
                  color: const Color(0xFF9D2BD1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.check_circle,
                  label: 'Graded',
                  value: '${_summary!.gradedCourses}',
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.trending_up,
                  label: 'Completion',
                  value: '${(_summary!.completionRate * 100).toInt()}%',
                  color: Colors.blue,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Best and Worst Subjects
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Performance Highlights',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildHighlightRow(
                    icon: Icons.emoji_events,
                    label: 'Highest Grade',
                    value: '${_summary!.highestGrade.toStringAsFixed(1)}%',
                    subtitle: _summary!.highestCourse,
                    color: Colors.amber,
                  ),
                  const Divider(height: 24),
                  _buildHighlightRow(
                    icon: Icons.trending_down,
                    label: 'Lowest Grade',
                    value: '${_summary!.lowestGrade.toStringAsFixed(1)}%',
                    subtitle: _summary!.lowestCourse,
                    color: Colors.red,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // US-05-T-03: Grades List Tab
  Widget _buildGradesTab() {
    // Sort grades by grade (highest first)
    final sortedGrades = List<GradeModel>.from(_grades);
    sortedGrades.sort((a, b) {
      if (a.grade == null && b.grade == null) return 0;
      if (a.grade == null) return 1;
      if (b.grade == null) return -1;
      return b.grade!.compareTo(a.grade!);
    });

    return RefreshIndicator(
      onRefresh: _refreshGrades,
      color: const Color(0xFF9D2BD1),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: sortedGrades.length,
        itemBuilder: (context, index) {
          final grade = sortedGrades[index];
          return _buildGradeCard(grade);
        },
      ),
    );
  }

  // Statistics Tab
  Widget _buildStatisticsTab() {
    if (_summary == null) return const SizedBox.shrink();

    final distribution = _summary!.gradeDistribution;
    final totalGraded = distribution.entries
        .where((e) => e.key != 'No Grade')
        .fold(0, (sum, e) => sum + e.value);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grade Distribution Chart
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Grade Distribution',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...distribution.entries.map((entry) {
                    final percentage = totalGraded > 0
                        ? (entry.value / totalGraded) * 100
                        : 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                entry.key,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                '${entry.value} course${entry.value != 1 ? 's' : ''}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percentage / 100,
                              backgroundColor: Colors.grey[200],
                              color: _getDistributionColor(entry.key),
                              minHeight: 8,
                            ),
                          ),
                          if (percentage > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                '${percentage.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Weight Distribution
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Grade Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryRow(
                    label: 'Highest Grade',
                    value: '${_summary!.highestGrade.toStringAsFixed(1)}%',
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryRow(
                    label: 'Lowest Grade',
                    value: '${_summary!.lowestGrade.toStringAsFixed(1)}%',
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryRow(
                    label: 'Average Grade',
                    value: '${_summary!.gwa.toStringAsFixed(1)}%',
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryRow(
                    label: 'Grade Range',
                    value: '${_summary!.lowestGrade.toStringAsFixed(0)}% - '
                        '${_summary!.highestGrade.toStringAsFixed(0)}%',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Last updated info
          Center(
            child: Text(
              'Grades fetched from LMS',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightRow({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGradeCard(GradeModel grade) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: grade.gradeColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          // Could navigate to detailed grade view
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Grade indicator circle
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: grade.gradeColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    grade.gradeIcon,
                    color: grade.gradeColor,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Course info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      grade.courseName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: grade.gradeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            grade.gradeStatus,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: grade.gradeColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${grade.weight} credits',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Grade value
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    grade.formattedGrade,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: grade.gradeColor,
                    ),
                  ),
                  if (grade.letterGrade != null)
                    Text(
                      grade.letterGrade!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Color _getDistributionColor(String range) {
    switch (range) {
      case '90-100':
        return Colors.green;
      case '80-89':
        return Colors.lightGreen;
      case '75-79':
        return Colors.lightGreen.shade700;
      case '70-74':
        return Colors.amber;
      case '60-69':
        return Colors.orange;
      case 'Below 60':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}