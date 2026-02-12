package handler

import (
	"github.com/gin-gonic/gin"
)

type TranslationHandler struct {
	// TODO: inject TranslationService
}

func NewTranslationHandler() *TranslationHandler {
	return &TranslationHandler{}
}

func (h *TranslationHandler) Convert(c *gin.Context) {
	// TODO: implement POST /translation/convert (zh-TW <-> zh-CN via OpenCC)
}

func (h *TranslationHandler) TranslateChapter(c *gin.Context) {
	// TODO: implement POST /translation/chapter (Google Translate)
}

func (h *TranslationHandler) TranslateText(c *gin.Context) {
	// TODO: implement POST /translation/text
}
