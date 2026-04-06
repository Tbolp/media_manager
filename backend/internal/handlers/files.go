package handlers

import (
	"database/sql"
	"net/http"
	"sort"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"

	"media-manager/internal/core"
	"media-manager/internal/database"
	"media-manager/internal/middleware"
)

type fileItem struct {
	ID           string   `json:"id"`
	Filename     string   `json:"filename"`
	RelativePath string   `json:"relative_path"`
	FileType     string   `json:"file_type"`
	Duration     *float64 `json:"duration"`
	Size         *int64   `json:"size"`
	Progress     *float64 `json:"progress"`
	IsWatched    *bool    `json:"is_watched"`
}

type fileRow struct {
	ID           string          `db:"id"`
	Filename     string          `db:"filename"`
	RelativePath string          `db:"relative_path"`
	FileType     string          `db:"file_type"`
	Duration     sql.NullFloat64 `db:"duration"`
	Size         sql.NullInt64   `db:"size"`
}

// HandleListFiles handles directory browsing and keyword search.
func HandleListFiles(c *gin.Context) {
	user := middleware.GetCurrentUser(c)
	if user == nil {
		core.RespondUnauthorized(c, "未认证", core.ErrCodeTokenExpired)
		return
	}

	libraryID := c.Param("id")
	pathPrefix := c.Query("path")
	keyword := c.Query("q")
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "30"))

	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 200 {
		pageSize = 30
	}

	if keyword != "" {
		handleKeywordSearch(c, libraryID, user.ID, keyword, page, pageSize)
	} else {
		handleDirectoryBrowse(c, libraryID, user.ID, pathPrefix, page, pageSize)
	}
}

func handleDirectoryBrowse(c *gin.Context, libraryID, userID, pathPrefix string, page, pageSize int) {
	// Normalize path prefix
	pathPrefix = strings.TrimSuffix(pathPrefix, "/")

	// Build SQL query for files under this path prefix
	var allFiles []fileRow
	var err error

	if pathPrefix == "" {
		err = database.AppDB.Select(&allFiles,
			"SELECT id, filename, relative_path, file_type, duration, size FROM media_files WHERE library_id = ?",
			libraryID)
	} else {
		likePattern := pathPrefix + "/%"
		err = database.AppDB.Select(&allFiles,
			"SELECT id, filename, relative_path, file_type, duration, size FROM media_files WHERE library_id = ? AND relative_path LIKE ?",
			libraryID, likePattern)
	}
	if err != nil {
		core.RespondInternalError(c)
		return
	}

	// Separate into dirs and direct files
	dirs := make(map[string]bool)
	var directFiles []fileRow

	prefixLen := 0
	if pathPrefix != "" {
		prefixLen = len(pathPrefix) + 1 // +1 for the trailing slash
	}

	for _, f := range allFiles {
		remainder := f.RelativePath
		if prefixLen > 0 {
			if len(f.RelativePath) <= prefixLen {
				continue
			}
			remainder = f.RelativePath[prefixLen:]
		}

		slashIdx := strings.Index(remainder, "/")
		if slashIdx == -1 {
			// Direct file at this level
			directFiles = append(directFiles, f)
		} else {
			// It's in a subdirectory
			dirName := remainder[:slashIdx]
			dirs[dirName] = true
		}
	}

	// Sort dirs
	dirList := make([]string, 0, len(dirs))
	for d := range dirs {
		dirList = append(dirList, d)
	}
	sort.Strings(dirList)

	// Paginate direct files
	total := len(directFiles)
	offset := (page - 1) * pageSize
	end := offset + pageSize
	if offset > total {
		offset = total
	}
	if end > total {
		end = total
	}
	pageFiles := directFiles[offset:end]

	// Build file items with progress
	items := buildFileItems(pageFiles, userID)

	c.JSON(http.StatusOK, gin.H{
		"path":      pathPrefix,
		"dirs":      dirList,
		"total":     total,
		"page":      page,
		"page_size": pageSize,
		"items":     items,
	})
}

func handleKeywordSearch(c *gin.Context, libraryID, userID, keyword string, page, pageSize int) {
	likeKeyword := "%" + keyword + "%"

	// Get total count
	var total int
	err := database.AppDB.Get(&total,
		"SELECT COUNT(*) FROM media_files WHERE library_id = ? AND filename LIKE ?",
		libraryID, likeKeyword)
	if err != nil {
		core.RespondInternalError(c)
		return
	}

	// Get paginated results
	offset := (page - 1) * pageSize
	var files []fileRow
	err = database.AppDB.Select(&files,
		"SELECT id, filename, relative_path, file_type, duration, size FROM media_files WHERE library_id = ? AND filename LIKE ? ORDER BY relative_path LIMIT ? OFFSET ?",
		libraryID, likeKeyword, pageSize, offset)
	if err != nil {
		core.RespondInternalError(c)
		return
	}

	items := buildFileItems(files, userID)

	c.JSON(http.StatusOK, gin.H{
		"total":     total,
		"page":      page,
		"page_size": pageSize,
		"items":     items,
	})
}

func buildFileItems(files []fileRow, userID string) []fileItem {
	if len(files) == 0 {
		return []fileItem{}
	}

	// Collect file IDs for batch progress query
	fileIDs := make([]string, len(files))
	for i, f := range files {
		fileIDs[i] = f.ID
	}

	// Query progress for all files at once
	type progressRow struct {
		FileID    string  `db:"file_id"`
		Position  float64 `db:"position"`
		Duration  float64 `db:"duration"`
		IsWatched bool    `db:"is_watched"`
	}

	progressMap := make(map[string]*progressRow)

	// Build query with IN clause
	query, args, err := buildInQuery(
		"SELECT file_id, position, duration, is_watched FROM playback_progress WHERE user_id = ? AND file_id IN (",
		userID, fileIDs)
	if err == nil {
		var progresses []progressRow
		if err := database.AppDB.Select(&progresses, query, args...); err == nil {
			for i := range progresses {
				progressMap[progresses[i].FileID] = &progresses[i]
			}
		}
	}

	items := make([]fileItem, 0, len(files))
	for _, f := range files {
		item := fileItem{
			ID:           f.ID,
			Filename:     f.Filename,
			RelativePath: f.RelativePath,
			FileType:     f.FileType,
		}

		if f.Duration.Valid {
			d := f.Duration.Float64
			item.Duration = &d
		}
		if f.Size.Valid {
			s := f.Size.Int64
			item.Size = &s
		}

		// Add progress info for video files
		if f.FileType == "video" {
			if p, ok := progressMap[f.ID]; ok {
				var progress float64
				if p.Duration > 0 {
					progress = p.Position / p.Duration
				}
				item.Progress = &progress
				item.IsWatched = &p.IsWatched
			} else {
				zero := 0.0
				falseBool := false
				item.Progress = &zero
				item.IsWatched = &falseBool
			}
		}

		items = append(items, item)
	}

	return items
}

// buildInQuery constructs a query with an IN clause for multiple values.
func buildInQuery(prefix string, userID string, ids []string) (string, []any, error) {
	if len(ids) == 0 {
		return "", nil, nil
	}

	placeholders := make([]string, len(ids))
	args := make([]any, 0, len(ids)+1)
	args = append(args, userID)

	for i, id := range ids {
		placeholders[i] = "?"
		args = append(args, id)
	}

	query := prefix + strings.Join(placeholders, ",") + ")"
	return query, args, nil
}
