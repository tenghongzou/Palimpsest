package handler

import (
	"github.com/gin-gonic/gin"
)

type AuthHandler struct {
	// TODO: inject AuthService
}

func NewAuthHandler() *AuthHandler {
	return &AuthHandler{}
}

func (h *AuthHandler) Register(c *gin.Context) {
	// TODO: implement POST /auth/register
}

func (h *AuthHandler) Login(c *gin.Context) {
	// TODO: implement POST /auth/login
}

func (h *AuthHandler) RefreshToken(c *gin.Context) {
	// TODO: implement POST /auth/refresh
}

func (h *AuthHandler) Logout(c *gin.Context) {
	// TODO: implement POST /auth/logout
}

func (h *AuthHandler) ForgotPassword(c *gin.Context) {
	// TODO: implement POST /auth/forgot-password
}

func (h *AuthHandler) ResetPassword(c *gin.Context) {
	// TODO: implement POST /auth/reset-password
}
