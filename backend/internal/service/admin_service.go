package service

import (
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// ErrHasChildren is returned when deleting a category that still has subcategories.
var ErrHasChildren = errors.New("category has subcategories")

// AdminService backs the admin console: catalogue maintenance and statistics.
type AdminService struct {
	db *gorm.DB
}

func NewAdminService(db *gorm.DB) *AdminService {
	return &AdminService{db: db}
}

// AdminNovelFilter narrows the admin novel list.
type AdminNovelFilter struct {
	Query     string
	Status    string
	Published *bool
}

func (s *AdminService) ListNovels(f AdminNovelFilter, page, pageSize int) ([]model.Novel, int64, error) {
	novels := []model.Novel{}
	var total int64
	q := s.db.Model(&model.Novel{})
	if f.Query != "" {
		like := "%" + strings.NewReplacer(`\`, `\\`, "%", `\%`, "_", `\_`).Replace(f.Query) + "%"
		q = q.Where("title ILIKE ? OR author_name ILIKE ?", like, like)
	}
	if f.Status != "" {
		q = q.Where("status = ?", f.Status)
	}
	if f.Published != nil {
		q = q.Where("is_published = ?", *f.Published)
	}
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	err := q.Preload("Categories").Preload("Tags").Order("created_at DESC").
		Offset(offset(page, pageSize)).Limit(pageSize).Find(&novels).Error
	return novels, total, err
}

// SetTaxonomy replaces a novel's categories and/or tags; nil leaves them as they are.
func (s *AdminService) SetTaxonomy(novel *model.Novel, categoryIDs *[]int, tagNames *[]string) error {
	return s.db.Transaction(func(tx *gorm.DB) error {
		if categoryIDs != nil {
			categories := []model.Category{}
			if len(*categoryIDs) > 0 {
				if err := tx.Where("id IN ?", *categoryIDs).Find(&categories).Error; err != nil {
					return err
				}
				if len(categories) != len(uniqueInts(*categoryIDs)) {
					return ErrNotFound
				}
			}
			if err := tx.Model(novel).Association("Categories").Replace(categories); err != nil {
				return err
			}
		}
		if tagNames != nil {
			tags := []model.Tag{}
			for _, name := range *tagNames {
				name = strings.TrimSpace(name)
				if name == "" || len([]rune(name)) > 30 {
					continue
				}
				tag := model.Tag{Name: name}
				if err := tx.Clauses(clause.OnConflict{Columns: []clause.Column{{Name: "name"}}, DoNothing: true}).Create(&tag).Error; err != nil {
					return err
				}
				if err := tx.Where("name = ?", name).First(&tag).Error; err != nil {
					return err
				}
				tags = append(tags, tag)
			}
			if err := tx.Model(novel).Association("Tags").Replace(tags); err != nil {
				return err
			}
		}
		return nil
	})
}

func uniqueInts(in []int) map[int]bool {
	set := make(map[int]bool, len(in))
	for _, v := range in {
		set[v] = true
	}
	return set
}

// ListChapters returns all chapters of a novel, published or not, without content.
func (s *AdminService) ListChapters(novelID uuid.UUID) ([]model.Chapter, error) {
	chapters := []model.Chapter{}
	err := s.db.Omit("content").Where("novel_id = ?", novelID).Order("chapter_number ASC").Find(&chapters).Error
	return chapters, err
}

// ------------------------------------------------------------- categories

type CategoryInput struct {
	ParentID  *int   `json:"parent_id"`
	Name      string `json:"name" binding:"required,max=50"`
	Slug      string `json:"slug" binding:"required,max=50"`
	IconURL   string `json:"icon_url" binding:"max=500"`
	SortOrder int    `json:"sort_order"`
	IsActive  *bool  `json:"is_active"`
}

func (s *AdminService) ListCategories() ([]model.Category, error) {
	categories := []model.Category{}
	err := s.db.Order("parent_id NULLS FIRST, sort_order ASC, id ASC").Find(&categories).Error
	return categories, err
}

// SaveCategory creates a category (id 0) or updates one. Slugs must be
// unique (ErrConflict) and a category cannot be its own parent.
func (s *AdminService) SaveCategory(id int, in CategoryInput) (*model.Category, error) {
	var category model.Category
	if id != 0 {
		if err := s.db.First(&category, id).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return nil, ErrNotFound
			}
			return nil, err
		}
	}
	if in.ParentID != nil {
		if *in.ParentID == id {
			return nil, ErrConflict
		}
		var count int64
		if err := s.db.Model(&model.Category{}).Where("id = ? AND parent_id IS NULL", *in.ParentID).Count(&count).Error; err != nil {
			return nil, err
		}
		if count == 0 {
			// Parents must exist and be top-level: categories are two levels deep.
			return nil, ErrNotFound
		}
	}
	category.ParentID = in.ParentID
	category.Name = strings.TrimSpace(in.Name)
	category.Slug = strings.TrimSpace(in.Slug)
	category.IconURL = in.IconURL
	category.SortOrder = in.SortOrder
	active := in.IsActive == nil || *in.IsActive
	category.IsActive = active
	if err := s.db.Save(&category).Error; err != nil {
		if IsUniqueViolation(err) {
			return nil, ErrConflict
		}
		return nil, err
	}
	// Creating skips false for a column with a default and reads the
	// default back, so store an inactive category explicitly.
	if !active {
		if err := s.db.Model(&category).Update("is_active", false).Error; err != nil {
			return nil, err
		}
	}
	return &category, nil
}

// DeleteCategory removes a category that has no subcategories; novels lose
// the category but are otherwise untouched.
func (s *AdminService) DeleteCategory(id int) error {
	var children int64
	if err := s.db.Model(&model.Category{}).Where("parent_id = ?", id).Count(&children).Error; err != nil {
		return err
	}
	if children > 0 {
		return ErrHasChildren
	}
	return s.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Exec("DELETE FROM novel_categories WHERE category_id = ?", id).Error; err != nil {
			return err
		}
		res := tx.Delete(&model.Category{}, id)
		if res.Error != nil {
			return res.Error
		}
		if res.RowsAffected == 0 {
			return ErrNotFound
		}
		return nil
	})
}

// ---------------------------------------------------------------- banners

type BannerInput struct {
	Title     string     `json:"title" binding:"required,max=200"`
	ImageURL  string     `json:"image_url" binding:"required,max=500"`
	LinkType  string     `json:"link_type" binding:"omitempty,oneof=novel url category"`
	LinkValue string     `json:"link_value" binding:"max=500"`
	SortOrder int        `json:"sort_order"`
	IsActive  *bool      `json:"is_active"`
	StartAt   *time.Time `json:"start_at"`
	EndAt     *time.Time `json:"end_at"`
}

func (s *AdminService) ListBanners() ([]model.Banner, error) {
	banners := []model.Banner{}
	err := s.db.Order("sort_order ASC, created_at DESC").Find(&banners).Error
	return banners, err
}

func (s *AdminService) SaveBanner(id *uuid.UUID, in BannerInput) (*model.Banner, error) {
	var banner model.Banner
	if id != nil {
		if err := s.db.First(&banner, "id = ?", *id).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return nil, ErrNotFound
			}
			return nil, err
		}
	}
	banner.Title, banner.ImageURL = in.Title, in.ImageURL
	banner.LinkType, banner.LinkValue = in.LinkType, in.LinkValue
	banner.SortOrder, banner.StartAt, banner.EndAt = in.SortOrder, in.StartAt, in.EndAt
	active := in.IsActive == nil || *in.IsActive
	banner.IsActive = active
	if err := s.db.Save(&banner).Error; err != nil {
		return nil, err
	}
	if !active {
		if err := s.db.Model(&banner).Update("is_active", false).Error; err != nil {
			return nil, err
		}
	}
	return &banner, nil
}

func (s *AdminService) DeleteBanner(id uuid.UUID) error {
	res := s.db.Delete(&model.Banner{}, "id = ?", id)
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return ErrNotFound
	}
	return nil
}

// ------------------------------------------------------------------ stats

// startOfLocalDay is the instant the day containing now began for a client
// utcOffsetMinutes east of UTC.
func startOfLocalDay(now time.Time, utcOffsetMinutes int) time.Time {
	local := now.In(time.FixedZone("", utcOffsetMinutes*60))
	return time.Date(local.Year(), local.Month(), local.Day(), 0, 0, 0, 0, local.Location())
}

// AdminStats is the admin dashboard overview.
type AdminStats struct {
	Users           int64 `json:"users"`
	NewUsersToday   int64 `json:"new_users_today"`
	Novels          int64 `json:"novels"`
	PublishedNovels int64 `json:"published_novels"`
	Chapters        int64 `json:"chapters"`
	Reviews         int64 `json:"reviews"`
	Comments        int64 `json:"comments"`
	PendingReports  int64 `json:"pending_reports"`
	ActiveReaders7d int64 `json:"active_readers_7d"`
	ReadsToday      int64 `json:"reads_today"`
}

// Stats counts the overview; "today" starts at local midnight for a client
// utcOffsetMinutes east of UTC.
func (s *AdminService) Stats(utcOffsetMinutes int) (*AdminStats, error) {
	st := &AdminStats{}
	today := startOfLocalDay(time.Now(), utcOffsetMinutes)
	counts := []struct {
		dst *int64
		q   *gorm.DB
	}{
		{&st.Users, s.db.Model(&model.User{})},
		{&st.NewUsersToday, s.db.Model(&model.User{}).Where("created_at >= ?", today)},
		{&st.Novels, s.db.Model(&model.Novel{})},
		{&st.PublishedNovels, s.db.Model(&model.Novel{}).Where("is_published")},
		{&st.Chapters, s.db.Model(&model.Chapter{})},
		{&st.Reviews, s.db.Model(&model.Review{})},
		{&st.Comments, s.db.Model(&model.Comment{})},
		{&st.PendingReports, s.db.Model(&model.Report{}).Where("status = ?", model.ReportPending)},
		{&st.ActiveReaders7d, s.db.Model(&model.ReadingHistory{}).Where("read_at >= ?", time.Now().AddDate(0, 0, -7)).Distinct("user_id")},
		{&st.ReadsToday, s.db.Model(&model.ReadingHistory{}).Where("read_at >= ?", today)},
	}
	for _, c := range counts {
		if err := c.q.Count(c.dst).Error; err != nil {
			return nil, err
		}
	}
	return st, nil
}
