// The four OJT requirement stages, shared by the student and instructor
// views so both agree on what "done" means (System Revision 2):
// - retired documents (no longer on the official list) are left out;
// - "download only" documents (upload_required = false, e.g. MOU / MOA in
//   Stage 2) are shown but never block a stage;
// - a 'final_details' stage (Stage 4) has no documents: it is done once
//   the student has submitted their final company and supervisor details.
const pool = require('../db');

// Templates still on the list (not retired).
const ACTIVE_TEMPLATES = 'retired_at IS NULL';
// Templates a student must actually upload.
const REQUIRED_TEMPLATES = 'retired_at IS NULL AND upload_required';

async function loadPhasesAndTemplates(db = pool) {
  const [phases, templates] = await Promise.all([
    db.query('SELECT * FROM ojt_requirement_phases ORDER BY order_index ASC'),
    db.query(`SELECT * FROM ojt_requirement_templates WHERE ${ACTIVE_TEMPLATES} ORDER BY phase_id, sort_order ASC, id ASC`),
  ]);
  return { phases: phases.rows, templates: templates.rows };
}

const isDone = (status) => status === 'submitted' || status === 'approved';

// phases/templates: rows from loadPhasesAndTemplates. toDocument(template,
// submission) builds each document's JSON (it must include `status`).
// companyConfirmed: whether the student submitted their final details.
function buildPhases({ phases, templates, submissionsByTemplate, companyConfirmed, toDocument }) {
  const withDocs = phases.map((phase) => {
    const kind = phase.kind || 'documents';
    const documents = templates
      .filter((t) => String(t.phase_id) === String(phase.id))
      .map((t) => ({
        ...toDocument(t, submissionsByTemplate.get(String(t.id)) || submissionsByTemplate.get(t.id)),
        uploadRequired: t.upload_required !== false,
      }));
    const docsDone = documents.every((d) => !d.uploadRequired || isDone(d.status));
    const fulfilled = kind === 'final_details' ? docsDone && Boolean(companyConfirmed) : docsDone;
    return {
      id: phase.id,
      order: phase.order_index,
      title: phase.title,
      description: phase.description,
      kind,
      documents,
      fulfilled,
    };
  });

  // Sequential lock/unlock: a stage can only be in progress or completed
  // if every earlier stage is done.
  let previousCompleted = true;
  return withDocs.map((phase) => {
    let status;
    if (!previousCompleted) status = 'locked';
    else if (phase.fulfilled) status = 'completed';
    else status = 'inProgress';
    previousCompleted = phase.fulfilled;
    return { ...phase, status };
  });
}

async function companyConfirmedFor(studentId, db = pool) {
  const r = await db.query('SELECT company_confirmed_at FROM student_profiles WHERE student_id = $1', [studentId]);
  return Boolean(r.rows[0]?.company_confirmed_at);
}

module.exports = { ACTIVE_TEMPLATES, REQUIRED_TEMPLATES, loadPhasesAndTemplates, buildPhases, companyConfirmedFor };
