package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"

	"media-manager/internal/config"
	"media-manager/internal/core"
	"media-manager/internal/middleware"
	"media-manager/internal/queue"
	"media-manager/internal/services"
)

var queueManager *queue.QueueManager

// SetQueueManager sets the global queue manager reference for handlers.
func SetQueueManager(qm *queue.QueueManager) {
	queueManager = qm
}

type createLibraryRequest struct {
	Name    string `json:"name" binding:"required"`
	Path    string `json:"path" binding:"required"`
	LibType string `json:"lib_type" binding:"required"`
}

type renameLibraryRequest struct {
	Name string `json:"name" binding:"required"`
}

// HandleListLibraries returns libraries visible to the current user, with refresh status.
func HandleListLibraries(c *gin.Context) {
	user := middleware.GetCurrentUser(c)
	if user == nil {
		core.RespondUnauthorized(c, "未认证", core.ErrCodeTokenExpired)
		return
	}

	libs, err := services.ListLibraries()
	if err != nil {
		core.RespondInternalError(c)
		return
	}

	// Parse user's whitelist
	var allowedIDs []string
	if user.Role != "admin" {
		_ = json.Unmarshal([]byte(user.LibraryIDs), &allowedIDs)
	}

	type libraryItem struct {
		ID            string `json:"id"`
		Name          string `json:"name"`
		LibType       string `json:"lib_type"`
		RefreshStatus string `json:"refresh_status"`
	}

	items := make([]libraryItem, 0)
	for _, lib := range libs {
		// Filter by whitelist for non-admin
		if user.Role != "admin" {
			found := false
			for _, id := range allowedIDs {
				if id == lib.ID {
					found = true
					break
				}
			}
			if !found {
				continue
			}
		}

		refreshStatus := "idle"
		if queueManager != nil {
			refreshStatus = queueManager.GetRefreshStatus(lib.ID)
		}

		items = append(items, libraryItem{
			ID:            lib.ID,
			Name:          lib.Name,
			LibType:       lib.LibType,
			RefreshStatus: refreshStatus,
		})
	}

	c.JSON(http.StatusOK, gin.H{"items": items})
}

// HandleCreateLibrary creates a new media library (admin only).
func HandleCreateLibrary(c *gin.Context) {
	admin := middleware.GetCurrentUser(c)

	var req createLibraryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		core.RespondBadRequest(c, "请求参数错误")
		return
	}

	lib, err := services.CreateLibrary(req.Name, req.Path, req.LibType)
	if err != nil {
		core.RespondBadRequest(c, err.Error())
		return
	}

	services.WriteLog(fmt.Sprintf("管理员 %s 创建媒体库 %s", admin.Username, lib.Name))

	// Start queue and enqueue initial full refresh
	if queueManager != nil {
		queueManager.StartQueue(lib.ID)
		queueManager.EnqueueFull(lib.ID)
	}

	c.JSON(http.StatusCreated, gin.H{"id": lib.ID, "name": lib.Name})
}

// HandleRenameLibrary renames a media library (admin only).
func HandleRenameLibrary(c *gin.Context) {
	admin := middleware.GetCurrentUser(c)
	libID := c.Param("id")

	var req renameLibraryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		core.RespondBadRequest(c, "请求参数错误")
		return
	}

	lib, err := services.GetLibraryByID(libID)
	if err != nil || lib.IsDeleted {
		core.RespondNotFound(c, "媒体库不存在")
		return
	}

	oldName := lib.Name
	if err := services.RenameLibrary(libID, req.Name); err != nil {
		core.RespondBadRequest(c, err.Error())
		return
	}

	services.WriteLog(fmt.Sprintf("管理员 %s 将媒体库 %s 改名为 %s", admin.Username, oldName, req.Name))

	c.JSON(http.StatusOK, gin.H{"detail": "已改名"})
}

// HandleDeleteLibrary deletes a media library (admin only).
func HandleDeleteLibrary(c *gin.Context) {
	admin := middleware.GetCurrentUser(c)
	libID := c.Param("id")

	lib, err := services.GetLibraryByID(libID)
	if err != nil || lib.IsDeleted {
		core.RespondNotFound(c, "媒体库不存在")
		return
	}

	// Cancel queue
	if queueManager != nil {
		queueManager.StopQueue(libID)
	}

	if err := services.DeleteLibrary(libID, config.C.ThumbnailsDir); err != nil {
		core.RespondInternalError(c)
		return
	}

	services.WriteLog(fmt.Sprintf("管理员 %s 删除媒体库 %s", admin.Username, lib.Name))

	c.JSON(http.StatusOK, gin.H{"detail": "已删除"})
}
