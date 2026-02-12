package model

import (
	"time"

	"github.com/google/uuid"
)

type Volume struct {
	ID           uuid.UUID `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"id"`
	NovelID      uuid.UUID `gorm:"type:uuid;not null;index:idx_volumes_novel" json:"novel_id"`
	Title        string    `gorm:"size:200;not null" json:"title"`
	VolumeNumber int       `gorm:"not null;uniqueIndex:idx_novel_volume" json:"volume_number"`
	SortOrder    int       `gorm:"not null" json:"sort_order"`
	CreatedAt    time.Time `json:"created_at"`
}

type Chapter struct {
	ID            uuid.UUID  `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"id"`
	NovelID       uuid.UUID  `gorm:"type:uuid;not null;index:idx_chapters_novel" json:"novel_id"`
	VolumeID      *uuid.UUID `gorm:"type:uuid" json:"volume_id,omitempty"`
	Title         string     `gorm:"size:200;not null" json:"title"`
	Content       string     `gorm:"type:text;not null" json:"content"`
	ChapterNumber int        `gorm:"not null;uniqueIndex:idx_novel_chapter" json:"chapter_number"`
	WordCount     int        `gorm:"default:0" json:"word_count"`
	IsPublished   bool       `gorm:"default:false" json:"is_published"`
	IsFree        bool       `gorm:"default:true" json:"is_free"`
	PublishedAt   *time.Time `json:"published_at,omitempty"`
	CreatedAt     time.Time  `json:"created_at"`
	UpdatedAt     time.Time  `json:"updated_at"`
}
