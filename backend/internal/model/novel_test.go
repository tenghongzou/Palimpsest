package model

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestNovelJSONMarshal(t *testing.T) {
	now := time.Now().Truncate(time.Second)
	authorID := uuid.MustParse("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
	latestChapterID := uuid.MustParse("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")

	novel := Novel{
		ID:                 uuid.MustParse("cccccccc-cccc-cccc-cccc-cccccccccccc"),
		Title:              "Test Novel",
		AuthorName:         "Author One",
		AuthorID:           &authorID,
		CoverURL:           "https://example.com/cover.jpg",
		Description:        "A test novel description",
		Status:             "ongoing",
		Language:           "zh-TW",
		TotalWords:         50000,
		TotalChapters:      25,
		ViewCount:          1000,
		FavoriteCount:      50,
		ReviewCount:        10,
		AvgRating:          4.5,
		IsPublished:        true,
		IsFeatured:         false,
		LatestChapterID:    &latestChapterID,
		LatestChapterTitle: "Chapter 25",
		LatestChapterAt:    &now,
		PublishedAt:        &now,
		CreatedAt:          now,
		UpdatedAt:          now,
	}

	data, err := json.Marshal(novel)
	if err != nil {
		t.Fatalf("json.Marshal() error: %v", err)
	}

	var decoded Novel
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("json.Unmarshal() error: %v", err)
	}

	if decoded.ID != novel.ID {
		t.Errorf("ID: expected %s, got %s", novel.ID, decoded.ID)
	}
	if decoded.Title != novel.Title {
		t.Errorf("Title: expected %q, got %q", novel.Title, decoded.Title)
	}
	if decoded.AuthorName != novel.AuthorName {
		t.Errorf("AuthorName: expected %q, got %q", novel.AuthorName, decoded.AuthorName)
	}
	if decoded.AuthorID == nil || *decoded.AuthorID != authorID {
		t.Errorf("AuthorID: expected %s, got %v", authorID, decoded.AuthorID)
	}
	if decoded.Status != "ongoing" {
		t.Errorf("Status: expected 'ongoing', got %q", decoded.Status)
	}
	if decoded.Language != "zh-TW" {
		t.Errorf("Language: expected 'zh-TW', got %q", decoded.Language)
	}
	if decoded.TotalWords != 50000 {
		t.Errorf("TotalWords: expected 50000, got %d", decoded.TotalWords)
	}
	if decoded.TotalChapters != 25 {
		t.Errorf("TotalChapters: expected 25, got %d", decoded.TotalChapters)
	}
	if decoded.ViewCount != 1000 {
		t.Errorf("ViewCount: expected 1000, got %d", decoded.ViewCount)
	}
	if decoded.AvgRating != 4.5 {
		t.Errorf("AvgRating: expected 4.5, got %f", decoded.AvgRating)
	}
	if decoded.IsPublished != true {
		t.Errorf("IsPublished: expected true, got %v", decoded.IsPublished)
	}
	if decoded.IsFeatured != false {
		t.Errorf("IsFeatured: expected false, got %v", decoded.IsFeatured)
	}
	if decoded.LatestChapterID == nil || *decoded.LatestChapterID != latestChapterID {
		t.Errorf("LatestChapterID: expected %s, got %v", latestChapterID, decoded.LatestChapterID)
	}
	if decoded.LatestChapterTitle != "Chapter 25" {
		t.Errorf("LatestChapterTitle: expected 'Chapter 25', got %q", decoded.LatestChapterTitle)
	}

	// Verify omitempty: DeletedAt should not appear
	var raw map[string]interface{}
	if err := json.Unmarshal(data, &raw); err != nil {
		t.Fatalf("json.Unmarshal() to map error: %v", err)
	}
	if _, exists := raw["deleted_at"]; exists {
		t.Error("DeletedAt should not appear in JSON output")
	}
}

