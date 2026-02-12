package handler

import (
	"github.com/gin-gonic/gin"
)

type AdminHandler struct {
	// TODO: inject admin services
}

func NewAdminHandler() *AdminHandler {
	return &AdminHandler{}
}

// Novel management
func (h *AdminHandler) ListNovels(c *gin.Context)   {}
func (h *AdminHandler) CreateNovel(c *gin.Context)   {}
func (h *AdminHandler) UpdateNovel(c *gin.Context)   {}
func (h *AdminHandler) DeleteNovel(c *gin.Context)   {}
func (h *AdminHandler) PublishNovel(c *gin.Context)  {}

// Chapter management
func (h *AdminHandler) CreateChapter(c *gin.Context)      {}
func (h *AdminHandler) UpdateChapter(c *gin.Context)      {}
func (h *AdminHandler) DeleteChapter(c *gin.Context)      {}
func (h *AdminHandler) BatchImportChapters(c *gin.Context) {}

// User management
func (h *AdminHandler) ListUsers(c *gin.Context)        {}
func (h *AdminHandler) GetUser(c *gin.Context)          {}
func (h *AdminHandler) UpdateUserStatus(c *gin.Context) {}

// Content moderation
func (h *AdminHandler) ListReviews(c *gin.Context)       {}
func (h *AdminHandler) ModerateReview(c *gin.Context)    {}
func (h *AdminHandler) ListReports(c *gin.Context)       {}
func (h *AdminHandler) ResolveReport(c *gin.Context)     {}

// Stats
func (h *AdminHandler) StatsOverview(c *gin.Context) {}
