import 'package:flutter/material.dart';
import '../../models/teacher_dashboard.dart';
import '../../services/api_client.dart';
import '../../services/teacher_announcements_service.dart';
import '../../services/teacher_classes_service.dart';
import '../../services/teacher_dashboard_service.dart';
import '../../services/teacher_notifications_service.dart';
import '../../services/teacher_students_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/common/app_bottom_nav.dart';
import '../../widgets/common/desk_ui.dart';
import 'teacher_documents_tab_navigator.dart';
import 'teacher_home_dashboard_screen.dart';
import 'teacher_notifications_tab_navigator.dart';
import 'teacher_profile_tab_navigator.dart';
import 'teacher_students_tab_navigator.dart';

class TeacherShell extends StatefulWidget {
  final ApiClient client;
  final TeacherDashboardService dashboardService;
  final TeacherDashboard initialDashboard;
  final VoidCallback onLoggedOut;

  const TeacherShell({
    super.key,
    required this.client,
    required this.dashboardService,
    required this.initialDashboard,
    required this.onLoggedOut,
  });

  @override
  State<TeacherShell> createState() => _TeacherShellState();
}

class _TeacherShellState extends State<TeacherShell> {
  int _navIndex = 0;
  late TeacherDashboard _dashboard;
  // Owned here (not inside TeacherDocumentsTabNavigator) so Home
  // Dashboard's "Needs your Attention" taps can deep-link straight into a
  // Document tab screen instead of just switching to its root.
  final GlobalKey<NavigatorState> _documentsNavigatorKey = GlobalKey<NavigatorState>();
  late final TeacherClassesService _classesService = HttpTeacherClassesService(
    widget.client,
  );
  late final TeacherStudentsService _studentsService = HttpTeacherStudentsService(
    widget.client,
  );
  late final TeacherNotificationsService _notificationsService =
      HttpTeacherNotificationsService(widget.client);
  late final TeacherAnnouncementsService _announcementsService =
      HttpTeacherAnnouncementsService(widget.client);

  @override
  void initState() {
    super.initState();
    _dashboard = widget.initialDashboard;
    // Loaded once here (rather than only inside the Notification tab) so
    // the Home Dashboard's preview and the bottom-nav badge have data
    // even if that tab is never opened directly.
    _notificationsService.load();
  }

  Future<void> _refreshDashboard() async {
    final dashboard = await widget.dashboardService.getDashboard();
    if (!mounted) return;
    setState(() => _dashboard = dashboard);
  }

  // IndexedStack keeps every tab's widget subtree built at all times, so
  // the Documents nested Navigator already exists even while another tab
  // is showing -- no need to wait a frame before pushing onto it.
  // Desktop Documents page picked from the sidebar submenu:
  // (0 = Requirements, 1 = Weekly Submission, reload counter).
  final ValueNotifier<(int, int)> _docsDesk = ValueNotifier((0, 0));

  void _openDocsDesk(int section) {
    setState(() => _navIndex = 2);
    _docsDesk.value = (section, _docsDesk.value.$2 + 1);
  }

  void _openRequirementsReview() {
    if (isDeskLayout(context)) return _openDocsDesk(0);
    setState(() => _navIndex = 2);
    _documentsNavigatorKey.currentState
        ?.pushNamed('/official-requirements', arguments: 'needsReview');
  }

  final GlobalKey<NavigatorState> _studentsNavigatorKey = GlobalKey<NavigatorState>();

  // Bumped whenever the Students tab is shown or Registration Requests
  // closes, so the roster and the requests banner never stay stale (the
  // IndexedStack keeps the tab alive from app start).
  final ValueNotifier<int> _studentsReload = ValueNotifier(0);

  @override
  void dispose() {
    _studentsReload.dispose();
    _docsDesk.dispose();
    super.dispose();
  }

  Future<void> _openRegistrationRequests() async {
    setState(() => _navIndex = 1);
    await _studentsNavigatorKey.currentState?.pushNamed<String>('/requests');
    _studentsReload.value++;
    await _refreshDashboard().catchError((_) {});
  }

  Future<void> _openWeeklyReview() async {
    if (isDeskLayout(context)) return _openDocsDesk(1);
    setState(() => _navIndex = 2);
    await _documentsNavigatorKey.currentState?.pushNamed<String>('/weekly-reports');
    // Approving weeks changes the "to review" count on Home.
    await _refreshDashboard().catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      TeacherHomeDashboardScreen(
        dashboard: _dashboard,
        notificationsService: _notificationsService,
        announcementsService: _announcementsService,
        onOpenNotifications: () => setState(() => _navIndex = 3),
        onOpenDocumentsHub: () => setState(() => _navIndex = 2),
        onOpenRequirementsReview: _openRequirementsReview,
        onOpenWeeklyReview: _openWeeklyReview,
        onOpenRegistrationRequests: _openRegistrationRequests,
        onOpenStudents: () => _selectTab(1),
        onRefresh: _refreshDashboard,
      ),
      TeacherStudentsTabNavigator(
        classesService: _classesService,
        studentsService: _studentsService,
        navigatorKey: _studentsNavigatorKey,
        reloadSignal: _studentsReload,
      ),
      TeacherDocumentsTabNavigator(
        client: widget.client,
        classesService: _classesService,
        navigatorKey: _documentsNavigatorKey,
        deskSection: _docsDesk,
      ),
      TeacherNotificationsTabNavigator(
        notificationsService: _notificationsService,
        announcementsService: _announcementsService,
        classesService: _classesService,
      ),
      TeacherProfileTabNavigator(
        client: widget.client,
        onLoggedOut: widget.onLoggedOut,
      ),
    ];

