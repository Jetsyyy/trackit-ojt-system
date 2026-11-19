// Shared by every route that shows a student's pace badge (student
// progress, Teacher Students tab/dashboard, Admin Overview) so On Track /
// Behind / Needs Attention / Ahead of Schedule / Completed means exactly
// the same thing everywhere it's shown.
//
// Hours arrive weekly now (DTR/AR submissions, see utils/creditedHours.js),
// so pace is judged per completed OJT week, not per day.

// Assumed OJT work pace (Mon-Fri, 8hr/day) used to derive an "expected
// hours by now" baseline from ojt_start_date, since there's no separate
// target-hours-per-week field. Only used for the status badge.
const ASSUMED_HOURS_PER_WEEK = 40;

// A student whose last submitted week ended this many days ago (or more)
// has skipped at least one whole weekly submission.
const MISSED_SUBMISSION_DAYS = 14;

const MS_PER_DAY = 24 * 60 * 60 * 1000;

// completedHours: approved (credited) hours -- decides 'completed'.
// pendingHours: submitted, awaiting instructor approval. Counted toward
//   PACE only, so a student isn't marked "Behind" just because their
//   instructor hasn't reviewed last week yet.
// lastActivityDate: end date of the student's most recent submitted or
//   approved week.
function computeProgressStatus({
  completedHours,
  pendingHours = 0,
  requiredHours,
  ojtStartDate,
  lastActivityDate,
}) {
  if (completedHours >= requiredHours) return 'completed';
  if (!ojtStartDate) return 'onTrack';

  const now = new Date();
  const start = new Date(ojtStartDate);
  const daysElapsed = Math.max(0, Math.floor((now - start) / MS_PER_DAY));

  // Only weeks that have fully ended can be expected to be submitted.
  const fullWeeksElapsed = Math.floor(daysElapsed / 7);
  const expectedHours = Math.min(requiredHours, fullWeeksElapsed * ASSUMED_HOURS_PER_WEEK);
  if (expectedHours <= 0) return 'onTrack';

  const paceRatio = (completedHours + pendingHours) / expectedHours;
  const daysSinceLastActivity = lastActivityDate
    ? Math.floor((now - new Date(lastActivityDate)) / MS_PER_DAY)
    : daysElapsed;

  if (paceRatio < 0.7 || daysSinceLastActivity >= MISSED_SUBMISSION_DAYS) return 'needsAttention';
  if (paceRatio < 0.9) return 'behind';
  if (paceRatio > 1.1) return 'aheadOfSchedule';
  return 'onTrack';
}

// The lifecycle bucket shown on the Teacher dashboard/Students tab --
// distinct from the pace status above. 'notStarted' has no tile of its
// own (students still working through Requirements), but is a valid
// filter value. Called "Ready for Deployment" on the dashboard and
// "Preparing" on the Students tab -- same bucket, the wire value stays
// readyForDeployment either way.
function computeStage({ completedHours, requiredHours, hasStarted }) {
  if (completedHours >= requiredHours) return 'completed';
  if (hasStarted && completedHours > 0) return 'active';
  if (hasStarted) return 'readyForDeployment';
  return 'notStarted';
}

module.exports = { computeProgressStatus, computeStage };
