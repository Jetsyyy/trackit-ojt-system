// One-time move of uploaded files into Supabase Storage, updating every
// database column that points at them. Handles:
//   - local paths ("/uploads/<folder>/<name>") from server/uploads, and
//   - Vercel Blob URLs: copied from Blob when it answers, otherwise from the
//     matching local copy in server/uploads (Blob names add a random suffix
//     to the local name: "<name>-<suffix>.<ext>").
// Files found in neither place are listed and left as they are.
//
// Needs DATABASE_URL, SUPABASE_URL and SUPABASE_SERVICE_KEY in trackit_app/.env.
//
//   node scripts/migrate_files_to_supabase.js           # dry run: lists what would move
//   node scripts/migrate_files_to_supabase.js --apply   # uploads and updates the database
//
// Safe to re-run: files already moved no longer match any row.
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '..', '.env') });
const fs = require('fs');
const pool = require('../db');
const { putSupabase, supabase } = require('../utils/storage');

const APPLY = process.argv.includes('--apply');
const UPLOAD_ROOT = path.join(__dirname, '..', 'uploads');
const BLOB_RE = /^https:\/\/[^/]+\.blob\.vercel-storage\.com\/(.+)$/;

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

function localFile(relative) {
  const p = path.join(UPLOAD_ROOT, relative);
  return p.startsWith(UPLOAD_ROOT) && fs.existsSync(p) ? p : null;
}

/// Where to read the file from: { relative, read() } or null.
async function source(url) {
  if (url.startsWith('/uploads/')) {
    const relative = decodeURIComponent(url.slice('/uploads/'.length));
    const p = localFile(relative);
    return p ? { relative, from: 'disk', read: async () => fs.readFileSync(p) } : null;
  }
  const m = BLOB_RE.exec(url);
  if (!m) return null;
  const blobPath = decodeURIComponent(m[1]);
  // Name without Blob's random suffix, as saved on this computer.
  const relative = blobPath.replace(/-[A-Za-z0-9]{20,40}(\.[^./]+)?$/, '$1');
  try {
    const res = await fetch(url, { method: 'HEAD' });
    if (res.ok) {
      return {
        relative,
        from: 'blob',
        read: async () => Buffer.from(await (await fetch(url)).arrayBuffer()),
      };
    }
  } catch {
    // Fall through to the local copy.
  }
  const p = localFile(relative) || localFile(blobPath);
  return p ? { relative, from: 'disk', read: async () => fs.readFileSync(p) } : null;
}

(async () => {
  if (!supabase()) {
    console.error('SUPABASE_URL / SUPABASE_SERVICE_KEY are not set in trackit_app/.env.');
    process.exit(1);
  }
  try {
    const columns = (
      await pool.query(
        `SELECT table_name, column_name FROM information_schema.columns
         WHERE table_schema = 'public' AND data_type IN ('text', 'character varying')`,
      )
    ).rows;
    const refs = new Map(); // url -> [{table, column}]
    for (const { table_name: t, column_name: c } of columns) {
      const rows = (
        await pool.query(
          `SELECT DISTINCT "${c}" AS url FROM "${t}"
           WHERE "${c}" LIKE '/uploads/%' OR "${c}" ~ '^https://[^/]+\\.blob\\.vercel-storage\\.com/'`,
        )
      ).rows;
      for (const { url } of rows) {
        if (!refs.has(url)) refs.set(url, []);
        refs.get(url).push({ table: t, column: c });
      }
    }

    let moved = 0;
    const missing = [];
    for (const [url, places] of refs) {
      const src = await source(url);
      const where = places.map((p) => `${p.table}.${p.column}`).join(', ');
      if (!src) {
        missing.push(`${url}  (${where})`);
        continue;
      }
      if (!APPLY) {
        console.log(`would move [${src.from}]`, src.relative, '->', where);
        moved++;
        continue;
      }
      const ext = path.extname(src.relative);
      const objectPath = src.relative.slice(0, src.relative.length - ext.length) + `-${Date.now().toString(36)}${ext}`;
      const newUrl = await putSupabase(objectPath, await src.read(), MIME[ext.toLowerCase()] || 'application/octet-stream');
      for (const p of places) {
        await pool.query(`UPDATE "${p.table}" SET "${p.column}" = $1 WHERE "${p.column}" = $2`, [newUrl, url]);
      }
      moved++;
      console.log(`moved [${src.from}]`, src.relative);
    }
    if (missing.length) {
      console.log(`\nNot found anywhere (left as is):`);
      for (const m of missing) console.log('  ', m);
    }
    console.log(
      `\n${APPLY ? 'Moved' : 'Would move'} ${moved} file(s); ${missing.length} not found.` +
        (APPLY ? '' : ' Run again with --apply to do it.'),
    );
  } catch (error) {
    console.error('Migration failed:', error.message);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
})();
