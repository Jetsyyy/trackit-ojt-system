const express = require('express');
const pool = require('../db');
const { requireAdminAuth } = require('../middleware/adminAuth');
const { getCurrentAcademicYear } = require('../utils/classHelpers');
const { regionOf, matchesLocation, sameCompany, loadDirectoryWithPlacements } = require('../utils/hteDirectory');
const { sendHteReport, groupByLocation } = require('../utils/hteReport');

const router = express.Router();
router.use(requireAdminAuth);

const SELECT_WITH_CONTACTS = `
  SELECT c.id, c.name, c.industry, c.location, c.address, c.email, c.website,
         c.date_accredited,
    COALESCE(
      json_agg(
        json_build_object('id', ct.id, 'name', ct.name, 'phone', ct.phone)
        ORDER BY ct.id
      ) FILTER (WHERE ct.id IS NOT NULL),
      '[]'
    ) AS contacts
  FROM hte_companies c
  LEFT JOIN hte_company_contacts ct ON ct.company_id = c.id
`;

function toCompanyJson(row) {
  return {
    id: Number(row.id),
    name: row.name,
    industry: row.industry,
    location: row.location,
    address: row.address,
    email: row.email,
    website: row.website,
    dateAccredited: row.date_accredited,
    contacts: row.contacts,
  };
}

// Directory with each company's students (System Revisions item 17) for
// ?academicYear= (default: the active year). ?location= matches a city
// or a region (e.g. "Metro Manila"); ?search= also matches student names.
router.get('/', async (req, res) => {
  try {
    const academicYear = (req.query.academicYear || '').toString().trim() || (await getCurrentAcademicYear());
    let companies = await loadDirectoryWithPlacements({
      academicYear,
      location: req.query.location,
      search: req.query.search,
    });
    if (req.query.industry) {
      companies = companies.filter((c) => c.industry === req.query.industry.toString());
    }
    res.json({ success: true, academicYear, companies });
  } catch (error) {
    console.error('Get admin HTE companies error:', error);
    res.status(500).json({ success: false, message: 'Failed to load companies.' });
  }
});

