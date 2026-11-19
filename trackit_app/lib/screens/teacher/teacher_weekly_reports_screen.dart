import 'package:flutter/material.dart';
import '../../models/teacher_weekly_report_row.dart';
import '../../models/weekly_submission.dart';
import '../../services/api_client.dart';
import '../../services/teacher_weekly_reports_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/common/back_nav_header.dart';
import '../../widgets/common/empty_state_view.dart';
import '../../widgets/common/filter_chip_pill.dart';
import '../../widgets/common/skeleton_list_tile.dart';

/// Weekly DTR & AR review: every assigned student with their credited
/// hours, students with weeks waiting for review first.
class TeacherWeeklyReportsScreen extends StatefulWidget {
  final TeacherWeeklyReportsService service;

  /// Opens one student's weeks; the list reloads when it returns, since
  /// approving/returning weeks there changes these numbers.
  final Future<void> Function(int studentId) onOpenStudent;

  const TeacherWeeklyReportsScreen({
    super.key,
    required this.service,
    required this.onOpenStudent,
  });

  @override
  State<TeacherWeeklyReportsScreen> createState() => _TeacherWeeklyReportsScreenState();
}

class _TeacherWeeklyReportsScreenState extends State<TeacherWeeklyReportsScreen> {
  List<TeacherWeeklyStudent> _students = [];
  bool _loading = true;
  Object? _error;
  String _query = '';
  bool _onlyToReview = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final students = await widget.service.getStudents();
      if (!mounted) return;
      setState(() {
        _students = students;
        _error = null;
        _loading = false;
        // Start on "To Review" when there is something to review.
        if (_students.any((s) => s.summary.pendingReviewWeeks > 0) && !_touchedFilter) {
          _onlyToReview = true;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  bool _touchedFilter = false;

  int get _toReviewWeeks =>
      _students.fold(0, (sum, s) => sum + s.summary.pendingReviewWeeks);

  List<TeacherWeeklyStudent> get _filtered {
    final q = _query.toLowerCase();
    return _students.where((s) {
      if (_onlyToReview && s.summary.pendingReviewWeeks == 0) return false;
      return q.isEmpty || s.name.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _open(TeacherWeeklyStudent student) async {
    await widget.onOpenStudent(student.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Column(
        children: [
          const BackNavHeader(subtitle: 'Weekly DTR & AR Review'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search Student...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.cardWhite,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                FilterChipPill(
                  label: 'To Review ($_toReviewWeeks)',
                  selected: _onlyToReview,
                  onTap: () => setState(() {
                    _touchedFilter = true;
                    _onlyToReview = true;
                  }),
                ),
                const SizedBox(width: 8),
                FilterChipPill(
                  label: 'All Students (${_students.length})',
                  selected: !_onlyToReview,
                  onTap: () => setState(() {
                    _touchedFilter = true;
                    _onlyToReview = false;
                  }),
                ),
              ],
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const SkeletonList();
    if (_error != null) {
      return ListView(
        children: [
          EmptyStateView(
            icon: Icons.cloud_off,
            title: 'Could not load students',
            message: '$_error',
          ),
          Center(child: OutlinedButton(onPressed: _load, child: const Text('Retry'))),
        ],
      );
    }
    final students = _filtered;
    return RefreshIndicator(
      color: AppColors.primaryMaroon,
      onRefresh: _load,
      child: students.isEmpty
          ? ListView(
              children: [
                EmptyStateView(
                  icon: _onlyToReview ? Icons.task_alt : Icons.summarize_outlined,
                  title: _onlyToReview ? 'All caught up' : 'No students found',
                  message: _onlyToReview
                      ? 'No weekly DTR & AR is waiting for your review.'
                      : 'Try a different search.',
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: students.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final student = students[index];
                return _StudentTile(student: student, onTap: () => _open(student));
              },
            ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  final TeacherWeeklyStudent student;
  final VoidCallback onTap;

  const _StudentTile({required this.student, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = student.summary;
    final ratio = s.requiredHours > 0 ? (s.completedHours / s.requiredHours).clamp(0.0, 1.0) : 0.0;

    final Widget badge;
    if (s.pendingReviewWeeks > 0) {
      badge = _Pill(
        text: '${s.pendingReviewWeeks} to review',
        color: AppColors.statOrangeIcon,
        background: AppColors.statOrangeBg,
      );
    } else if (s.isComplete) {
      badge = const _Pill(
        text: 'Complete',
        color: AppColors.successGreenText,
        background: AppColors.successGreenBg,
      );
    } else if (s.ojtStartDate == null) {
      badge = const _Pill(
        text: 'Not started',
        color: AppColors.textSecondary,
        background: AppColors.chipGrayBg,
      );
    } else {
      badge = const SizedBox.shrink();
    }

    return Material(
      color: AppColors.cardWhite,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.background,
                backgroundImage: student.avatarUrl != null
                    ? NetworkImage(ApiClient.resolveUrl(student.avatarUrl!))
                    : null,
                child: student.avatarUrl == null
                    ? const Icon(Icons.person, color: AppColors.primaryMaroon, size: 18)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            student.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        badge,
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${student.course} - ${student.section}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 6,
                        backgroundColor: AppColors.background,
                        valueColor: const AlwaysStoppedAnimation(AppColors.primaryMaroon),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatHours(s.completedHours)} / ${formatHours(s.requiredHours)} hrs credited'
                      '${s.pendingHours > 0 ? '  ·  ${formatHours(s.pendingHours)} hrs pending' : ''}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;

  const _Pill({required this.text, required this.color, required this.background});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
