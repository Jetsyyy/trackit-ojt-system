// Scheduled requirements from the OJT office (migration 33): the admin
// posts e.g. "Supervisor Evaluation Form" for "1st Semester" with a due
// date and time; every OJT student of the academic year gets it, with a
// notification now and a reminder the day before.
const express = require('express');
const multer = require('multer');
const pool = require('../db');
const { requireAdminAuth } = require('../middleware/adminAuth');
const { uploadStorage, removeStored } = require('../utils/storage');
const { requirementFileFilter } = require('../utils/requirementFileTypes');
const { getCurrentAcademicYear } = require('../utils/classHelpers');
const { formatDue, phDate, STUDENTS_OF_YEAR, notifyStudentsOfYear, sendDueReminders } = require('../utils/scheduledRequirements');

const router = express.Router();
router.use(requireAdminAuth);

const upload = multer({
  storage: uploadStorage('requirements/templates'),
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: requirementFileFilter,
});

const clean = (v) => (v == null ? '' : v.toString().trim());

function parseDue(value) {
  const d = new Date(clean(value));
  return Number.isNaN(d.getTime()) ? null : d;
}

function toJson(r) {
  return {
    id: Number(r.id),
    title: r.title,
    period: r.period || '',
    description: r.description || '',
    academicYear: r.academic_year,
    dueAt: r.due_at,
    templateUrl: r.template_url || null,
    templateName: r.template_name || null,
    templateSize: r.template_size != null ? Number(r.template_size) : null,
    createdAt: r.created_at,
    updatedAt: r.updated_at || null,
    reminderSentAt: r.reminder_sent_at || null,
    totalStudents: r.total_students != null ? Number(r.total_students) : undefined,
    submitted: r.submitted != null ? Number(r.submitted) : undefined,
    approved: r.approved != null ? Number(r.approved) : undefined,
    late: r.late != null ? Number(r.late) : undefined,
  };
}

// ?academicYear= (default: the active year), soonest due first.
router.get('/', async (req, res) => {
  try {
    sendDueReminders().catch((e) => console.error('Due reminders error:', e.message));
    const academicYear = clean(req.query.academicYear) || (await getCurrentAcademicYear());
    const result = await pool.query(
      `SELECT cr.*,
         (SELECT COUNT(*) FROM (${STUDENTS_OF_YEAR}) x) AS total_students,
         (SELECT COUNT(*) FROM student_custom_requirement_submissions s
            WHERE s.custom_requirement_id = cr.id AND s.status IN ('submitted', 'approved')) AS submitted,
         (SELECT COUNT(*) FROM student_custom_requirement_submissions s
            WHERE s.custom_requirement_id = cr.id AND s.status = 'approved') AS approved,
         (SELECT COUNT(*) FROM student_custom_requirement_submissions s
            WHERE s.custom_requirement_id = cr.id AND s.is_late) AS late
       FROM custom_requirements cr
       WHERE cr.audience = 'all_students' AND cr.academic_year = $1
       ORDER BY cr.due_at ASC NULLS LAST, cr.id ASC`,
      [academicYear],
    );
    res.json({ success: true, academicYear, requirements: result.rows.map(toJson) });
  } catch (error) {
    console.error('Get scheduled requirements error:', error);
    res.status(500).json({ success: false, message: 'Failed to load scheduled requirements.' });
  }
});

