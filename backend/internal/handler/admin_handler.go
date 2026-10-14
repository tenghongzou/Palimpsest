package handler

import (
	"encoding/json"
	"errors"
	"io"
	"log"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
	"github.com/tenghongzou/palimpsest/backend/internal/middleware"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/pkg/storage"
	"github.com/tenghongzou/palimpsest/backend/internal/repository"
	"github.com/tenghongzou/palimpsest/backend/internal/service"
	"gorm.io/gorm"
)

// maxBatchChapters bounds one batch import request.
const maxBatchChapters = 500

// AdminDeps are the services behind the admin console. Any may be nil in
// tests that only exercise request validation.
type AdminDeps struct {
	NovelRepo    *repository.NovelRepository
	NovelSvc     *service.NovelService
	AdminSvc     *service.AdminService
	CommunitySvc *service.CommunityService
	HomeSvc      *service.HomeService
	SearchSvc    *service.SearchService
	// Notifications, when set, tells bookshelf readers about new chapters.
	Notifications *service.NotificationService
	Store         storage.Store
	DB            *gorm.DB
	Redis         *redis.Client
}

type AdminHandler struct {
	AdminDeps
}

func NewAdminHandler(deps AdminDeps) *AdminHandler {
	return &AdminHandler{AdminDeps: deps}
}

// novelChanged keeps derived data in step after a novel changes: the search
// index and cached pages. Failures are logged rather than returned: the
// database write already succeeded.
func (h *AdminHandler) novelChanged(novel *model.Novel) {
	if h.NovelSvc != nil {
		h.NovelSvc.InvalidateNovel(novel.ID)
	}
	if h.SearchSvc == nil {
		return
	}
	if err := h.SearchSvc.SyncNovel(novel); err != nil {
		log.Printf("admin: failed to sync novel %s to search index: %v", novel.ID, err)
	}
}

// chaptersChanged refreshes a novel's chapter totals, caches and search entry.
func (h *AdminHandler) chaptersChanged(novelID uuid.UUID) {
	if h.NovelSvc != nil {
		if err := h.NovelSvc.ChaptersChanged(novelID); err != nil {
			log.Printf("admin: failed to refresh stats of novel %s: %v", novelID, err)
		}
	}
	if novel, err := h.NovelRepo.FindByID(novelID); err == nil {
		h.novelChanged(novel)
	}
}

// chaptersPublished notifies readers about chapters that just went public.
func (h *AdminHandler) chaptersPublished(novelID uuid.UUID, chapters []model.Chapter) {
	if h.Notifications == nil {
		return
	}
	var published []model.Chapter
	for _, ch := range chapters {
		if ch.IsPublished {
			published = append(published, ch)
		}
	}
	if err := h.Notifications.NotifyChapters(novelID, published); err != nil {
		log.Printf("admin: failed to notify readers of novel %s: %v", novelID, err)
	}
}

// ---------------------------------------------------------------- novels

func (h *AdminHandler) ListNovels(c *gin.Context) {
	page, size := pageParams(c, 20, 100)
	filter := service.AdminNovelFilter{Query: c.Query("q"), Status: c.Query("status")}
	if raw := c.Query("is_published"); raw != "" {
		published := raw == "true"
		filter.Published = &published
	}
	novels, total, err := h.AdminSvc.ListNovels(filter, page, size)
	if err != nil {
		serviceError(c, err, 40401, "")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(paginated(novels, page, size, total)))
}

func (h *AdminHandler) GetNovel(c *gin.Context) {
	id, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	novel, err := h.NovelRepo.FindByID(id)
	if err != nil {
		c.JSON(http.StatusNotFound, model.ErrorResponse(40401, "novel not found"))
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(novel))
}

// novelTaxonomy is the part of a novel request that sets associations.
type novelTaxonomy struct {
	CategoryIDs *[]int    `json:"category_ids"`
	Tags        *[]string `json:"tags"`
}

