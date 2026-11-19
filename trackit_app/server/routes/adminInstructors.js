const express = require('express');
const pool = require('../db');
const { requireAdminAuth } = require('../middleware/adminAuth');
const {
  generateInstructorActivationCode,
  generateInstructorRegistrationCode,
} = require('../utils/activationCode');
const { sendNoticeEmail } = require('../utils/mailer');
const { getCurrentAcademicYear, loadClassStudents } = require('../utils/classHelpers');

const router = express.Router();
router.use(requireAdminAuth);

// Instructor identity isn't year-scoped (unlike a section), so the list
// always shows every instructor regardless of the Academic Year picker
// -- only a given instructor's *assignment* (below, in the detail
// endpoint) is filtered by year.
router.get('/', async (req, res) => {
  try {
    const { search } = req.query;
    // Pending/declined self-registrations live under /requests, not the
    // faculty list.
    const params = [];
    let where = `WHERE approval_status = 'approved'`;
    if (search) {
      params.push(`%${search.toString().toLowerCase()}%`);
      where += ` AND (LOWER(name) LIKE $1 OR LOWER(instructor_number) LIKE $1)`;
    }
    const result = await pool.query(
      `SELECT id, name, instructor_number, photo_url, status, password_hash IS NOT NULL AS is_activated
       FROM advisers
       ${where}
       ORDER BY name ASC`,
      params,
    );
    res.json({
      success: true,
      instructors: result.rows.map((row) => ({
        id: Number(row.id),
        name: row.name,
        instructorNumber: row.instructor_number,
        avatarUrl: row.photo_url,
        status: row.status,
        accountStatus: row.is_activated ? 'activated' : 'pending',
      })),
    });
  } catch (error) {
    console.error('Get admin instructors error:', error);
    res.status(500).json({ success: false, message: 'Failed to load instructors.' });
  }
});

const DEPARTMENT_DEFAULT = 'Department of Computing Sciences and Engineering';

// Admin creates the account (no password yet -- Pending) and its real
// Instructor Activation Code immediately, mirroring Import Students:
// the instructor claims it themselves later by registering with the
// code (see routes/instructorAuth.js), which is the only way
// password_hash ever gets set from here on.
router.post('/', async (req, res) => {
  try {
    const { name, email, phone, department, position, dateHired } = req.body;
    if (!name || !name.toString().trim()) {
      return res.status(400).json({ success: false, message: 'Full name is required.' });
    }
    if (!email || !email.toString().trim()) {
      return res.status(400).json({ success: false, message: 'Email is required.' });
    }

    const normalizedEmail = email.toString().toLowerCase().trim();
    const existing = await pool.query('SELECT id FROM advisers WHERE email = $1', [
      normalizedEmail,
    ]);
    if (existing.rows.length > 0) {
      return res
        .status(409)
        .json({ success: false, message: 'An instructor with this email already exists.' });
    }

    const sequenceResult = await pool.query(
      `SELECT COALESCE(MAX(SUBSTRING(instructor_number FROM 'DCSE-(\\d+)')::int), 0) + 1 AS next
       FROM advisers`,
    );
    const instructorNumber = `DCSE-${String(sequenceResult.rows[0].next).padStart(3, '0')}`;
    const activationCode = await generateInstructorActivationCode();

    const inserted = await pool.query(
      `INSERT INTO advisers
         (name, email, phone, position, department, date_hired, instructor_number, activation_code)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING id, name, instructor_number, photo_url, status`,
      [
        name.toString().trim(),
        normalizedEmail,
        (phone || '').toString().trim(),
        (position || 'OJT Adviser').toString().trim(),
        (department || DEPARTMENT_DEFAULT).toString().trim(),
        dateHired || null,
        instructorNumber,
        activationCode,
      ],
    );
    const row = inserted.rows[0];

    res.status(201).json({
      success: true,
      instructor: {
        id: Number(row.id),
        name: row.name,
        instructorNumber: row.instructor_number,
        avatarUrl: row.photo_url,
        status: row.status,
        accountStatus: 'pending',
      },
    });
  } catch (error) {
    console.error('Create instructor error:', error);
    res.status(500).json({ success: false, message: 'Failed to create instructor.' });
  }
});

