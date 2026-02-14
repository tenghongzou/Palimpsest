package service

import (
	"github.com/meilisearch/meilisearch-go"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/repository"
)

type SearchService struct {
	meili    *meilisearch.Client
	novelRepo *repository.NovelRepository
}

func NewSearchService(meili *meilisearch.Client, novelRepo *repository.NovelRepository) *SearchService {
	return &SearchService{meili: meili, novelRepo: novelRepo}
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
	}

	// Build filter string
	var filterParts []string
	if status, ok := filters["status"]; ok && status != "" {
		filterParts = append(filterParts, "status = \""+status+"\"")
	}
	if lang, ok := filters["language"]; ok && lang != "" {
		filterParts = append(filterParts, "language = \""+lang+"\"")
	}
	if len(filterParts) > 0 {
		combined := filterParts[0]
		for i := 1; i < len(filterParts); i++ {
			combined += " AND " + filterParts[i]
		}
		searchReq.Filter = combined
	}

	resp, err := s.meili.Index("novels").Search(query, searchReq)
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

func convertHits(hits []interface{}) []map[string]interface{} {
	result := make([]map[string]interface{}, 0, len(hits))
	for _, hit := range hits {
		if m, ok := hit.(map[string]interface{}); ok {
			result = append(result, m)
		}
	}
	return result
}

func (s *SearchService) HotKeywords() ([]model.SearchKeyword, error) {
	var keywords []model.SearchKeyword
	// This would query from a search_keywords table; for now return empty
	return keywords, nil
}

func (s *SearchService) IndexNovel(novel *model.Novel) error {
	doc := map[string]interface{}{
		"id":            novel.ID.String(),
		"title":         novel.Title,
		"author_name":   novel.AuthorName,
		"description":   novel.Description,
		"status":        novel.Status,
		"language":      novel.Language,
		"total_words":   novel.TotalWords,
		"view_count":    novel.ViewCount,
		"avg_rating":    novel.AvgRating,
		"is_published":  novel.IsPublished,
	}

	_, err := s.meili.Index("novels").AddDocuments([]map[string]interface{}{doc}, "id")
	return err
}