// bindNovel reads a novel body into novel, plus optional category_ids and
// tags. Counters and timestamps the server maintains are left untouched.
func bindNovel(c *gin.Context, novel *model.Novel) (*novelTaxonomy, bool) {
	body, err := io.ReadAll(io.LimitReader(c.Request.Body, 1<<20))
	if err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, "unreadable body"))
		return nil, false
	}
	keep := *novel
	var tax novelTaxonomy
	var fields map[string]json.RawMessage
	if err := json.Unmarshal(body, &fields); err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, err.Error()))
		return nil, false
	}
	if err := json.Unmarshal(body, &tax); err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, err.Error()))
		return nil, false
	}
	// Tags arrive as names, unlike the model's tag objects; associations
	// are only set through tax.
	for _, key := range []string{"tags", "categories", "category_ids"} {
		delete(fields, key)
	}
	rest, _ := json.Marshal(fields)
	if err := json.Unmarshal(rest, novel); err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, err.Error()))
		return nil, false
	}
	novel.ID, novel.CreatedAt, novel.PublishedAt = keep.ID, keep.CreatedAt, keep.PublishedAt
	novel.TotalWords, novel.TotalChapters, novel.ViewCount = keep.TotalWords, keep.TotalChapters, keep.ViewCount
	novel.FavoriteCount, novel.ReviewCount, novel.AvgRating = keep.FavoriteCount, keep.ReviewCount, keep.AvgRating
	novel.LatestChapterID, novel.LatestChapterTitle, novel.LatestChapterAt = keep.LatestChapterID, keep.LatestChapterTitle, keep.LatestChapterAt
	novel.IsPublished = keep.IsPublished
	novel.Categories, novel.Tags = keep.Categories, keep.Tags
	if novel.Title == "" || novel.AuthorName == "" {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, "title and author_name are required"))
		return nil, false
	}
	switch novel.Status {
	case "":
		novel.Status = "ongoing"
	case "ongoing", "completed", "hiatus":
	default:
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, "status must be ongoing, completed or hiatus"))
		return nil, false
	}
	switch novel.Language {
	case "":
		novel.Language = "zh-TW"
	case "zh-TW", "zh-CN", "en":
	default:
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, "language must be zh-TW, zh-CN or en"))
		return nil, false
	}
	return &tax, true
}

func (h *AdminHandler) saveTaxonomy(c *gin.Context, novel *model.Novel, tax *novelTaxonomy) bool {
	if tax.CategoryIDs == nil && tax.Tags == nil {
		return true
	}
	if err := h.AdminSvc.SetTaxonomy(novel, tax.CategoryIDs, tax.Tags); err != nil {
		serviceError(c, err, 40407, "category not found")
		return false
	}
	return true
}

func (h *AdminHandler) CreateNovel(c *gin.Context) {
	novel := &model.Novel{}
	tax, ok := bindNovel(c, novel)
	if !ok {
		return
	}
	if err := h.NovelRepo.Create(novel); err != nil {
		serviceError(c, err, 40401, "")
		return
	}
	if !h.saveTaxonomy(c, novel, tax) {
		return
	}
	novel, _ = h.NovelRepo.FindByID(novel.ID)
	h.novelChanged(novel)
	c.JSON(http.StatusCreated, model.SuccessResponse(novel))
}

func (h *AdminHandler) UpdateNovel(c *gin.Context) {
	id, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	novel, err := h.NovelRepo.FindByID(id)
	if err != nil {
		c.JSON(http.StatusNotFound, model.ErrorResponse(40401, "novel not found"))
		return
	}
	tax, ok := bindNovel(c, novel)
	if !ok {
		return
	}
	categories, tags := novel.Categories, novel.Tags
	// Save would otherwise upsert the loaded associations; they change only
	// through saveTaxonomy.
	novel.Categories, novel.Tags = nil, nil
	if err := h.NovelRepo.Update(novel); err != nil {
		serviceError(c, err, 40401, "")
		return
	}
	novel.Categories, novel.Tags = categories, tags
	if !h.saveTaxonomy(c, novel, tax) {
		return
	}
	novel, _ = h.NovelRepo.FindByID(id)
	h.novelChanged(novel)
	c.JSON(http.StatusOK, model.SuccessResponse(novel))
}

func (h *AdminHandler) DeleteNovel(c *gin.Context) {
	id, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	if err := h.NovelRepo.Delete(id); err != nil {
		serviceError(c, err, 40401, "")
		return
	}
	if h.NovelSvc != nil {
		h.NovelSvc.InvalidateNovel(id)
	}
	if h.SearchSvc != nil {
		if err := h.SearchSvc.RemoveNovel(id.String()); err != nil {
			log.Printf("admin: failed to remove novel %s from search index: %v", id, err)
		}
	}
	c.JSON(http.StatusOK, model.SuccessResponse(nil))
}

