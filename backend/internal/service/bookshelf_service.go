package service

import (
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/repository"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// maxSyncedDuration caps the reading time one progress update may add, so a
// client left open overnight does not inflate the statistics.
const maxSyncedDuration = 3600

type BookshelfService struct {
	bookshelfRepo *repository.BookshelfRepository
	db            *gorm.DB
}

func NewBookshelfService(bookshelfRepo *repository.BookshelfRepository, db *gorm.DB) *BookshelfService {
	return &BookshelfService{bookshelfRepo: bookshelfRepo, db: db}
}

// ShelfProgress summarises where the reader is in a shelved novel.
type ShelfProgress struct {
	ChapterID     uuid.UUID `json:"chapter_id"`
	ChapterTitle  string    `json:"chapter_title"`
	ChapterNumber int       `json:"chapter_number"`
	Percentage    float64   `json:"percentage"`
	ReadAt        time.Time `json:"read_at"`
}

// BookshelfEntry is a shelved novel with the reader's progress in it.
type BookshelfEntry struct {
	model.BookshelfItem
	ReadingProgress *ShelfProgress `json:"reading_progress"`
	// HasUpdate is true when chapters were published after the reader last read.
	HasUpdate bool `json:"has_update"`
}

func (s *BookshelfService) List(userID uuid.UUID, sortBy string) ([]BookshelfEntry, error) {
	items, err := s.bookshelfRepo.List(userID, sortBy)
	if err != nil {
		return nil, err
	}
	entries := make([]BookshelfEntry, len(items))
	if len(items) == 0 {
		return entries, nil
	}

	novelIDs := make([]uuid.UUID, len(items))
	for i, item := range items {
		novelIDs[i] = item.NovelID
	}
	var rows []struct {
		NovelID       uuid.UUID
		ChapterID     uuid.UUID
		ChapterTitle  string
		ChapterNumber int
		ReadAt        time.Time
	}
	err = s.db.Table("reading_progresses p").
		Select("p.novel_id, p.chapter_id, c.title AS chapter_title, c.chapter_number, p.read_at").
		Joins("JOIN chapters c ON c.id = p.chapter_id").
		Where("p.user_id = ? AND p.novel_id IN ?", userID, novelIDs).
		Scan(&rows).Error
	if err != nil {
		return nil, err
	}
	progress := make(map[uuid.UUID]*ShelfProgress, len(rows))
	for _, r := range rows {
		progress[r.NovelID] = &ShelfProgress{ChapterID: r.ChapterID, ChapterTitle: r.ChapterTitle, ChapterNumber: r.ChapterNumber, ReadAt: r.ReadAt}
	}

	for i, item := range items {
		entry := BookshelfEntry{BookshelfItem: item}
		novel := item.Novel
		if p, ok := progress[item.NovelID]; ok {
			if novel.TotalChapters > 0 {
				p.Percentage = min(100, float64(p.ChapterNumber)*100/float64(novel.TotalChapters))
			}
			entry.ReadingProgress = p
			entry.HasUpdate = novel.LatestChapterAt != nil && novel.LatestChapterAt.After(p.ReadAt) &&
				(novel.LatestChapterID == nil || *novel.LatestChapterID != p.ChapterID)
		} else {
			entry.HasUpdate = novel.LatestChapterAt != nil && novel.LatestChapterAt.After(item.AddedAt)
		}
		entries[i] = entry
	}
	if sortBy == "" || sortBy == "recent" {
		sortByRecent(entries)
	}
	return entries, nil
}

// sortByRecent orders novels by when they were last read, falling back to
// when they were added for novels not read yet.
func sortByRecent(entries []BookshelfEntry) {
	last := func(e BookshelfEntry) time.Time {
		if e.ReadingProgress != nil && e.ReadingProgress.ReadAt.After(e.AddedAt) {
			return e.ReadingProgress.ReadAt
		}
		return e.AddedAt
	}
	for i := 1; i < len(entries); i++ {
		for j := i; j > 0 && last(entries[j]).After(last(entries[j-1])); j-- {
			entries[j], entries[j-1] = entries[j-1], entries[j]
		}
	}
}

// Add shelves a published novel. It returns ErrNotFound for an unknown novel
// and ErrConflict when the novel is already on the shelf.
func (s *BookshelfService) Add(userID, novelID uuid.UUID, groupName string) (*model.BookshelfItem, error) {
	if groupName == "" {
		groupName = "default"
	}
	var exists int64
	if err := s.db.Model(&model.Novel{}).Where("id = ? AND is_published", novelID).Count(&exists).Error; err != nil {
		return nil, err
	}
	if exists == 0 {
		return nil, ErrNotFound
	}

	item := &model.BookshelfItem{UserID: userID, NovelID: novelID, GroupName: groupName}
	err := s.db.Transaction(func(tx *gorm.DB) error {
		res := tx.Clauses(clause.OnConflict{DoNothing: true}).Create(item)
		if res.Error != nil {
			return res.Error
		}
		if res.RowsAffected == 0 {
			return ErrConflict
		}
		return tx.Model(&model.Novel{}).Where("id = ?", novelID).
			UpdateColumn("favorite_count", gorm.Expr("favorite_count + 1")).Error
	})
	if err != nil {
		return nil, err
	}
	return item, nil
}

func (s *BookshelfService) Remove(userID, novelID uuid.UUID) error {
	return s.RemoveMany(userID, []uuid.UUID{novelID})
}

// RemoveMany takes novels off the shelf, keeping favorite counts in step.
func (s *BookshelfService) RemoveMany(userID uuid.UUID, novelIDs []uuid.UUID) error {
	if len(novelIDs) == 0 {
		return nil
	}
	return s.db.Transaction(func(tx *gorm.DB) error {
		var removed []model.BookshelfItem
		err := tx.Clauses(clause.Returning{Columns: []clause.Column{{Name: "novel_id"}}}).
			Where("user_id = ? AND novel_id IN ?", userID, novelIDs).Delete(&removed).Error
		if err != nil {
			return err
		}
		for _, item := range removed {
			err := tx.Model(&model.Novel{}).Where("id = ? AND favorite_count > 0", item.NovelID).
				UpdateColumn("favorite_count", gorm.Expr("favorite_count - 1")).Error
			if err != nil {
				return err
			}
		}
		return nil
	})
}

// ItemUpdate changes a bookshelf entry; nil fields stay as they are.
type ItemUpdate struct {
	GroupName  *string `json:"group_name" binding:"omitempty,min=1,max=50"`
	IsNotified *bool   `json:"is_notified"`
}

// UpdateItem moves a bookshelf entry to another group or turns its update
// notifications on or off.
func (s *BookshelfService) UpdateItem(userID, novelID uuid.UUID, u ItemUpdate) error {
	updates := map[string]interface{}{}
	if u.GroupName != nil {
		updates["group_name"] = *u.GroupName
	}
	if u.IsNotified != nil {
		updates["is_notified"] = *u.IsNotified
	}
	q := s.db.Model(&model.BookshelfItem{}).Where("user_id = ? AND novel_id = ?", userID, novelID)
	if len(updates) == 0 {
		var n int64
		if err := q.Count(&n).Error; err != nil {
			return err
		}
		if n == 0 {
			return ErrNotFound
		}
		return nil
	}
	res := q.Updates(updates)
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return ErrNotFound
	}
	return nil
}

