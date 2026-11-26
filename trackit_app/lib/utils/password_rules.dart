/// Password rules for every account type (System Revision 5: password
/// guide). The server enforces the same list (server/utils/passwordPolicy.js);
/// keep the two in step.
class PasswordRule {
  final String label;
  final bool Function(String password) test;

  const PasswordRule(this.label, this.test);
}

final List<PasswordRule> passwordRules = [
  PasswordRule('At least 8 characters', (p) => p.length >= 8),
  PasswordRule('An uppercase letter (A–Z)', (p) => RegExp(r'[A-Z]').hasMatch(p)),
  PasswordRule('A lowercase letter (a–z)', (p) => RegExp(r'[a-z]').hasMatch(p)),
  PasswordRule('A number (0–9)', (p) => RegExp(r'[0-9]').hasMatch(p)),
  PasswordRule('A symbol (e.g. ! @ # \$ %)', (p) => RegExp(r'[^A-Za-z0-9\s]').hasMatch(p)),
];

/// Form validator for a new password: null when every rule is met.
String? newPasswordError(String? value) {
  final p = value ?? '';
  if (p.isEmpty) return 'Enter a password';
  if (RegExp(r'\s').hasMatch(p)) return 'Password must not contain spaces';
  final missing = passwordRules.where((r) => !r.test(p)).length;
  if (missing > 0) return 'Missing some requirements below';
  return null;
}
