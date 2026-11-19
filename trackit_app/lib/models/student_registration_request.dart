/// A student who registered with the code of one of the instructor's
/// sections and is waiting for approval (System Revisions item 11).
class StudentRegistrationRequest {
  final int id;
  final String name;
  final String email;
  final String? studentNumber;
  final String? yearLevel;
  final String program;
  final String section;
  final int? classId;
  final DateTime requestedAt;

  const StudentRegistrationRequest({
    required this.id,
    required this.name,
    required this.email,
    this.studentNumber,
    this.yearLevel,
    required this.program,
    required this.section,
    this.classId,
    required this.requestedAt,
  });

  factory StudentRegistrationRequest.fromJson(Map<String, dynamic> json) {
    return StudentRegistrationRequest(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      studentNumber: json['studentNumber'] as String?,
      yearLevel: json['yearLevel'] as String?,
      program: json['program'] as String,
      section: json['section'] as String,
      classId: json['classId'] as int?,
      requestedAt: DateTime.parse(json['requestedAt'] as String).toLocal(),
    );
  }
}
