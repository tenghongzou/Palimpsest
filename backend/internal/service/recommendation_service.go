package service

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"math"
	"sort"
	"time"

	"github.com/google/uuid"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/repository"
	"gorm.io/gorm"
)

const (
	recommendationTTL = 10 * time.Minute
	// Limits of Recommend and Similar; out of range values are clamped.
	DefaultRecommendationLimit = 12
	MaxRecommendationLimit     = 30
	DefaultSimilarLimit        = 6
	MaxSimilarLimit            = 20

	// candidatePool bounds how many matching novels are scored in Go.
	candidatePool = 300
	// historyWindow is how far back reading history counts as a signal.
	historyWindow = 90 * 24 * time.Hour

	// Signal weights per novel the reader interacted with.
	shelfWeight   = 3.0
	historyWeight = 2.0
	reviewWeight  = 3.0
	minLikedScore = 4.0

	// Score contributions of a personalised candidate. Category and author
	// are scaled by the strongest preference; tags add up to tagCap.
	categoryScore = 3.0
	tagScore      = 1.0
	tagCap        = 2.0
	authorScore   = 2.5

	// Scores of a similar novel per shared feature.
	similarCategoryScore = 3.0
	similarTagScore      = 1.0
	similarAuthorScore   = 2.0

	// popularityScale keeps popularity a tie-breaker next to the signals.
	popularityScale = 0.02
)

// Reason types of a recommendation.
const (
	ReasonCategory = "category"
	ReasonTag      = "tag"
	ReasonAuthor   = "author"
	ReasonPopular  = "popular"
)

// RecommendationReason says why a novel is recommended; Value is the
// category, tag or author name, empty for popular.
type RecommendationReason struct {
	Type  string `json:"type"`
	Value string `json:"value"`
}

// Recommendation is a recommended novel with its reason.
type Recommendation struct {
	Novel  model.Novel          `json:"novel"`
	Reason RecommendationReason `json:"reason"`
}

// Recommendations is the recommendation list; Personalized is false when it
// holds popular novels only.
type Recommendations struct {
	Personalized bool             `json:"personalized"`
	Items        []Recommendation `json:"items"`
}

type RecommendationService struct {
	repo      *repository.RecommendationRepository
	novelRepo *repository.NovelRepository
	// cache is optional; nil disables caching.
	cache *repository.CacheRepository
	now   func() time.Time
}

func NewRecommendationService(repo *repository.RecommendationRepository, novelRepo *repository.NovelRepository, cache *repository.CacheRepository) *RecommendationService {
	return &RecommendationService{repo: repo, novelRepo: novelRepo, cache: cache, now: time.Now}
}

func recommendationsCacheKey(userID *uuid.UUID, limit int) string {
	owner := "anon"
	if userID != nil {
		owner = userID.String()
	}
	return fmt.Sprintf("palimpsest:recommendations:%s:%d", owner, limit)
}

func similarCacheKey(novelID uuid.UUID, limit int) string {
	return fmt.Sprintf("palimpsest:novel:%s:similar:%d", novelID, limit)
}

// clampLimit returns limit within [1, upper].
func clampLimit(limit, upper int) int {
	return max(1, min(upper, limit))
}

func (s *RecommendationService) cached(key string, dst interface{}) bool {
	if s.cache == nil {
		return false
	}
	data, err := s.cache.Get(context.Background(), key)
	return err == nil && data != "" && json.Unmarshal([]byte(data), dst) == nil
}

func (s *RecommendationService) store(key string, v interface{}) {
	if s.cache == nil {
		return
	}
	if data, err := json.Marshal(v); err == nil {
		_ = s.cache.Set(context.Background(), key, string(data), recommendationTTL)
	}
}

// InvalidateUser drops a user's cached recommendations, e.g. after their
// bookshelf changed.
func (s *RecommendationService) InvalidateUser(userID uuid.UUID) {
	if s.cache == nil {
		return
	}
	keys := make([]string, 0, MaxRecommendationLimit)
	for limit := 1; limit <= MaxRecommendationLimit; limit++ {
		keys = append(keys, recommendationsCacheKey(&userID, limit))
	}
	if err := s.cache.Delete(context.Background(), keys...); err != nil {
		log.Printf("cache: failed to drop recommendations of %s: %v", userID, err)
	}
}

// Recommend returns up to limit novels for a user (nil for anonymous).
func (s *RecommendationService) Recommend(userID *uuid.UUID, limit int) (*Recommendations, error) {
	limit = clampLimit(limit, MaxRecommendationLimit)
	key := recommendationsCacheKey(userID, limit)
	var recs Recommendations
	if s.cached(key, &recs) {
		return &recs, nil
	}

	var res *Recommendations
	var err error
	if userID == nil {
		res, err = s.popular(nil, nil, limit)
	} else {
		res, err = s.personalized(*userID, limit)
	}
	if err != nil {
		return nil, err
	}
	s.store(key, res)
	return res, nil
}

