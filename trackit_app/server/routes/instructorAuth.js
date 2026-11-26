const express = require('express');
const { passwordProblem } = require('../utils/passwordPolicy');
const bcrypt = require('bcrypt');
const pool = require('../db');
const { recordActivity, describeDevice } = require('../utils/accountActivity');
const { generateInstructorToken } = require('../middleware/instructorAuth');

const router = express.Router();

// Two kinds of code are accepted:
//  1. An Instructor Registration Code (INS-XXXX-XXXX) the Admin generated
//     for one new instructor (System Revisions item 19). The instructor
//     registers with their own details; the account stays 'pending' until
//     the Admin approves it and assigns its section(s) -- no session yet.
//  2. The activation code of an account the Admin already created in
//     Faculty (FAC-YYYY-NNN). Claiming it just sets the password, as
//     before; the admin created that account, so it is already approved.
async function registerWithRegistrationCode(req, res, code) {
  const { name, email, phone, instructorNumber, password } = req.body;
  const missing = [
    ['name', name],
    ['email', email],
    ['phone', phone],
    ['instructorNumber', instructorNumber],
  ].filter(([, value]) => !value || !value.toString().trim());
  if (missing.length > 0) {
    return res.status(400).json({
      success: false,
      message: 'Full name, email, phone number and instructor number are required.',
    });
  }

  const normalizedEmail = email.toString().toLowerCase().trim();
  const normalizedNumber = instructorNumber.toString().trim().toUpperCase();
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const codeResult = await client.query(
      'SELECT * FROM instructor_registration_codes WHERE code = $1 FOR UPDATE',
      [code],
    );
    const codeRow = codeResult.rows[0];
    if (!codeRow || codeRow.revoked_at) {
      await client.query('ROLLBACK');
      return res.status(400).json({ success: false, message: 'Invalid registration code.' });
    }
    if (codeRow.used_at) {
      await client.query('ROLLBACK');
      return res
        .status(409)
        .json({ success: false, message: 'This registration code has already been used.' });
    }

    const duplicate = await client.query(
      'SELECT email, instructor_number FROM advisers WHERE email = $1 OR instructor_number = $2',
      [normalizedEmail, normalizedNumber],
    );
    if (duplicate.rows.length > 0) {
      await client.query('ROLLBACK');
      const sameEmail = duplicate.rows.some((r) => r.email === normalizedEmail);
      return res.status(409).json({
        success: false,
        message: sameEmail
          ? 'An instructor account with this email already exists.'
          : 'An instructor account with this instructor number already exists.',
      });
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const inserted = await client.query(
      `INSERT INTO advisers
         (name, email, phone, instructor_number, activation_code, password_hash, approval_status)
       VALUES ($1, $2, $3, $4, $5, $6, 'pending')
       RETURNING id`,
      [
        name.toString().trim(),
        normalizedEmail,
        phone.toString().trim(),
        normalizedNumber,
        code,
        passwordHash,
      ],
    );
    await client.query(
      'UPDATE instructor_registration_codes SET used_at = now(), used_by = $1 WHERE id = $2',
      [inserted.rows[0].id, codeRow.id],
    );
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }

  return res.status(201).json({
    success: true,
    pending: true,
    message:
      'Registration sent. You can log in once the Admin approves your account and assigns your section.',
  });
}

router.post('/register', async (req, res) => {
  try {
    const { activationCode, password } = req.body;
    if (!activationCode || !password) {
      return res
        .status(400)
        .json({ success: false, message: 'A code and a password are required.' });
    }
    const weak = passwordProblem(password);
    if (weak) {
      return res.status(400).json({ success: false, message: weak });
    }
    const code = activationCode.toString().trim().toUpperCase();

    const registrationCode = await pool.query(
      'SELECT id FROM instructor_registration_codes WHERE code = $1',
      [code],
    );
    if (registrationCode.rows.length > 0) {
      return await registerWithRegistrationCode(req, res, code);
    }

    const result = await pool.query('SELECT * FROM advisers WHERE activation_code = $1', [code]);
    if (result.rows.length === 0) {
      return res.status(400).json({ success: false, message: 'Invalid activation code.' });
    }
    const instructorRow = result.rows[0];
    if (instructorRow.password_hash) {
      return res
        .status(409)
        .json({ success: false, message: 'This activation code has already been used.' });
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const updated = await pool.query(
      `UPDATE advisers
       SET password_hash = $1, activated_at = now()
       WHERE id = $2
       RETURNING id, name, email, position`,
      [passwordHash, instructorRow.id],
    );
    const instructor = updated.rows[0];
    const token = generateInstructorToken(instructor.id);
    res.status(201).json({ success: true, token, instructor });
  } catch (error) {
    console.error('Instructor register error:', error);
    res.status(500).json({ success: false, message: 'Registration failed.' });
  }
});

router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res
        .status(400)
        .json({ success: false, message: 'email and password are required.' });
    }

    const normalizedEmail = email.toLowerCase().trim();
    const result = await pool.query('SELECT * FROM advisers WHERE email = $1', [
      normalizedEmail,
    ]);
    const instructor = result.rows[0];
    if (!instructor) {
      return res.status(401).json({ success: false, message: 'Invalid email or password.' });
    }
    // Pending row created by Admin (Add Instructor) -- no password set
    // yet, so there's nothing bcrypt.compare could meaningfully check.
    if (!instructor.password_hash) {
      return res.status(401).json({
        success: false,
        message:
          'This account has not been activated yet. Register with your Instructor Activation Code to set a password.',
      });
    }
    if (instructor.status === 'inactive') {
      return res.status(403).json({
        success: false,
        message: 'This account has been deactivated. Contact your administrator.',
      });
    }

    const passwordMatches = await bcrypt.compare(password, instructor.password_hash);
    if (!passwordMatches) {
      return res.status(401).json({ success: false, message: 'Invalid email or password.' });
    }
    if (instructor.approval_status === 'pending') {
      return res.status(403).json({
        success: false,
        code: 'pendingApproval',
        message:
          'Your account is waiting for the Admin\'s approval. You can log in once it is approved and your section is assigned.',
      });
    }
    if (instructor.approval_status === 'rejected') {
      return res.status(403).json({
        success: false,
        code: 'rejected',
        message: `Your instructor registration was declined${
          instructor.rejection_reason ? `: ${instructor.rejection_reason}` : '.'
        } Contact the Admin.`,
      });
    }

    await pool.query('UPDATE advisers SET last_login_at = now() WHERE id = $1', [instructor.id]);
    await recordActivity('instructor', instructor.id, 'Logged in', describeDevice(req.headers['user-agent']));

    const token = generateInstructorToken(instructor.id);
    delete instructor.password_hash;
    res.json({ success: true, token, instructor });
  } catch (error) {
    console.error('Instructor login error:', error);
    res.status(500).json({ success: false, message: 'Login failed.' });
  }
});

module.exports = router;
