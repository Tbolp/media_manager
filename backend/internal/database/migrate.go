package database

import (
	"database/sql"
	"fmt"
	"io/fs"

	"github.com/pressly/goose/v3"
)

func Migrate(db *sql.DB, embedFS fs.FS, migrationsDir string) error {
	goose.SetBaseFS(embedFS)
	if err := goose.SetDialect("sqlite3"); err != nil {
		return fmt.Errorf("set dialect: %w", err)
	}
	if err := goose.Up(db, migrationsDir); err != nil {
		return fmt.Errorf("run migrations from %s: %w", migrationsDir, err)
	}
	return nil
}
