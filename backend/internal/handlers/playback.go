package handlers

import (
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"

	"media-manager/internal/config"
	"media-manager/internal/core"
	"media-manager/internal/services"
)

// HandleStream serves a video file with HTTP Range support.
func HandleStream(c *gin.Context) {
	fileID := c.Param("fid")

	file, lib, err := services.GetMediaFile(fileID)
	if err != nil {
		core.RespondNotFound(c, "文件不存在或已移除")
		return
	}

	if file.FileType != "video" {
		core.RespondBadRequest(c, "此接口仅支持视频文件")
		return
	}

	absPath := services.GetAbsolutePath(lib, file)
	f, err := os.Open(absPath)
	if err != nil {
		core.RespondNotFound(c, "文件不存在或已移除")
		return
	}
	defer f.Close()

	stat, err := f.Stat()
	if err != nil {
		core.RespondInternalError(c)
		return
	}

	// Use http.ServeContent which handles Range requests automatically
	http.ServeContent(c.Writer, c.Request, file.Filename, stat.ModTime(), f)
}

// HandleRawImage serves an original image file.
func HandleRawImage(c *gin.Context) {
	fileID := c.Param("fid")

	file, lib, err := services.GetMediaFile(fileID)
	if err != nil {
		core.RespondNotFound(c, "文件不存在或已移除")
		return
	}

	if file.FileType != "image" {
		core.RespondBadRequest(c, "此接口仅支持图片文件")
		return
	}

	absPath := services.GetAbsolutePath(lib, file)
	c.File(absPath)
}

// HandleThumbnail serves a thumbnail (generated on demand and cached).
func HandleThumbnail(c *gin.Context) {
	fileID := c.Param("fid")

	file, lib, err := services.GetMediaFile(fileID)
	if err != nil {
		core.RespondNotFound(c, "文件不存在或已移除")
		return
	}

	if file.FileType != "image" {
		core.RespondBadRequest(c, "此接口仅支持图片文件")
		return
	}

	thumbPath, err := services.GetOrCreateThumbnail(file, lib, config.C.ThumbnailsDir)
	if err != nil {
		core.RespondInternalError(c)
		return
	}

	// Serve with cache headers
	c.Header("Cache-Control", "public, max-age=86400")
	http.ServeFile(c.Writer, c.Request, thumbPath)
}

// unused but needed to avoid import cycle — provides a modtime for ServeContent
var _ = time.Now
