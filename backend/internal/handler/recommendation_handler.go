package handler

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/service"
)

type RecommendationHandler struct {
	recSvc *service.RecommendationService
}

func NewRecommendationHandler(recSvc *service.RecommendationService) *RecommendationHandler {
	return &RecommendationHandler{recSvc: recSvc}
}

// limitParam reads the limit query parameter: def when absent or not a
// number, otherwise clamped to [1, upper].
func limitParam(c *gin.Context, def, upper int) int {
	limit, err := strconv.Atoi(c.Query("limit"))
	if err != nil {
		return def
	}
	return max(1, min(upper, limit))
}

// Recommendations lists novels recommended for the caller, personalised
// when the request is authenticated.
func (h *RecommendationHandler) Recommendations(c *gin.Context) {
	limit := limitParam(c, service.DefaultRecommendationLimit, service.MaxRecommendationLimit)
	recs, err := h.recSvc.Recommend(viewer(c), limit)
	if err != nil {
		serviceError(c, err, 40401, "")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(recs))
}

// Similar lists published novels similar to a published novel.
func (h *RecommendationHandler) Similar(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, "invalid novel id"))
		return
	}
	limit := limitParam(c, service.DefaultSimilarLimit, service.MaxSimilarLimit)
	novels, err := h.recSvc.Similar(id, limit)
	if err != nil {
		serviceError(c, err, 40401, "novel not found")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(novels))
}