// ProgressUpdate is one reading position report from a client.
type ProgressUpdate struct {
	ChapterID      uuid.UUID
	ParagraphIndex int
	ScrollOffset   float64
	// ReadAt is when the reader was at this position; zero means now.
	ReadAt time.Time
	// Duration is the reading time in seconds since the previous report.
	Duration int
}

// UpdateProgress stores reading progress. Offline clients sync late, so an
// update older than the stored progress is ignored (last read wins) and the
// stored progress is returned instead. Moving to another chapter adds a
// reading history entry and counts that chapter's words as read.
func (s *BookshelfService) UpdateProgress(userID, novelID uuid.UUID, u ProgressUpdate) (*model.ReadingProgress, error) {
	now := time.Now()
	readAt := u.ReadAt
	if readAt.IsZero() || readAt.After(now) {
		readAt = now
	}
	duration := max(0, min(u.Duration, maxSyncedDuration))

	var chapter model.Chapter
	err := s.db.Select("id, novel_id, word_count").First(&chapter, "id = ?", u.ChapterID).Error
	if errors.Is(err, gorm.ErrRecordNotFound) || (err == nil && chapter.NovelID != novelID) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}

	var progress model.ReadingProgress
	err = s.db.Transaction(func(tx *gorm.DB) error {
		err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
			Where("user_id = ? AND novel_id = ?", userID, novelID).First(&progress).Error
		isNew := errors.Is(err, gorm.ErrRecordNotFound)
		if err != nil && !isNew {
			return err
		}

		userUpdates := map[string]interface{}{}
		if duration > 0 {
			userUpdates["total_read_seconds"] = gorm.Expr("total_read_seconds + ?", duration)
		}
		if !isNew && readAt.Before(progress.ReadAt) {
			// A stale report: keep the newer position but still count the time.
			if duration > 0 {
				progress.ReadDuration += duration
				if err := tx.Model(&progress).UpdateColumn("read_duration", progress.ReadDuration).Error; err != nil {
					return err
				}
				if err := addHistoryDuration(tx, userID, novelID, u.ChapterID, duration); err != nil {
					return err
				}
			}
			return updateUser(tx, userID, userUpdates)
		}

		changedChapter := isNew || progress.ChapterID != u.ChapterID
		if changedChapter {
			history := model.ReadingHistory{UserID: userID, NovelID: novelID, ChapterID: u.ChapterID, ReadAt: readAt, Duration: duration}
			if err := tx.Create(&history).Error; err != nil {
				return err
			}
			userUpdates["total_read_words"] = gorm.Expr("total_read_words + ?", chapter.WordCount)
		} else if duration > 0 {
			if err := addHistoryDuration(tx, userID, novelID, u.ChapterID, duration); err != nil {
				return err
			}
		}

		if isNew {
			progress = model.ReadingProgress{UserID: userID, NovelID: novelID}
		}
		progress.ChapterID = u.ChapterID
		progress.ParagraphIndex = u.ParagraphIndex
		progress.ScrollOffset = u.ScrollOffset
		progress.ReadDuration += duration
		progress.ReadAt = readAt
		progress.SyncedAt = now
		if err := tx.Save(&progress).Error; err != nil {
			return err
		}
		return updateUser(tx, userID, userUpdates)
	})
	if err != nil {
		return nil, err
	}
	return &progress, nil
}

