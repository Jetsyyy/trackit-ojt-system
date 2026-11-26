const express = require('express');
const fs = require('fs');
const multer = require('multer');
const { uploadStorage, removeStored } = require('../utils/storage');
const path = require('path');
const pool = require('../db');
const { requireAdminAuth } = require('../middleware/adminAuth');
const { requirementFileFilter } = require('../utils/requirementFileTypes');

// Official Requirements catalog, managed by the Admin only (System
// Revisions item 15): the requirement list and order (so the corrected
// list from item 7 can be entered here), each requirement's template
// file, and which office issues it (item 6 -- issued requirements have no
// student download).

const router = express.Router();
router.use(requireAdminAuth);

const uploadTemplate = multer({
  storage: uploadStorage('requirements/templates'),
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: requirementFileFilter,
});

function toRequirementJson(t) {
  return {
    id: Number(t.id),
    phaseId: Number(t.phase_id),
    name: t.name,
    description: t.description,
    sortOrder: t.sort_order,
    issuedBy: t.issued_by || null,
    templateUrl: t.template_url || null,
    templateName: t.template_name || null,
    submissionCount: t.submission_count != null ? Number(t.submission_count) : undefined,
    copiesRequired: t.copies_required != null ? Number(t.copies_required) : 1,
    updatedAt: t.updated_at || null,
    updatedByName: t.updated_by_name || null,
    templateSize: t.template_size != null ? Number(t.template_size) : null,
    templateUploadedAt: t.template_uploaded_at || null,
  };
}

// Photocopies required: a whole number 0-20, or null when not given.
function copiesFrom(value) {
  if (value === undefined || value === null || value === '') return null;
  const n = Number(value);
  if (!Number.isInteger(n) || n < 0 || n > 20) return null;
  return n;
}

function cleanText(value) {
  return value == null ? null : value.toString().trim() || null;
}

// Template files no longer referenced are deleted from disk.
function removeTemplateFile(url) {
  removeStored(url);
}

router.get('/', async (req, res) => {
  try {
    const [phases, templates] = await Promise.all([
      pool.query('SELECT * FROM ojt_requirement_phases ORDER BY order_index ASC'),
      pool.query(
        `SELECT t.*, COUNT(s.id) AS submission_count, a.name AS updated_by_name
         FROM ojt_requirement_templates t
         LEFT JOIN student_requirement_submissions s ON s.requirement_template_id = t.id
         LEFT JOIN admins a ON a.id = t.updated_by
         GROUP BY t.id, a.name
         ORDER BY t.phase_id, t.sort_order ASC, t.id ASC`,
      ),
    ]);
    res.json({
      success: true,
      phases: phases.rows.map((p) => ({
        id: Number(p.id),
        order: p.order_index,
        title: p.title,
        description: p.description,
        requirements: templates.rows
          .filter((t) => Number(t.phase_id) === Number(p.id))
          .map(toRequirementJson),
      })),
    });
  } catch (error) {
    console.error('Get admin requirements error:', error);
    res.status(500).json({ success: false, message: 'Failed to load requirements.' });
  }
});

// Body: { phaseId, name, description, issuedBy } -- appended to the end
// of the phase.
router.post('/', async (req, res) => {
  try {
    const phaseId = Number(req.body.phaseId);
    const name = cleanText(req.body.name);
    if (!name) {
      return res.status(400).json({ success: false, message: 'Requirement name is required.' });
    }
    const phase = await pool.query('SELECT id FROM ojt_requirement_phases WHERE id = $1', [phaseId]);
    if (phase.rows.length === 0) {
      return res.status(400).json({ success: false, message: 'Pick a valid phase.' });
    }
    const inserted = await pool.query(
      `INSERT INTO ojt_requirement_templates
         (phase_id, name, description, issued_by, has_template, sort_order,
          copies_required, updated_at, updated_by)
       VALUES ($1, $2, $3, $4, false,
               (SELECT COALESCE(MAX(sort_order), 0) + 1 FROM ojt_requirement_templates WHERE phase_id = $1),
               $5, now(), $6)
       RETURNING *`,
      [
        phaseId,
        name,
        cleanText(req.body.description) || '',
        cleanText(req.body.issuedBy),
        copiesFrom(req.body.copiesRequired) ?? 1,
        req.adminId,
      ],
    );
    res.status(201).json({ success: true, requirement: toRequirementJson(inserted.rows[0]) });
  } catch (error) {
    console.error('Create requirement error:', error);
    res.status(500).json({ success: false, message: 'Failed to add the requirement.' });
  }
});

