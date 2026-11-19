import 'package:flutter/material.dart';
import '../../../models/teacher_dashboard.dart';
import '../../../services/teacher_notifications_service.dart';
import '../../../widgets/common/desk_ui.dart';
import '../../../widgets/student/student_ui.dart';

/// Desktop Home Dashboard (instructor mockup): greeting, Assigned
/// Programs & Sections, Today's Summary, Recent Notifications and Needs
/// Your Attention.
class TeacherDashboardDesk extends StatelessWidget {
  final TeacherDashboard dashboard;
  final TeacherNotificationsService notificationsService;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenStudents;
  final VoidCallback onOpenRequirementsReview;
  final VoidCallback onOpenWeeklyReview;
  final VoidCallback onOpenRegistrationRequests;
  final Future<void> Function() onRefresh;

  /// Phone layout (instructor mobile mockup): the maroon Home header, the
  /// greeting, then the same cards stacked in one column.
  final bool compact;

  const TeacherDashboardDesk({
    super.key,
    required this.dashboard,
    required this.notificationsService,
    required this.onOpenNotifications,
    required this.onOpenStudents,
    required this.onOpenRequirementsReview,
    required this.onOpenWeeklyReview,
    required this.onOpenRegistrationRequests,
    required this.onRefresh,
    this.compact = false,
  });

