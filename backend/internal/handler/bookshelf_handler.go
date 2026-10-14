package handler

import (
	"errors"
	"net/http"
	"time"

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
		GroupName string `json:"group_name" binding:"max=50"`
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
	if errors.Is(err, service.ErrConflict) {
		c.JSON(http.StatusConflict, model.ErrorResponse(40901, "novel already in bookshelf"))
		return
	}
	if err != nil {
		serviceError(c, err, 40401, "novel not found")
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
		ChapterID      string     `json:"chapter_id" binding:"required"`
		ParagraphIndex int        `json:"paragraph_index" binding:"min=0"`
		ScrollOffset   float64    `json:"scroll_offset" binding:"min=0,max=1"`
		ReadAt         *time.Time `json:"read_at"`
		Duration       int        `json:"duration" binding:"min=0"`
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

	var readAt time.Time
	if req.ReadAt != nil {
		readAt = *req.ReadAt
	}
	progress, err := h.bookshelfSvc.UpdateProgress(userID, novelID, service.ProgressUpdate{
		ChapterID: chapterID, ParagraphIndex: req.ParagraphIndex, ScrollOffset: req.ScrollOffset,
		ReadAt: readAt, Duration: req.Duration,
	})
	if errors.Is(err, service.ErrNotFound) {
		c.JSON(http.StatusNotFound, model.ErrorResponse(40402, "chapter not found in this novel"))
		return
	}
	if err != nil {
		c.JSON(http.StatusInternalServerError, model.ErrorResponse(50001, "failed to update progress"))
		return
	}

	c.JSON(http.StatusOK, model.SuccessResponse(progress))
}

func (h *BookshelfHandler) ListProgress(c *gin.Context) {
	userID := c.MustGet("userID").(uuid.UUID)
	progress, err := h.bookshelfSvc.ListProgress(userID, nil)
	if err != nil {
		c.JSON(http.StatusInternalServerError, model.ErrorResponse(50001, "failed to list reading progress"))
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

func (h *BookshelfHandler) UpdateItem(c *gin.Context) {
	novelID, ok := pathUUID(c, "novelId")
	if !ok {
		return
	}
	var req service.ItemUpdate
	if !bindJSON(c, &req) {
		return
	}
	if err := h.bookshelfSvc.UpdateItem(currentUser(c), novelID, req); err != nil {
		serviceError(c, err, 40401, "novel not in bookshelf")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(req))
}

func (h *BookshelfHandler) BatchRemove(c *gin.Context) {
	var req struct {
		NovelIDs []uuid.UUID `json:"novel_ids" binding:"required,min=1,max=200"`
	}
	if !bindJSON(c, &req) {
		return
	}
	if err := h.bookshelfSvc.RemoveMany(currentUser(c), req.NovelIDs); err != nil {
		serviceError(c, err, 40401, "")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(nil))
}

func (h *BookshelfHandler) BatchProgress(c *gin.Context) {
	var req struct {
		NovelIDs []uuid.UUID `json:"novel_ids" binding:"required,max=200"`
	}
	if !bindJSON(c, &req) {
		return
	}
	progress, err := h.bookshelfSvc.ListProgress(currentUser(c), req.NovelIDs)
	if err != nil {
		serviceError(c, err, 40401, "")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(progress))
}

func (h *BookshelfHandler) History(c *gin.Context) {
	page, size := pageParams(c, 20, 100)
	history, total, err := h.bookshelfSvc.History(currentUser(c), page, size)
	if err != nil {
		serviceError(c, err, 40401, "")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(paginated(history, page, size, total)))
}
