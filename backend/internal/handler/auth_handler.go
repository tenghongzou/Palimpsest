package handler

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/service"
)

type AuthHandler struct {
	authSvc *service.AuthService
}

func NewAuthHandler(authSvc *service.AuthService) *AuthHandler {
	return &AuthHandler{authSvc: authSvc}
}

func (h *AuthHandler) Register(c *gin.Context) {
	var req service.RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, err.Error()))
		return
	}

	user, tokens, err := h.authSvc.Register(&req)
	if err != nil {
		switch {
		case errors.Is(err, service.ErrUsernameExists):
			c.JSON(http.StatusConflict, model.ErrorResponse(40901, "username already exists"))
		case errors.Is(err, service.ErrEmailExists):
			c.JSON(http.StatusConflict, model.ErrorResponse(40902, "email already exists"))
		default:
			c.JSON(http.StatusInternalServerError, model.ErrorResponse(50001, "registration failed"))
		}
		return
	}

	c.JSON(http.StatusCreated, model.SuccessResponse(gin.H{
		"user":   user,
		"tokens": tokens,
	}))
}

func (h *AuthHandler) Login(c *gin.Context) {
	var req service.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, err.Error()))
		return
	}

	user, tokens, err := h.authSvc.Login(&req)
	if err != nil {
		switch {
		case errors.Is(err, service.ErrInvalidCredentials):
			c.JSON(http.StatusUnauthorized, model.ErrorResponse(40101, "invalid username or password"))
		case errors.Is(err, service.ErrUserBanned):
			c.JSON(http.StatusForbidden, model.ErrorResponse(40301, "account is banned"))
		default:
			c.JSON(http.StatusInternalServerError, model.ErrorResponse(50001, "login failed"))
		}
		return
	}

	c.JSON(http.StatusOK, model.SuccessResponse(gin.H{
		"user":   user,
		"tokens": tokens,
	}))
}

func (h *AuthHandler) RefreshToken(c *gin.Context) {
	var req service.RefreshRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, err.Error()))
		return
	}

	tokens, err := h.authSvc.RefreshToken(&req)
	if err != nil {
		c.JSON(http.StatusUnauthorized, model.ErrorResponse(40104, "invalid refresh token"))
		return
	}

	c.JSON(http.StatusOK, model.SuccessResponse(tokens))
}

func (h *AuthHandler) Logout(c *gin.Context) {
	// Token invalidation would require a blocklist in Redis
	// For stateless JWT, client simply discards the token
	c.JSON(http.StatusOK, model.SuccessResponse(nil))
}

func (h *AuthHandler) ForgotPassword(c *gin.Context) {
	var req service.ForgotPasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, err.Error()))
		return
	}

	_, _ = h.authSvc.ForgotPassword(&req)
	// Always return success to prevent email enumeration
	c.JSON(http.StatusOK, model.SuccessResponse(gin.H{
		"message": "if the email exists, a reset link has been sent",
	}))
}

func (h *AuthHandler) ResetPassword(c *gin.Context) {
	var req service.ResetPasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, err.Error()))
		return
	}

	if err := h.authSvc.ResetPassword(&req); err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40002, "invalid or expired reset token"))
		return
	}

	c.JSON(http.StatusOK, model.SuccessResponse(gin.H{
		"message": "password reset successfully",
	}))
}