// Every student of the year with their submission for this requirement.
router.get('/:id/submissions', async (req, res) => {
  try {
    const found = await pool.query(
      `SELECT * FROM custom_requirements WHERE id = $1 AND audience = 'all_students'`,
      [Number(req.params.id)],
    );
    const r = found.rows[0];
    if (!r) return res.status(404).json({ success: false, message: 'Requirement not found.' });
    const rows = await pool.query(
      `SELECT s.id, s.name, s.student_number, ic.program, ic.section,
              scs.status, scs.submitted_at, scs.is_late, scs.uploaded_file_name, scs.uploaded_file_url
       FROM students s
       JOIN student_profiles sp ON sp.student_id = s.id
       JOIN instructor_classes ic ON ic.id = sp.class_id
       LEFT JOIN student_custom_requirement_submissions scs
         ON scs.student_id = s.id AND scs.custom_requirement_id = $2
       WHERE s.approval_status = 'approved' AND ic.academic_year = $1
       ORDER BY ic.program, ic.section, s.name`,
      [r.academic_year, r.id],
    );
    res.json({
      success: true,
      students: rows.rows.map((x) => ({
        id: Number(x.id),
        name: x.name,
        studentNumber: x.student_number,
        section: `${x.program || ''}-${x.section || ''}`.replace(/^-|-$/g, ''),
        status: x.status || 'missing',
        submittedAt: x.submitted_at,
        isLate: Boolean(x.is_late),
        fileName: x.uploaded_file_name,
        fileUrl: x.uploaded_file_url,
      })),
    });
  } catch (error) {
    console.error('Get scheduled requirement submissions error:', error);
    res.status(500).json({ success: false, message: 'Failed to load submissions.' });
  }
});

// Multipart: title, period, description, dueAt (ISO), optional academicYear
// (default: the active one), optional `template` file.
router.post('/', upload.single('template'), async (req, res) => {
  try {
    const title = clean(req.body.title);
    const period = clean(req.body.period);
    const dueAt = parseDue(req.body.dueAt);
    if (!title || !period) {
      if (req.file) removeStored(req.file.url);
      return res.status(400).json({ success: false, message: 'Enter the requirement name and its period.' });
    }
    if (!dueAt || dueAt.getTime() <= Date.now()) {
      if (req.file) removeStored(req.file.url);
      return res.status(400).json({ success: false, message: 'Choose a due date and time in the future.' });
    }
    // Defaults to the active academic year.
    const academicYear = clean(req.body.academicYear) || (await getCurrentAcademicYear());
    if (!/^\d{4}-\d{4}$/.test(academicYear)) {
      if (req.file) removeStored(req.file.url);
      return res.status(400).json({ success: false, message: 'Choose a valid academic year.' });
    }
    const inserted = await pool.query(
      `INSERT INTO custom_requirements
         (admin_id, audience, academic_year, title, period, description, due_at, deadline,
          template_url, template_name, template_size, updated_at)
       VALUES ($1, 'all_students', $2, $3, $4, $5, $6, $7, $8, $9, $10, now())
       RETURNING *`,
      [
        req.adminId,
        academicYear,
        title,
        period,
        clean(req.body.description),
        dueAt,
        phDate(dueAt),
        req.file ? req.file.url : null,
        req.file ? req.file.originalname : null,
        req.file ? req.file.size : null,
      ],
    );
    const r = inserted.rows[0];
    try {
      await notifyStudentsOfYear(
        academicYear,
        `New requirement: ${title}`,
        `The OJT office posted "${title}" for ${period}. Upload it by ${formatDue(dueAt)} in Documents > Scheduled Requirements.`,
      );
    } catch (notifyError) {
      console.error('Notify students of scheduled requirement error:', notifyError.message);
    }
    res.status(201).json({ success: true, requirement: toJson(r) });
  } catch (error) {
    if (req.file) removeStored(req.file.url);
    console.error('Create scheduled requirement error:', error);
    res.status(500).json({ success: false, message: 'Failed to post the requirement.' });
  }
});

