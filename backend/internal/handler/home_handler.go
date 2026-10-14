package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/service"
)

type HomeHandler struct {
	homeSvc *service.HomeService
}

func NewHomeHandler(homeSvc *service.HomeService) *HomeHandler {
	return &HomeHandler{homeSvc: homeSvc}
}

func (h *HomeHandler) Home(c *gin.Context) {
	page, err := h.homeSvc.Home()
	if err != nil {
		serviceError(c, err, 40401, "")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(page))
}

func (h *HomeHandler) Banners(c *gin.Context) {
	banners, err := h.homeSvc.ActiveBanners()
	if err != nil {
		serviceError(c, err, 40401, "")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(banners))
}
