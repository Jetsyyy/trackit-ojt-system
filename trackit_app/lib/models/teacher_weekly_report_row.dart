import 'weekly_submission.dart';

/// One assigned student in the instructor's Weekly DTR & AR review list.
/// Uses the same [WeeklySummary] the student sees, so both sides always
/// agree on credited, pending and remaining hours.
class TeacherWeeklyStudent {
  final int id;
  final String name;
  final String? avatarUrl;
  final String course;
  final String section;
  final String? studentNumber;
  final int? classId;
  final WeeklySummary summary;

  const TeacherWeeklyStudent({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.course,
    required this.section,
    this.studentNumber,
    this.classId,
    required this.summary,
  });

  factory TeacherWeeklyStudent.fromJson(Map<String, dynamic> json) {
    return TeacherWeeklyStudent(
      id: json['id'] as int,
      name: json['name'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      course: json['course'] as String? ?? '',
      section: json['section'] as String? ?? '',
      studentNumber: json['studentNumber'] as String?,
      classId: json['classId'] as int?,
      // The list endpoint spreads the summary fields onto the student row.
      summary: WeeklySummary.fromJson(json),
    );
  }
}

/// One student's weeks, as returned by the detail and review endpoints.
class TeacherStudentWeeks {
  final TeacherWeeklyStudent student;
  final List<WeeklySubmission> weeks;

  const TeacherStudentWeeks({required this.student, required this.weeks});

  factory TeacherStudentWeeks.fromJson(Map<String, dynamic> json) {
    final student = json['student'] as Map<String, dynamic>;
    return TeacherStudentWeeks(
      student: TeacherWeeklyStudent.fromJson({
        ...student,
        ...(json['summary'] as Map<String, dynamic>),
      }),
      weeks: (json['reports'] as List<dynamic>)
          .map((w) => WeeklySubmission.fromJson(w as Map<String, dynamic>))
          .toList(),
    );
  }
}
