package model

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type Novel struct {
	ID                 uuid.UUID      `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"id"`
	Title              string         `gorm:"size:200;not null" json:"title"`
	AuthorName         string         `gorm:"size:100;not null;index:idx_novels_author" json:"author_name"`
	AuthorID           *uuid.UUID     `gorm:"type:uuid" json:"author_id,omitempty"`
	CoverURL           string         `gorm:"size:500" json:"cover_url,omitempty"`
	Description        string         `gorm:"type:text" json:"description,omitempty"`
	Status             string         `gorm:"size:20;default:ongoing" json:"status"`
	Language           string         `gorm:"size:10;default:zh-TW" json:"language"`
	TotalWords         int64          `gorm:"default:0" json:"total_words"`
	TotalChapters      int            `gorm:"default:0" json:"total_chapters"`
	ViewCount          int64          `gorm:"default:0" json:"view_count"`
	FavoriteCount      int            `gorm:"default:0" json:"favorite_count"`
	ReviewCount        int            `gorm:"default:0" json:"review_count"`
	AvgRating          float64        `gorm:"type:decimal(3,2);default:0" json:"avg_rating"`
	IsPublished        bool           `gorm:"default:false" json:"is_published"`
	IsFeatured         bool           `gorm:"default:false" json:"is_featured"`
	LatestChapterID    *uuid.UUID     `gorm:"type:uuid" json:"latest_chapter_id,omitempty"`
	LatestChapterTitle string         `gorm:"size:200" json:"latest_chapter_title,omitempty"`
	LatestChapterAt    *time.Time     `json:"latest_chapter_at,omitempty"`
	PublishedAt        *time.Time     `json:"published_at,omitempty"`
	CreatedAt          time.Time      `json:"created_at"`
	UpdatedAt          time.Time      `json:"updated_at"`
	DeletedAt          gorm.DeletedAt `gorm:"index" json:"-"`

	Categories []Category `gorm:"many2many:novel_categories" json:"categories,omitempty"`
	Tags       []Tag      `gorm:"many2many:novel_tags" json:"tags,omitempty"`
}

type Category struct {
	ID        int        `gorm:"primaryKey;autoIncrement" json:"id"`
	ParentID  *int       `json:"parent_id,omitempty"`
	Name      string     `gorm:"size:50;not null" json:"name"`
	Slug      string     `gorm:"size:50;uniqueIndex;not null" json:"slug"`
	IconURL   string     `gorm:"size:500" json:"icon_url,omitempty"`
	SortOrder int        `gorm:"default:0" json:"sort_order"`
	IsActive  bool       `gorm:"default:true" json:"is_active"`
	Children  []Category `gorm:"foreignKey:ParentID" json:"children,omitempty"`
	CreatedAt time.Time  `json:"created_at"`
	UpdatedAt time.Time  `json:"updated_at"`
}

type Tag struct {
	ID         int       `gorm:"primaryKey;autoIncrement" json:"id"`
	Name       string    `gorm:"size:30;uniqueIndex;not null" json:"name"`
	UsageCount int       `gorm:"default:0" json:"usage_count"`
	CreatedAt  time.Time `json:"created_at"`
}
