-- Faculty revision (Admin Side 2.3): one section per program + section +
-- academic year. Names are compared without case, spaces or punctuation,
-- so "BSIT 4A", "bsit 4-A" and "BS IT 4A" count as the same section.
-- Fails (and changes nothing) if duplicates already exist; remove or rename
-- them first. Safe to re-run.
CREATE UNIQUE INDEX IF NOT EXISTS instructor_classes_unique_section
  ON instructor_classes (
    regexp_replace(lower(program), '[^a-z0-9]', '', 'g'),
    regexp_replace(lower(section), '[^a-z0-9]', '', 'g'),
    academic_year
  );
