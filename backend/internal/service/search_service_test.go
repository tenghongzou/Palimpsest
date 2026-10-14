package service

import (
	"strings"
	"testing"
)

func TestConvertHitsEmpty(t *testing.T) {
	result := convertHits([]interface{}{})
	if len(result) != 0 {
		t.Errorf("expected empty result, got %d items", len(result))
	}
	if result == nil {
		t.Error("expected non-nil empty slice, got nil")
	}
}

func TestConvertHitsValid(t *testing.T) {
	hits := []interface{}{
		map[string]interface{}{
			"id":    "1",
			"title": "Novel One",
		},
		map[string]interface{}{
			"id":    "2",
			"title": "Novel Two",
		},
	}

	result := convertHits(hits)
	if len(result) != 2 {
		t.Fatalf("expected 2 results, got %d", len(result))
	}
	if result[0]["id"] != "1" {
		t.Errorf("result[0][\"id\"]: expected \"1\", got %v", result[0]["id"])
	}
	if result[0]["title"] != "Novel One" {
		t.Errorf("result[0][\"title\"]: expected \"Novel One\", got %v", result[0]["title"])
	}
	if result[1]["id"] != "2" {
		t.Errorf("result[1][\"id\"]: expected \"2\", got %v", result[1]["id"])
	}
	if result[1]["title"] != "Novel Two" {
		t.Errorf("result[1][\"title\"]: expected \"Novel Two\", got %v", result[1]["title"])
	}
}

func TestConvertHitsInvalid(t *testing.T) {
	hits := []interface{}{
		"not a map",
		42,
		true,
		nil,
	}

	result := convertHits(hits)
	if len(result) != 0 {
		t.Errorf("expected 0 results for all-invalid input, got %d", len(result))
	}
}

func TestConvertHitsMixed(t *testing.T) {
	hits := []interface{}{
		map[string]interface{}{"id": "1", "title": "Valid One"},
		"invalid string",
		map[string]interface{}{"id": "2", "title": "Valid Two"},
		123,
		nil,
		map[string]interface{}{"id": "3", "title": "Valid Three"},
	}

	result := convertHits(hits)
	if len(result) != 3 {
		t.Fatalf("expected 3 valid results, got %d", len(result))
	}
	if result[0]["id"] != "1" {
		t.Errorf("result[0][\"id\"]: expected \"1\", got %v", result[0]["id"])
	}
	if result[1]["id"] != "2" {
		t.Errorf("result[1][\"id\"]: expected \"2\", got %v", result[1]["id"])
	}
	if result[2]["id"] != "3" {
		t.Errorf("result[2][\"id\"]: expected \"3\", got %v", result[2]["id"])
	}
}

func TestConvertHitsNilInput(t *testing.T) {
	result := convertHits(nil)
	if len(result) != 0 {
		t.Errorf("expected empty result for nil input, got %d items", len(result))
	}
	if result == nil {
		t.Error("expected non-nil empty slice, got nil")
	}
}

func TestConvertHitsPreservesAllFields(t *testing.T) {
	hits := []interface{}{
		map[string]interface{}{
			"id":           "abc-123",
			"title":        "Test Novel",
			"author_name":  "Author",
			"view_count":   float64(1000),
			"is_published": true,
		},
	}

	result := convertHits(hits)
	if len(result) != 1 {
		t.Fatalf("expected 1 result, got %d", len(result))
	}

	m := result[0]
	if m["id"] != "abc-123" {
		t.Errorf("id: expected \"abc-123\", got %v", m["id"])
	}
	if m["title"] != "Test Novel" {
		t.Errorf("title: expected \"Test Novel\", got %v", m["title"])
	}
	if m["author_name"] != "Author" {
		t.Errorf("author_name: expected \"Author\", got %v", m["author_name"])
	}
	if m["view_count"] != float64(1000) {
		t.Errorf("view_count: expected 1000, got %v", m["view_count"])
	}
	if m["is_published"] != true {
		t.Errorf("is_published: expected true, got %v", m["is_published"])
	}
}

func TestBuildSearchFilterAlwaysPublishedOnly(t *testing.T) {
	if got := buildSearchFilter(nil); got != "is_published = true" {
		t.Errorf("expected published-only filter, got %q", got)
	}
}

func TestBuildSearchFilterAllowedValues(t *testing.T) {
	got := buildSearchFilter(map[string]string{"status": "completed", "language": "zh-CN"})
	want := `is_published = true AND status = "completed" AND language = "zh-CN"`
	if got != want {
		t.Errorf("expected %q, got %q", want, got)
	}
}

func TestBuildSearchFilterRejectsInjection(t *testing.T) {
	got := buildSearchFilter(map[string]string{
		"status":   `ongoing" OR is_published = false OR status = "x`,
		"language": "fr",
	})
	if got != "is_published = true" {
		t.Errorf("expected unknown filter values to be dropped, got %q", got)
	}
}

func TestNormalizeKeyword(t *testing.T) {
	cases := map[string]string{
		"  鬥破   蒼穹 ": "鬥破 蒼穹",
		"":             "",
		"   ":          "",
		strings.Repeat("字", maxKeywordLength+1): "",
	}
	for in, want := range cases {
		if got := normalizeKeyword(in); got != want {
			t.Errorf("normalizeKeyword(%q) = %q, want %q", in, got, want)
		}
	}
}
