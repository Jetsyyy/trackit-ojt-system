const PDFDocument = require('pdfkit');
const ExcelJS = require('exceljs');
const pool = require('../db');
const { loadWeekPlan, buildWeekList } = require('./weeklySubmissions');

// Downloadable records of an instructor's assigned students (System
// Revisions item 14), for monitoring, documentation and reporting.
// Excel: a "Students" summary sheet plus a "Weekly DTR & AR" sheet with
// every week of every student. PDF: the summary table, then each
// student's weekly log.

const STAGE_LABELS = {
  notStarted: 'Not started',
  readyForDeployment: 'Preparing',
  active: 'Active',
  completed: 'Completed',
};
const PACE_LABELS = {
  onTrack: 'On Track',
  behind: 'Behind',
  needsAttention: 'Needs Attention',
  aheadOfSchedule: 'Ahead of Schedule',
  completed: 'Completed',
};
const WEEK_STATUS = {
  missing: 'Not submitted',
  submitted: 'Waiting for review',
  approved: 'Approved',
  rejected: 'Returned',
};

function hrs(n) {
  const v = Number(n || 0);
  return Number.isInteger(v) ? String(v) : v.toFixed(2).replace(/0$/, '');
}

// students: rows from teacherStudents.loadAssignedStudents.
async function buildRecords(students) {
  const totalResult = await pool.query('SELECT COUNT(*)::int AS total FROM ojt_requirement_templates');
  const totalRequirements = totalResult.rows[0].total;
  const approved = await pool.query(
    `SELECT student_id, COUNT(*)::int AS count FROM student_requirement_submissions
     WHERE student_id = ANY($1::bigint[]) AND status = 'approved' GROUP BY student_id`,
    [students.map((s) => s.id)],
  );
  const approvedBy = new Map(approved.rows.map((r) => [Number(r.student_id), r.count]));

  const records = [];
  for (const s of students) {
    const plan = await loadWeekPlan(s.id);
    const weeks = await buildWeekList(plan);
    records.push({
      name: s.name,
      studentNumber: s.student_number || '',
      email: s.email,
      section: `${s.course} - ${s.section}`,
      company: s.company_name || 'Not yet deployed',
      companyAddress: s.company_address || '',
      supervisor: s.company_supervisor_name || '',
      supervisorContact: s.company_contact_number || '',
      ojtStartDate: s.ojt_start_date || '',
      completedHours: s.completedHours,
      pendingHours: s.pendingHours,
      requiredHours: s.requiredHours,
      approvedWeeks: s.approvedWeeks,
      stage: STAGE_LABELS[s.stage] || s.stage,
      pace: PACE_LABELS[s.progressStatus] || s.progressStatus,
      requirements: `${approvedBy.get(Number(s.id)) || 0} / ${totalRequirements}`,
      weeks,
    });
  }
  return records;
}

const SUMMARY_COLUMNS = [
  { key: 'name', label: 'Student', width: 24, pdf: 92 },
  { key: 'studentNumber', label: 'Student No.', width: 13, pdf: 52 },
  { key: 'section', label: 'Program - Section', width: 16, pdf: 58 },
  { key: 'company', label: 'Company (HTE)', width: 26, pdf: 98 },
  { key: 'supervisor', label: 'Supervisor', width: 20, pdf: 70 },
  { key: 'ojtStartDate', label: 'OJT Start', width: 12, pdf: 48 },
  { key: 'hours', label: 'Credited / Required', width: 16, pdf: 58 },
  { key: 'pendingHours', label: 'Hrs for Approval', width: 14, pdf: 44 },
  { key: 'approvedWeeks', label: 'Approved Weeks', width: 13, pdf: 40 },
  { key: 'requirements', label: 'Requirements Approved', width: 18, pdf: 52 },
  { key: 'stage', label: 'Stage', width: 12, pdf: 46 },
  { key: 'pace', label: 'Pace', width: 16, pdf: 56 },
];

function summaryValue(r, key) {
  if (key === 'hours') return `${hrs(r.completedHours)} / ${hrs(r.requiredHours)}`;
  if (key === 'pendingHours') return hrs(r.pendingHours);
  return r[key] ?? '';
}

