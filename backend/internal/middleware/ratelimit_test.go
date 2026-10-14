package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/alicebob/miniredis/v2"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
	jwtpkg "github.com/tenghongzou/palimpsest/backend/internal/pkg/jwt"
)

func TestNoOpRateLimiterPassesThrough(t *testing.T) {
	gin.SetMode(gin.TestMode)

	r := gin.New()
	r.GET("/test", RateLimiter(), func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"message": "ok"})
	})

	req, err := http.NewRequest(http.MethodGet, "/test", nil)
	if err != nil {
		t.Fatalf("failed to create request: %v", err)
	}
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, w.Code)
	}
}

func newLimitedRouter(t *testing.T, handlers ...gin.HandlerFunc) (*gin.Engine, *miniredis.Miniredis) {
	t.Helper()
	gin.SetMode(gin.TestMode)
	mr := miniredis.RunT(t)
	rdb := redis.NewClient(&redis.Options{Addr: mr.Addr()})
	t.Cleanup(func() { rdb.Close() })

	cfg := newTestConfig()
	r := gin.New()
	r.Use(GlobalRateLimiter(rdb, cfg, GlobalLimits{Public: 2, User: 3, Admin: 5}, time.Minute))
	r.Use(handlers...)
	ok := func(c *gin.Context) { c.Status(http.StatusOK) }
	r.GET("/a", ok)
	r.GET("/b", ok)
	return r, mr
}

func doRequest(r *gin.Engine, path, token string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(http.MethodGet, path, nil)
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	return w
}

func TestGlobalRateLimiterPublic(t *testing.T) {
	r, _ := newLimitedRouter(t)

	// The public limit is shared across routes.
	if w := doRequest(r, "/a", ""); w.Code != http.StatusOK || w.Header().Get("X-RateLimit-Remaining") != "1" {
		t.Fatalf("first request: code %d remaining %q", w.Code, w.Header().Get("X-RateLimit-Remaining"))
	}
	if w := doRequest(r, "/b", ""); w.Code != http.StatusOK {
		t.Fatalf("second request: code %d", w.Code)
	}
	w := doRequest(r, "/a", "")
	if w.Code != http.StatusTooManyRequests {
		t.Fatalf("third request: expected 429, got %d", w.Code)
	}
	if w.Header().Get("Retry-After") == "" {
		t.Error("expected Retry-After header")
	}
}

func TestGlobalRateLimiterAdminsGetTheirOwnLimit(t *testing.T) {
	r, _ := newLimitedRouter(t)
	token, _ := jwtpkg.GenerateAccessToken(newTestConfig().JWT.Secret, uuid.New(), "admin", time.Hour)
	for i := 0; i < 5; i++ {
		if w := doRequest(r, "/a", token); w.Code != http.StatusOK {
			t.Fatalf("admin request %d: expected 200, got %d", i+1, w.Code)
		}
	}
	if w := doRequest(r, "/a", token); w.Code != http.StatusTooManyRequests {
		t.Fatalf("expected 429 after the admin limit, got %d", w.Code)
	}
}

func TestGlobalRateLimiterAuthenticatedUsesUserLimit(t *testing.T) {
	r, _ := newLimitedRouter(t)
	cfg := newTestConfig()
	token, _ := jwtpkg.GenerateAccessToken(cfg.JWT.Secret, uuid.New(), "reader", time.Hour)

	for i := 0; i < 3; i++ {
		if w := doRequest(r, "/a", token); w.Code != http.StatusOK {
			t.Fatalf("request %d: expected 200, got %d", i+1, w.Code)
		}
	}
	if w := doRequest(r, "/a", token); w.Code != http.StatusTooManyRequests {
		t.Fatalf("expected 429 after user limit, got %d", w.Code)
	}
	// Anonymous clients from the same IP have their own quota.
	if w := doRequest(r, "/a", ""); w.Code != http.StatusOK {
		t.Fatalf("anonymous request: expected 200, got %d", w.Code)
	}
}

func TestGlobalRateLimiterInvalidTokenFallsBackToIP(t *testing.T) {
	r, _ := newLimitedRouter(t)
	for i := 0; i < 2; i++ {
		doRequest(r, "/a", "garbage")
	}
	if w := doRequest(r, "/a", "garbage"); w.Code != http.StatusTooManyRequests {
		t.Fatalf("expected IP limit to apply to invalid tokens, got %d", w.Code)
	}
}

func TestGlobalRateLimiterRedisDownAllows(t *testing.T) {
	r, mr := newLimitedRouter(t)
	mr.Close()
	for i := 0; i < 5; i++ {
		if w := doRequest(r, "/a", ""); w.Code != http.StatusOK {
			t.Fatalf("expected requests to pass when Redis is down, got %d", w.Code)
		}
	}
}

func TestScopedRateLimiterSharesQuota(t *testing.T) {
	gin.SetMode(gin.TestMode)
	mr := miniredis.RunT(t)
	rdb := redis.NewClient(&redis.Options{Addr: mr.Addr()})
	defer rdb.Close()

	limit := RateLimiterWithRedis(rdb, "translation", 2, time.Minute)
	r := gin.New()
	ok := func(c *gin.Context) { c.Status(http.StatusOK) }
	r.GET("/x", limit, ok)
	r.GET("/y", limit, ok)

	doRequest(r, "/x", "")
	doRequest(r, "/y", "")
	if w := doRequest(r, "/x", ""); w.Code != http.StatusTooManyRequests {
		t.Fatalf("expected shared scope quota to be exhausted, got %d", w.Code)
	}
}

func TestClientIPIgnoresSpoofedForwardedFor(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	if err := r.SetTrustedProxies([]string{"10.0.0.0/8"}); err != nil {
		t.Fatal(err)
	}
	r.GET("/ip", func(c *gin.Context) { c.String(http.StatusOK, c.ClientIP()) })

	cases := []struct{ remote, xff, want string }{
		// Behind the BFF (trusted): the browser IP appended by the proxy wins.
		{"10.0.0.5:1234", "203.0.113.9", "203.0.113.9"},
		// A client spoofing the header through the BFF only controls the left part.
		{"10.0.0.5:1234", "1.2.3.4, 203.0.113.9", "203.0.113.9"},
		// Direct untrusted connection: the header is ignored.
		{"198.51.100.7:1234", "1.2.3.4", "198.51.100.7"},
	}
	for _, c := range cases {
		req := httptest.NewRequest(http.MethodGet, "/ip", nil)
		req.RemoteAddr = c.remote
		req.Header.Set("X-Forwarded-For", c.xff)
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)
		if w.Body.String() != c.want {
			t.Errorf("remote %s xff %q: got %s, want %s", c.remote, c.xff, w.Body.String(), c.want)
		}
	}
}
