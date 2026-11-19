import 'package:flutter/material.dart';
import '../../../models/weekly_submission.dart';
import '../../../services/weekly_submissions_service.dart';
import 'weekly_submission_form_screen.dart';
import 'weekly_submissions_screen.dart';

/// Owns a nested Navigator for the Weekly tab (like DocumentsTabNavigator)
/// so opening a week keeps StudentShell's bottom nav visible.
class WeeklyTabNavigator extends StatefulWidget {
  final WeeklySubmissionsService service;

  /// Fires when the shell switches to this tab; the week list re-fetches.
  final Listenable reloadSignal;

  /// Called after a week is submitted, so the shell can refresh the Home
  /// tab's hours summary.
  final VoidCallback onSubmitted;

  const WeeklyTabNavigator({
    super.key,
    required this.service,
    required this.reloadSignal,
    required this.onSubmitted,
  });

  @override
  State<WeeklyTabNavigator> createState() => _WeeklyTabNavigatorState();
}

class _WeeklyTabNavigatorState extends State<WeeklyTabNavigator> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  Future<String?> _openWeek(WeeklySubmission week) async {
    final result = await _navigatorKey.currentState?.push<String>(
      MaterialPageRoute<String>(
        builder: (_) => WeeklySubmissionFormScreen(service: widget.service, week: week),
      ),
    );
    if (result != null) widget.onSubmitted();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _navigatorKey.currentState?.maybePop();
      },
      child: Navigator(
        key: _navigatorKey,
        onGenerateRoute: (settings) => MaterialPageRoute(
          settings: settings,
          builder: (_) => WeeklySubmissionsScreen(
            service: widget.service,
            reloadSignal: widget.reloadSignal,
            onOpenWeek: _openWeek,
          ),
        ),
      ),
    );
  }
}
