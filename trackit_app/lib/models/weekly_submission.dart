/// Status of one OJT week's DTR + AR submission.
/// missing: nothing submitted yet. submitted: waiting for the instructor.
/// approved: hours credited, week locked. rejected: returned with remarks,
/// can be resubmitted.
enum WeeklySubmissionStatus { missing, submitted, approved, rejected }

WeeklySubmissionStatus weeklySubmissionStatusFromDb(String? value) {
  switch (value) {
    case 'submitted':
      return WeeklySubmissionStatus.submitted;
    case 'approved':
      return WeeklySubmissionStatus.approved;
    case 'rejected':
      return WeeklySubmissionStatus.rejected;
    default:
      return WeeklySubmissionStatus.missing;
  }
}

/// An uploaded DTR or AR file. [url] is server-relative
/// (resolve it with ApiClient.resolveUrl before opening).
class WeeklyFile {
  final int id;
  final String fileName;
  final String? url;

  const WeeklyFile({required this.id, required this.fileName, this.url});

  factory WeeklyFile.fromJson(Map<String, dynamic> json) {
    return WeeklyFile(
      id: json['id'] as int,
      fileName: json['fileName'] as String,
      url: json['url'] as String?,
    );
  }
}

/// One OJT week: the student uploads the week's DTR (Daily Time Record)
/// and AR (Accomplishment Report) and claims the DTR's total hours. The
/// hours count toward the credited total only after instructor approval.
class WeeklySubmission {
  final int weekNumber;
  final DateTime weekStartDate;
  final DateTime weekEndDate;
  final WeeklySubmissionStatus status;
  final double? claimedHours;
  final String? description;
  final List<WeeklyFile> dtrFiles;
  final List<WeeklyFile> arFiles;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? remarks;

  const WeeklySubmission({
    required this.weekNumber,
    required this.weekStartDate,
    required this.weekEndDate,
    required this.status,
    this.claimedHours,
    this.description,
    this.dtrFiles = const [],
    this.arFiles = const [],
    this.submittedAt,
    this.reviewedAt,
    this.remarks,
  });

  /// Missing and rejected weeks are the ones the student still has to act on.
  bool get canSubmit =>
      status == WeeklySubmissionStatus.missing ||
      status == WeeklySubmissionStatus.rejected;

  static List<WeeklyFile> _files(dynamic list) => (list as List<dynamic>? ?? const [])
      .map((f) => WeeklyFile.fromJson(f as Map<String, dynamic>))
      .toList();

  static DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.parse(value as String).toLocal();

  factory WeeklySubmission.fromJson(Map<String, dynamic> json) {
    return WeeklySubmission(
      weekNumber: json['weekNumber'] as int,
      // Plain 'YYYY-MM-DD' dates -- parsed as calendar days, no timezone.
      weekStartDate: DateTime.parse(json['weekStartDate'] as String),
      weekEndDate: DateTime.parse(json['weekEndDate'] as String),
      status: weeklySubmissionStatusFromDb(json['status'] as String?),
      claimedHours: (json['claimedHours'] as num?)?.toDouble(),
      description: json['description'] as String?,
      dtrFiles: _files(json['dtrFiles']),
      arFiles: _files(json['arFiles']),
      submittedAt: _date(json['submittedAt']),
      reviewedAt: _date(json['reviewedAt']),
      remarks: json['remarks'] as String?,
    );
  }
}

/// Totals across all of a student's weeks, computed server-side.
class WeeklySummary {
  final DateTime? ojtStartDate;
  final double requiredHours;
  final double completedHours;
  final double pendingHours;
  final bool isComplete;
  final int totalWeeks;
  final int approvedWeeks;
  final int pendingReviewWeeks;
  final int rejectedWeeks;
  final int missingWeeks;

  const WeeklySummary({
    this.ojtStartDate,
    required this.requiredHours,
    required this.completedHours,
    required this.pendingHours,
    required this.isComplete,
    required this.totalWeeks,
    required this.approvedWeeks,
    required this.pendingReviewWeeks,
    required this.rejectedWeeks,
    required this.missingWeeks,
  });

  int get needsActionWeeks => missingWeeks + rejectedWeeks;

  double get remainingHours =>
      (requiredHours - completedHours).clamp(0, double.infinity).toDouble();

  factory WeeklySummary.fromJson(Map<String, dynamic> json) {
    return WeeklySummary(
      ojtStartDate: json['ojtStartDate'] != null
          ? DateTime.parse(json['ojtStartDate'] as String)
          : null,
      requiredHours: (json['requiredHours'] as num).toDouble(),
      completedHours: (json['completedHours'] as num).toDouble(),
      pendingHours: (json['pendingHours'] as num).toDouble(),
      isComplete: json['isComplete'] as bool,
      totalWeeks: json['totalWeeks'] as int,
      approvedWeeks: json['approvedWeeks'] as int,
      pendingReviewWeeks: json['pendingReviewWeeks'] as int,
      rejectedWeeks: json['rejectedWeeks'] as int,
      missingWeeks: json['missingWeeks'] as int,
    );
  }
}

class WeeklySubmissionsData {
  final WeeklySummary summary;
  final List<WeeklySubmission> weeks;

  const WeeklySubmissionsData({required this.summary, required this.weeks});

  factory WeeklySubmissionsData.fromJson(Map<String, dynamic> json) {
    return WeeklySubmissionsData(
      summary: WeeklySummary.fromJson(json['summary'] as Map<String, dynamic>),
      weeks: (json['reports'] as List<dynamic>)
          .map((w) => WeeklySubmission.fromJson(w as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Formats hours without a trailing ".0" (12 -> "12", 12.5 -> "12.5").
String formatHours(double hours) {
  if (hours == hours.roundToDouble()) return hours.toInt().toString();
  return hours.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
}