// Filter options for the directory and its reports: regions (Metro
// Manila, Laguna, ...) and exact city locations, each with company count.
router.get('/locations', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT location, address, COUNT(*)::int AS count FROM hte_companies
       GROUP BY location, address ORDER BY location`,
    );
    const regions = new Map();
    for (const row of result.rows) {
      const region = regionOf(row.location, row.address);
      regions.set(region, (regions.get(region) || 0) + row.count);
    }
    res.json({
      success: true,
      regions: [...regions.entries()]
        .map(([name, count]) => ({ name, count }))
        .sort((a, b) => a.name.localeCompare(b.name)),
      locations: result.rows
        .filter((r) => r.location)
        .map((r) => ({ name: r.location, region: regionOf(r.location, r.address), count: r.count })),
    });
  } catch (error) {
    console.error('Get HTE locations error:', error);
    res.status(500).json({ success: false, message: 'Failed to load locations.' });
  }
});

// Downloadable report (System Revisions items 18, 22):
// ?format=xlsx|pdf &location= &academicYear=
router.get('/report', async (req, res) => {
  try {
    const format = req.query.format === 'pdf' ? 'pdf' : 'xlsx';
    const academicYear = (req.query.academicYear || '').toString().trim() || (await getCurrentAcademicYear());
    // location may be a comma-separated list (multi-select). Sections never
    // narrow the report (Admin Side 2.2): every student placed in the
    // selected location is included. type=info leaves the students out.
    const location = (req.query.location || '').toString().trim();
    const locations = location.split(',').map((s) => s.trim()).filter(Boolean);
    const withStudents = req.query.type !== 'info';
    const companies = await loadDirectoryWithPlacements({ academicYear, location: locations.join(',') });
    // A separate table per location: per selected location (named as the
    // Admin picked it), or per region when no location is selected.
    const groups =
      locations.length > 0
        ? groupByLocation(companies, (c) => locations.find((l) => matchesLocation(c, l)) || null)
        : groupByLocation(companies);
    await sendHteReport(res, {
      format,
      companies,
      groups,
      withStudents,
      title: 'HTE Directory Report',
      subtitle: [
        `Academic Year ${academicYear || '-'}`,
        location ? `Location: ${locations.join(', ')}` : 'All locations',
      ].filter(Boolean).join('  |  '),
      fileBase: `HTE-Report-${academicYear || 'all'}${location ? `-${location}` : ''}`,
    });
  } catch (error) {
    console.error('HTE report error:', error);
    if (!res.headersSent) {
      res.status(500).json({ success: false, message: 'Failed to generate the report.' });
    }
  }
});

router.post('/', async (req, res) => {
  try {
    const { name, industry, location, address, email, website, dateAccredited, contacts } =
      req.body;
    if (!name || !industry || !location || !address) {
      return res.status(400).json({
        success: false,
        message: 'name, industry, location, and address are required.',
      });
    }

    const inserted = await pool.query(
      `INSERT INTO hte_companies (name, industry, location, address, email, website, date_accredited)
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id`,
      [
        name.trim(),
        industry.trim(),
        location.trim(),
        address.trim(),
        email ? email.toString().trim() : null,
        website ? website.toString().trim() : null,
        dateAccredited || null,
      ],
    );
    const companyId = inserted.rows[0].id;

    if (Array.isArray(contacts)) {
      for (const contact of contacts) {
        if (!contact.name || !contact.phone) continue;
        await pool.query(
          'INSERT INTO hte_company_contacts (company_id, name, phone) VALUES ($1, $2, $3)',
          [companyId, contact.name.toString().trim(), contact.phone.toString().trim()],
        );
      }
    }

    const full = await pool.query(`${SELECT_WITH_CONTACTS} WHERE c.id = $1 GROUP BY c.id`, [
      companyId,
    ]);
    res.status(201).json({ success: true, company: toCompanyJson(full.rows[0]) });
  } catch (error) {
    console.error('Create HTE company error:', error);
    res.status(500).json({ success: false, message: 'Failed to create company.' });
  }
});

router.patch('/:id', async (req, res) => {
  try {
    const companyId = Number(req.params.id);
    const existing = await pool.query('SELECT id FROM hte_companies WHERE id = $1', [companyId]);
    if (existing.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Company not found.' });
    }

    const { name, industry, location, address, email, website, dateAccredited, contacts } =
      req.body;
    if (!name || !industry || !location || !address) {
      return res.status(400).json({
        success: false,
        message: 'name, industry, location, and address are required.',
      });
    }

    await pool.query(
      `UPDATE hte_companies
       SET name = $1, industry = $2, location = $3, address = $4, email = $5,
           website = $6, date_accredited = $7, source = 'admin'
       WHERE id = $8`,
      [
        name.trim(),
        industry.trim(),
        location.trim(),
        address.trim(),
        email ? email.toString().trim() : null,
        website ? website.toString().trim() : null,
        dateAccredited || null,
        companyId,
      ],
    );

    if (Array.isArray(contacts)) {
      await pool.query('DELETE FROM hte_company_contacts WHERE company_id = $1', [companyId]);
      for (const contact of contacts) {
        if (!contact.name || !contact.phone) continue;
        await pool.query(
          'INSERT INTO hte_company_contacts (company_id, name, phone) VALUES ($1, $2, $3)',
          [companyId, contact.name.toString().trim(), contact.phone.toString().trim()],
        );
      }
    }

    const full = await pool.query(`${SELECT_WITH_CONTACTS} WHERE c.id = $1 GROUP BY c.id`, [
      companyId,
    ]);
    res.json({ success: true, company: toCompanyJson(full.rows[0]) });
  } catch (error) {
    console.error('Update HTE company error:', error);
    res.status(500).json({ success: false, message: 'Failed to update company.' });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    const companyId = Number(req.params.id);
    const deployed = await pool.query('SELECT COUNT(*)::int AS n FROM students WHERE company_id = $1', [companyId]);
    if (deployed.rows[0].n > 0) {
      const n = deployed.rows[0].n;
      return res.status(409).json({
        success: false,
        message: `This company can't be removed while ${n} student${n === 1 ? ' is' : 's are'} deployed there.`,
        deployedStudents: n,
      });
    }
    const result = await pool.query('DELETE FROM hte_companies WHERE id = $1 RETURNING id', [
      companyId,
    ]);
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Company not found.' });
    }
    res.json({ success: true });
  } catch (error) {
    console.error('Delete HTE company error:', error);
    res.status(500).json({ success: false, message: 'Failed to delete company.' });
  }
});

