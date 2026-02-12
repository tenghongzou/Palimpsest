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
