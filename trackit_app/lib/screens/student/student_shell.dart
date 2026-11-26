import 'package:flutter/material.dart';
import '../../models/notification.dart';
import '../../models/ojt_progress.dart';
import '../../models/student.dart';
import '../../models/student_profile.dart';
import '../../services/api_client.dart';
import '../../services/notifications_service.dart';
import '../../services/progress_service.dart';
import '../../services/student_announcements_service.dart';
import '../../services/weekly_submissions_service.dart';
import '../../widgets/common/app_bottom_nav.dart';
import '../../widgets/student/student_ui.dart';
import '../../services/student_profile_service.dart';
import '../../widgets/student/set_new_password_dialog.dart';
import 'documents/documents_tab_navigator.dart';
import 'notifications_screen.dart';
import 'profile/profile_tab_navigator.dart';
import 'student_announcements_screen.dart';
import 'student_home_view.dart';

/// Student app frame (TrackIT student mockup): three tabs -- Document,
/// Home, Profile -- with Home in the middle. Weekly DTR & AR now lives
/// under Documents, and Notifications open from the bell in every header.
class StudentShell extends StatefulWidget {
  final ApiClient client;
  final Student student;
  final OjtProgress initialProgress;
  final VoidCallback onLoggedOut;

  const StudentShell({
    super.key,
    required this.client,
    required this.student,
    required this.initialProgress,
    required this.onLoggedOut,
  });

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  static const int _documentsTab = 0;
  static const int _homeTab = 1;
  static const int _profileTab = 2;

  int _navIndex = _homeTab;
  // Mutable so Edit Profile's changes (name, avatar) show up immediately
  // across the shell instead of only after the next full login.
  late Student _student = widget.student;
  // Mutable so Home's hours reflect newly approved weeks without a
  // re-login (refreshed whenever Home is opened or a week is submitted).
  late OjtProgress _progress = widget.initialProgress;
  late final ProgressService _progressService = HttpProgressService(widget.client);
  late final WeeklySubmissionsService _weeklyService =
      HttpWeeklySubmissionsService(widget.client);
  late final NotificationsService _notificationsService =
      HttpNotificationsService(widget.client);
  late final StudentAnnouncementsService _announcementsService =
      HttpStudentAnnouncementsService(widget.client);
  final GlobalKey<DocumentsTabNavigatorState> _documentsKey = GlobalKey();

  // Bumped whenever Weekly Submissions opens so it re-fetches -- an
  // instructor may have reviewed a week since it was last shown.
  final ValueNotifier<int> _weeklyReload = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    // Loaded here so Home's preview and the bell badge have data.
    _notificationsService.load();
    _checkPasswordReset();
  }

  /// After an instructor reset, the student must set their own password
  /// before using the app (System Revision 4).
  Future<void> _checkPasswordReset() async {
    try {
      final response = await widget.client.get('/api/profile');
      final profile = response['profile'] as Map<String, dynamic>? ?? const {};
      if (profile['mustChangePassword'] != true || !mounted) return;
      final service = HttpStudentProfileService(widget.client);
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => SetNewPasswordDialog(
          save: service.changePassword,
          onLogout: () {
            Navigator.of(dialogContext).pop(false);
            widget.onLoggedOut();
          },
        ),
      );
    } catch (_) {
      // If the check fails the server still refuses to keep the temporary
      // password forever: it stays flagged until changed.
    }
  }

  @override
  void dispose() {
    _weeklyReload.dispose();
    super.dispose();
  }

  Future<void> _refreshProgress() async {
    try {
      final progress = await _progressService.getProgress();
      if (mounted) setState(() => _progress = progress);
    } catch (_) {
      // Keep showing the last known numbers; pull-to-refresh can retry.
    }
  }

  void _selectTab(int index) {
    setState(() => _navIndex = index);
    if (index == _homeTab) _refreshProgress();
  }

  void _openWeekly() {
    _selectTab(_documentsTab);
    _documentsKey.currentState?.openWeekly();
  }

  void _goToTab(NotificationTarget target) {
    switch (target) {
      case NotificationTarget.home:
        _selectTab(_homeTab);
      case NotificationTarget.weekly:
        _openWeekly();
      case NotificationTarget.documents:
        _selectTab(_documentsTab);
      case NotificationTarget.profile:
        _selectTab(_profileTab);
    }
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          body: StudentBackdrop(
            child: NotificationsScreen(
              service: _notificationsService,
              onNavigateTo: (target) {
                Navigator.of(context).pop();
                _goToTab(target);
              },
            ),
          ),
        ),
      ),
    );
  }

  void _updateStudentFromProfile(StudentProfile profile) {
    setState(() => _student = Student.fromProfile(profile));
  }

  void _openAnnouncements() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StudentAnnouncementsScreen(service: _announcementsService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DocumentsTabNavigator(
        key: _documentsKey,
        student: _student,
        client: widget.client,
        weeklyService: _weeklyService,
        weeklyReload: _weeklyReload,
        onWeekSubmitted: _refreshProgress,
      ),
      StudentBackdrop(
        child: StudentHomeView(
          student: _student,
          progress: _progress,
          onRefresh: _refreshProgress,
          onOpenWeekly: _openWeekly,
          announcementsService: _announcementsService,
          onOpenAnnouncements: _openAnnouncements,
          notificationsService: _notificationsService,
          onOpenNotifications: _openNotifications,
        ),
      ),
      ProfileTabNavigator(
        client: widget.client,
        onLoggedOut: widget.onLoggedOut,
        onProfileUpdated: _updateStudentFromProfile,
      ),
    ];

    return StudentChrome(
      onOpenNotifications: _openNotifications,
      unreadListenable: _notificationsService,
      unreadCount: () => _notificationsService.unreadCount,
      child: Scaffold(
        backgroundColor: StudentColors.page,
        body: IndexedStack(index: _navIndex, children: pages),
        bottomNavigationBar: AppBottomNav(
          items: const [
            AppBottomNavItem(icon: Icons.description_outlined, label: 'Document'),
            AppBottomNavItem(icon: Icons.home_outlined, label: 'Home'),
            AppBottomNavItem(icon: Icons.person_outline, label: 'Profile'),
          ],
          currentIndex: _navIndex,
          onTap: _selectTab,
        ),
      ),
    );
  }
}
