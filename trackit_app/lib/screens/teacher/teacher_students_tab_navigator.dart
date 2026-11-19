import 'package:flutter/material.dart';
import '../../services/teacher_classes_service.dart';
import '../../services/teacher_students_service.dart';
import 'teacher_registration_requests_screen.dart';
import 'teacher_student_detail_screen.dart';
import 'teacher_students_screen.dart';

/// Mirrors DocumentsTabNavigator: owns a nested Navigator so drilling
/// into a student's detail view keeps the bottom nav visible.
class TeacherStudentsTabNavigator extends StatefulWidget {
  final TeacherClassesService classesService;
  final TeacherStudentsService studentsService;

  /// Owned by TeacherShell so Home's "Registration Requests" item can
  /// open '/requests' here directly.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Fires when the shell wants the roster re-fetched.
  final Listenable? reloadSignal;

  const TeacherStudentsTabNavigator({
    super.key,
    required this.classesService,
    required this.studentsService,
    this.navigatorKey,
    this.reloadSignal,
  });

  @override
  State<TeacherStudentsTabNavigator> createState() =>
      _TeacherStudentsTabNavigatorState();
}

class _TeacherStudentsTabNavigatorState
    extends State<TeacherStudentsTabNavigator> {
  late final GlobalKey<NavigatorState> _navigatorKey =
      widget.navigatorKey ?? GlobalKey<NavigatorState>();

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
        onGenerateRoute: (settings) {
          Widget page;
          if (settings.name != null && settings.name!.startsWith('/student/')) {
            final studentId = int.parse(settings.name!.substring('/student/'.length));
            page = TeacherStudentDetailScreen(
              studentId: studentId,
              studentsService: widget.studentsService,
            );
          } else if (settings.name == '/requests') {
            page = TeacherRegistrationRequestsScreen(service: widget.studentsService);
          } else {
            page = TeacherStudentsScreen(
              classesService: widget.classesService,
              studentsService: widget.studentsService,
              reloadSignal: widget.reloadSignal,
              onOpenStudent: (studentId) =>
                  _navigatorKey.currentState?.pushNamed('/student/$studentId'),
              onOpenRequests: () async {
                await _navigatorKey.currentState?.pushNamed<String>('/requests');
              },
            );
          }
          return MaterialPageRoute<String>(builder: (_) => page, settings: settings);
        },
      ),
    );
  }
}
