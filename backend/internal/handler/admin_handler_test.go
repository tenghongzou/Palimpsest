package handler

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestAdminUpdateNovelInvalidID(t *testing.T) {
	h := NewAdminHandler(nil, nil)
	r := gin.New()
	r.PUT("/admin/novels/:id", h.UpdateNovel)

	req := httptest.NewRequest(http.MethodPut, "/admin/novels/not-uuid", nil)
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

func TestAdminDeleteNovelInvalidID(t *testing.T) {
	h := NewAdminHandler(nil, nil)
	r := gin.New()
	r.DELETE("/admin/novels/:id", h.DeleteNovel)

	req := httptest.NewRequest(http.MethodDelete, "/admin/novels/not-uuid", nil)
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

func TestAdminPublishNovelInvalidID(t *testing.T) {
	h := NewAdminHandler(nil, nil)
	r := gin.New()
	r.POST("/admin/novels/:id/publish", h.PublishNovel)

	req := httptest.NewRequest(http.MethodPost, "/admin/novels/not-uuid/publish", nil)
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

func TestAdminCreateChapterMissingBody(t *testing.T) {
	h := NewAdminHandler(nil, nil)
	r := gin.New()
	r.POST("/admin/chapters", h.CreateChapter)

	req := httptest.NewRequest(http.MethodPost, "/admin/chapters", nil)
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

func TestAdminUpdateUserStatusInvalidID(t *testing.T) {
	h := NewAdminHandler(nil, nil)
	r := gin.New()
	r.PUT("/admin/users/:userId/status", h.UpdateUserStatus)

	req := httptest.NewRequest(http.MethodPut, "/admin/users/not-uuid/status", nil)
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

func TestAdminGetUserInvalidID(t *testing.T) {
	h := NewAdminHandler(nil, nil)
	r := gin.New()
	r.GET("/admin/users/:userId", h.GetUser)

	req := httptest.NewRequest(http.MethodGet, "/admin/users/not-uuid", nil)
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

func TestAdminModerateReviewInvalidID(t *testing.T) {
	h := NewAdminHandler(nil, nil)
	r := gin.New()
	r.PUT("/admin/reviews/:reviewId", h.ModerateReview)

	req := httptest.NewRequest(http.MethodPut, "/admin/reviews/not-uuid", nil)
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
