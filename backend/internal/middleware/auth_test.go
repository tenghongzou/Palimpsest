package middleware

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/tenghongzou/palimpsest/backend/internal/config"
	jwtpkg "github.com/tenghongzou/palimpsest/backend/internal/pkg/jwt"
)

func init() {
	gin.SetMode(gin.TestMode)
}

func newTestConfig() *config.Config {
	cfg := &config.Config{}
	cfg.JWT.Secret = "test-secret-for-middleware-tests"
	return cfg
}

func TestAuthMissingHeader(t *testing.T) {
	cfg := newTestConfig()

	r := gin.New()
	r.GET("/test", Auth(cfg), func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"message": "ok"})
	})

	req, err := http.NewRequest(http.MethodGet, "/test", nil)
	if err != nil {
		t.Fatalf("failed to create request: %v", err)
	}
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected status %d, got %d", http.StatusUnauthorized, w.Code)
	}

	var body map[string]interface{}
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("failed to parse response body: %v", err)
	}

	code, ok := body["code"].(float64)
	if !ok || int(code) != 40101 {
		t.Errorf("expected code 40101, got %v", body["code"])
	}
}

func TestAuthInvalidFormat(t *testing.T) {
	cfg := newTestConfig()

	r := gin.New()
	r.GET("/test", Auth(cfg), func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"message": "ok"})
	})

	req, err := http.NewRequest(http.MethodGet, "/test", nil)
	if err != nil {
		t.Fatalf("failed to create request: %v", err)
	}
	req.Header.Set("Authorization", "Token some-token-value")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected status %d, got %d", http.StatusUnauthorized, w.Code)
	}

	var body map[string]interface{}
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("failed to parse response body: %v", err)
	}

	code, ok := body["code"].(float64)
	if !ok || int(code) != 40102 {
		t.Errorf("expected code 40102, got %v", body["code"])
	}
}

func TestAuthInvalidToken(t *testing.T) {
	cfg := newTestConfig()

	r := gin.New()
	r.GET("/test", Auth(cfg), func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"message": "ok"})
	})

	req, err := http.NewRequest(http.MethodGet, "/test", nil)
	if err != nil {
		t.Fatalf("failed to create request: %v", err)
	}
	req.Header.Set("Authorization", "Bearer this-is-not-a-valid-jwt")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected status %d, got %d", http.StatusUnauthorized, w.Code)
	}

	var body map[string]interface{}
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("failed to parse response body: %v", err)
	}

	code, ok := body["code"].(float64)
	if !ok || int(code) != 40103 {
		t.Errorf("expected code 40103, got %v", body["code"])
	}
}

func TestAuthExpiredToken(t *testing.T) {
	cfg := newTestConfig()

	userID := uuid.New()
	// Generate a token that expired 1 hour ago
	token, err := jwtpkg.GenerateAccessToken(cfg.JWT.Secret, userID, "reader", -time.Hour)
	if err != nil {
		t.Fatalf("failed to generate expired token: %v", err)
	}

	r := gin.New()
	r.GET("/test", Auth(cfg), func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"message": "ok"})
	})

	req, err := http.NewRequest(http.MethodGet, "/test", nil)
	if err != nil {
		t.Fatalf("failed to create request: %v", err)
	}
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected status %d, got %d", http.StatusUnauthorized, w.Code)
	}

	var body map[string]interface{}
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("failed to parse response body: %v", err)
	}

	code, ok := body["code"].(float64)
	if !ok || int(code) != 40103 {
		t.Errorf("expected code 40103, got %v", body["code"])
	}
}

func TestAuthValidToken(t *testing.T) {
	cfg := newTestConfig()

	userID := uuid.New()
	role := "reader"
	token, err := jwtpkg.GenerateAccessToken(cfg.JWT.Secret, userID, role, time.Hour)
	if err != nil {
		t.Fatalf("failed to generate token: %v", err)
	}

	var capturedUserID uuid.UUID
	var capturedRole string

	router := gin.New()
	router.GET("/test", Auth(cfg), func(c *gin.Context) {
		uid, _ := c.Get("userID")
		capturedUserID = uid.(uuid.UUID)
		r, _ := c.Get("userRole")
		capturedRole = r.(string)
		c.JSON(http.StatusOK, gin.H{"message": "ok"})
	})

	req, err := http.NewRequest(http.MethodGet, "/test", nil)
	if err != nil {
		t.Fatalf("failed to create request: %v", err)
	}
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, w.Code)
	}

	if capturedUserID != userID {
		t.Errorf("expected userID %s, got %s", userID, capturedUserID)
	}

	if capturedRole != role {
		t.Errorf("expected role %q, got %q", role, capturedRole)
	}
}

func TestAdminOnlyWithAdminRole(t *testing.T) {
	r := gin.New()
	r.GET("/test", func(c *gin.Context) {
		c.Set("userRole", "admin")
		c.Next()
	}, AdminOnly(), func(c *gin.Context) {
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

func TestAdminOnlyWithReaderRole(t *testing.T) {
	r := gin.New()
	r.GET("/test", func(c *gin.Context) {
		c.Set("userRole", "reader")
		c.Next()
	}, AdminOnly(), func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"message": "ok"})
	})

	req, err := http.NewRequest(http.MethodGet, "/test", nil)
	if err != nil {
		t.Fatalf("failed to create request: %v", err)
	}
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusForbidden {
		t.Errorf("expected status %d, got %d", http.StatusForbidden, w.Code)
	}

	var body map[string]interface{}
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("failed to parse response body: %v", err)
	}

	code, ok := body["code"].(float64)
	if !ok || int(code) != 40301 {
		t.Errorf("expected code 40301, got %v", body["code"])
	}
}

func TestAdminOnlyWithoutRole(t *testing.T) {
	r := gin.New()
	r.GET("/test", AdminOnly(), func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"message": "ok"})
	})

	req, err := http.NewRequest(http.MethodGet, "/test", nil)
	if err != nil {
		t.Fatalf("failed to create request: %v", err)
	}
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusForbidden {
		t.Errorf("expected status %d, got %d", http.StatusForbidden, w.Code)
	}

	var body map[string]interface{}
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("failed to parse response body: %v", err)
	}

	code, ok := body["code"].(float64)
	if !ok || int(code) != 40301 {
		t.Errorf("expected code 40301, got %v", body["code"])
	}
}
