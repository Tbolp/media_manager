package services

import (
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/google/uuid"

	"media-manager/internal/database"
	"media-manager/internal/models"
)

// CreateLibrary creates a new media library after validating the path and name uniqueness.
func CreateLibrary(name, dirPath, libType string) (*models.MediaLibrary, error) {
	// Validate lib_type
	if libType != "video" && libType != "camera" {
		return nil, fmt.Errorf("类型必须为 video 或 camera")
	}

	// Validate directory exists and is readable
	absPath, err := filepath.Abs(dirPath)
	if err != nil {
		return nil, fmt.Errorf("路径无效")
	}
	info, err := os.Stat(absPath)
	if err != nil || !info.IsDir() {
		return nil, fmt.Errorf("目录路径不存在或不可读")
	}

	// Check name uniqueness among non-deleted libraries
	var count int
	if err := database.AppDB.Get(&count,
		"SELECT COUNT(*) FROM media_libraries WHERE name = ? AND is_deleted = FALSE", name); err != nil {
		return nil, fmt.Errorf("check name: %w", err)
	}
	if count > 0 {
		return nil, fmt.Errorf("名称已存在，请修改后重试")
	}

	lib := &models.MediaLibrary{
		ID:        uuid.New().String(),
		Name:      name,
		Path:      absPath,
		LibType:   libType,
		CreatedAt: time.Now().UTC(),
	}

	_, err = database.AppDB.Exec(
		`INSERT INTO media_libraries (id, name, path, lib_type, created_at)
		 VALUES (?, ?, ?, ?, ?)`,
		lib.ID, lib.Name, lib.Path, lib.LibType, lib.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("insert library: %w", err)
	}

	return lib, nil
}

// ListLibraries returns all non-deleted libraries.
func ListLibraries() ([]models.MediaLibrary, error) {
	var libs []models.MediaLibrary
	err := database.AppDB.Select(&libs,
		"SELECT * FROM media_libraries WHERE is_deleted = FALSE ORDER BY created_at ASC")
	if err != nil {
		return nil, err
	}
	return libs, nil
}

// GetLibraryByID fetches a library by ID.
func GetLibraryByID(id string) (*models.MediaLibrary, error) {
	var lib models.MediaLibrary
	err := database.AppDB.Get(&lib, "SELECT * FROM media_libraries WHERE id = ?", id)
	if err != nil {
		return nil, err
	}
	return &lib, nil
}

// RenameLibrary updates a library's name after checking uniqueness.
func RenameLibrary(id, newName string) error {
	var count int
	if err := database.AppDB.Get(&count,
		"SELECT COUNT(*) FROM media_libraries WHERE name = ? AND is_deleted = FALSE AND id != ?",
		newName, id); err != nil {
		return fmt.Errorf("check name: %w", err)
	}
	if count > 0 {
		return fmt.Errorf("名称已存在，请修改后重试")
	}

	_, err := database.AppDB.Exec("UPDATE media_libraries SET name = ? WHERE id = ?", newName, id)
	return err
}

// DeleteLibrary soft-deletes a library, hard-deletes its media_files, and cleans up thumbnails.
func DeleteLibrary(id, thumbnailsDir string) error {
	// Soft-delete the library
	_, err := database.AppDB.Exec(
		"UPDATE media_libraries SET is_deleted = TRUE WHERE id = ?", id)
	if err != nil {
		return fmt.Errorf("soft delete library: %w", err)
	}

	// Hard-delete all media_files for this library
	_, err = database.AppDB.Exec("DELETE FROM media_files WHERE library_id = ?", id)
	if err != nil {
		return fmt.Errorf("delete media files: %w", err)
	}

	// Clean up thumbnail cache directory
	thumbDir := filepath.Join(thumbnailsDir, id)
	_ = os.RemoveAll(thumbDir)

	return nil
}
