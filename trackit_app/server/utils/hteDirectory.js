const pool = require('../db');
const { getCreditedHoursMap } = require('./creditedHours');

// HTE Directory helpers shared by the admin directory, its reports
// (System Revisions items 17, 18, 22) and the academic-year archive
// snapshot (item 20).

// Metro Manila's cities/municipality, for grouping city-level locations
// like "Makati City" under the region the panel used as an example.
const METRO_MANILA = [
  'caloocan', 'las pinas', 'las piñas', 'makati', 'malabon', 'mandaluyong', 'manila',
  'marikina', 'muntinlupa', 'navotas', 'paranaque', 'parañaque', 'pasay', 'pasig',
  'pateros', 'quezon city', 'san juan', 'taguig', 'valenzuela',
];

// "Calamba City, Laguna" -> "Laguna"; "Makati City" -> "Metro Manila";
// empty -> "Unspecified".
function regionOf(location) {
  const text = (location || '').trim();
  if (!text) return 'Unspecified';
  const parts = text.split(',').map((p) => p.trim()).filter(Boolean);
  if (parts.length > 1) return parts[parts.length - 1];
  const lower = text.toLowerCase().replace(/\s+city$/, '');
  if (METRO_MANILA.some((city) => lower === city || lower.startsWith(`${city} `) || text.toLowerCase() === city)) {
    return 'Metro Manila';
  }
  return text;
}

// Links a student to the directory entry for the company they entered,
// adding the company to the directory when it isn't listed yet (marked
// source='student' so the admin can complete its details). Matching is
// case- and whitespace-insensitive on the name.
async function linkStudentToHte(studentId, { name, address, industry }, db = pool) {
  const cleanName = (name || '').trim();
  if (!cleanName) return null;
  const existing = await db.query(
    'SELECT id FROM hte_companies WHERE LOWER(TRIM(name)) = LOWER($1) ORDER BY id LIMIT 1',
    [cleanName],
  );
  let companyId = existing.rows[0]?.id;
  if (!companyId) {
    const inserted = await db.query(
      `INSERT INTO hte_companies (name, industry, address, source)
       VALUES ($1, $2, $3, 'student') RETURNING id`,
      [cleanName, (industry || '').trim() || 'Not specified', (address || '').trim() || 'Not specified'],
    );
    companyId = inserted.rows[0].id;
  }
  await db.query('UPDATE students SET company_id = $1, updated_at = now() WHERE id = $2', [
    companyId,
    studentId,
  ]);
  return Number(companyId);
}

// Every directory entry with its contacts and, when academicYear is
// given, the approved students placed there whose section belongs to that
// year (with credited hours). location filters by exact location OR by
// region (see regionOf).
async function loadDirectoryWithPlacements({ academicYear, location, search } = {}) {
  const companies = await pool.query(
    `SELECT c.id, c.name, c.industry, c.location, c.address, c.email, c.website,
            c.date_accredited, c.source,
       COALESCE(
         json_agg(json_build_object('id', ct.id, 'name', ct.name, 'phone', ct.phone) ORDER BY ct.id)
           FILTER (WHERE ct.id IS NOT NULL),
         '[]'
       ) AS contacts
     FROM hte_companies c
     LEFT JOIN hte_company_contacts ct ON ct.company_id = c.id
     GROUP BY c.id
     ORDER BY c.name ASC`,
  );

  const placementParams = [];
  let yearFilter = '';
  if (academicYear) {
    placementParams.push(academicYear);
    yearFilter = 'AND cl.academic_year = $1';
  }
  const placements = await pool.query(
    `SELECT s.id, s.name, s.student_number, s.company_id, s.required_hours,
            sp.ojt_start_date, sp.company_supervisor_name, sp.company_contact_number,
            cl.program, cl.section, cl.academic_year
     FROM students s
     JOIN student_profiles sp ON sp.student_id = s.id
     JOIN instructor_classes cl ON cl.id = sp.class_id
     WHERE s.company_id IS NOT NULL AND s.approval_status = 'approved' ${yearFilter}
     ORDER BY s.name ASC`,
    placementParams,
  );
  const hours = await getCreditedHoursMap(placements.rows.map((p) => p.id));

  const byCompany = new Map();
  for (const p of placements.rows) {
    const list = byCompany.get(Number(p.company_id)) || [];
    const h = hours.get(Number(p.id));
    list.push({
      id: Number(p.id),
      name: p.name,
      studentNumber: p.student_number,
      program: p.program,
      section: p.section,
      academicYear: p.academic_year,
      ojtStartDate: p.ojt_start_date,
      supervisor: p.company_supervisor_name,
      contactNumber: p.company_contact_number,
      completedHours: h.completedHours,
      requiredHours: Number(p.required_hours),
    });
    byCompany.set(Number(p.company_id), list);
  }

  const query = (search || '').toString().trim().toLowerCase();
  const wanted = (location || '').toString().trim();
  return companies.rows
    .map((c) => ({
      id: Number(c.id),
      name: c.name,
      industry: c.industry,
      location: c.location,
      region: regionOf(c.location),
      address: c.address,
      email: c.email,
      website: c.website,
      dateAccredited: c.date_accredited,
      source: c.source,
      contacts: c.contacts,
      students: byCompany.get(Number(c.id)) || [],
    }))
    .filter((c) => !wanted || c.location === wanted || c.region === wanted)
    .filter(
      (c) =>
        !query ||
        c.name.toLowerCase().includes(query) ||
        (c.industry || '').toLowerCase().includes(query) ||
        c.students.some((s) => s.name.toLowerCase().includes(query)),
    );
}

module.exports = { regionOf, linkStudentToHte, loadDirectoryWithPlacements };
