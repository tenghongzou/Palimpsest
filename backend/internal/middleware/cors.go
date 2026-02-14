package middleware

import (
	"github.com/gin-gonic/gin"
	"github.com/tenghongzou/palimpsest/backend/internal/config"
)

// CORS configures Cross-Origin Resource Sharing with whitelisted domains.
// Set CORS_ALLOWED_ORIGINS env to a comma-separated list of origins,
// or "*" to allow all (default for development).
func CORS(cfg *config.Config) gin.HandlerFunc {
	allowed := make(map[string]bool, len(cfg.CORS.AllowedOrigins))
	allowAll := false
	for _, o := range cfg.CORS.AllowedOrigins {
		if o == "*" {
			allowAll = true
			break
		}
		allowed[o] = true
	}

	return func(c *gin.Context) {
		origin := c.GetHeader("Origin")

		if allowAll {
			c.Header("Access-Control-Allow-Origin", "*")
		} else if origin != "" && allowed[origin] {
			c.Header("Access-Control-Allow-Origin", origin)
			c.Header("Vary", "Origin")
		}

		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Origin, Content-Type, Authorization, Accept-Language, X-Device-Type, X-App-Version")
		c.Header("Access-Control-Max-Age", "86400")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	}
}
