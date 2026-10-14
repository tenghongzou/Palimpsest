package service

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/google/uuid"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/repository"
)

// ViewRecorder counts a read of a novel; RankingService implements it.
type ViewRecorder interface {
	RecordView(novelID uuid.UUID)
}

type NovelService struct {
	novelRepo *repository.NovelRepository
	cacheRepo *repository.CacheRepository
	views     ViewRecorder
}

func NewNovelService(novelRepo *repository.NovelRepository, cacheRepo *repository.CacheRepository, views ViewRecorder) *NovelService {
	return &NovelService{novelRepo: novelRepo, cacheRepo: cacheRepo, views: views}
}

func novelCacheKey(id uuid.UUID) string { return fmt.Sprintf("palimpsest:novel:%s", id) }

func chaptersCacheKey(id uuid.UUID, order string) string {
	return fmt.Sprintf("palimpsest:novel:%s:chapters:%s", id, order)
}

func (s *NovelService) List(page, pageSize int, categoryID *int, status, language, sortBy string) ([]model.Novel, int64, error) {
	return s.novelRepo.List(page, pageSize, categoryID, status, language, sortBy)
}

// CategoryIDBySlug resolves a category slug for list filters.
func (s *NovelService) CategoryIDBySlug(slug string) (int, error) {
	category, err := s.novelRepo.FindCategoryBySlug(slug)
	if err != nil {
		return 0, err
	}
	return category.ID, nil
}

// GetByID returns a published novel.
func (s *NovelService) GetByID(id uuid.UUID) (*model.Novel, error) {
	cacheKey := novelCacheKey(id)
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
	if !novel.IsPublished {
		return nil, ErrNotFound
	}

	// Cache for 10 minutes
	if data, err := json.Marshal(novel); err == nil {
		_ = s.cacheRepo.Set(ctx, cacheKey, string(data), 10*time.Minute)
	}

	return novel, nil
}

func (s *NovelService) ListChapters(novelID uuid.UUID, order string) ([]model.Chapter, error) {
	if order != "desc" {
		order = "asc"
	}
	cacheKey := chaptersCacheKey(novelID, order)
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

// GetChapter returns a published chapter with its neighbours. countView is
// false for bulk offline downloads, which are not reads.
func (s *NovelService) GetChapter(id uuid.UUID, countView bool) (*model.ChapterDetail, error) {
	chapter, err := s.novelRepo.FindPublishedChapter(id)
	if err != nil {
		return nil, err
	}
	prev, next, err := s.novelRepo.AdjacentChapters(chapter.NovelID, chapter.ChapterNumber)
	if err != nil {
		return nil, err
	}
	if countView && s.views != nil {
		s.views.RecordView(chapter.NovelID)
	}
	return &model.ChapterDetail{Chapter: *chapter, PrevChapter: prev, NextChapter: next}, nil
}

func (s *NovelService) ListCategories() ([]model.Category, error) {
	return s.novelRepo.ListCategories()
}

// InvalidateNovel drops the cached novel detail, chapter lists and home page
// so edits show up immediately instead of after the cache TTL.
func (s *NovelService) InvalidateNovel(id uuid.UUID) {
	if s.cacheRepo == nil {
		return
	}
	ctx := context.Background()
	for _, key := range []string{novelCacheKey(id), chaptersCacheKey(id, "asc"), chaptersCacheKey(id, "desc"), homeCacheKey} {
		if err := s.cacheRepo.Delete(ctx, key); err != nil {
			log.Printf("cache: failed to delete %s: %v", key, err)
		}
	}
}

// ChaptersChanged refreshes the novel's chapter totals and latest chapter
// after chapters are added, edited or removed, then drops stale caches.
func (s *NovelService) ChaptersChanged(novelID uuid.UUID) error {
	err := s.novelRepo.RefreshStats(novelID)
	s.InvalidateNovel(novelID)
	return err
}
