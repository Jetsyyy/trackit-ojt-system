// Additional Requirements come from two places (migration 33):
// - instructors, for chosen sections (custom_requirement_targets);
// - the OJT office (admin), "scheduled requirements" such as the
//   Supervisor Evaluation Form per period, for every OJT student in an
//   academic year (audience = 'all_students'), with an exact due date and
//   time. Students are notified when one is posted and again the day
//   before it's due.
const pool = require('../db');

// SQL condition: custom requirement `cr` applies to the student whose id
// is the query parameter $<param>.
function visibleToStudent(param) {
  return `(
    EXISTS (
      SELECT 1 FROM custom_requirement_targets crt
      JOIN student_profiles sp ON sp.class_id = crt.class_id
      WHERE crt.custom_requirement_id = cr.id AND sp.student_id = $${param}
    )
    OR (
      cr.audience = 'all_students'
      AND cr.academic_year = (
        SELECT ic.academic_year FROM student_profiles sp
        JOIN instructor_classes ic ON ic.id = sp.class_id
        WHERE sp.student_id = $${param}
      )
    )
  )`;
}

// "Dec 5, 2026, 5:00 PM" in Philippine time.
function formatDue(date) {
  return new Date(date).toLocaleString('en-US', {
    timeZone: 'Asia/Manila',
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  });
}

// The due date as a plain date in Philippine time (for the older
// date-only `deadline` column).
function phDate(date) {
  return new Date(date).toLocaleDateString('en-CA', { timeZone: 'Asia/Manila' });
}

// Approved OJT students whose section is in `academicYear`.
const STUDENTS_OF_YEAR = `
  SELECT s.id FROM students s
  JOIN student_profiles sp ON sp.student_id = s.id
  JOIN instructor_classes ic ON ic.id = sp.class_id
  WHERE s.approval_status = 'approved' AND ic.academic_year = $1`;

async function notifyStudentsOfYear(academicYear, title, message, db = pool) {
  await db.query(
    `INSERT INTO notifications (receiver_id, category, title, message, related_module)
     SELECT id, 'admin', $2, $3, 'requirements' FROM (${STUDENTS_OF_YEAR}) x`,
    [academicYear, title, message],
  );
}

// Day-before reminders, sent once per requirement to the students who
// haven't submitted yet. Called when students open their notifications or
// requirements (there is no always-on server); at most once every 30 seconds per
// server instance, and the database makes sure each reminder goes once.
let lastReminderCheck = 0;
async function sendDueReminders() {
  const now = Date.now();
  if (now - lastReminderCheck < 30 * 1000) return;
  lastReminderCheck = now;
  const due = await pool.query(
    `SELECT id FROM custom_requirements
     WHERE audience = 'all_students' AND reminder_sent_at IS NULL
       AND due_at > now() AND due_at <= now() + interval '24 hours'`,
  );
  for (const { id } of due.rows) {
    // Claim it first so two servers can't both send it.
    const claimed = await pool.query(
      `UPDATE custom_requirements SET reminder_sent_at = now()
       WHERE id = $1 AND reminder_sent_at IS NULL
       RETURNING title, period, due_at, academic_year`,
      [id],
    );
    const r = claimed.rows[0];
    if (!r) continue;
    await pool.query(
      `INSERT INTO notifications (receiver_id, category, title, message, related_module)
       SELECT x.id, 'admin', $2, $3, 'requirements' FROM (${STUDENTS_OF_YEAR}) x
       WHERE NOT EXISTS (
         SELECT 1 FROM student_custom_requirement_submissions scs
         WHERE scs.student_id = x.id AND scs.custom_requirement_id = $4
           AND scs.status IN ('submitted', 'approved')
       )`,
      [
        r.academic_year,
        `Due tomorrow: ${r.title}`,
        `Reminder: your ${r.title}${r.period ? ` (${r.period})` : ''} is due ${formatDue(r.due_at)}. Upload it in Documents > Scheduled Requirements.`,
        id,
      ],
    );
  }
}

module.exports = { visibleToStudent, formatDue, phDate, STUDENTS_OF_YEAR, notifyStudentsOfYear, sendDueReminders };
