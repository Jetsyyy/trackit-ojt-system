-- System Revision 2 (Documents): the official OJT document list from
-- Ma'am Ellen / the Figma "Revisions" page.
--
--   Stage 1 Pre-Application:  Pre-Application Form (template), Curriculum
--                             Vitae, Application Letter
--   Stage 2 Requirements:     Endorsement Letter (template), Acceptance
--                             Letter (template), MOU / MOA (template only:
--                             download, nothing to upload), Parental Consent
--   Stage 3 Internship Docs:  Enrollment Form, Medical Certificate,
--                             Psychological Certificate, Notarized MOU/MOA,
--                             Notarized Parental Consent
--   Stage 4 Final Details:    no documents; the student's final company and
--                             supervisor information form (moved here from
--                             the separate "Account Details Finalization").
--
-- Documents no longer on the list are RETIRED, not deleted: they disappear
-- from every screen but students' earlier submissions stay in the database.
-- Safe to re-run: the data part runs only once (until Stage 4 is marked).

ALTER TABLE ojt_requirement_templates
  ADD COLUMN IF NOT EXISTS upload_required boolean NOT NULL DEFAULT true;
ALTER TABLE ojt_requirement_templates
  ADD COLUMN IF NOT EXISTS retired_at timestamptz;
ALTER TABLE ojt_requirement_phases
  ADD COLUMN IF NOT EXISTS kind text NOT NULL DEFAULT 'documents';

DO $$
DECLARE
  p1 bigint;
  p2 bigint;
  p3 bigint;
  p4 bigint;
BEGIN
  IF EXISTS (SELECT 1 FROM ojt_requirement_phases WHERE kind = 'final_details') THEN
    RETURN; -- already applied
  END IF;

  SELECT id INTO p1 FROM ojt_requirement_phases WHERE order_index = 1;
  SELECT id INTO p2 FROM ojt_requirement_phases WHERE order_index = 2;
  SELECT id INTO p3 FROM ojt_requirement_phases WHERE order_index = 3;
  SELECT id INTO p4 FROM ojt_requirement_phases WHERE order_index = 4;

  -- Stage texts.
  UPDATE ojt_requirement_phases SET description = 'Submit your Pre-Application Form, CV and Application Letter.' WHERE id = p1;
  UPDATE ojt_requirement_phases SET description = 'Submit Required Documents to proceed.' WHERE id = p2;
  UPDATE ojt_requirement_phases SET description = 'Submit Internship Related Documents.' WHERE id = p3;
  UPDATE ojt_requirement_phases
     SET title = 'Final Details',
         description = 'Confirm your company and supervisor information.',
         kind = 'final_details'
   WHERE id = p4;

  -- Retire everything first; the documents on the new list are brought
  -- back below (existing rows keep their students' submissions).
  UPDATE ojt_requirement_templates SET retired_at = now() WHERE retired_at IS NULL;

  -- Stage 1
  UPDATE ojt_requirement_templates
     SET phase_id = p1, sort_order = 1, retired_at = NULL, upload_required = true,
         description = 'School-provided form template'
   WHERE name = 'Pre-Application Form';
  UPDATE ojt_requirement_templates
     SET name = 'Curriculum Vitae', phase_id = p1, sort_order = 2, retired_at = NULL, upload_required = true,
         has_template = false, template_url = NULL, template_name = NULL,
         description = 'Personal CV prepared by the student'
   WHERE name IN ('Resume', 'Curriculum Vitae');
  UPDATE ojt_requirement_templates
     SET phase_id = p1, sort_order = 3, retired_at = NULL, upload_required = true,
         has_template = false, template_url = NULL, template_name = NULL,
         description = 'Personalized letter to the chosen company'
   WHERE name = 'Application Letter';

  -- Stage 2
  UPDATE ojt_requirement_templates
     SET phase_id = p2, sort_order = 1, retired_at = NULL, upload_required = true,
         description = 'School-issued endorsement letter'
   WHERE name = 'Endorsement Letter';
  INSERT INTO ojt_requirement_templates (phase_id, name, description, has_template, sort_order, copies_required, upload_required, updated_at)
  SELECT p2, 'Acceptance Letter', 'School-issued acceptance letter', false, 2, 1, true, now()
   WHERE NOT EXISTS (SELECT 1 FROM ojt_requirement_templates WHERE name = 'Acceptance Letter');
  UPDATE ojt_requirement_templates
     SET name = 'MOU / MOA', phase_id = p2, sort_order = 3, retired_at = NULL, upload_required = false,
         description = 'Agreement between the school and company'
   WHERE name IN ('MOA', 'MOU / MOA');
  UPDATE ojt_requirement_templates
     SET name = 'Parental Consent', phase_id = p2, sort_order = 4, retired_at = NULL, upload_required = true,
         has_template = false, template_url = NULL, template_name = NULL,
         description = 'Parent or guardian authorization letter'
   WHERE name IN ('Parent Consent', 'Parental Consent');

  -- Stage 3
  UPDATE ojt_requirement_templates
     SET name = 'Enrollment Form', phase_id = p3, sort_order = 1, retired_at = NULL, upload_required = true,
         has_template = false, description = 'School-provided enrollment proof'
   WHERE name IN ('Registration/Enrollment Form', 'Enrollment Form');
  UPDATE ojt_requirement_templates
     SET phase_id = p3, sort_order = 2, retired_at = NULL, upload_required = true,
         has_template = false, description = 'Medical fitness certification'
   WHERE name = 'Medical Certificate';
  INSERT INTO ojt_requirement_templates (phase_id, name, description, has_template, sort_order, copies_required, upload_required, updated_at)
  SELECT p3, 'Psychological Certificate', 'Psychological fitness certification', false, 3, 1, true, now()
   WHERE NOT EXISTS (SELECT 1 FROM ojt_requirement_templates WHERE name = 'Psychological Certificate');
  INSERT INTO ojt_requirement_templates (phase_id, name, description, has_template, sort_order, copies_required, upload_required, updated_at)
  SELECT p3, 'Notarized MOU/MOA', 'Notarized company-school agreement', false, 4, 1, true, now()
   WHERE NOT EXISTS (SELECT 1 FROM ojt_requirement_templates WHERE name = 'Notarized MOU/MOA');
  INSERT INTO ojt_requirement_templates (phase_id, name, description, has_template, sort_order, copies_required, upload_required, updated_at)
  SELECT p3, 'Notarized Parental Consent', 'Notarized parent or guardian consent', false, 5, 1, true, now()
   WHERE NOT EXISTS (SELECT 1 FROM ojt_requirement_templates WHERE name = 'Notarized Parental Consent');
END $$;
