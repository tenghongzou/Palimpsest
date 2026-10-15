package repository

import (
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"gorm.io/gorm"
)

// popularityOrder ranks novels by a blend of views, favorites and rating,
// with the rating damped for novels that have few reviews. Ties break by id
// so results are stable.
const popularityOrder = "ln(1 + novels.view_count) + 2 * ln(1 + novels.favorite_count) + " +
	"novels.avg_rating::float8 * novels.review_count / (novels.review_count + 5.0) DESC, novels.id ASC"

// RecommendationRepository loads the reading signals and candidate novels
// behind recommendations and similar-novel lists.
type RecommendationRepository struct {
	db *gorm.DB
}

func NewRecommendationRepository(db *gorm.DB) *RecommendationRepository {
	return &RecommendationRepository{db: db}
}

// HistorySignal summarises a user's recent reading of one novel.
type HistorySignal struct {
	NovelID  uuid.UUID
	LastRead time.Time
	Duration int
	Chapters int
}

// ReviewSignal is a rating the user gave a novel.
type ReviewSignal struct {
	NovelID uuid.UUID
	Rating  float64
}

// ShelvedNovelIDs returns the novels on a user's bookshelf.
func (r *RecommendationRepository) ShelvedNovelIDs(userID uuid.UUID) ([]uuid.UUID, error) {
	var ids []uuid.UUID
	err := r.db.Model(&model.BookshelfItem{}).Where("user_id = ?", userID).
		Order("novel_id").Pluck("novel_id", &ids).Error
	return ids, err
}

// ReadingSince returns the novels a user read since a time, one row per novel.
func (r *RecommendationRepository) ReadingSince(userID uuid.UUID, since time.Time) ([]HistorySignal, error) {
	var rows []HistorySignal
	err := r.db.Model(&model.ReadingHistory{}).
		Select("novel_id, MAX(read_at) AS last_read, COALESCE(SUM(duration), 0) AS duration, COUNT(*) AS chapters").
		Where("user_id = ? AND read_at >= ?", userID, since).
		Group("novel_id").Order("novel_id").Scan(&rows).Error
	return rows, err
}

// ReviewsRatedAtLeast returns the user's reviews rated min or more.
func (r *RecommendationRepository) ReviewsRatedAtLeast(userID uuid.UUID, min float64) ([]ReviewSignal, error) {
	var rows []ReviewSignal
	err := r.db.Model(&model.Review{}).Select("novel_id, rating").
		Where("user_id = ? AND rating >= ?", userID, min).Order("novel_id").Scan(&rows).Error
	return rows, err
}

// NovelFeatures returns the author, categories and tags of novels, including
// ones since unpublished or deleted: they still describe the reader's taste.
func (r *RecommendationRepository) NovelFeatures(ids []uuid.UUID) ([]model.Novel, error) {
	var novels []model.Novel
	if len(ids) == 0 {
		return novels, nil
	}
	err := r.db.Unscoped().Select("id, author_name").Where("id IN ?", ids).
		Preload("Categories").Preload("Tags").Find(&novels).Error
	return novels, err
}

// CandidateFilter selects published novels for recommendation scoring.
type CandidateFilter struct {
	// A novel matches when it has one of these categories or tags or is by
	// one of these authors. Candidates ignores filters that are all empty.
	CategoryIDs []int
	TagIDs      []int
	Authors     []string
	// ExcludeUser drops novels this user has shelved, read or reviewed.
	ExcludeUser *uuid.UUID
	// ExcludeIDs drops these novels.
	ExcludeIDs []uuid.UUID
	Limit      int
}

func (r *RecommendationRepository) published(f CandidateFilter) *gorm.DB {
	q := r.db.Model(&model.Novel{}).Where("novels.is_published")
	if f.ExcludeUser != nil {
		u := *f.ExcludeUser
		q = q.Where("NOT EXISTS (SELECT 1 FROM bookshelf_items b WHERE b.user_id = ? AND b.novel_id = novels.id)", u).
			Where("NOT EXISTS (SELECT 1 FROM reading_history h WHERE h.user_id = ? AND h.novel_id = novels.id)", u).
			Where("NOT EXISTS (SELECT 1 FROM reading_progresses p WHERE p.user_id = ? AND p.novel_id = novels.id)", u).
			Where("NOT EXISTS (SELECT 1 FROM reviews rv WHERE rv.user_id = ? AND rv.novel_id = novels.id)", u)
	}
	if len(f.ExcludeIDs) > 0 {
		q = q.Where("novels.id NOT IN ?", f.ExcludeIDs)
	}
	return q.Order(popularityOrder).Limit(f.Limit).Preload("Categories").Preload("Tags")
}

// Candidates returns published novels sharing a category, tag or author
// with the filter, most popular first. It returns none when the filter has
// nothing to match.
func (r *RecommendationRepository) Candidates(f CandidateFilter) ([]model.Novel, error) {
	novels := []model.Novel{}
	var conds []string
	var args []interface{}
	if len(f.CategoryIDs) > 0 {
		conds = append(conds, "EXISTS (SELECT 1 FROM novel_categories nc WHERE nc.novel_id = novels.id AND nc.category_id IN ?)")
		args = append(args, f.CategoryIDs)
	}
	if len(f.TagIDs) > 0 {
		conds = append(conds, "EXISTS (SELECT 1 FROM novel_tags nt WHERE nt.novel_id = novels.id AND nt.tag_id IN ?)")
		args = append(args, f.TagIDs)
	}
	if len(f.Authors) > 0 {
		conds = append(conds, "novels.author_name IN ?")
		args = append(args, f.Authors)
	}
	if len(conds) == 0 || f.Limit <= 0 {
		return novels, nil
	}
	err := r.published(f).Where("("+strings.Join(conds, " OR ")+")", args...).Find(&novels).Error
	return novels, err
}

// Popular returns the most popular published novels, ignoring the
// category, tag and author filters.
func (r *RecommendationRepository) Popular(f CandidateFilter) ([]model.Novel, error) {
	novels := []model.Novel{}
	if f.Limit <= 0 {
		return novels, nil
	}
	err := r.published(f).Find(&novels).Error
	return novels, err
}
