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

type initRequest struct {
	Username string `json:"username" binding:"required,min=1"`
	Password string `json:"password"`
}

type loginRequest struct {
	Username string `json:"username" binding:"required,min=1"`
	Password string `json:"password"`
}

// HandleInitStatus returns whether the system has been initialized.
func HandleInitStatus(c *gin.Context) {
	count, err := services.CountUsers()
	if err != nil {
		core.RespondInternalError(c)
		return
	}
	c.JSON(http.StatusOK, gin.H{"initialized": count > 0})
}

// HandleInit creates the first admin user. Only works when no users exist.
func HandleInit(c *gin.Context) {
	count, err := services.CountUsers()
	if err != nil {
		core.RespondInternalError(c)
		return
	}
	if count > 0 {
		core.RespondBadRequest(c, "系统已初始化")
		return
	}

	var req initRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		core.RespondBadRequest(c, "请求参数错误")
		return
	}

	user, err := services.CreateUser(req.Username, req.Password, "admin")
	if err != nil {
		core.RespondBadRequest(c, err.Error())
		return
	}

	services.WriteLog(fmt.Sprintf("系统初始化，创建管理员 %s", services.LogUser(user.Username, user.ID)))

	c.JSON(http.StatusCreated, gin.H{"id": user.ID, "username": user.Username})
}

// HandleLogin authenticates a user and returns a JWT.
func HandleLogin(c *gin.Context) {
	var req loginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		core.RespondBadRequest(c, "请求参数错误")
		return
	}

	user, err := services.Authenticate(req.Username, req.Password)
	if err != nil {
		// Don't distinguish between username not found and wrong password
		core.RespondError(c, http.StatusUnauthorized, err.Error())
		return
	}

	token, err := core.GenerateToken(user.ID, user.TokenVersion, config.C.JWTSecret, config.C.TokenExpireHours)
	if err != nil {
		core.RespondInternalError(c)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"token": token,
		"user": gin.H{
			"id":       user.ID,
			"username": user.Username,
			"role":     user.Role,
		},
	})
}

// HandleLogout invalidates the current token by incrementing token_version.
func HandleLogout(c *gin.Context) {
	user := middleware.GetCurrentUser(c)
	if user == nil {
		core.RespondUnauthorized(c, "未认证", core.ErrCodeTokenExpired)
		return
	}

	if err := services.IncrementTokenVersion(user.ID); err != nil {
		core.RespondInternalError(c)
		return
	}

	c.JSON(http.StatusOK, gin.H{"detail": "已登出"})
}
