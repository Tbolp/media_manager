package services

import (
	"database/sql"
	"time"

	"github.com/google/uuid"

	"media-manager/internal/database"
)

// UpsertProgress updates or inserts a playback progress record.
// Marks as watched if position >= 90% of duration.
func UpsertProgress(userID, fileID string, position, duration float64) error {
	isWatched := false
	if duration > 0 && position/duration >= 0.9 {
		isWatched = true
	}

	now := time.Now().UTC()

	// Try update first
	result, err := database.AppDB.Exec(
		`UPDATE playback_progress SET position = ?, duration = ?, is_watched = CASE WHEN is_watched = TRUE THEN TRUE ELSE ? END, updated_at = ?
		 WHERE user_id = ? AND file_id = ?`,
		position, duration, isWatched, now, userID, fileID)
	if err != nil {
		return err
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected > 0 {
		return nil
	}

	// Insert new record
	_, err = database.AppDB.Exec(
		`INSERT INTO playback_progress (id, user_id, file_id, position, duration, is_watched, updated_at)
		 VALUES (?, ?, ?, ?, ?, ?, ?)`,
		uuid.New().String(), userID, fileID, position, duration, isWatched, now)
	return err
}

// UpsertWatchHistory records or updates a watch history entry.
func UpsertWatchHistory(userID, fileID string) error {
	now := time.Now().UTC()

	// Try update first
	result, err := database.AppDB.Exec(
		"UPDATE watch_history SET watched_at = ? WHERE user_id = ? AND file_id = ?",
		now, userID, fileID)
	if err != nil {
		return err
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected > 0 {
		return nil
	}

	// Insert new record
	_, err = database.AppDB.Exec(
		"INSERT INTO watch_history (id, user_id, file_id, watched_at) VALUES (?, ?, ?, ?)",
		uuid.New().String(), userID, fileID, now)
	return err
}

// WatchHistoryItem represents a watch history entry for API response.
type WatchHistoryItem struct {
	FileID       string          `db:"file_id" json:"file_id"`
	Filename     sql.NullString  `db:"filename" json:"-"`
	RelativePath sql.NullString  `db:"relative_path" json:"-"`
	LibraryID    sql.NullString  `db:"library_id" json:"-"`
	WatchedAt    time.Time       `db:"watched_at" json:"watched_at"`
}

// GetWatchHistory returns the user's recent watch history with file details.
func GetWatchHistory(userID string, page, pageSize int) ([]WatchHistoryItem, int, error) {
	var total int
	err := database.AppDB.Get(&total,
		"SELECT COUNT(*) FROM watch_history WHERE user_id = ?", userID)
	if err != nil {
		return nil, 0, err
	}

	offset := (page - 1) * pageSize
	var items []WatchHistoryItem
	err = database.AppDB.Select(&items,
		`SELECT wh.file_id, mf.filename, mf.relative_path, mf.library_id, wh.watched_at
		 FROM watch_history wh
		 LEFT JOIN media_files mf ON wh.file_id = mf.id
		 WHERE wh.user_id = ?
		 ORDER BY wh.watched_at DESC
		 LIMIT ? OFFSET ?`,
		userID, pageSize, offset)
	if err != nil {
		return nil, 0, err
	}

	return items, total, nil
}
