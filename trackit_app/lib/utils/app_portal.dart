import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/session_role.dart';

/// TrackIT has two separate portals (System Revisions, General):
/// - the Student portal: the main address and the Android app;
/// - the Staff portal for Instructors and the Admin: <address>/staff.
/// Each portal signs in, and reopens saved sessions for, its own roles only.
enum AppPortal { student, staff }

/// Path of the Staff portal on the web.
const String kStaffPortalPath = '/staff';

AppPortal get currentPortal {
  if (!kIsWeb) return AppPortal.student;
  final path = Uri.base.path.toLowerCase();
  return path == kStaffPortalPath || path.startsWith('$kStaffPortalPath/')
      ? AppPortal.staff
      : AppPortal.student;
}

/// Roles that can sign in to [portal], in the order the switcher lists them.
List<SessionRole> rolesFor(AppPortal portal) => portal == AppPortal.staff
    ? const [SessionRole.instructor, SessionRole.admin]
    : const [SessionRole.student];