// addHistoryDuration adds reading time to the latest history entry of a
// chapter, so daily statistics include time spent after the chapter opened.
func addHistoryDuration(tx *gorm.DB, userID, novelID, chapterID uuid.UUID, seconds int) error {
	return tx.Exec(`
		UPDATE reading_history SET duration = duration + ?
		WHERE id = (
			SELECT id FROM reading_history
			WHERE user_id = ? AND novel_id = ? AND chapter_id = ?
			ORDER BY read_at DESC LIMIT 1
		)`, seconds, userID, novelID, chapterID).Error
}

func updateUser(tx *gorm.DB, userID uuid.UUID, updates map[string]interface{}) error {
	if len(updates) == 0 {
		return nil
	}
	return tx.Model(&model.User{}).Where("id = ?", userID).UpdateColumns(updates).Error
}

// ListProgress returns a user's reading progress, most recent first,
// optionally limited to some novels.
func (s *BookshelfService) ListProgress(userID uuid.UUID, novelIDs []uuid.UUID) ([]model.ReadingProgress, error) {
	progress := []model.ReadingProgress{}
	q := s.db.Where("user_id = ?", userID)
	if novelIDs != nil {
		q = q.Where("novel_id IN ?", novelIDs)
	}
	err := q.Order("read_at DESC").Find(&progress).Error
	return progress, err
}

func (s *BookshelfService) GetProgress(userID, novelID uuid.UUID) (*model.ReadingProgress, error) {
	var progress model.ReadingProgress
	err := s.db.Where("user_id = ? AND novel_id = ?", userID, novelID).First(&progress).Error
	if err != nil {
		return nil, err
	}
	return &progress, nil
}

// History returns the chapters a user opened, newest first.
func (s *BookshelfService) History(userID uuid.UUID, page, pageSize int) ([]model.ReadingHistory, int64, error) {
	history := []model.ReadingHistory{}
	var total int64
	q := s.db.Model(&model.ReadingHistory{}).Where("user_id = ?", userID)
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	err := q.Order("read_at DESC").Offset(offset(page, pageSize)).Limit(pageSize).
		Preload("Novel", func(db *gorm.DB) *gorm.DB {
			return db.Unscoped()
		}).
		Preload("Chapter", func(db *gorm.DB) *gorm.DB {
			return db.Select("id, novel_id, title, chapter_number")
		}).
		Find(&history).Error
	return history, total, err
}
