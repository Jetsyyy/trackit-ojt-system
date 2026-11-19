const express = require('express');
const fs = require('fs');
const multer = require('multer');
const path = require('path');
const pool = require('../db');
const { requireAuth } = require('../middleware/auth');
const { notifyInstructorForStudent } = require('../utils/notifyInstructor');
const { loadWeekPlan, buildWeekList, summarize } = require('../utils/weeklySubmissions');

// Weekly Submissions (System Revisions items 2, 3, 9, 10): every OJT week
// the student uploads a photo/scan of the week's DTR and the matching AR,
// and enters the hours claimed from that DTR. The hours only count once
// the assigned instructor approves the week (routes/teacherWeeklyReports.js).

const router = express.Router();
router.use(requireAuth);

const UPLOAD_DIR = path.join(__dirname, '..', 'uploads', 'weekly');
const MAX_FILES_PER_KIND = 5;
const MAX_CLAIMED_HOURS = 168;

// A DTR is usually a phone photo or a scan, so images are allowed here
// (unlike Official Requirements, which are office documents only).
const ALLOWED_MIME_TYPES = new Set([
  'application/pdf',
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/heic',
  'image/heif',
]);

const upload = multer({
  storage: multer.diskStorage({
    destination: UPLOAD_DIR,
    filename: (req, file, cb) => {
      const unique = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
      cb(null, `${unique}${path.extname(file.originalname).toLowerCase()}`);
    },
  }),
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    if (ALLOWED_MIME_TYPES.has(file.mimetype)) return cb(null, true);
    cb(new multer.MulterError('LIMIT_UNEXPECTED_FILE', file.fieldname));
  },
}).fields([
  { name: 'dtr', maxCount: MAX_FILES_PER_KIND },
  { name: 'ar', maxCount: MAX_FILES_PER_KIND },
]);

function uploadWeekFiles(req, res, next) {
  upload(req, res, (error) => {
    if (!error) return next();
    discardUploads(req);
    let message = 'Upload failed.';
    if (error.code === 'LIMIT_FILE_SIZE') message = 'Each file must be 10 MB or smaller.';
    else if (error.code === 'LIMIT_UNEXPECTED_FILE') {
      message = `Only PDF or image files (JPG, PNG, WEBP, HEIC) are allowed, up to ${MAX_FILES_PER_KIND} per DTR/AR.`;
    }
    res.status(400).json({ success: false, message });
  });
}

function uploadedFiles(req) {
  return [...(req.files?.dtr || []), ...(req.files?.ar || [])];
}

// Rejected requests must not leave orphaned uploads behind.
function discardUploads(req) {
  for (const file of uploadedFiles(req)) {
    fs.unlink(file.path, (error) => {
      if (error && error.code !== 'ENOENT') {
        console.error('Discard weekly upload error:', file.path, error.message);
      }
    });
  }
}

router.get('/', async (req, res) => {
  try {
    const plan = await loadWeekPlan(req.studentId);
    const reports = await buildWeekList(plan);
    res.json({ success: true, summary: summarize(plan, reports), reports });
  } catch (error) {
    console.error('Get weekly submissions error:', error);
    res.status(500).json({ success: false, message: 'Failed to load weekly submissions.' });
  }
});

