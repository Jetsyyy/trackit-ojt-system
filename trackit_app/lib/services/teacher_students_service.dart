import '../models/student_registration_request.dart';
import '../models/teacher_student_detail.dart';
import '../models/teacher_student_summary.dart';
import '../widgets/teacher/password_reset_requests_card.dart';
import 'api_client.dart';

abstract class TeacherStudentsService {
  Future<List<TeacherStudentSummary>> getStudents();
  Future<TeacherStudentDetail> getStudentDetail(int studentId);

  /// Students waiting for this instructor to approve their registration.
  Future<List<StudentRegistrationRequest>> getRegistrationRequests();

  /// [reason] is required when declining.
  Future<void> decideRegistration({
    required int studentId,
    required bool approve,
    String? reason,
  });

  /// Records of every assigned student (System Revisions item 14) as
  /// 'xlsx' or 'pdf'.
  Future<RawFileResponse> exportRecords({required String format});

  /// Students who asked for a password reset (Forgot Password).
  Future<List<PasswordResetRequest>> getPasswordResets();

  /// Resets the student's password; returns the one-time temporary password.
  Future<String> resetPassword(int requestId);

  Future<void> dismissPasswordReset(int requestId);
}

class HttpTeacherStudentsService implements TeacherStudentsService {
  final ApiClient client;

  HttpTeacherStudentsService(this.client);

  @override
  Future<List<PasswordResetRequest>> getPasswordResets() async {
    final response = await client.get('/api/teacher/students/password-resets');
    return (response['requests'] as List<dynamic>)
        .map((r) => PasswordResetRequest.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<String> resetPassword(int requestId) async {
    final response = await client.post('/api/teacher/students/password-resets/$requestId/reset');
    return response['temporaryPassword'] as String;
  }

  @override
  Future<void> dismissPasswordReset(int requestId) async {
    await client.post('/api/teacher/students/password-resets/$requestId/dismiss');
  }

  @override
  Future<List<TeacherStudentSummary>> getStudents() async {
    final response = await client.get('/api/teacher/students');
    final rows = response['students'] as List<dynamic>;
    return rows
        .map(
          (row) => TeacherStudentSummary.fromJson(row as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Future<TeacherStudentDetail> getStudentDetail(int studentId) async {
    final response = await client.get('/api/teacher/students/$studentId');
    return TeacherStudentDetail.fromJson(response['student'] as Map<String, dynamic>);
  }

  @override
  Future<List<StudentRegistrationRequest>> getRegistrationRequests() async {
    final response = await client.get('/api/teacher/students/requests');
    return (response['requests'] as List<dynamic>)
        .map((row) => StudentRegistrationRequest.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> decideRegistration({
    required int studentId,
    required bool approve,
    String? reason,
  }) async {
    await client.patch(
      '/api/teacher/students/requests/$studentId',
      body: {
        'decision': approve ? 'approved' : 'rejected',
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
  }

  @override
  Future<RawFileResponse> exportRecords({required String format}) {
    return client.getBytes('/api/teacher/students/export?format=$format');
  }
}
