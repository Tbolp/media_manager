package handlers

import (
	"database/sql"
	"net/http"
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

	// --- 1. Query distinct direct sub-directory names ---
	var dirRows []struct {
		DirName string `db:"dir_name"`
	}

	if pathPrefix == "" {
		// Root level: extract first segment from parent_dir of all files that have a parent_dir
		database.AppDB.Select(&dirRows,
			`SELECT DISTINCT
				CASE WHEN INSTR(parent_dir, '/') = 0
					THEN parent_dir
					ELSE SUBSTR(parent_dir, 1, INSTR(parent_dir, '/') - 1)
				END AS dir_name
			FROM media_files
			WHERE library_id = ? AND parent_dir != ''
			ORDER BY dir_name`,
			libraryID)
	} else {
		// Sub-directory: find dirs whose parent_dir starts with pathPrefix/
		// and extract the next segment after pathPrefix/
		likePattern := pathPrefix + "/%"
		startPos := len(pathPrefix) + 2 // 1-indexed, position after "prefix/"
		database.AppDB.Select(&dirRows,
			`SELECT DISTINCT
				CASE WHEN INSTR(SUBSTR(parent_dir, ?), '/') = 0
					THEN SUBSTR(parent_dir, ?)
					ELSE SUBSTR(parent_dir, ?, INSTR(SUBSTR(parent_dir, ?), '/') - 1)
				END AS dir_name
			FROM media_files
			WHERE library_id = ? AND parent_dir LIKE ?
			ORDER BY dir_name`,
			startPos, startPos, startPos, startPos, libraryID, likePattern)
	}

	dirList := make([]string, 0, len(dirRows))
	for _, d := range dirRows {
		if d.DirName != "" {
			dirList = append(dirList, d.DirName)
		}
	}

	// --- 2. Count total direct files ---
	var total int
	if err := database.AppDB.Get(&total,
		"SELECT COUNT(*) FROM media_files WHERE library_id = ? AND parent_dir = ?",
		libraryID, pathPrefix); err != nil {
		core.RespondInternalError(c)
		return
	}

	// --- 3. Query paginated direct files ---
	offset := (page - 1) * pageSize
	var files []fileRow
	if err := database.AppDB.Select(&files,
		`SELECT id, filename, relative_path, file_type, duration, size
		FROM media_files WHERE library_id = ? AND parent_dir = ?
		ORDER BY filename LIMIT ? OFFSET ?`,
		libraryID, pathPrefix, pageSize, offset); err != nil {
		core.RespondInternalError(c)
		return
	}

	// Build file items with progress
	items := buildFileItems(files, userID)

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
