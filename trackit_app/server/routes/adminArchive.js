const express = require('express');
const PDFDocument = require('pdfkit');
const ExcelJS = require('exceljs');
const pool = require('../db');
const { requireAdminAuth } = require('../middleware/adminAuth');
const {
  programFullName,
  computeStudentStatus,
  getCurrentAcademicYear,
} = require('../utils/classHelpers');
const { toCsv } = require('../utils/csv');
const { getCreditedHoursMap } = require('../utils/creditedHours');
const bcrypt = require('bcrypt');
const { nextAcademicYear } = require('../utils/classHelpers');
const { loadDirectoryWithPlacements } = require('../utils/hteDirectory');
const { sendHteReport } = require('../utils/hteReport');

const router = express.Router();
router.use(requireAdminAuth);

// Same shape as adminClasses.js's loadClassStudents, plus real completed/
// required hours (approved weekly DTRs / students.required_hours) --
// Archive's student table shows a "completed / required hrs" column that
// Class Management's own view doesn't, so this isn't reused as-is.
async function loadArchivedClassStudents(classId) {
  const result = await pool.query(
    `SELECT s.id, s.name, s.student_number, s.avatar_url, s.required_hours,
            sp.company_name, sp.company_supervisor_name, sp.emergency_contact,
            lh.last_login
     FROM students s
     JOIN student_profiles sp ON sp.student_id = s.id
     LEFT JOIN LATERAL (
       SELECT MAX(login_at) AS last_login FROM login_history WHERE student_id = s.id
     ) lh ON true
     WHERE sp.class_id = $1
     ORDER BY s.name ASC`,
    [classId],
  );
  const hoursByStudent = await getCreditedHoursMap(result.rows.map((row) => row.id));
  return result.rows.map((row) => ({
    id: Number(row.id),
    name: row.name,
    studentNumber: row.student_number,
    avatarUrl: row.avatar_url,
    assignedCompany: row.company_name,
    status: computeStudentStatus(row.company_name, row.last_login),
    contactPerson: row.emergency_contact,
    ojtSupervisor: row.company_supervisor_name,
    completedHours: Math.round(hoursByStudent.get(Number(row.id)).completedHours * 10) / 10,
    requiredHours: Number(row.required_hours),
  }));
}

router.get('/academic-years', async (req, res) => {
  try {
    const currentYear = await getCurrentAcademicYear();
    const result = await pool.query(
      `SELECT academic_year, COUNT(*) AS class_count
       FROM instructor_classes
       WHERE $1::text IS NULL OR academic_year < $1
       GROUP BY academic_year
       ORDER BY academic_year DESC`,
      [currentYear],
    );
    res.json({
      success: true,
      academicYears: result.rows.map((row) => ({
        year: row.academic_year,
        classCount: Number(row.class_count),
      })),
    });
  } catch (error) {
    console.error('Get archived academic years error:', error);
    res.status(500).json({ success: false, message: 'Failed to load academic years.' });
  }
});

router.get('/classes', async (req, res) => {
  try {
    const { year, search } = req.query;
    if (!year) {
      return res.status(400).json({ success: false, message: 'year is required.' });
    }
    const currentYear = await getCurrentAcademicYear();
    if (year === currentYear) {
      return res
        .status(400)
        .json({ success: false, message: 'The current academic year is not archived.' });
    }

    const params = [year];
    let where = 'WHERE c.academic_year = $1';
    if (search) {
      params.push(`%${search.toString().toLowerCase()}%`);
      where += ' AND (LOWER(c.program) LIKE $2 OR LOWER(c.section) LIKE $2 OR LOWER(a.name) LIKE $2)';
    }

    const result = await pool.query(
      `SELECT c.*, a.name AS instructor_name, COUNT(sp.student_id) AS student_count
       FROM instructor_classes c
       LEFT JOIN advisers a ON a.id = c.instructor_id
       LEFT JOIN student_profiles sp ON sp.class_id = c.id
       ${where}
       GROUP BY c.id, a.name
       ORDER BY c.program ASC, c.section ASC`,
      params,
    );
    res.json({
      success: true,
      classes: result.rows.map((row) => ({
        id: Number(row.id),
        program: row.program,
        section: row.section,
        academicYear: row.academic_year,
        instructorName: row.instructor_name,
        studentCount: Number(row.student_count),
      })),
    });
  } catch (error) {
    console.error('Get archived classes error:', error);
    res.status(500).json({ success: false, message: 'Failed to load archived classes.' });
  }
});

