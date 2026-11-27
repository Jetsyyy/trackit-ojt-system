import 'ojt_requirement_doc.dart';

/// A requirement with a deadline, as the student sees it: either one the
/// OJT office scheduled for everyone (e.g. "Supervisor Evaluation Form",
/// 1st Semester) or an instructor's Additional Requirement for the section.
/// Same submit/status flow as the Official Requirements.
class CustomRequirement {
  final String id;
  final String name;
  final String description;
  final DateTime? deadline;
  final RequirementDocStatus status;
  final String? templateUrl;
  final String? templateName;
  final String? uploadedFileName;
  final String? uploadedFileUrl;
  final DateTime? submittedAt;
  final String? remarks;

  /// Posted by the OJT office for all students (vs. by the instructor).
  final bool fromOffice;

  /// e.g. "1st Semester", "Final".
  final String? period;

  /// Exact due date and time (OJT office requirements).
  final DateTime? dueAt;

  /// The upload came in after [dueAt].
  final bool isLate;

  const CustomRequirement({
    required this.id,
    required this.name,
    required this.description,
    this.deadline,
    required this.status,
    this.templateUrl,
    this.templateName,
    this.uploadedFileName,
    this.uploadedFileUrl,
    this.submittedAt,
    this.remarks,
    this.fromOffice = false,
    this.period,
    this.dueAt,
    this.isLate = false,
  });

  bool get isDone =>
      status == RequirementDocStatus.submitted || status == RequirementDocStatus.approved;

  factory CustomRequirement.fromJson(Map<String, dynamic> json) {
    return CustomRequirement(
      id: json['id'].toString(),
      name: json['name'] as String,
      description: json['description'] as String,
      deadline: json['deadline'] != null ? DateTime.parse(json['deadline'] as String) : null,
      status: RequirementDocStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => RequirementDocStatus.missing,
      ),
      templateUrl: json['templateUrl'] as String?,
      templateName: json['templateName'] as String?,
      uploadedFileName: json['uploadedFileName'] as String?,
      uploadedFileUrl: json['uploadedFileUrl'] as String?,
      submittedAt: json['submittedAt'] != null
          ? DateTime.parse(json['submittedAt'] as String)
          : null,
      remarks: json['remarks'] as String?,
      fromOffice: json['fromOffice'] as bool? ?? false,
      period: json['period'] as String?,
      dueAt: json['dueAt'] != null ? DateTime.parse(json['dueAt'] as String).toLocal() : null,
      isLate: json['isLate'] as bool? ?? false,
    );
  }

  /// Adapts this into the shape [RequirementDocTile] already knows how to
  /// render, so Additional Requirements reuses the same tile as Official
  /// Requirements instead of a near-duplicate widget.
  OjtRequirementDoc toDoc() {
    return OjtRequirementDoc(
      id: id,
      name: name,
      description: description,
      status: status,
      deadline: deadline,
      hasTemplate: templateUrl != null,
      templateUrl: templateUrl,
      templateName: templateName,
      uploadedFileName: uploadedFileName,
      uploadedFileUrl: uploadedFileUrl,
      submittedAt: submittedAt,
      remarks: remarks,
    );
  }
}