async function loadAssignedSectionsAndStudents(instructorId, academicYear) {
  const params = [instructorId];
  let where = 'WHERE c.instructor_id = $1';
  if (academicYear) {
    params.push(academicYear);
    where += ' AND c.academic_year = $2';
  }
  const classesResult = await pool.query(
    `SELECT c.id, c.program, c.section, c.academic_year,
            COUNT(sp.student_id)::int AS student_count
     FROM instructor_classes c
     LEFT JOIN student_profiles sp ON sp.class_id = c.id
     ${where}
     GROUP BY c.id
     ORDER BY c.program ASC, c.section ASC`,
    params,
  );

  const assignedSections = classesResult.rows.map((row) => ({
    id: Number(row.id),
    program: row.program,
    section: row.section,
    academicYear: row.academic_year,
    studentCount: row.student_count,
  }));

  const enrolledStudents = [];
  for (const section of assignedSections) {
    const students = await loadClassStudents(section.id);
    for (const student of students) {
      enrolledStudents.push({
        ...student,
        section: `${section.program} - ${section.section}`,
      });
    }
  }

  return { assignedSections, enrolledStudents };
}

// ---------- Instructor registration codes (System Revisions item 19) ----------
// The admin generates a single-use code and gives it to one instructor,
// who registers with their own details (routes/instructorAuth.js). These
// routes are defined before '/:id' so their paths aren't read as an id.

function toCodeJson(row) {
  let status = 'available';
  if (row.revoked_at) status = 'revoked';
  else if (row.used_at) status = 'used';
  return {
    id: Number(row.id),
    code: row.code,
    note: row.note,
    status,
    createdAt: row.created_at,
    usedAt: row.used_at,
    usedByName: row.used_by_name || null,
  };
}

router.get('/registration-codes', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT rc.*, a.name AS used_by_name
       FROM instructor_registration_codes rc
       LEFT JOIN advisers a ON a.id = rc.used_by
       ORDER BY rc.created_at DESC
       LIMIT 200`,
    );
    res.json({ success: true, codes: result.rows.map(toCodeJson) });
  } catch (error) {
    console.error('Get instructor registration codes error:', error);
    res.status(500).json({ success: false, message: 'Failed to load registration codes.' });
  }
});

// Body: { note } -- optional label, e.g. who the code is for.
router.post('/registration-codes', async (req, res) => {
  try {
    const note = (req.body.note || '').toString().trim() || null;
    const code = await generateInstructorRegistrationCode();
    const inserted = await pool.query(
      `INSERT INTO instructor_registration_codes (code, note, created_by)
       VALUES ($1, $2, $3)
       RETURNING *`,
      [code, note, req.adminId ?? null],
    );
    res.status(201).json({ success: true, code: toCodeJson(inserted.rows[0]) });
  } catch (error) {
    console.error('Create instructor registration code error:', error);
    res.status(500).json({ success: false, message: 'Failed to generate a code.' });
  }
});

router.patch('/registration-codes/:codeId/revoke', async (req, res) => {
  try {
    const result = await pool.query(
      `UPDATE instructor_registration_codes SET revoked_at = now()
       WHERE id = $1 AND used_at IS NULL AND revoked_at IS NULL
       RETURNING *`,
      [Number(req.params.codeId)],
    );
    if (result.rows.length === 0) {
      return res
        .status(409)
        .json({ success: false, message: 'This code was already used or revoked.' });
    }
    res.json({ success: true, code: toCodeJson(result.rows[0]) });
  } catch (error) {
    console.error('Revoke instructor registration code error:', error);
    res.status(500).json({ success: false, message: 'Failed to revoke the code.' });
  }
});

// ---------- Instructor account requests ----------

router.get('/requests', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, name, email, phone, instructor_number, department, position, created_at
       FROM advisers
       WHERE approval_status = 'pending'
       ORDER BY created_at ASC`,
    );
    res.json({
      success: true,
      requests: result.rows.map((row) => ({
        id: Number(row.id),
        name: row.name,
        email: row.email,
        phone: row.phone,
        instructorNumber: row.instructor_number,
        department: row.department,
        position: row.position,
        requestedAt: row.created_at,
      })),
    });
  } catch (error) {
    console.error('Get instructor requests error:', error);
    res.status(500).json({ success: false, message: 'Failed to load instructor requests.' });
  }
});

