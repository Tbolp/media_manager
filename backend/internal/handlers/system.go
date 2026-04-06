package handlers

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"media-manager/internal/core"
	"media-manager/internal/database"
	"media-manager/internal/services"
)

// HandleDashboard returns system dashboard data.
func HandleDashboard(c *gin.Context) {
	// Media total count
	var mediaTotal int
	if err := database.AppDB.Get(&mediaTotal, "SELECT COUNT(*) FROM media_files"); err != nil {
		core.RespondInternalError(c)
		return
	}

	// User activity: list non-deleted users with their last_active_at
	type userActivity struct {
		ID           string  `db:"id" json:"id"`
		Username     string  `db:"username" json:"username"`
		Role         string  `db:"role" json:"role"`
		LastActiveAt *string `db:"last_active_at" json:"last_active_at"`
	}

	var users []userActivity
	if err := database.AppDB.Select(&users,
		"SELECT id, username, role, last_active_at FROM users WHERE is_deleted = FALSE ORDER BY last_active_at DESC"); err != nil {
		core.RespondInternalError(c)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"media_total": mediaTotal,
		"users":       users,
	})
}

// HandleTasks returns the task center data from queue manager.
func HandleTasks(c *gin.Context) {
	if queueManager == nil {
		c.JSON(http.StatusOK, gin.H{"libraries": []any{}})
		return
	}

	libs, err := services.ListLibraries()
	if err != nil {
		core.RespondInternalError(c)
		return
	}

	type libraryTasks struct {
		ID            string `json:"id"`
		Name          string `json:"name"`
		CurrentTask   any    `json:"current_task"`
		PendingCount  int    `json:"pending_count"`
		RecentTasks   any    `json:"recent_tasks"`
	}

	items := make([]libraryTasks, 0, len(libs))
	for _, lib := range libs {
		current, recent, pending := queueManager.GetStatus(lib.ID)

		item := libraryTasks{
			ID:           lib.ID,
			Name:         lib.Name,
			CurrentTask:  current,
			PendingCount: pending,
			RecentTasks:  recent,
		}
		items = append(items, item)
	}

	c.JSON(http.StatusOK, gin.H{"libraries": items})
}

// HandleLogs returns paginated log entries with optional keyword filter.
func HandleLogs(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "30"))
	keyword := c.Query("q")

	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 200 {
		pageSize = 30
	}

	offset := (page - 1) * pageSize

	var total int
	var items []struct {
		ID        string `db:"id" json:"id"`
		CreatedAt string `db:"created_at" json:"created_at"`
		Message   string `db:"message" json:"message"`
	}

	if keyword != "" {
		likeKeyword := "%" + keyword + "%"
		if err := database.LogsDB.Get(&total,
			"SELECT COUNT(*) FROM logs WHERE message LIKE ?", likeKeyword); err != nil {
			core.RespondInternalError(c)
			return
		}
		if err := database.LogsDB.Select(&items,
			"SELECT id, created_at, message FROM logs WHERE message LIKE ? ORDER BY created_at DESC LIMIT ? OFFSET ?",
			likeKeyword, pageSize, offset); err != nil {
			core.RespondInternalError(c)
			return
		}
	} else {
		if err := database.LogsDB.Get(&total, "SELECT COUNT(*) FROM logs"); err != nil {
			core.RespondInternalError(c)
			return
		}
		if err := database.LogsDB.Select(&items,
			"SELECT id, created_at, message FROM logs ORDER BY created_at DESC LIMIT ? OFFSET ?",
			pageSize, offset); err != nil {
			core.RespondInternalError(c)
			return
		}
	}

	if items == nil {
		items = make([]struct {
			ID        string `db:"id" json:"id"`
			CreatedAt string `db:"created_at" json:"created_at"`
			Message   string `db:"message" json:"message"`
		}, 0)
	}

	c.JSON(http.StatusOK, gin.H{
		"total":     total,
		"page":      page,
		"page_size": pageSize,
		"items":     items,
	})
}
