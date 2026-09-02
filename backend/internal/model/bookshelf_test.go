package model

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestBookshelfItemJSONMarshal(t *testing.T) {
	now := time.Now().Truncate(time.Second)
	item := BookshelfItem{
		ID:         uuid.MustParse("11111111-1111-1111-1111-111111111111"),
		UserID:     uuid.MustParse("22222222-2222-2222-2222-222222222222"),
		NovelID:    uuid.MustParse("33333333-3333-3333-3333-333333333333"),
		GroupName:  "default",
		SortOrder:  0,
		IsNotified: true,
		AddedAt:    now,
	}

	data, err := json.Marshal(item)
	if err != nil {
		t.Fatalf("json.Marshal() error: %v", err)
	}

	var decoded BookshelfItem
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("json.Unmarshal() error: %v", err)
	}

	if decoded.ID != item.ID {
		t.Errorf("ID: expected %s, got %s", item.ID, decoded.ID)
	}
	if decoded.UserID != item.UserID {
		t.Errorf("UserID: expected %s, got %s", item.UserID, decoded.UserID)
	}
	if decoded.NovelID != item.NovelID {
		t.Errorf("NovelID: expected %s, got %s", item.NovelID, decoded.NovelID)
	}
	if decoded.GroupName != "default" {
		t.Errorf("GroupName: expected 'default', got %q", decoded.GroupName)
	}
	if decoded.SortOrder != 0 {
		t.Errorf("SortOrder: expected 0, got %d", decoded.SortOrder)
	}
	if decoded.IsNotified != true {
		t.Errorf("IsNotified: expected true, got %v", decoded.IsNotified)
	}

	// Verify JSON keys
	var raw map[string]interface{}
	if err := json.Unmarshal(data, &raw); err != nil {
		t.Fatalf("json.Unmarshal() to map error: %v", err)
	}
	for _, key := range []string{"id", "user_id", "novel_id", "group_name", "sort_order", "is_notified", "added_at"} {
		if _, exists := raw[key]; !exists {
			t.Errorf("expected JSON key %q to be present", key)
		}
	}
}

func TestReadingProgressJSONMarshal(t *testing.T) {
	now := time.Now().Truncate(time.Second)
	progress := ReadingProgress{
		ID:             uuid.MustParse("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"),
		UserID:         uuid.MustParse("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"),
		NovelID:        uuid.MustParse("cccccccc-cccc-cccc-cccc-cccccccccccc"),
		ChapterID:      uuid.MustParse("dddddddd-dddd-dddd-dddd-dddddddddddd"),
		ParagraphIndex: 5,
		ScrollOffset:   0.7532,
		ReadDuration:   3600,
		ReadAt:         now,
		SyncedAt:       now,
	}

	data, err := json.Marshal(progress)
	if err != nil {
		t.Fatalf("json.Marshal() error: %v", err)
	}

	var decoded ReadingProgress
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("json.Unmarshal() error: %v", err)
	}

	if decoded.ID != progress.ID {
		t.Errorf("ID: expected %s, got %s", progress.ID, decoded.ID)
	}
	if decoded.UserID != progress.UserID {
		t.Errorf("UserID: expected %s, got %s", progress.UserID, decoded.UserID)
	}
	if decoded.NovelID != progress.NovelID {
		t.Errorf("NovelID: expected %s, got %s", progress.NovelID, decoded.NovelID)
	}
	if decoded.ChapterID != progress.ChapterID {
		t.Errorf("ChapterID: expected %s, got %s", progress.ChapterID, decoded.ChapterID)
	}
	if decoded.ParagraphIndex != 5 {
		t.Errorf("ParagraphIndex: expected 5, got %d", decoded.ParagraphIndex)
	}
	if decoded.ScrollOffset != 0.7532 {
		t.Errorf("ScrollOffset: expected 0.7532, got %f", decoded.ScrollOffset)
	}
	if decoded.ReadDuration != 3600 {
		t.Errorf("ReadDuration: expected 3600, got %d", decoded.ReadDuration)
	}
}

