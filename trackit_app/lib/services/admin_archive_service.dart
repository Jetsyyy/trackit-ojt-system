import '../models/admin_class.dart';
import '../models/archive.dart';
import 'api_client.dart';

abstract class AdminArchiveService {
  Future<List<ArchiveAcademicYear>> getAcademicYears();

  Future<List<AdminClassSummary>> getClasses({required String year, String? search});

  Future<ArchiveClassDetail> getClassDetail(int classId);

  Future<RawFileResponse> exportYear(String year, {required String format});

  /// The active academic year and whether it can be archived.
  Future<ArchiveStatus> getStatus();

  /// Archives the active year (System Revisions item 20) after the Admin
  /// re-enters their email and password; the next year becomes active.
  Future<ArchiveResult> archiveActiveYear({required String email, required String password});

  Future<List<HteSnapshotSummary>> getHteSnapshots();

  Future<RawFileResponse> downloadHteSnapshot(String year, {required String format});
}

class ArchiveStatus {
  final String? activeYear;
  final String? nextYear;
  final bool alreadyArchived;

  /// The active year's records: companies with deployed students,
  /// approved students, and sections.
  final int companies;
  final int students;
  final int sections;

  const ArchiveStatus({
    this.activeYear,
    this.nextYear,
    required this.alreadyArchived,
    this.companies = 0,
    this.students = 0,
    this.sections = 0,
  });
}

class ArchiveResult {
  final String archivedYear;
  final String activeYear;
  final int companies;
  final int students;

  const ArchiveResult({
    required this.archivedYear,
    required this.activeYear,
    required this.companies,
    required this.students,
  });
}

class HteSnapshotSummary {
  final String academicYear;
  final DateTime archivedAt;
  final String? archivedBy;
  final int companies;
  final int students;
  final int sections;

  const HteSnapshotSummary({
    required this.academicYear,
    required this.archivedAt,
    this.archivedBy,
    required this.companies,
    required this.students,
    this.sections = 0,
  });
}

class HttpAdminArchiveService implements AdminArchiveService {
  final ApiClient client;

  HttpAdminArchiveService(this.client);

  @override
  Future<List<ArchiveAcademicYear>> getAcademicYears() async {
    final response = await client.get('/api/admin/archive/academic-years');
    final rows = response['academicYears'] as List<dynamic>;
    return rows
        .map((row) => ArchiveAcademicYear.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<AdminClassSummary>> getClasses({required String year, String? search}) async {
    final query = <String, String>{
      'year': year,
      if (search != null && search.isNotEmpty) 'search': search,
    };
    final uri = Uri(path: '/api/admin/archive/classes', queryParameters: query);
    final response = await client.get(uri.toString());
    final rows = response['classes'] as List<dynamic>;
    return rows
        .map((row) => AdminClassSummary.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ArchiveClassDetail> getClassDetail(int classId) async {
    final response = await client.get('/api/admin/archive/classes/$classId');
    return ArchiveClassDetail.fromJson(response['class'] as Map<String, dynamic>);
  }

  @override
  Future<RawFileResponse> exportYear(String year, {required String format}) async {
    final uri = Uri(
      path: '/api/admin/archive/export',
      queryParameters: {'year': year, 'format': format},
    );
    return client.getBytes(uri.toString());
  }

  @override
  Future<ArchiveStatus> getStatus() async {
    final response = await client.get('/api/admin/archive/status');
    return ArchiveStatus(
      activeYear: response['activeYear'] as String?,
      nextYear: response['nextYear'] as String?,
      alreadyArchived: response['alreadyArchived'] as bool? ?? false,
      companies: ((response['current'] as Map?)?['companies'] as num? ?? 0).toInt(),
      students: ((response['current'] as Map?)?['students'] as num? ?? 0).toInt(),
      sections: ((response['current'] as Map?)?['sections'] as num? ?? 0).toInt(),
    );
  }

  @override
  Future<ArchiveResult> archiveActiveYear({required String email, required String password}) async {
    final response = await client.post(
      '/api/admin/archive/academic-year',
      body: {'email': email, 'password': password},
    );
    final totals = response['totals'] as Map<String, dynamic>? ?? const {};
    return ArchiveResult(
      archivedYear: response['archivedYear'] as String,
      activeYear: response['activeYear'] as String,
      companies: (totals['companiesWithStudents'] as num? ?? 0).toInt(),
      students: (totals['students'] as num? ?? 0).toInt(),
    );
  }

  @override
  Future<List<HteSnapshotSummary>> getHteSnapshots() async {
    final response = await client.get('/api/admin/archive/hte-snapshots');
    return (response['snapshots'] as List<dynamic>).map((row) {
      final r = row as Map<String, dynamic>;
      final totals = r['totals'] as Map<String, dynamic>? ?? const {};
      return HteSnapshotSummary(
        academicYear: r['academicYear'] as String,
        archivedAt: DateTime.parse(r['archivedAt'] as String).toLocal(),
        archivedBy: r['archivedBy'] as String?,
        companies: (totals['companies'] as num? ?? 0).toInt(),
        students: (totals['students'] as num? ?? 0).toInt(),
        sections: (totals['sections'] as num? ?? 0).toInt(),
      );
    }).toList();
  }

  @override
  Future<RawFileResponse> downloadHteSnapshot(String year, {required String format}) {
    final uri = Uri(
      path: '/api/admin/archive/hte-snapshots/$year',
      queryParameters: {'format': format},
    );
    return client.getBytes(uri.toString());
  }
}
