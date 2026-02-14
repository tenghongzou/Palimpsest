package handler

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// setUserID returns middleware that sets a fake userID in the context
// so that handlers calling c.MustGet("userID") do not panic.
func setUserID() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Set("userID", uuid.New())
		c.Next()
	}
}

func TestAddToBookshelfMissingBody(t *testing.T) {
	h := NewBookshelfHandler(nil)
	r := gin.New()
	r.Use(setUserID())
	r.POST("/bookshelf", h.Add)

	req := httptest.NewRequest(http.MethodPost, "/bookshelf", nil)
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Fatalf("expected status 400, got %d", w.Code)
	}

	var resp apiResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}
	if resp.Code != 40001 {
		t.Errorf("expected code 40001, got %d", resp.Code)
	}
}

func TestAddToBookshelfInvalidNovelID(t *testing.T) {
	h := NewBookshelfHandler(nil)
	r := gin.New()
	r.Use(setUserID())
	r.POST("/bookshelf", h.Add)

	body := `{"novel_id":"not-uuid"}`
	req := httptest.NewRequest(http.MethodPost, "/bookshelf", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Fatalf("expected status 400, got %d", w.Code)
	}

	var resp apiResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}
	if resp.Code != 40001 {
		t.Errorf("expected code 40001, got %d", resp.Code)
	}
}

func TestRemoveFromBookshelfInvalidID(t *testing.T) {
	h := NewBookshelfHandler(nil)
	r := gin.New()
	r.Use(setUserID())
	r.DELETE("/bookshelf/:novelId", h.Remove)

	req := httptest.NewRequest(http.MethodDelete, "/bookshelf/not-uuid", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Fatalf("expected status 400, got %d", w.Code)
	}

	var resp apiResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}
	if resp.Code != 40001 {
		t.Errorf("expected code 40001, got %d", resp.Code)
	}
}

func TestUpdateProgressMissingBody(t *testing.T) {
	h := NewBookshelfHandler(nil)
	r := gin.New()
	r.Use(setUserID())
	r.PUT("/bookshelf/:novelId/progress", h.UpdateProgress)

	// Use a valid UUID for the route parameter so we reach the body-parsing step.
	validID := uuid.New().String()
	req := httptest.NewRequest(http.MethodPut, "/bookshelf/"+validID+"/progress", nil)
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Fatalf("expected status 400, got %d", w.Code)
	}

	var resp apiResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}
	if resp.Code != 40001 {
		t.Errorf("expected code 40001, got %d", resp.Code)
	}
}

func TestGetProgressInvalidNovelID(t *testing.T) {
	h := NewBookshelfHandler(nil)
	r := gin.New()
	r.Use(setUserID())
	r.GET("/bookshelf/:novelId/progress", h.GetProgress)

	req := httptest.NewRequest(http.MethodGet, "/bookshelf/not-uuid/progress", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Fatalf("expected status 400, got %d", w.Code)
	}

	var resp apiResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}
	if resp.Code != 40001 {
		t.Errorf("expected code 40001, got %d", resp.Code)
	}
}