// popular lists popular novels, leaving out ones the user has seen and exclude.
func (s *RecommendationService) popular(userID *uuid.UUID, exclude []uuid.UUID, limit int) (*Recommendations, error) {
	novels, err := s.repo.Popular(repository.CandidateFilter{ExcludeUser: userID, ExcludeIDs: exclude, Limit: limit})
	if err != nil {
		return nil, err
	}
	res := &Recommendations{Items: make([]Recommendation, 0, len(novels))}
	for _, n := range novels {
		res.Items = append(res.Items, Recommendation{Novel: n, Reason: RecommendationReason{Type: ReasonPopular, Value: ""}})
	}
	return res, nil
}

// preferences are a reader's aggregated weights per category, tag and author.
type preferences struct {
	categories    map[int]float64
	tags          map[int]float64
	authors       map[string]float64
	categoryNames map[int]string
	tagNames      map[int]string
}

func (p *preferences) empty() bool {
	return len(p.categories) == 0 && len(p.tags) == 0 && len(p.authors) == 0
}

// readerPreferences builds weighted preferences from the bookshelf, recent
// reading history and well rated reviews.
func (s *RecommendationService) readerPreferences(userID uuid.UUID) (*preferences, error) {
	weights := map[uuid.UUID]float64{}
	shelved, err := s.repo.ShelvedNovelIDs(userID)
	if err != nil {
		return nil, err
	}
	for _, id := range shelved {
		weights[id] += shelfWeight
	}

	now := s.now()
	history, err := s.repo.ReadingSince(userID, now.Add(-historyWindow))
	if err != nil {
		return nil, err
	}
	for _, h := range history {
		weights[h.NovelID] += historyWeight * historyFactor(now, h)
	}

	reviews, err := s.repo.ReviewsRatedAtLeast(userID, minLikedScore)
	if err != nil {
		return nil, err
	}
	for _, r := range reviews {
		weights[r.NovelID] += reviewWeight
	}

	prefs := &preferences{
		categories: map[int]float64{}, tags: map[int]float64{}, authors: map[string]float64{},
		categoryNames: map[int]string{}, tagNames: map[int]string{},
	}
	ids := make([]uuid.UUID, 0, len(weights))
	for id := range weights {
		ids = append(ids, id)
	}
	novels, err := s.repo.NovelFeatures(ids)
	if err != nil {
		return nil, err
	}
	for _, n := range novels {
		w := weights[n.ID]
		for _, c := range n.Categories {
			prefs.categories[c.ID] += w
			prefs.categoryNames[c.ID] = c.Name
		}
		for _, t := range n.Tags {
			prefs.tags[t.ID] += w
			prefs.tagNames[t.ID] = t.Name
		}
		if n.AuthorName != "" {
			prefs.authors[n.AuthorName] += w
		}
	}
	return prefs, nil
}

// historyFactor scales a reading history signal between 0.6 and 1.25: recent
// reading counts more, as does time spent (up to an hour).
func historyFactor(now time.Time, h repository.HistorySignal) float64 {
	recency := 1 - now.Sub(h.LastRead).Hours()/historyWindow.Hours()
	recency = math.Max(0, math.Min(1, recency))
	engagement := math.Min(1, float64(h.Duration)/3600)
	return (0.6 + 0.4*recency) * (1 + 0.25*engagement)
}

// popularity blends views, favorites and the review-damped rating, matching
// the order the repository uses.
func popularity(n *model.Novel) float64 {
	rc := float64(n.ReviewCount)
	return math.Log1p(float64(n.ViewCount)) + 2*math.Log1p(float64(n.FavoriteCount)) +
		n.AvgRating*rc/(rc+5)
}

type scored struct {
	novel  model.Novel
	score  float64
	reason RecommendationReason
}

// sortScored orders by score, best first, then by id for stable results.
func sortScored(list []scored) {
	sort.SliceStable(list, func(i, j int) bool {
		if list[i].score != list[j].score {
			return list[i].score > list[j].score
		}
		return list[i].novel.ID.String() < list[j].novel.ID.String()
	})
}

func maxWeight[K comparable](m map[K]float64) float64 {
	best := 0.0
	for _, w := range m {
		best = math.Max(best, w)
	}
	return best
}

