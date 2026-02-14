package handler

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestSearchMissingQuery(t *testing.T) {
	h := NewSearchHandler(nil)
	r := gin.New()
	r.GET("/search", h.SearchNovels)

	req := httptest.NewRequest(http.MethodGet, "/search", nil)
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

func TestSuggestionsEmptyQuery(t *testing.T) {
	h := NewSearchHandler(nil)
	r := gin.New()
	r.GET("/search/suggestions", h.Suggestions)

	req := httptest.NewRequest(http.MethodGet, "/search/suggestions", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}

	var resp struct {
		Code int      `json:"code"`
		Data []string `json:"data"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}
	if resp.Code != 0 {
		t.Errorf("expected code 0, got %d", resp.Code)
	}
}