// multipart/form-data: dtr (1-5 files), ar (1-5 files), claimedHours,
// description (optional). Allowed for a missing or rejected week;
// resubmitting a rejected week replaces its files and sends it back for
// review. Approved weeks are locked.
router.post('/:weekNumber/submit', uploadWeekFiles, async (req, res) => {
  const fail = (status, message) => {
    discardUploads(req);
    return res.status(status).json({ success: false, message });
  };

  try {
    const weekNumber = Number(req.params.weekNumber);
    const claimedHours = Number(req.body.claimedHours);
    const description = (req.body.description || '').toString().trim();
    const dtrFiles = req.files?.dtr || [];
    const arFiles = req.files?.ar || [];

    if (!Number.isFinite(claimedHours) || claimedHours <= 0 || claimedHours > MAX_CLAIMED_HOURS) {
      return fail(400, `Enter the hours claimed for this week (more than 0, at most ${MAX_CLAIMED_HOURS}).`);
    }
    if (Math.abs(Math.round(claimedHours * 100) - claimedHours * 100) > 1e-6) {
      return fail(400, 'Claimed hours can have at most 2 decimal places.');
    }
    if (dtrFiles.length === 0) return fail(400, "Upload a photo or scan of this week's DTR.");
    if (arFiles.length === 0) return fail(400, "Upload this week's Accomplishment Report.");

    const plan = await loadWeekPlan(req.studentId);
    if (!plan.ojtStartDate) {
      return fail(400, 'Set your company details (with OJT Start Date) before submitting.');
    }
    if (plan.isComplete) {
      return fail(400, 'Your required OJT hours are already complete. No more weekly submissions are needed.');
    }
    const week = plan.weeks.find((w) => w.weekNumber === weekNumber);
    if (!week) return fail(400, 'Invalid or future week.');

    const existing = plan.rows.find((r) => r.week_number === weekNumber);
    if (existing?.status === 'approved') {
      return fail(409, `Week ${weekNumber} is already approved and can no longer be changed.`);
    }
    if (existing?.status === 'submitted') {
      return fail(409, `Week ${weekNumber} is already waiting for your instructor's review.`);
    }

    const client = await pool.connect();
    let replacedFiles = [];
    try {
      await client.query('BEGIN');
      const inserted = await client.query(
        `INSERT INTO activity_reports
           (student_id, week_number, week_start_date, week_end_date, description,
            claimed_hours, status, submitted_at, remarks, reviewed_at, reviewed_by)
         VALUES ($1, $2, $3, $4, $5, $6, 'submitted', now(), NULL, NULL, NULL)
         ON CONFLICT (student_id, week_number)
         DO UPDATE SET description = $5, claimed_hours = $6, status = 'submitted',
           submitted_at = now(), week_start_date = $3, week_end_date = $4,
           remarks = NULL, reviewed_at = NULL, reviewed_by = NULL, updated_at = now()
         RETURNING id`,
        [req.studentId, weekNumber, week.weekStartDate, week.weekEndDate, description, claimedHours],
      );
      const reportId = inserted.rows[0].id;

      const removed = await client.query(
        'DELETE FROM activity_report_attachments WHERE activity_report_id = $1 RETURNING file_url',
        [reportId],
      );
      replacedFiles = removed.rows.map((r) => r.file_url).filter(Boolean);
      for (const [kind, files] of [['dtr', dtrFiles], ['ar', arFiles]]) {
        for (const file of files) {
          await client.query(
            `INSERT INTO activity_report_attachments (activity_report_id, kind, file_name, file_url)
             VALUES ($1, $2, $3, $4)`,
            [reportId, kind, file.originalname, `/uploads/weekly/${file.filename}`],
          );
        }
      }
      await client.query('COMMIT');
    } catch (dbError) {
      await client.query('ROLLBACK');
      throw dbError;
    } finally {
      client.release();
    }

    // A resubmitted (previously rejected) week replaces its files; only
    // delete the old ones once the new submission is safely committed.
    for (const fileUrl of replacedFiles) {
      if (!fileUrl.startsWith('/uploads/weekly/')) continue;
      fs.unlink(path.join(UPLOAD_DIR, path.basename(fileUrl)), (error) => {
        if (error && error.code !== 'ENOENT') {
          console.error('Remove replaced weekly upload error:', fileUrl, error.message);
        }
      });
    }

    try {
      const studentResult = await pool.query('SELECT name FROM students WHERE id = $1', [
        req.studentId,
      ]);
      const studentName = studentResult.rows[0]?.name;
      if (studentName) {
        await notifyInstructorForStudent(req.studentId, {
          title: existing?.status === 'rejected' ? 'Weekly DTR/AR Resubmitted' : 'Weekly DTR/AR Submitted',
          message: `${studentName} submitted the Week ${weekNumber} DTR and AR, claiming ${claimedHours} hours.`,
          relatedModule: 'reports',
        });
      }
    } catch (notifyError) {
      console.error('Notify instructor of weekly submission error:', notifyError);
    }

    const updatedPlan = await loadWeekPlan(req.studentId);
    const reports = await buildWeekList(updatedPlan);
    res.json({ success: true, summary: summarize(updatedPlan, reports), reports });
  } catch (error) {
    console.error('Submit weekly DTR/AR error:', error);
    discardUploads(req);
    res.status(500).json({ success: false, message: 'Failed to submit weekly DTR/AR.' });
  }
});

module.exports = router;
