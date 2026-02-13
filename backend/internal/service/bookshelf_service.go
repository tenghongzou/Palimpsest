package service

import (
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

func (s *BookshelfService) UpdateProgress(userID, novelID, chapterID uuid.UUID, paragraphIndex int, scrollOffset float64) (*model.ReadingProgress, error) {
	var progress model.ReadingProgress
	err := s.db.Where("user_id = ? AND novel_id = ?", userID, novelID).First(&progress).Error

	if err == gorm.ErrRecordNotFound {
		progress = model.ReadingProgress{
			UserID:         userID,
			NovelID:        novelID,
			ChapterID:      chapterID,
			ParagraphIndex: paragraphIndex,
			ScrollOffset:   scrollOffset,
		}
		return &progress, s.db.Create(&progress).Error
	}
	if err != nil {
		return nil, err
	}

	progress.ChapterID = chapterID
	progress.ParagraphIndex = paragraphIndex
	progress.ScrollOffset = scrollOffset
	return &progress, s.db.Save(&progress).Error
}

func (s *BookshelfService) GetProgress(userID, novelID uuid.UUID) (*model.ReadingProgress, error) {
	var progress model.ReadingProgress
	err := s.db.Where("user_id = ? AND novel_id = ?", userID, novelID).First(&progress).Error
	if err != nil {
		return nil, err
	}
	return &progress, nil
}
