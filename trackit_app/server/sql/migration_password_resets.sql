-- Student Forgot Password (System Revision 4): the student requests a
-- reset, their instructor approves it and hands over a temporary password,
-- and the student must set a new password at the next sign-in.
-- Non-destructive; safe to re-run.
CREATE TABLE IF NOT EXISTS password_reset_requests (
  id BIGSERIAL PRIMARY KEY,
  student_id BIGINT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending', -- pending | reset | dismissed
  requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at TIMESTAMPTZ,
  resolved_by BIGINT REFERENCES advisers(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS password_reset_requests_pending
  ON password_reset_requests (student_id) WHERE status = 'pending';

ALTER TABLE students ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN NOT NULL DEFAULT false;
