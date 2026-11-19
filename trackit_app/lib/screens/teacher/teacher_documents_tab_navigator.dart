import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/teacher_classes_service.dart';
import '../../services/teacher_requirements_service.dart';
import '../../services/teacher_weekly_reports_service.dart';
import '../../widgets/common/desk_ui.dart';
import 'desk/teacher_documents_desk.dart';
import 'teacher_documents_hub_screen.dart';
import 'teacher_official_requirements_screen.dart';
import 'teacher_requirement_review_screen.dart';
import 'teacher_weekly_report_detail_screen.dart';
import 'teacher_weekly_reports_screen.dart';

/// Owns a nested Navigator for the Document (OJT Management) tab, the
/// same pattern as the Students and Notification tabs, so pushing into
/// any of these screens keeps TeacherShell's bottom nav visible.
///
/// Instructors review submissions here; the Official Requirements list and
/// its template files are managed by the Admin, and instructors can no
/// longer post additional requirements (System Revisions item 15).
class TeacherDocumentsTabNavigator extends StatefulWidget {
  final ApiClient client;
  final TeacherClassesService classesService;

  /// Owned by TeacherShell so Home Dashboard's "Needs your Attention" taps
  /// can deep-link straight into a screen here (e.g. Official Requirements
  /// filtered to Needs Review, or Weekly DTR & AR Review) instead of just
  /// switching tabs to this navigator's root.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Desktop only: which page the sidebar's Documents submenu picked
  /// (0 = Requirements, 1 = Weekly Submission) and a counter bumped each
  /// time it's opened, so the page reloads instead of showing stale data.
  final ValueListenable<(int, int)>? deskSection;

  const TeacherDocumentsTabNavigator({
    super.key,
    required this.client,
    required this.classesService,
    this.navigatorKey,
    this.deskSection,
  });

  @override
  State<TeacherDocumentsTabNavigator> createState() =>
      _TeacherDocumentsTabNavigatorState();
}

class _TeacherDocumentsTabNavigatorState
    extends State<TeacherDocumentsTabNavigator> {
  late final GlobalKey<NavigatorState> _navigatorKey =
      widget.navigatorKey ?? GlobalKey<NavigatorState>();
  late final TeacherRequirementsService _requirementsService =
      HttpTeacherRequirementsService(widget.client);
  late final TeacherWeeklyReportsService _weeklyReportsService =
      HttpTeacherWeeklyReportsService(widget.client);

  @override
  Widget build(BuildContext context) {
    final deskSection = widget.deskSection;
    if (deskSection != null && isDeskLayout(context)) {
      return ValueListenableBuilder<(int, int)>(
        valueListenable: deskSection,
        builder: (context, value, _) => value.$1 == 1
            ? TeacherWeeklyDesk(
                key: ValueKey('weekly-${value.$2}'),
                service: _weeklyReportsService,
                classesService: widget.classesService,
              )
            : TeacherRequirementsDesk(
                key: ValueKey('requirements-${value.$2}'),
                service: _requirementsService,
                classesService: widget.classesService,
              ),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _navigatorKey.currentState?.maybePop();
      },
      child: Navigator(
        key: _navigatorKey,
        onGenerateRoute: (settings) {
          Widget page;
          final path = settings.name ?? '/';
          if (path == '/official-requirements') {
            page = TeacherOfficialRequirementsScreen(
              service: _requirementsService,
              initialStatusFilter: settings.arguments as String?,
              onOpenStudent: (studentId) => _navigatorKey.currentState
                  ?.pushNamed('/official-requirements/$studentId'),
            );
          } else if (path == '/weekly-reports') {
            page = TeacherWeeklyReportsScreen(
              service: _weeklyReportsService,
              onOpenStudent: (studentId) async {
                await _navigatorKey.currentState
                    ?.pushNamed<String>('/weekly-reports/$studentId');
              },
            );
          } else if (path.startsWith('/official-requirements/')) {
            page = TeacherRequirementReviewScreen(
              studentId: int.parse(path.split('/').last),
              service: _requirementsService,
            );
          } else if (path.startsWith('/weekly-reports/')) {
            page = TeacherWeeklyReportDetailScreen(
              studentId: int.parse(path.split('/').last),
              service: _weeklyReportsService,
            );
          } else {
            page = TeacherDocumentsHubScreen(
              onOpenOfficialRequirements: () =>
                  _navigatorKey.currentState?.pushNamed('/official-requirements'),
              onOpenWeeklyReports: () =>
                  _navigatorKey.currentState?.pushNamed('/weekly-reports'),
            );
          }
          // Typed <String> so routes pushed with pushNamed<String>() get a
          // matching Route<String> (an untyped MaterialPageRoute infers
          // <dynamic> and fails that check at runtime on web).
          return MaterialPageRoute<String>(builder: (_) => page, settings: settings);
        },
      ),
    );
  }
}
