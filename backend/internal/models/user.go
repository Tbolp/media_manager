package models

import (
	"database/sql"
	"time"
)

type User struct {
	ID            string       `db:"id" json:"id"`
	Username      string       `db:"username" json:"username"`
	PasswordHash  string       `db:"password_hash" json:"-"`
	Role          string       `db:"role" json:"role"`
	IsDisabled    bool         `db:"is_disabled" json:"is_disabled"`
	IsDeleted     bool         `db:"is_deleted" json:"-"`
	TokenVersion  int          `db:"token_version" json:"-"`
	LibraryIDs    string       `db:"library_ids" json:"library_ids"`
	DeletedAt     sql.NullTime `db:"deleted_at" json:"-"`
	LastActiveAt  sql.NullTime `db:"last_active_at" json:"last_active_at"`
	CreatedAt     time.Time    `db:"created_at" json:"created_at"`
}
