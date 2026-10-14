package service

import (
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type UserService struct {
	db *gorm.DB
}

func NewUserService(db *gorm.DB) *UserService {
	return &UserService{db: db}
}

func (s *UserService) Get(userID uuid.UUID) (*model.User, error) {
	var user model.User
	err := s.db.First(&user, "id = ?", userID).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	return &user, err
}

// ProfileUpdate holds the profile fields a user may change; nil means unchanged.
type ProfileUpdate struct {
	Nickname     *string `json:"nickname" binding:"omitempty,min=1,max=50"`
	Bio          *string `json:"bio" binding:"omitempty,max=500"`
	AvatarURL    *string `json:"avatar_url" binding:"omitempty,max=500"`
	LanguagePref *string `json:"language_pref" binding:"omitempty,oneof=zh-TW zh-CN en"`
}

func (s *UserService) UpdateProfile(userID uuid.UUID, u ProfileUpdate) (*model.User, error) {
	updates := map[string]interface{}{}
	if u.Nickname != nil {
		updates["nickname"] = *u.Nickname
	}
	if u.Bio != nil {
		updates["bio"] = *u.Bio
	}
	if u.AvatarURL != nil {
		updates["avatar_url"] = *u.AvatarURL
	}
	if u.LanguagePref != nil {
		updates["language_pref"] = *u.LanguagePref
	}
	if len(updates) > 0 {
		if err := s.db.Model(&model.User{}).Where("id = ?", userID).Updates(updates).Error; err != nil {
			return nil, err
		}
	}
	return s.Get(userID)
}

// ChangePassword replaces the password after checking the current one; a
// wrong current password returns ErrInvalidCredentials.
func (s *UserService) ChangePassword(userID uuid.UUID, current, next string) error {
	user, err := s.Get(userID)
	if err != nil {
		return err
	}
	if bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(current)) != nil {
		return ErrInvalidCredentials
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(next), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	return s.db.Model(user).Updates(map[string]interface{}{"password_hash": string(hash), "password_changed_at": time.Now()}).Error
}

// ReadingSettings returns the user's reader preferences, or the defaults
// when they never saved any.
func (s *UserService) ReadingSettings(userID uuid.UUID) (*model.ReadingSettings, error) {
	var settings model.ReadingSettings
	err := s.db.First(&settings, "user_id = ?", userID).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		settings = model.DefaultReadingSettings(userID)
		return &settings, nil
	}
	return &settings, err
}

func (s *UserService) SaveReadingSettings(userID uuid.UUID, settings model.ReadingSettings) (*model.ReadingSettings, error) {
	settings.ID = uuid.Nil
	settings.UserID = userID
	columns := []string{
		"font_size", "line_height", "letter_spacing", "margin", "font_family", "theme",
		"reading_mode", "brightness", "keep_screen_on", "auto_chapter", "updated_at",
	}
	// Clients that predate page_animation leave it out; keep what is stored.
	if settings.PageAnimation != "" {
		columns = append(columns, "page_animation")
	}
	err := s.db.Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "user_id"}},
		DoUpdates: clause.AssignmentColumns(columns),
	}).Create(&settings).Error
	if err != nil {
		return nil, err
	}
	return s.ReadingSettings(userID)
}

// ReadingStats summarises a user's reading for the profile page.
type ReadingStats struct {
	TotalReadWords   int64           `json:"total_read_words"`
	TotalReadSeconds int64           `json:"total_read_seconds"`
	ChaptersRead     int64           `json:"chapters_read"`
	NovelsRead       int64           `json:"novels_read"`
	BookshelfCount   int64           `json:"bookshelf_count"`
	BookmarkCount    int64           `json:"bookmark_count"`
	ReviewCount      int64           `json:"review_count"`
	Period           string          `json:"period"`
	Buckets          []ReadingBucket `json:"buckets"`
}

// ReadingBucket counts the chapters opened in one day, week or month.
type ReadingBucket struct {
	Start    time.Time `json:"start"`
	Chapters int64     `json:"chapters"`
	Words    int64     `json:"words"`
	Seconds  int64     `json:"seconds"`
}

var statsPeriods = map[string]struct {
	unit    string
	buckets int
}{
	"daily":   {"day", 7},
	"weekly":  {"week", 8},
	"monthly": {"month", 12},
}

func (s *UserService) ReadingStats(userID uuid.UUID, period string) (*ReadingStats, error) {
	p, ok := statsPeriods[period]
	if !ok {
		period, p = "daily", statsPeriods["daily"]
	}
	user, err := s.Get(userID)
	if err != nil {
		return nil, err
	}
	stats := &ReadingStats{TotalReadWords: user.TotalReadWords, TotalReadSeconds: user.TotalReadSeconds, Period: period}

	counts := []struct {
		dst   *int64
		query *gorm.DB
	}{
		{&stats.ChaptersRead, s.db.Model(&model.ReadingHistory{}).Where("user_id = ?", userID).Distinct("chapter_id")},
		{&stats.NovelsRead, s.db.Model(&model.ReadingHistory{}).Where("user_id = ?", userID).Distinct("novel_id")},
		{&stats.BookshelfCount, s.db.Model(&model.BookshelfItem{}).Where("user_id = ?", userID)},
		{&stats.BookmarkCount, s.db.Model(&model.Bookmark{}).Where("user_id = ?", userID)},
		{&stats.ReviewCount, s.db.Model(&model.Review{}).Where("user_id = ?", userID)},
	}
	for _, c := range counts {
		if err := c.query.Count(c.dst).Error; err != nil {
			return nil, err
		}
	}

	// unit is one of three fixed strings, so building the SQL with it is safe.
	err = s.db.Raw(`
		SELECT b.start, COUNT(h.id) AS chapters, COALESCE(SUM(c.word_count), 0) AS words,
		       COALESCE(SUM(h.duration), 0) AS seconds
		FROM generate_series(date_trunc('`+p.unit+`', now()) - (? - 1) * interval '1 `+p.unit+`',
		                     date_trunc('`+p.unit+`', now()), interval '1 `+p.unit+`') AS b(start)
		LEFT JOIN reading_history h ON h.user_id = ? AND date_trunc('`+p.unit+`', h.read_at) = b.start
		LEFT JOIN chapters c ON c.id = h.chapter_id
		GROUP BY b.start ORDER BY b.start`, p.buckets, userID).Scan(&stats.Buckets).Error
	if err != nil {
		return nil, err
	}
	return stats, nil
}
