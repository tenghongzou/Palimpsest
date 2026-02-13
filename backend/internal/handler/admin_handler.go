package handler

import (
	"math"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/repository"
	"gorm.io/gorm"
)

type AdminHandler struct {
	novelRepo *repository.NovelRepository
	db        *gorm.DB
}

func NewAdminHandler(novelRepo *repository.NovelRepository, db *gorm.DB) *AdminHandler {
	return &AdminHandler{novelRepo: novelRepo, db: db}
}

// Novel management
func (h *AdminHandler) ListNovels(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))

	var novels []model.Novel
	var total int64
	h.db.Model(&model.Novel{}).Count(&total)
	h.db.Preload("Categories").Preload("Tags").
		Order("created_at DESC").
		Offset((page - 1) * pageSize).Limit(pageSize).
		Find(&novels)

	c.JSON(http.StatusOK, model.SuccessResponse(model.PaginatedResponse{
		Items: novels,
		Pagination: model.Pagination{
			Page: page, PageSize: pageSize, Total: int(total),
			TotalPages: int(math.Ceil(float64(total) / float64(pageSize))),
		},
	}))
}

func (h *AdminHandler) CreateNovel(c *gin.Context) {
	var novel model.Novel
	if err := c.ShouldBindJSON(&novel); err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, err.Error()))
		return
	}
	if err := h.novelRepo.Create(&novel); err != nil {
		c.JSON(http.StatusInternalServerError, model.ErrorResponse(50001, "failed to create novel"))
		return
	}
	c.JSON(http.StatusCreated, model.SuccessResponse(novel))
}

func (h *AdminHandler) UpdateNovel(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, "invalid id"))
		return
	}
	novel, err := h.novelRepo.FindByID(id)
	if err != nil {
		c.JSON(http.StatusNotFound, model.ErrorResponse(40401, "novel not found"))
		return
	}
	if err := c.ShouldBindJSON(novel); err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, err.Error()))
		return
	}
	if err := h.novelRepo.Update(novel); err != nil {
		c.JSON(http.StatusInternalServerError, model.ErrorResponse(50001, "failed to update novel"))
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(novel))
}

func (h *AdminHandler) DeleteNovel(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, "invalid id"))
		return
	}
	if err := h.novelRepo.Delete(id); err != nil {
		c.JSON(http.StatusInternalServerError, model.ErrorResponse(50001, "failed to delete novel"))
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(nil))
}

func (h *AdminHandler) PublishNovel(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, "invalid id"))
		return
	}
	novel, err := h.novelRepo.FindByID(id)
	if err != nil {
		c.JSON(http.StatusNotFound, model.ErrorResponse(40401, "novel not found"))
		return
	}
	novel.IsPublished = true
	if err := h.novelRepo.Update(novel); err != nil {
		c.JSON(http.StatusInternalServerError, model.ErrorResponse(50001, "failed to publish"))
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(novel))
}

// Chapter management
func (h *AdminHandler) CreateChapter(c *gin.Context) {
	var chapter model.Chapter
	if err := c.ShouldBindJSON(&chapter); err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, err.Error()))
		return
	}
	if err := h.novelRepo.CreateChapter(&chapter); err != nil {
		c.JSON(http.StatusInternalServerError, model.ErrorResponse(50001, "failed to create chapter"))
		return
	}
	c.JSON(http.StatusCreated, model.SuccessResponse(chapter))
}

func (h *AdminHandler) UpdateChapter(c *gin.Context) {
	id, err := uuid.Parse(c.Param("chapterId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, "invalid id"))
		return
	}
	chapter, err := h.novelRepo.FindChapter(id)
	if err != nil {
		c.JSON(http.StatusNotFound, model.ErrorResponse(40402, "chapter not found"))
		return
	}
	if err := c.ShouldBindJSON(chapter); err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, err.Error()))
		return
	}
	if err := h.novelRepo.UpdateChapter(chapter); err != nil {
		c.JSON(http.StatusInternalServerError, model.ErrorResponse(50001, "failed to update chapter"))
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(chapter))
}

