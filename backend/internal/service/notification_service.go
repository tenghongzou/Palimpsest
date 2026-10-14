package service

import (
	"time"
	"unicode/utf8"

	"github.com/google/uuid"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// maxDevicesPerUser bounds a user's device list; registering more drops the
// least recently active ones.
const maxDevicesPerUser = 20

type NotificationService struct {
	db *gorm.DB
}

func NewNotificationService(db *gorm.DB) *NotificationService {
	return &NotificationService{db: db}
}

// List returns a page of the user's notifications, newest first.
func (s *NotificationService) List(userID uuid.UUID, unreadOnly bool, page, pageSize int) ([]model.Notification, int64, error) {
	items := []model.Notification{}
	var total int64
	q := s.db.Model(&model.Notification{}).Where("user_id = ?", userID)
	if unreadOnly {
		q = q.Where("read_at IS NULL")
	}
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	err := q.Preload("Actor").Order("created_at DESC, id").Offset(offset(page, pageSize)).Limit(pageSize).Find(&items).Error
	return items, total, err
}

func (s *NotificationService) UnreadCount(userID uuid.UUID) (int64, error) {
	var n int64
	err := s.db.Model(&model.Notification{}).Where("user_id = ? AND read_at IS NULL", userID).Count(&n).Error
	return n, err
}

// MarkRead marks one notification read; marking it again is harmless.
func (s *NotificationService) MarkRead(userID, id uuid.UUID) error {
	res := s.db.Model(&model.Notification{}).Where("id = ? AND user_id = ?", id, userID).
		Update("read_at", gorm.Expr("COALESCE(read_at, NOW())"))
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return ErrNotFound
	}
	return nil
}

// MarkAllRead marks every unread notification read and returns how many.
func (s *NotificationService) MarkAllRead(userID uuid.UUID) (int64, error) {
	res := s.db.Model(&model.Notification{}).Where("user_id = ? AND read_at IS NULL", userID).Update("read_at", time.Now())
	return res.RowsAffected, res.Error
}

func (s *NotificationService) Delete(userID, id uuid.UUID) error {
	res := s.db.Where("id = ? AND user_id = ?", id, userID).Delete(&model.Notification{})
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return ErrNotFound
	}
	return nil
}

// excerpt shortens s to at most n runes for a notification body.
func excerpt(s string, n int) string {
	if utf8.RuneCountInString(s) <= n {
		return s
	}
	r := []rune(s)
	return string(r[:n]) + "…"
}

// NotifyReply tells the author of parent that reply answered them. Replying
// to yourself sends nothing.
func (s *NotificationService) NotifyReply(reply, parent *model.Comment) error {
	if parent.UserID == reply.UserID {
		return nil
	}
	var actor model.UserBrief
	if err := s.db.First(&actor, "id = ?", reply.UserID).Error; err != nil {
		return err
	}
	var chapter model.Chapter
	if err := s.db.Select("novel_id").First(&chapter, "id = ?", reply.ChapterID).Error; err != nil {
		return err
	}
	name := actor.Nickname
	if name == "" {
		name = actor.Username
	}
	chapterID, threadID := reply.ChapterID, *reply.ParentID
	return s.db.Create(&model.Notification{
		UserID: parent.UserID, Type: model.NotificationCommentReply,
		Title: name + " 回覆了你的留言", Body: excerpt(reply.Content, 100),
		NovelID: &chapter.NovelID, ChapterID: &chapterID, CommentID: &threadID, ActorID: &reply.UserID,
	}).Error
}

