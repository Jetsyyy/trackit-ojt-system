import 'package:flutter/material.dart';
import '../../../models/student.dart';
import '../../../models/weekly_submission.dart';
import '../../../services/api_client.dart';
import '../../../services/custom_requirements_service.dart';
import '../../../services/hte_directory_service.dart';
import '../../../services/ojt_requirements_service.dart';
import '../../../services/student_profile_service.dart';
import '../../../services/weekly_submissions_service.dart';
import '../../../widgets/student/student_ui.dart';
import '../weekly/weekly_submission_form_screen.dart';
import '../weekly/weekly_submissions_screen.dart';
import 'additional_requirements_screen.dart';
import 'documents_hub_screen.dart';
import 'hte_directory_screen.dart';
import 'startup_requirements_screen.dart';

/// Owns a nested [Navigator] for the Document tab so pushing into HTE
/// Directory, OJT Requirements or Weekly Submissions keeps StudentShell's
/// bottom nav visible, instead of covering the whole screen the way a
/// root-level push would.
class DocumentsTabNavigator extends StatefulWidget {
  final Student student;
  final ApiClient client;
  final WeeklySubmissionsService weeklyService;
  final Listenable weeklyReload;
  final VoidCallback onWeekSubmitted;

  const DocumentsTabNavigator({
    super.key,
    required this.student,
    required this.client,
    required this.weeklyService,
    required this.weeklyReload,
    required this.onWeekSubmitted,
  });

  @override
  State<DocumentsTabNavigator> createState() => DocumentsTabNavigatorState();
}

class DocumentsTabNavigatorState extends State<DocumentsTabNavigator> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final HteDirectoryService _hteService = HttpHteDirectoryService(widget.client);
  late final OjtRequirementsService _ojtService = HttpOjtRequirementsService(widget.client);
  late final StudentProfileService _profileService = HttpStudentProfileService(widget.client);
  late final CustomRequirementsService _customRequirementsService =
      HttpCustomRequirementsService(widget.client);

  /// Opens Weekly Submissions from anywhere (Home's button, a notification).
  void openWeekly() {
    final nav = _navigatorKey.currentState;
    if (nav == null) return;
    nav.popUntil((route) => route.isFirst);
    nav.pushNamed('/weekly');
  }

  Future<String?> _openWeek(WeeklySubmission week) async {
    final result = await _navigatorKey.currentState?.push<String>(
      MaterialPageRoute<String>(
        builder: (_) => StudentBackdrop(
          child: WeeklySubmissionFormScreen(service: widget.weeklyService, week: week),
        ),
      ),
    );
    if (result != null) widget.onWeekSubmitted();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // The system back gesture targets the root Navigator, so forward
        // it to this nested one when there's a pushed screen to pop.
        _navigatorKey.currentState?.maybePop();
      },
      child: Navigator(
        key: _navigatorKey,
        onGenerateRoute: (settings) {
          Widget page;
          switch (settings.name) {
            case '/hte':
              page = HteDirectoryScreen(service: _hteService);
              break;
            case '/ojt-requirements':
              page = StartupRequirementsScreen(
                service: _ojtService,
                profileService: _profileService,
              );
              break;
            case '/weekly':
              // A fresh screen each time it's opened, so it loads current data.
              page = WeeklySubmissionsScreen(
                service: widget.weeklyService,
                reloadSignal: widget.weeklyReload,
                onOpenWeek: _openWeek,
              );
              break;
            case '/additional-requirements':
              page = AdditionalRequirementsScreen(service: _customRequirementsService);
              break;
            case '/':
            default:
              page = DocumentsHubScreen(
                onOpenHteDirectory: () => _navigatorKey.currentState?.pushNamed('/hte'),
                onOpenOjtRequirements: () =>
                    _navigatorKey.currentState?.pushNamed('/ojt-requirements'),
                onOpenWeeklySubmissions: () => _navigatorKey.currentState?.pushNamed('/weekly'),
                onOpenScheduledRequirements: () =>
                    _navigatorKey.currentState?.pushNamed('/additional-requirements'),
              );
          }
          return MaterialPageRoute(builder: (_) => StudentBackdrop(child: page), settings: settings);
        },
      ),
    );
  }
}
