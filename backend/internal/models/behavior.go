package models

import "time"

type PlaybackProgress struct {
	ID        string  `db:"id" json:"id"`
	UserID    string  `db:"user_id" json:"-"`
	FileID    string  `db:"file_id" json:"file_id"`
	Position  float64 `db:"position" json:"position"`
	Duration  float64 `db:"duration" json:"duration"`
	IsWatched bool    `db:"is_watched" json:"is_watched"`
	UpdatedAt time.Time `db:"updated_at" json:"updated_at"`
}

type WatchHistory struct {
	ID        string    `db:"id" json:"id"`
	UserID    string    `db:"user_id" json:"-"`
	FileID    string    `db:"file_id" json:"file_id"`
	WatchedAt time.Time `db:"watched_at" json:"watched_at"`
}
