package services

import (
	"fmt"

	"github.com/google/uuid"

	"media-manager/internal/database"
)

// WriteLog writes a log entry to the logs database.
func WriteLog(message string) {
	_, err := database.LogsDB.Exec(
		"INSERT INTO logs (id, created_at, message) VALUES (?, datetime('now'), ?)",
		uuid.New().String(), message)
	if err != nil {
		fmt.Printf("WARNING: failed to write log: %v\n", err)
	}
}

// LogUser formats a user as "username(id)" for log messages.
func LogUser(username, id string) string {
	return fmt.Sprintf("%s(%s)", username, id)
}

// LogLibrary formats a library as "name(id)" for log messages.
func LogLibrary(name, id string) string {
	return fmt.Sprintf("%s(%s)", name, id)
}

// GetLibraryNameByID returns the library name for logging. Returns id if not found.
func GetLibraryNameByID(libraryID string) string {
	var name string
	err := database.AppDB.Get(&name, "SELECT name FROM media_libraries WHERE id = ?", libraryID)
	if err != nil {
		return libraryID
	}
	return name
}
