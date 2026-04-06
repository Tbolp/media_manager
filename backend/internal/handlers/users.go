package handlers

import (
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"

	"media-manager/internal/config"
	"media-manager/internal/core"
	"media-manager/internal/middleware"
	"media-manager/internal/services"
)

type createUserRequest struct {
	Username string `json:"username" binding:"required,min=1"`
	Password string `json:"password"`
}

type resetPasswordRequest struct {
	Password string `json:"password"`
}

type updatePermissionsRequest struct {
	LibraryIDs []string `json:"library_ids" binding:"required"`
}

// HandleListUsers returns all non-deleted users.
func HandleListUsers(c *gin.Context) {
	users, err := services.ListUsers()
	if err != nil {
		core.RespondInternalError(c)
		return
	}

	// Build response items
	type userItem struct {
		ID         string  `json:"id"`
		Username   string  `json:"username"`
		Role       string  `json:"role"`
		IsDisabled bool    `json:"is_disabled"`
		LibraryIDs string  `json:"library_ids"`
		CreatedAt  string  `json:"created_at"`
		LastActiveAt *string `json:"last_active_at"`
	}

	items := make([]userItem, 0, len(users))
	for _, u := range users {
		item := userItem{
			ID:         u.ID,
			Username:   u.Username,
			Role:       u.Role,
			IsDisabled: u.IsDisabled,
			LibraryIDs: u.LibraryIDs,
			CreatedAt:  u.CreatedAt.Format("2006-01-02T15:04:05Z"),
		}
		if u.LastActiveAt.Valid {
			s := u.LastActiveAt.Time.Format("2006-01-02T15:04:05Z")
			item.LastActiveAt = &s
		}
		items = append(items, item)
	}

	c.JSON(http.StatusOK, gin.H{"items": items})
}

// HandleCreateUser creates a new regular user.
func HandleCreateUser(c *gin.Context) {
	var req createUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		core.RespondBadRequest(c, "请求参数错误")
		return
	}

	user, err := services.CreateUser(req.Username, req.Password, "user")
	if err != nil {
		core.RespondBadRequest(c, err.Error())
		return
	}

	admin := middleware.GetCurrentUser(c)
	services.WriteLog(fmt.Sprintf("管理员 %s 创建用户 %s", admin.Username, user.Username))

	c.JSON(http.StatusCreated, gin.H{"id": user.ID, "username": user.Username})
}

// HandleDisableUser disables a user.
func HandleDisableUser(c *gin.Context) {
	admin := middleware.GetCurrentUser(c)
	targetID := c.Param("id")

	if targetID == admin.ID {
		core.RespondBadRequest(c, "不可禁用自己")
		return
	}

	target, err := services.GetUserByID(targetID)
	if err != nil || target.IsDeleted {
		core.RespondNotFound(c, "用户不存在")
		return
	}

	if err := services.DisableUser(targetID); err != nil {
		core.RespondInternalError(c)
		return
	}

	services.WriteLog(fmt.Sprintf("管理员 %s 禁用用户 %s", admin.Username, target.Username))

	c.JSON(http.StatusOK, gin.H{"detail": "已禁用"})
}

// HandleEnableUser re-enables a user.
func HandleEnableUser(c *gin.Context) {
	admin := middleware.GetCurrentUser(c)
	targetID := c.Param("id")

	target, err := services.GetUserByID(targetID)
	if err != nil || target.IsDeleted {
		core.RespondNotFound(c, "用户不存在")
		return
	}

	if err := services.EnableUser(targetID); err != nil {
		core.RespondInternalError(c)
		return
	}

	services.WriteLog(fmt.Sprintf("管理员 %s 解禁用户 %s", admin.Username, target.Username))

	c.JSON(http.StatusOK, gin.H{"detail": "已解禁"})
}

// HandleDeleteUser soft-deletes a user and cleans up behavior data.
func HandleDeleteUser(c *gin.Context) {
	admin := middleware.GetCurrentUser(c)
	targetID := c.Param("id")

	if targetID == admin.ID {
		core.RespondBadRequest(c, "不可删除自己")
		return
	}

	target, err := services.GetUserByID(targetID)
	if err != nil || target.IsDeleted {
		core.RespondNotFound(c, "用户不存在")
		return
	}

	if err := services.DeleteUser(targetID); err != nil {
		core.RespondInternalError(c)
		return
	}

	services.WriteLog(fmt.Sprintf("管理员 %s 删除用户 %s", admin.Username, target.Username))

	c.JSON(http.StatusOK, gin.H{"detail": "已删除"})
}

// HandleResetPassword resets a user's password.
func HandleResetPassword(c *gin.Context) {
	admin := middleware.GetCurrentUser(c)
	targetID := c.Param("id")

	var req resetPasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		core.RespondBadRequest(c, "请求参数错误")
		return
	}

	target, err := services.GetUserByID(targetID)
	if err != nil || target.IsDeleted {
		core.RespondNotFound(c, "用户不存在")
		return
	}

	if err := services.ResetPassword(targetID, req.Password); err != nil {
		core.RespondInternalError(c)
		return
	}

	services.WriteLog(fmt.Sprintf("管理员 %s 重置用户 %s 的密码", admin.Username, target.Username))

	// Return a new token if the admin is resetting their own password
	if targetID == admin.ID {
		// Re-fetch to get updated token_version
		updated, _ := services.GetUserByID(targetID)
		if updated != nil {
			token, err := core.GenerateToken(updated.ID, updated.TokenVersion, config.C.JWTSecret, config.C.TokenExpireHours)
			if err == nil {
				c.JSON(http.StatusOK, gin.H{"detail": "密码已重置", "token": token})
				return
			}
		}
	}

	c.JSON(http.StatusOK, gin.H{"detail": "密码已重置"})
}

// HandleUpdatePermissions updates a user's library whitelist.
func HandleUpdatePermissions(c *gin.Context) {
	admin := middleware.GetCurrentUser(c)
	targetID := c.Param("id")

	var req updatePermissionsRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		core.RespondBadRequest(c, "请求参数错误")
		return
	}

	target, err := services.GetUserByID(targetID)
	if err != nil || target.IsDeleted {
		core.RespondNotFound(c, "用户不存在")
		return
	}

	if err := services.UpdatePermissions(targetID, req.LibraryIDs); err != nil {
		core.RespondInternalError(c)
		return
	}

	services.WriteLog(fmt.Sprintf("管理员 %s 更新用户 %s 的媒体库权限", admin.Username, target.Username))

	c.JSON(http.StatusOK, gin.H{"detail": "权限已更新"})
}
