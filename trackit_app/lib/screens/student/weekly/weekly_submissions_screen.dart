import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/weekly_submission.dart';
import '../../../services/weekly_submissions_service.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/common/back_nav_header.dart';
import '../../../widgets/common/empty_state_view.dart';
import '../../../widgets/common/skeleton_list_tile.dart';
import '../../../widgets/student/student_ui.dart';

/// Weekly Submissions (TrackIT student mockup): the OJT Progress card with
/// one bar segment per week so far, the approved / pending / missing
/// counts, and Weekly Records -- every OJT week including the upcoming
/// ones. Opened from Documents > Weekly Submissions.
class WeeklySubmissionsScreen extends StatefulWidget {
  final WeeklySubmissionsService service;

  /// Re-fetches the weeks whenever this fires.
  final Listenable reloadSignal;

  /// Opens a week's page; resolves to a confirmation message once the
  /// student submitted it, or null if they backed out.
  final Future<String?> Function(WeeklySubmission week) onOpenWeek;

  const WeeklySubmissionsScreen({
    super.key,
    required this.service,
    required this.reloadSignal,
    required this.onOpenWeek,
  });

  @override
  State<WeeklySubmissionsScreen> createState() => _WeeklySubmissionsScreenState();
}

class _WeeklySubmissionsScreenState extends State<WeeklySubmissionsScreen> {
  WeeklySubmissionsData? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.reloadSignal.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.reloadSignal.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await widget.service.getWeeks();
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _open(WeeklySubmission week) async {
    final confirmation = await widget.onOpenWeek(week);
    await _load();
    if (confirmation != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(confirmation), backgroundColor: AppColors.successGreenText),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const BackNavHeader(subtitle: 'Weekly Submissions'),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) return const SkeletonList();
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          EmptyStateView(icon: Icons.cloud_off, title: 'Could not load your weeks', message: '$_error'),
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton(
              onPressed: () {
                setState(() => _loading = true);
                _load();
              },
              child: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    final data = _data!;
    if (data.summary.ojtStartDate == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          EmptyStateView(
            icon: Icons.event_note_outlined,
            title: 'No weeks yet',
            message: 'Finish Account Details Finalization (with your OJT Start Date) under '
                'Documents > OJT Requirements. Your weekly DTR and AR start from that date.',
          ),
        ],
      );
    }

    final weeks = [...data.weeks]..sort((a, b) => a.weekNumber.compareTo(b.weekNumber));
    // Weeks still to come, assuming about 40 hours a week, so the student
    // sees the whole OJT like the mockup (Week 10 ... Week 15 "Upcoming").
    final expected = math.max(weeks.length, (data.summary.requiredHours / 40).ceil());
    final upcoming = <(int, DateTime, DateTime)>[];
    if (weeks.isNotEmpty && !data.summary.isComplete) {
      final last = weeks.last;
      for (var n = last.weekNumber + 1; n <= expected; n++) {
        final offset = Duration(days: 7 * (n - last.weekNumber));
        upcoming.add((n, last.weekStartDate.add(offset), last.weekEndDate.add(offset)));
      }
    }

    return RefreshIndicator(
      color: AppColors.primaryMaroon,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          _ProgressCard(summary: data.summary, weeks: weeks),
          const SizedBox(height: 16),
          const Text('Weekly Records', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (weeks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('Your first week will appear once your OJT starts.', textAlign: TextAlign.center),
            ),
          for (final week in weeks) ...[
            WeekRow(
              weekNumber: week.weekNumber,
              start: week.weekStartDate,
              end: week.weekEndDate,
              status: weekStatusChip(week.status),
              onTap: () => _open(week),
            ),
            const SizedBox(height: 8),
          ],
          for (final (n, start, end) in upcoming) ...[
            WeekRow(weekNumber: n, start: start, end: end, status: upcomingChip, onTap: null),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// Status chip for a week (mockup colors).
StudentStatusPill weekStatusChip(WeeklySubmissionStatus status) {
  switch (status) {
    case WeeklySubmissionStatus.approved:
      return const StudentStatusPill(label: 'Approved', background: Color(0xFFD3EBD7), foreground: Color(0xFF2E7D45));
    case WeeklySubmissionStatus.submitted:
      return const StudentStatusPill(label: 'Pending', background: Color(0xFFFCEBC4), foreground: Color(0xFFD9822B));
    case WeeklySubmissionStatus.rejected:
      return const StudentStatusPill(label: 'Returned', background: Color(0xFFF6D9DB), foreground: Color(0xFF8C1C2A));
    case WeeklySubmissionStatus.missing:
      return const StudentStatusPill(label: 'Missing', background: Color(0xFFE2C6C9), foreground: Color(0xFF6E1423));
  }
}

const upcomingChip = StudentStatusPill(label: 'Upcoming', background: Color(0xFFE3E3E3), foreground: Color(0xFF7A7A7A));

/// One "Week N | dates | status >" row (also the header on a week's page).
class WeekRow extends StatelessWidget {
  final int weekNumber;
  final DateTime start;
  final DateTime end;
  final Widget status;
  final VoidCallback? onTap;
  final bool showChevron;

  const WeekRow({
    super.key,
    required this.weekNumber,
    required this.start,
    required this.end,
    required this.status,
    required this.onTap,
    this.showChevron = true,
  });

  static final _fmt = DateFormat('MMM. d, yyyy');

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFD6D6D6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDEDED),
                  border: Border.all(color: const Color(0xFFF0C9CC)),
                ),
                child: Text(
                  'Week $weekNumber',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: StudentColors.maroon),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_fmt.format(start)} - ${_fmt.format(end)}',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF333333)),
                ),
              ),
              status,
              if (showChevron) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: onTap == null ? const Color(0xFFBDBDBD) : const Color(0xFF1F1F1F)),
              ] else
                const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final WeeklySummary summary;
  final List<WeeklySubmission> weeks;

  const _ProgressCard({required this.summary, required this.weeks});

  static const _green = Color(0xFF1E9E45);
  static const _yellow = Color(0xFFF2C200);
  static const _maroon = Color(0xFF6E1423);

  @override
  Widget build(BuildContext context) {
    final active = weeks.length;
    final approved = weeks.where((w) => w.status == WeeklySubmissionStatus.approved).length;
    final pending = weeks.where((w) => w.status == WeeklySubmissionStatus.submitted).length;
    final missing = weeks.where((w) => w.canSubmit).length;
    return StudentCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('OJT Progress', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$approved',
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w500, color: StudentColors.heading),
                    ),
                    TextSpan(
                      text: '/$active',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w400, color: Color(0xFF1F1F1F)),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${formatHours(summary.completedHours)} HOURS',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: StudentColors.heading),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 18, color: StudentColors.heading),
                ],
              ),
            ],
          ),
          // One segment per week so far; the arrow above marks this week.
          Row(
            children: [
              for (var i = 0; i < math.max(active, 1); i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Expanded(
                  child: Container(
                    height: 8,
                    color: active == 0
                        ? const Color(0xFFD6D6D6)
                        : switch (weeks[i].status) {
                            WeeklySubmissionStatus.approved => _green,
                            WeeklySubmissionStatus.submitted => _yellow,
                            _ => _maroon,
                          },
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Text('$approved week${approved == 1 ? '' : 's'} credited', style: const TextStyle(fontSize: 9, color: Color(0xFF333333))),
              const Spacer(),
              Text('$active active week${active == 1 ? '' : 's'}', style: const TextStyle(fontSize: 9, color: Color(0xFF333333))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CountChip(
                  icon: Icons.check_circle_outline,
                  count: approved,
                  label: 'Approved',
                  color: _green,
                  background: const Color(0xFFDDF3E2),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _CountChip(
                  icon: Icons.schedule,
                  count: pending,
                  label: 'Pending',
                  color: const Color(0xFFE8A317),
                  background: const Color(0xFFFCEBC4),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _CountChip(
                  icon: Icons.error_outline,
                  count: missing,
                  label: 'Missing',
                  color: const Color(0xFFC62828),
                  background: const Color(0xFFFBE3E5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final Color color;
  final Color background;

  const _CountChip({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count Week${count == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F)),
                ),
                Text(label, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
