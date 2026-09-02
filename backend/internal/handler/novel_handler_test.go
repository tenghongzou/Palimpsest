package handler

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

func TestGetByIDInvalidUUID(t *testing.T) {
	h := NewNovelHandler(nil)
	r := gin.New()
	r.GET("/novels/:id", h.GetByID)

	req := httptest.NewRequest(http.MethodGet, "/novels/not-a-uuid", nil)
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

func TestGetChapterInvalidNovelID(t *testing.T) {
	h := NewNovelHandler(nil)
	r := gin.New()
	r.GET("/novels/:id/chapters", h.ListChapters)

	req := httptest.NewRequest(http.MethodGet, "/novels/bad/chapters", nil)
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

func TestGetChapterInvalidChapterID(t *testing.T) {
	h := NewNovelHandler(nil)
	r := gin.New()
	r.GET("/novels/:id/chapters/:chapterId", h.GetChapter)

	// Use a valid UUID for the novel ID but an invalid one for the chapter ID.
	validID := uuid.New().String()
	req := httptest.NewRequest(http.MethodGet, "/novels/"+validID+"/chapters/bad", nil)
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
