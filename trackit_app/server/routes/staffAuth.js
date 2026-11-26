const express = require('express');
const pool = require('../db');
const adminAuthRoutes = require('./adminAuth');
const instructorAuthRoutes = require('./instructorAuth');

// One sign-in for the Staff portal (System Revision 7): the user no longer
// picks "Admin" or "Instructor" -- the server finds which kind of account
// the email belongs to and runs that account type's own sign-in (approval
// checks, deactivation, login history, tokens all unchanged). The response
// is that sign-in's response plus { role: 'admin' | 'instructor' }.
const router = express.Router();

router.post('/login', async (req, res, next) => {
  try {
    const email = (req.body.email || '').toString().toLowerCase().trim();
    if (!email || !req.body.password) {
      return res.status(400).json({ success: false, message: 'Enter your email and password.' });
    }
    const admin = await pool.query('SELECT 1 FROM admins WHERE email = $1', [email]);
    const instructor =
      admin.rows.length > 0 ? { rows: [] } : await pool.query('SELECT 1 FROM advisers WHERE email = $1', [email]);
    if (admin.rows.length === 0 && instructor.rows.length === 0) {
      // Same answer as a wrong password, so emails can't be probed.
      return res.status(401).json({ success: false, message: 'Invalid email or password.' });
    }
    const role = admin.rows.length > 0 ? 'admin' : 'instructor';
    const json = res.json.bind(res);
    res.json = (body) => json(body && typeof body === 'object' && body.success ? { ...body, role } : body);
    req.url = '/login';
    return (role === 'admin' ? adminAuthRoutes : instructorAuthRoutes)(req, res, next);
  } catch (error) {
    console.error('Staff login error:', error);
    res.status(500).json({ success: false, message: 'Failed to sign in.' });
  }
});

module.exports = router;
