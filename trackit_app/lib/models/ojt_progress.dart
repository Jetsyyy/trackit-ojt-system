/// How the student's submitted weekly hours compare to the expected pace
/// for their OJT start date, computed server-side
/// (server/utils/progressStatus.js). [completed] takes priority once
/// approved hours reach the required total.
enum OjtProgressStatus { onTrack, behind, needsAttention, aheadOfSchedule, completed }

OjtProgressStatus ojtProgressStatusFromDb(String? value) {
  switch (value) {
    case 'behind':
      return OjtProgressStatus.behind;
    case 'needsAttention':
      return OjtProgressStatus.needsAttention;
    case 'aheadOfSchedule':
      return OjtProgressStatus.aheadOfSchedule;
    case 'completed':
      return OjtProgressStatus.completed;
    default:
      return OjtProgressStatus.onTrack;
  }
}

/// The student's OJT hours. [completedHours] are credited hours: only
/// weeks the instructor approved. [pendingHours] are claimed in weeks
/// still waiting for review and are never part of the credited total.
class OjtProgress {
  final double completedHours;
  final double totalHours;
  final double pendingHours;
  final int approvedWeeks;
  final double weeklyAverageHours;
  final OjtProgressStatus status;

  const OjtProgress({
    required this.completedHours,
    required this.totalHours,
    required this.pendingHours,
    required this.approvedWeeks,
    required this.weeklyAverageHours,
    required this.status,
  });

  factory OjtProgress.fromJson(Map<String, dynamic> json) {
    return OjtProgress(
      completedHours: (json['completedHours'] as num).toDouble(),
      totalHours: (json['totalHours'] as num).toDouble(),
      pendingHours: (json['pendingHours'] as num? ?? 0).toDouble(),
      approvedWeeks: (json['approvedWeeks'] as num? ?? 0).toInt(),
      weeklyAverageHours: (json['weeklyAverageHours'] as num? ?? 0).toDouble(),
      status: ojtProgressStatusFromDb(json['status'] as String?),
    );
  }

  double get remainingHours =>
      (totalHours - completedHours).clamp(0, double.infinity).toDouble();

  double get progressRatio {
    if (totalHours <= 0) return 0;
    return (completedHours / totalHours).clamp(0, 1).toDouble();
  }

  int get progressPercent => (progressRatio * 100).round();

  /// Weeks still needed at the student's approved weekly average, or null
  /// before any week has been approved (no pace to project from).
  int? get estimatedWeeksLeft {
    if (status == OjtProgressStatus.completed) return 0;
    if (weeklyAverageHours <= 0) return null;
    return (remainingHours / weeklyAverageHours).ceil();
  }
}