    final body = IndexedStack(index: _navIndex, children: pages);

    // System Revisions item 12: on a desktop or laptop the bottom nav
    // becomes a left sidebar and the content is centred at a readable
    // width; phones keep the bottom nav.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _desktopBreakpoint) {
          return Scaffold(
            backgroundColor: DeskColors.page,
            body: Row(
              children: [
                ListenableBuilder(
                  listenable: Listenable.merge([_notificationsService, _docsDesk]),
                  builder: (context, _) => _TeacherSidebar(
                    selectedIndex: _navIndex,
                    docsSection: _docsDesk.value.$1,
                    onSelectDocs: _openDocsDesk,
                    unreadCount: _notificationsService.unreadCount,
                    instructorName: _dashboard.instructorName,
                    onSelect: _selectTab,
                    onLogout: _confirmLogout,
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: _desktopContentWidth),
                      child: body,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return Scaffold(
          backgroundColor: AppColors.background,
          body: body,
          bottomNavigationBar: ListenableBuilder(
            listenable: _notificationsService,
            builder: (context, _) {
              final navItems = [
                const AppBottomNavItem(icon: Icons.home, label: 'Home'),
                const AppBottomNavItem(icon: Icons.groups, label: 'Students'),
                const AppBottomNavItem(icon: Icons.description, label: 'Document'),
                AppBottomNavItem(
                  icon: Icons.notifications,
                  label: 'Notification',
                  badgeCount: _notificationsService.unreadCount,
                ),
                const AppBottomNavItem(icon: Icons.person, label: 'Profile'),
              ];
              return AppBottomNav(
                items: navItems,
                currentIndex: _navIndex,
                onTap: _selectTab,
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to use TrackIT.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryMaroon,
              foregroundColor: Colors.white,
            ),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onLoggedOut();
  }

  void _selectTab(int index) {
    setState(() => _navIndex = index);
    // Keep Home's counts current (e.g. after reviewing weeks).
    if (index == 0) _refreshDashboard().catchError((_) {});
    if (index == 1) _studentsReload.value++;
    if (index == 2) _docsDesk.value = (_docsDesk.value.$1, _docsDesk.value.$2 + 1);
  }
}

/// Width at which the instructor app switches to the desktop layout.
const double _desktopBreakpoint = 900;

/// Content column width on desktop -- the screens are designed as
/// single-column lists, so they stay readable instead of stretching
/// across a wide monitor.
const double _desktopContentWidth = 1100;

class _TeacherSidebar extends StatelessWidget {
  final int selectedIndex;
  final int unreadCount;
  final String instructorName;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;
  final int docsSection;
  final ValueChanged<int> onSelectDocs;

  const _TeacherSidebar({
    required this.selectedIndex,
    required this.docsSection,
    required this.onSelectDocs,
    required this.unreadCount,
    required this.instructorName,
    required this.onSelect,
    required this.onLogout,
  });

  static const _items = [
    (Icons.grid_view_outlined, 'Dashboard'),
    (Icons.people_outline, 'Student'),
    (Icons.description_outlined, 'Documents'),
    (Icons.campaign_outlined, 'Notification'),
    (Icons.person_outline, 'Profile'),
  ];

  static const _divider = Divider(height: 1, thickness: 1, color: Color(0x33FFFFFF));

  String get _initials {
    final parts = instructorName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'I';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: const Color(0xFF5C1219),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    'assets/images/trackit_logo_white.png',
                    width: 130,
                    semanticLabel: 'TrackIT',
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 48),
                    child: Text(
                      'OJT TRACKING SYSTEM',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 7.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 18), child: _divider),
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 22, 22, 10),
              child: Text(
                'WORKSPACE',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            for (var i = 0; i < _items.length; i++) ...[
              _item(i),
              // Documents opens into its two pages, like the mockup.
              if (i == 2 && selectedIndex == 2) ...[
                _subItem(Icons.description_outlined, 'Requirements', docsSection == 0, () => onSelectDocs(0)),
                _subItem(Icons.folder_open_outlined, 'Weekly Submission', docsSection == 1, () => onSelectDocs(1)),
              ],
            ],
            const Spacer(),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 18), child: _divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: Colors.white,
                    child: Text(
                      _initials,
                      style: const TextStyle(
                        color: AppColors.primaryMaroon,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      instructorName.isEmpty ? 'Instructor' : instructorName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
              child: OutlinedButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout, size: 17),
                label: const Text('Log out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0x55FFFFFF)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _subItem(IconData icon, String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 1, 18, 1),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 34,
            decoration: BoxDecoration(
              color: selected ? AppColors.accentOrange : Colors.transparent,
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(3)),
            ),
          ),
          const SizedBox(width: 33),
          Expanded(
            child: Material(
              color: selected ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      Icon(icon, size: 17, color: selected ? Colors.white : Colors.white70),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.white70,
                            fontSize: 12.5,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(int i) {
    final selected = selectedIndex == i;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 2, 18, 2),
      child: Row(
        children: [
          // Orange accent bar on the selected item, like the design.
          Container(
            width: 3,
            height: 38,
            decoration: BoxDecoration(
              color: selected ? AppColors.accentOrange : Colors.transparent,
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(3)),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Material(
              color: selected ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onSelect(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Icon(_items[i].$1, size: 20, color: selected ? Colors.white : Colors.white70),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _items[i].$2,
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.white70,
                            fontSize: 13.5,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (i == 2)
                        Icon(
                          selected ? Icons.expand_less : Icons.expand_more,
                          size: 18,
                          color: Colors.white70,
                        ),
                      if (i == 3 && unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accentOrange,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
