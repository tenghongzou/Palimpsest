package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
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
		c.JSON(http.StatusInternalServerError, model.ErrorResponse(50001, "conversion failed"))
		return
	}

	c.JSON(http.StatusOK, model.SuccessResponse(gin.H{
		"text":      result,
		"direction": req.Direction,
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
		c.JSON(http.StatusInternalServerError, model.ErrorResponse(50001, "chapter translation failed"))
		return
	}

	c.JSON(http.StatusOK, model.SuccessResponse(gin.H{
		"content":     result,
		"chapter_id":  req.ChapterID,
		"target_lang": req.TargetLang,
	}))
}

func (h *TranslationHandler) TranslateText(c *gin.Context) {
	var req service.TranslateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, err.Error()))
		return
	}

	result, err := h.translationSvc.TranslateText(&req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, model.ErrorResponse(50001, "translation failed"))
		return
	}

	c.JSON(http.StatusOK, model.SuccessResponse(gin.H{
		"text":        result,
		"target_lang": req.TargetLang,
	}))
}
