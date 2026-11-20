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

// Provinces a company can be filed under, and the cities/municipalities
// (CALABARZON, where most partner companies are) that belong to each, so
// a company saved as just "San Pablo City" still counts as Laguna.
const PROVINCES = ['Laguna', 'Batangas', 'Cavite', 'Rizal', 'Quezon', 'Bulacan', 'Pampanga', 'Metro Manila'];
const CITY_PROVINCE = {
  Laguna: [
    'san pablo', 'calamba', 'santa rosa', 'binan', 'cabuyao', 'san pedro', 'los banos', 'santa cruz',
    'bay', 'calauan', 'alaminos', 'nagcarlan', 'liliw', 'victoria', 'pila', 'pagsanjan', 'lumban',
    'paete', 'pakil', 'pangil', 'siniloan', 'famy', 'mabitac', 'majayjay', 'magdalena', 'luisiana',
    'cavinti', 'kalayaan', 'santa maria',
  ],
  Batangas: [
    'batangas', 'lipa', 'tanauan', 'santo tomas', 'malvar', 'nasugbu', 'bauan', 'rosario', 'ibaan',
    'san jose', 'lemery', 'balayan', 'calaca', 'calatagan', 'taal', 'mabini', 'padre garcia',
  ],
  Cavite: [
    'bacoor', 'imus', 'dasmarinas', 'general trias', 'tagaytay', 'cavite', 'trece martires', 'silang',
    'carmona', 'kawit', 'tanza', 'naic', 'noveleta', 'general mariano alvarez', 'indang', 'alfonso',
  ],
  Rizal: ['antipolo', 'cainta', 'taytay', 'binangonan', 'san mateo', 'rodriguez', 'montalban', 'angono', 'morong', 'tanay', 'teresa'],
  Quezon: ['lucena', 'tayabas', 'sariaya', 'candelaria', 'tiaong', 'pagbilao', 'lucban', 'dolores'],
};

// Lower-case, no accents, "Sta."/"Sto." spelled out, no "City"/"City of".
function placeKey(text) {
  return (text || '')
    .toString()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/\bsta\.?\s/g, 'santa ')
    .replace(/\bsto\.?\s/g, 'santo ')
    .replace(/\bcity of\b/g, '')
    .replace(/\bcity\b/g, '')
    .replace(/\bprovince\b/g, '')
    .replace(/[^a-z\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function placeParts(...texts) {
  return texts.flatMap((t) => (t || '').toString().split(',')).map(placeKey).filter(Boolean);
}

// The province (or Metro Manila) a company is in, read from its location
// and, when that doesn't say, its address: "Calamba City, Laguna" and
// "San Pablo City" -> "Laguna"; "Makati City" -> "Metro Manila"; nothing
// to go on -> "Unspecified".
function regionOf(location, address) {
  // Quezon City is in Metro Manila, not Quezon province (placeKey drops
  // the word City, so check it first).
  if (/\bquezon city\b/i.test(`${location || ''} ${address || ''}`)) return 'Metro Manila';
  const parts = placeParts(location, address);
  const named = [...parts].reverse();
  for (const p of named) {
    if (p === 'ncr' || p === 'metro manila' || p === 'national capital region') return 'Metro Manila';
    // "Laguna" or a part that ends with it, like "San Pablo Laguna".
    const province = PROVINCES.find((name) => p === placeKey(name) || p.endsWith(` ${placeKey(name)}`));
    if (province) return province;
  }
  for (const p of parts) {
    if (METRO_MANILA.some((city) => p === placeKey(city))) return 'Metro Manila';
    for (const [province, cities] of Object.entries(CITY_PROVINCE)) {
      if (cities.includes(p)) return province;
    }
  }
  const text = (location || '').trim();
  return text ? text.split(',').pop().trim() : 'Unspecified';
}

// True when a company matches one location filter value: its region, its
// location, or any part of its location/address (e.g. "Laguna",
// "San Pablo City"), ignoring case and accents.
function matchesLocation(company, wanted) {
  const w = placeKey(wanted);
  if (!w) return true;
  if (placeKey(company.region) === w || placeKey(company.location) === w) return true;
  return placeParts(company.location, company.address).includes(w);
}

// Company names compared loosely: case, punctuation and suffixes like
// "Inc." or "Corp." ignored, so "Community General Hospital" finds
// "Community General Hospital of San Pablo City, Inc.".
function companyKey(name) {
  return (name || '')
    .toString()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/&/g, ' and ')
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\b(the|inc|incorporated|corp|corporation|co|company|ltd|limited)\b/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function sameCompany(a, b) {
  const x = companyKey(a);
  const y = companyKey(b);
  if (!x || !y) return false;
  if (x === y) return true;
  const [short, long] = x.length <= y.length ? [x, y] : [y, x];
  // The shorter name must be specific: at least two words, 15+ letters.
  return short.length >= 15 && short.includes(' ') && long.startsWith(`${short} `);
}

// Links a student to the directory entry for the company they entered,
// adding the company to the directory when it isn't listed yet (marked
// source='student' so the admin can complete its details). Matching is
// case- and whitespace-insensitive on the name.
async function linkStudentToHte(studentId, { name, address, industry }, db = pool) {
  const cleanName = (name || '').trim();
  if (!cleanName) return null;
  const all = await db.query("SELECT id, name, source FROM hte_companies ORDER BY (source = 'admin') DESC, id");
  let companyId = all.rows.find((c) => sameCompany(c.name, cleanName))?.id;
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
            sp.company_department,
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
      department: p.company_department,
      supervisor: p.company_supervisor_name,
      contactNumber: p.company_contact_number,
      completedHours: h.completedHours,
      requiredHours: Number(p.required_hours),
    });
    byCompany.set(Number(p.company_id), list);
  }

  const query = (search || '').toString().trim().toLowerCase();
  const wanted = (location || '')
    .toString()
    .split(',')
    .map((l) => l.trim())
    .filter(Boolean);
  return companies.rows
    .map((c) => ({
      id: Number(c.id),
      name: c.name,
      industry: c.industry,
      location: c.location,
      region: regionOf(c.location, c.address),
      address: c.address,
      email: c.email,
      website: c.website,
      dateAccredited: c.date_accredited,
      source: c.source,
      contacts: c.contacts,
      students: byCompany.get(Number(c.id)) || [],
    }))
    .filter((c) => wanted.length === 0 || wanted.some((w) => matchesLocation(c, w)))
    .filter(
      (c) =>
        !query ||
        c.name.toLowerCase().includes(query) ||
        (c.industry || '').toLowerCase().includes(query) ||
        c.students.some((s) => s.name.toLowerCase().includes(query)),
    );
}

module.exports = { regionOf, matchesLocation, sameCompany, linkStudentToHte, loadDirectoryWithPlacements };
