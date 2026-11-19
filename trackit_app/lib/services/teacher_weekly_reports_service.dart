import '../models/teacher_weekly_report_row.dart';
import 'api_client.dart';

/// Instructor review of weekly DTR + AR submissions (System Revisions
/// item 13). Approving a week credits its claimed hours to the student;
/// returning it requires remarks and lets the student resubmit.
abstract class TeacherWeeklyReportsService {
  Future<List<TeacherWeeklyStudent>> getStudents();

  Future<TeacherStudentWeeks> getStudentWeeks(int studentId);

  Future<TeacherStudentWeeks> reviewWeek({
    required int studentId,
    required int weekNumber,
    required bool approve,
    String? remarks,
  });
}

class HttpTeacherWeeklyReportsService implements TeacherWeeklyReportsService {
  final ApiClient client;

  HttpTeacherWeeklyReportsService(this.client);

  @override
  Future<List<TeacherWeeklyStudent>> getStudents() async {
    final response = await client.get('/api/teacher/weekly-reports/students');
    return (response['students'] as List<dynamic>)
        .map((row) => TeacherWeeklyStudent.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<TeacherStudentWeeks> getStudentWeeks(int studentId) async {
    final response = await client.get('/api/teacher/weekly-reports/students/$studentId');
    return TeacherStudentWeeks.fromJson(response);
  }

  @override
  Future<TeacherStudentWeeks> reviewWeek({
    required int studentId,
    required int weekNumber,
    required bool approve,
    String? remarks,
  }) async {
    final response = await client.patch(
      '/api/teacher/weekly-reports/students/$studentId/weeks/$weekNumber',
      body: {
        'decision': approve ? 'approved' : 'rejected',
        if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
      },
    );
    return TeacherStudentWeeks.fromJson(response);
  }
}