// PublishNovel publishes a novel, or unpublishes it with {"is_published": false}.
func (h *AdminHandler) PublishNovel(c *gin.Context) {
	id, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	req := struct {
		IsPublished *bool `json:"is_published"`
	}{}
	if c.Request.ContentLength > 0 && !bindJSON(c, &req) {
		return
	}
	novel, err := h.NovelRepo.FindByID(id)
	if err != nil {
		c.JSON(http.StatusNotFound, model.ErrorResponse(40401, "novel not found"))
		return
	}
	novel.IsPublished = req.IsPublished == nil || *req.IsPublished
	if novel.IsPublished && novel.PublishedAt == nil {
		now := time.Now()
		novel.PublishedAt = &now
	}
	categories, tags := novel.Categories, novel.Tags
	novel.Categories, novel.Tags = nil, nil
	if err := h.DB.Model(novel).Select("is_published", "published_at").Updates(novel).Error; err != nil {
		serviceError(c, err, 40401, "")
		return
	}
	novel.Categories, novel.Tags = categories, tags
	h.novelChanged(novel)
	c.JSON(http.StatusOK, model.SuccessResponse(novel))
}

// -------------------------------------------------------------- chapters

func (h *AdminHandler) ListChapters(c *gin.Context) {
	novelID, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	chapters, err := h.AdminSvc.ListChapters(novelID)
	if err != nil {
		serviceError(c, err, 40401, "")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(chapters))
}

func (h *AdminHandler) GetChapter(c *gin.Context) {
	id, ok := pathUUID(c, "chapterId")
	if !ok {
		return
	}
	chapter, err := h.NovelRepo.FindChapter(id)
	if err != nil {
		c.JSON(http.StatusNotFound, model.ErrorResponse(40402, "chapter not found"))
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(chapter))
}

func validChapter(c *gin.Context, ch *model.Chapter) bool {
	if ch.Title == "" || ch.Content == "" || ch.ChapterNumber < 1 {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, "title, content and a positive chapter_number are required"))
		return false
	}
	return true
}

// chapterSaveError answers a failed chapter write; a duplicate chapter
// number within the novel is a conflict.
func chapterSaveError(c *gin.Context, err error) {
	if isUniqueViolation(err) {
		c.JSON(http.StatusConflict, model.ErrorResponse(40904, "chapter number already exists in this novel"))
		return
	}
	serviceError(c, err, 40401, "novel not found")
}

func (h *AdminHandler) CreateChapter(c *gin.Context) {
	novelID, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	var chapter model.Chapter
	if !bindJSON(c, &chapter) || !validChapter(c, &chapter) {
		return
	}
	chapter.ID = uuid.Nil
	chapter.NovelID = novelID
	if err := h.NovelRepo.CreateChapter(&chapter); err != nil {
		chapterSaveError(c, err)
		return
	}
	h.chaptersChanged(novelID)
	h.chaptersPublished(novelID, []model.Chapter{chapter})
	c.JSON(http.StatusCreated, model.SuccessResponse(chapter))
}

func (h *AdminHandler) UpdateChapter(c *gin.Context) {
	id, ok := pathUUID(c, "chapterId")
	if !ok {
		return
	}
	chapter, err := h.NovelRepo.FindChapter(id)
	if err != nil {
		c.JSON(http.StatusNotFound, model.ErrorResponse(40402, "chapter not found"))
		return
	}
	novelID, wasPublished := chapter.NovelID, chapter.IsPublished
	if !bindJSON(c, chapter) || !validChapter(c, chapter) {
		return
	}
	chapter.ID, chapter.NovelID = id, novelID
	if err := h.NovelRepo.UpdateChapter(chapter); err != nil {
		chapterSaveError(c, err)
		return
	}
	h.chaptersChanged(novelID)
	if !wasPublished {
		h.chaptersPublished(novelID, []model.Chapter{*chapter})
	}
	c.JSON(http.StatusOK, model.SuccessResponse(chapter))
}

func (h *AdminHandler) DeleteChapter(c *gin.Context) {
	id, ok := pathUUID(c, "chapterId")
	if !ok {
		return
	}
	chapter, err := h.NovelRepo.FindChapter(id)
	if err != nil {
		c.JSON(http.StatusNotFound, model.ErrorResponse(40402, "chapter not found"))
		return
	}
	if err := h.NovelRepo.DeleteChapter(id); err != nil {
		serviceError(c, err, 40402, "chapter not found")
		return
	}
	h.chaptersChanged(chapter.NovelID)
	c.JSON(http.StatusOK, model.SuccessResponse(nil))
}

