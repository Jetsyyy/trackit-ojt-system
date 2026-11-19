-- ============================================================
-- TRACKIT migration: Official Requirements managed by Admin
-- (System Revisions items 6, 15)
--
-- Run this AFTER migration_phase2_accounts.sql. Non-destructive and safe
-- to re-run.
--
-- issued_by names the office a student gets a requirement from (e.g. the
-- Clinic issues the Medical Certificate, the Registrar the Registration
-- Form). Such requirements have no downloadable template on the Student
-- side -- the student obtains them from that office directly (item 6).
-- ============================================================

ALTER TABLE ojt_requirement_templates
  ADD COLUMN IF NOT EXISTS issued_by TEXT;

UPDATE ojt_requirement_templates
SET issued_by = 'Clinic'
WHERE issued_by IS NULL AND LOWER(name) LIKE 'medical certificate%';

UPDATE ojt_requirement_templates
SET issued_by = 'Registrar'
WHERE issued_by IS NULL AND LOWER(name) LIKE 'registration%form%';
