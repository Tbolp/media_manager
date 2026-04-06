package database

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/jmoiron/sqlx"
	_ "modernc.org/sqlite"
)

var (
	AppDB  *sqlx.DB
	LogsDB *sqlx.DB
)

func Init(dataDir string) error {
	if err := os.MkdirAll(dataDir, 0755); err != nil {
		return fmt.Errorf("create data dir: %w", err)
	}

	var err error
	AppDB, err = openDB(filepath.Join(dataDir, "app.db"))
	if err != nil {
		return fmt.Errorf("open app.db: %w", err)
	}

	LogsDB, err = openDB(filepath.Join(dataDir, "logs.db"))
	if err != nil {
		return fmt.Errorf("open logs.db: %w", err)
	}

	return nil
}

func Close() {
	if AppDB != nil {
		AppDB.Close()
	}
	if LogsDB != nil {
		LogsDB.Close()
	}
}

func openDB(path string) (*sqlx.DB, error) {
	db, err := sqlx.Open("sqlite", path)
	if err != nil {
		return nil, err
	}

	// Enable WAL mode for concurrent read-write
	if _, err := db.Exec("PRAGMA journal_mode=WAL"); err != nil {
		db.Close()
		return nil, fmt.Errorf("set WAL mode: %w", err)
	}

	// Enable foreign keys
	if _, err := db.Exec("PRAGMA foreign_keys=ON"); err != nil {
		db.Close()
		return nil, fmt.Errorf("enable foreign keys: %w", err)
	}

	// SQLite should use a single connection to avoid locking issues
	db.SetMaxOpenConns(1)

	return db, nil
}
