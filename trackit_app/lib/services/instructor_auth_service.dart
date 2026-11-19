import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';

class InstructorAuthResult {
  final String token;
  final Map<String, dynamic> instructor;

  const InstructorAuthResult({required this.token, required this.instructor});
}

/// Either a logged-in session ([auth]) or an account request now waiting
/// for the Admin ([pendingMessage]).
class InstructorRegisterResult {
  final InstructorAuthResult? auth;
  final String? pendingMessage;

  const InstructorRegisterResult({this.auth, this.pendingMessage});

  bool get isPending => auth == null;
}

class InstructorAuthService {
  final ApiClient client;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const _tokenKey = 'trackit_instructor_auth_token';

  InstructorAuthService(this.client);

  /// Loads a previously stored token (if any) and primes [client] with it.
  Future<String?> loadStoredToken() async {
    final token = await _storage.read(key: _tokenKey);
    client.setToken(token);
    return token;
  }

  /// Two kinds of code work here:
  /// - An Instructor Registration Code (INS-...) the Admin generated: the
  ///   instructor sends their own details, and the account waits for the
  ///   Admin's approval and section assignment ([InstructorRegisterResult.pendingMessage]).
  /// - The activation code of an account the Admin already created
  ///   (FAC-...): only a password is needed and it logs in right away.
  Future<InstructorRegisterResult> register({
    required String activationCode,
    required String password,
    String? name,
    String? email,
    String? phone,
    String? instructorNumber,
  }) async {
    final response = await client.post(
      '/api/instructor-auth/register',
      body: {
        'activationCode': activationCode,
        'password': password,
        'name': ?name,
        'email': ?email,
        'phone': ?phone,
        'instructorNumber': ?instructorNumber,
      },
    );
    if (response['pending'] == true) {
      return InstructorRegisterResult(pendingMessage: response['message'] as String?);
    }
    return InstructorRegisterResult(auth: await _persistAuthResponse(response));
  }

  /// True for an Admin-generated Instructor Registration Code, which
  /// needs the instructor's own details.
  static bool isRegistrationCode(String code) =>
      code.trim().toUpperCase().startsWith('INS-');

  Future<InstructorAuthResult> login({
    required String email,
    required String password,
  }) async {
    final response = await client.post(
      '/api/instructor-auth/login',
      body: {'email': email, 'password': password},
    );
    return _persistAuthResponse(response);
  }

  Future<InstructorAuthResult> _persistAuthResponse(Map<String, dynamic> response) async {
    final token = response['token'] as String;
    final instructor = response['instructor'] as Map<String, dynamic>;
    await _storage.write(key: _tokenKey, value: token);
    client.setToken(token);
    return InstructorAuthResult(token: token, instructor: instructor);
  }

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    client.setToken(null);
  }
}
