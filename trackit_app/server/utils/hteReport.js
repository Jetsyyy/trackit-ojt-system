const PDFDocument = require('pdfkit');
const ExcelJS = require('exceljs');

// HTE Directory report (System Revisions items 18, 22), as Excel or PDF.
// Also used for archived academic-year snapshots (item 20).
//
// Companies are grouped into a separate table per location (System
// Revision: HTE Report Generation) -- e.g. Batangas and Metro Manila never
// share a table. Locations are listed A-Z, companies A-Z inside each
// table, and students A-Z inside each company. With the students report,
// a company with no students this year still gets one row so the
// directory is complete.

const STUDENT_COLUMNS = [
  { key: 'company', label: 'Company (HTE)', width: 28, pdf: 130 },
  { key: 'location', label: 'City / Municipality', width: 20, pdf: 80 },
  { key: 'industry', label: 'Industry', width: 18, pdf: 70 },
  { key: 'contacts', label: 'Contact Person(s)', width: 26, pdf: 95 },
  { key: 'student', label: 'Student', width: 24, pdf: 100 },
  { key: 'section', label: 'Program - Section', width: 16, pdf: 62 },
  { key: 'department', label: 'Department', width: 18, pdf: 62 },
  { key: 'supervisor', label: 'Supervisor & Contact', width: 26, pdf: 85 },
  { key: 'hours', label: 'Credited / Required Hrs', width: 14, pdf: 56 },
];

// "HTE Information" report: company details only.
const INFO_COLUMNS = [
  { key: 'company', label: 'Company (HTE)', width: 28, pdf: 150 },
  { key: 'address', label: 'Address', width: 40, pdf: 200 },
  { key: 'industry', label: 'Industry', width: 18, pdf: 90 },
  { key: 'contacts', label: 'Contact Person(s)', width: 28, pdf: 130 },
  { key: 'email', label: 'Email', width: 26, pdf: 110 },
  { key: 'students', label: 'Students', width: 10, pdf: 50 },
];

const byName = (a, b) => a.localeCompare(b, 'en', { sensitivity: 'base', numeric: true });

function formatHours(value) {
  const n = Number(value || 0);
  return Number.isInteger(n) ? String(n) : n.toFixed(2).replace(/0$/, '');
}

function contactsOf(c) {
  return (c.contacts || []).map((ct) => `${ct.name} (${ct.phone})`).join('; ');
}

function toInfoRows(companies) {
  return companies.map((c) => ({
    company: c.name,
    address: c.address || c.location || '',
    industry: c.industry || '',
    contacts: contactsOf(c),
    email: c.email || '',
    students: String(c.students.length),
  }));
}

function toRows(companies) {
  const rows = [];
  for (const c of companies) {
    const base = {
      company: c.name,
      location: (c.location || '').split(',')[0].trim() || 'Not set',
      industry: c.industry || '',
      contacts: contactsOf(c),
    };
    if (c.students.length === 0) {
      rows.push({ ...base, student: 'No student placed', section: '', department: '', supervisor: '', hours: '' });
    }
    for (const s of [...c.students].sort((a, b) => byName(a.name, b.name))) {
      rows.push({
        ...base,
        student: s.name,
        section: `${s.program} - ${s.section}`,
        department: s.department || '',
        supervisor: [s.supervisor, s.contactNumber].filter(Boolean).join(' · '),
        hours: `${formatHours(s.completedHours)} / ${formatHours(s.requiredHours)}`,
      });
    }
  }
  return rows;
}

// [{ label, companies }] sorted A-Z by location, companies A-Z inside.
// groupOf(company) picks the table a company goes in (default: its
// region, e.g. "Laguna"); companies it returns null for are left out.
function groupByLocation(companies, groupOf = (c) => c.region || 'Unspecified') {
  const map = new Map();
  for (const c of companies) {
    const label = groupOf(c);
    if (!label) continue;
    if (!map.has(label)) map.set(label, []);
    map.get(label).push(c);
  }
  return [...map.entries()]
    .sort(([a], [b]) => (a === 'Unspecified') - (b === 'Unspecified') || byName(a, b))
    .map(([label, list]) => ({ label, companies: [...list].sort((a, b) => byName(a.name, b.name)) }));
}

function groupTotals(group) {
  const students = group.companies.reduce((n, c) => n + c.students.length, 0);
  const companies = group.companies.length;
  return {
    companies,
    students,
    text: `${companies} compan${companies === 1 ? 'y' : 'ies'} · ${students} student${students === 1 ? '' : 's'}`,
  };
}

function safeFileName(base, ext) {
  return `${base.replace(/[^A-Za-z0-9._-]+/g, '-').replace(/-+/g, '-')}.${ext}`;
}

// Excel sheet names: 31 characters max, no []:*?/\ , unique.
function sheetName(label, used) {
  let name = label.replace(/[[\]:*?/\\]/g, ' ').trim().slice(0, 31) || 'Location';
  let n = 2;
  while (used.has(name.toLowerCase())) name = `${label.slice(0, 27)} (${n++})`;
  used.add(name.toLowerCase());
  return name;
}

