-- Admin > Documents (UI revision): photocopies required, who last changed
-- each requirement and when, and the template file's size and upload
-- time. Non-destructive; safe to re-run.
ALTER TABLE ojt_requirement_templates ADD COLUMN IF NOT EXISTS copies_required INT NOT NULL DEFAULT 1;
ALTER TABLE ojt_requirement_templates ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;
ALTER TABLE ojt_requirement_templates ADD COLUMN IF NOT EXISTS updated_by BIGINT;
ALTER TABLE ojt_requirement_templates ADD COLUMN IF NOT EXISTS template_size BIGINT;
ALTER TABLE ojt_requirement_templates ADD COLUMN IF NOT EXISTS template_uploaded_at TIMESTAMPTZ;
