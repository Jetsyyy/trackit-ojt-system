import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/weekly_submission.dart';
import '../../../utils/app_colors.dart';
import '../../common/status_badge.dart';

String weeklyStatusLabel(WeeklySubmissionStatus status) {
  switch (status) {
    case WeeklySubmissionStatus.missing:
      return 'Not Submitted';
    case WeeklySubmissionStatus.submitted:
      return 'Waiting for Review';
    case WeeklySubmissionStatus.approved:
      return 'Approved';
    case WeeklySubmissionStatus.rejected:
      return 'Returned';
  }
}

StatusKind weeklyStatusKind(WeeklySubmissionStatus status) {
  switch (status) {
    case WeeklySubmissionStatus.missing:
      return StatusKind.missing;
    case WeeklySubmissionStatus.submitted:
      return StatusKind.pending;
    case WeeklySubmissionStatus.approved:
      return StatusKind.approved;
    case WeeklySubmissionStatus.rejected:
      return StatusKind.rejected;
  }
}

String weekDateRange(WeeklySubmission week) =>
    '${DateFormat('MMM d').format(week.weekStartDate)} - '
    '${DateFormat('MMM d, yyyy').format(week.weekEndDate)}';

class WeeklySubmissionTile extends StatelessWidget {
  final WeeklySubmission week;
  final VoidCallback onTap;

  const WeeklySubmissionTile({super.key, required this.week, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hours = week.claimedHours;
    final String detail;
    switch (week.status) {
      case WeeklySubmissionStatus.missing:
        detail = 'Tap to upload your DTR and AR';
        break;
      case WeeklySubmissionStatus.submitted:
        detail = '${formatHours(hours ?? 0)} hrs claimed, not yet credited';
        break;
      case WeeklySubmissionStatus.approved:
        detail = '${formatHours(hours ?? 0)} hrs credited';
        break;
      case WeeklySubmissionStatus.rejected:
        detail = 'Fix and resubmit';
        break;
    }

    return Material(
      color: AppColors.cardWhite,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Week ${week.weekNumber}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  StatusBadge(
                    kind: weeklyStatusKind(week.status),
                    labelOverride: weeklyStatusLabel(week.status),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                weekDateRange(week),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    week.canSubmit ? Icons.upload_file : Icons.schedule,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      detail,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
              if (week.status == WeeklySubmissionStatus.rejected &&
                  (week.remarks ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Instructor: ${week.remarks}',
                  style: const TextStyle(color: AppColors.statRedIcon, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
