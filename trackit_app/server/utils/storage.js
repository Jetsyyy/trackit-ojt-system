// Where uploaded files live.
//
// Online (Vercel) the server's disk is wiped between requests, so files go
// to Supabase Storage when SUPABASE_URL and SUPABASE_SERVICE_KEY are set
// (bucket SUPABASE_BUCKET, default "trackit-files", which must be Public).
// Vercel Blob is still supported as a fallback. On a computer with neither,
// files are saved under server/uploads and served from /uploads.
//
// uploadStorage(folder) is a multer storage engine. After an upload,
// req.file.url is the address to save in the database: an https:// public
// URL online, or "/uploads/<folder>/<name>" locally.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const UPLOAD_ROOT = path.join(__dirname, '..', 'uploads');

// ---- Supabase Storage (REST API, no extra package needed) ----

function supabase() {
  const url = (process.env.SUPABASE_URL || '').trim().replace(/\/+$/, '');
  const key = (process.env.SUPABASE_SERVICE_KEY || '').trim();
  if (!url || !key) return null;
  const bucket = (process.env.SUPABASE_BUCKET || 'trackit-files').trim();
  return { url, key, bucket, publicPrefix: `${url}/storage/v1/object/public/${bucket}/` };
}

const supabaseHeaders = (cfg, extra = {}) => ({ apikey: cfg.key, Authorization: `Bearer ${cfg.key}`, ...extra });
const encodePath = (objectPath) => objectPath.split('/').map(encodeURIComponent).join('/');

/// Uploads a buffer to Supabase and returns its public URL.
async function putSupabase(objectPath, buffer, contentType) {
  const cfg = supabase();
  const res = await fetch(`${cfg.url}/storage/v1/object/${cfg.bucket}/${encodePath(objectPath)}`, {
    method: 'POST',
    headers: supabaseHeaders(cfg, { 'Content-Type': contentType || 'application/octet-stream', 'x-upsert': 'false' }),
    body: buffer,
  });
  if (!res.ok) {
    const text = await res.text().catch(() => '');
    throw new Error(`File storage upload failed (${res.status}): ${text.slice(0, 200)}`);
  }
  return cfg.publicPrefix + encodePath(objectPath);
}

// ---- Vercel Blob (fallback) ----

// The Blob store's key. Vercel names it BLOB_READ_WRITE_TOKEN unless a
// custom prefix was chosen when connecting the store (e.g.
// TRACKIT_FILES_READ_WRITE_TOKEN), so any *_READ_WRITE_TOKEN holding a
// Blob key is accepted.
function blobToken() {
  if (process.env.BLOB_READ_WRITE_TOKEN) return process.env.BLOB_READ_WRITE_TOKEN;
  for (const [name, value] of Object.entries(process.env)) {
    if (name.endsWith('_READ_WRITE_TOKEN') && String(value).startsWith('vercel_blob_rw_')) return value;
  }
  return null;
}
// Newer stores sign in without a key: Vercel provides BLOB_STORE_ID and a
// short-lived per-request token (OIDC), which @vercel/blob uses by itself.
const useBlob = () => Boolean(blobToken() || process.env.BLOB_STORE_ID);
// Pass the key only when there is one, so OIDC sign-in is used otherwise.
const auth = () => (blobToken() ? { token: blobToken() } : {});

function uniqueName(originalName) {
  const ext = path.extname(originalName || '').toLowerCase();
  return `${Date.now()}-${crypto.randomInt(1e9)}${ext}`;
}

function readStream(stream) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    stream.on('data', (chunk) => chunks.push(chunk));
    stream.on('error', reject);
    stream.on('end', () => resolve(Buffer.concat(chunks)));
  });
}

class UploadStorage {
  constructor(folder) {
    this.folder = folder;
  }

  _handleFile(req, file, cb) {
    const name = uniqueName(file.originalname);
    if (supabase()) {
      readStream(file.stream)
        .then(async (buffer) => {
          const url = await putSupabase(`${this.folder}/${name}`, buffer, file.mimetype);
          cb(null, { filename: name, size: buffer.length, url, path: null });
        })
        .catch(cb);
      return;
    }
    if (useBlob()) {
      readStream(file.stream)
        .then(async (buffer) => {
          const { put } = require('@vercel/blob');
          const blob = await put(`${this.folder}/${name}`, buffer, {
            access: 'public',
            contentType: file.mimetype,
            addRandomSuffix: true,
            ...auth(),
          });
          cb(null, { filename: name, size: buffer.length, url: blob.url, path: null });
        })
        .catch(cb);
      return;
    }
    if (process.env.VERCEL) {
      // Vercel's disk is read-only: without online storage there is nowhere
      // to keep the file.
      // Names only (never values), to show which storage settings exist.
      const related = Object.keys(process.env).filter((n) => /BLOB|STORE|READ_WRITE|SUPABASE/i.test(n));
      cb(
        new Error(
          'File storage is not set up: add SUPABASE_URL and SUPABASE_SERVICE_KEY to the project and redeploy.' +
            ` (storage settings found: ${related.length ? related.join(', ') : 'none'})`,
        ),
      );
      return;
    }
    const dir = path.join(UPLOAD_ROOT, this.folder);
    try {
      fs.mkdirSync(dir, { recursive: true });
    } catch (error) {
      cb(error);
      return;
    }
    const target = path.join(dir, name);
    const out = fs.createWriteStream(target);
    let size = 0;
    file.stream.on('data', (chunk) => {
      size += chunk.length;
    });
    file.stream.pipe(out);
    out.on('error', cb);
    out.on('finish', () =>
      cb(null, {
        filename: name,
        size,
        path: target,
        url: `/uploads/${this.folder}/${name}`,
      }),
    );
  }

  _removeFile(req, file, cb) {
    removeStored(file.url).then(() => cb(null), () => cb(null));
  }
}

const uploadStorage = (folder) => new UploadStorage(folder);

/// Deletes a stored file by the URL saved in the database (a Supabase or
/// Blob URL, or a local /uploads path). Missing files are ignored.
async function removeStored(url) {
  if (!url) return;
  try {
    const cfg = supabase();
    if (cfg && url.startsWith(cfg.publicPrefix)) {
      const objectPath = url.slice(cfg.publicPrefix.length);
      const res = await fetch(`${cfg.url}/storage/v1/object/${cfg.bucket}/${objectPath}`, {
        method: 'DELETE',
        headers: supabaseHeaders(cfg),
      });
      if (!res.ok && res.status !== 404 && res.status !== 400) {
        console.error('Remove stored file error:', url, res.status);
      }
      return;
    }
    if (/^https?:\/\//.test(url)) {
      if (!useBlob()) return;
      const { del } = require('@vercel/blob');
      await del(url, auth());
      return;
    }
    if (!url.startsWith('/uploads/')) return;
    const filePath = path.join(UPLOAD_ROOT, url.slice('/uploads/'.length));
    if (!filePath.startsWith(UPLOAD_ROOT)) return;
    await fs.promises.unlink(filePath);
  } catch (error) {
    if (error && error.code === 'ENOENT') return;
    console.error('Remove stored file error:', url, error && error.message);
  }
}

module.exports = { uploadStorage, removeStored, putSupabase, supabase, UPLOAD_ROOT };
