-- Profile "Account Security" and "Recent Account Activity" (UI revision).
-- Non-destructive; safe to re-run.

-- When the account's password was last changed ("Never changed" if null).
ALTER TABLE advisers ADD COLUMN IF NOT EXISTS password_changed_at TIMESTAMPTZ;
ALTER TABLE students ADD COLUMN IF NOT EXISTS password_changed_at TIMESTAMPTZ;
ALTER TABLE students ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMPTZ;

-- One row per account event: logged in, changed password / email / photo.
CREATE TABLE IF NOT EXISTS account_activity (
  id BIGSERIAL PRIMARY KEY,
  account_role TEXT NOT NULL CHECK (account_role IN ('student', 'instructor', 'admin')),
  account_id BIGINT NOT NULL,
  action TEXT NOT NULL,
  detail TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS account_activity_account_idx
  ON account_activity (account_role, account_id, created_at DESC);
