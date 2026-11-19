const express = require('express');
const pool = require('../db');
const { requireInstructorAuth } = require('../middleware/instructorAuth');
const { computeProgressStatus, computeStage } = require('../utils/progressStatus');
const { getCreditedHoursMap } = require('../utils/creditedHours');
const { sendNoticeEmail } = require('../utils/mailer');
const { sendStudentRecords } = require('../utils/studentRecordsReport');

const router = express.Router();
router.use(requireInstructorAuth);

// Shared by the list and detail endpoints: every assigned student, joined
// with what's needed to compute hours/pace/stage. Scoped to this
// instructor's own students only.
async function loadAssignedStudents(instructorId) {
  const studentsResult = await pool.query(
    `SELECT s.id, s.name, s.email, s.course, s.section, s.student_number,
            s.year_level, s.avatar_url, s.required_hours,
            sp.emergency_contact, sp.company_name, sp.company_address,
            sp.company_supervisor_name, sp.company_contact_number,
            sp.ojt_start_date, sp.phone, sp.address, sp.class_id
     FROM students s
     JOIN student_profiles sp ON sp.student_id = s.id
     WHERE sp.adviser_id = $1
     ORDER BY s.name ASC`,
    [instructorId],
  );
  const students = studentsResult.rows;
  if (students.length === 0) return [];

  const hoursByStudent = await getCreditedHoursMap(students.map((s) => s.id));

  return students.map((student) => {
    const hours = hoursByStudent.get(Number(student.id));
    const { completedHours, pendingHours, approvedWeeks } = hours;
    const lastActivityDate = hours.lastSubmittedWeekEnd;
    const requiredHours = Number(student.required_hours);
    const hasStarted = student.ojt_start_date != null;

    return {
      ...student,
      completedHours,
      pendingHours,
      approvedWeeks,
      lastActivityDate,
      requiredHours,
      stage: computeStage({ completedHours, requiredHours, hasStarted }),
      progressStatus: computeProgressStatus({
        completedHours,
        pendingHours,
        requiredHours,
        ojtStartDate: student.ojt_start_date,
        lastActivityDate,
      }),
    };
  });
}

function toSummaryJson(student) {
  return {
    id: Number(student.id),
    name: student.name,
    avatarUrl: student.avatar_url,
    course: student.course,
    section: student.section,
    companyName: student.company_name,
    companyAddress: student.company_address,
    email: student.email,
    studentNumber: student.student_number,
    yearLevel: student.year_level,
    classId: student.class_id != null ? Number(student.class_id) : null,
    phone: student.phone,
    address: student.address,
    contactPerson: student.emergency_contact,
    completedHours: student.completedHours,
    requiredHours: student.requiredHours,
    stage: student.stage,
    progressStatus: student.progressStatus,
  };
}

router.get('/', async (req, res) => {
  try {
    const { search, company, stage, progress, sortBy, sortDir } = req.query;
    let students = await loadAssignedStudents(req.instructorId);

    if (search) {
      const query = search.toString().toLowerCase();
      students = students.filter((s) => s.name.toLowerCase().includes(query));
    }
    if (company) {
      if (company === 'none') {
        students = students.filter((s) => !s.company_name);
      } else {
        students = students.filter((s) => s.company_name === company);
      }
    }
    if (stage) {
      students = students.filter((s) => s.stage === stage);
    }
    if (progress) {
      students = students.filter((s) => s.progressStatus === progress);
    }

    const direction = sortDir === 'desc' ? -1 : 1;
    if (sortBy === 'progress') {
      students.sort(
        (a, b) =>
          direction *
          (a.completedHours / (a.requiredHours || 1) -
            b.completedHours / (b.requiredHours || 1)),
      );
    } else {
      students.sort((a, b) => direction * a.name.localeCompare(b.name));
    }

    res.json({ success: true, students: students.map(toSummaryJson) });
  } catch (error) {
    console.error('Get teacher students error:', error);
    res.status(500).json({ success: false, message: 'Failed to load students.' });
  }
});

// Download the records of all assigned students (System Revisions item
// 14): ?format=xlsx|pdf. Defined before '/:id'.
router.get('/export', async (req, res) => {
  try {
    const format = req.query.format === 'pdf' ? 'pdf' : 'xlsx';
    const [students, instructor] = await Promise.all([
      loadAssignedStudents(req.instructorId),
      pool.query('SELECT name FROM advisers WHERE id = $1', [req.instructorId]),
    ]);
    await sendStudentRecords(res, {
      format,
      students,
      instructorName: instructor.rows[0]?.name || '',
    });
  } catch (error) {
    console.error('Export student records error:', error);
    if (!res.headersSent) {
      res.status(500).json({ success: false, message: 'Failed to export student records.' });
    }
  }
});

// ---------- Registration Requests (System Revisions item 11) ----------
// Students who registered with the code of one of this instructor's
// sections and are waiting for approval. Defined before '/:id' so
// '/requests' isn't captured as a student id.

function toRequestJson(row) {
  return {
    id: Number(row.id),
    name: row.name,
    email: row.email,
    studentNumber: row.student_number,
    yearLevel: row.year_level,
    program: row.program,
    section: row.section,
    classId: Number(row.class_id),
    requestedAt: row.updated_at || row.created_at,
  };
}

