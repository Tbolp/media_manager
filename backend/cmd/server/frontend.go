package main

import (
	"embed"
	"io/fs"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

//go:embed dist/*
var frontendFS embed.FS

// setupFrontend serves the embedded frontend static files.
// All non-API routes fall back to index.html for SPA routing.
func setupFrontend(r *gin.Engine) {
	// Strip the "dist" prefix so files are served from root
	stripped, err := fs.Sub(frontendFS, "dist")
	if err != nil {
		panic("failed to get frontend sub filesystem: " + err.Error())
	}
	fileServer := http.FileServer(http.FS(stripped))

	r.NoRoute(func(c *gin.Context) {
		path := c.Request.URL.Path

		// Don't serve frontend for API routes
		if strings.HasPrefix(path, "/api") {
			c.JSON(http.StatusNotFound, gin.H{"detail": "接口不存在"})
			return
		}

		// Try to serve the exact file (js, css, images, etc.)
		// Check if the file exists in the embedded FS
		filePath := strings.TrimPrefix(path, "/")
		if filePath == "" {
			filePath = "index.html"
		}

		if f, err := stripped.Open(filePath); err == nil {
			f.Close()
			fileServer.ServeHTTP(c.Writer, c.Request)
			return
		}

		// SPA fallback: serve index.html for all other routes
		c.Request.URL.Path = "/"
		fileServer.ServeHTTP(c.Writer, c.Request)
	})
}
