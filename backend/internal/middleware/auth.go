package middleware

import (
	"strings"
	"time"

	"github.com/gin-gonic/gin"

	"media-manager/internal/config"
	"media-manager/internal/core"
	"media-manager/internal/database"
	"media-manager/internal/models"
)

const UserContextKey = "user"

// GetCurrentUser extracts the authenticated user from gin.Context.
func GetCurrentUser(c *gin.Context) *models.User {
	u, exists := c.Get(UserContextKey)
	if !exists {
		return nil
	}
	user, ok := u.(*models.User)
	if !ok {
		return nil
	}
	return user
}

// AuthMiddleware parses the JWT from the Authorization header, validates the
// token version against the database, and injects the User into the context.
func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Extract token from "Authorization: Bearer <token>"
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
			core.RespondUnauthorized(c, "缺少认证令牌", core.ErrCodeTokenExpired)
			c.Abort()
			return
		}
		tokenString := strings.TrimPrefix(authHeader, "Bearer ")

		// Parse JWT
		claims, err := core.ParseToken(tokenString, config.C.JWTSecret)
		if err != nil {
			core.RespondUnauthorized(c, "登录已过期，请重新登录", core.ErrCodeTokenExpired)
			c.Abort()
			return
		}

		// Extract sub and ver
		userID, _ := claims["sub"].(string)
		verFloat, _ := claims["ver"].(float64)
		ver := int(verFloat)

		if userID == "" {
			core.RespondUnauthorized(c, "无效的认证令牌", core.ErrCodeTokenExpired)
			c.Abort()
			return
		}

		// Fetch user from database
		var user models.User
		err = database.AppDB.Get(&user, "SELECT * FROM users WHERE id = ?", userID)
		if err != nil {
			core.RespondUnauthorized(c, "用户不存在", core.ErrCodeUserDeleted)
			c.Abort()
			return
		}

		// Ordered validation: is_deleted → is_disabled → token_version
		if user.IsDeleted {
			core.RespondUnauthorized(c, "账号不存在，请联系管理员", core.ErrCodeUserDeleted)
			c.Abort()
			return
		}

		if user.IsDisabled {
			core.RespondUnauthorized(c, "账号已被停用，请联系管理员", core.ErrCodeUserDisabled)
			c.Abort()
			return
		}

		if ver != user.TokenVersion {
			core.RespondUnauthorized(c, "登录已过期，请重新登录", core.ErrCodeTokenExpired)
			c.Abort()
			return
		}

		// Update last_active_at
		now := time.Now().UTC()
		_, _ = database.AppDB.Exec("UPDATE users SET last_active_at = ? WHERE id = ?", now, user.ID)

		// Inject user into context
		c.Set(UserContextKey, &user)
		c.Next()
	}
}
