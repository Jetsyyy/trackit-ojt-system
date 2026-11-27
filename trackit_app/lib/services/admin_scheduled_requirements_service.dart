import 'api_client.dart';

/// A requirement the OJT office schedules for every OJT student of an
/// academic year, e.g. "Supervisor Evaluation Form" for "1st Semester".
class ScheduledRequirement {
  final int id;
  final String title;
  final String period;
  final String description;
  final String academicYear;
  final DateTime? dueAt;
  final String? templateUrl;
  final String? templateName;
  final int totalStudents;
  final int submitted;
  final int approved;
  final int late;

  const ScheduledRequirement({
    required this.id,
    required this.title,
    required this.period,
    required this.description,
    required this.academicYear,
    this.dueAt,
    this.templateUrl,
    this.templateName,
    this.totalStudents = 0,
    this.submitted = 0,
    this.approved = 0,
    this.late = 0,
  });

  bool get isClosed => dueAt != null && DateTime.now().isAfter(dueAt!);
  bool get isDueSoon => dueAt != null && !isClosed && dueAt!.difference(DateTime.now()).inHours < 24;

  factory ScheduledRequirement.fromJson(Map<String, dynamic> json) => ScheduledRequirement(
        id: (json['id'] as num).toInt(),
        title: json['title'] as String? ?? '',
        period: json['period'] as String? ?? '',
        description: json['description'] as String? ?? '',
        academicYear: json['academicYear'] as String? ?? '',
        dueAt: json['dueAt'] != null ? DateTime.parse(json['dueAt'] as String).toLocal() : null,
        templateUrl: json['templateUrl'] as String?,
        templateName: json['templateName'] as String?,
        totalStudents: (json['totalStudents'] as num?)?.toInt() ?? 0,
        submitted: (json['submitted'] as num?)?.toInt() ?? 0,
        approved: (json['approved'] as num?)?.toInt() ?? 0,
        late: (json['late'] as num?)?.toInt() ?? 0,
      );
}

/// One student's status for a scheduled requirement.
class ScheduledSubmission {
  final int studentId;
  final String name;
  final String section;
  final String status;
  final DateTime? submittedAt;
  final bool isLate;
  final String? fileName;
  final String? fileUrl;

  const ScheduledSubmission({
    required this.studentId,
    required this.name,
    required this.section,
    required this.status,
    this.submittedAt,
    this.isLate = false,
    this.fileName,
    this.fileUrl,
  });

  factory ScheduledSubmission.fromJson(Map<String, dynamic> json) => ScheduledSubmission(
        studentId: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? '',
        section: json['section'] as String? ?? '',
        status: json['status'] as String? ?? 'missing',
        submittedAt: json['submittedAt'] != null ? DateTime.parse(json['submittedAt'] as String).toLocal() : null,
        isLate: json['isLate'] as bool? ?? false,
        fileName: json['fileName'] as String?,
        fileUrl: json['fileUrl'] as String?,
      );
}

class AdminScheduledRequirementsService {
  final ApiClient client;
  AdminScheduledRequirementsService(this.client);

  static const _base = '/api/admin/scheduled-requirements';

  /// Returns the academic year shown and its requirements (soonest due first).
  Future<(String, List<ScheduledRequirement>)> getAll({String? academicYear}) async {
    final response = await client.get(
      academicYear == null ? _base : '$_base?academicYear=${Uri.encodeQueryComponent(academicYear)}',
    );
    final list = (response['requirements'] as List<dynamic>)
        .map((r) => ScheduledRequirement.fromJson(r as Map<String, dynamic>))
        .toList();
    return (response['academicYear'] as String? ?? '', list);
  }

  Future<List<ScheduledSubmission>> getSubmissions(int id) async {
    final response = await client.get('$_base/$id/submissions');
    return (response['students'] as List<dynamic>)
        .map((s) => ScheduledSubmission.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  Map<String, String> _fields({
    required String title,
    required String period,
    required String description,
    required DateTime dueAt,
  }) =>
      {
        'title': title,
        'period': period,
        'description': description,
        'dueAt': dueAt.toUtc().toIso8601String(),
      };

  /// Posts it for [academicYear] (default: the active one); every student
  /// there is notified.
  Future<void> create({
    String? academicYear,
    required String title,
    required String period,
    required String description,
    required DateTime dueAt,
    List<int>? templateBytes,
    String? templateName,
    String templateContentType = 'application/pdf',
  }) async {
    await client.postMultipart(
      _base,
      fieldName: 'template',
      fileBytes: templateBytes,
      fileName: templateName,
      contentType: templateContentType,
      fields: {
        ..._fields(title: title, period: period, description: description, dueAt: dueAt),
        'academicYear': ?academicYear,
      },
    );
  }

  Future<void> update(
    int id, {
    required String title,
    required String period,
    required String description,
    required DateTime dueAt,
    List<int>? templateBytes,
    String? templateName,
    String templateContentType = 'application/pdf',
  }) async {
    await client.postMultipart(
      '$_base/$id',
      method: 'PATCH',
      fieldName: 'template',
      fileBytes: templateBytes,
      fileName: templateName,
      contentType: templateContentType,
      fields: _fields(title: title, period: period, description: description, dueAt: dueAt),
    );
  }

  Future<void> removeTemplate(int id) async {
    await client.delete('$_base/$id/template');
  }

  Future<void> delete(int id) async {
    await client.delete('$_base/$id');
  }
}
