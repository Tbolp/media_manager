-- +goose Up
ALTER TABLE media_files ADD COLUMN parent_dir TEXT NOT NULL DEFAULT '';

-- Backfill: extract parent directory from relative_path
-- "a/b/c.mp4" → "a/b", "c.mp4" → ""
UPDATE media_files SET parent_dir =
  CASE
    WHEN INSTR(relative_path, '/') = 0 THEN ''
    ELSE SUBSTR(relative_path, 1, LENGTH(relative_path) - LENGTH(filename) - 1)
  END;

CREATE INDEX idx_media_files_parent_dir ON media_files(library_id, parent_dir, filename);

-- +goose Down
DROP INDEX IF EXISTS idx_media_files_parent_dir;
