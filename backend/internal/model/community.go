package model

import (
	"time"

	"github.com/google/uuid"
)

// Like target types.
const (
	LikeTargetReview  = "review"
	LikeTargetComment = "comment"
)

type Like struct {
	ID         uuid.UUID `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"id"`
	UserID     uuid.UUID `gorm:"type:uuid;not null;uniqueIndex:idx_likes_user_target" json:"user_id"`
	TargetType string    `gorm:"size:20;not null;uniqueIndex:idx_likes_user_target" json:"target_type"`
	TargetID   uuid.UUID `gorm:"type:uuid;not null;uniqueIndex:idx_likes_user_target" json:"target_id"`
	CreatedAt  time.Time `json:"created_at"`
}

// Report statuses.
const (
	ReportPending   = "pending"
	ReportResolved  = "resolved"
	ReportDismissed = "dismissed"
)

type Report struct {
	ID          uuid.UUID  `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"id"`
	ReporterID  uuid.UUID  `gorm:"type:uuid;not null" json:"reporter_id"`
	TargetType  string     `gorm:"size:20;not null" json:"target_type"`
	TargetID    uuid.UUID  `gorm:"type:uuid;not null" json:"target_id"`
	Reason      string     `gorm:"size:50;not null" json:"reason"`
	Description string     `gorm:"type:text" json:"description,omitempty"`
	Status      string     `gorm:"size:20;default:pending;index:idx_reports_status" json:"status"`
	ResolvedBy  *uuid.UUID `gorm:"type:uuid" json:"resolved_by,omitempty"`
	ResolvedAt  *time.Time `json:"resolved_at,omitempty"`
	CreatedAt   time.Time  `gorm:"index:idx_reports_status" json:"created_at"`
	Reporter    *UserBrief `gorm:"foreignKey:ReporterID" json:"reporter,omitempty"`
}

type Banner struct {
	ID        uuid.UUID  `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"id"`
	Title     string     `gorm:"size:200;not null" json:"title"`
	ImageURL  string     `gorm:"size:500;not null" json:"image_url"`
	LinkType  string     `gorm:"size:20" json:"link_type,omitempty"`
	LinkValue string     `gorm:"size:500" json:"link_value,omitempty"`
	SortOrder int        `gorm:"default:0" json:"sort_order"`
	IsActive  bool       `gorm:"default:true" json:"is_active"`
	StartAt   *time.Time `json:"start_at,omitempty"`
	EndAt     *time.Time `json:"end_at,omitempty"`
	CreatedAt time.Time  `json:"created_at"`
}