router.get('/classes/:id', async (req, res) => {
  try {
    const classId = Number(req.params.id);
    const result = await pool.query(
      `SELECT c.*, a.name AS instructor_name, a.email AS instructor_email
       FROM instructor_classes c
       LEFT JOIN advisers a ON a.id = c.instructor_id
       WHERE c.id = $1`,
      [classId],
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Class not found.' });
    }
    const row = result.rows[0];

    const currentYear = await getCurrentAcademicYear();
    if (row.academic_year === currentYear) {
      return res.status(403).json({
        success: false,
        message: 'This class belongs to the current academic year and is not archived.',
      });
    }

    const students = await loadArchivedClassStudents(classId);

    const yearLevelResult = await pool.query(
      `SELECT DISTINCT s.year_level FROM students s
       JOIN student_profiles sp ON sp.student_id = s.id
       WHERE sp.class_id = $1 AND s.year_level IS NOT NULL`,
      [classId],
    );
    const yearLevel =
      yearLevelResult.rows.length === 1 ? yearLevelResult.rows[0].year_level : null;

    res.json({
      success: true,
      class: {
        id: Number(row.id),
        program: row.program,
        programFullName: programFullName(row.program),
        section: row.section,
        academicYear: row.academic_year,
        yearLevel,
        instructorName: row.instructor_name,
        instructorEmail: row.instructor_email,
        totalStudents: students.length,
        students,
      },
    });
  } catch (error) {
    console.error('Get archived class detail error:', error);
    res.status(500).json({ success: false, message: 'Failed to load archived class.' });
  }
});

const EXPORT_COLUMNS = [
  { key: 'program', label: 'Program' },
  { key: 'section', label: 'Section' },
  { key: 'academicYear', label: 'Academic Year' },
  { key: 'instructorName', label: 'Instructor' },
  { key: 'studentName', label: 'Student Name' },
  { key: 'studentNumber', label: 'Student Number' },
  { key: 'assignedCompany', label: 'Assigned Company' },
  { key: 'status', label: 'Status' },
  { key: 'completedHours', label: 'Hours Completed' },
  { key: 'requiredHours', label: 'Hours Required' },
];

async function buildExportRows(year) {
  const classesResult = await pool.query(
    `SELECT c.*, a.name AS instructor_name
     FROM instructor_classes c
     LEFT JOIN advisers a ON a.id = c.instructor_id
     WHERE c.academic_year = $1
     ORDER BY c.program ASC, c.section ASC`,
    [year],
  );

  const rows = [];
  for (const classRow of classesResult.rows) {
    const students = await loadArchivedClassStudents(classRow.id);
    for (const student of students) {
      rows.push({
        program: classRow.program,
        section: classRow.section,
        academicYear: classRow.academic_year,
        instructorName: classRow.instructor_name || 'Unassigned',
        studentName: student.name,
        studentNumber: student.studentNumber || '',
        assignedCompany: student.assignedCompany || 'N/A',
        status: student.status,
        completedHours: student.completedHours,
        requiredHours: student.requiredHours,
      });
    }
  }
  return rows;
}

function renderArchivePdf(doc, year, rows) {
  const columns = [
    { key: 'program', label: 'Program', width: 55 },
    { key: 'section', label: 'Section', width: 55 },
    { key: 'instructorName', label: 'Instructor', width: 95 },
    { key: 'studentName', label: 'Student Name', width: 130 },
    { key: 'studentNumber', label: 'Student No.', width: 80 },
    { key: 'assignedCompany', label: 'Company', width: 140 },
    { key: 'status', label: 'Status', width: 60 },
    { key: 'completedHours', label: 'Hours', width: 50 },
    { key: 'requiredHours', label: 'Req. Hrs', width: 55 },
  ];
  const left = doc.page.margins.left;
  const rowHeight = 18;
  const tableWidth = columns.reduce((sum, c) => sum + c.width, 0);

  function drawHeaderRow(y) {
    doc.font('Helvetica-Bold').fontSize(9);
    let x = left;
    for (const col of columns) {
      doc.text(col.label, x, y, { width: col.width, ellipsis: true });
      x += col.width;
    }
    doc.moveTo(left, y + 13).lineTo(left + tableWidth, y + 13).strokeColor('#cccccc').stroke();
    doc.font('Helvetica').fontSize(8.5).fillColor('#000000');
  }

  doc.font('Helvetica-Bold').fontSize(16).text(`TRACKIT Archive - A.Y. ${year}`);
  doc.moveDown(0.5);

  let y = doc.y + 4;
  drawHeaderRow(y);
  y += rowHeight;

  for (const row of rows) {
    if (y > doc.page.height - doc.page.margins.bottom - rowHeight) {
      doc.addPage();
      y = doc.page.margins.top;
      drawHeaderRow(y);
      y += rowHeight;
    }
    let x = left;
    for (const col of columns) {
      const value = row[col.key];
      doc.text(value === null || value === undefined ? '' : value.toString(), x, y, {
        width: col.width,
        ellipsis: true,
      });
      x += col.width;
    }
    y += rowHeight;
  }
}

