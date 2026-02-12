package handler

import (
	"github.com/gin-gonic/gin"
)

type SearchHandler struct {
	// TODO: inject SearchService
}

func NewSearchHandler() *SearchHandler {
	return &SearchHandler{}
}

func (h *SearchHandler) SearchNovels(c *gin.Context) {
	// TODO: implement GET /search/novels
}

func (h *SearchHandler) Suggestions(c *gin.Context) {
	// TODO: implement GET /search/suggestions
}

func (h *SearchHandler) HotKeywords(c *gin.Context) {
	// TODO: implement GET /search/hot-keywords
}
