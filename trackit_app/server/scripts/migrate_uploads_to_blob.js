// One-time move of files saved under server/uploads (before the switch to
// Vercel Blob) into the Blob store, updating every database column that
// points at them.
//
// Needs DATABASE_URL (from trackit_app/.env) and BLOB_READ_WRITE_TOKEN
// (Vercel > Storage > your Blob store > .env.local tab).
//
//   node scripts/migrate_uploads_to_blob.js           # dry run: lists what would move
//   node scripts/migrate_uploads_to_blob.js --apply   # uploads and updates the database
//
// Safe to re-run: files already moved no longer match any row.
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '..', '.env') });
const fs = require('fs');
const pool = require('../db');

const APPLY = process.argv.includes('--apply');
const UPLOAD_ROOT = path.join(__dirname, '..', 'uploads');

const MIME = {
  '.pdf': 'application/pdf',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.heic': 'image/heic',
  '.heif': 'image/heif',
  '.doc': 'application/msword',
  '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  '.xls': 'application/vnd.ms-excel',
  '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
};

(async () => {
  if (APPLY && !process.env.BLOB_READ_WRITE_TOKEN) {
    console.error('BLOB_READ_WRITE_TOKEN is not set. See the comment at the top of this file.');
    process.exit(1);
  }
  try {
    // Every text column in the database that holds an /uploads/ path.
    const columns = (
      await pool.query(
        `SELECT table_name, column_name FROM information_schema.columns
         WHERE table_schema = 'public' AND data_type IN ('text', 'character varying')`,
      )
    ).rows;
    const refs = new Map(); // '/uploads/..' -> [{table, column}]
    for (const { table_name: t, column_name: c } of columns) {
      const rows = (
        await pool.query(`SELECT DISTINCT "${c}" AS url FROM "${t}" WHERE "${c}" LIKE '/uploads/%'`)
      ).rows;
      for (const { url } of rows) {
        if (!refs.has(url)) refs.set(url, []);
        refs.get(url).push({ table: t, column: c });
      }
    }

    let moved = 0;
    let missing = 0;
    const { put } = APPLY ? require('@vercel/blob') : { put: null };
    for (const [url, places] of refs) {
      const local = path.join(UPLOAD_ROOT, url.slice('/uploads/'.length));
      if (!local.startsWith(UPLOAD_ROOT) || !fs.existsSync(local)) {
        missing++;
        console.log('MISSING on disk (left as is):', url);
        continue;
      }
      const where = places.map((p) => `${p.table}.${p.column}`).join(', ');
      if (!APPLY) {
        console.log('would move', url, '->', where);
        moved++;
        continue;
      }
      const blob = await put(url.slice('/uploads/'.length), fs.readFileSync(local), {
        access: 'public',
        contentType: MIME[path.extname(local).toLowerCase()] || 'application/octet-stream',
        addRandomSuffix: true,
      });
      for (const p of places) {
        await pool.query(`UPDATE "${p.table}" SET "${p.column}" = $1 WHERE "${p.column}" = $2`, [blob.url, url]);
      }
      moved++;
      console.log('moved', url);
    }
    console.log(
      `${APPLY ? 'Moved' : 'Would move'} ${moved} file(s); ${missing} referenced file(s) not found on disk.` +
        (APPLY ? '' : ' Run again with --apply to do it.'),
    );
  } catch (error) {
    console.error('Migration failed:', error.message);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
})();
