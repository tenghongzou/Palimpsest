package service

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/repository"
)

const (
	rankingTTL = 10 * time.Minute
	// Daily view counters are kept long enough to build the monthly ranking.
	dailyViewsTTL = 40 * 24 * time.Hour
)

// RankingTypes are the ranking boards clients may request.
var RankingTypes = map[string]bool{"views": true, "favorites": true, "rating": true, "latest": true, "completed": true}

var rankingPeriodDays = map[string]int{"daily": 1, "weekly": 7, "monthly": 30}

type RankingService struct {
	rdb       *redis.Client
	novelRepo *repository.NovelRepository
	now       func() time.Time
}

func NewRankingService(rdb *redis.Client, novelRepo *repository.NovelRepository) *RankingService {
	return &RankingService{rdb: rdb, novelRepo: novelRepo, now: time.Now}
}

func dailyViewsKey(day time.Time) string {
	return "palimpsest:ranking:views:day:" + day.UTC().Format("20060102")
}

// RecordView counts a chapter read towards the novel's view total and the
// daily counter behind the daily/weekly/monthly view rankings.
func (s *RankingService) RecordView(novelID uuid.UUID) {
	if err := s.novelRepo.IncrementViews(novelID); err != nil {
		log.Printf("ranking: failed to count view for %s: %v", novelID, err)
	}
	if s.rdb == nil {
		return
	}
	ctx := context.Background()
	key := dailyViewsKey(s.now())
	pipe := s.rdb.Pipeline()
	pipe.ZIncrBy(ctx, key, 1, novelID.String())
	pipe.Expire(ctx, key, dailyViewsTTL)
	if _, err := pipe.Exec(ctx); err != nil {
		log.Printf("ranking: failed to record daily view: %v", err)
	}
}

// GetRanking returns one page of a ranking board. View rankings for a
// period come from the daily view counters; every other board, and the
// all-time view board, is ordered from the database.
func (s *RankingService) GetRanking(rankType, period string, page, pageSize int) ([]model.Novel, int64, error) {
	if !RankingTypes[rankType] {
		return nil, 0, ErrNotFound
	}
	if rankType == "views" {
		if days, ok := rankingPeriodDays[period]; ok && s.rdb != nil {
			novels, total, err := s.periodViews(period, days, page, pageSize)
			if err == nil && total > 0 {
				return novels, total, nil
			}
			if err != nil {
				log.Printf("ranking: period views unavailable, using all-time views: %v", err)
			}
		}
	}

	ctx := context.Background()
	key := fmt.Sprintf("palimpsest:ranking:%s:%s:%d:%d", rankType, period, page, pageSize)
	if s.rdb != nil {
		if cached, err := s.rdb.Get(ctx, key).Result(); err == nil {
			var p cachedPage
			if json.Unmarshal([]byte(cached), &p) == nil {
				return p.Novels, p.Total, nil
			}
		}
	}

	var sortBy, status string
	switch rankType {
	case "views":
		sortBy = "popular"
	case "favorites":
		sortBy = "favorites"
	case "rating":
		sortBy = "rating"
	case "completed":
		status, sortBy = "completed", "latest"
	default:
		sortBy = "latest"
	}
	novels, total, err := s.novelRepo.List(page, pageSize, nil, status, "", sortBy)
	if err != nil {
		return nil, 0, err
	}
	if s.rdb != nil {
		if data, err := json.Marshal(cachedPage{Novels: novels, Total: total}); err == nil {
			s.rdb.Set(ctx, key, data, rankingTTL)
		}
	}
	return novels, total, nil
}

type cachedPage struct {
	Novels []model.Novel `json:"novels"`
	Total  int64         `json:"total"`
}

// periodViews sums the last `days` daily counters into a cached sorted set.
func (s *RankingService) periodViews(period string, days, page, pageSize int) ([]model.Novel, int64, error) {
	ctx := context.Background()
	key := "palimpsest:ranking:views:" + period
	exists, err := s.rdb.Exists(ctx, key).Result()
	if err != nil {
		return nil, 0, err
	}
	if exists == 0 {
		today := s.now()
		keys := make([]string, days)
		for i := range keys {
			keys[i] = dailyViewsKey(today.AddDate(0, 0, -i))
		}
		pipe := s.rdb.TxPipeline()
		pipe.ZUnionStore(ctx, key, &redis.ZStore{Keys: keys, Aggregate: "SUM"})
		pipe.Expire(ctx, key, rankingTTL)
		if _, err := pipe.Exec(ctx); err != nil {
			return nil, 0, err
		}
	}

	total, err := s.rdb.ZCard(ctx, key).Result()
	if err != nil || total == 0 {
		return nil, total, err
	}
	start := int64(offset(page, pageSize))
	members, err := s.rdb.ZRevRange(ctx, key, start, start+int64(pageSize)-1).Result()
	if err != nil {
		return nil, 0, err
	}
	ids := make([]uuid.UUID, 0, len(members))
	for _, m := range members {
		if id, err := uuid.Parse(m); err == nil {
			ids = append(ids, id)
		}
	}
	novels, err := s.novelRepo.FindPublishedByIDs(ids)
	return novels, total, err
}
