const express = require('express');
const bcrypt = require('bcrypt');
const { passwordProblem } = require('../utils/passwordPolicy');
const multer = require('multer');
const { uploadStorage } = require('../utils/storage');
const path = require('path');
const pool = require('../db');
const { requireAuth } = require('../middleware/auth');
const { linkStudentToHte } = require('../utils/hteDirectory');

const router = express.Router();
router.use(requireAuth);

const NAME_CHANGE_COOLDOWN_DAYS = 14;

const storage = uploadStorage('avatars');
const upload = multer({
  storage,
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const allowed = ['image/jpeg', 'image/png', 'image/webp'];
    cb(null, allowed.includes(file.mimetype));
  },
});

router.get('/', async (req, res) => {
  try {
    const studentResult = await pool.query(
      `SELECT name, email, course, section, student_number, year_level, avatar_url, name_changed_at,
              must_change_password
       FROM students
       WHERE id = $1`,
      [req.studentId],
    );
    if (studentResult.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Student not found.' });
    }
    const student = studentResult.rows[0];
    const nameChangeAvailableAt = student.name_changed_at
      ? new Date(
          new Date(student.name_changed_at).getTime() +
            NAME_CHANGE_COOLDOWN_DAYS * 24 * 60 * 60 * 1000,
        )
      : null;

    const profileResult = await pool.query(
      `SELECT sp.phone,
              sp.company_name, sp.company_address, sp.company_industry,
              sp.company_supervisor_name, sp.company_contact_number, sp.company_department,
              sp.company_latitude, sp.company_longitude, sp.ojt_start_date,
              a.name AS adviser_name, a.position AS adviser_position,
              a.email AS adviser_email, a.phone AS adviser_phone
       FROM student_profiles sp
       LEFT JOIN advisers a ON a.id = sp.adviser_id
       WHERE sp.student_id = $1`,
      [req.studentId],
    );
    const profile = profileResult.rows[0] || null;

    res.json({
      success: true,
      profile: {
        fullName: student.name,
        // Set after an instructor password reset: the app asks for a new
        // password before anything else.
        mustChangePassword: student.must_change_password === true,
        // null once the cooldown has elapsed (or the name was never
        // changed) -- the Edit Profile screen uses this to show/hide the
        // "you can change your name again on..." banner up front, not
        // just after a rejected attempt.
        nameChangeAvailableAt:
          nameChangeAvailableAt && nameChangeAvailableAt > new Date()
            ? nameChangeAvailableAt.toISOString()
            : null,
        email: student.email,
        course: student.course,
        section: student.section,
        studentNumber: student.student_number,
        yearLevel: student.year_level,
        avatarUrl: student.avatar_url,
        mobileNumber: profile ? profile.phone : null,
        adviser: profile && profile.adviser_name
          ? {
              name: profile.adviser_name,
              role: profile.adviser_position,
              email: profile.adviser_email,
              phone: profile.adviser_phone,
            }
          : null,
        // Self-reported via the Confirm Company Details form -- independent
        // of the HTE Directory. Matches CompanyDetails.fromJson's shape.
        company: profile && profile.company_name
          ? {
              name: profile.company_name,
              address: profile.company_address,
              industry: profile.company_industry,
              supervisorName: profile.company_supervisor_name,
              contactNumber: profile.company_contact_number,
              department: profile.company_department,
              latitude: profile.company_latitude,
              longitude: profile.company_longitude,
              ojtStartDate: profile.ojt_start_date,
            }
          : null,
        // Derived from the same Confirm Company Details form (it collects
        // the supervisor's name and contact number together with the
        // company info) rather than a separate supervisors-table FK.
        supervisor: profile && profile.company_supervisor_name
          ? {
              name: profile.company_supervisor_name,
              role: 'HR Supervisor',
              email: '',
              phone: profile.company_contact_number,
            }
          : null,
      },
    });
  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({ success: false, message: 'Failed to load profile.' });
  }
});

