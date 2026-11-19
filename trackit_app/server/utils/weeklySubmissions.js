const pool = require('../db');
const { generateWeeks, toDateOnly } = require('./weekSlots');

// Shared by the student's Weekly Submissions endpoints
// (routes/activityReports.js) and the instructor's review endpoints
// (routes/teacherWeeklyReports.js), so both sides always see the same
// weeks, the same files and the same statuses (System Revisions: "The DTR
// and AR submission process must be reflected consistently in the Student
// and Instructor sides").

// Everything needed to list a student's weeks. The OJT period ends at the
// week in which APPROVED hours first reach the required total (item 10);
// until then a new slot opens every week with no fixed cap.
async function loadWeekPlan(studentId) {
  const profileResult = await pool.query(
    `SELECT s.required_hours, sp.ojt_start_date
     FROM students s
     LEFT JOIN student_profiles sp ON sp.student_id = s.id
     WHERE s.id = $1`,
    [studentId],
  );
  const profile = profileResult.rows[0];
  const requiredHours = profile ? Number(profile.required_hours) : 0;
  const ojtStartDate = profile?.ojt_start_date ? toDateOnly(profile.ojt_start_date) : null;

  const rowsResult = await pool.query(
    `SELECT * FROM activity_reports
     WHERE student_id = $1 AND week_number IS NOT NULL
     ORDER BY week_number ASC`,
    [studentId],
  );
  const rows = rowsResult.rows;

  let completedHours = 0;
  let completionWeek = null;
  for (const row of rows) {
    if (row.status !== 'approved') continue;
    completedHours += Number(row.claimed_hours || 0);
    if (completionWeek == null && requiredHours > 0 && completedHours >= requiredHours) {
      completionWeek = row.week_number;
    }
  }

  const weeks = ojtStartDate ? generateWeeks(ojtStartDate, { lastWeek: completionWeek }) : [];
  return {
    ojtStartDate,
    requiredHours,
    completedHours,
    isComplete: completionWeek != null,
    completionWeek,
    weeks,
    rows,
  };
}

async function loadAttachments(reportIds) {
  const byReport = new Map();
  if (reportIds.length === 0) return byReport;
  const result = await pool.query(
    `SELECT * FROM activity_report_attachments
     WHERE activity_report_id = ANY($1::bigint[])
     ORDER BY id ASC`,
    [reportIds],
  );
  for (const a of result.rows) {
    const key = Number(a.activity_report_id);
    const list = byReport.get(key) || [];
    list.push(a);
    byReport.set(key, list);
  }
  return byReport;
}

function toFileJson(a) {
  return { id: Number(a.id), kind: a.kind, fileName: a.file_name, url: a.file_url || null };
}

// Merges generated week slots with the stored submissions. A week with no
// row is 'missing'.
async function buildWeekList(plan) {
  const byWeek = new Map(plan.rows.map((r) => [r.week_number, r]));
  const attachments = await loadAttachments(plan.rows.map((r) => Number(r.id)));

  return plan.weeks.map((week) => {
    const row = byWeek.get(week.weekNumber);
    const files = row ? attachments.get(Number(row.id)) || [] : [];
    return {
      weekNumber: week.weekNumber,
      weekStartDate: week.weekStartDate,
      weekEndDate: week.weekEndDate,
      status: row?.status || 'missing',
      claimedHours: row?.claimed_hours != null ? Number(row.claimed_hours) : null,
      description: row?.description || null,
      dtrFiles: files.filter((f) => f.kind === 'dtr').map(toFileJson),
      arFiles: files.filter((f) => f.kind === 'ar').map(toFileJson),
      // File names only -- kept for the current app build until its
      // weekly screens switch to dtrFiles/arFiles.
      attachments: files.map((f) => f.file_name),
      submittedAt: row?.submitted_at || null,
      reviewedAt: row?.reviewed_at || null,
      remarks: row?.remarks || null,
    };
  });
}

function summarize(plan, weekList) {
  const count = (status) => weekList.filter((w) => w.status === status).length;
  const pendingHours = weekList
    .filter((w) => w.status === 'submitted')
    .reduce((sum, w) => sum + (w.claimedHours || 0), 0);
  return {
    ojtStartDate: plan.ojtStartDate,
    requiredHours: plan.requiredHours,
    completedHours: plan.completedHours,
    pendingHours,
    isComplete: plan.isComplete,
    totalWeeks: weekList.length,
    approvedWeeks: count('approved'),
    pendingReviewWeeks: count('submitted'),
    rejectedWeeks: count('rejected'),
    missingWeeks: count('missing'),
  };
}

module.exports = { loadWeekPlan, buildWeekList, summarize };
