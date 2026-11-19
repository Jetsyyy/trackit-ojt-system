/// One row in the Overview's student roster for the selected academic
/// year -- backs both the stat cards/charts (aggregated) and the
/// View Student List drill-down (per-row).
enum AdminOverviewCompletionBucket { completed, ongoing, notStarted }

AdminOverviewCompletionBucket _completionBucketFromDb(String value) {
  switch (value) {
    case 'completed':
      return AdminOverviewCompletionBucket.completed;
    case 'notStarted':
      return AdminOverviewCompletionBucket.notStarted;
    default:
      return AdminOverviewCompletionBucket.ongoing;
  }
}

/// Where a student stands on weekly DTR & AR submissions.
enum AdminOverviewWeeklyStatus { awaitingReview, returned, noRecent, upToDate, notStarted }

AdminOverviewWeeklyStatus _weeklyStatusFromDb(String value) {
  switch (value) {
    case 'awaitingReview':
      return AdminOverviewWeeklyStatus.awaitingReview;
    case 'returned':
      return AdminOverviewWeeklyStatus.returned;
    case 'noRecent':
      return AdminOverviewWeeklyStatus.noRecent;
    case 'notStarted':
      return AdminOverviewWeeklyStatus.notStarted;
    default:
      return AdminOverviewWeeklyStatus.upToDate;
  }
}

class AdminOverviewStudent {
  final int id;
  final String name;
  final String? program;
  final String? section;
  final String? instructorName;
  final bool accountActivated;
  final AdminOverviewCompletionBucket completionBucket;
  final double completedHours;
  final double requiredHours;

  const AdminOverviewStudent({
    required this.id,
    required this.name,
    this.program,
    this.section,
    this.instructorName,
    required this.accountActivated,
    required this.completionBucket,
    required this.completedHours,
    required this.requiredHours,
  });

  factory AdminOverviewStudent.fromJson(Map<String, dynamic> json) {
    return AdminOverviewStudent(
      id: json['id'] as int,
      name: json['name'] as String,
      program: json['program'] as String?,
      section: json['section'] as String?,
      instructorName: json['instructorName'] as String?,
      accountActivated: json['accountStatus'] == 'activated',
      completionBucket: _completionBucketFromDb(json['completionBucket'] as String),
      completedHours: (json['completedHours'] as num).toDouble(),
      requiredHours: (json['requiredHours'] as num).toDouble(),
    );
  }
}

class AdminOverviewWeeklyEntry {
  final int id;
  final String name;
  final String? program;
  final String? section;
  final String? instructorName;
  final AdminOverviewWeeklyStatus status;
  final int approvedWeeks;
  final int awaitingReviewWeeks;
  final int returnedWeeks;
  final DateTime? lastWeekEnd;

  const AdminOverviewWeeklyEntry({
    required this.id,
    required this.name,
    this.program,
    this.section,
    this.instructorName,
    required this.status,
    required this.approvedWeeks,
    required this.awaitingReviewWeeks,
    required this.returnedWeeks,
    this.lastWeekEnd,
  });

  factory AdminOverviewWeeklyEntry.fromJson(Map<String, dynamic> json) {
    return AdminOverviewWeeklyEntry(
      id: json['id'] as int,
      name: json['name'] as String,
      program: json['program'] as String?,
      section: json['section'] as String?,
      instructorName: json['instructorName'] as String?,
      status: _weeklyStatusFromDb(json['status'] as String),
      approvedWeeks: json['approvedWeeks'] as int,
      awaitingReviewWeeks: json['awaitingReviewWeeks'] as int,
      returnedWeeks: json['returnedWeeks'] as int,
      lastWeekEnd:
          json['lastWeekEnd'] != null ? DateTime.parse(json['lastWeekEnd'] as String) : null,
    );
  }
}

class AdminOverviewAccountPreparing {
  final int id;
  final String name;
  final String email;
  final String? program;
  final String? section;

  const AdminOverviewAccountPreparing({
    required this.id,
    required this.name,
    required this.email,
    this.program,
    this.section,
  });

  factory AdminOverviewAccountPreparing.fromJson(Map<String, dynamic> json) {
    return AdminOverviewAccountPreparing(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      program: json['program'] as String?,
      section: json['section'] as String?,
    );
  }
}

class AdminOverviewDocumentPending {
  final String id;
  final String studentName;
  final String requirementName;
  final DateTime? submittedAt;

  const AdminOverviewDocumentPending({
    required this.id,
    required this.studentName,
    required this.requirementName,
    this.submittedAt,
  });

  factory AdminOverviewDocumentPending.fromJson(Map<String, dynamic> json) {
    return AdminOverviewDocumentPending(
      id: json['id'] as String,
      studentName: json['studentName'] as String,
      requirementName: json['requirementName'] as String,
      submittedAt:
          json['submittedAt'] != null ? DateTime.parse(json['submittedAt'] as String) : null,
    );
  }
}

class AdminOverviewCompanyPending {
  final int id;
  final String name;
  final String? program;
  final String? section;
  final String? companyName;

  const AdminOverviewCompanyPending({
    required this.id,
    required this.name,
    this.program,
    this.section,
    this.companyName,
  });

  factory AdminOverviewCompanyPending.fromJson(Map<String, dynamic> json) {
    return AdminOverviewCompanyPending(
      id: json['id'] as int,
      name: json['name'] as String,
      program: json['program'] as String?,
      section: json['section'] as String?,
      companyName: json['companyName'] as String?,
    );
  }
}

class AdminOverviewRiskStudent {
  final int id;
  final String name;

