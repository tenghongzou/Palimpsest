package handler

import (
	"github.com/gin-gonic/gin"
)

type BookshelfHandler struct {
	// TODO: inject BookshelfService
}

func NewBookshelfHandler() *BookshelfHandler {
	return &BookshelfHandler{}
}

func (h *BookshelfHandler) List(c *gin.Context) {
	// TODO: implement GET /bookshelf
}

func (h *BookshelfHandler) Add(c *gin.Context) {
	// TODO: implement POST /bookshelf
}

func (h *BookshelfHandler) Remove(c *gin.Context) {
	// TODO: implement DELETE /bookshelf/:novelId
}

func (h *BookshelfHandler) UpdateProgress(c *gin.Context) {
	// TODO: implement PUT /reading-progress/:novelId
}

func (h *BookshelfHandler) GetProgress(c *gin.Context) {
	// TODO: implement GET /reading-progress/:novelId
}