// Body: { decision: 'approved' | 'rejected', sectionIds: number[], reason }.
// Approving requires at least one section; only sections with no
// instructor yet can be assigned here, so approving never silently takes
// a section away from another instructor. Declining requires a reason.
router.patch('/requests/:id', async (req, res) => {
  const client = await pool.connect();
  try {
    const instructorId = Number(req.params.id);
    const { decision } = req.body;
    const reason = (req.body.reason || '').toString().trim();
    const sectionIds = Array.isArray(req.body.sectionIds)
      ? [...new Set(req.body.sectionIds.map(Number).filter(Number.isFinite))]
      : [];

    if (decision !== 'approved' && decision !== 'rejected') {
      return res
        .status(400)
        .json({ success: false, message: 'decision must be "approved" or "rejected".' });
    }
    if (decision === 'approved' && sectionIds.length === 0) {
      return res
        .status(400)
        .json({ success: false, message: 'Assign at least one section before approving.' });
    }
    if (decision === 'rejected' && !reason) {
      return res
        .status(400)
        .json({ success: false, message: 'Add a reason for declining.' });
    }

    await client.query('BEGIN');
    const found = await client.query(
      `SELECT id, name, email FROM advisers
       WHERE id = $1 AND approval_status = 'pending'
       FOR UPDATE`,
      [instructorId],
    );
    if (found.rows.length === 0) {
      await client.query('ROLLBACK');
      return res
        .status(404)
        .json({ success: false, message: 'This request was not found or was already decided.' });
    }
    const instructor = found.rows[0];

    if (decision === 'approved') {
      const assigned = await client.query(
        `UPDATE instructor_classes SET instructor_id = $1
         WHERE id = ANY($2::bigint[]) AND instructor_id IS NULL
         RETURNING id`,
        [instructorId, sectionIds],
      );
      if (assigned.rows.length !== sectionIds.length) {
        await client.query('ROLLBACK');
        return res.status(409).json({
          success: false,
          message:
            'One or more of those sections already has an instructor. Refresh and pick unassigned sections.',
        });
      }
      await client.query(
        `UPDATE advisers
         SET approval_status = 'approved', approval_decided_at = now(),
             rejection_reason = NULL, activated_at = COALESCE(activated_at, now())
         WHERE id = $1`,
        [instructorId],
      );
    } else {
      await client.query(
        `UPDATE advisers
         SET approval_status = 'rejected', approval_decided_at = now(), rejection_reason = $2
         WHERE id = $1`,
        [instructorId, reason],
      );
    }
    await client.query('COMMIT');

    try {
      if (decision === 'approved') {
        await sendNoticeEmail(
          instructor.email,
          'Your TRACKIT instructor account was approved',
          `Hi ${instructor.name},\n\nYour TRACKIT instructor account was approved. You can now log in.`,
        );
      } else {
        await sendNoticeEmail(
          instructor.email,
          'Your TRACKIT instructor registration was declined',
          `Hi ${instructor.name},\n\nYour TRACKIT instructor registration was declined: ${reason}`,
        );
      }
    } catch (mailError) {
      console.error('Instructor decision email not sent:', mailError.message);
    }

    res.json({ success: true });
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    console.error('Decide instructor request error:', error);
    res.status(500).json({ success: false, message: 'Failed to save decision.' });
  } finally {
    client.release();
  }
});

