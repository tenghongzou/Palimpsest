package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/service"
)

type BookmarkHandler struct {
	bookmarkSvc *service.BookmarkService
}

func NewBookmarkHandler(bookmarkSvc *service.BookmarkService) *BookmarkHandler {
	return &BookmarkHandler{bookmarkSvc: bookmarkSvc}
}

func (h *BookmarkHandler) List(c *gin.Context) {
	var novelID *uuid.UUID
	if raw := c.Query("novel_id"); raw != "" {
		id, err := uuid.Parse(raw)
		if err != nil {
			c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, "invalid novel_id"))
			return
		}
		novelID = &id
	}
	bookmarks, err := h.bookmarkSvc.List(currentUser(c), novelID)
	if err != nil {
		serviceError(c, err, 40401, "")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(bookmarks))
}

func (h *BookmarkHandler) Create(c *gin.Context) {
	var req service.BookmarkInput
	if !bindJSON(c, &req) {
		return
	}
	bookmark, err := h.bookmarkSvc.Create(currentUser(c), req)
	if err != nil {
		serviceError(c, err, 40402, "chapter not found")
		return
	}
	c.JSON(http.StatusCreated, model.SuccessResponse(bookmark))
}

func (h *BookmarkHandler) Update(c *gin.Context) {
	id, ok := pathUUID(c, "bookmarkId")
	if !ok {
		return
	}
	var req service.BookmarkPatch
	if !bindJSON(c, &req) {
		return
	}
	bookmark, err := h.bookmarkSvc.Update(currentUser(c), id, req)
	if err != nil {
		serviceError(c, err, 40403, "bookmark not found")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(bookmark))
}

func (h *BookmarkHandler) Delete(c *gin.Context) {
	id, ok := pathUUID(c, "bookmarkId")
	if !ok {
		return
	}
	if err := h.bookmarkSvc.Delete(currentUser(c), id); err != nil {
		serviceError(c, err, 40403, "bookmark not found")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(nil))
}

func (h *BookmarkHandler) Sync(c *gin.Context) {
	var req service.BookmarkSync
	if !bindJSON(c, &req) {
		return
	}
	bookmarks, err := h.bookmarkSvc.Sync(currentUser(c), req)
	if err != nil {
		serviceError(c, err, 40403, "bookmark not found")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(bookmarks))
}
