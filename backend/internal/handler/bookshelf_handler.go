package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/service"
)

type BookshelfHandler struct {
	bookshelfSvc *service.BookshelfService
}

func NewBookshelfHandler(bookshelfSvc *service.BookshelfService) *BookshelfHandler {
	return &BookshelfHandler{bookshelfSvc: bookshelfSvc}
}

func (h *BookshelfHandler) List(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)
	sortBy := c.DefaultQuery("sort_by", "recent")

	items, err := h.bookshelfSvc.List(userID, sortBy)
	if err != nil {
		c.JSON(http.StatusInternalServerError, model.ErrorResponse(50001, "failed to list bookshelf"))
		return
	}

	c.JSON(http.StatusOK, model.SuccessResponse(items))
}

func (h *BookshelfHandler) Add(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)

	var req struct {
		NovelID   string `json:"novel_id" binding:"required"`
		GroupName string `json:"group_name"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, err.Error()))
		return
	}

	novelID, err := uuid.Parse(req.NovelID)
	if err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, "invalid novel_id"))
		return
	}

	item, err := h.bookshelfSvc.Add(userID, novelID, req.GroupName)
	if err != nil {
		c.JSON(http.StatusConflict, model.ErrorResponse(40901, "novel already in bookshelf"))
		return
	}

	c.JSON(http.StatusCreated, model.SuccessResponse(item))
}

func (h *BookshelfHandler) Remove(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)
	novelID, err := uuid.Parse(c.Param("novelId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, "invalid novel id"))
		return
	}

	if err := h.bookshelfSvc.Remove(userID, novelID); err != nil {
		c.JSON(http.StatusInternalServerError, model.ErrorResponse(50001, "failed to remove from bookshelf"))
		return
	}

	c.JSON(http.StatusOK, model.SuccessResponse(nil))
}

func (h *BookshelfHandler) UpdateProgress(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)
	novelID, err := uuid.Parse(c.Param("novelId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, "invalid novel id"))
		return
	}

	var req struct {
		ChapterID      string  `json:"chapter_id" binding:"required"`
		ParagraphIndex int     `json:"paragraph_index"`
		ScrollOffset   float64 `json:"scroll_offset"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, err.Error()))
		return
	}

	chapterID, err := uuid.Parse(req.ChapterID)
	if err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, "invalid chapter_id"))
		return
	}

	progress, err := h.bookshelfSvc.UpdateProgress(userID, novelID, chapterID, req.ParagraphIndex, req.ScrollOffset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, model.ErrorResponse(50001, "failed to update progress"))
		return
	}

	c.JSON(http.StatusOK, model.SuccessResponse(progress))
}

func (h *BookshelfHandler) GetProgress(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)
	novelID, err := uuid.Parse(c.Param("novelId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, "invalid novel id"))
		return
	}

	progress, err := h.bookshelfSvc.GetProgress(userID, novelID)
	if err != nil {
		c.JSON(http.StatusNotFound, model.ErrorResponse(40401, "no reading progress found"))
		return
	}

	c.JSON(http.StatusOK, model.SuccessResponse(progress))
}
