import 'package:flutter/material.dart';
import '../../models/ojt_progress.dart';
import '../../models/weekly_submission.dart';
import '../../utils/app_colors.dart';
import '../common/ojt_progress_status_badge.dart';
import 'ojt_stat_tile.dart';

/// Home's hours summary. Credited hours come only from weekly DTRs the
/// instructor approved; hours still under review are shown separately.
class OjtProgressCard extends StatelessWidget {
  final OjtProgress progress;
  final VoidCallback onOpenWeekly;

  const OjtProgressCard({super.key, required this.progress, required this.onOpenWeekly});

  @override
  Widget build(BuildContext context) {
    final weeksLeft = progress.estimatedWeeksLeft;
    final completed = progress.status == OjtProgressStatus.completed;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'OJT Hours Progress',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          if (completed)
            _CompletedBanner(totalHours: progress.completedHours)
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Credited (approved)',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: formatHours(progress.completedHours),
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryMaroon,
                              ),
                            ),
                            TextSpan(
                              text: ' / ${formatHours(progress.totalHours)} Hours',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                OjtProgressStatusBadge(status: progress.status),
              ],
            ),
          const SizedBox(height: 14),
          _ProgressBar(ratio: progress.progressRatio),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OjtStatTile(
                  icon: Icons.task_alt,
                  iconColor: AppColors.successGreenText,
                  backgroundColor: AppColors.successGreenBg,
                  value: '${progress.approvedWeeks} '
                      'Week${progress.approvedWeeks == 1 ? '' : 's'}',
                  label: 'Approved Weeks',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OjtStatTile(
                  icon: Icons.hourglass_bottom,
                  iconColor: AppColors.statOrangeIcon,
                  backgroundColor: AppColors.statOrangeBg,
                  value: '${formatHours(progress.pendingHours)} Hours',
                  label: 'For Approval',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OjtStatTile(
                  icon: Icons.bar_chart,
                  iconColor: AppColors.statBlueIcon,
                  backgroundColor: AppColors.statBlueBg,
                  value: '${formatHours(progress.weeklyAverageHours)} Hours',
                  label: 'Weekly Average',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OjtStatTile(
                  icon: Icons.calendar_today,
                  iconColor: AppColors.statPurpleIcon,
                  backgroundColor: AppColors.statPurpleBg,
                  value: completed
                      ? 'Done'
                      : weeksLeft == null
                          ? '--'
                          : '~$weeksLeft Week${weeksLeft == 1 ? '' : 's'}',
                  label: 'Est. Time Left',
                ),
              ),
            ],
          ),
          if (!completed) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onOpenWeekly,
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Submit Weekly DTR & AR'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryMaroon,
                  side: const BorderSide(color: AppColors.primaryMaroon),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompletedBanner extends StatelessWidget {
  final double totalHours;

  const _CompletedBanner({required this.totalHours});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.successGreenBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.successGreenText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Completed: ${formatHours(totalHours)} credited hours',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.successGreenText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double ratio;

  const _ProgressBar({required this.ratio});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 20,
            backgroundColor: AppColors.background,
            valueColor: const AlwaysStoppedAnimation(AppColors.primaryMaroon),
          ),
        ),
        Text(
          '${(ratio * 100).round()}%',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: ratio > 0.08 ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
