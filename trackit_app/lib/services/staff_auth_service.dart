import 'admin_auth_service.dart';
import 'api_client.dart';
import 'instructor_auth_service.dart';
import 'session_role.dart';

/// Staff portal sign-in (System Revision 7): one email + password form; the
/// server decides whether the account is an Admin or an Instructor and the
/// matching service keeps the session.
class StaffAuthService {
  final ApiClient client;
  final AdminAuthService adminAuth;
  final InstructorAuthService instructorAuth;

  StaffAuthService({required this.client, required this.adminAuth, required this.instructorAuth});

  /// Signs in and returns the role the server found for this account.
  Future<SessionRole> login({required String email, required String password}) async {
    final response = await client.post(
      '/api/staff-auth/login',
      body: {'email': email, 'password': password},
    );
    if (response['role'] == 'admin') {
      await adminAuth.completeLogin(response);
      return SessionRole.admin;
    }
    await instructorAuth.completeLogin(response);
    return SessionRole.instructor;
  }
}