// Body: any of { name, description, issuedBy }. issuedBy: null/'' clears it.
router.patch('/:id', async (req, res) => {
  try {
    const id = Number(req.params.id);
    const fields = [];
    const values = [];
    if (req.body.name !== undefined) {
      const name = cleanText(req.body.name);
      if (!name) {
        return res.status(400).json({ success: false, message: 'Requirement name is required.' });
      }
      values.push(name);
      fields.push(`name = $${values.length}`);
    }
    if (req.body.description !== undefined) {
      values.push(cleanText(req.body.description) || '');
      fields.push(`description = $${values.length}`);
    }
    let dropTemplateUrl = null;
    if (req.body.issuedBy !== undefined) {
      const issuedBy = cleanText(req.body.issuedBy);
      values.push(issuedBy);
      fields.push(`issued_by = $${values.length}`);
      // An office-issued document (e.g. Medical Certificate from the Clinic)
      // has no TrackIT template: students submit the actual issued
      // document, so any stored template is removed.
      if (issuedBy) {
        const current = await pool.query('SELECT template_url FROM ojt_requirement_templates WHERE id = $1', [id]);
        dropTemplateUrl = current.rows[0]?.template_url || null;
        fields.push(
          'template_url = NULL',
          'template_name = NULL',
          'has_template = false',
          'template_size = NULL',
          'template_uploaded_at = NULL',
        );
      }
    }
    if (req.body.copiesRequired !== undefined) {
      const copies = copiesFrom(req.body.copiesRequired);
      if (copies === null) {
        return res.status(400).json({ success: false, message: 'Photocopies must be a whole number from 0 to 20.' });
      }
      values.push(copies);
      fields.push(`copies_required = $${values.length}`);
    }
    if (req.body.phaseId !== undefined) {
      // Moving to another stage puts it at the end of that stage.
      const phaseId = Number(req.body.phaseId);
      const phase = await pool.query('SELECT id FROM ojt_requirement_phases WHERE id = $1', [phaseId]);
      if (phase.rows.length === 0) {
        return res.status(400).json({ success: false, message: 'Pick a valid stage.' });
      }
      const current = await pool.query('SELECT phase_id FROM ojt_requirement_templates WHERE id = $1', [id]);
      if (current.rows[0] && Number(current.rows[0].phase_id) !== phaseId) {
        values.push(phaseId);
        fields.push(`phase_id = $${values.length}::bigint`);
        fields.push(
          `sort_order = (SELECT COALESCE(MAX(sort_order), 0) + 1 FROM ojt_requirement_templates WHERE phase_id = $${values.length}::bigint)`,
        );
      }
    }
    if (fields.length === 0) {
      return res.status(400).json({ success: false, message: 'Nothing to update.' });
    }
    values.push(req.adminId);
    fields.push(`updated_by = $${values.length}`, 'updated_at = now()');
    values.push(id);
    const updated = await pool.query(
      `UPDATE ojt_requirement_templates SET ${fields.join(', ')} WHERE id = $${values.length} RETURNING *`,
      values,
    );
    if (updated.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Requirement not found.' });
    }
    if (dropTemplateUrl) removeTemplateFile(dropTemplateUrl);
    res.json({ success: true, requirement: toRequirementJson(updated.rows[0]) });
  } catch (error) {
    console.error('Update requirement error:', error);
    res.status(500).json({ success: false, message: 'Failed to update the requirement.' });
  }
});

// Body: { direction: 'up' | 'down' } -- swaps with the neighbour in the
// same phase. Students see requirements in this order.
router.patch('/:id/move', async (req, res) => {
  const client = await pool.connect();
  try {
    const id = Number(req.params.id);
    const direction = req.body.direction === 'up' ? 'up' : 'down';
    await client.query('BEGIN');
    const current = await client.query(
      'SELECT id, phase_id, sort_order FROM ojt_requirement_templates WHERE id = $1 FOR UPDATE',
      [id],
    );
    if (current.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ success: false, message: 'Requirement not found.' });
    }
    // Normalise to 1..n first so equal or gapped sort_order values can't
    // make a swap a no-op.
    const siblings = await client.query(
      `SELECT id FROM ojt_requirement_templates WHERE phase_id = $1
       ORDER BY sort_order ASC, id ASC FOR UPDATE`,
      [current.rows[0].phase_id],
    );
    const order = siblings.rows.map((r) => Number(r.id));
    const index = order.indexOf(id);
    const target = direction === 'up' ? index - 1 : index + 1;
    if (target >= 0 && target < order.length) {
      [order[index], order[target]] = [order[target], order[index]];
    }
    for (let i = 0; i < order.length; i++) {
      await client.query('UPDATE ojt_requirement_templates SET sort_order = $1 WHERE id = $2', [
        i + 1,
        order[i],
      ]);
    }
    await client.query('COMMIT');
    res.json({ success: true });
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    console.error('Move requirement error:', error);
    res.status(500).json({ success: false, message: 'Failed to reorder.' });
  } finally {
    client.release();
  }
});

