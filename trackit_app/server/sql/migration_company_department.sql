-- HTE Directory revision: the department a student is assigned to at
-- their company (shown beside their supervisor in the Admin's HTE
-- Directory). Entered by the student with their company details and
-- editable later, like the supervisor. Non-destructive; safe to re-run.
ALTER TABLE student_profiles ADD COLUMN IF NOT EXISTS company_department TEXT;
