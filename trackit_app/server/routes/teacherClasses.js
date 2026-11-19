const express = require('express');
const pool = require('../db');
const { requireInstructorAuth } = require('../middleware/instructorAuth');

const router = express.Router();
router.use(requireInstructorAuth);

// The instructor's assigned sections. Sections are created by the Admin
// and assigned when approving the instructor (System Revisions item 19:
// "Newly registered instructors will not select or set their own
// section"), so there is no create route here.
router.get('/', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT c.*, COUNT(sp.student_id) AS student_count
       FROM instructor_classes c
       LEFT JOIN student_profiles sp ON sp.class_id = c.id
       WHERE c.instructor_id = $1
       GROUP BY c.id
       ORDER BY c.created_at DESC`,
      [req.instructorId],
    );
    res.json({
      success: true,
      classes: result.rows.map((row) => ({
        id: Number(row.id),
        program: row.program,
        section: row.section,
        academicYear: row.academic_year,
        activationCode: row.activation_code,
        studentCount: Number(row.student_count),
      })),
    });
  } catch (error) {
    console.error('Get classes error:', error);
    res.status(500).json({ success: false, message: 'Failed to load classes.' });
  }
});

module.exports = router;
