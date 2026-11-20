const express = require('express');
const pool = require('../db');
const { requireAdminAuth } = require('../middleware/adminAuth');
const { getCurrentAcademicYear } = require('../utils/classHelpers');
const { regionOf, matchesLocation, loadDirectoryWithPlacements } = require('../utils/hteDirectory');
const { sendHteReport } = require('../utils/hteReport');

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
    let companies = await loadDirectoryWithPlacements({ academicYear, location: locations.join(',') });
    // Several locations: keep each location's companies together.
    if (locations.length > 1) {
      const groupOf = (c) => locations.findIndex((l) => matchesLocation(c, l));
      companies = [...companies].sort((a, b) => groupOf(a) - groupOf(b) || a.name.localeCompare(b.name));
    }
    await sendHteReport(res, {
      format,
      companies,
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

module.exports = router;