func TestBookmarkJSONMarshal(t *testing.T) {
	now := time.Now().Truncate(time.Second)
	bookmark := Bookmark{
		ID:             uuid.MustParse("11111111-aaaa-1111-aaaa-111111111111"),
		UserID:         uuid.MustParse("22222222-bbbb-2222-bbbb-222222222222"),
		NovelID:        uuid.MustParse("33333333-cccc-3333-cccc-333333333333"),
		ChapterID:      uuid.MustParse("44444444-dddd-4444-dddd-444444444444"),
		ParagraphIndex: 10,
		Note:           "Important passage",
		CreatedAt:      now,
		SyncedAt:       now,
	}

	data, err := json.Marshal(bookmark)
	if err != nil {
		t.Fatalf("json.Marshal() error: %v", err)
	}

	var decoded Bookmark
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("json.Unmarshal() error: %v", err)
	}

	if decoded.ID != bookmark.ID {
		t.Errorf("ID: expected %s, got %s", bookmark.ID, decoded.ID)
	}
	if decoded.ParagraphIndex != 10 {
		t.Errorf("ParagraphIndex: expected 10, got %d", decoded.ParagraphIndex)
	}
	if decoded.Note != "Important passage" {
		t.Errorf("Note: expected 'Important passage', got %q", decoded.Note)
	}
}

func TestBookmarkJSONMarshalOmitNote(t *testing.T) {
	now := time.Now().Truncate(time.Second)
	bookmark := Bookmark{
		ID:        uuid.MustParse("55555555-aaaa-5555-aaaa-555555555555"),
		UserID:    uuid.MustParse("66666666-bbbb-6666-bbbb-666666666666"),
		NovelID:   uuid.MustParse("77777777-cccc-7777-cccc-777777777777"),
		ChapterID: uuid.MustParse("88888888-dddd-8888-dddd-888888888888"),
		CreatedAt: now,
		SyncedAt:  now,
	}

	data, err := json.Marshal(bookmark)
	if err != nil {
		t.Fatalf("json.Marshal() error: %v", err)
	}

	var raw map[string]interface{}
	if err := json.Unmarshal(data, &raw); err != nil {
		t.Fatalf("json.Unmarshal() error: %v", err)
	}

	if _, exists := raw["note"]; exists {
		t.Error("note should be omitted when empty (omitempty)")
	}
}

func TestReviewJSONMarshal(t *testing.T) {
	now := time.Now().Truncate(time.Second)
	review := Review{
		ID:        uuid.MustParse("aaaaaaaa-1111-aaaa-1111-aaaaaaaaaaaa"),
		UserID:    uuid.MustParse("bbbbbbbb-2222-bbbb-2222-bbbbbbbbbbbb"),
		NovelID:   uuid.MustParse("cccccccc-3333-cccc-3333-cccccccccccc"),
		Title:     "Great Novel",
		Content:   "This novel is amazing with rich world building.",
		Rating:    4.5,
		LikeCount: 25,
		Status:    "approved",
		CreatedAt: now,
		UpdatedAt: now,
	}

	data, err := json.Marshal(review)
	if err != nil {
		t.Fatalf("json.Marshal() error: %v", err)
	}

	var decoded Review
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("json.Unmarshal() error: %v", err)
	}

	if decoded.ID != review.ID {
		t.Errorf("ID: expected %s, got %s", review.ID, decoded.ID)
	}
	if decoded.Title != "Great Novel" {
		t.Errorf("Title: expected 'Great Novel', got %q", decoded.Title)
	}
	if decoded.Content != review.Content {
		t.Errorf("Content: expected %q, got %q", review.Content, decoded.Content)
	}
	if decoded.Rating != 4.5 {
		t.Errorf("Rating: expected 4.5, got %f", decoded.Rating)
	}
	if decoded.LikeCount != 25 {
		t.Errorf("LikeCount: expected 25, got %d", decoded.LikeCount)
	}
	if decoded.Status != "approved" {
		t.Errorf("Status: expected 'approved', got %q", decoded.Status)
	}

	// Verify JSON keys
	var raw map[string]interface{}
	if err := json.Unmarshal(data, &raw); err != nil {
		t.Fatalf("json.Unmarshal() to map error: %v", err)
	}
	for _, key := range []string{"id", "user_id", "novel_id", "title", "content", "rating", "like_count", "status", "created_at", "updated_at"} {
		if _, exists := raw[key]; !exists {
			t.Errorf("expected JSON key %q to be present", key)
		}
	}
}

