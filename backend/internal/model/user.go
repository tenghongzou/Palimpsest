package model

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type User struct {
	ID               uuid.UUID  `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"id"`
	Username         string     `gorm:"size:50;uniqueIndex:idx_users_username;not null" json:"username"`
	Email            *string    `gorm:"size:255;uniqueIndex:idx_users_email" json:"email,omitempty"`
	Phone            *string    `gorm:"size:20;uniqueIndex:idx_users_phone" json:"phone,omitempty"`
	PasswordHash     string     `gorm:"size:255;not null" json:"-"`
	Nickname         string     `gorm:"size:50" json:"nickname"`
	AvatarURL        string     `gorm:"size:500" json:"avatar_url,omitempty"`
	Bio              string     `gorm:"type:text" json:"bio,omitempty"`
	Role             string     `gorm:"size:20;default:reader" json:"role"`
	Status           string     `gorm:"size:20;default:active" json:"status"`
	LanguagePref     string     `gorm:"size:10;default:zh-TW" json:"language_pref"`
	TotalReadWords   int64      `gorm:"default:0" json:"total_read_words"`
	TotalReadSeconds int64      `gorm:"default:0" json:"total_read_seconds"`
	LastLoginAt      *time.Time `json:"last_login_at,omitempty"`
	// PasswordChangedAt invalidates reset and refresh tokens issued before it.
	PasswordChangedAt *time.Time     `json:"-"`
	CreatedAt         time.Time      `json:"created_at"`
	UpdatedAt         time.Time      `json:"updated_at"`
	DeletedAt         gorm.DeletedAt `gorm:"index" json:"-"`
}

// ReadingSettings are a user's reader preferences, synced across devices.
// The booleans have no column default: GORM skips zero values that have one,
// so false could never be saved.
type ReadingSettings struct {
	ID            uuid.UUID `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"-"`
	UserID        uuid.UUID `gorm:"type:uuid;uniqueIndex;not null" json:"-"`
	FontSize      int       `gorm:"default:18" json:"font_size" binding:"min=12,max=36"`
	LineHeight    float64   `gorm:"type:decimal(3,1);default:1.8" json:"line_height" binding:"min=1.2,max=3"`
	LetterSpacing float64   `gorm:"type:decimal(3,1);default:0" json:"letter_spacing" binding:"min=0,max=5"`
	Margin        int       `gorm:"default:16" json:"margin" binding:"min=0,max=64"`
	FontFamily    string    `gorm:"size:50;default:system" json:"font_family" binding:"max=50"`
	Theme         string    `gorm:"size:20;default:white" json:"theme" binding:"oneof=white sepia green dark black"`
	ReadingMode   string    `gorm:"size:20;default:scroll" json:"reading_mode" binding:"oneof=scroll page"`
	Brightness    int       `gorm:"default:100" json:"brightness" binding:"min=10,max=100"`
	KeepScreenOn  bool      `gorm:"not null" json:"keep_screen_on"`
	AutoChapter   bool      `gorm:"not null" json:"auto_chapter"`
	CreatedAt     time.Time `json:"-"`
	UpdatedAt     time.Time `json:"updated_at"`
}

func (ReadingSettings) TableName() string { return "user_reading_settings" }

// DefaultReadingSettings matches the column defaults.
func DefaultReadingSettings(userID uuid.UUID) ReadingSettings {
	return ReadingSettings{
		UserID: userID, FontSize: 18, LineHeight: 1.8, Margin: 16, FontFamily: "system",
		Theme: "white", ReadingMode: "scroll", Brightness: 100, KeepScreenOn: true, AutoChapter: true,
	}
}

// UserBrief is the public face of a user shown next to reviews and comments.
type UserBrief struct {
	ID        uuid.UUID `gorm:"type:uuid;primaryKey" json:"id"`
	Username  string    `json:"username"`
	Nickname  string    `json:"nickname"`
	AvatarURL string    `json:"avatar_url,omitempty"`
}

func (UserBrief) TableName() string { return "users" }
