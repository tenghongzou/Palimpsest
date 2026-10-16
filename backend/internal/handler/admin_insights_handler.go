package handler

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/service"
)

// intParam reads an integer query parameter, using def when it is missing or
// malformed and clamping it to [min, max].
func intParam(c *gin.Context, name string, def, min, max int) int {
	n, err := strconv.Atoi(c.Query(name))
	if err != nil {
		return def
	}
	if n < min {
		return min
	}
	if n > max {
		return max
	}
	return n
}

// ----------------------------------------------------------------- stats

// StatsTrends returns the dashboard's daily activity series.
func (h *AdminHandler) StatsTrends(c *gin.Context) {
	trends, err := h.AdminSvc.Trends(intParam(c, "days", 30, 7, 90), utcOffsetParam(c))
	if err != nil {
		serviceError(c, err, 40401, "")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(trends))
}

// StatsTopNovels returns the most-read novels of the last days.
func (h *AdminHandler) StatsTopNovels(c *gin.Context) {
	top, err := h.AdminSvc.TopNovels(intParam(c, "days", 7, 1, 90), intParam(c, "limit", 10, 1, 50), utcOffsetParam(c))
	if err != nil {
		serviceError(c, err, 40401, "")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(top))
}

// StatsCategories returns reads per category over the last days.
func (h *AdminHandler) StatsCategories(c *gin.Context) {
	stats, err := h.AdminSvc.CategoryStats(intParam(c, "days", 30, 1, 90), utcOffsetParam(c))
	if err != nil {
		serviceError(c, err, 40407, "")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(stats))
}

// ------------------------------------------------------------ moderation

// ModerationQueue lists held or flagged reviews and comments.
func (h *AdminHandler) ModerationQueue(c *gin.Context) {
	page, size := pageParams(c, 20, 100)
	queue := c.Query("queue")
	if queue != service.QueueFlagged {
		queue = service.QueuePending
	}
	kind := c.Query("type")
	if kind != model.LikeTargetReview && kind != model.LikeTargetComment {
		kind = ""
	}
	items, total, err := h.CommunitySvc.ModerationQueue(queue, kind, page, size)
	if err != nil {
		serviceError(c, err, 40404, "")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(paginated(items, page, size, total)))
}

// Moderate approves, rejects or hides a review or comment.
func (h *AdminHandler) Moderate(c *gin.Context) {
	kind := c.Param("type")
	notFoundCode, notFoundMsg := 40404, "review not found"
	switch kind {
	case model.LikeTargetReview:
	case model.LikeTargetComment:
		notFoundCode, notFoundMsg = 40405, "comment not found"
	default:
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, "type must be review or comment"))
		return
	}
	id, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	var req struct {
		Status string `json:"status" binding:"required,oneof=approved rejected hidden"`
	}
	if !bindJSON(c, &req) {
		return
	}
	item, err := h.CommunitySvc.Moderate(kind, id, req.Status)
	if err != nil {
		serviceError(c, err, notFoundCode, notFoundMsg)
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(item))
}

// ListModerationTerms returns the moderation terms, newest first.
func (h *AdminHandler) ListModerationTerms(c *gin.Context) {
	terms, err := h.ModerationSvc.ListTerms()
	if err != nil {
		serviceError(c, err, 40412, "")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(terms))
}

// CreateModerationTerm adds a term.
func (h *AdminHandler) CreateModerationTerm(c *gin.Context) {
	var req service.ModerationTermInput
	if !bindJSON(c, &req) {
		return
	}
	term, err := h.ModerationSvc.CreateTerm(req)
	switch {
	case errors.Is(err, service.ErrInvalidTerm):
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, "term must contain letters or digits"))
		return
	case errors.Is(err, service.ErrConflict):
		c.JSON(http.StatusConflict, model.ErrorResponse(40906, "term already exists"))
		return
	case err != nil:
		serviceError(c, err, 40412, "")
		return
	}
	c.JSON(http.StatusCreated, model.SuccessResponse(term))
}

// DeleteModerationTerm removes a term.
func (h *AdminHandler) DeleteModerationTerm(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("termId"))
	if err != nil || id < 1 {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, "invalid termId"))
		return
	}
	if err := h.ModerationSvc.DeleteTerm(id); err != nil {
		serviceError(c, err, 40412, "term not found")
		return
	}
	c.Status(http.StatusNoContent)
}
