package model

import (
	"time"

	"github.com/google/uuid"
)

type BookshelfItem struct {
	ID         uuid.UUID `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"id"`
	UserID     uuid.UUID `gorm:"type:uuid;not null;uniqueIndex:idx_user_novel" json:"user_id"`
	NovelID    uuid.UUID `gorm:"type:uuid;not null;uniqueIndex:idx_user_novel" json:"novel_id"`
	GroupName  string    `gorm:"size:50;default:default" json:"group_name"`
	SortOrder  int       `gorm:"default:0" json:"sort_order"`
	IsNotified bool      `gorm:"default:true" json:"is_notified"`
	AddedAt    time.Time `gorm:"default:now()" json:"added_at"`
	Novel      Novel     `gorm:"foreignKey:NovelID" json:"novel,omitempty"`
}

type ReadingProgress struct {
	ID             uuid.UUID `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"id"`
	UserID         uuid.UUID `gorm:"type:uuid;not null;uniqueIndex:idx_user_novel_progress" json:"user_id"`
	NovelID        uuid.UUID `gorm:"type:uuid;not null;uniqueIndex:idx_user_novel_progress" json:"novel_id"`
	ChapterID      uuid.UUID `gorm:"type:uuid;not null" json:"chapter_id"`
	ParagraphIndex int       `gorm:"default:0" json:"paragraph_index"`
	ScrollOffset   float64   `gorm:"type:decimal(5,4);default:0" json:"scroll_offset"`
	ReadDuration   int       `gorm:"default:0" json:"read_duration"`
	ReadAt         time.Time `gorm:"default:now()" json:"read_at"`
	SyncedAt       time.Time `gorm:"default:now()" json:"synced_at"`
}

type Bookmark struct {
	ID             uuid.UUID `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"id"`
	UserID         uuid.UUID `gorm:"type:uuid;not null" json:"user_id"`
	NovelID        uuid.UUID `gorm:"type:uuid;not null" json:"novel_id"`
	ChapterID      uuid.UUID `gorm:"type:uuid;not null" json:"chapter_id"`
	ParagraphIndex int       `gorm:"default:0" json:"paragraph_index"`
	Note           string    `gorm:"size:500" json:"note,omitempty"`
	CreatedAt      time.Time `json:"created_at"`
	SyncedAt       time.Time `json:"synced_at"`
}

type Review struct {
	ID        uuid.UUID `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"id"`
	UserID    uuid.UUID `gorm:"type:uuid;not null;uniqueIndex:idx_user_novel_review" json:"user_id"`
	NovelID   uuid.UUID `gorm:"type:uuid;not null;uniqueIndex:idx_user_novel_review" json:"novel_id"`
	Title     string    `gorm:"size:200;not null" json:"title"`
	Content   string    `gorm:"type:text;not null" json:"content"`
	Rating    float64   `gorm:"type:decimal(2,1);not null" json:"rating"`
	LikeCount int       `gorm:"default:0" json:"like_count"`
	Status    string    `gorm:"size:20;default:approved" json:"status"`
	User      User      `gorm:"foreignKey:UserID" json:"user,omitempty"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

type Comment struct {
	ID             uuid.UUID `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"id"`
	UserID         uuid.UUID `gorm:"type:uuid;not null" json:"user_id"`
	ChapterID      uuid.UUID `gorm:"type:uuid;not null" json:"chapter_id"`
	ParentID       *uuid.UUID `gorm:"type:uuid" json:"parent_id,omitempty"`
	Content        string    `gorm:"type:text;not null" json:"content"`
	ParagraphIndex *int      `json:"paragraph_index,omitempty"`
	LikeCount      int       `gorm:"default:0" json:"like_count"`
	Status         string    `gorm:"size:20;default:approved" json:"status"`
	User           User      `gorm:"foreignKey:UserID" json:"user,omitempty"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
}
