package service

import (
	"context"
	"encoding/json"
	"time"

	"github.com/redis/go-redis/v9"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"gorm.io/gorm"
)

const (
	homeCacheKey     = "palimpsest:home"
	homeCacheTTL     = 5 * time.Minute
	homeSectionLimit = 12
)

// HomePage is the bookstore front page.
type HomePage struct {
	Banners       []model.Banner `json:"banners"`
	Featured      []model.Novel  `json:"featured"`
	LatestUpdates []model.Novel  `json:"latest_updates"`
	Popular       []model.Novel  `json:"popular"`
	NewArrivals   []model.Novel  `json:"new_arrivals"`
	Completed     []model.Novel  `json:"completed"`
}

type HomeService struct {
	db  *gorm.DB
	rdb *redis.Client
}

func NewHomeService(db *gorm.DB, rdb *redis.Client) *HomeService {
	return &HomeService{db: db, rdb: rdb}
}

// ActiveBanners returns banners that are switched on and inside their schedule.
func (s *HomeService) ActiveBanners() ([]model.Banner, error) {
	banners := []model.Banner{}
	now := time.Now()
	err := s.db.Where("is_active AND (start_at IS NULL OR start_at <= ?) AND (end_at IS NULL OR end_at > ?)", now, now).
		Order("sort_order ASC, created_at DESC").Find(&banners).Error
	return banners, err
}

func (s *HomeService) Home() (*HomePage, error) {
	ctx := context.Background()
	if s.rdb != nil {
		if cached, err := s.rdb.Get(ctx, homeCacheKey).Result(); err == nil {
			var page HomePage
			if json.Unmarshal([]byte(cached), &page) == nil {
				return &page, nil
			}
		}
	}

	page := &HomePage{}
	var err error
	if page.Banners, err = s.ActiveBanners(); err != nil {
		return nil, err
	}
	sections := []struct {
		dst   *[]model.Novel
		where string
		order string
	}{
		{&page.Featured, "is_featured", "favorite_count DESC"},
		{&page.LatestUpdates, "latest_chapter_at IS NOT NULL", "latest_chapter_at DESC"},
		{&page.Popular, "", "view_count DESC"},
		{&page.NewArrivals, "", "published_at DESC NULLS LAST, created_at DESC"},
		{&page.Completed, "status = 'completed'", "latest_chapter_at DESC NULLS LAST"},
	}
	for _, sec := range sections {
		*sec.dst = []model.Novel{}
		q := s.db.Where("is_published").Order(sec.order).Limit(homeSectionLimit)
		if sec.where != "" {
			q = q.Where(sec.where)
		}
		if err := q.Preload("Categories").Find(sec.dst).Error; err != nil {
			return nil, err
		}
	}

	if s.rdb != nil {
		if data, err := json.Marshal(page); err == nil {
			s.rdb.Set(ctx, homeCacheKey, data, homeCacheTTL)
		}
	}
	return page, nil
}

// InvalidateHome drops the cached front page, e.g. after banners change.
func (s *HomeService) InvalidateHome() {
	if s.rdb != nil {
		s.rdb.Del(context.Background(), homeCacheKey)
	}
}
