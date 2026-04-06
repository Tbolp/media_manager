-- +goose Up
CREATE TABLE users (
    id            TEXT PRIMARY KEY,
    username      TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    role          TEXT NOT NULL DEFAULT 'user',
    is_disabled   BOOLEAN NOT NULL DEFAULT FALSE,
    is_deleted    BOOLEAN NOT NULL DEFAULT FALSE,
    token_version INTEGER NOT NULL DEFAULT 0,
    library_ids   TEXT NOT NULL DEFAULT '[]',
    deleted_at    DATETIME NULL,
    last_active_at DATETIME NULL,
    created_at    DATETIME NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE media_libraries (
    id         TEXT PRIMARY KEY,
    name       TEXT NOT NULL,
    path       TEXT NOT NULL,
    lib_type   TEXT NOT NULL,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    created_at DATETIME NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE media_files (
    id            TEXT PRIMARY KEY,
    library_id    TEXT NOT NULL REFERENCES media_libraries(id),
    filename      TEXT NOT NULL,
    relative_path TEXT NOT NULL,
    file_type     TEXT NOT NULL,
    duration      REAL NULL,
    size          INTEGER NULL,
    indexed_at    DATETIME NOT NULL DEFAULT (datetime('now')),
    UNIQUE (library_id, relative_path)
);

CREATE TABLE playback_progress (
    id         TEXT PRIMARY KEY,
    user_id    TEXT NOT NULL REFERENCES users(id),
    file_id    TEXT NOT NULL,
    position   REAL NOT NULL,
    duration   REAL NOT NULL,
    is_watched BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at DATETIME NOT NULL DEFAULT (datetime('now')),
    UNIQUE (user_id, file_id)
);

CREATE TABLE watch_history (
    id         TEXT PRIMARY KEY,
    user_id    TEXT NOT NULL REFERENCES users(id),
    file_id    TEXT NOT NULL,
    watched_at DATETIME NOT NULL DEFAULT (datetime('now')),
    UNIQUE (user_id, file_id)
);

-- +goose Down
DROP TABLE watch_history;
DROP TABLE playback_progress;
DROP TABLE media_files;
DROP TABLE media_libraries;
DROP TABLE users;