func (h *AdminHandler) BatchImportChapters(c *gin.Context) {
	novelID, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	var chapters []model.Chapter
	if !bindJSON(c, &chapters) {
		return
	}
	if len(chapters) == 0 || len(chapters) > maxBatchChapters {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, "send between 1 and 500 chapters"))
		return
	}
	for i := range chapters {
		if !validChapter(c, &chapters[i]) {
			return
		}
		chapters[i].ID = uuid.Nil
		chapters[i].NovelID = novelID
	}
	if err := h.DB.CreateInBatches(&chapters, 100).Error; err != nil {
		chapterSaveError(c, err)
		return
	}
	h.chaptersChanged(novelID)
	h.chaptersPublished(novelID, chapters)
	c.JSON(http.StatusCreated, model.SuccessResponse(gin.H{"imported": len(chapters)}))
}

// ----------------------------------------------------------------- users

func (h *AdminHandler) ListUsers(c *gin.Context) {
	page, size := pageParams(c, 20, 100)
	users := []model.User{}
	var total int64
	q := h.DB.Model(&model.User{})
	if s := c.Query("q"); s != "" {
		like := "%" + s + "%"
		q = q.Where("username ILIKE ? OR email ILIKE ? OR nickname ILIKE ?", like, like, like)
	}
	if status := c.Query("status"); status != "" {
		q = q.Where("status = ?", status)
	}
	if err := q.Count(&total).Error; err != nil {
		serviceError(c, err, 40401, "")
		return
	}
	if err := q.Order("created_at DESC").Offset((page - 1) * size).Limit(size).Find(&users).Error; err != nil {
		serviceError(c, err, 40401, "")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(paginated(users, page, size, total)))
}

func (h *AdminHandler) GetUser(c *gin.Context) {
	id, ok := pathUUID(c, "userId")
	if !ok {
		return
	}
	var user model.User
	if err := h.DB.First(&user, "id = ?", id).Error; err != nil {
		c.JSON(http.StatusNotFound, model.ErrorResponse(40401, "user not found"))
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(user))
}

func (h *AdminHandler) UpdateUserStatus(c *gin.Context) {
	id, ok := pathUUID(c, "userId")
	if !ok {
		return
	}
	var req struct {
		Status string `json:"status" binding:"required,oneof=active banned"`
	}
	if !bindJSON(c, &req) {
		return
	}
	if id == currentUser(c) {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, "you cannot change your own status"))
		return
	}
	res := h.DB.Model(&model.User{}).Where("id = ?", id).Update("status", req.Status)
	if res.Error != nil {
		serviceError(c, res.Error, 40401, "user not found")
		return
	}
	if res.RowsAffected == 0 {
		c.JSON(http.StatusNotFound, model.ErrorResponse(40401, "user not found"))
		return
	}
	// Access tokens stay valid until they expire; the Redis mark makes the
	// ban take effect on the user's next request.
	if h.Redis != nil {
		key := middleware.BannedUserKey(id)
		var err error
		if req.Status == "banned" {
			err = h.Redis.Set(c.Request.Context(), key, "1", middleware.BanTTL).Err()
		} else {
			err = h.Redis.Del(c.Request.Context(), key).Err()
		}
		if err != nil {
			log.Printf("admin: failed to update ban mark for %s: %v", id, err)
		}
	}
	c.JSON(http.StatusOK, model.SuccessResponse(gin.H{"status": req.Status}))
}

// ------------------------------------------------------------ moderation

func (h *AdminHandler) ListReviews(c *gin.Context) {
	page, size := pageParams(c, 20, 100)
	reviews, total, err := h.CommunitySvc.AdminListReviews(c.Query("status"), page, size)
	if err != nil {
		serviceError(c, err, 40404, "")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(paginated(reviews, page, size, total)))
}

func (h *AdminHandler) ModerateReview(c *gin.Context) {
	id, ok := pathUUID(c, "reviewId")
	if !ok {
		return
	}
	var req struct {
		Status string `json:"status" binding:"required,oneof=approved rejected hidden"`
	}
	if !bindJSON(c, &req) {
		return
	}
	review, err := h.CommunitySvc.SetReviewStatus(id, req.Status)
	if err != nil {
		serviceError(c, err, 40404, "review not found")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(review))
}

func (h *AdminHandler) ListReports(c *gin.Context) {
	page, size := pageParams(c, 20, 100)
	reports, total, err := h.CommunitySvc.AdminListReports(c.Query("status"), page, size)
	if err != nil {
		serviceError(c, err, 40406, "")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(paginated(reports, page, size, total)))
}

