// Full TrackIT backup to this computer: every database table (as JSON) and
// every uploaded file in Supabase Storage. Read-only: nothing online is
// changed.
//
//   cd trackit_app/server
//   npm run backup
//
// Saves to trackit-ojt-system/backups/backup-<date-time>/ :
//   database.json   all public tables, row by row
//   files/...       the Supabase bucket, same folders as online
//   summary.txt     counts, so you can see at a glance what was saved
// The backups folder is git-ignored (it holds personal data); keep a copy
// somewhere safe too (USB drive, Google Drive).
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '..', '.env'), quiet: true });
const fs = require('fs');
const pool = require('../db');
const { supabase } = require('../utils/storage');

const stamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
const OUT = path.join(__dirname, '..', '..', '..', 'backups', `backup-${stamp}`);

async function backupDatabase() {
  const tables = (
    await pool.query(
      `SELECT table_name FROM information_schema.tables
       WHERE table_schema = 'public' AND table_type = 'BASE TABLE' ORDER BY table_name`,
    )
  ).rows.map((r) => r.table_name);
  const data = {};
  let rows = 0;
  for (const t of tables) {
    data[t] = (await pool.query(`SELECT * FROM "${t}"`)).rows;
    rows += data[t].length;
  }
  fs.writeFileSync(
    path.join(OUT, 'database.json'),
    JSON.stringify({ createdAt: new Date().toISOString(), tables: data }, null, 1),
  );
  return { tables: tables.length, rows, perTable: tables.map((t) => `${t}: ${data[t].length}`) };
}

async function listAll(cfg, prefix = '') {
  const found = [];
  for (let offset = 0; ; offset += 1000) {
    const res = await fetch(`${cfg.url}/storage/v1/object/list/${cfg.bucket}`, {
      method: 'POST',
      headers: { apikey: cfg.key, Authorization: `Bearer ${cfg.key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ prefix, limit: 1000, offset, sortBy: { column: 'name', order: 'asc' } }),
    });
    if (!res.ok) throw new Error(`Could not list files (${res.status}): ${(await res.text()).slice(0, 200)}`);
    const items = await res.json();
    for (const it of items) {
      const full = prefix ? `${prefix}/${it.name}` : it.name;
      // Folders have no id; files do.
      if (it.id) found.push(full);
      else found.push(...(await listAll(cfg, full)));
    }
    if (items.length < 1000) break;
  }
  return found;
}

async function backupFiles() {
  const cfg = supabase();
  if (!cfg) return { skipped: 'SUPABASE_URL / SUPABASE_SERVICE_KEY not set', files: 0, bytes: 0, failed: [] };
  const all = await listAll(cfg);
  let bytes = 0;
  const failed = [];
  for (const objectPath of all) {
    const encoded = objectPath.split('/').map(encodeURIComponent).join('/');
    const res = await fetch(`${cfg.url}/storage/v1/object/${cfg.bucket}/${encoded}`, {
      headers: { apikey: cfg.key, Authorization: `Bearer ${cfg.key}` },
    });
    if (!res.ok) {
      failed.push(`${objectPath} (${res.status})`);
      continue;
    }
    const buf = Buffer.from(await res.arrayBuffer());
    const target = path.join(OUT, 'files', ...objectPath.split('/'));
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.writeFileSync(target, buf);
    bytes += buf.length;
  }
  return { files: all.length - failed.length, bytes, failed };
}

(async () => {
  try {
    fs.mkdirSync(OUT, { recursive: true });
    console.log('Backing up to', OUT);
    const db = await backupDatabase();
    console.log(`Database: ${db.tables} tables, ${db.rows} rows`);
    const files = await backupFiles();
    if (files.skipped) console.log('Files skipped:', files.skipped);
    else console.log(`Files: ${files.files} downloaded (${(files.bytes / 1024 / 1024).toFixed(1)} MB)`);
    for (const f of files.failed) console.log('  FAILED', f);
    fs.writeFileSync(
      path.join(OUT, 'summary.txt'),
      [
        `TrackIT backup ${new Date().toString()}`,
        '',
        `Database: ${db.tables} tables, ${db.rows} rows`,
        ...db.perTable.map((l) => `  ${l}`),
        '',
        files.skipped
          ? `Files skipped: ${files.skipped}`
          : `Files: ${files.files} (${(files.bytes / 1024 / 1024).toFixed(1)} MB)`,
        ...files.failed.map((f) => `  FAILED ${f}`),
        '',
      ].join('\n'),
    );
    console.log('Done.');
    if (files.failed.length) process.exitCode = 1;
  } catch (error) {
    console.error('Backup failed:', error.message);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
})();
