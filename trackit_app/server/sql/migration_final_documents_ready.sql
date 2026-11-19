-- OJT Requirements > Final Documents: "I have all the Documents Ready".
-- When the student told their instructor the final (physical) documents
-- are complete. Non-destructive; safe to re-run.
ALTER TABLE student_profiles ADD COLUMN IF NOT EXISTS final_documents_ready_at TIMESTAMPTZ;
