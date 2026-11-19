const pool = require('../db');

// The one place credited OJT hours are computed (System Revisions items
// 3, 9, 13). Credited hours are the claimed hours of weekly DTR/AR
// submissions the assigned instructor has APPROVED -- nothing else
// counts. Pending (submitted) hours are reported separately so screens
// can show "X hrs awaiting approval" without ever adding them to the
// total. Every route that shows a student's hours goes through here so
// the number is identical on the student, instructor and admin sides.

function emptyHours() {
  return {
    completedHours: 0,
    pendingHours: 0,
    approvedWeeks: 0,
    submittedWeeks: 0,
    lastSubmittedWeekEnd: null,
    lastApprovedWeekHours: 0,
  };
}

// Returns Map<number studentId, hours> -- every requested id is present,
// zero-filled when the student has no submissions yet.
async function getCreditedHoursMap(studentIds) {
  const ids = [...new Set(studentIds.map(Number))];
  const map = new Map(ids.map((id) => [id, emptyHours()]));
  if (ids.length === 0) return map;

  const result = await pool.query(
    `SELECT student_id,
       COALESCE(SUM(claimed_hours) FILTER (WHERE status = 'approved'), 0) AS completed_hours,
       COALESCE(SUM(claimed_hours) FILTER (WHERE status = 'submitted'), 0) AS pending_hours,
       COUNT(*) FILTER (WHERE status = 'approved') AS approved_weeks,
       COUNT(*) FILTER (WHERE status = 'submitted') AS submitted_weeks,
       MAX(week_end_date) FILTER (WHERE status IN ('submitted', 'approved')) AS last_submitted_week_end,
       (ARRAY_AGG(claimed_hours ORDER BY week_number DESC)
          FILTER (WHERE status = 'approved'))[1] AS last_approved_week_hours
     FROM activity_reports
     WHERE student_id = ANY($1::bigint[]) AND week_number IS NOT NULL
     GROUP BY student_id`,
    [ids],
  );

  for (const row of result.rows) {
    map.set(Number(row.student_id), {
      completedHours: Number(row.completed_hours),
      pendingHours: Number(row.pending_hours),
      approvedWeeks: Number(row.approved_weeks),
      submittedWeeks: Number(row.submitted_weeks),
      lastSubmittedWeekEnd: row.last_submitted_week_end,
      lastApprovedWeekHours: Number(row.last_approved_week_hours || 0),
    });
  }
  return map;
}

async function getCreditedHours(studentId) {
  const map = await getCreditedHoursMap([studentId]);
  return map.get(Number(studentId));
}

module.exports = { getCreditedHours, getCreditedHoursMap };
