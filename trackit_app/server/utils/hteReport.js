const PDFDocument = require('pdfkit');
const ExcelJS = require('exceljs');

// HTE Directory report (System Revisions items 18, 22), as Excel or PDF.
// One row per student placement; a company with no students this year
// still gets one row so the directory is complete. Also used for archived
// academic-year snapshots (item 20).

const STUDENT_COLUMNS = [
  { key: 'company', label: 'Company (HTE)', width: 26, pdf: 120 },
  { key: 'location', label: 'Location', width: 20, pdf: 80 },
  { key: 'region', label: 'Region', width: 14, pdf: 60 },
  { key: 'industry', label: 'Industry', width: 18, pdf: 70 },
  { key: 'contacts', label: 'Contact Person(s)', width: 26, pdf: 95 },
  { key: 'student', label: 'Student', width: 24, pdf: 95 },
  { key: 'section', label: 'Program - Section', width: 16, pdf: 65 },
  { key: 'supervisor', label: 'Supervisor / Contact', width: 26, pdf: 70 },
  { key: 'hours', label: 'Credited / Required Hrs', width: 14, pdf: 55 },
];

function formatHours(value) {
  const n = Number(value || 0);
  return Number.isInteger(n) ? String(n) : n.toFixed(2).replace(/0$/, '');
}

// "HTE Information" report: company details only.
const INFO_COLUMNS = [
  { key: 'company', label: 'Company (HTE)', width: 28, pdf: 150 },
  { key: 'address', label: 'Address', width: 40, pdf: 200 },
  { key: 'industry', label: 'Industry', width: 18, pdf: 90 },
  { key: 'contacts', label: 'Contact Person(s)', width: 28, pdf: 130 },
  { key: 'email', label: 'Email', width: 26, pdf: 110 },
  { key: 'students', label: 'Students', width: 10, pdf: 50 },
];

function toInfoRows(companies) {
  return companies.map((c) => ({
    company: c.name,
    address: c.address || c.location || '',
    industry: c.industry || '',
    contacts: (c.contacts || []).map((ct) => `${ct.name} (${ct.phone})`).join('; '),
    email: c.email || '',
    students: String(c.students.length),
  }));
}

function toRows(companies) {
  const rows = [];
  for (const c of companies) {
    const base = {
      company: c.name,
      location: c.location || 'Not set',
      region: c.region,
      industry: c.industry || '',
      contacts: (c.contacts || []).map((ct) => `${ct.name} (${ct.phone})`).join('; '),
    };
    if (c.students.length === 0) {
      rows.push({ ...base, student: 'No student placed', section: '', supervisor: '', hours: '' });
    }
    for (const s of c.students) {
      rows.push({
        ...base,
        student: s.name,
        section: `${s.program} - ${s.section}`,
        supervisor: [s.supervisor, s.contactNumber].filter(Boolean).join(' · '),
        hours: `${formatHours(s.completedHours)} / ${formatHours(s.requiredHours)}`,
      });
    }
  }
  return rows;
}

function summarizeByRegion(companies) {
  const map = new Map();
  for (const c of companies) {
    const entry = map.get(c.region) || { region: c.region, companies: 0, students: 0 };
    entry.companies += 1;
    entry.students += c.students.length;
    map.set(c.region, entry);
  }
  return [...map.values()].sort((a, b) => a.region.localeCompare(b.region));
}

function safeFileName(base, ext) {
  return `${base.replace(/[^A-Za-z0-9._-]+/g, '-').replace(/-+/g, '-')}.${ext}`;
}

