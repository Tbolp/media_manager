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
