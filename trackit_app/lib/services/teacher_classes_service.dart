import '../models/instructor_class.dart';
import 'api_client.dart';

/// The instructor's assigned sections. Sections are created and assigned
/// by the Admin (System Revisions item 19), so there's no create call.
abstract class TeacherClassesService {
  Future<List<InstructorClass>> getClasses();
}

class HttpTeacherClassesService implements TeacherClassesService {
  final ApiClient client;

  HttpTeacherClassesService(this.client);

  @override
  Future<List<InstructorClass>> getClasses() async {
    final response = await client.get('/api/teacher/classes');
    final rows = response['classes'] as List<dynamic>;
    return rows
        .map((row) => InstructorClass.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