router.get('/export', async (req, res) => {
  try {
    const { year } = req.query;
    const format = (req.query.format || 'csv').toString().toLowerCase();
    if (!year) {
      return res.status(400).json({ success: false, message: 'year is required.' });
    }
    const currentYear = await getCurrentAcademicYear();
    if (year === currentYear) {
      return res
        .status(400)
        .json({ success: false, message: 'The current academic year is not archived.' });
    }

    const yearString = year.toString();
    const rows = await buildExportRows(yearString);
    const sanitize = (s) => s.toString().replace(/["\r\n]/g, '').trim();
    const baseFilename = `trackit-archive-${sanitize(yearString)}`;

    if (format === 'xlsx') {
      const workbook = new ExcelJS.Workbook();
      const sheet = workbook.addWorksheet(`AY ${yearString}`.slice(0, 31));
      sheet.columns = EXPORT_COLUMNS.map((c) => ({ header: c.label, key: c.key, width: 20 }));
      sheet.addRows(rows);
      sheet.getRow(1).font = { bold: true };
      res.setHeader(
        'Content-Type',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      res.setHeader('Content-Disposition', `attachment; filename="${baseFilename}.xlsx"`);
      await workbook.xlsx.write(res);
      res.end();
      return;
    }

    if (format === 'pdf') {
      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader('Content-Disposition', `attachment; filename="${baseFilename}.pdf"`);
      const doc = new PDFDocument({ margin: 36, size: 'A4', layout: 'landscape' });
      doc.pipe(res);
      renderArchivePdf(doc, yearString, rows);
      doc.end();
      return;
    }

    const csv = toCsv(EXPORT_COLUMNS, rows);
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="${baseFilename}.csv"`);
    res.send(csv);
  } catch (error) {
    console.error('Export archive error:', error);
    res.status(500).json({ success: false, message: 'Failed to export archived data.' });
  }
});

// ---------- Archive the academic year (System Revisions item 20) ----------

// Counts for the active year's records (Archive page "Current Records"):
// companies with deployed students, approved students, and sections.
async function currentRecordCounts(academicYear) {
  const result = await pool.query(
    `SELECT
       (SELECT COUNT(*)::int FROM instructor_classes WHERE academic_year = $1) AS sections,
       COUNT(s.id)::int AS students,
       COUNT(DISTINCT s.company_id)::int AS companies
     FROM students s
     JOIN student_profiles sp ON sp.student_id = s.id
     JOIN instructor_classes cl ON cl.id = sp.class_id
     WHERE cl.academic_year = $1 AND s.approval_status = 'approved'`,
    [academicYear],
  );
  const r = result.rows[0];
  return { companies: r.companies, students: r.students, sections: r.sections };
}

// The active year and whether it can be archived, for the Archive screen.
router.get('/status', async (req, res) => {
  try {
    const activeYear = await getCurrentAcademicYear();
    const archived = activeYear
      ? await pool.query('SELECT 1 FROM hte_archives WHERE academic_year = $1', [activeYear])
      : { rows: [] };
    res.json({
      success: true,
      activeYear,
      nextYear: nextAcademicYear(activeYear),
      alreadyArchived: archived.rows.length > 0,
      current: activeYear ? await currentRecordCounts(activeYear) : { companies: 0, students: 0, sections: 0 },
    });
  } catch (error) {
    console.error('Get archive status error:', error);
    res.status(500).json({ success: false, message: 'Failed to load archive status.' });
  }
});

// Body: { email, password } -- the Admin re-enters their own login to
// confirm. Saves a snapshot of the active year's HTE Directory with each
// company's students, then makes the next academic year active
// (e.g. 2026-2027 -> 2027-2028).
router.post('/academic-year', async (req, res) => {
  const client = await pool.connect();
  try {
    const email = (req.body.email || '').toString().toLowerCase().trim();
    const password = (req.body.password || '').toString();
    if (!email || !password) {
      return res
        .status(400)
        .json({ success: false, message: 'Enter your admin email and password to confirm.' });
    }
    const adminResult = await pool.query('SELECT id, email, password_hash FROM admins WHERE id = $1', [
      req.adminId,
    ]);
    const admin = adminResult.rows[0];
    const valid =
      admin && admin.email === email && (await bcrypt.compare(password, admin.password_hash));
    if (!valid) {
      return res
        .status(401)
        .json({ success: false, message: 'Email or password is incorrect. Nothing was archived.' });
    }

    const activeYear = await getCurrentAcademicYear();
    const nextYear = nextAcademicYear(activeYear);
    if (!activeYear || !nextYear) {
      return res
        .status(400)
        .json({ success: false, message: 'There is no active academic year to archive.' });
    }

    const companies = await loadDirectoryWithPlacements({ academicYear: activeYear });
    const counts = await currentRecordCounts(activeYear);
    const sections = (
      await pool.query(
        `SELECT cl.program, cl.section, a.name AS instructor, COUNT(sp.student_id)::int AS students
         FROM instructor_classes cl
         LEFT JOIN advisers a ON a.id = cl.instructor_id
         LEFT JOIN student_profiles sp ON sp.class_id = cl.id
         WHERE cl.academic_year = $1
         GROUP BY cl.id, a.name ORDER BY cl.program, cl.section`,
        [activeYear],
      )
    ).rows;
    const snapshot = {
      academicYear: activeYear,
      companies,
      sections,
      totals: {
        companies: counts.companies,
        directoryCompanies: companies.length,
        companiesWithStudents: companies.filter((c) => c.students.length > 0).length,
        students: counts.students,
        deployedStudents: companies.reduce((sum, c) => sum + c.students.length, 0),
        sections: counts.sections,
      },
    };

    await client.query('BEGIN');
    const inserted = await client.query(
      `INSERT INTO hte_archives (academic_year, archived_by, snapshot)
       VALUES ($1, $2, $3)
       ON CONFLICT (academic_year) DO NOTHING
       RETURNING id`,
      [activeYear, req.adminId, JSON.stringify(snapshot)],
    );
    if (inserted.rows.length === 0) {
      await client.query('ROLLBACK');
      return res
        .status(409)
        .json({ success: false, message: `Academic Year ${activeYear} is already archived.` });
    }
    await client.query(
      `INSERT INTO app_settings (key, value, updated_at) VALUES ('active_academic_year', $1, now())
       ON CONFLICT (key) DO UPDATE SET value = $1, updated_at = now()`,
      [nextYear],
    );
    await client.query('COMMIT');

    res.json({ success: true, archivedYear: activeYear, activeYear: nextYear, totals: snapshot.totals });
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    console.error('Archive academic year error:', error);
    res.status(500).json({ success: false, message: 'Failed to archive the academic year.' });
  } finally {
    client.release();
  }
});

router.get('/hte-snapshots', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT a.academic_year, a.archived_at, a.snapshot -> 'totals' AS totals, ad.name AS archived_by_name,
              (SELECT COUNT(DISTINCT (st ->> 'program') || ' - ' || (st ->> 'section'))::int
               FROM jsonb_array_elements(a.snapshot -> 'companies') co,
                    jsonb_array_elements(co -> 'students') st) AS section_count
       FROM hte_archives a LEFT JOIN admins ad ON ad.id = a.archived_by
       ORDER BY a.academic_year DESC`,
    );
    res.json({
      success: true,
      snapshots: result.rows.map((r) => ({
        academicYear: r.academic_year,
        archivedAt: r.archived_at,
        archivedBy: r.archived_by_name,
        totals: {
          ...(r.totals || {}),
          companies: r.totals?.companiesWithStudents ?? r.totals?.companies ?? 0,
          students: r.totals?.students ?? 0,
          sections: r.totals?.sections ?? r.section_count ?? 0,
        },
      })),
    });
  } catch (error) {
    console.error('Get HTE snapshots error:', error);
    res.status(500).json({ success: false, message: 'Failed to load archived HTE records.' });
  }
});

// One archived year's HTE Directory: JSON, or ?format=xlsx|pdf.
router.get('/hte-snapshots/:year', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT snapshot, archived_at FROM hte_archives WHERE academic_year = $1',
      [req.params.year],
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'That academic year is not archived.' });
    }
    const snapshot = result.rows[0].snapshot;
    const location = (req.query.location || '').toString().trim();
    const companies = snapshot.companies.filter(
      (c) => !location || c.location === location || c.region === location,
    );
    if (req.query.format === 'xlsx' || req.query.format === 'pdf') {
      return await sendHteReport(res, {
        format: req.query.format,
        companies,
        title: `Archived HTE Directory - Academic Year ${snapshot.academicYear}`,
        subtitle: [
          `Archived ${new Date(result.rows[0].archived_at).toLocaleDateString('en-PH', { timeZone: 'Asia/Manila' })}`,
          location ? `Location: ${location}` : 'All locations',
        ].join('  |  '),
        fileBase: `HTE-Archive-${snapshot.academicYear}${location ? `-${location}` : ''}`,
      });
    }
    res.json({ success: true, academicYear: snapshot.academicYear, totals: snapshot.totals, companies });
  } catch (error) {
    console.error('Get HTE snapshot error:', error);
    if (!res.headersSent) {
      res.status(500).json({ success: false, message: 'Failed to load the archived year.' });
    }
  }
});

module.exports = router;