async function sendExcel(res, { companies, title, subtitle, fileBase, withStudents = true }) {
  const COLUMNS = withStudents ? STUDENT_COLUMNS : INFO_COLUMNS;
  const rowsFor = withStudents ? toRows : toInfoRows;
  const workbook = new ExcelJS.Workbook();
  const sheet = workbook.addWorksheet('Placements');
  sheet.addRow([title]).font = { bold: true, size: 14 };
  sheet.addRow([subtitle]);
  sheet.addRow([`Generated ${new Date().toLocaleString('en-PH', { timeZone: 'Asia/Manila' })}`]);
  sheet.addRow([]);
  const header = sheet.addRow(COLUMNS.map((c) => c.label));
  header.font = { bold: true };
  header.eachCell((cell) => {
    cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFEDE2E4' } };
  });
  COLUMNS.forEach((c, i) => {
    sheet.getColumn(i + 1).width = c.width;
  });
  for (const row of rowsFor(companies)) sheet.addRow(COLUMNS.map((c) => row[c.key]));

  const summary = workbook.addWorksheet('By Region');
  summary.addRow(['Region', 'Companies', 'Students Placed']).font = { bold: true };
  for (const s of summarizeByRegion(companies)) summary.addRow([s.region, s.companies, s.students]);
  summary.getColumn(1).width = 22;
  summary.getColumn(2).width = 12;
  summary.getColumn(3).width = 16;

  res.setHeader(
    'Content-Type',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );
  res.setHeader('Content-Disposition', `attachment; filename="${safeFileName(fileBase, 'xlsx')}"`);
  await workbook.xlsx.write(res);
  res.end();
}

function sendPdf(res, { companies, title, subtitle, fileBase, withStudents = true }) {
  const COLUMNS = withStudents ? STUDENT_COLUMNS : INFO_COLUMNS;
  const rowsFor = withStudents ? toRows : toInfoRows;
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `attachment; filename="${safeFileName(fileBase, 'pdf')}"`);
  const doc = new PDFDocument({ margin: 30, size: 'A4', layout: 'landscape' });
  doc.pipe(res);

  doc.font('Helvetica-Bold').fontSize(15).text(title);
  doc.font('Helvetica').fontSize(9).fillColor('#444444').text(subtitle);
  doc.text(`Generated ${new Date().toLocaleString('en-PH', { timeZone: 'Asia/Manila' })}`);
  doc.moveDown(0.6);

  const summary = summarizeByRegion(companies);
  doc.fillColor('#000000').font('Helvetica-Bold').fontSize(10).text('Summary by region');
  doc.font('Helvetica').fontSize(9);
  for (const s of summary) {
    doc.text(`${s.region}: ${s.companies} compan${s.companies === 1 ? 'y' : 'ies'}, ${s.students} student${s.students === 1 ? '' : 's'}`);
  }
  doc.moveDown(0.6);

  const left = doc.page.margins.left;
  const bottom = doc.page.height - doc.page.margins.bottom;
  const drawHeader = () => {
    let x = left;
    const y = doc.y;
    doc.font('Helvetica-Bold').fontSize(7.5).fillColor('#6E1423');
    for (const col of COLUMNS) {
      doc.text(col.label, x, y, { width: col.pdf - 4, ellipsis: true });
      x += col.pdf;
    }
    doc.moveTo(left, y + 11).lineTo(x, y + 11).strokeColor('#cccccc').stroke();
    doc.y = y + 14;
    doc.font('Helvetica').fontSize(7.5).fillColor('#000000');
  };
  drawHeader();

  for (const row of rowsFor(companies)) {
    const heights = COLUMNS.map((col) => doc.heightOfString(String(row[col.key] ?? ''), { width: col.pdf - 4 }));
    const rowHeight = Math.max(...heights) + 4;
    if (doc.y + rowHeight > bottom) {
      doc.addPage();
      drawHeader();
    }
    const y = doc.y;
    let x = left;
    for (const col of COLUMNS) {
      doc.text(String(row[col.key] ?? ''), x, y, { width: col.pdf - 4 });
      x += col.pdf;
    }
    doc.y = y + rowHeight;
  }
  if (companies.length === 0) doc.text('No companies match this report.');
  doc.end();
}

async function sendHteReport(res, options) {
  if (options.format === 'pdf') return sendPdf(res, options);
  return sendExcel(res, options);
}

module.exports = { sendHteReport };