// NotifyChapters tells readers who keep a published novel on their
// bookshelf, with notifications on, that chapters were published. A reader
// who has not yet read the previous update keeps a single notification,
// still pointing at the first chapter they have not been told about.
func (s *NotificationService) NotifyChapters(novelID uuid.UUID, published []model.Chapter) error {
	if len(published) == 0 {
		return nil
	}
	var novel model.Novel
	if err := s.db.Select("id", "title", "is_published").First(&novel, "id = ?", novelID).Error; err != nil {
		return err
	}
	if !novel.IsPublished {
		return nil
	}
	first, last := published[0], published[0]
	for _, ch := range published[1:] {
		if ch.ChapterNumber < first.ChapterNumber {
			first = ch
		}
		if ch.ChapterNumber > last.ChapterNumber {
			last = ch
		}
	}
	title := "《" + novel.Title + "》有新章節"
	body := "更新至：" + last.Title

	subscribers := s.db.Table("bookshelf_items AS b").Select("b.user_id").
		Joins("JOIN users u ON u.id = b.user_id AND u.deleted_at IS NULL AND u.status = 'active'").
		Where("b.novel_id = ? AND b.is_notified", novelID)
	return s.db.Transaction(func(tx *gorm.DB) error {
		pending := tx.Model(&model.Notification{}).
			Where("type = ? AND novel_id = ? AND read_at IS NULL", model.NotificationChapterUpdate, novelID)
		if err := pending.Session(&gorm.Session{}).Where("user_id IN (?)", subscribers).
			Updates(map[string]interface{}{"title": title, "body": body, "created_at": time.Now()}).Error; err != nil {
			return err
		}
		return tx.Exec(`
			INSERT INTO notifications (user_id, type, title, body, novel_id, chapter_id, created_at)
			SELECT s.user_id, ?, ?, ?, ?, ?, NOW() FROM (?) AS s
			WHERE NOT EXISTS (
				SELECT 1 FROM notifications n
				WHERE n.user_id = s.user_id AND n.type = ? AND n.novel_id = ? AND n.read_at IS NULL)`,
			model.NotificationChapterUpdate, title, body, novelID, first.ID, subscribers,
			model.NotificationChapterUpdate, novelID).Error
	})
}

// Broadcast sends a system notification to every active user and returns
// how many received it.
func (s *NotificationService) Broadcast(title, body string) (int64, error) {
	res := s.db.Exec(`
		INSERT INTO notifications (user_id, type, title, body, created_at)
		SELECT id, ?, ?, ?, NOW() FROM users WHERE deleted_at IS NULL AND status = 'active'`,
		model.NotificationSystem, title, body)
	return res.RowsAffected, res.Error
}

// ------------------------------------------------------------------ devices

// DeviceInput registers a client installation.
type DeviceInput struct {
	DeviceID   string `json:"device_id" binding:"required,max=255"`
	DeviceType string `json:"device_type" binding:"required,oneof=web android ios windows macos linux"`
	DeviceName string `json:"device_name" binding:"max=100"`
	PushToken  string `json:"push_token" binding:"max=500"`
}

func (s *NotificationService) ListDevices(userID uuid.UUID) ([]model.UserDevice, error) {
	devices := []model.UserDevice{}
	err := s.db.Where("user_id = ?", userID).Order("last_active_at DESC").Find(&devices).Error
	return devices, err
}

// RegisterDevice adds the device or refreshes it. A push token belongs to one
// installation, so it is taken away from any other account that had it.
func (s *NotificationService) RegisterDevice(userID uuid.UUID, in DeviceInput) (*model.UserDevice, error) {
	device := model.UserDevice{
		UserID: userID, DeviceID: in.DeviceID, DeviceType: in.DeviceType,
		DeviceName: in.DeviceName, PushToken: in.PushToken, LastActiveAt: time.Now(),
	}
	err := s.db.Transaction(func(tx *gorm.DB) error {
		if in.PushToken != "" {
			if err := tx.Model(&model.UserDevice{}).Where("push_token = ? AND user_id <> ?", in.PushToken, userID).
				Update("push_token", "").Error; err != nil {
				return err
			}
		}
		err := tx.Clauses(clause.OnConflict{
			Columns:   []clause.Column{{Name: "user_id"}, {Name: "device_id"}},
			DoUpdates: clause.AssignmentColumns([]string{"device_type", "device_name", "push_token", "last_active_at"}),
		}).Create(&device).Error
		if err != nil {
			return err
		}
		if err := tx.First(&device, "user_id = ? AND device_id = ?", userID, in.DeviceID).Error; err != nil {
			return err
		}
		return tx.Where("user_id = ? AND id NOT IN (?)", userID,
			tx.Model(&model.UserDevice{}).Select("id").Where("user_id = ?", userID).
				Order("last_active_at DESC").Limit(maxDevicesPerUser)).
			Delete(&model.UserDevice{}).Error
	})
	if err != nil {
		return nil, err
	}
	return &device, nil
}

func (s *NotificationService) RemoveDevice(userID, id uuid.UUID) error {
	res := s.db.Where("id = ? AND user_id = ?", id, userID).Delete(&model.UserDevice{})
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return ErrNotFound
	}
	return nil
}
