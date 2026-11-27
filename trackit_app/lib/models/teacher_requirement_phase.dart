import 'ojt_requirement_phase.dart';
import 'teacher_requirement_document.dart';

/// A stage in the Official Requirements checklist, from the reviewing
/// instructor's side. Reuses [PhaseStatus] (locked/inProgress/completed)
/// since the same stage-locking rule applies for both roles.
class TeacherRequirementPhase {
  final String id;
  final int order;
  final String title;
  final String description;
  final PhaseStatus status;
  final List<TeacherRequirementDocument> documents;

  /// 'final_details' for Stage 4: the student's final company and
  /// supervisor information (no documents). [companyConfirmed] says whether
  /// they've submitted it.
  final String kind;
  final bool companyConfirmed;

  const TeacherRequirementPhase({
    required this.id,
    required this.order,
    required this.title,
    required this.description,
    required this.status,
    required this.documents,
    this.kind = 'documents',
    this.companyConfirmed = false,
  });

  bool get isFinalDetails => kind == 'final_details';

  /// What Stage 4 shows instead of documents.
  String get finalDetailsNote => companyConfirmed
      ? 'The student submitted their final company, address and supervisor details.'
      : 'Waiting for the student to submit their final company, address and supervisor details.';

  factory TeacherRequirementPhase.fromJson(Map<String, dynamic> json) {
    return TeacherRequirementPhase(
      id: json['id'].toString(),
      order: (json['order'] as num).toInt(),
      title: json['title'] as String,
      description: json['description'] as String,
      status: PhaseStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => PhaseStatus.locked,
      ),
      documents: (json['documents'] as List<dynamic>)
          .map((d) => TeacherRequirementDocument.fromJson(d as Map<String, dynamic>))
          .toList(),
      kind: json['kind'] as String? ?? 'documents',
      companyConfirmed: json['companyConfirmed'] as bool? ?? false,
    );
  }
}