  Widget _compact(BuildContext context) {
    final name = dashboard.instructorName.trim();
    return StudentBackdrop(
      child: Column(
        children: [
          const StudentHeader(title: 'Home', subtitle: 'Personal Dashboard'),
          Expanded(
            child: RefreshIndicator(
              color: DeskColors.maroon,
              onRefresh: onRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                children: [
                  Text.rich(
                    TextSpan(
                      style: studentSerif(size: 24),
                      children: [
                        TextSpan(text: '${phGreeting()}${name.isEmpty ? '!' : ','}'),
                        if (name.isNotEmpty)
                          TextSpan(text: ' $name!', style: studentSerif(size: 24, color: StudentColors.heading)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionsCard(classes: dashboard.classes, onOpen: onOpenStudents, compact: true),
                  const SizedBox(height: 14),
                  _SummaryCard(dashboard: dashboard, onOpenStudents: onOpenStudents, compact: true),
                  const SizedBox(height: 14),
                  _AttentionCard(
                    dashboard: dashboard,
                    onRequirements: onOpenRequirementsReview,
                    onWeekly: onOpenWeeklyReview,
                    onRegistrations: onOpenRegistrationRequests,
                  ),
                  const SizedBox(height: 14),
                  _NotificationsCard(service: notificationsService, onViewAll: onOpenNotifications),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (compact) return _compact(context);
    final name = dashboard.instructorName.trim();
    return DeskPage(
      title: '${phGreeting()}${name.isEmpty ? '' : ', $name'}!',
      onRefresh: onRefresh,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 4, child: _SectionsCard(classes: dashboard.classes, onOpen: onOpenStudents)),
              const SizedBox(width: 16),
              Expanded(flex: 6, child: _SummaryCard(dashboard: dashboard, onOpenStudents: onOpenStudents)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 4,
                child: _NotificationsCard(
                  service: notificationsService,
                  onViewAll: onOpenNotifications,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 6,
                child: _AttentionCard(
                  dashboard: dashboard,
                  onRequirements: onOpenRequirementsReview,
                  onWeekly: onOpenWeeklyReview,
                  onRegistrations: onOpenRegistrationRequests,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionsCard extends StatelessWidget {
  final List<TeacherDashboardClass> classes;
  final VoidCallback onOpen;
  final bool compact;

  const _SectionsCard({required this.classes, required this.onOpen, this.compact = false});

  Widget _gridTile(TeacherDashboardClass c) => DeskTile(
        onTap: onOpen,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              c.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F)),
            ),
            const SizedBox(height: 3),
            Text(
              '${c.studentCount} student${c.studentCount == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 11.5, color: DeskColors.muted),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return DeskCard(
      title: 'Assigned Programs & Sections',
      child: classes.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No sections assigned yet. The Admin assigns your sections.',
                style: TextStyle(fontSize: 12.5, color: DeskColors.muted),
              ),
            )
          : compact
              ? LayoutBuilder(
                  builder: (context, box) {
                    final w = (box.maxWidth - 10) / 2;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [for (final c in classes) SizedBox(width: w, child: _gridTile(c))],
                    );
                  },
                )
              : Column(
              children: [
                for (final c in classes) ...[
                  DeskTile(
                    onTap: onOpen,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.label,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1F1F1F),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${c.studentCount} student${c.studentCount == 1 ? '' : 's'}',
                                style: const TextStyle(fontSize: 12, color: DeskColors.muted),
                              ),
                            ],
                          ),
                        ),
                        if (c.academicYear != null)
                          Text(
                            c.academicYear!,
                            style: const TextStyle(fontSize: 11, color: DeskColors.muted),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final TeacherDashboard dashboard;
  final VoidCallback onOpenStudents;

  final bool compact;

  const _SummaryCard({required this.dashboard, required this.onOpenStudents, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final total = dashboard.assignedStudents;
    final tiles = [
      (Icons.groups_outlined, 'Assigned Students', '$total'),
      (Icons.directions_run, 'Active Students', '${dashboard.activeStudents} / $total'),
      (Icons.flight_takeoff, 'Ready for Deployment', '${dashboard.readyForDeployment} / $total'),
      (Icons.verified_outlined, 'Completed OJT', '${dashboard.completedStudents} / $total'),
    ];
    return DeskCard(
      title: "Today's Summary",
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 30, vertical: compact ? 0 : 6),
        child: Column(
          children: [
            for (var row = 0; row < 2; row++) ...[
              IntrinsicHeight(
                child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var col = 0; col < 2; col++) ...[
                    if (col == 1) SizedBox(width: compact ? 10 : 30),
                    Expanded(
                      child: _SummaryTile(
                        icon: tiles[row * 2 + col].$1,
                        label: tiles[row * 2 + col].$2,
                        value: tiles[row * 2 + col].$3,
                        onTap: onOpenStudents,
                        compact: compact,
                      ),
                    ),
                  ],
                ],
              ),
              ),
              if (row == 0) SizedBox(height: compact ? 10 : 22),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool compact;

  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return DeskTile(
      raised: true,
      onTap: onTap,
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 16, vertical: compact ? 12 : 16),
      child: Row(
        children: [
          DeskIconBox(icon: icon, size: compact ? 28 : 32),
          SizedBox(width: compact ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: DeskColors.heading),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: compact ? 11 : 12.5, fontWeight: FontWeight.w500, color: const Color(0xFF2B2B2B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsCard extends StatelessWidget {
  final TeacherNotificationsService service;
  final VoidCallback onViewAll;

  const _NotificationsCard({required this.service, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return DeskCard(
      title: 'Recent Notifications',
      titleIcon: Icons.notifications_none,
      trailing: InkWell(
        onTap: onViewAll,
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Text(
            'View All',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: DeskColors.heading),
          ),
        ),
      ),
      child: ListenableBuilder(
        listenable: service,
        builder: (context, _) {
          final items = service.notifications.take(4).toList();
          if (items.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No notifications yet.',
                style: TextStyle(fontSize: 12.5, color: DeskColors.muted),
              ),
            );
          }
          return Column(
            children: [
              for (final n in items) ...[
                DeskTile(
                  onTap: () {
                    service.markAsRead(n.id);
                    onViewAll();
                  },
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDEAFB),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.shield_outlined, size: 12, color: Color(0xFF5B4FCF)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700,
                                color: const Color(0xFF1F1F1F),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              timeAgo(n.createdAt),
                              style: const TextStyle(fontSize: 11, color: DeskColors.muted),
                            ),
                          ],
                        ),
                      ),
                      if (!n.isRead)
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(top: 5, left: 6),
                          decoration: const BoxDecoration(color: Color(0xFFFF7A1A), shape: BoxShape.circle),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AttentionCard extends StatelessWidget {
  final TeacherDashboard dashboard;
  final VoidCallback onRequirements;
  final VoidCallback onWeekly;
  final VoidCallback onRegistrations;

  const _AttentionCard({
    required this.dashboard,
    required this.onRequirements,
    required this.onWeekly,
    required this.onRegistrations,
  });

  String _plural(int n, String one, String many) => '$n ${n == 1 ? one : many}';

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.description_outlined,
        'Requirements Approval',
        '${_plural(dashboard.requirementsToReview, 'requirement', 'requirements')} waiting for your review',
        dashboard.requirementsToReview,
        onRequirements,
      ),
      (
        Icons.event_note_outlined,
        'Weekly DTR & AR Approval',
        '${_plural(dashboard.weeklySubmissionsToReview, 'week', 'weeks')} pending your approval',
        dashboard.weeklySubmissionsToReview,
        onWeekly,
      ),
      (
        Icons.how_to_reg_outlined,
        'Account Approval',
        '${_plural(dashboard.registrationRequests, 'student', 'students')} waiting to join your sections',
        dashboard.registrationRequests,
        onRegistrations,
      ),
    ];
    return DeskCard(
      title: 'Needs Your Attention',
      titleIcon: Icons.warning_amber_rounded,
      child: Column(
        children: [
          for (final item in items) ...[
            DeskTile(
              onTap: item.$5,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  DeskIconBox(icon: item.$1, size: 34),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$2,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F)),
                        ),
                        const SizedBox(height: 2),
                        Text(item.$3, style: const TextStyle(fontSize: 11.5, color: DeskColors.muted)),
                      ],
                    ),
                  ),
                  if (item.$4 > 0) DeskCountBadge(count: item.$4),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
