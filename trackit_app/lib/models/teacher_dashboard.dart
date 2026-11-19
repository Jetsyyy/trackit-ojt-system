/// Aggregate data for the Teacher Home Dashboard, computed server-side
/// from real student records (see GET /api/teacher/dashboard) -- not
/// mock data. Program/sections are derived from the instructor's
/// assigned students rather than self-declared, since a teacher's
/// students are the source of truth for what they actually teach.
class TeacherDashboard {
  final String instructorName;
  final List<String> programs;
  final List<String> sections;

  /// Every section the Admin assigned, with its approved-student count.
  final List<TeacherDashboardClass> classes;
  final int assignedStudents;
  final int activeStudents;
  final int readyForDeployment;
  final int completedStudents;
  final int requirementsToReview;
  final int weeklySubmissionsToReview;
  final int registrationRequests;

  const TeacherDashboard({
    required this.instructorName,
    required this.programs,
    required this.sections,
    this.classes = const [],
    required this.assignedStudents,
    required this.activeStudents,
    required this.readyForDeployment,
    required this.completedStudents,
    required this.requirementsToReview,
    required this.weeklySubmissionsToReview,
    required this.registrationRequests,
  });

  factory TeacherDashboard.fromJson(Map<String, dynamic> json) {
    return TeacherDashboard(
      instructorName: json['instructorName'] as String,
      programs: (json['programs'] as List<dynamic>).cast<String>(),
      sections: (json['sections'] as List<dynamic>).cast<String>(),
      classes: ((json['classes'] as List<dynamic>?) ?? const [])
          .map((e) => TeacherDashboardClass.fromJson(e as Map<String, dynamic>))
          .toList(),
      assignedStudents: json['assignedStudents'] as int,
      activeStudents: json['activeStudents'] as int,
      readyForDeployment: json['readyForDeployment'] as int,
      completedStudents: json['completedStudents'] as int,
      requirementsToReview: json['requirementsToReview'] as int,
      weeklySubmissionsToReview: json['weeklySubmissionsToReview'] as int? ?? 0,
      registrationRequests: json['registrationRequests'] as int? ?? 0,
    );
  }
}

class TeacherDashboardClass {
  final int id;
  final String program;
  final String section;
  final String? academicYear;
  final int studentCount;

  const TeacherDashboardClass({
    required this.id,
    required this.program,
    required this.section,
    this.academicYear,
    required this.studentCount,
  });

  String get label => '$program - $section';

  factory TeacherDashboardClass.fromJson(Map<String, dynamic> json) {
    return TeacherDashboardClass(
      id: json['id'] as int,
      program: json['program'] as String,
      section: json['section'] as String,
      academicYear: json['academicYear'] as String?,
      studentCount: json['studentCount'] as int? ?? 0,
    );
  }
}
