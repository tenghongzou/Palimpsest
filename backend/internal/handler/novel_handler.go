package handler

import (
	"math"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/service"
)

type NovelHandler struct {
	novelSvc *service.NovelService
}

func NewNovelHandler(novelSvc *service.NovelService) *NovelHandler {
	return &NovelHandler{novelSvc: novelSvc}
}

func (h *NovelHandler) List(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))
	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 20
	}

	status := c.Query("status")
	language := c.Query("language")
	sortBy := c.DefaultQuery("sort_by", "latest")

	var categoryID *int
	if catStr := c.Query("category_id"); catStr != "" {
		if id, err := strconv.Atoi(catStr); err == nil {
			categoryID = &id
		}
	}

	novels, total, err := h.novelSvc.List(page, pageSize, categoryID, status, language, sortBy)
	if err != nil {
		c.JSON(http.StatusInternalServerError, model.ErrorResponse(50001, "failed to list novels"))
		return
	}

	totalPages := int(math.Ceil(float64(total) / float64(pageSize)))
	c.JSON(http.StatusOK, model.SuccessResponse(model.PaginatedResponse{
		Items: novels,
		Pagination: model.Pagination{
			Page:       page,
			PageSize:   pageSize,
			Total:      int(total),
			TotalPages: totalPages,
		},
	}))
}

func (h *NovelHandler) GetByID(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, "invalid novel id"))
		return
	}

	novel, err := h.novelSvc.GetByID(id)
	if err != nil {
		c.JSON(http.StatusNotFound, model.ErrorResponse(40401, "novel not found"))
		return
	}

	c.JSON(http.StatusOK, model.SuccessResponse(novel))
}

func (h *NovelHandler) ListChapters(c *gin.Context) {
	novelID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, "invalid novel id"))
		return
	}

	order := c.DefaultQuery("order", "asc")
	chapters, err := h.novelSvc.ListChapters(novelID, order)
	if err != nil {
		c.JSON(http.StatusInternalServerError, model.ErrorResponse(50001, "failed to list chapters"))
		return
	}

	c.JSON(http.StatusOK, model.SuccessResponse(chapters))
}

func (h *NovelHandler) GetChapter(c *gin.Context) {
	chapterID, err := uuid.Parse(c.Param("chapterId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, "invalid chapter id"))
		return
	}

	chapter, err := h.novelSvc.GetChapter(chapterID)
	if err != nil {
		c.JSON(http.StatusNotFound, model.ErrorResponse(40402, "chapter not found"))
		return
	}

	c.JSON(http.StatusOK, model.SuccessResponse(chapter))
}

func (h *NovelHandler) ListCategories(c *gin.Context) {
	categories, err := h.novelSvc.ListCategories()
	if err != nil {
		c.JSON(http.StatusInternalServerError, model.ErrorResponse(50001, "failed to list categories"))
		return
	}

	c.JSON(http.StatusOK, model.SuccessResponse(categories))
}
