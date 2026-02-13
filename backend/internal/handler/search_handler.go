package handler

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/service"
)

type SearchHandler struct {
	searchSvc *service.SearchService
}

func NewSearchHandler(searchSvc *service.SearchService) *SearchHandler {
	return &SearchHandler{searchSvc: searchSvc}
}

func (h *SearchHandler) SearchNovels(c *gin.Context) {
	query := c.Query("q")
	if query == "" {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, "query parameter 'q' is required"))
		return
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))

	filters := map[string]string{
		"status":   c.Query("status"),
		"language": c.Query("language"),
	}

	result, err := h.searchSvc.Search(query, page, pageSize, filters)
	if err != nil {
		c.JSON(http.StatusInternalServerError, model.ErrorResponse(50001, "search failed"))
		return
	}

	c.JSON(http.StatusOK, model.SuccessResponse(result))
}

func (h *SearchHandler) Suggestions(c *gin.Context) {
	query := c.Query("q")
	if query == "" {
		c.JSON(http.StatusOK, model.SuccessResponse([]string{}))
		return
	}

	result, err := h.searchSvc.Search(query, 1, 5, nil)
	if err != nil {
		c.JSON(http.StatusOK, model.SuccessResponse([]string{}))
		return
	}

	var suggestions []string
	for _, hit := range result.Hits {
		if title, ok := hit["title"].(string); ok {
			suggestions = append(suggestions, title)
		}
	}

	c.JSON(http.StatusOK, model.SuccessResponse(suggestions))
}

func (h *SearchHandler) HotKeywords(c *gin.Context) {
	keywords, err := h.searchSvc.HotKeywords()
	if err != nil {
		c.JSON(http.StatusInternalServerError, model.ErrorResponse(50001, "failed to get hot keywords"))
		return
	}

	c.JSON(http.StatusOK, model.SuccessResponse(keywords))
}