async function sendExcel(res, { records, title, subtitle, fileName }) {
  const workbook = new ExcelJS.Workbook();
  const sheet = workbook.addWorksheet('Students');
  sheet.addRow([title]).font = { bold: true, size: 14 };
  sheet.addRow([subtitle]);
  sheet.addRow([]);
  const header = sheet.addRow(SUMMARY_COLUMNS.map((c) => c.label));
  header.font = { bold: true };
  SUMMARY_COLUMNS.forEach((c, i) => {
    sheet.getColumn(i + 1).width = c.width;
  });
  for (const r of records) sheet.addRow(SUMMARY_COLUMNS.map((c) => summaryValue(r, c.key)));

  const weekly = workbook.addWorksheet('Weekly DTR & AR');
  weekly.addRow(['Student', 'Week', 'Dates', 'Status', 'Hours Claimed', 'Remarks']).font = { bold: true };
  [24, 8, 26, 18, 14, 40].forEach((w, i) => {
    weekly.getColumn(i + 1).width = w;
  });
  for (const r of records) {
    for (const w of r.weeks) {
      weekly.addRow([
        r.name,
        w.weekNumber,
        `${w.weekStartDate} to ${w.weekEndDate}`,
        WEEK_STATUS[w.status] || w.status,
        w.claimedHours != null ? Number(w.claimedHours) : '',
        w.remarks || '',
      ]);
    }
  }

  res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  res.setHeader('Content-Disposition', `attachment; filename="${fileName}.xlsx"`);
  await workbook.xlsx.write(res);
  res.end();
}

function sendPdf(res, { records, title, subtitle, fileName }) {
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `attachment; filename="${fileName}.pdf"`);
  const doc = new PDFDocument({ margin: 28, size: 'A4', layout: 'landscape' });
  doc.pipe(res);
  const left = doc.page.margins.left;
  const bottom = () => doc.page.height - doc.page.margins.bottom;

  doc.font('Helvetica-Bold').fontSize(15).text(title);
  doc.font('Helvetica').fontSize(9).fillColor('#444444').text(subtitle);
  doc.moveDown(0.6);

  const table = (columns, rows) => {
    const drawHeader = () => {
      let x = left;
      const y = doc.y;
      doc.font('Helvetica-Bold').fontSize(7).fillColor('#6E1423');
      for (const c of columns) {
        doc.text(c.label, x, y, { width: c.pdf - 3 });
        x += c.pdf;
      }
      const h = Math.max(...columns.map((c) => doc.heightOfString(c.label, { width: c.pdf - 3 })));
      doc.moveTo(left, y + h + 2).lineTo(x, y + h + 2).strokeColor('#cccccc').stroke();
      doc.y = y + h + 5;
      doc.font('Helvetica').fontSize(7).fillColor('#000000');
    };
    drawHeader();
    for (const row of rows) {
      const cells = columns.map((c) => String(row[c.key] ?? ''));
      const h = Math.max(...cells.map((t, i) => doc.heightOfString(t, { width: columns[i].pdf - 3 }))) + 3;
      if (doc.y + h > bottom()) {
        doc.addPage();
        drawHeader();
      }
      const y = doc.y;
      let x = left;
      cells.forEach((t, i) => {
        doc.text(t, x, y, { width: columns[i].pdf - 3 });
        x += columns[i].pdf;
      });
      doc.y = y + h;
    }
  };

  table(
    SUMMARY_COLUMNS,
    records.map((r) => Object.fromEntries(SUMMARY_COLUMNS.map((c) => [c.key, summaryValue(r, c.key)]))),
  );
  if (records.length === 0) doc.text('No assigned students.');

  const weekColumns = [
    { key: 'week', label: 'Week', pdf: 40 },
    { key: 'dates', label: 'Dates', pdf: 140 },
    { key: 'status', label: 'Status', pdf: 100 },
    { key: 'hours', label: 'Hours Claimed', pdf: 70 },
    { key: 'remarks', label: 'Remarks', pdf: 380 },
  ];
  for (const r of records) {
    if (r.weeks.length === 0) continue;
    if (doc.y + 60 > bottom()) doc.addPage();
    doc.moveDown(0.8);
    doc.x = left;
    doc.font('Helvetica-Bold').fontSize(10).fillColor('#000000')
      .text(`${r.name} - ${r.section} - ${r.company}`, left);
    doc.moveDown(0.2);
    table(
      weekColumns,
      r.weeks.map((w) => ({
        week: w.weekNumber,
        dates: `${w.weekStartDate} to ${w.weekEndDate}`,
        status: WEEK_STATUS[w.status] || w.status,
        hours: w.claimedHours != null ? hrs(w.claimedHours) : '',
        remarks: w.remarks || '',
      })),
    );
  }
  doc.end();
}

async function sendStudentRecords(res, { format, students, instructorName }) {
  const records = await buildRecords(students);
  const today = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Manila' }).format(new Date());
  const options = {
    records,
    title: 'OJT Student Records',
    subtitle: `Instructor: ${instructorName}  |  ${records.length} student${records.length === 1 ? '' : 's'}  |  Generated ${today}`,
    fileName: `OJT-Student-Records-${today}`,
  };
  if (format === 'pdf') return sendPdf(res, options);
  return sendExcel(res, options);
}

module.exports = { sendStudentRecords };