func (h *AdminHandler) DeleteChapter(c *gin.Context) {
	id, err := uuid.Parse(c.Param("chapterId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, "invalid id"))
		return
	}
	if err := h.novelRepo.DeleteChapter(id); err != nil {
		c.JSON(http.StatusInternalServerError, model.ErrorResponse(50001, "failed to delete chapter"))
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(nil))
}

func (h *AdminHandler) BatchImportChapters(c *gin.Context) {
	var chapters []model.Chapter
	if err := c.ShouldBindJSON(&chapters); err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, err.Error()))
		return
	}
	if err := h.db.Create(&chapters).Error; err != nil {
		c.JSON(http.StatusInternalServerError, model.ErrorResponse(50001, "batch import failed"))
		return
	}
	c.JSON(http.StatusCreated, model.SuccessResponse(gin.H{"imported": len(chapters)}))
}

// User management
func (h *AdminHandler) ListUsers(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))
	var users []model.User
	var total int64
	h.db.Model(&model.User{}).Count(&total)
	h.db.Order("created_at DESC").Offset((page-1)*pageSize).Limit(pageSize).Find(&users)
	c.JSON(http.StatusOK, model.SuccessResponse(model.PaginatedResponse{
		Items: users,
		Pagination: model.Pagination{
			Page: page, PageSize: pageSize, Total: int(total),
			TotalPages: int(math.Ceil(float64(total) / float64(pageSize))),
		},
	}))
}

func (h *AdminHandler) GetUser(c *gin.Context) {
	id, err := uuid.Parse(c.Param("userId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, "invalid user id"))
		return
	}
	var user model.User
	if err := h.db.First(&user, "id = ?", id).Error; err != nil {
		c.JSON(http.StatusNotFound, model.ErrorResponse(40401, "user not found"))
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(user))
}

func (h *AdminHandler) UpdateUserStatus(c *gin.Context) {
	id, err := uuid.Parse(c.Param("userId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, "invalid user id"))
		return
	}
	var req struct {
		Status string `json:"status" binding:"required,oneof=active banned"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, err.Error()))
		return
	}
	if err := h.db.Model(&model.User{}).Where("id = ?", id).Update("status", req.Status).Error; err != nil {
		c.JSON(http.StatusInternalServerError, model.ErrorResponse(50001, "failed to update user status"))
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(gin.H{"status": req.Status}))
}

// Content moderation
func (h *AdminHandler) ListReviews(c *gin.Context) {
	var reviews []model.Review
	h.db.Preload("User").Order("created_at DESC").Limit(50).Find(&reviews)
	c.JSON(http.StatusOK, model.SuccessResponse(reviews))
}

func (h *AdminHandler) ModerateReview(c *gin.Context) {
	id, err := uuid.Parse(c.Param("reviewId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, "invalid review id"))
		return
	}
	var req struct {
		Status string `json:"status" binding:"required,oneof=approved rejected"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, err.Error()))
		return
	}
	h.db.Model(&model.Review{}).Where("id = ?", id).Update("status", req.Status)
	c.JSON(http.StatusOK, model.SuccessResponse(nil))
}

func (h *AdminHandler) ListReports(c *gin.Context)   {
	c.JSON(http.StatusOK, model.SuccessResponse([]interface{}{}))
}
func (h *AdminHandler) ResolveReport(c *gin.Context)  {
	c.JSON(http.StatusOK, model.SuccessResponse(nil))
}

// Stats
func (h *AdminHandler) StatsOverview(c *gin.Context) {
	var userCount, novelCount, chapterCount int64
	h.db.Model(&model.User{}).Count(&userCount)
	h.db.Model(&model.Novel{}).Count(&novelCount)
	h.db.Model(&model.Chapter{}).Count(&chapterCount)

	c.JSON(http.StatusOK, model.SuccessResponse(gin.H{
		"users":    userCount,
		"novels":   novelCount,
		"chapters": chapterCount,
	}))
}
