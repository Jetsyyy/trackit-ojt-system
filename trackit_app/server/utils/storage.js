// Where uploaded files live.
//
// Online (Vercel) the server's disk is wiped between requests, so files go
// to Vercel Blob; that's switched on by the BLOB_READ_WRITE_TOKEN variable
// Vercel adds when a Blob store is connected to the project. On a computer
// without that variable, files are saved under server/uploads as before
// and served from /uploads.
//
// uploadStorage(folder) is a multer storage engine. After an upload,
// req.file.url is the address to save in the database: an https:// Blob
// URL online, or "/uploads/<folder>/<name>" locally.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const UPLOAD_ROOT = path.join(__dirname, '..', 'uploads');
const useBlob = () => Boolean(process.env.BLOB_READ_WRITE_TOKEN);

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
    if (useBlob()) {
      readStream(file.stream)
        .then(async (buffer) => {
          const { put } = require('@vercel/blob');
          const blob = await put(`${this.folder}/${name}`, buffer, {
            access: 'public',
            contentType: file.mimetype,
            addRandomSuffix: true,
          });
          cb(null, { filename: name, size: buffer.length, url: blob.url, path: null });
        })
        .catch(cb);
      return;
    }
    const dir = path.join(UPLOAD_ROOT, this.folder);
    fs.mkdirSync(dir, { recursive: true });
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

/// Deletes a stored file by the URL saved in the database (a Blob URL or
/// a local /uploads path). Missing files are ignored.
async function removeStored(url) {
  if (!url) return;
  try {
    if (/^https?:\/\//.test(url)) {
      if (!useBlob()) return;
      const { del } = require('@vercel/blob');
      await del(url);
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

module.exports = { uploadStorage, removeStored, UPLOAD_ROOT };
