const express = require('express');
const multer = require('multer');
const { uploadStorage } = require('../utils/storage');
const path = require('path');
const pool = require('../db');
const { requireAuth } = require('../middleware/auth');
const { notifyInstructorForStudent } = require('../utils/notifyInstructor');
const { requirementFileFilter } = require('../utils/requirementFileTypes');
const { visibleToStudent, sendDueReminders } = require('../utils/scheduledRequirements');

const router = express.Router();
router.use(requireAuth);

const storage = uploadStorage('requirements');
const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: requirementFileFilter,
});

// Additional Requirements -- instructor-created, targeted at the
// student's class. Same submit/status flow as the fixed Official
// Requirements, just a different source table (see
// migration_teacher_documents.sql).
router.get('/', async (req, res) => {
  try {
    sendDueReminders().catch((e) => console.error('Due reminders error:', e.message));
    // Instructor-made ones for the student's section, and the OJT office's
    // scheduled requirements for their academic year (soonest due first).
    const requirementsResult = await pool.query(
      `SELECT cr.* FROM custom_requirements cr
       WHERE ${visibleToStudent(1)}
       ORDER BY COALESCE(cr.due_at, cr.deadline::timestamptz) ASC NULLS LAST, cr.created_at DESC`,
      [req.studentId],
    );
    const submissionsResult = await pool.query(
      'SELECT * FROM student_custom_requirement_submissions WHERE student_id = $1',
      [req.studentId],
    );
    const byRequirement = new Map(
      submissionsResult.rows.map((s) => [s.custom_requirement_id, s]),
    );

    const requirements = requirementsResult.rows.map((requirement) => {
      const submission = byRequirement.get(requirement.id);
      return {
        id: requirement.id,
        name: requirement.title,
        description: requirement.description,
        deadline: requirement.deadline,
        // Scheduled by the OJT office: period and exact due date and time.
        fromOffice: requirement.audience === 'all_students',
        period: requirement.period || null,
        dueAt: requirement.due_at || null,
        isLate: submission ? Boolean(submission.is_late) : false,
        templateUrl: requirement.template_url,
        templateName: requirement.template_name,
        status: submission ? submission.status : 'missing',
        uploadedFileName: submission ? submission.uploaded_file_name : null,
        uploadedFileUrl: submission ? submission.uploaded_file_url : null,
        submittedAt: submission ? submission.submitted_at : null,
        remarks: submission ? submission.remarks : null,
      };
    });

    res.json({ success: true, requirements });
  } catch (error) {
    console.error('Get custom requirements error:', error);
    res.status(500).json({ success: false, message: 'Failed to load additional requirements.' });
  }
});

router.post('/:requirementId/submit', upload.single('file'), async (req, res) => {
  try {
    const requirementId = Number(req.params.requirementId);
    const fileName = req.file ? req.file.originalname : req.body.fileName;
    const fileUrl = req.file ? req.file.url : null;
    if (!fileName) {
      return res.status(400).json({ success: false, message: 'No file provided.' });
    }

    const owns = await pool.query(
      `SELECT cr.id, cr.due_at FROM custom_requirements cr
       WHERE cr.id = $1 AND ${visibleToStudent(2)}`,
      [requirementId, req.studentId],
    );
    if (owns.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Requirement not found.' });
    }
    // Uploads after the due date and time are accepted but marked late.
    const dueAt = owns.rows[0].due_at;
    const isLate = Boolean(dueAt && Date.now() > new Date(dueAt).getTime());

    const result = await pool.query(
      `INSERT INTO student_custom_requirement_submissions
         (student_id, custom_requirement_id, status, uploaded_file_name, uploaded_file_url, submitted_at, is_late)
       VALUES ($1, $2, 'submitted', $3, $4, now(), $5)
       ON CONFLICT (student_id, custom_requirement_id)
       DO UPDATE SET status = 'submitted', uploaded_file_name = $3,
         uploaded_file_url = $4, submitted_at = now(), updated_at = now(), is_late = $5
       RETURNING *`,
      [req.studentId, requirementId, fileName, fileUrl, isLate],
    );

    try {
      const [studentResult, requirementResult] = await Promise.all([
        pool.query('SELECT name FROM students WHERE id = $1', [req.studentId]),
        pool.query('SELECT title FROM custom_requirements WHERE id = $1', [requirementId]),
      ]);
      const studentName = studentResult.rows[0]?.name;
      const requirementName = requirementResult.rows[0]?.title;
      if (studentName && requirementName) {
        await notifyInstructorForStudent(req.studentId, {
          title: 'Requirement Submitted',
          message: `${studentName} submitted "${requirementName}" for review${isLate ? ' (late)' : ''}.`,
          relatedModule: 'requirements',
        });
      }
    } catch (notifyError) {
      console.error('Notify instructor of custom requirement submission error:', notifyError);
    }

    res.json({ success: true, submission: result.rows[0] });
  } catch (error) {
    console.error('Submit custom requirement error:', error);
    res.status(500).json({ success: false, message: 'Failed to submit document.' });
  }
});

module.exports = router;
