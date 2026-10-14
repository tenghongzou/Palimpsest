package service

import (
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// maxBookmarkSync bounds one offline sync request.
const maxBookmarkSync = 500

type BookmarkService struct {
	db *gorm.DB
}

func NewBookmarkService(db *gorm.DB) *BookmarkService {
	return &BookmarkService{db: db}
}

// BookmarkInput creates or replaces a bookmark. ID may be set by an offline
// client so the bookmark keeps its identity when it is synced later.
type BookmarkInput struct {
	ID             *uuid.UUID `json:"id"`
	ChapterID      uuid.UUID  `json:"chapter_id" binding:"required"`
	ParagraphIndex int        `json:"paragraph_index" binding:"min=0"`
	Note           string     `json:"note" binding:"max=500"`
	CreatedAt      *time.Time `json:"created_at"`
}

func (s *BookmarkService) withChapter(db *gorm.DB) *gorm.DB {
	return db.Preload("Chapter", func(db *gorm.DB) *gorm.DB {
		return db.Select("id, novel_id, title, chapter_number")
	}).Preload("Novel", func(db *gorm.DB) *gorm.DB {
		return db.Unscoped()
	})
}

func (s *BookmarkService) List(userID uuid.UUID, novelID *uuid.UUID) ([]model.Bookmark, error) {
	bookmarks := []model.Bookmark{}
	q := s.withChapter(s.db).Where("user_id = ?", userID)
	if novelID != nil {
		q = q.Where("novel_id = ?", *novelID)
	}
	err := q.Order("created_at DESC").Find(&bookmarks).Error
	return bookmarks, err
}

// Create adds a bookmark; the novel is taken from the chapter.
func (s *BookmarkService) Create(userID uuid.UUID, in BookmarkInput) (*model.Bookmark, error) {
	var created *model.Bookmark
	err := s.db.Transaction(func(tx *gorm.DB) error {
		var err error
		created, err = s.upsert(tx, userID, in)
		return err
	})
	if err != nil {
		return nil, err
	}
	return s.get(userID, created.ID)
}

func (s *BookmarkService) upsert(tx *gorm.DB, userID uuid.UUID, in BookmarkInput) (*model.Bookmark, error) {
	var chapter model.Chapter
	err := tx.Select("id, novel_id").First(&chapter, "id = ?", in.ChapterID).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}

	now := time.Now()
	b := &model.Bookmark{
		UserID: userID, NovelID: chapter.NovelID, ChapterID: chapter.ID,
		ParagraphIndex: in.ParagraphIndex, Note: in.Note, CreatedAt: now, SyncedAt: now,
	}
	if in.CreatedAt != nil && in.CreatedAt.Before(now) {
		b.CreatedAt = *in.CreatedAt
	}
	if in.ID != nil {
		b.ID = *in.ID
		// Never let one user's id overwrite another user's bookmark.
		var existing []model.Bookmark
		if err := tx.Select("user_id").Where("id = ?", b.ID).Limit(1).Find(&existing).Error; err != nil {
			return nil, err
		}
		if len(existing) > 0 && existing[0].UserID != userID {
			return nil, ErrForbidden
		}
	}
	err = tx.Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "id"}},
		DoUpdates: clause.AssignmentColumns([]string{"chapter_id", "novel_id", "paragraph_index", "note", "synced_at"}),
	}).Create(b).Error
	return b, err
}

func (s *BookmarkService) get(userID, id uuid.UUID) (*model.Bookmark, error) {
	var b model.Bookmark
	err := s.withChapter(s.db).First(&b, "id = ? AND user_id = ?", id, userID).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	return &b, err
}

// BookmarkPatch changes a bookmark's note or position; nil means unchanged.
type BookmarkPatch struct {
	ParagraphIndex *int    `json:"paragraph_index" binding:"omitempty,min=0"`
	Note           *string `json:"note" binding:"omitempty,max=500"`
}

func (s *BookmarkService) Update(userID, id uuid.UUID, p BookmarkPatch) (*model.Bookmark, error) {
	updates := map[string]interface{}{"synced_at": time.Now()}
	if p.ParagraphIndex != nil {
		updates["paragraph_index"] = *p.ParagraphIndex
	}
	if p.Note != nil {
		updates["note"] = *p.Note
	}
	res := s.db.Model(&model.Bookmark{}).Where("id = ? AND user_id = ?", id, userID).Updates(updates)
	if res.Error != nil {
		return nil, res.Error
	}
	if res.RowsAffected == 0 {
		return nil, ErrNotFound
	}
	return s.get(userID, id)
}

func (s *BookmarkService) Delete(userID, id uuid.UUID) error {
	res := s.db.Where("id = ? AND user_id = ?", id, userID).Delete(&model.Bookmark{})
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return ErrNotFound
	}
	return nil
}

// BookmarkSync carries bookmarks changed while offline.
type BookmarkSync struct {
	Upserts []BookmarkInput `json:"upserts" binding:"dive"`
	Deletes []uuid.UUID     `json:"deletes"`
}

// Sync applies offline changes and returns the user's full bookmark list.
// Bookmarks on chapters that no longer exist are skipped.
func (s *BookmarkService) Sync(userID uuid.UUID, in BookmarkSync) ([]model.Bookmark, error) {
	if len(in.Upserts)+len(in.Deletes) > maxBookmarkSync {
		return nil, ErrConflict
	}
	err := s.db.Transaction(func(tx *gorm.DB) error {
		if len(in.Deletes) > 0 {
			if err := tx.Where("user_id = ? AND id IN ?", userID, in.Deletes).Delete(&model.Bookmark{}).Error; err != nil {
				return err
			}
		}
		for _, b := range in.Upserts {
			if b.ID == nil {
				id := uuid.New()
				b.ID = &id
			}
			if _, err := s.upsert(tx, userID, b); err != nil && !errors.Is(err, ErrNotFound) && !errors.Is(err, ErrForbidden) {
				return err
			}
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return s.List(userID, nil)
}
