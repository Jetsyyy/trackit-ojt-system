import 'hte_company_contact.dart';

/// A student placed at an HTE in the selected academic year (System
/// Revisions item 17).
class HtePlacement {
  final int id;
  final String name;
  final String program;
  final String section;

  /// Department at the company the student is assigned to.
  final String? department;
  final String? supervisor;
  final String? contactNumber;
  final double completedHours;
  final double requiredHours;

  const HtePlacement({
    required this.id,
    required this.name,
    required this.program,
    required this.section,
    this.department,
    this.supervisor,
    this.contactNumber,
    required this.completedHours,
    required this.requiredHours,
  });

  factory HtePlacement.fromJson(Map<String, dynamic> json) {
    return HtePlacement(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      program: json['program'] as String? ?? '',
      section: json['section'] as String? ?? '',
      department: json['department'] as String?,
      supervisor: json['supervisor'] as String?,
      contactNumber: json['contactNumber'] as String?,
      completedHours: (json['completedHours'] as num? ?? 0).toDouble(),
      requiredHours: (json['requiredHours'] as num? ?? 0).toDouble(),
    );
  }
}

/// An HTE (Host Training Establishment) in the directory. Students read
/// the admin-reviewed entries; the Admin also sees entries added
/// automatically from students' company details ([addedByStudent]) and
/// the students placed at each company.
class HteCompany {
  final int id;
  final String name;
  final String industry;
  final String location;

  /// Province or region derived from [location] (e.g. "Metro Manila",
  /// "Laguna"); empty when not provided by the server.
  final String region;
  final String address;

  /// Empty when not provided (student-added entries have none).
  final String email;
  final String? website;
  final DateTime? dateAccredited;
  final List<HteCompanyContact> contacts;

  /// 'admin' or 'student' (added from a student's company details).
  final String source;
  final List<HtePlacement> students;

  const HteCompany({
    required this.id,
    required this.name,
    required this.industry,
    required this.location,
    this.region = '',
    required this.address,
    required this.email,
    this.website,
    this.dateAccredited,
    this.contacts = const [],
    this.source = 'admin',
    this.students = const [],
  });

  bool get addedByStudent => source == 'student';

  factory HteCompany.fromJson(Map<String, dynamic> json) {
    final contactsJson = json['contacts'] as List<dynamic>? ?? const [];
    final studentsJson = json['students'] as List<dynamic>? ?? const [];
    return HteCompany(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      industry: json['industry'] as String? ?? '',
      location: json['location'] as String? ?? '',
      region: json['region'] as String? ?? '',
      address: json['address'] as String? ?? '',
      email: json['email'] as String? ?? '',
      website: json['website'] as String?,
      dateAccredited: json['dateAccredited'] != null
          ? DateTime.parse(json['dateAccredited'] as String)
          : null,
      contacts: contactsJson
          .map((c) => HteCompanyContact.fromJson(c as Map<String, dynamic>))
          .toList(),
      source: json['source'] as String? ?? 'admin',
      students: studentsJson
          .map((s) => HtePlacement.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}
