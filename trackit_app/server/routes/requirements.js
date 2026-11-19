const express = require('express');
const multer = require('multer');
const path = require('path');
const pool = require('../db');
const { requireAuth } = require('../middleware/auth');
const { notifyInstructorForStudent } = require('../utils/notifyInstructor');
const { requirementFileFilter } = require('../utils/requirementFileTypes');

const router = express.Router();
router.use(requireAuth);

const storage = multer.diskStorage({
  destination: path.join(__dirname, '..', 'uploads', 'requirements'),
  filename: (req, file, cb) => {
    const unique = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
    cb(null, `${unique}${path.extname(file.originalname)}`);
  },
});
const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: requirementFileFilter,
});

router.get('/', async (req, res) => {
  try {
    const phases = await pool.query(
      'SELECT * FROM ojt_requirement_phases ORDER BY order_index ASC',
    );
    const templates = await pool.query(
      'SELECT * FROM ojt_requirement_templates ORDER BY phase_id, sort_order ASC',
    );
    const submissions = await pool.query(
      'SELECT * FROM student_requirement_submissions WHERE student_id = $1',
      [req.studentId],
    );
    const submissionsByTemplate = new Map(
      submissions.rows.map((s) => [s.requirement_template_id, s]),
    );

    const phasesWithDocs = phases.rows.map((phase) => {
      const documents = templates.rows
        .filter((t) => t.phase_id === phase.id)
        .map((template) => {
          const submission = submissionsByTemplate.get(template.id);
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
        });
      const fulfilled = documents.every(
        (d) => d.status === 'submitted' || d.status === 'approved',
      );
      return {
        id: phase.id,
        order: phase.order_index,
        title: phase.title,
        description: phase.description,
        documents,
        fulfilled,
      };
    });

    // Sequential lock/unlock: a phase can only be in progress or completed
    // if every earlier phase is fulfilled.
    let previousCompleted = true;
    const result = phasesWithDocs.map((phase) => {
      let status;
      if (!previousCompleted) status = 'locked';
      else if (phase.fulfilled) status = 'completed';
      else status = 'inProgress';
      previousCompleted = phase.fulfilled;
      return { ...phase, status };
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
    const fileUrl = req.file ? `/uploads/requirements/${req.file.filename}` : null;
    if (!fileName) {
      return res.status(400).json({ success: false, message: 'No file provided.' });
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
