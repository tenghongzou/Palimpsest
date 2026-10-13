package service

import (
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/repository"
	"gorm.io/gorm"
)

type BookshelfService struct {
	bookshelfRepo *repository.BookshelfRepository
	db            *gorm.DB
}

func NewBookshelfService(bookshelfRepo *repository.BookshelfRepository, db *gorm.DB) *BookshelfService {
	return &BookshelfService{bookshelfRepo: bookshelfRepo, db: db}
}

func (s *BookshelfService) List(userID uuid.UUID, sortBy string) ([]model.BookshelfItem, error) {
	return s.bookshelfRepo.List(userID, sortBy)
}

func (s *BookshelfService) Add(userID, novelID uuid.UUID, groupName string) (*model.BookshelfItem, error) {
	if groupName == "" {
		groupName = "default"
	}
	item := &model.BookshelfItem{
		UserID:    userID,
		NovelID:   novelID,
		GroupName: groupName,
	}
	if err := s.bookshelfRepo.Add(item); err != nil {
		return nil, err
	}
	return item, nil
}

func (s *BookshelfService) Remove(userID, novelID uuid.UUID) error {
	return s.bookshelfRepo.Remove(userID, novelID)
}

// UpdateProgress stores reading progress. readAt is when the reader was at
// this position; a zero value means now. Offline clients sync late, so an
// update older than the stored progress is ignored (last read wins) and the
// stored progress is returned instead.
func (s *BookshelfService) UpdateProgress(userID, novelID, chapterID uuid.UUID, paragraphIndex int, scrollOffset float64, readAt time.Time) (*model.ReadingProgress, error) {
	now := time.Now()
	if readAt.IsZero() || readAt.After(now) {
		readAt = now
	}

	var progress model.ReadingProgress
	err := s.db.Where("user_id = ? AND novel_id = ?", userID, novelID).First(&progress).Error

	if errors.Is(err, gorm.ErrRecordNotFound) {
		progress = model.ReadingProgress{
			UserID:         userID,
			NovelID:        novelID,
			ChapterID:      chapterID,
			ParagraphIndex: paragraphIndex,
			ScrollOffset:   scrollOffset,
			ReadAt:         readAt,
			SyncedAt:       now,
		}
		return &progress, s.db.Create(&progress).Error
	}
	if err != nil {
		return nil, err
	}
	if readAt.Before(progress.ReadAt) {
		return &progress, nil
	}

	progress.ChapterID = chapterID
	progress.ParagraphIndex = paragraphIndex
	progress.ScrollOffset = scrollOffset
	progress.ReadAt = readAt
	progress.SyncedAt = now
	return &progress, s.db.Save(&progress).Error
}

// ListProgress returns all of a user's reading progress, most recent first.
func (s *BookshelfService) ListProgress(userID uuid.UUID) ([]model.ReadingProgress, error) {
	progress := []model.ReadingProgress{}
	err := s.db.Where("user_id = ?", userID).Order("read_at DESC").Find(&progress).Error
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
