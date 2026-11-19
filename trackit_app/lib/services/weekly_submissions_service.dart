import '../models/weekly_submission.dart';
import 'api_client.dart';

/// A file the student picked, ready to upload.
class PickedWeeklyFile {
  final String fileName;
  final List<int> bytes;

  const PickedWeeklyFile({required this.fileName, required this.bytes});

  int get size => bytes.length;
}

/// File types the server accepts for a DTR/AR (routes/activityReports.js).
const List<String> weeklyFileExtensions = ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic'];
const int weeklyMaxFileBytes = 10 * 1024 * 1024;
const int weeklyMaxFilesPerKind = 5;

String weeklyFileContentType(String fileName) {
  switch (fileName.split('.').last.toLowerCase()) {
    case 'pdf':
      return 'application/pdf';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'heic':
      return 'image/heic';
    default:
      return 'application/octet-stream';
  }
}

/// Weekly DTR + AR submissions (one per OJT week). Hours claimed here are
/// only credited after the instructor approves the week.
abstract class WeeklySubmissionsService {
  Future<WeeklySubmissionsData> getWeeks();

  Future<WeeklySubmissionsData> submitWeek({
    required int weekNumber,
    required double claimedHours,
    required String description,
    required List<PickedWeeklyFile> dtrFiles,
    required List<PickedWeeklyFile> arFiles,
  });
}

class HttpWeeklySubmissionsService implements WeeklySubmissionsService {
  final ApiClient client;

  HttpWeeklySubmissionsService(this.client);

  @override
  Future<WeeklySubmissionsData> getWeeks() async {
    final response = await client.get('/api/activity-reports');
    return WeeklySubmissionsData.fromJson(response);
  }

  @override
  Future<WeeklySubmissionsData> submitWeek({
    required int weekNumber,
    required double claimedHours,
    required String description,
    required List<PickedWeeklyFile> dtrFiles,
    required List<PickedWeeklyFile> arFiles,
  }) async {
    MultipartUpload toUpload(String field, PickedWeeklyFile file) => MultipartUpload(
          fieldName: field,
          fileName: file.fileName,
          bytes: file.bytes,
          contentType: weeklyFileContentType(file.fileName),
        );

    final response = await client.postMultipartFiles(
      '/api/activity-reports/$weekNumber/submit',
      fields: {
        'claimedHours': claimedHours.toString(),
        'description': description,
      },
      files: [
        for (final f in dtrFiles) toUpload('dtr', f),
        for (final f in arFiles) toUpload('ar', f),
      ],
    );
    return WeeklySubmissionsData.fromJson(response);
  }
}
