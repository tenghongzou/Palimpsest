package main

import (
	"log"
	"math"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
	"github.com/tenghongzou/palimpsest/backend/internal/config"
	"github.com/tenghongzou/palimpsest/backend/internal/handler"
	"github.com/tenghongzou/palimpsest/backend/internal/middleware"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/service"
)

type Handlers struct {
	Auth        *handler.AuthHandler
	Novel       *handler.NovelHandler
	Bookshelf   *handler.BookshelfHandler
	Search      *handler.SearchHandler
	Translation *handler.TranslationHandler
	Admin       *handler.AdminHandler
	Ranking     *service.RankingService
}

func setupRouter(cfg *config.Config, rdb *redis.Client, h *Handlers) *gin.Engine {
	if cfg.Server.Mode == "release" {
		gin.SetMode(gin.ReleaseMode)
	}

	r := gin.New()
	if err := r.SetTrustedProxies(cfg.Server.TrustedProxies); err != nil {
		log.Fatalf("invalid TRUSTED_PROXIES: %v", err)
	}

	// Middleware chain: Recovery -> Logger -> CORS
	r.Use(gin.Recovery())
	r.Use(middleware.Logger())
	r.Use(middleware.CORS(cfg))

	// Health check
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})

	// API v1: 60 req/min per IP for anonymous clients, 120 req/min per user when authenticated
	v1 := r.Group("/api/v1")
	v1.Use(middleware.GlobalRateLimiter(rdb, cfg, 60, 120, time.Minute))
	translationLimit := middleware.RateLimiterWithRedis(rdb, "translation", 20, time.Minute)

	// --- Auth routes (public) ---
	auth := v1.Group("/auth")
	{
		auth.POST("/register", h.Auth.Register)
		auth.POST("/login", h.Auth.Login)
		auth.POST("/refresh", h.Auth.RefreshToken)
		auth.POST("/logout", h.Auth.Logout)
		auth.POST("/forgot-password", h.Auth.ForgotPassword)
		auth.POST("/reset-password", h.Auth.ResetPassword)
	}

	// --- Public content routes ---
	v1.GET("/novels", h.Novel.List)
	v1.GET("/novels/:id", h.Novel.GetByID)
	v1.GET("/novels/:id/chapters", h.Novel.ListChapters)
	v1.GET("/novels/:id/chapters/:chapterId", h.Novel.GetChapter)
	v1.GET("/chapters/:chapterId", h.Novel.GetChapter)
	v1.GET("/categories", h.Novel.ListCategories)
	v1.GET("/search/novels", h.Search.SearchNovels)
	v1.GET("/search/suggestions", h.Search.Suggestions)
	v1.GET("/search/hot-keywords", h.Search.HotKeywords)
	v1.POST("/translation/convert", translationLimit, h.Translation.Convert)

	// --- Rankings ---
	v1.GET("/rankings/:type", func(c *gin.Context) {
		rankType := c.Param("type")
		period := c.DefaultQuery("period", "weekly")
		page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
		pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))

		novels, total, err := h.Ranking.GetRanking(rankType, period, page, pageSize)
		if err != nil {
			c.JSON(http.StatusInternalServerError, model.ErrorResponse(50001, "failed to get ranking"))
			return
		}

		c.JSON(http.StatusOK, model.SuccessResponse(model.PaginatedResponse{
			Items: novels,
			Pagination: model.Pagination{
				Page: page, PageSize: pageSize, Total: int(total),
				TotalPages: int(math.Ceil(float64(total) / float64(pageSize))),
			},
		}))
	})

	// --- Protected routes (requires auth) ---
	protected := v1.Group("")
	protected.Use(middleware.Auth(cfg))
	{
		// Bookshelf
		protected.GET("/bookshelf", h.Bookshelf.List)
		protected.POST("/bookshelf", h.Bookshelf.Add)
		protected.DELETE("/bookshelf/:novelId", h.Bookshelf.Remove)

		// Reading progress
		protected.GET("/reading-progress", h.Bookshelf.ListProgress)
		protected.PUT("/reading-progress/:novelId", h.Bookshelf.UpdateProgress)
		protected.GET("/reading-progress/:novelId", h.Bookshelf.GetProgress)

		// Translation (shares the 20 req/min quota with /translation/convert)
		translation := protected.Group("/translation")
		translation.Use(translationLimit)
		{
			translation.POST("/chapter", h.Translation.TranslateChapter)
			translation.POST("/text", h.Translation.TranslateText)
		}
	}

	// --- Admin routes ---
	admin := v1.Group("/admin")
	admin.Use(middleware.Auth(cfg))
	admin.Use(middleware.AdminOnly())
	{
		// Novel management
		admin.GET("/novels", h.Admin.ListNovels)
		admin.POST("/novels", h.Admin.CreateNovel)
		admin.PUT("/novels/:id", h.Admin.UpdateNovel)
		admin.DELETE("/novels/:id", h.Admin.DeleteNovel)
		admin.POST("/novels/:id/publish", h.Admin.PublishNovel)

		// Chapter management
		admin.POST("/novels/:id/chapters", h.Admin.CreateChapter)
		admin.PUT("/chapters/:chapterId", h.Admin.UpdateChapter)
		admin.DELETE("/chapters/:chapterId", h.Admin.DeleteChapter)
		admin.POST("/novels/:id/chapters/batch", h.Admin.BatchImportChapters)

		// User management
		admin.GET("/users", h.Admin.ListUsers)
		admin.GET("/users/:userId", h.Admin.GetUser)
		admin.PUT("/users/:userId/status", h.Admin.UpdateUserStatus)

		// Content moderation
		admin.GET("/reviews", h.Admin.ListReviews)
		admin.PUT("/reviews/:reviewId", h.Admin.ModerateReview)
		admin.GET("/reports", h.Admin.ListReports)
		admin.PUT("/reports/:reportId", h.Admin.ResolveReport)

		// Stats
		admin.GET("/stats", h.Admin.StatsOverview)
	}

	return r
}
