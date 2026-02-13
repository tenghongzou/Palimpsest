package service

import (
	"context"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/repository"
)

type RankingService struct {
	rdb       *redis.Client
	novelRepo *repository.NovelRepository
}

func NewRankingService(rdb *redis.Client, novelRepo *repository.NovelRepository) *RankingService {
	return &RankingService{rdb: rdb, novelRepo: novelRepo}
}

type RankingItem struct {
	Rank  int          `json:"rank"`
	Novel model.Novel  `json:"novel"`
	Score float64      `json:"score"`
}

// GetRanking returns novels ranked by the given type and period.
// rankType: views, favorites, rating, latest, completed
// period: daily, weekly, monthly, all
func (s *RankingService) GetRanking(rankType, period string, page, pageSize int) ([]model.Novel, int64, error) {
	ctx := context.Background()
	key := fmt.Sprintf("palimpsest:ranking:%s:%s", rankType, period)

	// Try to get from Redis sorted set
	start := int64((page - 1) * pageSize)
	stop := start + int64(pageSize) - 1

	ids, err := s.rdb.ZRevRange(ctx, key, start, stop).Result()
	if err == nil && len(ids) > 0 {
		total, _ := s.rdb.ZCard(ctx, key).Result()
		novels := s.fetchNovelsByIDs(ids)
		return novels, total, nil
	}

	// Fallback to database query
	var sortBy string
	var status string
	switch rankType {
	case "views":
		sortBy = "popular"
	case "favorites":
		sortBy = "favorites"
	case "rating":
		sortBy = "rating"
	case "completed":
		status = "completed"
		sortBy = "latest"
	default:
		sortBy = "latest"
	}

	novels, total, err := s.novelRepo.List(page, pageSize, nil, status, "", sortBy)
	if err != nil {
		return nil, 0, err
	}

	// Cache in Redis for 10 minutes
	s.cacheRanking(ctx, key, novels, 10*time.Minute)

	return novels, total, nil
}

func (s *RankingService) fetchNovelsByIDs(ids []string) []model.Novel {
	var novels []model.Novel
	for _, id := range ids {
		uid, err := parseUUID(id)
		if err != nil {
			continue
		}
		novel, err := s.novelRepo.FindByID(uid)
		if err != nil {
			continue
		}
		novels = append(novels, *novel)
	}
	return novels
}

func (s *RankingService) cacheRanking(ctx context.Context, key string, novels []model.Novel, ttl time.Duration) {
	pipe := s.rdb.Pipeline()
	for i, novel := range novels {
		pipe.ZAdd(ctx, key, redis.Z{
			Score:  float64(len(novels) - i),
			Member: novel.ID.String(),
		})
	}
	pipe.Expire(ctx, key, ttl)
	_, _ = pipe.Exec(ctx)
}