router.patch('/', async (req, res) => {
  try {
    const {
      phone,
      alternateEmail,
      address,
      emergencyContact,
      studentNumber,
      yearLevel,
      fullName,
    } = req.body;

    // A name change is atomic with its own cooldown check: the eligibility
    // check (no change within the last 14 days) and the write happen in
    // the same statement, so it can't be bypassed by refreshing, logging
    // out/in, another device, or calling the API directly -- a rejected
    // request writes nothing and never resets the cooldown.
    if (fullName !== undefined) {
      const trimmedName = fullName.trim();
      if (!trimmedName) {
        return res.status(400).json({ success: false, message: 'Full name is required.' });
      }

      const renamed = await pool.query(
        `UPDATE students
         SET name = $1, name_changed_at = now(), updated_at = now()
         WHERE id = $2 AND name != $1
           AND (name_changed_at IS NULL
             OR name_changed_at <= now() - INTERVAL '${NAME_CHANGE_COOLDOWN_DAYS} days')
         RETURNING name`,
        [trimmedName, req.studentId],
      );

      if (renamed.rows.length === 0) {
        const current = (
          await pool.query('SELECT name, name_changed_at FROM students WHERE id = $1', [
            req.studentId,
          ])
        ).rows[0];

        // Only an actual change (different from the current name) is
        // subject to the cooldown -- resubmitting the same name is a
        // silent no-op, not a rejection.
        if (current.name !== trimmedName && current.name_changed_at) {
          const availableAt = new Date(
            new Date(current.name_changed_at).getTime() +
              NAME_CHANGE_COOLDOWN_DAYS * 24 * 60 * 60 * 1000,
          );
          if (availableAt > new Date()) {
            return res.status(403).json({
              success: false,
              message: 'You recently changed your name.',
              nameChangeAvailableAt: availableAt.toISOString(),
            });
          }
        }
      }
    }

    // COALESCE against the existing row so a partial update (e.g. saving
    // just a name change) never blanks out fields the caller didn't send.
    await pool.query(
      `INSERT INTO student_profiles (student_id, phone, alternate_email, address, emergency_contact)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (student_id)
       DO UPDATE SET
         phone = COALESCE($2, student_profiles.phone),
         alternate_email = COALESCE($3, student_profiles.alternate_email),
         address = COALESCE($4, student_profiles.address),
         emergency_contact = COALESCE($5, student_profiles.emergency_contact),
         updated_at = now()`,
      [req.studentId, phone, alternateEmail, address, emergencyContact],
    );

    if (studentNumber !== undefined || yearLevel !== undefined) {
      await pool.query(
        `UPDATE students
         SET student_number = COALESCE($1, student_number),
             year_level = COALESCE($2, year_level),
             updated_at = now()
         WHERE id = $3`,
        [studentNumber, yearLevel, req.studentId],
      );
    }

    res.json({ success: true });
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({ success: false, message: 'Failed to update profile.' });
  }
});

