package service

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/repository"
)

type NovelService struct {
	novelRepo *repository.NovelRepository
	cacheRepo *repository.CacheRepository
}

func NewNovelService(novelRepo *repository.NovelRepository, cacheRepo *repository.CacheRepository) *NovelService {
	return &NovelService{novelRepo: novelRepo, cacheRepo: cacheRepo}
}

func (s *NovelService) List(page, pageSize int, categoryID *int, status, language, sortBy string) ([]model.Novel, int64, error) {
	return s.novelRepo.List(page, pageSize, categoryID, status, language, sortBy)
}

func (s *NovelService) GetByID(id uuid.UUID) (*model.Novel, error) {
	cacheKey := fmt.Sprintf("palimpsest:novel:%s", id.String())
	ctx := context.Background()

	// Try cache first
	cached, err := s.cacheRepo.Get(ctx, cacheKey)
	if err == nil && cached != "" {
		var novel model.Novel
		if json.Unmarshal([]byte(cached), &novel) == nil {
			return &novel, nil
		}
	}

	novel, err := s.novelRepo.FindByID(id)
	if err != nil {
		return nil, err
	}

	// Cache for 10 minutes
	if data, err := json.Marshal(novel); err == nil {
		_ = s.cacheRepo.Set(ctx, cacheKey, string(data), 10*time.Minute)
	}

	return novel, nil
}

func (s *NovelService) ListChapters(novelID uuid.UUID, order string) ([]model.Chapter, error) {
	cacheKey := fmt.Sprintf("palimpsest:novel:%s:chapters:%s", novelID.String(), order)
	ctx := context.Background()

	cached, err := s.cacheRepo.Get(ctx, cacheKey)
	if err == nil && cached != "" {
		var chapters []model.Chapter
		if json.Unmarshal([]byte(cached), &chapters) == nil {
			return chapters, nil
		}
	}

	chapters, err := s.novelRepo.ListChapters(novelID, order)
	if err != nil {
		return nil, err
	}

	// Cache for 1 hour
	if data, err := json.Marshal(chapters); err == nil {
		_ = s.cacheRepo.Set(ctx, cacheKey, string(data), time.Hour)
	}

	return chapters, nil
}

func (s *NovelService) GetChapter(id uuid.UUID) (*model.Chapter, error) {
	return s.novelRepo.FindChapter(id)
}

func (s *NovelService) ListCategories() ([]model.Category, error) {
	return s.novelRepo.ListCategories()
}
