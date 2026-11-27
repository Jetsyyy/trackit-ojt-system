import 'package:flutter/material.dart';
import '../../widgets/common/motion.dart';
import '../../models/notification.dart';
import '../../models/ojt_progress.dart';
import '../../models/student.dart';
import '../../services/api_client.dart';
import '../../services/notifications_service.dart';
import '../../services/student_announcements_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/common/desk_ui.dart';
import '../../widgets/student/student_ui.dart';

/// Student Home (TrackIT student mockup): profile card with the company,
/// OJT Hours Progress with credited weeks and the current week, then the
/// latest announcements / notifications.
class StudentHomeView extends StatelessWidget {
  final Student student;
  final OjtProgress progress;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenWeekly;
  final StudentAnnouncementsService announcementsService;
  final VoidCallback onOpenAnnouncements;
  final NotificationsService notificationsService;
  final VoidCallback onOpenNotifications;

  const StudentHomeView({
    super.key,
    required this.student,
    required this.progress,
    required this.onRefresh,
    required this.onOpenWeekly,
    required this.announcementsService,
    required this.onOpenAnnouncements,
    required this.notificationsService,
    required this.onOpenNotifications,
  });

  /// Week number of the OJT today (week 1 starts on the OJT start date).
  int? get _currentWeek {
    final start = student.ojtStartDate;
    if (start == null) return null;
    final today = DateTime.now().toUtc().add(const Duration(hours: 8));
    final days = DateTime.utc(today.year, today.month, today.day)
        .difference(DateTime.utc(start.year, start.month, start.day))
        .inDays;
    if (days < 0) return null;
    return days ~/ 7 + 1;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primaryMaroon,
      onRefresh: () async {
        await Future.wait([onRefresh(), notificationsService.load()]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          const StudentHeader(title: 'Home', subtitle: 'Personal Dashboard'),
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 22, 26, 24),
            child: StaggeredColumn(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProfileCard(student: student),
                const SizedBox(height: 20),
                _HoursCard(progress: progress, currentWeek: _currentWeek, onTap: onOpenWeekly),
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Icon(Icons.campaign_outlined, color: StudentColors.maroon, size: 26),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Latest Announcement / Notifications',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F1F1F)),
                      ),
                    ),
                    InkWell(
                      onTap: onOpenNotifications,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Text(
                          'See All',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: StudentColors.maroon),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ListenableBuilder(
                  listenable: notificationsService,
                  builder: (context, _) {
                    final items = notificationsService.notifications.take(3).toList();
                    if (items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No announcements or notifications yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, color: StudentColors.muted),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final n in items) ...[
                          _NoticeTile(
                            notification: n,
                            onTap: () {
                              notificationsService.markAsRead(n.id);
                              onOpenNotifications();
                            },
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final Student student;

  const _ProfileCard({required this.student});

  @override
  Widget build(BuildContext context) {
    return StudentCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DeskAvatar(
                name: student.name,
                imageUrl: student.avatarUrl == null ? null : ApiClient.resolveUrl(student.avatarUrl!),
                radius: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: studentSerif(size: 24),
                    ),
                    Text(
                      '${student.course} - ${student.section}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentOrange,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.accentOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: StudentColors.chip,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 2))],
            ),
            child: Text(
              student.hasCompany ? student.companyName : 'Not yet deployed',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
                color: student.hasCompany ? const Color(0xFF333333) : StudentColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HoursCard extends StatelessWidget {
  final OjtProgress progress;
  final int? currentWeek;
  final VoidCallback onTap;

  const _HoursCard({required this.progress, required this.currentWeek, required this.onTap});

  static String _num(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final total = progress.totalHours;
    final ratio = total <= 0 ? 0.0 : (progress.completedHours / total).clamp(0.0, 1.0);
    final weeks = progress.approvedWeeks;
    return StudentCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'OJT Hours Progress',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F)),
          ),
          const SizedBox(height: 18),
          const Text('Completed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: StudentColors.muted)),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: _num(progress.completedHours),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: StudentColors.heading),
                ),
                TextSpan(
                  text: ' / ${_num(total)} ',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: Color(0xFF1F1F1F)),
                ),
                const TextSpan(text: 'Hours', style: TextStyle(fontSize: 12, color: Color(0xFF1F1F1F))),
              ],
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Container(
                  height: 14,
                  decoration: BoxDecoration(color: const Color(0xFFC4C4C4), borderRadius: BorderRadius.circular(8)),
                ),
                Container(
                  height: 14,
                  width: constraints.maxWidth * ratio,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(color: StudentColors.maroon, borderRadius: BorderRadius.circular(8)),
                  child: ratio >= 0.12
                      ? Text(
                          '${(ratio * 100).round()}%',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                        )
                      : null,
                ),
                if (ratio < 0.12)
                  Positioned(
                    left: constraints.maxWidth * ratio + 6,
                    top: 1,
                    child: Text(
                      '${(ratio * 100).round()}%',
                      style: const TextStyle(color: Color(0xFF333333), fontSize: 9, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.event_available,
                  color: const Color(0xFF1E9E45),
                  value: '$weeks Week${weeks == 1 ? '' : 's'}',
                  label: 'Credited Weeks',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  icon: Icons.calendar_month,
                  color: const Color(0xFF7B4FCF),
                  value: currentWeek == null ? 'Not started' : 'Week $currentWeek',
                  label: 'Current Week',
                ),
              ),
            ],
          ),
          if (progress.pendingHours > 0) ...[
            const SizedBox(height: 8),
            Text(
              '${_num(progress.pendingHours)} hours waiting for your instructor\'s approval',
              style: const TextStyle(fontSize: 11, color: StudentColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _StatTile({required this.icon, required this.color, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: StudentColors.chip,
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: StudentColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NoticeTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final n = notification;
    return StudentCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DeskIconBox(icon: Icons.campaign_outlined, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.title,
                  style: TextStyle(fontSize: 13, fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  n.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF555555)),
                ),
                const SizedBox(height: 4),
                Text(timeAgo(n.createdAt), style: const TextStyle(fontSize: 10.5, color: StudentColors.muted)),
              ],
            ),
          ),
          if (!n.isRead)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 4, left: 6),
              decoration: const BoxDecoration(color: AppColors.accentOrange, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }
}
