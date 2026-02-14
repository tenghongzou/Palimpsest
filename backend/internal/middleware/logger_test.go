package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestLoggerPassesThrough(t *testing.T) {
	gin.SetMode(gin.TestMode)

	r := gin.New()
	r.GET("/test", Logger(), func(c *gin.Context) {
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

func TestLoggerSetsCorrectStatus(t *testing.T) {
	gin.SetMode(gin.TestMode)

	r := gin.New()
	r.GET("/created", Logger(), func(c *gin.Context) {
		c.JSON(http.StatusCreated, gin.H{"message": "created"})
	})
	r.GET("/not-found", Logger(), func(c *gin.Context) {
		c.JSON(http.StatusNotFound, gin.H{"message": "not found"})
	})

	// Test that a 201 Created status is preserved
	req, err := http.NewRequest(http.MethodGet, "/created", nil)
	if err != nil {
		t.Fatalf("failed to create request: %v", err)
	}
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Errorf("expected status %d, got %d", http.StatusCreated, w.Code)
	}

	// Test that a 404 Not Found status is preserved
	req, err = http.NewRequest(http.MethodGet, "/not-found", nil)
	if err != nil {
		t.Fatalf("failed to create request: %v", err)
	}
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected status %d, got %d", http.StatusNotFound, w.Code)
	}
}
