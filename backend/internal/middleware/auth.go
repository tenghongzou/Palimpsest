package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/tenghongzou/palimpsest/backend/internal/config"
	jwtpkg "github.com/tenghongzou/palimpsest/backend/internal/pkg/jwt"
)

// Auth validates JWT Bearer tokens on protected routes.
func Auth(cfg *config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		header := c.GetHeader("Authorization")
		if header == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"code":    40101,
				"message": "missing authorization header",
			})
			return
		}

		token := strings.TrimPrefix(header, "Bearer ")
		if token == header {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"code":    40102,
				"message": "invalid authorization format",
			})
			return
		}

		claims, err := jwtpkg.ValidateTokenType(cfg.JWT.Secret, token, jwtpkg.TypeAccess)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"code":    40103,
				"message": "invalid or expired token",
			})
			return
		}

		c.Set("userID", claims.UserID)
		c.Set("userRole", claims.Role)
		c.Next()
	}
}

// AdminOnly ensures the authenticated user has admin role.
func AdminOnly() gin.HandlerFunc {
	return func(c *gin.Context) {
		role, exists := c.Get("userRole")
		if !exists || role != "admin" {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
				"code":    40301,
				"message": "admin access required",
			})
			return
		}
		c.Next()
	}
}

// OptionalAuth identifies the user when a valid access token is sent but
// lets anonymous requests through, for public pages that personalise
// results (such as marking what the viewer liked).
func OptionalAuth(cfg *config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		if token, ok := strings.CutPrefix(c.GetHeader("Authorization"), "Bearer "); ok {
			if claims, err := jwtpkg.ValidateTokenType(cfg.JWT.Secret, token, jwtpkg.TypeAccess); err == nil {
				c.Set("userID", claims.UserID)
				c.Set("userRole", claims.Role)
			}
		}
		c.Next()
	}
}
