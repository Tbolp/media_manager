package core

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// Error codes for 401 responses
const (
	ErrCodeTokenExpired = "token_expired"
	ErrCodeUserDisabled = "user_disabled"
	ErrCodeUserDeleted  = "user_deleted"
)

// ErrorResponse is the standard error response body.
type ErrorResponse struct {
	Detail    string `json:"detail"`
	ErrorCode string `json:"error_code,omitempty"`
}

func RespondError(c *gin.Context, status int, detail string) {
	c.JSON(status, ErrorResponse{Detail: detail})
}

func RespondErrorWithCode(c *gin.Context, status int, detail, errorCode string) {
	c.JSON(status, ErrorResponse{Detail: detail, ErrorCode: errorCode})
}

func RespondBadRequest(c *gin.Context, detail string) {
	RespondError(c, http.StatusBadRequest, detail)
}

func RespondUnauthorized(c *gin.Context, detail, errorCode string) {
	RespondErrorWithCode(c, http.StatusUnauthorized, detail, errorCode)
}

func RespondForbidden(c *gin.Context, detail string) {
	RespondError(c, http.StatusForbidden, detail)
}

func RespondNotFound(c *gin.Context, detail string) {
	RespondError(c, http.StatusNotFound, detail)
}

func RespondConflict(c *gin.Context, detail string) {
	RespondError(c, http.StatusConflict, detail)
}

func RespondInternalError(c *gin.Context) {
	RespondError(c, http.StatusInternalServerError, "服务异常，请稍后再试")
}
