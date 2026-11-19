-- ============================================================
-- TRACKIT migration: Account approvals (System Revisions items 11, 19)
--
-- Run this AFTER migration_weekly_dtr_submissions.sql. Non-destructive
-- and safe to re-run. Every existing student and instructor is treated
-- as already approved.
-- ============================================================

-- ---------- Item 11: instructors approve student registrations ----------
-- A self-registered student is 'pending' until the instructor of the
-- section they registered into approves them. Until then the section is
-- only REQUESTED (student_profiles.requested_class_id); class_id and
-- adviser_id stay NULL, so a pending student never appears in any
-- instructor or admin student list, count or report.
ALTER TABLE students
  ADD COLUMN IF NOT EXISTS approval_status TEXT NOT NULL DEFAULT 'approved',
  ADD COLUMN IF NOT EXISTS approval_decided_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS approval_decided_by BIGINT REFERENCES advisers(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

DO $$ BEGIN
  ALTER TABLE students
    ADD CONSTRAINT students_approval_status_check
    CHECK (approval_status IN ('pending', 'approved', 'rejected'));
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE student_profiles
  ADD COLUMN IF NOT EXISTS requested_class_id BIGINT REFERENCES instructor_classes(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_student_profiles_requested_class
  ON student_profiles (requested_class_id);

-- ---------- Item 19: admin-generated instructor registration codes ----------
-- The admin generates a single-use code and hands it to one instructor,
-- who registers with their own details. The account is 'pending' until
-- the admin approves it and assigns its section(s).
CREATE TABLE IF NOT EXISTS instructor_registration_codes (
  id            BIGSERIAL PRIMARY KEY,
  code          TEXT NOT NULL UNIQUE,
  note          TEXT,
  created_by    BIGINT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  used_at       TIMESTAMPTZ,
  used_by       BIGINT REFERENCES advisers(id) ON DELETE SET NULL,
  revoked_at    TIMESTAMPTZ
);

ALTER TABLE advisers
  ADD COLUMN IF NOT EXISTS approval_status TEXT NOT NULL DEFAULT 'approved',
  ADD COLUMN IF NOT EXISTS approval_decided_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

DO $$ BEGIN
  ALTER TABLE advisers
    ADD CONSTRAINT advisers_approval_status_check
    CHECK (approval_status IN ('pending', 'approved', 'rejected'));
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;
