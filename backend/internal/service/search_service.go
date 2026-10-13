package service

import (
	"context"
	"log"
	"strings"
	"unicode/utf8"

	"github.com/meilisearch/meilisearch-go"
	"github.com/redis/go-redis/v9"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/repository"
)

const (
	novelIndex       = "novels"
	hotKeywordsKey   = "palimpsest:search:hot_keywords"
	hotKeywordsLimit = 10
	// hotKeywordsKeep bounds the sorted set so it cannot grow without limit.
	hotKeywordsKeep  = 1000
	maxKeywordLength = 50
)

// Allowed values for search filters. Filter values are interpolated into a
// Meilisearch filter expression, so only known values may pass through.
var (
	searchStatuses  = map[string]bool{"ongoing": true, "completed": true, "hiatus": true}
	searchLanguages = map[string]bool{"zh-TW": true, "zh-CN": true, "en": true}
)

type SearchService struct {
	meili     *meilisearch.Client
	rdb       *redis.Client
	novelRepo *repository.NovelRepository
}

func NewSearchService(meili *meilisearch.Client, rdb *redis.Client, novelRepo *repository.NovelRepository) *SearchService {
	return &SearchService{meili: meili, rdb: rdb, novelRepo: novelRepo}
}

type SearchResult struct {
	Hits             []map[string]interface{} `json:"hits"`
	Query            string                   `json:"query"`
	ProcessingTimeMs int64                    `json:"processing_time_ms"`
	EstimatedTotal   int64                    `json:"estimated_total"`
}

func (s *SearchService) Search(query string, page, pageSize int, filters map[string]string) (*SearchResult, error) {
	searchReq := &meilisearch.SearchRequest{
		Limit:  int64(pageSize),
		Offset: int64((page - 1) * pageSize),
		Filter: buildSearchFilter(filters),
	}

	resp, err := s.meili.Index(novelIndex).Search(query, searchReq)
	if err != nil {
		return nil, err
	}

	return &SearchResult{
		Hits:             convertHits(resp.Hits),
		Query:            query,
		ProcessingTimeMs: resp.ProcessingTimeMs,
		EstimatedTotal:   resp.EstimatedTotalHits,
	}, nil
}

// buildSearchFilter always restricts results to published novels and adds
// whitelisted status/language filters.
func buildSearchFilter(filters map[string]string) string {
	parts := []string{"is_published = true"}
	if status := filters["status"]; searchStatuses[status] {
		parts = append(parts, `status = "`+status+`"`)
	}
	if lang := filters["language"]; searchLanguages[lang] {
		parts = append(parts, `language = "`+lang+`"`)
	}
	return strings.Join(parts, " AND ")
}

func convertHits(hits []interface{}) []map[string]interface{} {
	result := make([]map[string]interface{}, 0, len(hits))
	for _, hit := range hits {
		if m, ok := hit.(map[string]interface{}); ok {
			result = append(result, m)
		}
	}
	return result
}

// RecordKeyword counts a search query towards the hot keyword ranking.
func (s *SearchService) RecordKeyword(query string) {
	keyword := normalizeKeyword(query)
	if keyword == "" || s.rdb == nil {
		return
	}
	ctx := context.Background()
	pipe := s.rdb.Pipeline()
	pipe.ZIncrBy(ctx, hotKeywordsKey, 1, keyword)
	pipe.ZRemRangeByRank(ctx, hotKeywordsKey, 0, -hotKeywordsKeep-1)
	if _, err := pipe.Exec(ctx); err != nil {
		log.Printf("search: failed to record keyword: %v", err)
	}
}

func normalizeKeyword(query string) string {
	keyword := strings.Join(strings.Fields(query), " ")
	if utf8.RuneCountInString(keyword) > maxKeywordLength {
		return ""
	}
	return keyword
}

// HotKeywords returns the most searched keywords.
func (s *SearchService) HotKeywords() ([]string, error) {
	if s.rdb == nil {
		return []string{}, nil
	}
	keywords, err := s.rdb.ZRevRange(context.Background(), hotKeywordsKey, 0, hotKeywordsLimit-1).Result()
	if err != nil {
		return nil, err
	}
	return keywords, nil
}

// EnsureIndex configures the novel index so filters and searchable fields work.
func (s *SearchService) EnsureIndex() error {
	_, err := s.meili.Index(novelIndex).UpdateSettings(&meilisearch.Settings{
		SearchableAttributes: []string{"title", "author_name", "description"},
		FilterableAttributes: []string{"is_published", "status", "language"},
		SortableAttributes:   []string{"view_count", "avg_rating", "total_words"},
	})
	return err
}

// ReindexAll pushes every published novel into the search index.
func (s *SearchService) ReindexAll() (int, error) {
	const batchSize = 500
	indexed := 0
	for offset := 0; ; offset += batchSize {
		novels, err := s.novelRepo.ListPublishedBatch(offset, batchSize)
		if err != nil {
			return indexed, err
		}
		if len(novels) == 0 {
			return indexed, nil
		}
		docs := make([]map[string]interface{}, 0, len(novels))
		for i := range novels {
			docs = append(docs, novelDocument(&novels[i]))
		}
		if _, err := s.meili.Index(novelIndex).AddDocuments(docs, "id"); err != nil {
			return indexed, err
		}
		indexed += len(novels)
	}
}

// SyncNovel keeps the search index in line with a novel after it changes:
// published novels are (re)indexed, everything else is removed.
func (s *SearchService) SyncNovel(novel *model.Novel) error {
	if !novel.IsPublished {
		return s.RemoveNovel(novel.ID.String())
	}
	return s.IndexNovel(novel)
}

func (s *SearchService) IndexNovel(novel *model.Novel) error {
	_, err := s.meili.Index(novelIndex).AddDocuments([]map[string]interface{}{novelDocument(novel)}, "id")
	return err
}

func (s *SearchService) RemoveNovel(id string) error {
	_, err := s.meili.Index(novelIndex).DeleteDocument(id)
	return err
}

func novelDocument(novel *model.Novel) map[string]interface{} {
	return map[string]interface{}{
		"id":                   novel.ID.String(),
		"title":                novel.Title,
		"author_name":          novel.AuthorName,
		"description":          novel.Description,
		"cover_url":            novel.CoverURL,
		"status":               novel.Status,
		"language":             novel.Language,
		"total_words":          novel.TotalWords,
		"total_chapters":       novel.TotalChapters,
		"view_count":           novel.ViewCount,
		"favorite_count":       novel.FavoriteCount,
		"avg_rating":           novel.AvgRating,
		"latest_chapter_title": novel.LatestChapterTitle,
		"is_published":         novel.IsPublished,
	}
}
