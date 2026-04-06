package services

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
	"time"

	"github.com/disintegration/imaging"

	"media-manager/internal/database"
	"media-manager/internal/models"
)

// thumbnailLocks prevents concurrent generation for the same file.
var thumbnailLocks sync.Map

// GetMediaFile fetches a media file by ID with its library info.
func GetMediaFile(fileID string) (*models.MediaFile, *models.MediaLibrary, error) {
	var file models.MediaFile
	err := database.AppDB.Get(&file, "SELECT * FROM media_files WHERE id = ?", fileID)
	if err != nil {
		return nil, nil, fmt.Errorf("file not found")
	}

	var lib models.MediaLibrary
	err = database.AppDB.Get(&lib, "SELECT * FROM media_libraries WHERE id = ?", file.LibraryID)
	if err != nil {
		return nil, nil, fmt.Errorf("library not found")
	}

	return &file, &lib, nil
}

// GetAbsolutePath returns the absolute path of a media file.
func GetAbsolutePath(lib *models.MediaLibrary, file *models.MediaFile) string {
	return filepath.Join(lib.Path, filepath.FromSlash(file.RelativePath))
}

// GetOrCreateThumbnail returns the path to a thumbnail, generating it if needed.
// Supports both image and video files. Uses per-file locking to prevent concurrent generation.
func GetOrCreateThumbnail(file *models.MediaFile, lib *models.MediaLibrary, thumbnailsDir string) (string, error) {
	thumbPath := filepath.Join(thumbnailsDir, lib.ID, file.ID+".jpg")

	// Check if thumbnail already exists
	if _, err := os.Stat(thumbPath); err == nil {
		return thumbPath, nil
	}

	// Per-file lock
	type lockEntry struct {
		done chan struct{}
		err  error
		once sync.Once
	}

	entryVal, loaded := thumbnailLocks.LoadOrStore(file.ID, &lockEntry{done: make(chan struct{})})
	entry := entryVal.(*lockEntry)

	if loaded {
		<-entry.done
		if entry.err != nil {
			return "", entry.err
		}
		return thumbPath, nil
	}

	defer func() {
		close(entry.done)
		thumbnailLocks.Delete(file.ID)
	}()

	// Ensure thumbnail directory exists
	thumbDir := filepath.Dir(thumbPath)
	if err := os.MkdirAll(thumbDir, 0755); err != nil {
		entry.err = fmt.Errorf("create thumb dir: %w", err)
		return "", entry.err
	}

	srcPath := GetAbsolutePath(lib, file)

	if file.FileType == "video" {
		entry.err = generateVideoThumbnail(srcPath, thumbPath)
		if entry.err != nil {
			return "", entry.err
		}
		return thumbPath, nil
	}

	// Image thumbnail
	entry.err = generateImageThumbnail(srcPath, thumbPath)
	if entry.err != nil {
		return "", entry.err
	}
	return thumbPath, nil
}

// generateVideoThumbnail uses ffmpeg to capture a frame at 1 second.
func generateVideoThumbnail(videoPath, thumbPath string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "ffmpeg",
		"-ss", "1",           // seek to 1 second
		"-i", videoPath,
		"-vframes", "1",      // capture 1 frame
		"-vf", "scale=400:-1", // 400px width, auto height
		"-q:v", "3",          // quality (2-5, lower is better)
		"-y",                 // overwrite
		thumbPath,
	)
	if err := cmd.Run(); err != nil {
		// Fallback: try at 0 second (very short videos)
		cmd2 := exec.CommandContext(ctx, "ffmpeg",
			"-ss", "0",
			"-i", videoPath,
			"-vframes", "1",
			"-vf", "scale=400:-1",
			"-q:v", "3",
			"-y",
			thumbPath,
		)
		if err2 := cmd2.Run(); err2 != nil {
			return fmt.Errorf("ffmpeg thumbnail: %w", err2)
		}
	}
	return nil
}

// generateImageThumbnail resizes an image to 400px width.
func generateImageThumbnail(srcPath, thumbPath string) error {
	src, err := imaging.Open(srcPath)
	if err != nil {
		return fmt.Errorf("open image: %w", err)
	}

	bounds := src.Bounds()
	if bounds.Dx() <= 400 {
		// Small enough — copy original as thumbnail
		data, err := os.ReadFile(srcPath)
		if err != nil {
			return err
		}
		return os.WriteFile(thumbPath, data, 0644)
	}

	thumb := imaging.Resize(src, 400, 0, imaging.Lanczos)
	if err := imaging.Save(thumb, thumbPath); err != nil {
		return fmt.Errorf("save thumbnail: %w", err)
	}
	return nil
}
