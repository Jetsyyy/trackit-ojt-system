import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/session_marker.dart';

/// Which kind of account is currently logged in. Needed because
/// AuthService (student) and InstructorAuthService keep separate tokens
/// under separate storage keys -- this says which one AuthGate should
/// trust on app restart.
enum SessionRole { student, instructor, admin }

class SessionRoleStore {
  static const _key = 'trackit_active_role';
  static const _rememberKey = 'trackit_remember_me';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> save(SessionRole role) async {
    setSessionMarker();
    await _storage.write(key: _key, value: role.name);
  }

  /// "Remember me" on the login screen. When false, the stored login is
  /// dropped once the browser tab / app is closed (see session_marker.dart).
  Future<void> setRemember(bool remember) =>
      _storage.write(key: _rememberKey, value: remember ? '1' : '0');

  /// The stored role, or null when nobody is logged in -- or when the user
  /// logged in without "Remember me" and this is a new browser/app session
  /// ([expired] is then true so the caller can clear the old tokens).
  Future<({SessionRole? role, bool expired})> load() async {
    final value = await _storage.read(key: _key);
    SessionRole? role;
    for (final r in SessionRole.values) {
      if (r.name == value) role = r;
    }
    if (role == null) return (role: null, expired: false);
    final remember = await _storage.read(key: _rememberKey);
    if (remember == '0' && !hasSessionMarker()) {
      await clear();
      return (role: null, expired: true);
    }
    setSessionMarker();
    return (role: role, expired: false);
  }

  Future<void> clear() => _storage.delete(key: _key);
}