func (h *AdminHandler) ResolveReport(c *gin.Context) {
	id, ok := pathUUID(c, "reportId")
	if !ok {
		return
	}
	var req struct {
		Status     string `json:"status" binding:"required,oneof=resolved dismissed"`
		HideTarget bool   `json:"hide_target"`
	}
	if !bindJSON(c, &req) {
		return
	}
	report, err := h.CommunitySvc.ResolveReport(currentUser(c), id, req.Status, req.HideTarget)
	if err != nil {
		serviceError(c, err, 40406, "report not found")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(report))
}

// ------------------------------------------------------------ categories

func (h *AdminHandler) ListCategories(c *gin.Context) {
	categories, err := h.AdminSvc.ListCategories()
	if err != nil {
		serviceError(c, err, 40407, "")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(categories))
}

func (h *AdminHandler) saveCategory(c *gin.Context, id int) {
	var req service.CategoryInput
	if !bindJSON(c, &req) {
		return
	}
	category, err := h.AdminSvc.SaveCategory(id, req)
	if err != nil {
		serviceError(c, err, 40407, "category or parent category not found")
		return
	}
	status := http.StatusOK
	if id == 0 {
		status = http.StatusCreated
	}
	c.JSON(status, model.SuccessResponse(category))
}

func categoryID(c *gin.Context) (int, bool) {
	id, err := strconv.Atoi(c.Param("categoryId"))
	if err != nil || id < 1 {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, "invalid categoryId"))
		return 0, false
	}
	return id, true
}

func (h *AdminHandler) CreateCategory(c *gin.Context) { h.saveCategory(c, 0) }

func (h *AdminHandler) UpdateCategory(c *gin.Context) {
	if id, ok := categoryID(c); ok {
		h.saveCategory(c, id)
	}
}

func (h *AdminHandler) DeleteCategory(c *gin.Context) {
	id, ok := categoryID(c)
	if !ok {
		return
	}
	if err := h.AdminSvc.DeleteCategory(id); err != nil {
		if errors.Is(err, service.ErrHasChildren) {
			c.JSON(http.StatusConflict, model.ErrorResponse(40905, "category has subcategories"))
			return
		}
		serviceError(c, err, 40407, "category not found")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(nil))
}

// --------------------------------------------------------------- banners

func (h *AdminHandler) ListBanners(c *gin.Context) {
	banners, err := h.AdminSvc.ListBanners()
	if err != nil {
		serviceError(c, err, 40408, "")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(banners))
}

func (h *AdminHandler) saveBanner(c *gin.Context, id *uuid.UUID) {
	var req service.BannerInput
	if !bindJSON(c, &req) {
		return
	}
	banner, err := h.AdminSvc.SaveBanner(id, req)
	if err != nil {
		serviceError(c, err, 40408, "banner not found")
		return
	}
	if h.HomeSvc != nil {
		h.HomeSvc.InvalidateHome()
	}
	status := http.StatusOK
	if id == nil {
		status = http.StatusCreated
	}
	c.JSON(status, model.SuccessResponse(banner))
}

func (h *AdminHandler) CreateBanner(c *gin.Context) { h.saveBanner(c, nil) }

func (h *AdminHandler) UpdateBanner(c *gin.Context) {
	if id, ok := pathUUID(c, "bannerId"); ok {
		h.saveBanner(c, &id)
	}
}

func (h *AdminHandler) DeleteBanner(c *gin.Context) {
	id, ok := pathUUID(c, "bannerId")
	if !ok {
		return
	}
	if err := h.AdminSvc.DeleteBanner(id); err != nil {
		serviceError(c, err, 40408, "banner not found")
		return
	}
	if h.HomeSvc != nil {
		h.HomeSvc.InvalidateHome()
	}
	c.JSON(http.StatusOK, model.SuccessResponse(nil))
}

// --------------------------------------------------------------- uploads

// UploadImage stores a cover or banner image and returns its URL.
func (h *AdminHandler) UploadImage(c *gin.Context) {
	folder := c.DefaultQuery("kind", "covers")
	if folder != "covers" && folder != "banners" {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, "kind must be covers or banners"))
		return
	}
	url, ok := uploadImage(c, h.Store, "file", folder, maxImageBytes)
	if !ok {
		return
	}
	c.JSON(http.StatusCreated, model.SuccessResponse(gin.H{"url": url}))
}

// ----------------------------------------------------------------- stats

func (h *AdminHandler) StatsOverview(c *gin.Context) {
	stats, err := h.AdminSvc.Stats()
	if err != nil {
		serviceError(c, err, 40401, "")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(stats))
}

// isUniqueViolation reports a duplicate key error from Postgres.
func isUniqueViolation(err error) bool {
	return service.IsUniqueViolation(err) || errors.Is(err, gorm.ErrDuplicatedKey)
}
