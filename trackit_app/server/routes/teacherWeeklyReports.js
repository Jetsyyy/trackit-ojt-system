const express = require('express');
const pool = require('../db');
const { requireInstructorAuth } = require('../middleware/instructorAuth');
const { loadWeekPlan, buildWeekList, summarize } = require('../utils/weeklySubmissions');
const { loadAssignedStudents } = require('./teacherStudents');

// Weekly DTR/AR review (System Revisions item 13): the assigned instructor
// opens each week's DTR and AR files and approves or rejects the week.
// Only approval adds the week's claimed hours to the student's credited
// total (utils/creditedHours.js).

const router = express.Router();
router.use(requireInstructorAuth);

async function findOwnedStudent(studentId, instructorId) {
  const result = await pool.query(
    `SELECT s.id, s.name, s.avatar_url, s.course, s.section FROM students s
     JOIN student_profiles sp ON sp.student_id = s.id
     WHERE s.id = $1 AND sp.adviser_id = $2`,
    [studentId, instructorId],
  );
  return result.rows[0] || null;
}

function toStudentJson(student) {
  return {
    id: Number(student.id),
    name: student.name,
    avatarUrl: student.avatar_url,
    course: student.course,
    section: student.section,
    studentNumber: student.student_number || null,
    classId: student.class_id != null ? Number(student.class_id) : null,
  };
}

// Every assigned student with their weekly progress, students with weeks
// waiting for review first.
router.get('/students', async (req, res) => {
  try {
    const students = await loadAssignedStudents(req.instructorId);
    const result = [];
    for (const student of students) {
      const plan = await loadWeekPlan(student.id);
      const weeks = await buildWeekList(plan);
      const summary = summarize(plan, weeks);
      result.push({
        ...toStudentJson(student),
        ...summary,
        // Kept for the current app build's list tiles.
        expectedWeeks: summary.totalWeeks,
        submittedWeeks: summary.approvedWeeks + summary.pendingReviewWeeks,
      });
    }
    result.sort(
      (a, b) => b.pendingReviewWeeks - a.pendingReviewWeeks || a.name.localeCompare(b.name),
    );
    res.json({ success: true, students: result });
  } catch (error) {
    console.error('Get teacher weekly submission students error:', error);
    res.status(500).json({ success: false, message: 'Failed to load students.' });
  }
});

router.get('/students/:studentId', async (req, res) => {
  try {
    const studentId = Number(req.params.studentId);
    const student = await findOwnedStudent(studentId, req.instructorId);
    if (!student) {
      return res
        .status(404)
        .json({ success: false, message: 'Student not found or not assigned to you.' });
    }
    const plan = await loadWeekPlan(studentId);
    const reports = await buildWeekList(plan);
    res.json({
      success: true,
      student: toStudentJson(student),
      summary: summarize(plan, reports),
      reports,
    });
  } catch (error) {
    console.error('Get teacher weekly submissions error:', error);
    res.status(500).json({ success: false, message: 'Failed to load weekly submissions.' });
  }
});

// Body: { decision: 'approved' | 'rejected', remarks }. Remarks are
// required when rejecting so the student knows what to fix. Only a week
// that is waiting for review can be decided.
router.patch('/students/:studentId/weeks/:weekNumber', async (req, res) => {
  try {
    const studentId = Number(req.params.studentId);
    const weekNumber = Number(req.params.weekNumber);
    const { decision } = req.body;
    const remarks = (req.body.remarks || '').toString().trim();

    if (decision !== 'approved' && decision !== 'rejected') {
      return res
        .status(400)
        .json({ success: false, message: 'decision must be "approved" or "rejected".' });
    }
    if (decision === 'rejected' && !remarks) {
      return res
        .status(400)
        .json({ success: false, message: 'Add remarks so the student knows what to fix.' });
    }

    const student = await findOwnedStudent(studentId, req.instructorId);
    if (!student) {
      return res
        .status(404)
        .json({ success: false, message: 'Student not found or not assigned to you.' });
    }

    // The status check is in the WHERE clause so two reviewers (or a
    // double-click) can't both decide the same week.
    const updated = await pool.query(
      `UPDATE activity_reports
       SET status = $1, remarks = $2, reviewed_at = now(), reviewed_by = $3, updated_at = now()
       WHERE student_id = $4 AND week_number = $5 AND status = 'submitted'
       RETURNING claimed_hours`,
      [decision, remarks || null, req.instructorId, studentId, weekNumber],
    );
    if (updated.rows.length === 0) {
      return res.status(409).json({
        success: false,
        message: `Week ${weekNumber} is not waiting for review.`,
      });
    }
    const claimedHours = Number(updated.rows[0].claimed_hours);

    const plan = await loadWeekPlan(studentId);
    const reports = await buildWeekList(plan);
    const summary = summarize(plan, reports);

    try {
      const notices = [];
      if (decision === 'approved') {
        notices.push([
          'Weekly DTR/AR Approved',
          `Your Week ${weekNumber} DTR and AR were approved. ${claimedHours} hours were added to your credited hours.`,
        ]);
        if (plan.isComplete && plan.completionWeek === weekNumber) {
          notices.push([
            'OJT Hours Completed',
            `You have completed your required ${plan.requiredHours} OJT hours. No more weekly submissions are needed.`,
          ]);
        }
      } else {
        notices.push([
          'Weekly DTR/AR Returned',
          `Your Week ${weekNumber} DTR and AR were returned: ${remarks}`,
        ]);
      }
      for (const [title, message] of notices) {
        await pool.query(
          `INSERT INTO notifications (receiver_id, category, title, message, related_module)
           VALUES ($1, 'instructor', $2, $3, 'activity_reports')`,
          [studentId, title, message],
        );
      }
    } catch (notifyError) {
      console.error('Notify student of weekly review error:', notifyError);
    }

    res.json({ success: true, student: toStudentJson(student), summary, reports });
  } catch (error) {
    console.error('Review weekly submission error:', error);
    res.status(500).json({ success: false, message: 'Failed to save decision.' });
  }
});

module.exports = router;
