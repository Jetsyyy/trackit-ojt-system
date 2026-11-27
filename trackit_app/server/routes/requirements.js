const express = require('express');
const multer = require('multer');
const { uploadStorage } = require('../utils/storage');
const path = require('path');
const pool = require('../db');
const { requireAuth } = require('../middleware/auth');
const { notifyInstructorForStudent } = require('../utils/notifyInstructor');
const { requirementFileFilter } = require('../utils/requirementFileTypes');
const { loadPhasesAndTemplates, buildPhases, companyConfirmedFor } = require('../utils/requirementPhases');

const router = express.Router();
router.use(requireAuth);

const storage = uploadStorage('requirements');
const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: requirementFileFilter,
});

router.get('/', async (req, res) => {
  try {
    const [{ phases, templates }, submissions, companyConfirmed] = await Promise.all([
      loadPhasesAndTemplates(),
      pool.query('SELECT * FROM student_requirement_submissions WHERE student_id = $1', [req.studentId]),
      companyConfirmedFor(req.studentId),
    ]);
    const submissionsByTemplate = new Map(
      submissions.rows.map((s) => [String(s.requirement_template_id), s]),
    );

    const result = buildPhases({
      phases,
      templates,
      submissionsByTemplate,
      companyConfirmed,
      toDocument: (template, submission) => {
          // Office-issued requirements (System Revisions item 6) never
          // expose a template: the student gets them from that office.
          const issuedBy = template.issued_by || null;
          return {
            id: template.id,
            name: template.name,
            description: template.description,
            issuedBy,
            hasTemplate: issuedBy ? false : template.has_template && !!template.template_url,
            templateUrl: issuedBy ? null : template.template_url,
            templateName: issuedBy ? null : template.template_name,
            status: submission ? submission.status : 'missing',
            uploadedFileName: submission ? submission.uploaded_file_name : null,
            uploadedFileUrl: submission ? submission.uploaded_file_url : null,
            deadline: submission ? submission.deadline : null,
            submittedAt: submission ? submission.submitted_at : null,
            remarks: submission ? submission.remarks : null,
          };
      },
    });

    res.json({ success: true, phases: result });
  } catch (error) {
    console.error('Get requirements error:', error);
    res.status(500).json({ success: false, message: 'Failed to load requirements.' });
  }
});

// Real multipart file upload -- the JSON { fileName } fallback stays as a
// defensive no-op path, but the Flutter app always sends real file bytes.
// Final Documents: the student confirms the final (physical) documents
// are complete. Saved once with a timestamp and the instructor is told.
router.get('/final-ready', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT final_documents_ready_at FROM student_profiles WHERE student_id = $1',
      [req.studentId],
    );
    res.json({ success: true, readyAt: result.rows[0]?.final_documents_ready_at || null });
  } catch (error) {
    console.error('Get final documents ready error:', error);
    res.status(500).json({ success: false, message: 'Failed to load.' });
  }
});

router.post('/final-ready', async (req, res) => {
  try {
    const result = await pool.query(
      `UPDATE student_profiles
       SET final_documents_ready_at = COALESCE(final_documents_ready_at, now()), updated_at = now()
       WHERE student_id = $1
       RETURNING final_documents_ready_at`,
      [req.studentId],
    );
    const readyAt = result.rows[0]?.final_documents_ready_at || null;
    try {
      const student = await pool.query('SELECT name FROM students WHERE id = $1', [req.studentId]);
      await notifyInstructorForStudent(req.studentId, {
        title: 'Final Documents Ready',
        message: `${student.rows[0]?.name || 'A student'} says all final documents are ready for your review and confirmation.`,
        relatedModule: 'requirements',
      });
    } catch (notifyError) {
      console.error('Final documents ready notification not sent:', notifyError.message);
    }
    res.json({ success: true, readyAt });
  } catch (error) {
    console.error('Final documents ready error:', error);
    res.status(500).json({ success: false, message: 'Failed to send.' });
  }
});

router.post('/:templateId/submit', upload.single('file'), async (req, res) => {
  try {
    const templateId = Number(req.params.templateId);
    const fileName = req.file ? req.file.originalname : req.body.fileName;
    const fileUrl = req.file ? req.file.url : null;
    if (!fileName) {
      return res.status(400).json({ success: false, message: 'No file provided.' });
    }
    const template = await pool.query(
      'SELECT upload_required, retired_at FROM ojt_requirement_templates WHERE id = $1',
      [templateId],
    );
    const t = template.rows[0];
    if (!t || t.retired_at) {
      return res.status(404).json({ success: false, message: 'This document is no longer on the requirements list.' });
    }
    if (t.upload_required === false) {
      return res.status(400).json({
        success: false,
        message: 'This document only needs to be downloaded. There is nothing to upload for it.',
      });
    }

    const result = await pool.query(
      `INSERT INTO student_requirement_submissions
         (student_id, requirement_template_id, status, uploaded_file_name, uploaded_file_url, submitted_at)
       VALUES ($1, $2, 'submitted', $3, $4, now())
       ON CONFLICT (student_id, requirement_template_id)
       DO UPDATE SET status = 'submitted', uploaded_file_name = $3,
         uploaded_file_url = $4, submitted_at = now(), updated_at = now()
       RETURNING *`,
      [req.studentId, templateId, fileName, fileUrl],
    );

    try {
      const [studentResult, templateResult] = await Promise.all([
        pool.query('SELECT name FROM students WHERE id = $1', [req.studentId]),
        pool.query('SELECT name FROM ojt_requirement_templates WHERE id = $1', [templateId]),
      ]);
      const studentName = studentResult.rows[0]?.name;
      const templateName = templateResult.rows[0]?.name;
      if (studentName && templateName) {
        await notifyInstructorForStudent(req.studentId, {
          title: 'Requirement Submitted',
          message: `${studentName} submitted "${templateName}" for review.`,
          relatedModule: 'requirements',
        });
      }
    } catch (notifyError) {
      console.error('Notify instructor of requirement submission error:', notifyError);
    }

    res.json({ success: true, submission: result.rows[0] });
  } catch (error) {
    console.error('Submit requirement error:', error);
    res.status(500).json({ success: false, message: 'Failed to submit document.' });
  }
});

module.exports = router;
