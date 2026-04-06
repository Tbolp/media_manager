package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"media-manager/internal/core"
)

// RequireAdmin ensures the authenticated user has the admin role.
func RequireAdmin() gin.HandlerFunc {
	return func(c *gin.Context) {
		user := GetCurrentUser(c)
		if user == nil {
			core.RespondError(c, http.StatusUnauthorized, "未认证")
			c.Abort()
			return
		}
		if user.Role != "admin" {
			core.RespondForbidden(c, "无权访问")
			c.Abort()
			return
		}
		c.Next()
	}
}
