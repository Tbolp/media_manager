package models

import (
	"database/sql"
	"time"
)

type MediaLibrary struct {
	ID        string    `db:"id" json:"id"`
	Name      string    `db:"name" json:"name"`
	Path      string    `db:"path" json:"-"`
	LibType   string    `db:"lib_type" json:"lib_type"`
	IsDeleted bool      `db:"is_deleted" json:"-"`
	CreatedAt time.Time `db:"created_at" json:"created_at"`
}

type MediaFile struct {
	ID           string        `db:"id" json:"id"`
	LibraryID    string        `db:"library_id" json:"-"`
	Filename     string        `db:"filename" json:"filename"`
	RelativePath string        `db:"relative_path" json:"relative_path"`
	FileType     string        `db:"file_type" json:"file_type"`
	Duration     sql.NullFloat64 `db:"duration" json:"-"`
	Size         sql.NullInt64   `db:"size" json:"-"`
	IndexedAt    time.Time     `db:"indexed_at" json:"-"`
}
