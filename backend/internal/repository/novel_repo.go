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
		q = q.Order("latest_chapter_at DESC")
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
	q := r.db.Where("novel_id = ? AND is_published = ?", novelID, true)
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