func TestNovelJSONMarshalOmitEmpty(t *testing.T) {
	novel := Novel{
		ID:         uuid.MustParse("dddddddd-dddd-dddd-dddd-dddddddddddd"),
		Title:      "Minimal Novel",
		AuthorName: "Author",
		Status:     "ongoing",
		Language:   "zh-TW",
		CreatedAt:  time.Now().Truncate(time.Second),
		UpdatedAt:  time.Now().Truncate(time.Second),
	}

	data, err := json.Marshal(novel)
	if err != nil {
		t.Fatalf("json.Marshal() error: %v", err)
	}

	var raw map[string]interface{}
	if err := json.Unmarshal(data, &raw); err != nil {
		t.Fatalf("json.Unmarshal() error: %v", err)
	}

	// Optional fields with omitempty should be absent when nil/empty
	for _, field := range []string{"author_id", "cover_url", "description", "latest_chapter_id", "latest_chapter_title", "latest_chapter_at", "published_at", "categories", "tags"} {
		if _, exists := raw[field]; exists {
			t.Errorf("field %q should be omitted when zero/nil/empty", field)
		}
	}
}

func TestCategoryJSONMarshal(t *testing.T) {
	now := time.Now().Truncate(time.Second)
	cat := Category{
		ID:        1,
		Name:      "Fantasy",
		Slug:      "fantasy",
		IconURL:   "https://example.com/fantasy.png",
		SortOrder: 1,
		IsActive:  true,
		CreatedAt: now,
		UpdatedAt: now,
	}

	data, err := json.Marshal(cat)
	if err != nil {
		t.Fatalf("json.Marshal() error: %v", err)
	}

	var decoded Category
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("json.Unmarshal() error: %v", err)
	}

	if decoded.ID != 1 {
		t.Errorf("ID: expected 1, got %d", decoded.ID)
	}
	if decoded.Name != "Fantasy" {
		t.Errorf("Name: expected 'Fantasy', got %q", decoded.Name)
	}
	if decoded.Slug != "fantasy" {
		t.Errorf("Slug: expected 'fantasy', got %q", decoded.Slug)
	}
	if decoded.SortOrder != 1 {
		t.Errorf("SortOrder: expected 1, got %d", decoded.SortOrder)
	}
	if decoded.IsActive != true {
		t.Errorf("IsActive: expected true, got %v", decoded.IsActive)
	}

	// ParentID should be omitted when nil
	var raw map[string]interface{}
	if err := json.Unmarshal(data, &raw); err != nil {
		t.Fatalf("json.Unmarshal() to map error: %v", err)
	}
	if _, exists := raw["parent_id"]; exists {
		t.Error("parent_id should be omitted when nil")
	}
	if _, exists := raw["children"]; exists {
		t.Error("children should be omitted when nil")
	}
}

func TestCategoryJSONMarshalWithParent(t *testing.T) {
	now := time.Now().Truncate(time.Second)
	parentID := 10
	cat := Category{
		ID:        2,
		ParentID:  &parentID,
		Name:      "Wuxia",
		Slug:      "wuxia",
		SortOrder: 2,
		IsActive:  true,
		CreatedAt: now,
		UpdatedAt: now,
	}

	data, err := json.Marshal(cat)
	if err != nil {
		t.Fatalf("json.Marshal() error: %v", err)
	}

	var decoded Category
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("json.Unmarshal() error: %v", err)
	}

	if decoded.ParentID == nil {
		t.Fatal("ParentID should not be nil")
	}
	if *decoded.ParentID != parentID {
		t.Errorf("ParentID: expected %d, got %d", parentID, *decoded.ParentID)
	}
}

func TestTagJSONMarshal(t *testing.T) {
	now := time.Now().Truncate(time.Second)
	tag := Tag{
		ID:         1,
		Name:       "martial-arts",
		UsageCount: 42,
		CreatedAt:  now,
	}

	data, err := json.Marshal(tag)
	if err != nil {
		t.Fatalf("json.Marshal() error: %v", err)
	}

	var decoded Tag
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("json.Unmarshal() error: %v", err)
	}

	if decoded.ID != 1 {
		t.Errorf("ID: expected 1, got %d", decoded.ID)
	}
	if decoded.Name != "martial-arts" {
		t.Errorf("Name: expected 'martial-arts', got %q", decoded.Name)
	}
	if decoded.UsageCount != 42 {
		t.Errorf("UsageCount: expected 42, got %d", decoded.UsageCount)
	}

	// Verify round-trip preserves CreatedAt
	if decoded.CreatedAt.Unix() != now.Unix() {
		t.Errorf("CreatedAt: expected %v, got %v", now, decoded.CreatedAt)
	}
}