// Multipart: any of title, period, description, dueAt, `template` file.
// A new due date re-arms the day-before reminder and tells the students.
router.patch('/:id', upload.single('template'), async (req, res) => {
  const id = Number(req.params.id);
  try {
    const found = await pool.query(`SELECT * FROM custom_requirements WHERE id = $1 AND audience = 'all_students'`, [id]);
    const current = found.rows[0];
    if (!current) {
      if (req.file) removeStored(req.file.url);
      return res.status(404).json({ success: false, message: 'Requirement not found.' });
    }
    const title = req.body.title !== undefined ? clean(req.body.title) : current.title;
    const period = req.body.period !== undefined ? clean(req.body.period) : current.period;
    if (!title || !period) {
      if (req.file) removeStored(req.file.url);
      return res.status(400).json({ success: false, message: 'Enter the requirement name and its period.' });
    }
    let dueAt = current.due_at;
    if (req.body.dueAt !== undefined) {
      dueAt = parseDue(req.body.dueAt);
      if (!dueAt) {
        if (req.file) removeStored(req.file.url);
        return res.status(400).json({ success: false, message: 'Choose a valid due date and time.' });
      }
    }
    const dueChanged = new Date(dueAt).getTime() !== new Date(current.due_at).getTime();
    const updated = await pool.query(
      `UPDATE custom_requirements
       SET title = $2, period = $3, description = $4, due_at = $5, deadline = $6,
           reminder_sent_at = CASE WHEN $7 THEN NULL ELSE reminder_sent_at END,
           template_url = COALESCE($8, template_url), template_name = COALESCE($9, template_name),
           template_size = COALESCE($10, template_size), updated_at = now()
       WHERE id = $1 RETURNING *`,
      [
        id,
        title,
        period,
        req.body.description !== undefined ? clean(req.body.description) : current.description,
        dueAt,
        phDate(dueAt),
        dueChanged,
        req.file ? req.file.url : null,
        req.file ? req.file.originalname : null,
        req.file ? req.file.size : null,
      ],
    );
    if (req.file && current.template_url) removeStored(current.template_url);
    if (dueChanged) {
      try {
        await notifyStudentsOfYear(
          current.academic_year,
          `New due date: ${title}`,
          `"${title}" (${period}) is now due ${formatDue(dueAt)}.`,
        );
      } catch (notifyError) {
        console.error('Notify students of new due date error:', notifyError.message);
      }
    }
    res.json({ success: true, requirement: toJson(updated.rows[0]) });
  } catch (error) {
    if (req.file) removeStored(req.file.url);
    console.error('Update scheduled requirement error:', error);
    res.status(500).json({ success: false, message: 'Failed to save the requirement.' });
  }
});

router.delete('/:id/template', async (req, res) => {
  try {
    const result = await pool.query(
      `UPDATE custom_requirements cr SET template_url = NULL, template_name = NULL, template_size = NULL, updated_at = now()
       FROM (SELECT id, template_url FROM custom_requirements WHERE id = $1 AND audience = 'all_students') old
       WHERE cr.id = old.id RETURNING old.template_url`,
      [Number(req.params.id)],
    );
    if (result.rows.length === 0) return res.status(404).json({ success: false, message: 'Requirement not found.' });
    removeStored(result.rows[0].template_url);
    res.json({ success: true });
  } catch (error) {
    console.error('Remove scheduled template error:', error);
    res.status(500).json({ success: false, message: 'Failed to remove the template.' });
  }
});

// Removes the requirement and the students' uploads for it.
router.delete('/:id', async (req, res) => {
  try {
    const id = Number(req.params.id);
    const files = await pool.query(
      'SELECT uploaded_file_url FROM student_custom_requirement_submissions WHERE custom_requirement_id = $1',
      [id],
    );
    const deleted = await pool.query(
      `DELETE FROM custom_requirements WHERE id = $1 AND audience = 'all_students' RETURNING template_url`,
      [id],
    );
    if (deleted.rows.length === 0) return res.status(404).json({ success: false, message: 'Requirement not found.' });
    removeStored(deleted.rows[0].template_url);
    for (const f of files.rows) removeStored(f.uploaded_file_url);
    res.json({ success: true });
  } catch (error) {
    console.error('Delete scheduled requirement error:', error);
    res.status(500).json({ success: false, message: 'Failed to delete the requirement.' });
  }
});

module.exports = router;
