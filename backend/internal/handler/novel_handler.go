package handler

import (
	"github.com/gin-gonic/gin"
)

type NovelHandler struct {
	// TODO: inject NovelService
}

func NewNovelHandler() *NovelHandler {
	return &NovelHandler{}
}

func (h *NovelHandler) List(c *gin.Context) {
	// TODO: implement GET /novels
}

func (h *NovelHandler) GetByID(c *gin.Context) {
	// TODO: implement GET /novels/:id
}

func (h *NovelHandler) ListChapters(c *gin.Context) {
	// TODO: implement GET /novels/:id/chapters
}

func (h *NovelHandler) GetChapter(c *gin.Context) {
	// TODO: implement GET /novels/:id/chapters/:chapterId
}

func (h *NovelHandler) ListCategories(c *gin.Context) {
	// TODO: implement GET /categories
}
