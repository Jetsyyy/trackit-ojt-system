-- ============================================================
-- TRACKIT migration: HTE Directory placements, reports, archiving
-- (System Revisions items 17, 18, 20, 22)
--
-- Run this AFTER migration_phase3_requirements.sql. Non-destructive and
-- safe to re-run.
-- ============================================================

-- ---------- Item 17: students linked to their HTE ----------
-- 'student' = added automatically from a student's company details (the
-- admin can complete location/contacts); 'admin' = entered by the admin.
ALTER TABLE hte_companies
  ADD COLUMN IF NOT EXISTS source TEXT NOT NULL DEFAULT 'admin';

-- Student-added entries have no company email.
ALTER TABLE hte_companies ALTER COLUMN email DROP NOT NULL;

-- Backfill: every company a student already entered becomes a directory
-- entry (when not already listed), then each student is linked to it.
INSERT INTO hte_companies (name, industry, address, source)
SELECT DISTINCT ON (LOWER(TRIM(sp.company_name)))
       TRIM(sp.company_name),
       COALESCE(NULLIF(TRIM(sp.company_industry), ''), 'Not specified'),
       COALESCE(NULLIF(TRIM(sp.company_address), ''), 'Not specified'),
       'student'
FROM student_profiles sp
WHERE sp.company_name IS NOT NULL AND TRIM(sp.company_name) <> ''
  AND NOT EXISTS (
    SELECT 1 FROM hte_companies c WHERE LOWER(TRIM(c.name)) = LOWER(TRIM(sp.company_name))
  )
ORDER BY LOWER(TRIM(sp.company_name)), sp.company_confirmed_at DESC NULLS LAST;

UPDATE students s
SET company_id = c.id
FROM student_profiles sp, hte_companies c
WHERE sp.student_id = s.id
  AND sp.company_name IS NOT NULL
  AND LOWER(TRIM(c.name)) = LOWER(TRIM(sp.company_name))
  AND s.company_id IS DISTINCT FROM c.id;

-- ---------- Item 20: explicit active academic year ----------
CREATE TABLE IF NOT EXISTS app_settings (
  key         TEXT PRIMARY KEY,
  value       TEXT NOT NULL,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Starts as the newest year that has sections (what the app treated as
-- "current" until now).
INSERT INTO app_settings (key, value)
SELECT 'active_academic_year', MAX(academic_year) FROM instructor_classes
HAVING MAX(academic_year) IS NOT NULL
ON CONFLICT (key) DO NOTHING;

-- One snapshot per archived year: that year's HTE Directory with each
-- company's students, frozen at the moment of archiving.
CREATE TABLE IF NOT EXISTS hte_archives (
  id             BIGSERIAL PRIMARY KEY,
  academic_year  TEXT NOT NULL UNIQUE,
  archived_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  archived_by    BIGINT,
  snapshot       JSONB NOT NULL
);
