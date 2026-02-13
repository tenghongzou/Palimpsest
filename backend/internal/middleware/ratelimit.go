package middleware

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
)

// RateLimiterWithRedis creates a rate limiter backed by Redis sliding window.
func RateLimiterWithRedis(rdb *redis.Client, limit int, window time.Duration) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Use IP for unauthenticated, userID for authenticated
		key := c.ClientIP()
		if userID, exists := c.Get("userID"); exists {
			key = fmt.Sprintf("%v", userID)
		}
		redisKey := fmt.Sprintf("palimpsest:ratelimit:%s:%s", c.FullPath(), key)

		ctx := context.Background()
		now := time.Now().UnixMilli()
		windowStart := now - window.Milliseconds()

		pipe := rdb.Pipeline()
		pipe.ZRemRangeByScore(ctx, redisKey, "0", fmt.Sprintf("%d", windowStart))
		pipe.ZCard(ctx, redisKey)
		pipe.ZAdd(ctx, redisKey, redis.Z{Score: float64(now), Member: now})
		pipe.Expire(ctx, redisKey, window)

		results, err := pipe.Exec(ctx)
		if err != nil {
			// If Redis is down, allow the request
			c.Next()
			return
		}

		count := results[1].(*redis.IntCmd).Val()
		if count >= int64(limit) {
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
				"code":    42901,
				"message": "rate limit exceeded",
			})
			return
		}

		c.Next()
	}
}

// RateLimiter is a no-op fallback when Redis is not available.
func RateLimiter() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Next()
	}
}