func (s *RecommendationService) personalized(userID uuid.UUID, limit int) (*Recommendations, error) {
	prefs, err := s.readerPreferences(userID)
	if err != nil {
		return nil, err
	}
	if prefs.empty() {
		return s.popular(&userID, nil, limit)
	}

	filter := repository.CandidateFilter{ExcludeUser: &userID, Limit: candidatePool}
	for id := range prefs.categories {
		filter.CategoryIDs = append(filter.CategoryIDs, id)
	}
	for id := range prefs.tags {
		filter.TagIDs = append(filter.TagIDs, id)
	}
	for name := range prefs.authors {
		filter.Authors = append(filter.Authors, name)
	}
	sort.Ints(filter.CategoryIDs)
	sort.Ints(filter.TagIDs)
	sort.Strings(filter.Authors)
	candidates, err := s.repo.Candidates(filter)
	if err != nil {
		return nil, err
	}

	maxCat, maxTag, maxAuthor := maxWeight(prefs.categories), maxWeight(prefs.tags), maxWeight(prefs.authors)
	list := make([]scored, 0, len(candidates))
	for _, n := range candidates {
		if sc, ok := scoreCandidate(prefs, &n, maxCat, maxTag, maxAuthor); ok {
			list = append(list, sc)
		}
	}
	sortScored(list)
	if len(list) > limit {
		list = list[:limit]
	}

	res := &Recommendations{Personalized: len(list) > 0, Items: make([]Recommendation, 0, limit)}
	picked := make([]uuid.UUID, 0, len(list))
	for _, sc := range list {
		res.Items = append(res.Items, Recommendation{Novel: sc.novel, Reason: sc.reason})
		picked = append(picked, sc.novel.ID)
	}
	if len(res.Items) < limit {
		pad, err := s.popular(&userID, picked, limit-len(res.Items))
		if err != nil {
			return nil, err
		}
		res.Items = append(res.Items, pad.Items...)
	}
	return res, nil
}

// scoreCandidate scores a novel against the reader's preferences. The
// reason is the largest of the category, tag and author contributions.
func scoreCandidate(prefs *preferences, n *model.Novel, maxCat, maxTag, maxAuthor float64) (scored, bool) {
	var catPart, tagPart, authorPart, bestTagW float64
	var catReason, tagReason RecommendationReason
	bestCatW := 0.0
	for _, c := range n.Categories {
		if w := prefs.categories[c.ID]; w > bestCatW {
			bestCatW = w
			catReason = RecommendationReason{Type: ReasonCategory, Value: prefs.categoryNames[c.ID]}
		}
	}
	if bestCatW > 0 {
		catPart = categoryScore * bestCatW / maxCat
	}
	tagSum := 0.0
	for _, t := range n.Tags {
		w := prefs.tags[t.ID]
		tagSum += w
		if w > bestTagW {
			bestTagW = w
			tagReason = RecommendationReason{Type: ReasonTag, Value: prefs.tagNames[t.ID]}
		}
	}
	if tagSum > 0 {
		tagPart = math.Min(tagCap, tagScore*tagSum/maxTag)
	}
	if w := prefs.authors[n.AuthorName]; w > 0 && n.AuthorName != "" {
		authorPart = authorScore * w / maxAuthor
	}

	sc := scored{novel: *n, score: catPart + tagPart + authorPart + popularityScale*popularity(n)}
	switch {
	case catPart == 0 && tagPart == 0 && authorPart == 0:
		return sc, false
	case catPart >= tagPart && catPart >= authorPart:
		sc.reason = catReason
	case tagPart >= authorPart:
		sc.reason = tagReason
	default:
		sc.reason = RecommendationReason{Type: ReasonAuthor, Value: n.AuthorName}
	}
	return sc, true
}

// Similar returns published novels sharing categories, tags or the author
// with a published novel, most similar first. It returns ErrNotFound when
// the novel does not exist or is not published.
func (s *RecommendationService) Similar(novelID uuid.UUID, limit int) ([]model.Novel, error) {
	limit = clampLimit(limit, MaxSimilarLimit)
	key := similarCacheKey(novelID, limit)
	novels := []model.Novel{}
	if s.cached(key, &novels) && novels != nil {
		return novels, nil
	}

	novel, err := s.novelRepo.FindByID(novelID)
	if errors.Is(err, gorm.ErrRecordNotFound) || (err == nil && !novel.IsPublished) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}

	filter := repository.CandidateFilter{ExcludeIDs: []uuid.UUID{novel.ID}, Limit: candidatePool}
	categories := map[int]bool{}
	for _, c := range novel.Categories {
		categories[c.ID] = true
		filter.CategoryIDs = append(filter.CategoryIDs, c.ID)
	}
	tags := map[int]bool{}
	for _, t := range novel.Tags {
		tags[t.ID] = true
		filter.TagIDs = append(filter.TagIDs, t.ID)
	}
	if novel.AuthorName != "" {
		filter.Authors = []string{novel.AuthorName}
	}
	candidates, err := s.repo.Candidates(filter)
	if err != nil {
		return nil, err
	}

	list := make([]scored, 0, len(candidates))
	for _, n := range candidates {
		score := 0.0
		for _, c := range n.Categories {
			if categories[c.ID] {
				score += similarCategoryScore
			}
		}
		for _, t := range n.Tags {
			if tags[t.ID] {
				score += similarTagScore
			}
		}
		if novel.AuthorName != "" && n.AuthorName == novel.AuthorName {
			score += similarAuthorScore
		}
		if score == 0 {
			continue
		}
		list = append(list, scored{novel: n, score: score + popularityScale*popularity(&n)})
	}
	sortScored(list)
	if len(list) > limit {
		list = list[:limit]
	}
	novels = make([]model.Novel, 0, len(list))
	for _, sc := range list {
		novels = append(novels, sc.novel)
	}
	s.store(key, novels)
	return novels, nil
}
