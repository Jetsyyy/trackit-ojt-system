import 'api_client.dart';

/// A single-use Instructor Registration Code (System Revisions item 19).
class InstructorRegistrationCode {
  final int id;
  final String code;
  final String? note;

  /// 'available', 'used' or 'revoked'.
  final String status;
  final DateTime createdAt;
  final DateTime? usedAt;
  final String? usedByName;

  const InstructorRegistrationCode({
    required this.id,
    required this.code,
    this.note,
    required this.status,
    required this.createdAt,
    this.usedAt,
    this.usedByName,
  });

  factory InstructorRegistrationCode.fromJson(Map<String, dynamic> json) {
    return InstructorRegistrationCode(
      id: json['id'] as int,
      code: json['code'] as String,
      note: json['note'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      usedAt: json['usedAt'] != null ? DateTime.parse(json['usedAt'] as String).toLocal() : null,
      usedByName: json['usedByName'] as String?,
    );
  }
}

/// An instructor who registered with a code and waits for approval.
class InstructorAccountRequest {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String instructorNumber;
  final DateTime requestedAt;

  const InstructorAccountRequest({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.instructorNumber,
    required this.requestedAt,
  });

  factory InstructorAccountRequest.fromJson(Map<String, dynamic> json) {
    return InstructorAccountRequest(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      instructorNumber: json['instructorNumber'] as String,
      requestedAt: DateTime.parse(json['requestedAt'] as String).toLocal(),
    );
  }
}

/// A section (program + section + academic year) and its student code.
class AdminSection {
  final int id;
  final String program;
  final String section;
  final String academicYear;
  final int? instructorId;
  final String? instructorName;
  final String activationCode;
  final int studentCount;

  const AdminSection({
    required this.id,
    required this.program,
    required this.section,
    required this.academicYear,
    this.instructorId,
    this.instructorName,
    required this.activationCode,
    required this.studentCount,
  });

  String get label => '$program - $section';

  factory AdminSection.fromJson(Map<String, dynamic> json) {
    return AdminSection(
      id: json['id'] as int,
      program: json['program'] as String,
      section: json['section'] as String,
      academicYear: json['academicYear'] as String,
      instructorId: json['instructorId'] as int?,
      instructorName: json['instructorName'] as String?,
      activationCode: json['activationCode'] as String? ?? '',
      studentCount: json['studentCount'] as int? ?? 0,
    );
  }
}

/// An approved instructor, for the section-assignment picker.
class ApprovedInstructor {
  final int id;
  final String name;
  final String instructorNumber;
  final bool isActive;

  const ApprovedInstructor({
    required this.id,
    required this.name,
    required this.instructorNumber,
    required this.isActive,
  });

  factory ApprovedInstructor.fromJson(Map<String, dynamic> json) {
    return ApprovedInstructor(
      id: json['id'] as int,
      name: json['name'] as String,
      instructorNumber: json['instructorNumber'] as String,
      isActive: json['status'] == 'active',
    );
  }
}

/// Admin side of instructor onboarding: registration codes, account
/// requests, and the Sections list instructors are assigned to.
class AdminAccountsService {
  final ApiClient client;

  AdminAccountsService(this.client);

  Future<List<InstructorRegistrationCode>> getCodes() async {
    final response = await client.get('/api/admin/instructors/registration-codes');
    return (response['codes'] as List<dynamic>)
        .map((row) => InstructorRegistrationCode.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<InstructorRegistrationCode> createCode({String? note}) async {
    final response = await client.post(
      '/api/admin/instructors/registration-codes',
      body: {if (note != null && note.isNotEmpty) 'note': note},
    );
    return InstructorRegistrationCode.fromJson(response['code'] as Map<String, dynamic>);
  }

  Future<void> revokeCode(int codeId) async {
    await client.patch('/api/admin/instructors/registration-codes/$codeId/revoke');
  }

  Future<List<InstructorAccountRequest>> getRequests() async {
    final response = await client.get('/api/admin/instructors/requests');
    return (response['requests'] as List<dynamic>)
        .map((row) => InstructorAccountRequest.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> decideRequest({
    required int instructorId,
    required bool approve,
    List<int> sectionIds = const [],
    String? reason,
  }) async {
    await client.patch(
      '/api/admin/instructors/requests/$instructorId',
      body: {
        'decision': approve ? 'approved' : 'rejected',
        if (approve) 'sectionIds': sectionIds,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
  }

  Future<List<AdminSection>> getSections({String? academicYear}) async {
    final query = <String, String>{
      if (academicYear != null && academicYear.isNotEmpty) 'academicYear': academicYear,
    };
    final uri = Uri(path: '/api/admin/classes', queryParameters: query);
    final response = await client.get(uri.toString());
    return (response['classes'] as List<dynamic>)
        .map((row) => AdminSection.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> createSection({
    required String program,
    required String section,
    required String academicYear,
  }) async {
    await client.post(
      '/api/admin/classes',
      body: {'program': program, 'section': section, 'academicYear': academicYear},
    );
  }

  /// [instructorId] null unassigns the section.
  Future<void> assignSection({required int sectionId, int? instructorId}) async {
    await client.patch(
      '/api/admin/classes/$sectionId/instructor',
      body: {'instructorId': instructorId},
    );
  }

  /// The active academic year (moves forward when the Admin archives a
  /// year, System Revisions item 20).
  Future<String?> getActiveAcademicYear() async {
    final response = await client.get('/api/admin/archive/status');
    return response['activeYear'] as String?;
  }

  Future<List<ApprovedInstructor>> getApprovedInstructors() async {
    final response = await client.get('/api/admin/instructors');
    return (response['instructors'] as List<dynamic>)
        .map((row) => ApprovedInstructor.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
