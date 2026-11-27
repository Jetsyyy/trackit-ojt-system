import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../services/admin_auth_service.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/instructor_auth_service.dart';
import '../../services/session_role.dart';
import '../../widgets/common/trackit_splash.dart';
import '../../utils/app_portal.dart';
import '../admin/admin_bootstrap.dart';
import '../student/student_bootstrap.dart';
import '../teacher/teacher_bootstrap.dart';
import 'login_screen.dart';

/// Root of the app below MaterialApp: decides between the login flow and
/// the authenticated Student or Teacher module based on the stored
/// session role, and owns the single ApiClient/auth service instances
/// shared by everything underneath.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final ApiClient _client = ApiClient();
  late final AuthService _authService = AuthService(_client);
  late final InstructorAuthService _instructorAuthService =
      InstructorAuthService(_client);
  late final AdminAuthService _adminAuthService = AdminAuthService(_client);
  final SessionRoleStore _roleStore = SessionRoleStore();
  bool _checking = true;
  SessionRole? _activeRole;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  // On phones the splash stays up for its whole intro (logo pop, then the
  // school name rising) plus a short pause. On the website the page's own
  // loading screen (web/index.html) has already played it, so no wait.
  static final _minSplash = kIsWeb
      ? Duration.zero
      : TrackitSplash.introDuration + const Duration(milliseconds: 500);

  Future<void> _checkSession() async {
    final shown = Stopwatch()..start();
    final stored = await _roleStore.load();
    if (stored.expired) {
      // Logged in without "Remember me" in an earlier browser/app session.
      await _authService.logout();
      await _instructorAuthService.logout();
      await _adminAuthService.logout();
    }
    // A saved session only reopens in its own portal: a student session is
    // not resumed on /staff, nor an instructor or admin one on the Student
    // portal (they see that portal's login instead).
    final role = rolesFor(currentPortal).contains(stored.role) ? stored.role : null;
    SessionRole? resolvedRole;
    if (role == SessionRole.student) {
      final token = await _authService.loadStoredToken();
      if (token != null) resolvedRole = SessionRole.student;
    } else if (role == SessionRole.instructor) {
      final token = await _instructorAuthService.loadStoredToken();
      if (token != null) resolvedRole = SessionRole.instructor;
    } else if (role == SessionRole.admin) {
      final token = await _adminAuthService.loadStoredToken();
      if (token != null) resolvedRole = SessionRole.admin;
    }
    final wait = _minSplash - shown.elapsed;
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    if (!mounted) return;
    setState(() {
      _activeRole = resolvedRole;
      _checking = false;
    });
  }

  Future<void> _handleLoggedIn(SessionRole role) async {
    await _roleStore.save(role);
    if (!mounted) return;
    setState(() => _activeRole = role);
  }

  Future<void> _handleLoggedOut() async {
    await _authService.logout();
    await _instructorAuthService.logout();
    await _adminAuthService.logout();
    await _roleStore.clear();
    if (mounted) setState(() => _activeRole = null);
  }

  @override
  Widget build(BuildContext context) {
    // Fades from the splash to the login page or the user's home.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: KeyedSubtree(
        key: ValueKey(_checking ? 'splash' : 'role-${_activeRole?.name ?? 'none'}'),
        child: _checking ? const TrackitSplash(playIntro: !kIsWeb) : _screen(),
      ),
    );
  }

  Widget _screen() {
    switch (_activeRole) {
      case SessionRole.student:
        return StudentBootstrap(client: _client, onLoggedOut: _handleLoggedOut);
      case SessionRole.instructor:
        return TeacherBootstrap(client: _client, onLoggedOut: _handleLoggedOut);
      case SessionRole.admin:
        return AdminBootstrap(
          client: _client,
          adminAuthService: _adminAuthService,
          onLoggedOut: _handleLoggedOut,
        );
      case null:
        return LoginScreen(
          authService: _authService,
          instructorAuthService: _instructorAuthService,
          adminAuthService: _adminAuthService,
          onLoggedIn: _handleLoggedIn,
        );
    }
  }
}
