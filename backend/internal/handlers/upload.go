package handlers

import (
	"fmt"
	"io"
	"mime"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"

	"github.com/gin-gonic/gin"

	"media-manager/internal/core"
	"media-manager/internal/middleware"
	"media-manager/internal/services"
)

// Upload concurrency control: (userID, libraryID) → *sync.Mutex
var uploadLocks sync.Map

type uploadKey struct {
	UserID    string
	LibraryID string
}

// HandleUpload handles file upload with concurrency control, atomic write, and path traversal protection.
func HandleUpload(c *gin.Context) {
	user := middleware.GetCurrentUser(c)
	if user == nil {
		core.RespondUnauthorized(c, "未认证", core.ErrCodeTokenExpired)
		return
	}

	libraryID := c.Param("id")
	subPath := c.Query("path")

	// Get library
	lib, err := services.GetLibraryByID(libraryID)
	if err != nil || lib.IsDeleted {
		core.RespondNotFound(c, "媒体库不存在")
		return
	}

	// Parse filename from Content-Disposition header
	cdHeader := c.GetHeader("Content-Disposition")
	filename := extractFilename(cdHeader)
	if filename == "" {
		core.RespondBadRequest(c, "缺少文件名，请在 Content-Disposition 头中指定")
		return
	}

	// Validate file extension
	ext := strings.ToLower(filepath.Ext(filename))
	if !isAllowedExt(lib.LibType, ext) {
		core.RespondBadRequest(c, fmt.Sprintf("不支持的文件类型: %s", ext))
		return
	}

	// Build target directory and validate path traversal
	targetDir := lib.Path
	if subPath != "" {
		targetDir = filepath.Join(lib.Path, filepath.FromSlash(subPath))
	}
	// Ensure the resolved path is within the library root
	absTarget, err := filepath.Abs(targetDir)
	if err != nil {
		core.RespondBadRequest(c, "路径无效")
		return
	}
	absLibRoot, _ := filepath.Abs(lib.Path)
	if !strings.HasPrefix(absTarget, absLibRoot) {
		core.RespondBadRequest(c, "路径无效")
		return
	}

	// Concurrency control: TryLock per (user, library)
	key := uploadKey{UserID: user.ID, LibraryID: libraryID}
	lockVal, _ := uploadLocks.LoadOrStore(key, &sync.Mutex{})
	lock := lockVal.(*sync.Mutex)

	if !lock.TryLock() {
		core.RespondConflict(c, "当前有上传任务进行中，请等待完成后再上传")
		return
	}
	defer lock.Unlock()

	// Ensure target directory exists
	if err := os.MkdirAll(absTarget, 0755); err != nil {
		core.RespondInternalError(c)
		return
	}

	// Atomic write: write to .tmp file, then rename
	targetPath := filepath.Join(absTarget, filename)
	tmpPath := targetPath + ".tmp"

	tmpFile, err := os.Create(tmpPath)
	if err != nil {
		core.RespondInternalError(c)
		return
	}

	_, err = io.Copy(tmpFile, c.Request.Body)
	tmpFile.Close()

	if err != nil {
		os.Remove(tmpPath)
		services.WriteLog(fmt.Sprintf("用户 %s 上传 %s 至媒体库 %s 失败：写入中断", services.LogUser(user.Username, user.ID), filename, services.LogLibrary(lib.Name, lib.ID)))
		core.RespondError(c, http.StatusInternalServerError, "上传失败，请重试")
		return
	}

	// Rename temp file to final path
	if err := os.Rename(tmpPath, targetPath); err != nil {
		os.Remove(tmpPath)
		core.RespondInternalError(c)
		return
	}

	// Calculate relative path for indexing
	var relativePath string
	if subPath != "" {
		relativePath = filepath.ToSlash(subPath) + "/" + filename
	} else {
		relativePath = filename
	}

	services.WriteLog(fmt.Sprintf("用户 %s 上传 %s 至媒体库 %s", services.LogUser(user.Username, user.ID), filename, services.LogLibrary(lib.Name, lib.ID)))

	// Enqueue targeted refresh
	if queueManager != nil {
		queueManager.EnqueueTargeted(libraryID, relativePath)
	}

	c.JSON(http.StatusOK, gin.H{"detail": "上传成功", "relative_path": relativePath})
}

// HandleRefresh triggers a full refresh for a library.
func HandleRefresh(c *gin.Context) {
	user := middleware.GetCurrentUser(c)
	if user == nil {
		core.RespondUnauthorized(c, "未认证", core.ErrCodeTokenExpired)
		return
	}

	libraryID := c.Param("id")

	lib, err := services.GetLibraryByID(libraryID)
	if err != nil || lib.IsDeleted {
		core.RespondNotFound(c, "媒体库不存在")
		return
	}

	queued := false
	if queueManager != nil {
		queued = queueManager.EnqueueFull(libraryID)
	}

	if queued {
		services.WriteLog(fmt.Sprintf("用户 %s 触发媒体库 %s 全量刷新", services.LogUser(user.Username, user.ID), services.LogLibrary(lib.Name, lib.ID)))
	}

	c.JSON(http.StatusOK, gin.H{"queued": queued})
}

func extractFilename(contentDisposition string) string {
	if contentDisposition == "" {
		return ""
	}
	_, params, err := mime.ParseMediaType(contentDisposition)
	if err != nil {
		return ""
	}
	return params["filename"]
}

func isAllowedExt(libType, ext string) bool {
	if libType == "camera" {
		return ext == ".mp4" || ext == ".mkv" || ext == ".jpg" || ext == ".png"
	}
	return ext == ".mp4" || ext == ".mkv"
}
