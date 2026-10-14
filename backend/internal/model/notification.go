package model

import (
	"time"

	"github.com/google/uuid"
)

// Notification types.
const (
	NotificationChapterUpdate = "chapter_update"
	NotificationCommentReply  = "comment_reply"
	NotificationSystem        = "system"
)

// Notification is an in-app message for one user. The optional ids point
// at what it is about so clients can link to it.
type Notification struct {
	ID        uuid.UUID  `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"id"`
	UserID    uuid.UUID  `gorm:"type:uuid;not null;index:idx_notifications_user,priority:1;index:idx_notifications_unread,where:read_at IS NULL" json:"-"`
	Type      string     `gorm:"size:30;not null" json:"type"`
	Title     string     `gorm:"size:200;not null" json:"title"`
	Body      string     `gorm:"type:text" json:"body,omitempty"`
	NovelID   *uuid.UUID `gorm:"type:uuid" json:"novel_id,omitempty"`
	ChapterID *uuid.UUID `gorm:"type:uuid" json:"chapter_id,omitempty"`
	CommentID *uuid.UUID `gorm:"type:uuid" json:"comment_id,omitempty"`
	// Params lets clients write the title and body in their UI language;
	// Title and Body hold the zh-TW text as a fallback.
	Params    NotificationParams `gorm:"type:jsonb;serializer:json" json:"params,omitempty"`
	ActorID   *uuid.UUID         `gorm:"type:uuid" json:"-"`
	ReadAt    *time.Time         `json:"read_at"`
	CreatedAt time.Time          `gorm:"index:idx_notifications_user,priority:2,sort:desc" json:"created_at"`
	Actor     *UserBrief         `gorm:"foreignKey:ActorID" json:"actor,omitempty"`
}

// NotificationParams are the values a notification's text is built from:
//   - chapter_update: novel, chapter (title of the latest chapter), chapter_number
//   - comment_reply: actor (display name)
type NotificationParams map[string]string

// Device types a client may register as.
var DeviceTypes = []string{"web", "android", "ios", "windows", "macos", "linux"}

// UserDevice is a client installation signed in as the user. PushToken is
// the platform push token when the client has one.
type UserDevice struct {
	ID           uuid.UUID `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"id"`
	UserID       uuid.UUID `gorm:"type:uuid;not null;index:idx_user_devices_user;uniqueIndex:idx_user_devices_device" json:"-"`
	DeviceType   string    `gorm:"size:20;not null" json:"device_type"`
	DeviceName   string    `gorm:"size:100" json:"device_name,omitempty"`
	DeviceID     string    `gorm:"size:255;not null;uniqueIndex:idx_user_devices_device" json:"device_id"`
	PushToken    string    `gorm:"size:500" json:"-"`
	LastActiveAt time.Time `gorm:"default:now()" json:"last_active_at"`
	CreatedAt    time.Time `json:"created_at"`
}
