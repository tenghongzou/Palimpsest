package middleware

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
)

// BanTTL outlives every access token issued before a ban; after that,
// login and refresh check the account status themselves.
const BanTTL = 25 * time.Hour

// BannedUserKey marks a banned user in Redis.
func BannedUserKey(id uuid.UUID) string {
	return "palimpsest:user:" + id.String() + ":banned"
}

// RejectBanned stops requests from users banned after their access token
// was issued, so a ban takes effect immediately. Auth must run first. If
// Redis is unavailable the request is allowed.
func RejectBanned(rdb *redis.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		if rdb == nil {
			c.Next()
			return
		}
		userID, ok := c.Get("userID")
		if !ok {
			c.Next()
			return
		}
		n, err := rdb.Exists(c.Request.Context(), BannedUserKey(userID.(uuid.UUID))).Result()
		if err == nil && n > 0 {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
				"code":    40303,
				"message": "account is banned",
			})
			return
		}
		c.Next()
	}
}
