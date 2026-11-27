import '../models/hte_company.dart';
import '../models/hte_company_contact.dart';
import 'api_client.dart';
import '../widgets/admin/hte_merge_dialog.dart';

abstract class AdminHteCompaniesService implements HteMergeApi {
  Future<List<HteCompany>> getCompanies();

  Future<HteCompany> createCompany({
    required String name,
    required String industry,
    required String location,
    required String address,
    required String email,
    String? website,
    DateTime? dateAccredited,
    required List<HteCompanyContact> contacts,
  });

  Future<HteCompany> updateCompany({
    required int id,
    required String name,
    required String industry,
    required String location,
    required String address,
    required String email,
    String? website,
    DateTime? dateAccredited,
    required List<HteCompanyContact> contacts,
  });

  Future<void> deleteCompany(int id);

  /// HTE Directory report (System Revisions items 18, 22) as 'xlsx' or
  /// 'pdf'. [location] is a city or a region such as "Metro Manila".
  /// [type] 'info' leaves students out; [sections] like 'BSIT - 4A'.
  Future<RawFileResponse> downloadReport({
    required String format,
    String? location,
    String type = 'students',
    List<String> sections = const [],
  });
}

class HttpAdminHteCompaniesService implements AdminHteCompaniesService {
  final ApiClient client;

  HttpAdminHteCompaniesService(this.client);

  Map<String, dynamic> _body({
    required String name,
    required String industry,
    required String location,
    required String address,
    required String email,
    String? website,
    DateTime? dateAccredited,
    required List<HteCompanyContact> contacts,
  }) {
    return {
      'name': name,
      'industry': industry,
      'location': location,
      'address': address,
      'email': email,
      'website': website,
      'dateAccredited': dateAccredited?.toIso8601String().split('T').first,
      'contacts': contacts.map((c) => c.toJson()).toList(),
    };
  }

  @override
  Future<List<HteCompany>> getCompanies() async {
    final response = await client.get('/api/admin/hte-companies');
    final rows = response['companies'] as List<dynamic>;
    return rows.map((row) => HteCompany.fromJson(row as Map<String, dynamic>)).toList();
  }

  @override
  Future<HteCompany> createCompany({
    required String name,
    required String industry,
    required String location,
    required String address,
    required String email,
    String? website,
    DateTime? dateAccredited,
    required List<HteCompanyContact> contacts,
  }) async {
    final response = await client.post(
      '/api/admin/hte-companies',
      body: _body(
        name: name,
        industry: industry,
        location: location,
        address: address,
        email: email,
        website: website,
        dateAccredited: dateAccredited,
        contacts: contacts,
      ),
    );
    return HteCompany.fromJson(response['company'] as Map<String, dynamic>);
  }

  @override
  Future<HteCompany> updateCompany({
    required int id,
    required String name,
    required String industry,
    required String location,
    required String address,
    required String email,
    String? website,
    DateTime? dateAccredited,
    required List<HteCompanyContact> contacts,
  }) async {
    final response = await client.patch(
      '/api/admin/hte-companies/$id',
      body: _body(
        name: name,
        industry: industry,
        location: location,
        address: address,
        email: email,
        website: website,
        dateAccredited: dateAccredited,
        contacts: contacts,
      ),
    );
    return HteCompany.fromJson(response['company'] as Map<String, dynamic>);
  }

  @override
  Future<void> deleteCompany(int id) async {
    await client.delete('/api/admin/hte-companies/$id');
  }

  @override
  Future<List<HteDuplicateGroup>> getDuplicates() async {
    final response = await client.get('/api/admin/hte-companies/duplicates');
    return (response['groups'] as List<dynamic>)
        .map((g) => HteDuplicateGroup.fromJson(g as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<HteMergePreview> previewMerge({required int keepId, required List<int> mergeIds}) async {
    final response = await client.post(
      '/api/admin/hte-companies/$keepId/merge',
      body: {'mergeIds': mergeIds, 'dryRun': true},
    );
    final moving = response['moving'] as Map<String, dynamic>? ?? const {};
    return HteMergePreview(
      students: (moving['students'] as num?)?.toInt() ?? 0,
      reports: (moving['reports'] as num?)?.toInt() ?? 0,
      supervisors: (moving['supervisors'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<void> merge({required int keepId, required List<int> mergeIds}) async {
    await client.post('/api/admin/hte-companies/$keepId/merge', body: {'mergeIds': mergeIds});
  }

  @override
  Future<RawFileResponse> downloadReport({
    required String format,
    String? location,
    String type = 'students',
    List<String> sections = const [],
  }) {
    final uri = Uri(
      path: '/api/admin/hte-companies/report',
      queryParameters: {
        'format': format,
        'type': type,
        if (location != null && location.isNotEmpty) 'location': location,
        if (sections.isNotEmpty) 'sections': sections.join(','),
      },
    );
    return client.getBytes(uri.toString());
  }
}
