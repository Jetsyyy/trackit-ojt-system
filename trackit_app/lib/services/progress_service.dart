import '../models/ojt_progress.dart';
import 'api_client.dart';

/// The student's credited OJT hours (approved weekly DTRs only).
abstract class ProgressService {
  Future<OjtProgress> getProgress();
}

class HttpProgressService implements ProgressService {
  final ApiClient client;

  HttpProgressService(this.client);

  @override
  Future<OjtProgress> getProgress() async {
    // Served from the old attendance route path; the numbers come from
    // approved weekly submissions (server/utils/creditedHours.js).
    final response = await client.get('/api/attendance/progress');
    return OjtProgress.fromJson(response['progress'] as Map<String, dynamic>);
  }
}
