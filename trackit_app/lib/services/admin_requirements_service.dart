import 'api_client.dart';

/// One Official Requirement as the Admin manages it.
class AdminRequirement {
  final int id;
  final int phaseId;
  final String name;
  final String description;

  /// Office the student gets it from ('Clinic', 'Registrar', ...). When
  /// set, students get no template download (System Revisions item 6).
  final String? issuedBy;
  final String? templateUrl;
  final String? templateName;

  /// How many student submissions already use it; a used requirement
  /// can't be deleted.
  final int submissionCount;
  final int copiesRequired;
  final DateTime? updatedAt;
  final String? updatedByName;
  final int? templateSize;
  final DateTime? templateUploadedAt;

  const AdminRequirement({
    required this.id,
    required this.phaseId,
    required this.name,
    required this.description,
    this.issuedBy,
    this.templateUrl,
    this.templateName,
    required this.submissionCount,
    this.copiesRequired = 1,
    this.updatedAt,
    this.updatedByName,
    this.templateSize,
    this.templateUploadedAt,
  });

  factory AdminRequirement.fromJson(Map<String, dynamic> json) {
    return AdminRequirement(
      id: json['id'] as int,
      phaseId: json['phaseId'] as int,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      issuedBy: json['issuedBy'] as String?,
      templateUrl: json['templateUrl'] as String?,
      templateName: json['templateName'] as String?,
      submissionCount: json['submissionCount'] as int? ?? 0,
      copiesRequired: json['copiesRequired'] as int? ?? 1,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : null,
      updatedByName: json['updatedByName'] as String?,
      templateSize: json['templateSize'] as int?,
      templateUploadedAt:
          json['templateUploadedAt'] != null ? DateTime.parse(json['templateUploadedAt'] as String) : null,
    );
  }
}

class AdminRequirementPhase {
  final int id;
  final int order;
  final String title;
  final List<AdminRequirement> requirements;

  const AdminRequirementPhase({
    required this.id,
    required this.order,
    required this.title,
    required this.requirements,
  });

  factory AdminRequirementPhase.fromJson(Map<String, dynamic> json) {
    return AdminRequirementPhase(
      id: json['id'] as int,
      order: json['order'] as int,
      title: json['title'] as String,
      requirements: (json['requirements'] as List<dynamic>)
          .map((r) => AdminRequirement.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Official Requirements catalog, managed by the Admin only (System
/// Revisions item 15).
class AdminRequirementsService {
  final ApiClient client;

  AdminRequirementsService(this.client);

  Future<List<AdminRequirementPhase>> getPhases() async {
    final response = await client.get('/api/admin/requirements');
    return (response['phases'] as List<dynamic>)
        .map((p) => AdminRequirementPhase.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  /// Returns the new requirement's id.
  Future<int?> create({
    required int phaseId,
    required String name,
    required String description,
    String? issuedBy,
    int copiesRequired = 1,
  }) async {
    final response = await client.post(
      '/api/admin/requirements',
      body: {
        'phaseId': phaseId,
        'name': name,
        'description': description,
        'issuedBy': issuedBy,
        'copiesRequired': copiesRequired,
      },
    );
    return (response['requirement'] as Map<String, dynamic>?)?['id'] as int?;
  }

  Future<void> update(
    int id, {
    required String name,
    required String description,
    String? issuedBy,
    int? copiesRequired,
    int? phaseId,
  }) async {
    await client.patch(
      '/api/admin/requirements/$id',
      body: {
        'name': name,
        'description': description,
        'issuedBy': issuedBy ?? '',
        if (copiesRequired != null) 'copiesRequired': copiesRequired,
        if (phaseId != null) 'phaseId': phaseId,
      },
    );
  }

  Future<void> move(int id, {required bool up}) async {
    await client.patch('/api/admin/requirements/$id/move', body: {'direction': up ? 'up' : 'down'});
  }

  Future<void> delete(int id) async {
    await client.delete('/api/admin/requirements/$id');
  }

  Future<void> uploadTemplate(
    int id, {
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) async {
    await client.postMultipart(
      '/api/admin/requirements/$id/template',
      fieldName: 'template',
      fileBytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );
  }

  Future<void> removeTemplate(int id) async {
    await client.delete('/api/admin/requirements/$id/template');
  }
}
