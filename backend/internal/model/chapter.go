package model

import (
	"time"
	"unicode"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type Volume struct {
	ID           uuid.UUID `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"id"`
	NovelID      uuid.UUID `gorm:"type:uuid;not null;index:idx_volumes_novel;uniqueIndex:idx_volumes_novel_number" json:"novel_id"`
	Title        string    `gorm:"size:200;not null" json:"title"`
	VolumeNumber int       `gorm:"not null;uniqueIndex:idx_volumes_novel_number" json:"volume_number"`
	SortOrder    int       `gorm:"not null" json:"sort_order"`
	CreatedAt    time.Time `json:"created_at"`
}

type Chapter struct {
	ID            uuid.UUID  `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"id"`
	NovelID       uuid.UUID  `gorm:"type:uuid;not null;index:idx_chapters_novel;uniqueIndex:idx_chapters_novel_number" json:"novel_id"`
	VolumeID      *uuid.UUID `gorm:"type:uuid" json:"volume_id,omitempty"`
	Title         string     `gorm:"size:200;not null" json:"title"`
	Content       string     `gorm:"type:text;not null" json:"content,omitempty"`
	ChapterNumber int        `gorm:"not null;uniqueIndex:idx_chapters_novel_number" json:"chapter_number"`
	WordCount     int        `gorm:"default:0" json:"word_count"`
	IsPublished   bool       `gorm:"default:false" json:"is_published"`
	IsFree        bool       `gorm:"default:true" json:"is_free"`
	PublishedAt   *time.Time `json:"published_at,omitempty"`
	CreatedAt     time.Time  `json:"created_at"`
	UpdatedAt     time.Time  `json:"updated_at"`
}

// ChapterRef identifies a neighbouring chapter for reader navigation.
type ChapterRef struct {
	ID            uuid.UUID `json:"id"`
	Title         string    `json:"title"`
	ChapterNumber int       `json:"chapter_number"`
}

// ChapterDetail is a chapter with links to the previous and next published chapters.
type ChapterDetail struct {
	Chapter
	PrevChapter *ChapterRef `json:"prev_chapter"`
	NextChapter *ChapterRef `json:"next_chapter"`
}

// BeforeSave keeps word_count in step with the content and stamps the
// first publication time. Chinese text has no
// spaces, so every non-whitespace character counts as one word.
func (c *Chapter) BeforeSave(*gorm.DB) error {
	if c.Content != "" {
		c.WordCount = CountWords(c.Content)
	}
	if c.IsPublished && c.PublishedAt == nil {
		now := time.Now()
		c.PublishedAt = &now
	}
	return nil
}

func CountWords(text string) int {
	n := 0
	for _, r := range text {
		if !unicode.IsSpace(r) {
			n++
		}
	}
	return n
}
