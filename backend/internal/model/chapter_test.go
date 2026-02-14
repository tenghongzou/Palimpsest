package model

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestChapterJSONMarshal(t *testing.T) {
	now := time.Now().Truncate(time.Second)
	volumeID := uuid.MustParse("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
	publishedAt := now

	chapter := Chapter{
		ID:            uuid.MustParse("11111111-1111-1111-1111-111111111111"),
		NovelID:       uuid.MustParse("22222222-2222-2222-2222-222222222222"),
		VolumeID:      &volumeID,
		Title:         "The Beginning",
		Content:       "Once upon a time in a land far away...",
		ChapterNumber: 1,
		WordCount:     500,
		IsPublished:   true,
		IsFree:        true,
		PublishedAt:   &publishedAt,
		CreatedAt:     now,
		UpdatedAt:     now,
	}

	data, err := json.Marshal(chapter)
	if err != nil {
		t.Fatalf("json.Marshal() error: %v", err)
	}

	var decoded Chapter
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("json.Unmarshal() error: %v", err)
	}

	if decoded.ID != chapter.ID {
		t.Errorf("ID: expected %s, got %s", chapter.ID, decoded.ID)
	}
	if decoded.NovelID != chapter.NovelID {
		t.Errorf("NovelID: expected %s, got %s", chapter.NovelID, decoded.NovelID)
	}
	if decoded.VolumeID == nil || *decoded.VolumeID != volumeID {
		t.Errorf("VolumeID: expected %s, got %v", volumeID, decoded.VolumeID)
	}
	if decoded.Title != "The Beginning" {
		t.Errorf("Title: expected 'The Beginning', got %q", decoded.Title)
	}
	if decoded.Content != chapter.Content {
		t.Errorf("Content: expected %q, got %q", chapter.Content, decoded.Content)
	}
	if decoded.ChapterNumber != 1 {
		t.Errorf("ChapterNumber: expected 1, got %d", decoded.ChapterNumber)
	}
	if decoded.WordCount != 500 {
		t.Errorf("WordCount: expected 500, got %d", decoded.WordCount)
	}
	if decoded.IsPublished != true {
		t.Errorf("IsPublished: expected true, got %v", decoded.IsPublished)
	}
	if decoded.IsFree != true {
		t.Errorf("IsFree: expected true, got %v", decoded.IsFree)
	}
	if decoded.PublishedAt == nil {
		t.Error("PublishedAt should not be nil")
	}
}

func TestChapterJSONMarshalOmitEmpty(t *testing.T) {
	now := time.Now().Truncate(time.Second)
	chapter := Chapter{
		ID:            uuid.MustParse("33333333-3333-3333-3333-333333333333"),
		NovelID:       uuid.MustParse("44444444-4444-4444-4444-444444444444"),
		Title:         "Minimal Chapter",
		Content:       "Content here",
		ChapterNumber: 1,
		CreatedAt:     now,
		UpdatedAt:     now,
	}

	data, err := json.Marshal(chapter)
	if err != nil {
		t.Fatalf("json.Marshal() error: %v", err)
	}

	var raw map[string]interface{}
	if err := json.Unmarshal(data, &raw); err != nil {
		t.Fatalf("json.Unmarshal() error: %v", err)
	}

	// VolumeID and PublishedAt should be omitted when nil
	if _, exists := raw["volume_id"]; exists {
		t.Error("volume_id should be omitted when nil")
	}
	if _, exists := raw["published_at"]; exists {
		t.Error("published_at should be omitted when nil")
	}
}

func TestVolumeJSONMarshal(t *testing.T) {
	now := time.Now().Truncate(time.Second)
	volume := Volume{
		ID:           uuid.MustParse("55555555-5555-5555-5555-555555555555"),
		NovelID:      uuid.MustParse("66666666-6666-6666-6666-666666666666"),
		Title:        "Volume One",
		VolumeNumber: 1,
		SortOrder:    1,
		CreatedAt:    now,
	}

	data, err := json.Marshal(volume)
	if err != nil {
		t.Fatalf("json.Marshal() error: %v", err)
	}

	var decoded Volume
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("json.Unmarshal() error: %v", err)
	}

	if decoded.ID != volume.ID {
		t.Errorf("ID: expected %s, got %s", volume.ID, decoded.ID)
	}
	if decoded.NovelID != volume.NovelID {
		t.Errorf("NovelID: expected %s, got %s", volume.NovelID, decoded.NovelID)
	}
	if decoded.Title != "Volume One" {
		t.Errorf("Title: expected 'Volume One', got %q", decoded.Title)
	}
	if decoded.VolumeNumber != 1 {
		t.Errorf("VolumeNumber: expected 1, got %d", decoded.VolumeNumber)
	}
	if decoded.SortOrder != 1 {
		t.Errorf("SortOrder: expected 1, got %d", decoded.SortOrder)
	}
	if decoded.CreatedAt.Unix() != now.Unix() {
		t.Errorf("CreatedAt: expected %v, got %v", now, decoded.CreatedAt)
	}
}
