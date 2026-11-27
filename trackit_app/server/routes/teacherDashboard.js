const express = require('express');
const pool = require('../db');
const { requireInstructorAuth } = require('../middleware/instructorAuth');
const { computeStage } = require('../utils/progressStatus');
const { getCreditedHoursMap } = require('../utils/creditedHours');

const router = express.Router();
router.use(requireInstructorAuth);

router.get('/', async (req, res) => {
  try {
    const instructorResult = await pool.query('SELECT name FROM advisers WHERE id = $1', [
      req.instructorId,
    ]);
    if (instructorResult.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Instructor not found.' });
    }
    const instructorName = instructorResult.rows[0].name;

    const studentsResult = await pool.query(
      `SELECT s.id, s.course, s.section, s.required_hours
       FROM students s
       JOIN student_profiles sp ON sp.student_id = s.id
       WHERE sp.adviser_id = $1`,
      [req.instructorId],
    );
    const students = studentsResult.rows;
    // From the sections the Admin assigned (not from students), so a newly
    // assigned instructor with no approved students yet still sees them.
    const assignedClasses = await pool.query(
      `SELECT c.id, c.program, c.section, c.academic_year,
              (SELECT COUNT(*)::int FROM student_profiles sp WHERE sp.class_id = c.id) AS student_count
       FROM instructor_classes c
       WHERE c.instructor_id = $1
       ORDER BY c.program, c.section`,
      [req.instructorId],
    );
    const programs = [...new Set(assignedClasses.rows.map((c) => c.program))];
    const sections = [...new Set(assignedClasses.rows.map((c) => c.section))];
    // Each assigned section with its number of approved students.
    const classes = assignedClasses.rows.map((c) => ({
      id: Number(c.id),
      program: c.program,
      section: c.section,
      academicYear: c.academic_year,
      studentCount: c.student_count,
    }));

    const requestsResult = await pool.query(
      `SELECT COUNT(*)::int AS count
       FROM students s
       JOIN student_profiles sp ON sp.student_id = s.id
       JOIN instructor_classes c ON c.id = sp.requested_class_id
       WHERE s.approval_status = 'pending' AND c.instructor_id = $1`,
      [req.instructorId],
    );
    const registrationRequests = requestsResult.rows[0].count;

    if (students.length === 0) {
      return res.json({
        success: true,
        dashboard: {
          instructorName,
          programs,
          sections,
          classes,
          assignedStudents: 0,
          activeStudents: 0,
          readyForDeployment: 0,
          completedStudents: 0,
          requirementsToReview: 0,
          attendanceCorrections: 0,
          weeklySubmissionsToReview: 0,
          registrationRequests,
        },
      });
    }
    const studentIds = students.map((s) => s.id);

    const hoursByStudent = await getCreditedHoursMap(studentIds);

    const profileResult = await pool.query(
      'SELECT student_id, ojt_start_date FROM student_profiles WHERE student_id = ANY($1::bigint[])',
      [studentIds],
    );
    const startedByStudent = new Map(
      profileResult.rows.map((r) => [r.student_id, r.ojt_start_date != null]),
    );

    let activeStudents = 0;
    let readyForDeployment = 0;
    let completedStudents = 0;
    for (const student of students) {
      const stage = computeStage({
        completedHours: hoursByStudent.get(Number(student.id)).completedHours,
        requiredHours: Number(student.required_hours),
        hasStarted: startedByStudent.get(student.id) || false,
      });
      if (stage === 'completed') completedStudents++;
      else if (stage === 'active') activeStudents++;
      else if (stage === 'readyForDeployment') readyForDeployment++;
    }

    // Retired documents (no longer on the list) aren't waiting for review.
    const reqReviewResult = await pool.query(
      `SELECT COUNT(*) FROM student_requirement_submissions s
       JOIN ojt_requirement_templates t ON t.id = s.requirement_template_id
       WHERE s.student_id = ANY($1::bigint[]) AND s.status = 'submitted' AND t.retired_at IS NULL`,
      [studentIds],
    );
    const correctionsResult = await pool.query(
      `SELECT COUNT(*) FROM attendance_corrections
       WHERE student_id = ANY($1::bigint[]) AND status = 'pending'`,
      [studentIds],
    );
    const weeklyReviewResult = await pool.query(
      `SELECT COUNT(*) FROM activity_reports
       WHERE student_id = ANY($1::bigint[]) AND week_number IS NOT NULL AND status = 'submitted'`,
      [studentIds],
    );

    res.json({
      success: true,
      dashboard: {
        instructorName,
        programs,
        sections,
        classes,
        assignedStudents: students.length,
        activeStudents,
        readyForDeployment,
        completedStudents,
        requirementsToReview: Number(reqReviewResult.rows[0].count),
        attendanceCorrections: Number(correctionsResult.rows[0].count),
        weeklySubmissionsToReview: Number(weeklyReviewResult.rows[0].count),
        registrationRequests,
      },
    });
  } catch (error) {
    console.error('Get teacher dashboard error:', error);
    res.status(500).json({ success: false, message: 'Failed to load dashboard.' });
  }
});

module.exports = router;
