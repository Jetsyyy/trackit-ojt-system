const express = require('express');
const pool = require('../db');
const { requireAdminAuth } = require('../middleware/adminAuth');
const { computeStage, computeProgressStatus } = require('../utils/progressStatus');
const { todayInManila } = require('../utils/manilaTime');
const { getCreditedHoursMap } = require('../utils/creditedHours');

const router = express.Router();
router.use(requireAdminAuth);

// A started student whose latest submitted/approved week ended more than
// this many days ago is flagged "No DTR & AR in the last 2 weeks" (System
// Revisions items 1-3 replaced daily clock in/out with weekly DTR & AR).
const NO_RECENT_SUBMISSION_DAYS = 14;

const MS_PER_DAY = 24 * 60 * 60 * 1000;

function daysAgoInManila(days) {
  const [y, m, d] = todayInManila().split('-').map(Number);
  const todayUtcMidnight = Date.UTC(y, m - 1, d);
  const target = new Date(todayUtcMidnight - days * MS_PER_DAY);
  return target.toISOString().slice(0, 10);
}

// Everything the Admin Overview dashboard shows, for one academic year --
// deliberately one aggregation endpoint (mirroring teacherDashboard.js's
// shape, just school-wide and year-scoped) rather than a call per card, so
// the whole dashboard is one consistent snapshot instead of cards that can
// individually race and disagree with each other.
router.get('/', async (req, res) => {
  try {
    const academicYear = (req.query.academicYear || '').toString().trim();
    if (!academicYear) {
      return res.status(400).json({ success: false, message: 'academicYear is required.' });
    }

    // The full active-student roster for this year in one shot -- avoids
    // N+1 queries for the per-student computations below.
    const rosterResult = await pool.query(
      `SELECT s.id, s.name, s.email, s.student_number, s.required_hours, s.password_hash,
              s.company_id, sp.class_id, sp.ojt_start_date, sp.company_confirmed_at,
              sp.company_name, c.program, c.section, c.instructor_id,
              a.name AS instructor_name
       FROM students s
       JOIN student_profiles sp ON sp.student_id = s.id
       JOIN instructor_classes c ON c.id = sp.class_id
       LEFT JOIN advisers a ON a.id = c.instructor_id
       WHERE c.academic_year = $1
       ORDER BY s.name ASC`,
      [academicYear],
    );
    const roster = rosterResult.rows;
    const studentIds = roster.map((r) => Number(r.id));

    const instructorCountResult = await pool.query(
      `SELECT COUNT(DISTINCT c.instructor_id) AS count
       FROM instructor_classes c
       JOIN advisers a ON a.id = c.instructor_id AND a.status = 'active'
       WHERE c.academic_year = $1`,
      [academicYear],
    );
    const totalInstructors = Number(instructorCountResult.rows[0].count);

    if (studentIds.length === 0) {
      return res.json({
        success: true,
        overview: emptyOverview(academicYear, totalInstructors),
      });
    }

    const recentCutoff = daysAgoInManila(NO_RECENT_SUBMISSION_DAYS);

    const [hoursByStudent, weeklyResult, docsResult, customDocsResult] = await Promise.all([
      getCreditedHoursMap(studentIds),
      // Weekly DTR & AR counts per student; a returned week that the
      // student resubmits goes back to 'submitted', so 'rejected' rows are
      // the ones still waiting on the student.
      pool.query(
        `SELECT student_id,
                COUNT(*) FILTER (WHERE status = 'approved') AS approved,
                COUNT(*) FILTER (WHERE status = 'submitted') AS submitted,
                COUNT(*) FILTER (WHERE status = 'rejected') AS returned
         FROM activity_reports
         WHERE student_id = ANY($1::bigint[]) AND week_number IS NOT NULL
         GROUP BY student_id`,
        [studentIds],
      ),
      pool.query(
        `SELECT srs.id, srs.student_id, s.name AS student_name, ort.name AS requirement_name,
                srs.submitted_at
         FROM student_requirement_submissions srs
         JOIN students s ON s.id = srs.student_id
         JOIN ojt_requirement_templates ort ON ort.id = srs.requirement_template_id
         WHERE srs.student_id = ANY($1::bigint[]) AND srs.status = 'submitted'
         ORDER BY srs.submitted_at ASC`,
        [studentIds],
      ),
      pool.query(
        `SELECT scrs.id, scrs.student_id, s.name AS student_name, cr.title AS requirement_name,
                scrs.submitted_at
         FROM student_custom_requirement_submissions scrs
         JOIN students s ON s.id = scrs.student_id
         JOIN custom_requirements cr ON cr.id = scrs.custom_requirement_id
         WHERE scrs.student_id = ANY($1::bigint[]) AND scrs.status = 'submitted'
         ORDER BY scrs.submitted_at ASC`,
        [studentIds],
      ),
    ]);

    const weeklyByStudent = new Map(
      weeklyResult.rows.map((r) => [
        Number(r.student_id),
        { approved: Number(r.approved), submitted: Number(r.submitted), returned: Number(r.returned) },
      ]),
    );

    let completed = 0;
    let ongoing = 0;
    let notStarted = 0;
    let weeksApproved = 0;
    let weeksAwaitingReview = 0;
    let weeksReturned = 0;
    let studentsAwaitingReview = 0;
    let totalRenderedHours = 0;
    let totalRequiredHours = 0;
    const accountsPreparing = [];
    const companyVerification = [];
    const belowHalfHours = [];
    const noRecentSubmission = [];
    const behindSchedule = [];
    const studentList = [];
    const weeklyList = [];

    for (const row of roster) {
      const id = Number(row.id);
      const requiredHours = Number(row.required_hours);
      const hours = hoursByStudent.get(id);
      const { completedHours, pendingHours } = hours;
      const lastActivityDate = hours.lastSubmittedWeekEnd;
      const hasStarted = row.ojt_start_date != null;
      const isActivated = row.password_hash != null;
      const weekly = weeklyByStudent.get(id) || { approved: 0, submitted: 0, returned: 0 };

      const stage = computeStage({ completedHours, requiredHours, hasStarted });
      const completionBucket =
        stage === 'completed' ? 'completed' : stage === 'notStarted' ? 'notStarted' : 'ongoing';
      if (completionBucket === 'completed') completed++;
      else if (completionBucket === 'ongoing') ongoing++;
      else notStarted++;

      totalRenderedHours += completedHours;
      totalRequiredHours += requiredHours;

      weeksApproved += weekly.approved;
      weeksAwaitingReview += weekly.submitted;
      weeksReturned += weekly.returned;
      if (weekly.submitted > 0) studentsAwaitingReview++;

      const underway = hasStarted && stage !== 'completed';
      // A student who started less than 2 weeks ago can't have a gap yet.
      // DATE columns come back as 'YYYY-MM-DD' text, so they compare as strings.
      const startedBeforeCutoff = hasStarted && row.ojt_start_date <= recentCutoff;
      const noRecent =
        underway && startedBeforeCutoff && (!lastActivityDate || lastActivityDate < recentCutoff);

      let weeklyStatus;
      if (weekly.submitted > 0) weeklyStatus = 'awaitingReview';
      else if (weekly.returned > 0) weeklyStatus = 'returned';
      else if (noRecent) weeklyStatus = 'noRecent';
      else if (!hasStarted) weeklyStatus = 'notStarted';
      else weeklyStatus = 'upToDate';

      if (!isActivated) {
        accountsPreparing.push({
          id,
          name: row.name,
          email: row.email,
          program: row.program,
          section: row.section,
        });
      }

      // System Revisions item 21: the Admin no longer approves the HTE a
      // student enters, so companyVerification always stays empty.

      // At-risk buckets only apply to students actually underway --
      // a student who hasn't started yet isn't "behind," they're simply
      // not started (already its own, non-alarming completion bucket).
      if (underway) {
        if (completedHours < requiredHours * 0.5) {
          belowHalfHours.push({ id, name: row.name });
        }
        if (noRecent) {
          noRecentSubmission.push({ id, name: row.name });
        }
        const progressStatus = computeProgressStatus({
          completedHours,
          pendingHours,
          requiredHours,
          ojtStartDate: row.ojt_start_date,
          lastActivityDate,
        });
        if (progressStatus === 'behind' || progressStatus === 'needsAttention') {
          behindSchedule.push({ id, name: row.name });
        }
      }

      studentList.push({
        id,
        name: row.name,
        program: row.program,
        section: row.section,
        instructorName: row.instructor_name,
        accountStatus: isActivated ? 'activated' : 'pending',
        completionBucket,
        completedHours,
        requiredHours,
      });

      weeklyList.push({
        id,
        name: row.name,
        program: row.program,
        section: row.section,
        instructorName: row.instructor_name,
        status: weeklyStatus,
        approvedWeeks: weekly.approved,
        awaitingReviewWeeks: weekly.submitted,
        returnedWeeks: weekly.returned,
        lastWeekEnd: lastActivityDate,
      });
    }

    const documentsAwaitingReview = [
      ...docsResult.rows.map((r) => ({
        id: `req-${r.id}`,
        studentName: r.student_name,
        requirementName: r.requirement_name,
        submittedAt: r.submitted_at,
      })),
      ...customDocsResult.rows.map((r) => ({
        id: `custom-${r.id}`,
        studentName: r.student_name,
        requirementName: r.requirement_name,
        submittedAt: r.submitted_at,
      })),
    ].sort((a, b) => new Date(a.submittedAt) - new Date(b.submittedAt));

    res.json({
      success: true,
      overview: {
        academicYear,
        totalStudents: roster.length,
        totalInstructors,
        completion: { completed, ongoing, notStarted, total: roster.length },
        weeklyReports: {
          approved: weeksApproved,
          awaitingReview: weeksAwaitingReview,
          returned: weeksReturned,
          studentsAwaitingReview,
        },
        hours: {
          totalRendered: Math.round(totalRenderedHours * 10) / 10,
          totalRequired: totalRequiredHours,
          overallCompletionPercent:
            totalRequiredHours > 0
              ? Math.round((totalRenderedHours / totalRequiredHours) * 1000) / 10
              : 0,
        },
        pendingTasks: {
          accountsPreparing,
          documentsAwaitingReview,
          companyVerification,
        },
        atRisk: { belowHalfHours, noRecentSubmission, behindSchedule },
        studentList,
        weeklyList,
      },
    });
  } catch (error) {
    console.error('Get admin overview error:', error);
    res.status(500).json({ success: false, message: 'Failed to load overview.' });
  }
});

function emptyOverview(academicYear, totalInstructors) {
  return {
    academicYear,
    totalStudents: 0,
    totalInstructors,
    completion: { completed: 0, ongoing: 0, notStarted: 0, total: 0 },
    weeklyReports: { approved: 0, awaitingReview: 0, returned: 0, studentsAwaitingReview: 0 },
    hours: { totalRendered: 0, totalRequired: 0, overallCompletionPercent: 0 },
    pendingTasks: {
      accountsPreparing: [],
      documentsAwaitingReview: [],
      companyVerification: [],
    },
    atRisk: { belowHalfHours: [], noRecentSubmission: [], behindSchedule: [] },
    studentList: [],
    weeklyList: [],
  };
}

module.exports = router;
