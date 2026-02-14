package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/tenghongzou/palimpsest/backend/internal/config"
)

func TestCORSHeaders(t *testing.T) {
	gin.SetMode(gin.TestMode)
	cfg := &config.Config{}

	r := gin.New()
	r.GET("/test", CORS(cfg), func(c *gin.Context) {
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

	expectedHeaders := map[string]string{
		"Access-Control-Allow-Origin":  "*",
		"Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS",
		"Access-Control-Allow-Headers": "Origin, Content-Type, Authorization, Accept-Language, X-Device-Type, X-App-Version",
		"Access-Control-Max-Age":       "86400",
	}

	for header, expected := range expectedHeaders {
		actual := w.Header().Get(header)
		if actual != expected {
			t.Errorf("expected header %s to be %q, got %q", header, expected, actual)
		}
	}
}

func TestCORSOptionsRequest(t *testing.T) {
	gin.SetMode(gin.TestMode)
	cfg := &config.Config{}

	r := gin.New()
	r.OPTIONS("/test", CORS(cfg), func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"message": "ok"})
	})

	req, err := http.NewRequest(http.MethodOptions, "/test", nil)
	if err != nil {
		t.Fatalf("failed to create request: %v", err)
	}
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusNoContent {
		t.Errorf("expected status %d, got %d", http.StatusNoContent, w.Code)
	}

	expectedHeaders := map[string]string{
		"Access-Control-Allow-Origin":  "*",
		"Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS",
		"Access-Control-Allow-Headers": "Origin, Content-Type, Authorization, Accept-Language, X-Device-Type, X-App-Version",
		"Access-Control-Max-Age":       "86400",
	}

	for header, expected := range expectedHeaders {
		actual := w.Header().Get(header)
		if actual != expected {
			t.Errorf("expected header %s to be %q, got %q", header, expected, actual)
		}
	}
}
