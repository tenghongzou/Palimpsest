package repository

import (
	"github.com/google/uuid"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"gorm.io/gorm"
)

type BookshelfRepository struct {
	db *gorm.DB
}

func NewBookshelfRepository(db *gorm.DB) *BookshelfRepository {
	return &BookshelfRepository{db: db}
}

func (r *BookshelfRepository) List(userID uuid.UUID, sortBy string) ([]model.BookshelfItem, error) {
	var items []model.BookshelfItem
	q := r.db.Where("user_id = ?", userID).Preload("Novel")
	switch sortBy {
	case "added":
		q = q.Order("added_at DESC")
	case "title":
		q = q.Joins("JOIN novels ON novels.id = bookshelf_items.novel_id").Order("novels.title ASC")
	default:
		q = q.Order("added_at DESC")
	}
	err := q.Find(&items).Error
	return items, err
}

func (r *BookshelfRepository) Add(item *model.BookshelfItem) error {
	return r.db.Create(item).Error
}

func (r *BookshelfRepository) Remove(userID, novelID uuid.UUID) error {
	return r.db.Where("user_id = ? AND novel_id = ?", userID, novelID).Delete(&model.BookshelfItem{}).Error
}
