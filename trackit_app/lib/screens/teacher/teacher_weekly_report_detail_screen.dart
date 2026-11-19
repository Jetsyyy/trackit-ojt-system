import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/teacher_weekly_report_row.dart';
import '../../models/weekly_submission.dart';
import '../../services/api_client.dart';
import '../../services/teacher_weekly_reports_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/attachment_kind.dart';
import '../../utils/attachment_launcher.dart';
import '../../widgets/common/back_nav_header.dart';
import '../../widgets/common/empty_state_view.dart';
import '../../widgets/common/skeleton_list_tile.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/student/weekly/weekly_submission_tile.dart';

/// One student's weekly DTR & AR submissions. Weeks waiting for review
/// can be approved (hours are credited) or returned with remarks.
class TeacherWeeklyReportDetailScreen extends StatefulWidget {
  final int studentId;
  final TeacherWeeklyReportsService service;

  const TeacherWeeklyReportDetailScreen({
    super.key,
    required this.studentId,
    required this.service,
  });

  @override
  State<TeacherWeeklyReportDetailScreen> createState() =>
      _TeacherWeeklyReportDetailScreenState();
}

class _TeacherWeeklyReportDetailScreenState extends State<TeacherWeeklyReportDetailScreen> {
  TeacherStudentWeeks? _data;
  Object? _error;
  bool _loading = true;
  int? _busyWeek;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await widget.service.getStudentWeeks(widget.studentId);
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