router.get('/requests', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT s.id, s.name, s.email, s.student_number, s.year_level, s.created_at, s.updated_at,
              c.id AS class_id, c.program, c.section
       FROM students s
       JOIN student_profiles sp ON sp.student_id = s.id
       JOIN instructor_classes c ON c.id = sp.requested_class_id
       WHERE s.approval_status = 'pending' AND c.instructor_id = $1
       ORDER BY s.updated_at ASC`,
      [req.instructorId],
    );
    res.json({ success: true, requests: result.rows.map(toRequestJson) });
  } catch (error) {
    console.error('Get registration requests error:', error);
    res.status(500).json({ success: false, message: 'Failed to load registration requests.' });
  }
});

// Body: { decision: 'approved' | 'rejected', reason }. A reason is
// required to decline, so the student knows what to fix.
router.patch('/requests/:studentId', async (req, res) => {
  const client = await pool.connect();
  try {
    const studentId = Number(req.params.studentId);
    const { decision } = req.body;
    const reason = (req.body.reason || '').toString().trim();
    if (decision !== 'approved' && decision !== 'rejected') {
      return res
        .status(400)
        .json({ success: false, message: 'decision must be "approved" or "rejected".' });
    }
    if (decision === 'rejected' && !reason) {
      return res
        .status(400)
        .json({ success: false, message: 'Add a reason so the student knows what to fix.' });
    }

    await client.query('BEGIN');
    // FOR UPDATE + the status check stop two instructors (or a
    // double-click) from deciding the same request twice.
    const found = await client.query(
      `SELECT s.id, s.name, s.email, c.id AS class_id, c.program, c.section
       FROM students s
       JOIN student_profiles sp ON sp.student_id = s.id
       JOIN instructor_classes c ON c.id = sp.requested_class_id
       WHERE s.id = $1 AND s.approval_status = 'pending' AND c.instructor_id = $2
       FOR UPDATE OF s`,
      [studentId, req.instructorId],
    );
    if (found.rows.length === 0) {
      await client.query('ROLLBACK');
      return res
        .status(404)
        .json({ success: false, message: 'This request was not found or was already decided.' });
    }
    const request = found.rows[0];

    if (decision === 'approved') {
      await client.query(
        `UPDATE students
         SET approval_status = 'approved', approval_decided_at = now(),
             approval_decided_by = $2, rejection_reason = NULL,
             activated_at = COALESCE(activated_at, now()), updated_at = now()
         WHERE id = $1`,
        [studentId, req.instructorId],
      );
      await client.query(
        `UPDATE student_profiles
         SET class_id = requested_class_id, adviser_id = $2,
             requested_class_id = NULL, updated_at = now()
         WHERE student_id = $1`,
        [studentId, req.instructorId],
      );
    } else {
      await client.query(
        `UPDATE students
         SET approval_status = 'rejected', approval_decided_at = now(),
             approval_decided_by = $2, rejection_reason = $3, updated_at = now()
         WHERE id = $1`,
        [studentId, req.instructorId, reason],
      );
    }
    await client.query('COMMIT');

    // Best effort: tell the student by email (they can't log in to see an
    // in-app notice until approved). SMTP may not be configured.
    try {
      const section = `${request.program} - ${request.section}`;
      if (decision === 'approved') {
        await sendNoticeEmail(
          request.email,
          'Your TRACKIT account was approved',
          `Hi ${request.name},\n\nYour instructor approved your TRACKIT account for ${section}. You can now log in.`,
        );
      } else {
        await sendNoticeEmail(
          request.email,
          'Your TRACKIT registration was declined',
          `Hi ${request.name},\n\nYour instructor declined your TRACKIT registration for ${section}: ${reason}\n\nYou can register again with the correct details.`,
        );
      }
    } catch (mailError) {
      console.error('Registration decision email not sent:', mailError.message);
    }

    res.json({ success: true });
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    console.error('Decide registration request error:', error);
    res.status(500).json({ success: false, message: 'Failed to save decision.' });
  } finally {
    client.release();
  }
});

router.get('/:id', async (req, res) => {
  try {
    const studentId = Number(req.params.id);
    const students = await loadAssignedStudents(req.instructorId);
    // s.id comes straight from a pg BIGINT column, which node-postgres
    // returns as a string -- compare numerically, not by reference type.
    const student = students.find((s) => Number(s.id) === studentId);
    if (!student) {
      return res
        .status(404)
        .json({ success: false, message: 'Student not found or not assigned to you.' });
    }

    const weeklyAverageHours =
      student.approvedWeeks > 0 ? student.completedHours / student.approvedWeeks : 0;
    const averageHoursPerDay = weeklyAverageHours / 5;

    res.json({
      success: true,
      student: {
        id: Number(student.id),
        name: student.name,
        email: student.email,
        course: student.course,
        section: student.section,
        studentNumber: student.student_number,
        yearLevel: student.year_level,
        avatarUrl: student.avatar_url,
        contactPerson: student.emergency_contact,
        phone: student.phone || null,
        address: student.address || null,
        ojtStartDate: student.ojt_start_date || null,
        company: student.company_name
          ? {
              name: student.company_name,
              address: student.company_address,
              supervisorName: student.company_supervisor_name,
              contactNumber: student.company_contact_number,
            }
          : null,
        progress: {
          completedHours: student.completedHours,
          requiredHours: student.requiredHours,
          pendingHours: student.pendingHours,
          approvedWeeks: student.approvedWeeks,
          // Kept for the current app build; now counts approved weeks.
          daysAttended: student.approvedWeeks,
          averageHoursPerDay,
          weeklyAverageHours,
          lastAttendanceDate: student.lastActivityDate,
          lastSubmittedWeekEnd: student.lastActivityDate,
        },
        stage: student.stage,
        progressStatus: student.progressStatus,
      },
    });
  } catch (error) {
    console.error('Get teacher student detail error:', error);
    res.status(500).json({ success: false, message: 'Failed to load student.' });
  }
});

module.exports = router;
// Reused by teacherRequirements.js and teacherAttendance.js so the
// assigned-students query (and its stage/progress computation) never
// drifts across the Document module's screens.
module.exports.loadAssignedStudents = loadAssignedStudents;
