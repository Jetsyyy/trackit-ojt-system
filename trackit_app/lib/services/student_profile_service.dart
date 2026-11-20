import '../models/company_details.dart';
import '../models/login_history_entry.dart';
import '../models/staff_contact.dart';
import '../models/student_profile.dart';
import 'api_client.dart';

abstract class StudentProfileService {
  Future<StudentProfile> getProfile();

  Future<StudentProfile> uploadAvatar({
    required List<int> bytes,
    required String fileName,
    required String contentType,
  });

  /// Saves editable profile fields. [fullName] is subject to a 14-day
  /// cooldown enforced server-side -- throws [ApiException] (403) if a
  /// change is attempted too soon; omit it to leave the name untouched
  /// (never triggers the cooldown).
  Future<StudentProfile> updateProfile({
    String? fullName,
    String? mobileNumber,
  });

  Future<List<LoginHistoryEntry>> getLoginHistory();

  /// Saves the student's self-reported company details (Confirm Company
  /// Details step). Also sets [StudentProfile.supervisor], since that form
  /// collects the supervisor's name and contact number together with the
  /// company info.
  Future<StudentProfile> submitCompanyDetails(CompanyDetails details);

  /// The supervisor can change after deployment, so it stays editable
  /// after the one-time company entry (System Revisions item 5).
  Future<StudentProfile> updateSupervisor({
    required String supervisorName,
    required String contactNumber,
    String? department,
  });

  /// Matching companies already saved in the system, for suggestions
  /// while typing the company name (System Revisions item 8).
  Future<List<CompanySuggestion>> suggestCompanies(String query);
}

class CompanySuggestion {
  final String name;
  final String? address;
  final String? industry;

  /// 'directory' (Admin's HTE Directory) or 'students' (entered before).
  final String source;

  const CompanySuggestion({
    required this.name,
    this.address,
    this.industry,
    required this.source,
  });

  factory CompanySuggestion.fromJson(Map<String, dynamic> json) {
    return CompanySuggestion(
      name: json['name'] as String,
      address: json['address'] as String?,
      industry: json['industry'] as String?,
      source: json['source'] as String? ?? 'students',
    );
  }
}

class MockStudentProfileService implements StudentProfileService {
  StudentProfile _profile = const StudentProfile(
    fullName: 'Way-Ar Sangngern',
    studentNumber: '21-00456',
    course: 'BS Information Technology',
    yearLevel: '4th Year',
    section: 'Section F',
    school: 'Dalubhasaan ng Lungsod ng San Pablo',
    email: 'wayar.sangngern@dlsp.edu.ph',
    mobileNumber: '+63 917 123 4567',
    adviser: StaffContact(
      name: 'Gawin Caskey',
      role: 'OJT Adviser',
      email: 'gawin.caskey@dlsp.edu.ph',
      phone: '+63 917 555 0101',
    ),
    // Null until the student completes the Confirm Company Details step.
    company: null,
    supervisor: null,
  );

  @override
  Future<StudentProfile> getProfile() async => _profile;

  @override
  Future<StudentProfile> uploadAvatar({
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) async {
    _profile = _profile.copyWith(avatarUrl: 'mock://avatar');
    return _profile;
  }

  @override
  Future<StudentProfile> updateProfile({String? fullName, String? mobileNumber}) async {
    return _profile;
  }

  @override
  Future<List<LoginHistoryEntry>> getLoginHistory() async => [];

  @override
  Future<StudentProfile> submitCompanyDetails(CompanyDetails details) async {
    _profile = _profile.withCompanyDetails(details);
    return _profile;
  }

  @override
  Future<StudentProfile> updateSupervisor({
    required String supervisorName,
    required String contactNumber,
    String? department,
  }) async => _profile;

  @override
  Future<List<CompanySuggestion>> suggestCompanies(String query) async => const [];
}

class HttpStudentProfileService implements StudentProfileService {
  final ApiClient client;

  HttpStudentProfileService(this.client);

  @override
  Future<StudentProfile> getProfile() async {
    final response = await client.get('/api/profile');
    return StudentProfile.fromJson(response['profile'] as Map<String, dynamic>);
  }

  @override
  Future<StudentProfile> uploadAvatar({
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) async {
    await client.postMultipart(
      '/api/profile/avatar',
      fieldName: 'avatar',
      fileBytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );
    return getProfile();
  }

  @override
  Future<StudentProfile> updateProfile({
    String? fullName,
    String? mobileNumber,
  }) async {
    await client.patch(
      '/api/profile',
      body: {
        if (fullName != null) 'fullName': fullName,
        if (mobileNumber != null) 'phone': mobileNumber,
      },
    );
    return getProfile();
  }

  @override
  Future<List<LoginHistoryEntry>> getLoginHistory() async {
    final response = await client.get('/api/profile/login-history');
    final rows = response['sessions'] as List<dynamic>;
    return rows
        .map((row) => LoginHistoryEntry.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<StudentProfile> submitCompanyDetails(CompanyDetails details) async {
    await client.post('/api/profile/company', body: details.toJson());
    return getProfile();
  }

  @override
  Future<StudentProfile> updateSupervisor({
    required String supervisorName,
    required String contactNumber,
    String? department,
  }) async {
    await client.patch(
      '/api/profile/company/supervisor',
      body: {
        'supervisorName': supervisorName,
        'contactNumber': contactNumber,
        'department': ?department,
      },
    );
    return getProfile();
  }

  @override
  Future<List<CompanySuggestion>> suggestCompanies(String query) async {
    final uri = Uri(path: '/api/hte-companies/suggest', queryParameters: {'q': query});
    final response = await client.get(uri.toString());
    return (response['suggestions'] as List<dynamic>)
        .map((row) => CompanySuggestion.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
