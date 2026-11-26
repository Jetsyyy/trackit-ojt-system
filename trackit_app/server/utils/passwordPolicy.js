// Password rules for every account type (System Revision 5: password
// guide). The app shows the same list while the user types
// (lib/utils/password_rules.dart); keep the two in step.
const RULES = [
  { label: 'at least 8 characters', test: (p) => p.length >= 8 },
  { label: 'an uppercase letter', test: (p) => /[A-Z]/.test(p) },
  { label: 'a lowercase letter', test: (p) => /[a-z]/.test(p) },
  { label: 'a number', test: (p) => /[0-9]/.test(p) },
  { label: 'a symbol (e.g. ! @ # $ %)', test: (p) => /[^A-Za-z0-9\s]/.test(p) },
];

/// null when the password is strong enough, otherwise a message listing
/// what it still needs.
function passwordProblem(password) {
  const p = (password || '').toString();
  if (/\s/.test(p)) return 'Password must not contain spaces.';
  const missing = RULES.filter((r) => !r.test(p)).map((r) => r.label);
  if (missing.length === 0) return null;
  return `Password needs ${missing.join(', ')}.`;
}

module.exports = { passwordProblem };