// Only a requirement nobody has submitted yet can be deleted, so no
// student's uploaded document is ever orphaned.
router.delete('/:id', async (req, res) => {
  try {
    const id = Number(req.params.id);
    const used = await pool.query(
      'SELECT COUNT(*)::int AS count FROM student_requirement_submissions WHERE requirement_template_id = $1',
      [id],
    );
    if (used.rows[0].count > 0) {
      return res.status(409).json({
        success: false,
        message: `${used.rows[0].count} student submission(s) already use this requirement, so it can't be deleted. Rename it instead.`,
      });
    }
    const deleted = await pool.query(
      'DELETE FROM ojt_requirement_templates WHERE id = $1 RETURNING template_url',
      [id],
    );
    if (deleted.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Requirement not found.' });
    }
    removeTemplateFile(deleted.rows[0].template_url);
    res.json({ success: true });
  } catch (error) {
    console.error('Delete requirement error:', error);
    res.status(500).json({ success: false, message: 'Failed to delete the requirement.' });
  }
});

// Office-issued documents never take a TrackIT template; refuse before the
// file is stored anywhere.
async function rejectIfIssued(req, res, next) {
  try {
    const found = await pool.query('SELECT issued_by FROM ojt_requirement_templates WHERE id = $1', [
      Number(req.params.id),
    ]);
    const office = found.rows[0]?.issued_by;
    if (office) {
      return res.status(400).json({
        success: false,
        message: `This document is issued by the ${office}, so it has no TrackIT template. Students submit the actual issued document.`,
      });
    }
    next();
  } catch (error) {
    next(error);
  }
}

// Upload or replace the downloadable template (pdf/doc/docx/xls/xlsx).
router.post('/:id/template', rejectIfIssued, uploadTemplate.single('template'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'No file uploaded (PDF, DOC, DOCX, XLS or XLSX only).',
      });
    }
    const id = Number(req.params.id);
    const previous = await pool.query(
      'SELECT template_url, issued_by FROM ojt_requirement_templates WHERE id = $1',
      [id],
    );
    if (previous.rows.length === 0) {
      removeStored(req.file.url);
      return res.status(404).json({ success: false, message: 'Requirement not found.' });
    }
    if (previous.rows[0].issued_by) {
      removeStored(req.file.url);
      return res.status(400).json({
        success: false,
        message: `This document is issued by the ${previous.rows[0].issued_by}, so it has no TrackIT template. Students submit the actual issued document.`,
      });
    }
    const updated = await pool.query(
      `UPDATE ojt_requirement_templates
       SET template_url = $1, template_name = $2, has_template = true,
           template_size = $4, template_uploaded_at = now(), updated_at = now(), updated_by = $5
       WHERE id = $3 RETURNING *`,
      [req.file.url, req.file.originalname, id, req.file.size, req.adminId],
    );
    removeTemplateFile(previous.rows[0].template_url);
    res.json({ success: true, requirement: toRequirementJson(updated.rows[0]) });
  } catch (error) {
    console.error('Upload requirement template error:', error);
    res.status(500).json({ success: false, message: 'Failed to upload the template.' });
  }
});

router.delete('/:id/template', async (req, res) => {
  try {
    const id = Number(req.params.id);
    const previous = await pool.query(
      'SELECT template_url FROM ojt_requirement_templates WHERE id = $1',
      [id],
    );
    if (previous.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Requirement not found.' });
    }
    const updated = await pool.query(
      `UPDATE ojt_requirement_templates
       SET template_url = NULL, template_name = NULL, has_template = false,
           template_size = NULL, template_uploaded_at = NULL, updated_at = now(), updated_by = $2
       WHERE id = $1 RETURNING *`,
      [id, req.adminId],
    );
    removeTemplateFile(previous.rows[0].template_url);
    res.json({ success: true, requirement: toRequirementJson(updated.rows[0]) });
  } catch (error) {
    console.error('Remove requirement template error:', error);
    res.status(500).json({ success: false, message: 'Failed to remove the template.' });
  }
});

module.exports = router;
