const pool = require('../db');

// Account events shown in Profile > Recent Account Activity. Recording is
// best effort: a failure here must never break the login or the change
// that triggered it.

// "Chrome on Windows" from a User-Agent header.
function describeDevice(userAgent) {
  const ua = (userAgent || '').toString();
  if (!ua) return null;
  let browser = 'Browser';
  if (/Edg\//.test(ua)) browser = 'Edge';
  else if (/OPR\/|Opera/.test(ua)) browser = 'Opera';
  else if (/Firefox\//.test(ua)) browser = 'Firefox';
  else if (/Chrome\//.test(ua)) browser = 'Chrome';
  else if (/Safari\//.test(ua)) browser = 'Safari';
  else if (/Dart\//.test(ua)) browser = 'TrackIT app';
  let os = '';
  if (/Android/.test(ua)) os = 'Android';
  else if (/iPhone|iPad|iOS/.test(ua)) os = 'iOS';
  else if (/Windows/.test(ua)) os = 'Windows';
  else if (/Mac OS X|Macintosh/.test(ua)) os = 'macOS';
  else if (/Linux/.test(ua)) os = 'Linux';
  return os ? `${browser} on ${os}` : browser;
}

async function recordActivity(role, accountId, action, detail = null) {
  try {
    await pool.query(
      'INSERT INTO account_activity (account_role, account_id, action, detail) VALUES ($1, $2, $3, $4)',
      [role, accountId, action, detail],
    );
  } catch (error) {
    console.error('Account activity not recorded:', error.message);
  }
}

async function recentActivity(role, accountId, limit = 6) {
  try {
    const result = await pool.query(
      `SELECT action, detail, created_at FROM account_activity
       WHERE account_role = $1 AND account_id = $2
       ORDER BY created_at DESC LIMIT $3`,
      [role, accountId, limit],
    );
    return result.rows.map((r) => ({ action: r.action, detail: r.detail, at: r.created_at }));
  } catch (error) {
    console.error('Account activity not loaded:', error.message);
    return [];
  }
}

module.exports = { describeDevice, recordActivity, recentActivity };