  /// Weeks waiting for review first (oldest first, so they're reviewed in
  /// order), then everything else newest first.
  List<WeeklySubmission> get _orderedWeeks {
    final weeks = [...?_data?.weeks];
    final waiting = weeks.where((w) => w.status == WeeklySubmissionStatus.submitted).toList()
      ..sort((a, b) => a.weekNumber.compareTo(b.weekNumber));
    final rest = weeks.where((w) => w.status != WeeklySubmissionStatus.submitted).toList()
      ..sort((a, b) => b.weekNumber.compareTo(a.weekNumber));
    return [...waiting, ...rest];
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.statRedIcon : AppColors.successGreenText,
      ),
    );
  }

  Future<void> _review(WeeklySubmission week, {required bool approve, String? remarks}) async {
    setState(() => _busyWeek = week.weekNumber);
    try {
      final data = await widget.service.reviewWeek(
        studentId: widget.studentId,
        weekNumber: week.weekNumber,
        approve: approve,
        remarks: remarks,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _busyWeek = null;
      });
      _snack(
        approve
            ? 'Week ${week.weekNumber} approved. '
                '${formatHours(week.claimedHours ?? 0)} hrs credited.'
            : 'Week ${week.weekNumber} returned to the student.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyWeek = null);
      _snack(e is ApiException ? e.message : 'Could not save. Please try again.', error: true);
      await _load();
    }
  }

  Future<void> _confirmApprove(WeeklySubmission week) async {
    final hours = formatHours(week.claimedHours ?? 0);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Approve Week ${week.weekNumber}?'),
        content: Text(
          'Approve only if the DTR and AR match. $hours hours will be added to '
          '${_data?.student.name ?? 'the student'}\'s credited hours, and the '
          'week will be locked.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.successGreenText,
              foregroundColor: Colors.white,
            ),
            child: Text('Approve $hours hrs'),
          ),
        ],
      ),
    );
    if (ok == true) await _review(week, approve: true);
  }

  Future<void> _askReturn(WeeklySubmission week) async {
    final remarks = await showDialog<String>(
      context: context,
      builder: (context) => _ReturnDialog(weekNumber: week.weekNumber),
    );
    if (remarks != null) await _review(week, approve: false, remarks: remarks);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return SafeArea(
      top: false,
      bottom: false,
      child: Column(
        children: [
          BackNavHeader(subtitle: data?.student.name ?? 'Weekly DTR & AR'),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const SkeletonList();
    if (_error != null || _data == null) {
      return ListView(
        children: [
          EmptyStateView(
            icon: Icons.cloud_off,
            title: 'Could not load this student',
            message: '${_error ?? ''}',
          ),
          Center(child: OutlinedButton(onPressed: _load, child: const Text('Retry'))),
        ],
      );
    }
    final data = _data!;
    final summary = data.student.summary;
    if (summary.ojtStartDate == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          EmptyStateView(
            icon: Icons.event_note_outlined,
            title: 'No weeks yet',
            message: 'This student hasn\'t confirmed their company details and '
                'OJT Start Date yet, so no weekly slots exist.',
          ),
        ],
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryMaroon,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _SummaryCard(summary: summary),
          const SizedBox(height: 16),
          for (final week in _orderedWeeks) ...[
            _WeekCard(
              week: week,
              busy: _busyWeek == week.weekNumber,
              onApprove: _busyWeek == null ? () => _confirmApprove(week) : null,
              onReturn: _busyWeek == null ? () => _askReturn(week) : null,
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final WeeklySummary summary;

  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final ratio = summary.requiredHours > 0
        ? (summary.completedHours / summary.requiredHours).clamp(0.0, 1.0)
        : 0.0;
    Widget stat(String value, String label, Color color) => Expanded(
          child: Column(
            children: [
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Credited Hours',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
              if (summary.isComplete)
                const StatusBadge(kind: StatusKind.completed, labelOverride: 'Hours Complete'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${formatHours(summary.completedHours)} / ${formatHours(summary.requiredHours)} hrs',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryMaroon,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: AppColors.background,
              valueColor: const AlwaysStoppedAnimation(AppColors.primaryMaroon),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              stat('${summary.pendingReviewWeeks}', 'To Review', AppColors.statOrangeIcon),
              stat('${summary.approvedWeeks}', 'Approved', AppColors.successGreenText),
              stat('${summary.rejectedWeeks}', 'Returned', AppColors.statRedIcon),
              stat('${summary.missingWeeks}', 'Not Submitted', AppColors.textSecondary),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  final WeeklySubmission week;
  final bool busy;
  final VoidCallback? onApprove;
  final VoidCallback? onReturn;

  const _WeekCard({
    required this.week,
    required this.busy,
    required this.onApprove,
    required this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    final waiting = week.status == WeeklySubmissionStatus.submitted;
    final hasSubmission = week.status != WeeklySubmissionStatus.missing;
    final dateFormat = DateFormat('MMM d, yyyy h:mm a');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: waiting ? Border.all(color: AppColors.statOrangeIcon, width: 1.2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Week ${week.weekNumber}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ),
              StatusBadge(
                kind: weeklyStatusKind(week.status),
                labelOverride: weeklyStatusLabel(week.status),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            weekDateRange(week),
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          if (hasSubmission) ...[
            const SizedBox(height: 10),
            Text(
              '${formatHours(week.claimedHours ?? 0)} hrs claimed',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            _FileGroup(label: 'DTR', files: week.dtrFiles),
            _FileGroup(label: 'AR', files: week.arFiles),
            if ((week.description ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Student notes: ${week.description}',
                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
              ),
            ],
            if (week.status == WeeklySubmissionStatus.rejected && (week.remarks ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Your remarks: ${week.remarks}',
                style: const TextStyle(fontSize: 12, color: AppColors.statRedIcon),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              [
                if (week.submittedAt != null) 'Submitted ${dateFormat.format(week.submittedAt!)}',
                if (week.reviewedAt != null && !waiting) 'Reviewed ${dateFormat.format(week.reviewedAt!)}',
              ].join('  ·  '),
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
          if (waiting) ...[
            const SizedBox(height: 12),
            if (busy)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReturn,
                      icon: const Icon(Icons.assignment_return_outlined, size: 18),
                      label: const Text('Return'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.statRedIcon,
                        side: const BorderSide(color: AppColors.statRedIcon),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.successGreenText,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _FileGroup extends StatelessWidget {
  final String label;
  final List<WeeklyFile> files;

  const _FileGroup({required this.label, required this.files});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          Expanded(
            child: files.isEmpty
                ? const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'No file',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  )
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final f in files) _FileChip(file: f)],
                  ),
          ),
        ],
      ),
    );
  }
}

class _FileChip extends StatelessWidget {
  final WeeklyFile file;

  const _FileChip({required this.file});

  @override
  Widget build(BuildContext context) {
    final url = file.url;
    return ActionChip(
      avatar: Icon(
        attachmentIconOf(attachmentKindOf(file.fileName)),
        size: 16,
        color: AppColors.primaryMaroon,
      ),
      label: Text(
        file.fileName,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11),
      ),
      tooltip: 'Open ${file.fileName}',
      onPressed: url == null
          ? null
          : () async {
              final opened = await openAttachment(ApiClient.resolveUrl(url));
              if (!opened && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not open this file.')),
                );
              }
            },
    );
  }
}

/// Asks for the remarks the student will see; returns them, or null if
/// cancelled.
class _ReturnDialog extends StatefulWidget {
  final int weekNumber;

  const _ReturnDialog({required this.weekNumber});

  @override
  State<_ReturnDialog> createState() => _ReturnDialogState();
}

class _ReturnDialogState extends State<_ReturnDialog> {
  final _controller = TextEditingController();
  bool _showError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Return Week ${widget.weekNumber}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The student will see your remarks and can fix and resubmit. '
            'No hours are credited for this week until you approve it.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Remarks for the student',
              helperText: 'e.g. DTR is missing your supervisor\'s signature.',
              helperMaxLines: 2,
              errorText: _showError ? 'Remarks are required' : null,
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.statRedIcon,
            foregroundColor: Colors.white,
          ),
          child: const Text('Return to Student'),
        ),
      ],
    );
  }
}