router.get('/:id', async (req, res) => {
  try {
    const instructorId = Number(req.params.id);
    const result = await pool.query('SELECT * FROM advisers WHERE id = $1', [instructorId]);
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Instructor not found.' });
    }
    const row = result.rows[0];

    const academicYear = req.query.academicYear
      ? req.query.academicYear.toString()
      : await getCurrentAcademicYear();
    const { assignedSections, enrolledStudents } = await loadAssignedSectionsAndStudents(
      instructorId,
      academicYear,
    );

    res.json({
      success: true,
      instructor: {
        id: Number(row.id),
        name: row.name,
        instructorNumber: row.instructor_number,
        avatarUrl: row.photo_url,
        status: row.status,
        email: row.email,
        phone: row.phone,
        department: row.department,
        position: row.position,
        dateHired: row.date_hired,
        activationCode: row.activation_code,
        activationCodeCreatedAt: row.activation_code_created_at,
        accountStatus: row.password_hash ? 'activated' : 'pending',
        activatedAt: row.activated_at,
        lastLoginAt: row.last_login_at,
        academicYear,
        assignedSections,
        enrolledStudents,
        totalEnrolled: enrolledStudents.length,
      },
    });
  } catch (error) {
    console.error('Get admin instructor detail error:', error);
    res.status(500).json({ success: false, message: 'Failed to load instructor.' });
  }
});

router.patch('/:id', async (req, res) => {
  try {
    const instructorId = Number(req.params.id);
    const { name, email, phone, department, position, dateHired } = req.body;

    if (email !== undefined) {
      const normalizedEmail = email.toString().toLowerCase().trim();
      const existing = await pool.query('SELECT id FROM advisers WHERE email = $1 AND id != $2', [
        normalizedEmail,
        instructorId,
      ]);
      if (existing.rows.length > 0) {
        return res
          .status(409)
          .json({ success: false, message: 'An instructor with this email already exists.' });
      }
    }

    const updated = await pool.query(
      `UPDATE advisers
       SET name = COALESCE($1, name),
           email = COALESCE($2, email),
           phone = COALESCE($3, phone),
           department = COALESCE($4, department),
           position = COALESCE($5, position),
           date_hired = COALESCE($6, date_hired)
       WHERE id = $7
       RETURNING id, name, instructor_number, photo_url, status`,
      [
        name?.toString().trim(),
        email !== undefined ? email.toString().toLowerCase().trim() : undefined,
        phone?.toString().trim(),
        department?.toString().trim(),
        position?.toString().trim(),
        dateHired,
        instructorId,
      ],
    );
    if (updated.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Instructor not found.' });
    }
    res.json({ success: true });
  } catch (error) {
    console.error('Update instructor error:', error);
    res.status(500).json({ success: false, message: 'Failed to update instructor.' });
  }
});

// Real enforcement, not cosmetic -- requireInstructorAuth checks `status`
// on every request too, so a revoked instructor's existing token stops
// working immediately (see routes/instructorAuth.js / middleware).
router.patch('/:id/revoke', async (req, res) => {
  try {
    const instructorId = Number(req.params.id);
    const result = await pool.query(
      `UPDATE advisers SET status = 'inactive' WHERE id = $1 RETURNING id`,
      [instructorId],
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Instructor not found.' });
    }
    res.json({ success: true });
  } catch (error) {
    console.error('Revoke instructor error:', error);
    res.status(500).json({ success: false, message: 'Failed to revoke access.' });
  }
});

router.patch('/:id/reactivate', async (req, res) => {
  try {
    const instructorId = Number(req.params.id);
    const result = await pool.query(
      `UPDATE advisers SET status = 'active' WHERE id = $1 RETURNING id`,
      [instructorId],
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Instructor not found.' });
    }
    res.json({ success: true });
  } catch (error) {
    console.error('Reactivate instructor error:', error);
    res.status(500).json({ success: false, message: 'Failed to reactivate.' });
  }
});

router.patch('/:id/regenerate-code', async (req, res) => {
  try {
    const instructorId = Number(req.params.id);
    const code = await generateInstructorActivationCode();
    const result = await pool.query(
      `UPDATE advisers
       SET activation_code = $1, activation_code_created_at = now()
       WHERE id = $2
       RETURNING activation_code, activation_code_created_at`,
      [code, instructorId],
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Instructor not found.' });
    }
    res.json({
      success: true,
      activationCode: result.rows[0].activation_code,
      activationCodeCreatedAt: result.rows[0].activation_code_created_at,
    });
  } catch (error) {
    console.error('Regenerate instructor code error:', error);
    res.status(500).json({ success: false, message: 'Failed to regenerate code.' });
  }
});

module.exports = router;
