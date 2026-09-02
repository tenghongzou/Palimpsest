package model

import (
	"encoding/json"
	"testing"
	"time"
)

func TestSearchKeywordJSONMarshal(t *testing.T) {
	now := time.Now().Truncate(time.Second)
	keyword := SearchKeyword{
		ID:          1,
		Keyword:     "martial arts",
		SearchCount: 9999,
		IsHot:       true,
		CreatedAt:   now,
		UpdatedAt:   now,
	}

	data, err := json.Marshal(keyword)
	if err != nil {
		t.Fatalf("json.Marshal() error: %v", err)
	}

	var decoded SearchKeyword
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("json.Unmarshal() error: %v", err)
	}

	if decoded.ID != 1 {
		t.Errorf("ID: expected 1, got %d", decoded.ID)
	}
	if decoded.Keyword != "martial arts" {
		t.Errorf("Keyword: expected 'martial arts', got %q", decoded.Keyword)
	}
	if decoded.SearchCount != 9999 {
		t.Errorf("SearchCount: expected 9999, got %d", decoded.SearchCount)
	}
	if decoded.IsHot != true {
		t.Errorf("IsHot: expected true, got %v", decoded.IsHot)
	}
	if decoded.CreatedAt.Unix() != now.Unix() {
		t.Errorf("CreatedAt: expected %v, got %v", now, decoded.CreatedAt)
	}
	if decoded.UpdatedAt.Unix() != now.Unix() {
		t.Errorf("UpdatedAt: expected %v, got %v", now, decoded.UpdatedAt)
	}

	// Verify JSON keys are correct
	var raw map[string]interface{}
	if err := json.Unmarshal(data, &raw); err != nil {
		t.Fatalf("json.Unmarshal() to map error: %v", err)
	}

	expectedKeys := []string{"id", "keyword", "search_count", "is_hot", "created_at", "updated_at"}
	for _, key := range expectedKeys {
		if _, exists := raw[key]; !exists {
			t.Errorf("expected JSON key %q to be present", key)
		}
	}
}

func TestSearchKeywordJSONMarshalNotHot(t *testing.T) {
	now := time.Now().Truncate(time.Second)
	keyword := SearchKeyword{
		ID:          2,
		Keyword:     "obscure term",
		SearchCount: 1,
		IsHot:       false,
		CreatedAt:   now,
		UpdatedAt:   now,
	}

	data, err := json.Marshal(keyword)
	if err != nil {
		t.Fatalf("json.Marshal() error: %v", err)
	}

	var decoded SearchKeyword
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("json.Unmarshal() error: %v", err)
	}

	if decoded.IsHot != false {
		t.Errorf("IsHot: expected false, got %v", decoded.IsHot)
	}
	if decoded.SearchCount != 1 {
		t.Errorf("SearchCount: expected 1, got %d", decoded.SearchCount)
	}
}
