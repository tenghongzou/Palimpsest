package service

// SearchService handles full-text search via Meilisearch.
type SearchService struct {
	// TODO: inject Meilisearch client
}

func NewSearchService() *SearchService {
	return &SearchService{}
}

// TODO: implement Search, Suggestions, HotKeywords, IndexNovel
