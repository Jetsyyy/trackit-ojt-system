const { todayInManila } = require('./manilaTime');

const MS_PER_DAY = 24 * 60 * 60 * 1000;

// Dates are handled as plain 'YYYY-MM-DD' strings so no timezone shift can
// move a week boundary: node-postgres parses a DATE column as LOCAL
// midnight, and a naive toISOString() on that lands on the previous day
// for any timezone east of UTC (including Asia/Manila).
function toDateOnly(value) {
  if (value instanceof Date) {
    const y = value.getFullYear();
    const m = String(value.getMonth() + 1).padStart(2, '0');
    const d = String(value.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }
  return String(value).slice(0, 10);
}

function toUtcMs(ymd) {
  const [y, m, d] = ymd.split('-').map(Number);
  return Date.UTC(y, m - 1, d);
}

function addDays(ymd, days) {
  return new Date(toUtcMs(ymd) + days * MS_PER_DAY).toISOString().slice(0, 10);
}

// One slot per OJT week, from ojtStartDate through the current week
// (Philippine calendar), with no fixed 15-week cap -- the OJT runs as long
// as the required hours take (System Revisions item 10). Pass lastWeek to
// stop early once the required hours were reached in that week.
function generateWeeks(ojtStartDate, { lastWeek } = {}) {
  const start = toDateOnly(ojtStartDate);
  const daysElapsed = Math.max(
    0,
    Math.floor((toUtcMs(todayInManila()) - toUtcMs(start)) / MS_PER_DAY),
  );
  let currentWeek = Math.floor(daysElapsed / 7) + 1;
  if (lastWeek != null) currentWeek = Math.min(currentWeek, lastWeek);

  const weeks = [];
  for (let n = 1; n <= currentWeek; n++) {
    const weekStartDate = addDays(start, (n - 1) * 7);
    weeks.push({ weekNumber: n, weekStartDate, weekEndDate: addDays(weekStartDate, 6) });
  }
  return weeks;
}

module.exports = { generateWeeks, toDateOnly };
