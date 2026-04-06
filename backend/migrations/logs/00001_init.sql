-- +goose Up
CREATE TABLE logs (
    id         TEXT PRIMARY KEY,
    created_at DATETIME NOT NULL DEFAULT (datetime('now')),
    message    TEXT NOT NULL
);

CREATE INDEX idx_logs_created_at ON logs(created_at DESC);

-- +goose Down
DROP TABLE logs;
