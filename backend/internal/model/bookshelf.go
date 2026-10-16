package model

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type BookshelfItem struct {
	ID         uuid.UUID `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"id"`
	UserID     uuid.UUID `gorm:"type:uuid;not null;uniqueIndex:idx_user_novel" json:"user_id"`
	NovelID    uuid.UUID `gorm:"type:uuid;not null;uniqueIndex:idx_user_novel" json:"novel_id"`
	GroupName  string    `gorm:"size:50;default:default" json:"group_name"`
	SortOrder  int       `gorm:"default:0" json:"sort_order"`
	IsNotified bool      `gorm:"default:true" json:"is_notified"`
	AddedAt    time.Time `gorm:"default:now();index:idx_bookshelf_items_added_at" json:"added_at"`
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
	ID             uuid.UUID   `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"id"`
	UserID         uuid.UUID   `gorm:"type:uuid;not null" json:"user_id"`
	NovelID        uuid.UUID   `gorm:"type:uuid;not null" json:"novel_id"`
	ChapterID      uuid.UUID   `gorm:"type:uuid;not null" json:"chapter_id"`
	ParagraphIndex int         `gorm:"default:0" json:"paragraph_index"`
	Note           string      `gorm:"size:500" json:"note,omitempty"`
	CreatedAt      time.Time   `json:"created_at"`
	SyncedAt       time.Time   `json:"synced_at"`
	Chapter        *Chapter    `gorm:"foreignKey:ChapterID" json:"chapter,omitempty"`
	Novel          *NovelBrief `gorm:"foreignKey:NovelID" json:"novel,omitempty"`
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
	// Moderation is what automated moderation found; only admins see it.
	Moderation *ModerationResult `gorm:"type:jsonb;serializer:json" json:"moderation,omitempty"`
	User       *UserBrief        `gorm:"foreignKey:UserID" json:"user,omitempty"`
	Novel      *NovelBrief       `gorm:"foreignKey:NovelID" json:"novel,omitempty"`
	LikedByMe  bool              `gorm:"-" json:"liked_by_me"`
	CreatedAt  time.Time         `gorm:"index:idx_reviews_created_at;index:idx_reviews_pending,where:status = 'pending'" json:"created_at"`
	UpdatedAt  time.Time         `json:"updated_at"`
}

type Comment struct {
	ID             uuid.UUID  `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"id"`
	UserID         uuid.UUID  `gorm:"type:uuid;not null" json:"user_id"`
	ChapterID      uuid.UUID  `gorm:"type:uuid;not null" json:"chapter_id"`
	ParentID       *uuid.UUID `gorm:"type:uuid" json:"parent_id,omitempty"`
	Content        string     `gorm:"type:text;not null" json:"content"`
	ParagraphIndex *int       `json:"paragraph_index,omitempty"`
	LikeCount      int        `gorm:"default:0" json:"like_count"`
	Status         string     `gorm:"size:20;default:approved" json:"status"`
	// Moderation is what automated moderation found; only admins see it.
	Moderation *ModerationResult `gorm:"type:jsonb;serializer:json" json:"moderation,omitempty"`
	User       *UserBrief        `gorm:"foreignKey:UserID" json:"user,omitempty"`
	LikedByMe  bool              `gorm:"-" json:"liked_by_me"`
	CreatedAt  time.Time         `gorm:"index:idx_comments_created_at;index:idx_comments_pending,where:status = 'pending'" json:"created_at"`
	UpdatedAt  time.Time         `json:"updated_at"`
	DeletedAt  gorm.DeletedAt    `gorm:"index" json:"-"`
	Replies    []Comment         `gorm:"foreignKey:ParentID" json:"replies,omitempty"`
}

// ReadingHistory records each chapter a user opened, for history and stats.
type ReadingHistory struct {
	ID        uuid.UUID `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"id"`
	UserID    uuid.UUID `gorm:"type:uuid;not null;index:idx_reading_history_user" json:"-"`
	NovelID   uuid.UUID `gorm:"type:uuid;not null" json:"novel_id"`
	ChapterID uuid.UUID `gorm:"type:uuid;not null" json:"chapter_id"`
	ReadAt    time.Time `gorm:"index:idx_reading_history_user,sort:desc;index:idx_reading_history_read_at" json:"read_at"`
	Duration  int       `gorm:"default:0" json:"duration"`
	Novel     *Novel    `gorm:"foreignKey:NovelID" json:"novel,omitempty"`
	Chapter   *Chapter  `gorm:"foreignKey:ChapterID" json:"chapter,omitempty"`
}

func (ReadingHistory) TableName() string { return "reading_history" }