async function sendExcel(res, { groups, title, subtitle, fileBase, withStudents = true }) {
  const COLUMNS = withStudents ? STUDENT_COLUMNS : INFO_COLUMNS;
  const rowsFor = withStudents ? toRows : toInfoRows;
  const generated = `Generated ${new Date().toLocaleString('en-PH', { timeZone: 'Asia/Manila' })}`;
  const workbook = new ExcelJS.Workbook();

  // Summary first: one line per location table.
  const summary = workbook.addWorksheet('Summary');
  summary.addRow([title]).font = { bold: true, size: 14 };
  summary.addRow([subtitle]);
  summary.addRow([generated]);
  summary.addRow([]);
  summary.addRow(['Location', 'Companies', 'Students Placed']).font = { bold: true };
  for (const g of groups) {
    const t = groupTotals(g);
    summary.addRow([g.label, t.companies, t.students]);
  }
  summary.getColumn(1).width = 26;
  summary.getColumn(2).width = 12;
  summary.getColumn(3).width = 16;
  if (groups.length === 0) summary.addRow(['No companies match this report.']);

  // Then one sheet -- one table -- per location.
  const used = new Set(['summary']);
  for (const g of groups) {
    const sheet = workbook.addWorksheet(sheetName(g.label, used));
    sheet.addRow([`${g.label}`]).font = { bold: true, size: 14, color: { argb: 'FF6E1423' } };
    sheet.addRow([`${groupTotals(g).text}  |  ${subtitle}`]);
    sheet.addRow([]);
    const header = sheet.addRow(COLUMNS.map((c) => c.label));
    header.font = { bold: true };
    header.eachCell((cell) => {
      cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFEDE2E4' } };
    });
    COLUMNS.forEach((c, i) => {
      sheet.getColumn(i + 1).width = c.width;
    });
    for (const row of rowsFor(g.companies)) sheet.addRow(COLUMNS.map((c) => row[c.key]));
    sheet.views = [{ state: 'frozen', ySplit: 4 }];
  }

  res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  res.setHeader('Content-Disposition', `attachment; filename="${safeFileName(fileBase, 'xlsx')}"`);
  await workbook.xlsx.write(res);
  res.end();
}

function sendPdf(res, { groups, title, subtitle, fileBase, withStudents = true }) {
  const COLUMNS = withStudents ? STUDENT_COLUMNS : INFO_COLUMNS;
  const rowsFor = withStudents ? toRows : toInfoRows;
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `attachment; filename="${safeFileName(fileBase, 'pdf')}"`);
  const doc = new PDFDocument({ margin: 30, size: 'A4', layout: 'landscape' });
  doc.pipe(res);
  const left = doc.page.margins.left;
  const bottom = () => doc.page.height - doc.page.margins.bottom;
  const tableWidth = COLUMNS.reduce((w, c) => w + c.pdf, 0);

  doc.font('Helvetica-Bold').fontSize(15).fillColor('#000000').text(title);
  doc.font('Helvetica').fontSize(9).fillColor('#444444').text(subtitle);
  doc.text(`Generated ${new Date().toLocaleString('en-PH', { timeZone: 'Asia/Manila' })}`);
  doc.moveDown(0.5);
  doc.fillColor('#000000').font('Helvetica-Bold').fontSize(10).text('Summary by location');
  doc.font('Helvetica').fontSize(9);
  for (const g of groups) doc.text(`${g.label}: ${groupTotals(g).text}`);
  if (groups.length === 0) doc.text('No companies match this report.');

  const drawHeader = () => {
    let x = left;
    const y = doc.y;
    doc.font('Helvetica-Bold').fontSize(7.5).fillColor('#6E1423');
    // Labels may wrap ("Credited / Required Hrs"); the row is as tall as the
    // tallest one so the rule line never cuts through text.
    const h = Math.max(...COLUMNS.map((col) => doc.heightOfString(col.label, { width: col.pdf - 4 })));
    for (const col of COLUMNS) {
      doc.text(col.label, x, y, { width: col.pdf - 4 });
      x += col.pdf;
    }
    doc.moveTo(left, y + h + 2).lineTo(left + tableWidth, y + h + 2).strokeColor('#cccccc').stroke();
    doc.y = y + h + 5;
    doc.font('Helvetica').fontSize(7.5).fillColor('#000000');
  };

  // A separate table per location: its own heading, column header and rows.
  for (const g of groups) {
    const rows = rowsFor(g.companies);
    if (doc.y + 70 > bottom()) doc.addPage();
    else doc.moveDown(1);
    const top = doc.y;
    doc.rect(left, top, tableWidth, 20).fill('#F5E6E8');
    doc.fillColor('#6E1423').font('Helvetica-Bold').fontSize(11).text(g.label, left + 8, top + 5, { continued: true });
    doc.fillColor('#555555').font('Helvetica').fontSize(8.5).text(`    ${groupTotals(g).text}`);
    doc.y = top + 26;
    drawHeader();
    for (const row of rows) {
      const heights = COLUMNS.map((col) => doc.heightOfString(String(row[col.key] ?? ''), { width: col.pdf - 4 }));
      const rowHeight = Math.max(...heights) + 4;
      if (doc.y + rowHeight > bottom()) {
        doc.addPage();
        doc.fillColor('#6E1423').font('Helvetica-Bold').fontSize(9).text(`${g.label} (continued)`, left, doc.y);
        doc.moveDown(0.3);
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
  }
  doc.end();
}

// options: { format, companies, groups?, withStudents, title, subtitle,
// fileBase }. Without `groups`, companies are grouped by region.
async function sendHteReport(res, options) {
  const groups = options.groups || groupByLocation(options.companies || []);
  const opts = { ...options, groups };
  if (options.format === 'pdf') return sendPdf(res, opts);
  return sendExcel(res, opts);
}

module.exports = { sendHteReport, groupByLocation };
