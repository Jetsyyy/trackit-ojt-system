// Fresh start for the revised system: removes every account and record
// from the old system while keeping the setup the Admin prepared.
//
// Deleted: students, instructors, sections, registration codes, requirement
// and weekly DTR/AR submissions, announcements, notifications, attendance
// data, login history and account activity -- plus their uploaded files in
// Vercel Blob.
// Kept: the Admin account(s), app settings, help articles, the HTE
// Directory (companies + contacts) and the official requirements list with
// its templates.
//
//   node scripts/reset_old_data.js           # dry run: shows what would go
//   node scripts/reset_old_data.js --apply   # backs up, then deletes
//
// The backup (every deleted row, as JSON) is written to
// trackit-ojt-system/backups/ before anything is deleted.
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '..', '.env'), quiet: true });
const fs = require('fs');
const pool = require('../db');

const APPLY = process.argv.includes('--apply');

const CLEAR = [
  'account_activity',
  'activity_report_attachments',
  'activity_reports',
  'admin_announcements',
  'admin_login_history',
  'admin_password_otps',
  'advisers',
  'announcement_targets',
  'announcements',
  'attendance_corrections',
  'attendance_records',
  'custom_requirement_targets',
  'custom_requirements',
  'hte_archives',
  'instructor_classes',
  'instructor_notifications',
  'instructor_registration_codes',
  'login_history',
  'notification_preferences',
  'notifications',
  'profile_photo_uploads',
  'student_custom_requirement_submissions',
  'student_profiles',
  'student_requirement_submissions',
  'students',
  'supervisors',
  'user_sessions',
];

const isBlobUrl = (v) => typeof v === 'string' && /^https:\/\/[^/]+\.blob\.vercel-storage\.com\//.test(v);

(async () => {
  try {
    const existing = new Set(
      (
        await pool.query(
          `SELECT table_name FROM information_schema.tables
           WHERE table_schema = 'public' AND table_type = 'BASE TABLE'`,
        )
      ).rows.map((r) => r.table_name),
    );
    const tables = CLEAR.filter((t) => existing.has(t));

    const backup = { createdAt: new Date().toISOString(), tables: {} };
    const blobUrls = new Set();
    let total = 0;
    for (const t of tables) {
      const rows = (await pool.query(`SELECT * FROM "${t}"`)).rows;
      backup.tables[t] = rows;
      total += rows.length;
      for (const row of rows) for (const v of Object.values(row)) if (isBlobUrl(v)) blobUrls.add(v);
      console.log(`${String(rows.length).padStart(5)}  ${t}`);
    }
    // Never delete a file the kept data still uses (templates, admin photo).
    const keptUrls = new Set();
    for (const [t, cols] of Object.entries({
      ojt_requirement_templates: ['template_url'],
      admins: ['avatar_url'],
    })) {
      for (const c of cols) {
        const rows = (await pool.query(`SELECT "${c}" AS u FROM "${t}"`).catch(() => ({ rows: [] }))).rows;
        rows.forEach((r) => keptUrls.add(r.u));
      }
    }
    const toDelete = [...blobUrls].filter((u) => !keptUrls.has(u));
    console.log(`${total} rows in ${tables.length} tables; ${toDelete.length} uploaded file(s) in Blob.`);

    if (!APPLY) {
      console.log('Dry run: nothing changed. Run with --apply to back up and delete.');
      return;
    }

    const dir = path.join(__dirname, '..', '..', '..', 'backups');
    fs.mkdirSync(dir, { recursive: true });
    const file = path.join(dir, `trackit-old-data-${backup.createdAt.replace(/[:.]/g, '-')}.json`);
    fs.writeFileSync(file, JSON.stringify(backup, null, 1));
    console.log('Backup written:', file);

    if (toDelete.length) {
      const { del } = require('@vercel/blob');
      for (let i = 0; i < toDelete.length; i += 50) await del(toDelete.slice(i, i + 50));
      console.log('Deleted', toDelete.length, 'uploaded file(s) from Blob.');
    }

    // One statement so tables that point at each other clear together; no
    // CASCADE, so it fails instead of touching any table not listed here.
    await pool.query(`TRUNCATE ${tables.map((t) => `"${t}"`).join(', ')} RESTART IDENTITY`);
    console.log('Cleared', tables.length, 'tables.');
  } catch (error) {
    console.error('Reset failed (nothing was cleared if this happened before "Cleared"):', error.message);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
})();
