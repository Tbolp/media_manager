package handlers

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"media-manager/internal/core"
	"media-manager/internal/middleware"
	"media-manager/internal/services"
)

type progressRequest struct {
	Position float64 `json:"position" binding:"required"`
	Duration float64 `json:"duration" binding:"required"`
}

// HandleReportProgress handles playback progress reporting.
func HandleReportProgress(c *gin.Context) {
	user := middleware.GetCurrentUser(c)
	if user == nil {
		core.RespondUnauthorized(c, "未认证", core.ErrCodeTokenExpired)
		return
	}

	fileID := c.Param("fid")

	var req progressRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		core.RespondBadRequest(c, "请求参数错误")
		return
	}

	// Upsert progress
	if err := services.UpsertProgress(user.ID, fileID, req.Position, req.Duration); err != nil {
		core.RespondInternalError(c)
		return
	}

	// Upsert watch history
	_ = services.UpsertWatchHistory(user.ID, fileID)

	c.JSON(http.StatusOK, gin.H{"detail": "已记录"})
}

// HandleGetHistory returns the user's watch history.
func HandleGetHistory(c *gin.Context) {
	user := middleware.GetCurrentUser(c)
	if user == nil {
		core.RespondUnauthorized(c, "未认证", core.ErrCodeTokenExpired)
		return
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "30"))
	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 200 {
		pageSize = 30
	}

	historyItems, total, err := services.GetWatchHistory(user.ID, page, pageSize)
	if err != nil {
		core.RespondInternalError(c)
		return
	}

	type historyResponse struct {
		FileID       string  `json:"file_id"`
		Filename     *string `json:"filename"`
		RelativePath *string `json:"relative_path"`
		LibraryID    *string `json:"library_id"`
		WatchedAt    string  `json:"watched_at"`
	}

	items := make([]historyResponse, 0, len(historyItems))
	for _, h := range historyItems {
		item := historyResponse{
			FileID:    h.FileID,
			WatchedAt: h.WatchedAt.Format("2006-01-02T15:04:05Z"),
		}
		if h.Filename.Valid {
			item.Filename = &h.Filename.String
		}
		if h.RelativePath.Valid {
			item.RelativePath = &h.RelativePath.String
		}
		if h.LibraryID.Valid {
			item.LibraryID = &h.LibraryID.String
		}
		items = append(items, item)
	}

	c.JSON(http.StatusOK, gin.H{
		"total":     total,
		"page":      page,
		"page_size": pageSize,
		"items":     items,
	})
}