// ------------------------------------------------------------ merging
// Duplicate companies (e.g. a student typed "Community General Hospital"
// before the admin's "Community General Hospital of San Pablo City, Inc."
// existed in the directory) are merged into one record: students, weekly
// reports and supervisors move to the kept company, its blank details are
// filled from the others, new contacts are copied, then the others are
// removed.

// Everything that points at each company, for the merge preview.
async function usageCounts(db, ids) {
  const { rows } = await db.query(
    `SELECT c.id, c.name, c.location, c.address, c.source,
            (SELECT COUNT(*) FROM students s WHERE s.company_id = c.id)::int AS students,
            (SELECT COUNT(*) FROM activity_reports a WHERE a.company_id = c.id)::int AS reports,
            (SELECT COUNT(*) FROM supervisors x WHERE x.company_id = c.id)::int AS supervisors,
            (SELECT COUNT(*) FROM hte_company_contacts x WHERE x.company_id = c.id)::int AS contacts
     FROM hte_companies c
     WHERE ($1::bigint[] IS NULL OR c.id = ANY($1::bigint[]))
     ORDER BY c.id`,
    [ids],
  );
  return rows.map((r) => ({
    id: Number(r.id),
    name: r.name,
    location: r.location,
    address: r.address,
    source: r.source,
    students: r.students,
    reports: r.reports,
    supervisors: r.supervisors,
    contacts: r.contacts,
  }));
}

// Which one to keep: the admin's record first, then the one with more
// students, then the older one.
function preferred(a, b) {
  if ((a.source === 'admin') !== (b.source === 'admin')) return a.source === 'admin' ? -1 : 1;
  if (a.students !== b.students) return b.students - a.students;
  return a.id - b.id;
}

// Groups of companies whose names look like the same company.
router.get('/duplicates', async (req, res) => {
  try {
    const all = await usageCounts(pool, null);
    const parent = new Map(all.map((c) => [c.id, c.id]));
    const find = (x) => (parent.get(x) === x ? x : find(parent.get(x)));
    for (let i = 0; i < all.length; i++) {
      for (let j = i + 1; j < all.length; j++) {
        if (sameCompany(all[i].name, all[j].name)) parent.set(find(all[i].id), find(all[j].id));
      }
    }
    const groups = new Map();
    for (const c of all) {
      const root = find(c.id);
      if (!groups.has(root)) groups.set(root, []);
      groups.get(root).push(c);
    }
    const result = [...groups.values()]
      .filter((g) => g.length > 1)
      .map((g) => {
        const companies = [...g].sort(preferred);
        return { keepId: companies[0].id, companies };
      });
    res.json({ success: true, groups: result });
  } catch (error) {
    console.error('Find duplicate HTE companies error:', error);
    res.status(500).json({ success: false, message: 'Failed to look for duplicates.' });
  }
});

