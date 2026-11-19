import 'ojt_progress.dart';
import 'ojt_stage.dart';

class TeacherStudentCompany {
  final String name;
  final String address;
  final String supervisorName;
  final String contactNumber;

  const TeacherStudentCompany({
    required this.name,
    required this.address,
    required this.supervisorName,
    required this.contactNumber,
  });

  factory TeacherStudentCompany.fromJson(Map<String, dynamic> json) {
    return TeacherStudentCompany(
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      supervisorName: json['supervisorName'] as String? ?? '',
      contactNumber: json['contactNumber'] as String? ?? '',
    );
  }
}

/// Credited hours come only from approved weekly DTRs; [pendingHours] are
/// claimed in weeks still waiting for review.
class TeacherStudentProgressSummary {
  final double completedHours;
  final double requiredHours;
  final double pendingHours;
  final int approvedWeeks;
  final double weeklyAverageHours;
  final DateTime? lastSubmittedWeekEnd;

  const TeacherStudentProgressSummary({
    required this.completedHours,
    required this.requiredHours,
    required this.pendingHours,
    required this.approvedWeeks,
    required this.weeklyAverageHours,
    this.lastSubmittedWeekEnd,
  });

  double get progressRatio {
    if (requiredHours <= 0) return 0;
    final ratio = completedHours / requiredHours;
    if (ratio < 0) return 0;
    if (ratio > 1) return 1;
    return ratio;
  }

  factory TeacherStudentProgressSummary.fromJson(Map<String, dynamic> json) {
    return TeacherStudentProgressSummary(
      completedHours: (json['completedHours'] as num).toDouble(),
      requiredHours: (json['requiredHours'] as num).toDouble(),
      pendingHours: (json['pendingHours'] as num? ?? 0).toDouble(),
      approvedWeeks: (json['approvedWeeks'] as num? ?? 0).toInt(),
      weeklyAverageHours: (json['weeklyAverageHours'] as num).toDouble(),
      lastSubmittedWeekEnd: json['lastSubmittedWeekEnd'] != null
          ? DateTime.parse(json['lastSubmittedWeekEnd'] as String).toLocal()
          : null,
    );
  }
}

class TeacherStudentDetail {
  final int id;
  final String name;
  final String email;
  final String course;
  final String section;
  final String? studentNumber;
  final String? yearLevel;
  final String? avatarUrl;
  final String? contactPerson;
  final String? phone;
  final String? address;
  final DateTime? ojtStartDate;
  final TeacherStudentCompany? company;
  final TeacherStudentProgressSummary progress;
  final OjtStage stage;
  final OjtProgressStatus progressStatus;

  const TeacherStudentDetail({
    required this.id,
    required this.name,
    required this.email,
    required this.course,
    required this.section,
    this.studentNumber,
    this.yearLevel,
    this.avatarUrl,
    this.contactPerson,
    this.phone,
    this.address,
    this.ojtStartDate,
    this.company,
    required this.progress,
    required this.stage,
    required this.progressStatus,
  });

  factory TeacherStudentDetail.fromJson(Map<String, dynamic> json) {
    return TeacherStudentDetail(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      course: json['course'] as String,
      section: json['section'] as String,
      studentNumber: json['studentNumber'] as String?,
      yearLevel: json['yearLevel'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      contactPerson: json['contactPerson'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      ojtStartDate: json['ojtStartDate'] != null
          ? DateTime.tryParse(json['ojtStartDate'] as String)?.toLocal()
          : null,
      company: json['company'] != null
          ? TeacherStudentCompany.fromJson(json['company'] as Map<String, dynamic>)
          : null,
      progress: TeacherStudentProgressSummary.fromJson(
        json['progress'] as Map<String, dynamic>,
      ),
      stage: ojtStageFromDb(json['stage'] as String),
      progressStatus: ojtProgressStatusFromDb(json['progressStatus'] as String?),
    );
  }
}
