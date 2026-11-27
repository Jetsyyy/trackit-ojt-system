-- Scheduled requirements from the OJT office (admin), e.g. the
-- Supervisor Evaluation Form for "1st Semester" and again for "Final".
-- They reuse the Additional Requirements tables: the admin posts one with
-- a period and an exact due date and time; it goes to every OJT student
-- in that academic year, who are notified when it's posted and again the
-- day before it's due. Uploads after the deadline are accepted but marked
-- late. Instructor-made Additional Requirements are unchanged.
-- Safe to re-run.

ALTER TABLE custom_requirements ALTER COLUMN instructor_id DROP NOT NULL;
ALTER TABLE custom_requirements
  ADD COLUMN IF NOT EXISTS admin_id bigint REFERENCES admins(id) ON DELETE SET NULL;
-- 'classes': the sections in custom_requirement_targets (instructor-made);
-- 'all_students': every OJT student in academic_year (admin-made).
ALTER TABLE custom_requirements ADD COLUMN IF NOT EXISTS audience text NOT NULL DEFAULT 'classes';
ALTER TABLE custom_requirements ADD COLUMN IF NOT EXISTS academic_year text;
ALTER TABLE custom_requirements ADD COLUMN IF NOT EXISTS period text;
ALTER TABLE custom_requirements ADD COLUMN IF NOT EXISTS due_at timestamptz;
ALTER TABLE custom_requirements ADD COLUMN IF NOT EXISTS reminder_sent_at timestamptz;
ALTER TABLE custom_requirements ADD COLUMN IF NOT EXISTS template_size bigint;
ALTER TABLE custom_requirements ADD COLUMN IF NOT EXISTS updated_at timestamptz;

ALTER TABLE student_custom_requirement_submissions
  ADD COLUMN IF NOT EXISTS is_late boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_custom_requirements_audience_year
  ON custom_requirements (audience, academic_year);
