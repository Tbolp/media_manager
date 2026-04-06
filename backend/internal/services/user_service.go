package services

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"

	"media-manager/internal/core"
	"media-manager/internal/database"
	"media-manager/internal/models"
)

// CreateUser creates a new user. Returns error if username already exists among non-deleted users.
func CreateUser(username, password, role string) (*models.User, error) {
	// Check username uniqueness among non-deleted users
	var count int
	if err := database.AppDB.Get(&count,
		"SELECT COUNT(*) FROM users WHERE username = ? AND is_deleted = FALSE", username); err != nil {
		return nil, fmt.Errorf("check username: %w", err)
	}
	if count > 0 {
		return nil, fmt.Errorf("用户名已被使用")
	}

	hash, err := core.HashPassword(password)
	if err != nil {
		return nil, fmt.Errorf("hash password: %w", err)
	}

	user := &models.User{
		ID:           uuid.New().String(),
		Username:     username,
		PasswordHash: hash,
		Role:         role,
		LibraryIDs:   "[]",
		CreatedAt:    time.Now().UTC(),
	}

	_, err = database.AppDB.Exec(
		`INSERT INTO users (id, username, password_hash, role, library_ids, created_at)
		 VALUES (?, ?, ?, ?, ?, ?)`,
		user.ID, user.Username, user.PasswordHash, user.Role, user.LibraryIDs, user.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("insert user: %w", err)
	}

	return user, nil
}

// GetUserByUsername fetches a non-deleted user by username.
func GetUserByUsername(username string) (*models.User, error) {
	var user models.User
	err := database.AppDB.Get(&user,
		"SELECT * FROM users WHERE username = ? AND is_deleted = FALSE", username)
	if err != nil {
		return nil, err
	}
	return &user, nil
}

// GetUserByID fetches a user by ID (including deleted).
func GetUserByID(id string) (*models.User, error) {
	var user models.User
	err := database.AppDB.Get(&user, "SELECT * FROM users WHERE id = ?", id)
	if err != nil {
		return nil, err
	}
	return &user, nil
}

// ListUsers returns all non-deleted users (including disabled).
func ListUsers() ([]models.User, error) {
	var users []models.User
	err := database.AppDB.Select(&users,
		"SELECT * FROM users WHERE is_deleted = FALSE ORDER BY created_at ASC")
	if err != nil {
		return nil, err
	}
	return users, nil
}

// CountUsers returns the total number of non-deleted users.
func CountUsers() (int, error) {
	var count int
	err := database.AppDB.Get(&count, "SELECT COUNT(*) FROM users WHERE is_deleted = FALSE")
	return count, err
}

// IncrementTokenVersion bumps token_version to invalidate all existing tokens.
func IncrementTokenVersion(userID string) error {
	_, err := database.AppDB.Exec(
		"UPDATE users SET token_version = token_version + 1 WHERE id = ?", userID)
	return err
}

// DisableUser disables a user and increments their token version.
func DisableUser(userID string) error {
	_, err := database.AppDB.Exec(
		"UPDATE users SET is_disabled = TRUE, token_version = token_version + 1 WHERE id = ?", userID)
	return err
}

// EnableUser re-enables a user.
func EnableUser(userID string) error {
	_, err := database.AppDB.Exec(
		"UPDATE users SET is_disabled = FALSE WHERE id = ?", userID)
	return err
}

// DeleteUser soft-deletes a user and cleans up their behavior data.
func DeleteUser(userID string) error {
	now := time.Now().UTC()
	_, err := database.AppDB.Exec(
		`UPDATE users SET is_deleted = TRUE, deleted_at = ?, token_version = token_version + 1
		 WHERE id = ?`, now, userID)
	if err != nil {
		return err
	}

	// Clean up behavior data
	_, _ = database.AppDB.Exec("DELETE FROM playback_progress WHERE user_id = ?", userID)
	_, _ = database.AppDB.Exec("DELETE FROM watch_history WHERE user_id = ?", userID)

	return nil
}

// ResetPassword updates the password and increments token version.
func ResetPassword(userID, newPassword string) error {
	hash, err := core.HashPassword(newPassword)
	if err != nil {
		return fmt.Errorf("hash password: %w", err)
	}
	_, err = database.AppDB.Exec(
		"UPDATE users SET password_hash = ?, token_version = token_version + 1 WHERE id = ?",
		hash, userID)
	return err
}

// UpdatePermissions updates a user's library whitelist.
func UpdatePermissions(userID string, libraryIDs []string) error {
	data, err := json.Marshal(libraryIDs)
	if err != nil {
		return err
	}
	_, err = database.AppDB.Exec(
		"UPDATE users SET library_ids = ? WHERE id = ?", string(data), userID)
	return err
}

// Authenticate verifies username/password and returns the user.
func Authenticate(username, password string) (*models.User, error) {
	user, err := GetUserByUsername(username)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("用户名或密码错误")
		}
		return nil, err
	}

	if !core.CheckPassword(password, user.PasswordHash) {
		return nil, fmt.Errorf("用户名或密码错误")
	}

	if user.IsDisabled {
		return nil, fmt.Errorf("账号已被停用，请联系管理员")
	}

	return user, nil
}
