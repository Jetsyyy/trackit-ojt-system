const crypto = require('crypto');

// One-time password an instructor hands to a student after approving a
// reset, e.g. "Trk-7KQ2-x9fA!". It always meets the password rules
// (upper, lower, number, symbol, 8+ characters); the student must replace
// it at the next sign-in. Look-alike characters (0/O, 1/l/I) are left out.
const UPPER = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
const LOWER = 'abcdefghijkmnpqrstuvwxyz';
const DIGITS = '23456789';
const MIXED = UPPER + LOWER + DIGITS;

const pick = (set) => set[crypto.randomInt(set.length)];

function temporaryPassword() {
  const block = (n) => Array.from({ length: n }, () => pick(MIXED)).join('');
  return `Trk-${pick(DIGITS)}${pick(UPPER)}${block(2)}-${pick(LOWER)}${pick(DIGITS)}${block(2)}!`;
}

module.exports = { temporaryPassword };
