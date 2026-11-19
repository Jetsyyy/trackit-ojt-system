import 'package:flutter/material.dart';
import '../../models/teacher_dashboard.dart';
import '../../services/teacher_announcements_service.dart';
import '../../services/teacher_notifications_service.dart';
import '../../widgets/common/desk_ui.dart';
import 'desk/teacher_dashboard_desk.dart';

class TeacherHomeDashboardScreen extends StatefulWidget {
  final TeacherDashboard dashboard;
  final TeacherNotificationsService notificationsService;
  final TeacherAnnouncementsService announcementsService;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenDocumentsHub;
  final VoidCallback onOpenRequirementsReview;
  final VoidCallback onOpenWeeklyReview;
  final VoidCallback onOpenRegistrationRequests;
  final VoidCallback? onOpenStudents;
  final Future<void> Function() onRefresh;

  const TeacherHomeDashboardScreen({
    super.key,
    required this.dashboard,
    required this.notificationsService,
    required this.announcementsService,
    required this.onOpenNotifications,
    required this.onOpenDocumentsHub,
    required this.onOpenRequirementsReview,
    required this.onOpenWeeklyReview,
    required this.onOpenRegistrationRequests,
    this.onOpenStudents,
    required this.onRefresh,
  });

  @override
  State<TeacherHomeDashboardScreen> createState() =>
      _TeacherHomeDashboardScreenState();
}

class _TeacherHomeDashboardScreenState
    extends State<TeacherHomeDashboardScreen> {
  Future<void> _refresh() => widget.onRefresh();

  @override
  Widget build(BuildContext context) {
    final dashboard = widget.dashboard;
    // Desktop and phone both use the mockup layout; phones stack it.
    return TeacherDashboardDesk(
      compact: !isDeskLayout(context),
      dashboard: dashboard,
      notificationsService: widget.notificationsService,
      onOpenNotifications: widget.onOpenNotifications,
      onOpenStudents: widget.onOpenStudents ?? widget.onOpenRegistrationRequests,
      onOpenRequirementsReview: widget.onOpenRequirementsReview,
      onOpenWeeklyReview: widget.onOpenWeeklyReview,
      onOpenRegistrationRequests: widget.onOpenRegistrationRequests,
      onRefresh: _refresh,
    );
  }
}