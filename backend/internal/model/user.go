package model

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type User struct {
	ID            uuid.UUID      `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"id"`
	Username      string         `gorm:"size:50;uniqueIndex:idx_users_username;not null" json:"username"`
	Email         *string        `gorm:"size:255;uniqueIndex:idx_users_email" json:"email,omitempty"`
	Phone         *string        `gorm:"size:20;uniqueIndex:idx_users_phone" json:"phone,omitempty"`
	PasswordHash  string         `gorm:"size:255;not null" json:"-"`
	Nickname      string         `gorm:"size:50" json:"nickname"`
	AvatarURL     string         `gorm:"size:500" json:"avatar_url,omitempty"`
	Bio           string         `gorm:"type:text" json:"bio,omitempty"`
	Role          string         `gorm:"size:20;default:reader" json:"role"`
	Status        string         `gorm:"size:20;default:active" json:"status"`
	LanguagePref  string         `gorm:"size:10;default:zh-TW" json:"language_pref"`
	TotalReadWords   int64       `gorm:"default:0" json:"total_read_words"`
	TotalReadSeconds int64       `gorm:"default:0" json:"total_read_seconds"`
	LastLoginAt   *time.Time     `json:"last_login_at,omitempty"`
	CreatedAt     time.Time      `json:"created_at"`
	UpdatedAt     time.Time      `json:"updated_at"`
	DeletedAt     gorm.DeletedAt `gorm:"index" json:"-"`
}