func TestCommentJSONMarshal(t *testing.T) {
	now := time.Now().Truncate(time.Second)
	paraIdx := 3
	comment := Comment{
		ID:             uuid.MustParse("11112222-3333-4444-5555-666677778888"),
		UserID:         uuid.MustParse("aaaabbbb-cccc-dddd-eeee-ffff00001111"),
		ChapterID:      uuid.MustParse("22223333-4444-5555-6666-777788889999"),
		Content:        "This chapter was so exciting!",
		ParagraphIndex: &paraIdx,
		LikeCount:      5,
		Status:         "approved",
		CreatedAt:      now,
		UpdatedAt:      now,
	}

	data, err := json.Marshal(comment)
	if err != nil {
		t.Fatalf("json.Marshal() error: %v", err)
	}

	var decoded Comment
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("json.Unmarshal() error: %v", err)
	}

	if decoded.ID != comment.ID {
		t.Errorf("ID: expected %s, got %s", comment.ID, decoded.ID)
	}
	if decoded.UserID != comment.UserID {
		t.Errorf("UserID: expected %s, got %s", comment.UserID, decoded.UserID)
	}
	if decoded.ChapterID != comment.ChapterID {
		t.Errorf("ChapterID: expected %s, got %s", comment.ChapterID, decoded.ChapterID)
	}
	if decoded.Content != comment.Content {
		t.Errorf("Content: expected %q, got %q", comment.Content, decoded.Content)
	}
	if decoded.ParagraphIndex == nil || *decoded.ParagraphIndex != 3 {
		t.Errorf("ParagraphIndex: expected 3, got %v", decoded.ParagraphIndex)
	}
	if decoded.LikeCount != 5 {
		t.Errorf("LikeCount: expected 5, got %d", decoded.LikeCount)
	}
	if decoded.Status != "approved" {
		t.Errorf("Status: expected 'approved', got %q", decoded.Status)
	}
}

func TestCommentJSONMarshalOmitOptional(t *testing.T) {
	now := time.Now().Truncate(time.Second)
	comment := Comment{
		ID:        uuid.MustParse("99998888-7777-6666-5555-444433332222"),
		UserID:    uuid.MustParse("11110000-aaaa-bbbb-cccc-ddddeeee0000"),
		ChapterID: uuid.MustParse("ffffeeee-dddd-cccc-bbbb-aaaa00001111"),
		Content:   "Nice!",
		Status:    "approved",
		CreatedAt: now,
		UpdatedAt: now,
	}

	data, err := json.Marshal(comment)
	if err != nil {
		t.Fatalf("json.Marshal() error: %v", err)
	}

	var raw map[string]interface{}
	if err := json.Unmarshal(data, &raw); err != nil {
		t.Fatalf("json.Unmarshal() error: %v", err)
	}

	// ParentID and ParagraphIndex should be omitted when nil
	if _, exists := raw["parent_id"]; exists {
		t.Error("parent_id should be omitted when nil")
	}
	if _, exists := raw["paragraph_index"]; exists {
		t.Error("paragraph_index should be omitted when nil")
	}
}
