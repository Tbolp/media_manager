package middleware

import (
	"encoding/json"

	"github.com/gin-gonic/gin"

	"media-manager/internal/core"
	"media-manager/internal/database"
)

// RequireLibraryAccess checks that the current user has access to the specified library.
// For routes with :id param (library_id), it reads from the URL path.
// For routes with :fid param (file_id), it looks up the library_id from media_files.
// Admin users bypass the whitelist check.
func RequireLibraryAccess() gin.HandlerFunc {
	return func(c *gin.Context) {
		user := GetCurrentUser(c)
		if user == nil {
			core.RespondUnauthorized(c, "未认证", core.ErrCodeTokenExpired)
			c.Abort()
			return
		}

		// Determine library_id from path params
		libraryID := c.Param("id")
		if libraryID == "" {
			// Try file-based route: look up library_id from file_id
			fileID := c.Param("fid")
			if fileID == "" {
				core.RespondBadRequest(c, "缺少资源标识")
				c.Abort()
				return
			}
			var libID string
			err := database.AppDB.Get(&libID,
				"SELECT library_id FROM media_files WHERE id = ?", fileID)
			if err != nil {
				core.RespondNotFound(c, "文件不存在")
				c.Abort()
				return
			}
			libraryID = libID
		}

		// Check library exists and is not deleted
		var isDeleted bool
		err := database.AppDB.Get(&isDeleted,
			"SELECT is_deleted FROM media_libraries WHERE id = ?", libraryID)
		if err != nil {
			core.RespondNotFound(c, "媒体库不存在")
			c.Abort()
			return
		}
		if isDeleted {
			core.RespondNotFound(c, "媒体库不存在")
			c.Abort()
			return
		}

		// Admin bypasses whitelist check (but still validated library exists above)
		if user.Role == "admin" {
			c.Next()
			return
		}

		// Parse user's library_ids JSON array
		var allowedIDs []string
		if err := json.Unmarshal([]byte(user.LibraryIDs), &allowedIDs); err != nil {
			core.RespondForbidden(c, "您无权访问此媒体库")
			c.Abort()
			return
		}

		// Check if libraryID is in the whitelist
		for _, id := range allowedIDs {
			if id == libraryID {
				c.Next()
				return
			}
		}

		core.RespondForbidden(c, "您无权访问此媒体库")
		c.Abort()
	}
}