// Merges mergeIds into :id. With dryRun, only reports what would move.
router.post('/:id/merge', async (req, res) => {
  const keepId = Number(req.params.id);
  const mergeIds = [...new Set((req.body.mergeIds || []).map(Number))].filter((n) => Number.isInteger(n) && n > 0);
  if (!Number.isInteger(keepId) || keepId <= 0) {
    return res.status(400).json({ success: false, message: 'Choose the company to keep.' });
  }
  if (mergeIds.length === 0) {
    return res.status(400).json({ success: false, message: 'Choose at least one company to merge into it.' });
  }
  if (mergeIds.includes(keepId)) {
    return res.status(400).json({ success: false, message: "A company can't be merged into itself." });
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    // Lock the rows so two admins can't merge the same companies at once.
    const locked = await client.query('SELECT * FROM hte_companies WHERE id = ANY($1::bigint[]) ORDER BY id FOR UPDATE', [
      [keepId, ...mergeIds],
    ]);
    const byId = new Map(locked.rows.map((r) => [Number(r.id), r]));
    if (!byId.has(keepId)) {
      await client.query('ROLLBACK');
      return res.status(404).json({ success: false, message: 'The company to keep no longer exists.' });
    }
    const missing = mergeIds.filter((id) => !byId.has(id));
    if (missing.length) {
      await client.query('ROLLBACK');
      return res.status(404).json({ success: false, message: 'Some of those companies no longer exist. Refresh and try again.' });
    }

    const usage = await usageCounts(client, mergeIds);
    const moving = usage.reduce(
      (t, u) => ({
        students: t.students + u.students,
        reports: t.reports + u.reports,
        supervisors: t.supervisors + u.supervisors,
      }),
      { students: 0, reports: 0, supervisors: 0 },
    );
    if (req.body.dryRun) {
      await client.query('ROLLBACK');
      return res.json({ success: true, dryRun: true, keep: { id: keepId, name: byId.get(keepId).name }, merging: usage, moving });
    }

    await client.query('UPDATE students SET company_id = $1, updated_at = now() WHERE company_id = ANY($2::bigint[])', [keepId, mergeIds]);
    await client.query('UPDATE activity_reports SET company_id = $1 WHERE company_id = ANY($2::bigint[])', [keepId, mergeIds]);
    await client.query('UPDATE supervisors SET company_id = $1 WHERE company_id = ANY($2::bigint[])', [keepId, mergeIds]);

    // Contacts the kept company doesn't already have (same name and number).
    const digits = (v) => (v || '').toString().replace(/\D/g, '');
    const key = (c) => `${(c.name || '').trim().toLowerCase()}|${digits(c.phone)}`;
    const have = new Set(
      (await client.query('SELECT name, phone FROM hte_company_contacts WHERE company_id = $1', [keepId])).rows.map(key),
    );
    const theirs = (
      await client.query('SELECT id, name, phone FROM hte_company_contacts WHERE company_id = ANY($1::bigint[]) ORDER BY id', [mergeIds])
    ).rows;
    let contactsAdded = 0;
    for (const c of theirs) {
      if (have.has(key(c))) continue;
      have.add(key(c));
      await client.query('UPDATE hte_company_contacts SET company_id = $1 WHERE id = $2', [keepId, c.id]);
      contactsAdded++;
    }

    // Fill the kept company's blank details from the merged ones.
    const blank = (v) => v == null || (typeof v === 'string' && (!v.trim() || v.trim() === 'Not specified'));
    const keep = byId.get(keepId);
    const fillable = ['industry', 'address', 'location', 'email', 'phone', 'website', 'description', 'date_accredited', 'available_positions', 'available_slots'];
    const updates = {};
    for (const col of fillable) {
      if (!(col in keep) || !blank(keep[col])) continue;
      const donor = mergeIds.map((id) => byId.get(id)).find((r) => !blank(r[col]));
      if (donor) updates[col] = donor[col];
    }
    const cols = Object.keys(updates);
    if (cols.length) {
      await client.query(
        `UPDATE hte_companies SET ${cols.map((c, i) => `"${c}" = $${i + 2}`).join(', ')}, updated_at = now() WHERE id = $1`,
        [keepId, ...cols.map((c) => updates[c])],
      );
    }

    await client.query('DELETE FROM hte_companies WHERE id = ANY($1::bigint[])', [mergeIds]);
    await client.query('COMMIT');
    res.json({
      success: true,
      keep: { id: keepId, name: keep.name },
      merged: usage.map((u) => u.name),
      moved: { ...moving, contacts: contactsAdded },
      filled: cols,
    });
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    console.error('Merge HTE companies error:', error);
    res.status(500).json({ success: false, message: 'Failed to merge the companies.' });
  } finally {
    client.release();
  }
});

module.exports = router;
