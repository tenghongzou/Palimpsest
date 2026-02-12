package middleware

import (
	"github.com/gin-gonic/gin"
)

// RateLimiter applies token-bucket rate limiting per IP/user.
// Limits: 60 req/min (public), 120 req/min (authenticated), 20 req/min (translation).
func RateLimiter() gin.HandlerFunc {
	// TODO: implement with Redis-backed token bucket
	return func(c *gin.Context) {
		c.Next()
	}
}
