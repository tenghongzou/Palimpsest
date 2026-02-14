package handler

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
)

type apiResponse struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

func init() {
	gin.SetMode(gin.TestMode)
}

func TestRegisterMissingBody(t *testing.T) {
	h := NewAuthHandler(nil)
	r := gin.New()
	r.POST("/register", h.Register)

	req := httptest.NewRequest(http.MethodPost, "/register", nil)
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

func TestRegisterMissingUsername(t *testing.T) {
	h := NewAuthHandler(nil)
	r := gin.New()
	r.POST("/register", h.Register)

	body := `{"email":"a@b.com","password":"12345678"}`
	req := httptest.NewRequest(http.MethodPost, "/register", strings.NewReader(body))
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

func TestRegisterPasswordTooShort(t *testing.T) {
	h := NewAuthHandler(nil)
	r := gin.New()
	r.POST("/register", h.Register)

	body := `{"username":"test","email":"a@b.com","password":"123"}`
	req := httptest.NewRequest(http.MethodPost, "/register", strings.NewReader(body))
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

func TestLoginMissingBody(t *testing.T) {
	h := NewAuthHandler(nil)
	r := gin.New()
	r.POST("/login", h.Login)

	req := httptest.NewRequest(http.MethodPost, "/login", nil)
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

func TestLoginMissingPassword(t *testing.T) {
	h := NewAuthHandler(nil)
	r := gin.New()
	r.POST("/login", h.Login)

	body := `{"username":"test"}`
	req := httptest.NewRequest(http.MethodPost, "/login", strings.NewReader(body))
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

func TestRefreshMissingBody(t *testing.T) {
	h := NewAuthHandler(nil)
	r := gin.New()
	r.POST("/refresh", h.RefreshToken)

	req := httptest.NewRequest(http.MethodPost, "/refresh", nil)
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

func TestRefreshMissingToken(t *testing.T) {
	h := NewAuthHandler(nil)
	r := gin.New()
	r.POST("/refresh", h.RefreshToken)

	body := `{}`
	req := httptest.NewRequest(http.MethodPost, "/refresh", strings.NewReader(body))
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
