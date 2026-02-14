package model

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestUserJSONMarshal(t *testing.T) {
	now := time.Now().Truncate(time.Second)
	user := User{
		ID:               uuid.MustParse("11111111-1111-1111-1111-111111111111"),
		Username:         "testuser",
		PasswordHash:     "secret-hash-should-not-appear",
		Nickname:         "Test",
		Role:             "reader",
		Status:           "active",
		LanguagePref:     "zh-TW",
		TotalReadWords:   1000,
		TotalReadSeconds: 3600,
		CreatedAt:        now,
		UpdatedAt:        now,
	}

	data, err := json.Marshal(user)
	if err != nil {
		t.Fatalf("json.Marshal() error: %v", err)
	}

	var raw map[string]interface{}
	if err := json.Unmarshal(data, &raw); err != nil {
		t.Fatalf("json.Unmarshal() error: %v", err)
	}

	// PasswordHash must not appear in JSON (json:"-")
	if _, exists := raw["password_hash"]; exists {
		t.Error("PasswordHash should not be present in JSON output")
	}

	// DeletedAt must not appear in JSON (json:"-")
	if _, exists := raw["deleted_at"]; exists {
		t.Error("DeletedAt should not be present in JSON output")
	}

	// Email should be omitted when nil (omitempty)
	if _, exists := raw["email"]; exists {
		t.Error("Email should be omitted when nil")
	}

	// Phone should be omitted when nil (omitempty)
	if _, exists := raw["phone"]; exists {
		t.Error("Phone should be omitted when nil")
	}

	// LastLoginAt should be omitted when nil (omitempty)
	if _, exists := raw["last_login_at"]; exists {
		t.Error("LastLoginAt should be omitted when nil")
	}

	// AvatarURL should be omitted when empty (omitempty)
	if _, exists := raw["avatar_url"]; exists {
		t.Error("AvatarURL should be omitted when empty string")
	}

	// Verify present fields
	if raw["username"] != "testuser" {
		t.Errorf("expected username 'testuser', got %v", raw["username"])
	}
	if raw["nickname"] != "Test" {
		t.Errorf("expected nickname 'Test', got %v", raw["nickname"])
	}
	if raw["role"] != "reader" {
		t.Errorf("expected role 'reader', got %v", raw["role"])
	}
	if raw["status"] != "active" {
		t.Errorf("expected status 'active', got %v", raw["status"])
	}

	// Round-trip: unmarshal back into User
	var decoded User
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("json.Unmarshal() into User error: %v", err)
	}
	if decoded.Username != user.Username {
		t.Errorf("round-trip username: expected %q, got %q", user.Username, decoded.Username)
	}
	if decoded.ID != user.ID {
		t.Errorf("round-trip ID: expected %s, got %s", user.ID, decoded.ID)
	}
	// PasswordHash should be zero value after round-trip (not in JSON)
	if decoded.PasswordHash != "" {
		t.Errorf("round-trip PasswordHash should be empty, got %q", decoded.PasswordHash)
	}
}

func TestUserJSONMarshalWithEmail(t *testing.T) {
	email := "test@example.com"
	phone := "+886912345678"
	loginTime := time.Now().Truncate(time.Second)
	user := User{
		ID:           uuid.MustParse("22222222-2222-2222-2222-222222222222"),
		Username:     "emailuser",
		Email:        &email,
		Phone:        &phone,
		PasswordHash: "should-not-appear",
		Nickname:     "EmailUser",
		AvatarURL:    "https://example.com/avatar.png",
		Bio:          "Hello world",
		Role:         "author",
		Status:       "active",
		LanguagePref: "zh-CN",
		LastLoginAt:  &loginTime,
		CreatedAt:    loginTime,
		UpdatedAt:    loginTime,
	}

	data, err := json.Marshal(user)
	if err != nil {
		t.Fatalf("json.Marshal() error: %v", err)
	}

	var raw map[string]interface{}
	if err := json.Unmarshal(data, &raw); err != nil {
		t.Fatalf("json.Unmarshal() error: %v", err)
	}

	// Email should be present when set
	if raw["email"] != email {
		t.Errorf("expected email %q, got %v", email, raw["email"])
	}

	// Phone should be present when set
	if raw["phone"] != phone {
		t.Errorf("expected phone %q, got %v", phone, raw["phone"])
	}

	// AvatarURL should be present when non-empty
	if raw["avatar_url"] != "https://example.com/avatar.png" {
		t.Errorf("expected avatar_url, got %v", raw["avatar_url"])
	}

	// Bio should be present when non-empty
	if raw["bio"] != "Hello world" {
		t.Errorf("expected bio 'Hello world', got %v", raw["bio"])
	}

	// LastLoginAt should be present when set
	if _, exists := raw["last_login_at"]; !exists {
		t.Error("last_login_at should be present when set")
	}

	// PasswordHash must still not appear
	if _, exists := raw["password_hash"]; exists {
		t.Error("PasswordHash should not be present in JSON output")
	}

	// Round-trip
	var decoded User
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("json.Unmarshal() into User error: %v", err)
	}
	if decoded.Email == nil || *decoded.Email != email {
		t.Errorf("round-trip email: expected %q, got %v", email, decoded.Email)
	}
	if decoded.Phone == nil || *decoded.Phone != phone {
		t.Errorf("round-trip phone: expected %q, got %v", phone, decoded.Phone)
	}
}

func TestUserDefaults(t *testing.T) {
	var user User

	// Zero-value struct should have sensible Go defaults
	if user.ID != uuid.Nil {
		t.Errorf("expected zero UUID, got %s", user.ID)
	}
	if user.Username != "" {
		t.Errorf("expected empty username, got %q", user.Username)
	}
	if user.Email != nil {
		t.Errorf("expected nil email, got %v", user.Email)
	}
	if user.Phone != nil {
		t.Errorf("expected nil phone, got %v", user.Phone)
	}
	if user.PasswordHash != "" {
		t.Errorf("expected empty password hash, got %q", user.PasswordHash)
	}
	if user.Nickname != "" {
		t.Errorf("expected empty nickname, got %q", user.Nickname)
	}
	if user.AvatarURL != "" {
		t.Errorf("expected empty avatar URL, got %q", user.AvatarURL)
	}
	if user.Bio != "" {
		t.Errorf("expected empty bio, got %q", user.Bio)
	}
	if user.Role != "" {
		t.Errorf("expected empty role (Go default), got %q", user.Role)
	}
	if user.Status != "" {
		t.Errorf("expected empty status (Go default), got %q", user.Status)
	}
	if user.LanguagePref != "" {
		t.Errorf("expected empty language_pref (Go default), got %q", user.LanguagePref)
	}
	if user.TotalReadWords != 0 {
		t.Errorf("expected 0 total_read_words, got %d", user.TotalReadWords)
	}
	if user.TotalReadSeconds != 0 {
		t.Errorf("expected 0 total_read_seconds, got %d", user.TotalReadSeconds)
	}
	if user.LastLoginAt != nil {
		t.Errorf("expected nil last_login_at, got %v", user.LastLoginAt)
	}
}
