package repository

import (
	"github.com/google/uuid"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"gorm.io/gorm"
)

type NovelRepository struct {
	db *gorm.DB
}

func NewNovelRepository(db *gorm.DB) *NovelRepository {
	return &NovelRepository{db: db}
}

func (r *NovelRepository) List(page, pageSize int, categoryID *int, status, language, sortBy string) ([]model.Novel, int64, error) {
	var novels []model.Novel
	var total int64

	q := r.db.Model(&model.Novel{}).Where("is_published = ?", true)

	if categoryID != nil {
		q = q.Joins("JOIN novel_categories ON novel_categories.novel_id = novels.id").
			Where("novel_categories.category_id = ?", *categoryID)
	}
	if status != "" {
		q = q.Where("status = ?", status)
	}
	if language != "" {
		q = q.Where("language = ?", language)
	}

	q.Count(&total)

	switch sortBy {
	case "popular":
		q = q.Order("view_count DESC")
	case "rating":
		q = q.Order("avg_rating DESC")
	case "words":
		q = q.Order("total_words DESC")
	default:
		q = q.Order("latest_chapter_at DESC NULLS LAST")
	}

	err := q.Offset((page - 1) * pageSize).Limit(pageSize).
		Preload("Categories").Preload("Tags").
		Find(&novels).Error
	return novels, total, err
}

func (r *NovelRepository) FindByID(id uuid.UUID) (*model.Novel, error) {
	var novel model.Novel
	err := r.db.Preload("Categories").Preload("Tags").First(&novel, "id = ?", id).Error
	return &novel, err
}

func (r *NovelRepository) ListChapters(novelID uuid.UUID, order string) ([]model.Chapter, error) {
	var chapters []model.Chapter
	// The table of contents never needs chapter bodies, which can be large.
	q := r.db.Omit("content").Where("novel_id = ? AND is_published = ?", novelID, true)
	if order == "desc" {
		q = q.Order("chapter_number DESC")
	} else {
		q = q.Order("chapter_number ASC")
	}
	err := q.Find(&chapters).Error
	return chapters, err
}

func (r *NovelRepository) FindChapter(id uuid.UUID) (*model.Chapter, error) {
	var chapter model.Chapter
	err := r.db.First(&chapter, "id = ?", id).Error
	return &chapter, err
}

func (r *NovelRepository) ListCategories() ([]model.Category, error) {
	var categories []model.Category
	err := r.db.Where("is_active = ? AND parent_id IS NULL", true).
		Preload("Children").
		Order("sort_order ASC").
		Find(&categories).Error
	return categories, err
}

// ListPublishedBatch returns published novels ordered by id, for bulk jobs such as reindexing.
func (r *NovelRepository) ListPublishedBatch(offset, limit int) ([]model.Novel, error) {
	var novels []model.Novel
	err := r.db.Where("is_published = ?", true).Order("id").Offset(offset).Limit(limit).Find(&novels).Error
	return novels, err
}

func (r *NovelRepository) Create(novel *model.Novel) error {
	return r.db.Create(novel).Error
}

func (r *NovelRepository) Update(novel *model.Novel) error {
	return r.db.Save(novel).Error
}

func (r *NovelRepository) Delete(id uuid.UUID) error {
	return r.db.Delete(&model.Novel{}, "id = ?", id).Error
}

func (r *NovelRepository) CreateChapter(chapter *model.Chapter) error {
	return r.db.Create(chapter).Error
}

func (r *NovelRepository) UpdateChapter(chapter *model.Chapter) error {
	return r.db.Save(chapter).Error
}

func (r *NovelRepository) DeleteChapter(id uuid.UUID) error {
	return r.db.Delete(&model.Chapter{}, "id = ?", id).Error
}

// FindPublishedChapter returns a chapter readers may see: published, in a
// published novel that has not been deleted.
func (r *NovelRepository) FindPublishedChapter(id uuid.UUID) (*model.Chapter, error) {
	var chapter model.Chapter
	err := r.db.Joins("JOIN novels ON novels.id = chapters.novel_id").
		Where("chapters.id = ? AND chapters.is_published AND novels.is_published AND novels.deleted_at IS NULL", id).
		First(&chapter).Error
	return &chapter, err
}

// AdjacentChapters returns the published chapters just before and after number.
func (r *NovelRepository) AdjacentChapters(novelID uuid.UUID, number int) (prev, next *model.ChapterRef, err error) {
	find := func(cmp, order string) (*model.ChapterRef, error) {
		var refs []model.ChapterRef
		err := r.db.Model(&model.Chapter{}).Select("id, title, chapter_number").
			Where("novel_id = ? AND is_published AND chapter_number "+cmp+" ?", novelID, number).
			Order("chapter_number " + order).Limit(1).Find(&refs).Error
		if err != nil || len(refs) == 0 {
			return nil, err
		}
		return &refs[0], nil
	}
	if prev, err = find("<", "DESC"); err != nil {
		return nil, nil, err
	}
	next, err = find(">", "ASC")
	return prev, next, err
}

// FindCategoryBySlug looks up an active category by its slug.
func (r *NovelRepository) FindCategoryBySlug(slug string) (*model.Category, error) {
	var category model.Category
	err := r.db.First(&category, "slug = ?", slug).Error
	return &category, err
}

// FindPublishedByIDs returns published novels in the order of ids.
func (r *NovelRepository) FindPublishedByIDs(ids []uuid.UUID) ([]model.Novel, error) {
	var found []model.Novel
	if len(ids) == 0 {
		return found, nil
	}
	if err := r.db.Where("id IN ? AND is_published", ids).Preload("Categories").Preload("Tags").Find(&found).Error; err != nil {
		return nil, err
	}
	byID := make(map[uuid.UUID]model.Novel, len(found))
	for _, n := range found {
		byID[n.ID] = n
	}
	novels := make([]model.Novel, 0, len(found))
	for _, id := range ids {
		if n, ok := byID[id]; ok {
			novels = append(novels, n)
		}
	}
	return novels, nil
}

// IncrementViews adds one view to a novel.
func (r *NovelRepository) IncrementViews(novelID uuid.UUID) error {
	return r.db.Model(&model.Novel{}).Where("id = ?", novelID).
		UpdateColumn("view_count", gorm.Expr("view_count + 1")).Error
}

// RefreshStats recomputes a novel's chapter count, word count and latest
// chapter from its published chapters.
func (r *NovelRepository) RefreshStats(novelID uuid.UUID) error {
	return r.db.Exec(`
		UPDATE novels SET
			total_chapters = s.cnt,
			total_words = s.words,
			latest_chapter_id = l.id,
			latest_chapter_title = COALESCE(l.title, ''),
			latest_chapter_at = l.published_at
		FROM (
			SELECT COUNT(*) AS cnt, COALESCE(SUM(word_count), 0) AS words
			FROM chapters WHERE novel_id = ? AND is_published
		) s
		LEFT JOIN LATERAL (
			SELECT id, title, COALESCE(published_at, created_at) AS published_at
			FROM chapters WHERE novel_id = ? AND is_published
			ORDER BY chapter_number DESC LIMIT 1
		) l ON true
		WHERE novels.id = ?`, novelID, novelID, novelID).Error
}
