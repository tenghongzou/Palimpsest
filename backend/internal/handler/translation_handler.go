package handler

import (
	"errors"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/pkg/translate"
	"github.com/tenghongzou/palimpsest/backend/internal/service"
)

type TranslationHandler struct {
	translationSvc *service.TranslationService
}

func NewTranslationHandler(translationSvc *service.TranslationService) *TranslationHandler {
	return &TranslationHandler{translationSvc: translationSvc}
}

func (h *TranslationHandler) Convert(c *gin.Context) {
	var req service.ConvertRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, err.Error()))
		return
	}

	result, err := h.translationSvc.Convert(&req)
	if err != nil {
		h.writeError(c, err, "conversion failed")
		return
	}

	c.JSON(http.StatusOK, model.SuccessResponse(gin.H{
		"text": result,
		"from": req.From,
		"to":   req.To,
	}))
}

func (h *TranslationHandler) TranslateChapter(c *gin.Context) {
	var req service.TranslateChapterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, err.Error()))
		return
	}

	result, err := h.translationSvc.TranslateChapter(&req)
	if err != nil {
		h.writeError(c, err, "chapter translation failed")
		return
	}

	c.JSON(http.StatusOK, model.SuccessResponse(result))
}

func (h *TranslationHandler) TranslateText(c *gin.Context) {
	var req service.TranslateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, err.Error()))
		return
	}

	result, err := h.translationSvc.TranslateText(&req)
	if err != nil {
		h.writeError(c, err, "translation failed")
		return
	}

	c.JSON(http.StatusOK, model.SuccessResponse(gin.H{
		"text": result,
		"from": req.From,
		"to":   req.To,
	}))
}

func (h *TranslationHandler) writeError(c *gin.Context, err error, fallback string) {
	switch {
	case errors.Is(err, service.ErrChapterNotFound):
		c.JSON(http.StatusNotFound, model.ErrorResponse(40402, "chapter not found"))
	case errors.Is(err, service.ErrTranslatorUnavailable):
		c.JSON(http.StatusServiceUnavailable, model.ErrorResponse(50301, "machine translation is not available"))
	case errors.Is(err, translate.ErrUpstream):
		log.Printf("translation: %v", err)
		c.JSON(http.StatusServiceUnavailable, model.ErrorResponse(50302, "translation provider error"))
	default:
		log.Printf("translation: %v", err)
		c.JSON(http.StatusInternalServerError, model.ErrorResponse(50001, fallback))
	}
}