// Real login/logout history -- one row per token issued at register/login
// (see utils/loginHistory.js), closed by POST /api/auth/logout. Never
// synthesized: a page refresh reuses the existing token and creates
// nothing here, so this is exactly the student's real session activity.
router.get('/login-history', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, login_at, logout_at, user_agent
       FROM login_history
       WHERE student_id = $1
       ORDER BY login_at DESC
       LIMIT 50`,
      [req.studentId],
    );
    res.json({
      success: true,
      sessions: result.rows.map((row) => ({
        id: Number(row.id),
        loginAt: row.login_at,
        logoutAt: row.logout_at,
        userAgent: row.user_agent,
      })),
    });
  } catch (error) {
    console.error('Get login history error:', error);
    res.status(500).json({ success: false, message: 'Failed to load login history.' });
  }
});

// Confirm Company Details: manual, self-reported entry shown once all
// Startup Requirements phases are complete. This is the source of truth
// for the Home/Profile company card, independent of the HTE Directory.
router.post('/company', async (req, res) => {
  try {
    const {
      name,
      address,
      industry,
      supervisorName,
      contactNumber,
      latitude,
      longitude,
      ojtStartDate,
    } = req.body;
    const department = (req.body.department || '').toString().trim() || null;
    if (!name || !address || !industry || !supervisorName || !contactNumber) {
      return res
        .status(400)
        .json({ success: false, message: 'All company detail fields are required.' });
    }

    // System Revisions item 4: company information is a one-time entry.
    // After it's submitted only the supervisor can change (PATCH
    // /company/supervisor below). Item 21: it's reflected as entered --
    // there is no Admin approval step.
    const existing = await pool.query(
      'SELECT company_confirmed_at FROM student_profiles WHERE student_id = $1',
      [req.studentId],
    );
    if (existing.rows[0]?.company_confirmed_at) {
      return res.status(409).json({
        success: false,
        message:
          'Your company information was already submitted and can no longer be changed. You can still update your supervisor.',
      });
    }

    await pool.query(
      `INSERT INTO student_profiles
         (student_id, company_name, company_address, company_industry,
          company_supervisor_name, company_contact_number,
          company_latitude, company_longitude, ojt_start_date, company_department, company_confirmed_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, now())
       ON CONFLICT (student_id)
       DO UPDATE SET company_name = $2, company_address = $3, company_industry = $4,
         company_supervisor_name = $5, company_contact_number = $6,
         company_latitude = $7, company_longitude = $8, ojt_start_date = $9, company_department = $10,
         company_confirmed_at = now(), updated_at = now()`,
      [
        req.studentId,
        name,
        address,
        industry,
        supervisorName,
        contactNumber,
        latitude ?? null,
        longitude ?? null,
        ojtStartDate ?? null,
        department,
      ],
    );

    // System Revisions item 17: the student appears under their company in
    // the HTE Directory (added there automatically if not yet listed).
    try {
      await linkStudentToHte(req.studentId, { name, address, industry });
    } catch (linkError) {
      console.error('Link student to HTE error:', linkError);
    }

    res.json({ success: true });
  } catch (error) {
    console.error('Submit company details error:', error);
    res.status(500).json({ success: false, message: 'Failed to save company details.' });
  }
});

// System Revisions item 5: the supervisor may change after deployment, so
// the supervisor's name and contact number stay editable.
router.patch('/company/supervisor', async (req, res) => {
  try {
    const supervisorName = (req.body.supervisorName || '').toString().trim();
    const contactNumber = (req.body.contactNumber || '').toString().trim();
    if (!supervisorName || !contactNumber) {
      return res.status(400).json({
        success: false,
        message: 'Supervisor name and contact number are required.',
      });
    }
    const updated = await pool.query(
      `UPDATE student_profiles
       SET company_supervisor_name = $1, company_contact_number = $2,
           company_department = CASE WHEN $4::boolean THEN $5 ELSE company_department END,
           updated_at = now()
       WHERE student_id = $3 AND company_confirmed_at IS NOT NULL
       RETURNING student_id`,
      [
        supervisorName,
        contactNumber,
        req.studentId,
        req.body.department !== undefined,
        (req.body.department || '').toString().trim() || null,
      ],
    );
    if (updated.rows.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Submit your company information first.',
      });
    }
    res.json({ success: true });
  } catch (error) {
    console.error('Update supervisor error:', error);
    res.status(500).json({ success: false, message: 'Failed to update supervisor.' });
  }
});

router.patch('/password', async (req, res) => {
  try {
    const currentPassword = (req.body.currentPassword || '').toString();
    const newPassword = (req.body.newPassword || '').toString();
    const found = await pool.query('SELECT password_hash, must_change_password FROM students WHERE id = $1', [
      req.studentId,
    ]);
    const hash = found.rows[0]?.password_hash;
    // Right after an instructor reset, the student already signed in with
    // the temporary password, so it isn't asked for again.
    const forced = found.rows[0]?.must_change_password === true;
    if (!newPassword || (!forced && !currentPassword)) {
      return res.status(400).json({ success: false, message: 'Enter your current and new password.' });
    }
    const weak = passwordProblem(newPassword);
    if (weak) {
      return res.status(400).json({ success: false, message: weak });
    }
    if (!hash || (!forced && !(await bcrypt.compare(currentPassword, hash)))) {
      return res.status(401).json({ success: false, message: 'Current password is incorrect.' });
    }
    if (await bcrypt.compare(newPassword, hash)) {
      return res.status(400).json({ success: false, message: 'Choose a password different from your current one.' });
    }
    await pool.query('UPDATE students SET password_hash = $1, must_change_password = false, password_changed_at = now(), updated_at = now() WHERE id = $2', [
      await bcrypt.hash(newPassword, 10),
      req.studentId,
    ]);
    res.json({ success: true });
  } catch (error) {
    console.error('Change student password error:', error);
    res.status(500).json({ success: false, message: 'Failed to change password.' });
  }
});

router.post('/avatar', upload.single('avatar'), async (req, res) => {
  try {
    if (!req.file) {
      return res
        .status(400)
        .json({ success: false, message: 'No image uploaded (jpg/png/webp only).' });
    }
    const avatarUrl = req.file.url;
    await pool.query('UPDATE students SET avatar_url = $1, updated_at = now() WHERE id = $2', [
      avatarUrl,
      req.studentId,
    ]);
    res.json({ success: true, avatarUrl });
  } catch (error) {
    console.error('Upload avatar error:', error);
    res.status(500).json({ success: false, message: 'Failed to upload avatar.' });
  }
});

module.exports = router;