  const AdminOverviewRiskStudent({required this.id, required this.name});

  factory AdminOverviewRiskStudent.fromJson(Map<String, dynamic> json) {
    return AdminOverviewRiskStudent(id: json['id'] as int, name: json['name'] as String);
  }
}

class AdminOverview {
  final String academicYear;
  final int totalStudents;
  final int totalInstructors;

  final int completedCount;
  final int ongoingCount;
  final int notStartedCount;

  final int weeksApproved;
  final int weeksAwaitingReview;
  final int weeksReturned;
  final int studentsAwaitingReview;

  final double totalHoursRendered;
  final double totalHoursRequired;
  final double overallCompletionPercent;

  final List<AdminOverviewAccountPreparing> accountsPreparing;
  final List<AdminOverviewDocumentPending> documentsAwaitingReview;
  final List<AdminOverviewCompanyPending> companyVerification;

  final List<AdminOverviewRiskStudent> belowHalfHours;
  final List<AdminOverviewRiskStudent> noRecentSubmission;
  final List<AdminOverviewRiskStudent> behindSchedule;

  final List<AdminOverviewStudent> studentList;
  final List<AdminOverviewWeeklyEntry> weeklyList;

  const AdminOverview({
    required this.academicYear,
    required this.totalStudents,
    required this.totalInstructors,
    required this.completedCount,
    required this.ongoingCount,
    required this.notStartedCount,
    required this.weeksApproved,
    required this.weeksAwaitingReview,
    required this.weeksReturned,
    required this.studentsAwaitingReview,
    required this.totalHoursRendered,
    required this.totalHoursRequired,
    required this.overallCompletionPercent,
    required this.accountsPreparing,
    required this.documentsAwaitingReview,
    required this.companyVerification,
    required this.belowHalfHours,
    required this.noRecentSubmission,
    required this.behindSchedule,
    required this.studentList,
    required this.weeklyList,
  });

  int get pendingTasksTotal =>
      accountsPreparing.length +
      documentsAwaitingReview.length +
      companyVerification.length;

  /// The union of every at-risk student, each tagged with which
  /// condition(s) it met -- a student can appear under more than one
  /// reason.
  List<({int id, String name, List<String> reasons})> get atRiskUnion {
    final byId = <int, ({int id, String name, List<String> reasons})>{};
    void addAll(List<AdminOverviewRiskStudent> students, String reason) {
      for (final s in students) {
        final existing = byId[s.id];
        if (existing == null) {
          byId[s.id] = (id: s.id, name: s.name, reasons: [reason]);
        } else {
          byId[s.id] = (id: s.id, name: s.name, reasons: [...existing.reasons, reason]);
        }
      }
    }

    addAll(belowHalfHours, 'Below 50% of required hours');
    addAll(noRecentSubmission, 'No DTR & AR in the last 2 weeks');
    addAll(behindSchedule, 'Behind schedule');
    final list = byId.values.toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  factory AdminOverview.fromJson(Map<String, dynamic> json) {
    final completion = json['completion'] as Map<String, dynamic>;
    final weekly = json['weeklyReports'] as Map<String, dynamic>;
    final hours = json['hours'] as Map<String, dynamic>;
    final pendingTasks = json['pendingTasks'] as Map<String, dynamic>;
    final atRisk = json['atRisk'] as Map<String, dynamic>;

    List<T> parseList<T>(List<dynamic> raw, T Function(Map<String, dynamic>) fromJson) =>
        raw.map((e) => fromJson(e as Map<String, dynamic>)).toList();

    return AdminOverview(
      academicYear: json['academicYear'] as String,
      totalStudents: json['totalStudents'] as int,
      totalInstructors: json['totalInstructors'] as int,
      completedCount: completion['completed'] as int,
      ongoingCount: completion['ongoing'] as int,
      notStartedCount: completion['notStarted'] as int,
      weeksApproved: weekly['approved'] as int,
      weeksAwaitingReview: weekly['awaitingReview'] as int,
      weeksReturned: weekly['returned'] as int,
      studentsAwaitingReview: weekly['studentsAwaitingReview'] as int,
      totalHoursRendered: (hours['totalRendered'] as num).toDouble(),
      totalHoursRequired: (hours['totalRequired'] as num).toDouble(),
      overallCompletionPercent: (hours['overallCompletionPercent'] as num).toDouble(),
      accountsPreparing: parseList(
        pendingTasks['accountsPreparing'] as List<dynamic>,
        AdminOverviewAccountPreparing.fromJson,
      ),
      documentsAwaitingReview: parseList(
        pendingTasks['documentsAwaitingReview'] as List<dynamic>,
        AdminOverviewDocumentPending.fromJson,
      ),
      companyVerification: parseList(
        pendingTasks['companyVerification'] as List<dynamic>,
        AdminOverviewCompanyPending.fromJson,
      ),
      belowHalfHours: parseList(
        atRisk['belowHalfHours'] as List<dynamic>,
        AdminOverviewRiskStudent.fromJson,
      ),
      noRecentSubmission: parseList(
        atRisk['noRecentSubmission'] as List<dynamic>,
        AdminOverviewRiskStudent.fromJson,
      ),
      behindSchedule: parseList(
        atRisk['behindSchedule'] as List<dynamic>,
        AdminOverviewRiskStudent.fromJson,
      ),
      studentList: parseList(json['studentList'] as List<dynamic>, AdminOverviewStudent.fromJson),
      weeklyList: parseList(
        json['weeklyList'] as List<dynamic>,
        AdminOverviewWeeklyEntry.fromJson,
      ),
    );
  }
}
