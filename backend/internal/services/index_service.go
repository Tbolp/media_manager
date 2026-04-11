package services

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"

	"media-manager/internal/database"
	"media-manager/internal/models"
	"media-manager/internal/queue"
)

// RunRefresh executes a refresh task for a library.
func RunRefresh(ctx context.Context, libraryID string, task queue.RefreshTask) error {
	lib, err := GetLibraryByID(libraryID)
	if err != nil {
		return fmt.Errorf("get library: %w", err)
	}

	if task.TaskType == "full" {
		return runFullRefresh(ctx, lib)
	}
	return runTargetedRefresh(ctx, lib, task.TargetFile)
}

func runFullRefresh(ctx context.Context, lib *models.MediaLibrary) error {
	// Step 1: Scan disk and collect all valid files
	diskFiles := make(map[string]bool) // relative_path → exists
	extensions := allowedExtensions(lib.LibType)

	err := filepath.WalkDir(lib.Path, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return nil // skip unreadable entries
		}
		if ctx.Err() != nil {
			return ctx.Err()
		}
		if d.IsDir() {
			return nil
		}

		ext := strings.ToLower(filepath.Ext(d.Name()))
		if !extensions[ext] {
			return nil
		}

		relPath, err := filepath.Rel(lib.Path, path)
		if err != nil {
			return nil
		}
		// Normalize to forward slashes
		relPath = filepath.ToSlash(relPath)
		diskFiles[relPath] = true
		return nil
	})
	if err != nil {
		return fmt.Errorf("scan directory: %w", err)
	}

	// Step 2: Upsert files into index
	for relPath := range diskFiles {
		if ctx.Err() != nil {
			return ctx.Err()
		}
		if err := upsertFile(ctx, lib, relPath); err != nil {
			// Log but continue
			fmt.Printf("WARNING: failed to index %s: %v\n", relPath, err)
		}
	}

	// Step 3: Delete files no longer on disk
	var existingFiles []models.MediaFile
	if err := database.AppDB.Select(&existingFiles,
		"SELECT id, relative_path FROM media_files WHERE library_id = ?", lib.ID); err != nil {
		return fmt.Errorf("query existing files: %w", err)
	}

	for _, f := range existingFiles {
		if !diskFiles[f.RelativePath] {
			_, _ = database.AppDB.Exec("DELETE FROM media_files WHERE id = ?", f.ID)
		}
	}

	return nil
}

func runTargetedRefresh(ctx context.Context, lib *models.MediaLibrary, relativePath string) error {
	return upsertFile(ctx, lib, relativePath)
}

func upsertFile(ctx context.Context, lib *models.MediaLibrary, relativePath string) error {
	absPath := filepath.Join(lib.Path, filepath.FromSlash(relativePath))
	filename := filepath.Base(relativePath)
	ext := strings.ToLower(filepath.Ext(filename))

	// Compute parent directory: "a/b/c.mp4" → "a/b", "c.mp4" → ""
	parentDir := filepath.Dir(filepath.ToSlash(relativePath))
	if parentDir == "." {
		parentDir = ""
	}

	// Determine file type
	fileType := "video"
	if ext == ".jpg" || ext == ".png" {
		fileType = "image"
	}

	// Get file size
	info, err := os.Stat(absPath)
	if err != nil {
		return fmt.Errorf("stat file %s: %w", relativePath, err)
	}
	size := info.Size()

	// Get video duration if applicable
	var duration *float64
	if fileType == "video" {
		d, err := GetVideoDuration(ctx, absPath)
		if err != nil {
			// Log but continue with nil duration
			fmt.Printf("WARNING: failed to get duration for %s: %v\n", relativePath, err)
		} else {
			duration = &d
		}
	}

	// Check if file already exists
	var existingID string
	err = database.AppDB.Get(&existingID,
		"SELECT id FROM media_files WHERE library_id = ? AND relative_path = ?",
		lib.ID, relativePath)

	now := time.Now().UTC()

	if err == nil {
		// Update existing record
		if duration != nil {
			_, err = database.AppDB.Exec(
				`UPDATE media_files SET filename = ?, parent_dir = ?, file_type = ?, duration = ?, size = ?, indexed_at = ?
				 WHERE id = ?`,
				filename, parentDir, fileType, *duration, size, now, existingID)
		} else {
			_, err = database.AppDB.Exec(
				`UPDATE media_files SET filename = ?, parent_dir = ?, file_type = ?, size = ?, indexed_at = ?
				 WHERE id = ?`,
				filename, parentDir, fileType, size, now, existingID)
		}
	} else {
		// Insert new record
		id := uuid.New().String()
		if duration != nil {
			_, err = database.AppDB.Exec(
				`INSERT INTO media_files (id, library_id, filename, relative_path, parent_dir, file_type, duration, size, indexed_at)
				 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
				id, lib.ID, filename, relativePath, parentDir, fileType, *duration, size, now)
		} else {
			_, err = database.AppDB.Exec(
				`INSERT INTO media_files (id, library_id, filename, relative_path, parent_dir, file_type, size, indexed_at)
				 VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
				id, lib.ID, filename, relativePath, parentDir, fileType, size, now)
		}
	}

	return err
}

func allowedExtensions(libType string) map[string]bool {
	if libType == "camera" {
		return map[string]bool{".mp4": true, ".mkv": true, ".jpg": true, ".png": true}
	}
	return map[string]bool{".mp4": true, ".mkv": true}
}

// GetVideoDuration calls ffprobe to read the duration of a video file.
func GetVideoDuration(ctx context.Context, filePath string) (float64, error) {
	cmd := exec.CommandContext(ctx, "ffprobe",
		"-v", "quiet", "-print_format", "json", "-show_format", filePath)
	out, err := cmd.Output()
	if err != nil {
		return 0, fmt.Errorf("ffprobe: %w", err)
	}

	var result struct {
		Format struct {
			Duration string `json:"duration"`
		} `json:"format"`
	}
	if err := json.Unmarshal(out, &result); err != nil {
		return 0, fmt.Errorf("parse ffprobe output: %w", err)
	}

	return strconv.ParseFloat(result.Format.Duration, 64)
}
