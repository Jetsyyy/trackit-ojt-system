-- ============================================================
-- TRACKIT migration: Weekly DTR + AR submissions (System Revisions,
-- items 1-3, 9-10, 13)
--
-- Run this AFTER migration_admin_instructors.sql. Non-destructive and
-- safe to re-run.
--
-- Daily clock in/out is retired. Each OJT week the student uploads a
-- DTR (Daily Time Record) and an AR (Accomplishment Report) and enters
-- the hours being claimed for that week. The assigned instructor then
-- approves or rejects the week. Credited hours = SUM(claimed_hours) of
-- approved weeks only (see utils/creditedHours.js).
--
-- attendance_records / attendance_corrections are left in place, just
-- unused for hours going forward.
-- ============================================================

-- 'rejected' is what the app and API already use for a returned week;
-- the original enum only had 'needs_revision'.
ALTER TYPE activity_report_status ADD VALUE IF NOT EXISTS 'rejected';

-- submitted_at was read/written by routes/activityReports.js since the
-- weekly AR migration but never actually created, so submitting a weekly
-- report failed with "column does not exist".
ALTER TABLE activity_reports
  ADD COLUMN IF NOT EXISTS submitted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS claimed_hours NUMERIC(6,2),
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS reviewed_by BIGINT REFERENCES advisers(id) ON DELETE SET NULL;

DO $$ BEGIN
  ALTER TABLE activity_reports
    ADD CONSTRAINT activity_reports_claimed_hours_range
    CHECK (claimed_hours IS NULL OR (claimed_hours > 0 AND claimed_hours <= 168));
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Each attachment is either the week's DTR or its AR. Existing rows
-- (pre-revision AR-only uploads, file name only) are tagged 'ar'.
ALTER TABLE activity_report_attachments
  ADD COLUMN IF NOT EXISTS kind TEXT NOT NULL DEFAULT 'ar';

DO $$ BEGIN
  ALTER TABLE activity_report_attachments
    ADD CONSTRAINT activity_report_attachments_kind_check CHECK (kind IN ('dtr', 'ar'));
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_activity_reports_student_status
  ON activity_reports (student_id, status);
