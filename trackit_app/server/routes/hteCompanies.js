const express = require('express');
const pool = require('../db');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();
router.use(requireAuth);

// Read-only for students -- name, industry, location, address, email,
// website, date accredited, and contact persons, exactly what the Admin
// entered. No positions/slots/application data: this directory is a pure
// reference/recommendation list, not an application tracker.
router.get('/', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT c.id, c.name, c.industry, c.location, c.address, c.email, c.website,
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
       -- Entries added automatically from student details stay out of the
       -- student-facing directory until the Admin reviews them.
       WHERE c.source = 'admin'
       GROUP BY c.id
       ORDER BY c.name ASC`,
    );
    res.json({
      success: true,
      companies: result.rows.map((row) => ({
        id: Number(row.id),
        name: row.name,
        industry: row.industry,
        location: row.location,
        address: row.address,
        email: row.email,
        website: row.website,
        dateAccredited: row.date_accredited,
        contacts: row.contacts,
      })),
    });
  } catch (error) {
    console.error('Get HTE companies error:', error);
    res.status(500).json({ success: false, message: 'Failed to load companies.' });
  }
});

// Company suggestions while typing (System Revisions item 8): matches
// from the Admin's HTE Directory plus companies other students already
// entered, so the same company isn't saved under different spellings.
// GET /suggest?q=acc -> up to 8 { name, address, industry, source }.
router.get('/suggest', async (req, res) => {
  try {
    const q = (req.query.q || '').toString().trim();
    if (q.length < 2) return res.json({ success: true, suggestions: [] });
    const pattern = `%${q.toLowerCase().replace(/[\\%_]/g, (c) => `\\${c}`)}%`;

    const result = await pool.query(
      `WITH directory AS (
         SELECT name, address, industry, 'directory' AS source, 0 AS rank
         FROM hte_companies
         WHERE LOWER(name) LIKE $1
       ),
       entered AS (
         SELECT DISTINCT ON (LOWER(TRIM(company_name)))
                TRIM(company_name) AS name, company_address AS address,
                company_industry AS industry, 'students' AS source, 1 AS rank
         FROM student_profiles
         WHERE company_name IS NOT NULL AND LOWER(company_name) LIKE $1
         ORDER BY LOWER(TRIM(company_name)), company_confirmed_at DESC NULLS LAST
       )
       SELECT * FROM directory
       UNION ALL
       SELECT * FROM entered e
       WHERE NOT EXISTS (SELECT 1 FROM directory d WHERE LOWER(d.name) = LOWER(e.name))
       ORDER BY rank, name
       LIMIT 8`,
      [pattern],
    );
    res.json({
      success: true,
      suggestions: result.rows.map((row) => ({
        name: row.name,
        address: row.address,
        industry: row.industry,
        source: row.source,
      })),
    });
  } catch (error) {
    console.error('Suggest companies error:', error);
    res.status(500).json({ success: false, message: 'Failed to load suggestions.' });
  }
});

module.exports = router;
