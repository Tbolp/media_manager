package services

import (
	"fmt"
	"os"
	"path/filepath"
	"sync"

	"github.com/disintegration/imaging"

	"media-manager/internal/database"
	"media-manager/internal/models"
)

// thumbnailLocks prevents concurrent generation for the same file.
var thumbnailLocks sync.Map // key: file_id → *sync.Once (one-shot), or use chan approach

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
// Uses per-file locking to prevent concurrent generation.
func GetOrCreateThumbnail(file *models.MediaFile, lib *models.MediaLibrary, thumbnailsDir string) (string, error) {
	thumbPath := filepath.Join(thumbnailsDir, lib.ID, file.ID+".jpg")

	// Check if thumbnail already exists
	if _, err := os.Stat(thumbPath); err == nil {
		return thumbPath, nil
	}

	// Per-file lock using sync.Map with a channel as a lock
	type lockEntry struct {
		done chan struct{}
		err  error
		once sync.Once
	}

	entryVal, loaded := thumbnailLocks.LoadOrStore(file.ID, &lockEntry{done: make(chan struct{})})
	entry := entryVal.(*lockEntry)

	if loaded {
		// Another goroutine is generating this thumbnail — wait for it
		<-entry.done
		if entry.err != nil {
			return "", entry.err
		}
		return thumbPath, nil
	}

	// We are the first — generate the thumbnail
	defer func() {
		close(entry.done)
		thumbnailLocks.Delete(file.ID)
	}()

	srcPath := GetAbsolutePath(lib, file)

	// Open source image
	src, err := imaging.Open(srcPath)
	if err != nil {
		entry.err = fmt.Errorf("open image: %w", err)
		return "", entry.err
	}

	// Check if resize is needed
	bounds := src.Bounds()
	if bounds.Dx() <= 400 {
		// Original is small enough — return original path directly
		return srcPath, nil
	}

	// Resize to 400px width, maintaining aspect ratio
	thumb := imaging.Resize(src, 400, 0, imaging.Lanczos)

	// Ensure thumbnail directory exists
	thumbDir := filepath.Dir(thumbPath)
	if err := os.MkdirAll(thumbDir, 0755); err != nil {
		entry.err = fmt.Errorf("create thumb dir: %w", err)
		return "", entry.err
	}

	// Save thumbnail
	if err := imaging.Save(thumb, thumbPath); err != nil {
		entry.err = fmt.Errorf("save thumbnail: %w", err)
		return "", entry.err
	}

	return thumbPath, nil
}
