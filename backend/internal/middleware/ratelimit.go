package middleware

import (
	"context"
	"fmt"
	"math"
	"net/http"
	"strconv"
	"strings"
	"sync/atomic"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
	"github.com/tenghongzou/palimpsest/backend/internal/config"
	jwtpkg "github.com/tenghongzou/palimpsest/backend/internal/pkg/jwt"
)

// requestSeq makes sorted-set members unique when requests share a millisecond.
var requestSeq atomic.Uint64

// slidingWindow records a request under key and reports whether it is within
// limit for the window, plus how many requests remain.
func slidingWindow(ctx context.Context, rdb *redis.Client, key string, limit int, window time.Duration) (bool, int, error) {
	now := time.Now().UnixMilli()
	windowStart := now - window.Milliseconds()
	member := fmt.Sprintf("%d-%d", now, requestSeq.Add(1))

	pipe := rdb.Pipeline()
	pipe.ZRemRangeByScore(ctx, key, "0", strconv.FormatInt(windowStart, 10))
	countCmd := pipe.ZCard(ctx, key)
	pipe.ZAdd(ctx, key, redis.Z{Score: float64(now), Member: member})
	pipe.PExpire(ctx, key, window)
	if _, err := pipe.Exec(ctx); err != nil {
		return true, limit, err
	}

	count := int(countCmd.Val())
	if count >= limit {
		return false, 0, nil
	}
	return true, limit - count - 1, nil
}

func limitRequest(c *gin.Context, rdb *redis.Client, key string, limit int, window time.Duration) bool {
	allowed, remaining, err := slidingWindow(c.Request.Context(), rdb, key, limit, window)
	if err != nil {
		// If Redis is down, allow the request.
		return true
	}
	c.Header("X-RateLimit-Limit", strconv.Itoa(limit))
	c.Header("X-RateLimit-Remaining", strconv.Itoa(remaining))
	if !allowed {
		c.Header("Retry-After", strconv.Itoa(int(math.Ceil(window.Seconds()))))
		c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
			"code":    42901,
			"message": "rate limit exceeded",
		})
		return false
	}
	return true
}

// GlobalLimits are the API-wide request quotas per window.
type GlobalLimits struct {
	Public int // per client IP, for anonymous requests
	User   int // per user, for requests with a valid access token
	Admin  int // per user, for admins (bulk catalogue work)
}

// GlobalRateLimiter applies the API-wide limits: per user for requests
// carrying a valid access token (admins get their own, larger quota), per
// client IP otherwise.
// It runs before route-level Auth, so it validates the token itself; an
// invalid token simply falls back to the IP limit.
func GlobalRateLimiter(rdb *redis.Client, cfg *config.Config, limits GlobalLimits, window time.Duration) gin.HandlerFunc {
	return func(c *gin.Context) {
		if rdb == nil {
			c.Next()
			return
		}
		key := "palimpsest:ratelimit:global:ip:" + c.ClientIP()
		limit := limits.Public
		if token, ok := strings.CutPrefix(c.GetHeader("Authorization"), "Bearer "); ok {
			if claims, err := jwtpkg.ValidateTokenType(cfg.JWT.Secret, token, jwtpkg.TypeAccess); err == nil {
				key = "palimpsest:ratelimit:global:user:" + claims.UserID.String()
				limit = limits.User
				if claims.Role == "admin" {
					limit = limits.Admin
				}
			}
		}
		if limitRequest(c, rdb, key, limit, window) {
			c.Next()
		}
	}
}

// RateLimiterWithRedis limits the routes sharing scope: per user when
// authenticated (Auth must run first), per client IP otherwise. An empty
// scope gives each route its own quota.
func RateLimiterWithRedis(rdb *redis.Client, scope string, limit int, window time.Duration) gin.HandlerFunc {
	return func(c *gin.Context) {
		if rdb == nil {
			c.Next()
			return
		}
		key := c.ClientIP()
		if userID, exists := c.Get("userID"); exists {
			key = fmt.Sprintf("%v", userID)
		}
		routeScope := scope
		if routeScope == "" {
			routeScope = c.FullPath()
		}
		redisKey := fmt.Sprintf("palimpsest:ratelimit:%s:%s", routeScope, key)
		if limitRequest(c, rdb, redisKey, limit, window) {
			c.Next()
		}
	}
}

// RateLimiter is a no-op fallback when Redis is not available.
func RateLimiter() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Next()
	}
}
