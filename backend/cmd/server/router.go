package main

import (
	"errors"
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
	User        *handler.UserHandler
	Novel       *handler.NovelHandler
	Home        *handler.HomeHandler
	Bookshelf   *handler.BookshelfHandler
	Bookmark    *handler.BookmarkHandler
	Community   *handler.CommunityHandler
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
	// Each credential endpoint gets its own tight per-IP quota against brute forcing.
	credentialLimit := middleware.RateLimiterWithRedis(rdb, "", 5, time.Minute)
	optionalAuth := middleware.OptionalAuth(cfg)

	// --- Auth routes (public) ---
	auth := v1.Group("/auth")
	{
		auth.POST("/register", credentialLimit, h.Auth.Register)
		auth.POST("/login", credentialLimit, h.Auth.Login)
		auth.POST("/refresh", h.Auth.RefreshToken)
		auth.POST("/logout", h.Auth.Logout)
		auth.POST("/forgot-password", credentialLimit, h.Auth.ForgotPassword)
		auth.POST("/reset-password", credentialLimit, h.Auth.ResetPassword)
	}

	// --- Public content routes ---
	v1.GET("/home", h.Home.Home)
	v1.GET("/banners", h.Home.Banners)
	v1.GET("/novels", h.Novel.List)
	v1.GET("/novels/:id", h.Novel.GetByID)
	v1.GET("/novels/:id/chapters", h.Novel.ListChapters)
	v1.GET("/novels/:id/chapters/:chapterId", h.Novel.GetChapter)
	v1.GET("/novels/:id/reviews", optionalAuth, h.Community.ListReviews)
	v1.GET("/chapters/:chapterId", h.Novel.GetChapter)
	v1.GET("/chapters/:chapterId/comments", optionalAuth, h.Community.ListComments)
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
		if page < 1 {
			page = 1
		}
		if pageSize < 1 || pageSize > 100 {
			pageSize = 20
		}

		novels, total, err := h.Ranking.GetRanking(rankType, period, page, pageSize)
		if errors.Is(err, service.ErrNotFound) {
			c.JSON(http.StatusNotFound, model.ErrorResponse(40409, "unknown ranking type"))
			return
		}
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
	protected.Use(middleware.Auth(cfg), middleware.RejectBanned(rdb))
	{
		// Current user
		protected.GET("/users/me", h.User.Me)
		protected.PATCH("/users/me", h.User.UpdateMe)
		protected.POST("/users/me/avatar", h.User.UploadAvatar)
		protected.PUT("/users/me/password", h.User.ChangePassword)
		protected.GET("/users/me/reading-stats", h.User.ReadingStats)
		protected.GET("/users/me/reading-settings", h.User.GetReadingSettings)
		protected.PUT("/users/me/reading-settings", h.User.PutReadingSettings)

		// Bookshelf
		protected.GET("/bookshelf", h.Bookshelf.List)
		protected.POST("/bookshelf", h.Bookshelf.Add)
		protected.POST("/bookshelf/batch-remove", h.Bookshelf.BatchRemove)
		protected.PATCH("/bookshelf/:novelId", h.Bookshelf.SetGroup)
		protected.DELETE("/bookshelf/:novelId", h.Bookshelf.Remove)

		// Reading progress and history
		protected.GET("/reading-progress", h.Bookshelf.ListProgress)
		protected.POST("/reading-progress/batch", h.Bookshelf.BatchProgress)
		protected.PUT("/reading-progress/:novelId", h.Bookshelf.UpdateProgress)
		protected.GET("/reading-progress/:novelId", h.Bookshelf.GetProgress)
		protected.GET("/reading-history", h.Bookshelf.History)

		// Bookmarks
		protected.GET("/bookmarks", h.Bookmark.List)
		protected.POST("/bookmarks", h.Bookmark.Create)
		protected.POST("/bookmarks/sync", h.Bookmark.Sync)
		protected.PATCH("/bookmarks/:bookmarkId", h.Bookmark.Update)
		protected.DELETE("/bookmarks/:bookmarkId", h.Bookmark.Delete)

		// Community
		protected.POST("/novels/:id/reviews", h.Community.CreateReview)
		protected.PUT("/reviews/:reviewId", h.Community.UpdateReview)
		protected.DELETE("/reviews/:reviewId", h.Community.DeleteReview)
		protected.POST("/reviews/:reviewId/like", h.Community.LikeReview)
		protected.DELETE("/reviews/:reviewId/like", h.Community.UnlikeReview)
		protected.POST("/chapters/:chapterId/comments", h.Community.CreateComment)
		protected.DELETE("/comments/:commentId", h.Community.DeleteComment)
		protected.POST("/comments/:commentId/like", h.Community.LikeComment)
		protected.DELETE("/comments/:commentId/like", h.Community.UnlikeComment)
		protected.POST("/reports", h.Community.CreateReport)

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
	admin.Use(middleware.Auth(cfg), middleware.RejectBanned(rdb))
	admin.Use(middleware.AdminOnly())
	{
		// Novel management
		admin.GET("/novels", h.Admin.ListNovels)
		admin.POST("/novels", h.Admin.CreateNovel)
		admin.GET("/novels/:id", h.Admin.GetNovel)
		admin.PUT("/novels/:id", h.Admin.UpdateNovel)
		admin.DELETE("/novels/:id", h.Admin.DeleteNovel)
		admin.POST("/novels/:id/publish", h.Admin.PublishNovel)

		// Chapter management
		admin.GET("/novels/:id/chapters", h.Admin.ListChapters)
		admin.POST("/novels/:id/chapters", h.Admin.CreateChapter)
		admin.POST("/novels/:id/chapters/batch", h.Admin.BatchImportChapters)
		admin.GET("/chapters/:chapterId", h.Admin.GetChapter)
		admin.PUT("/chapters/:chapterId", h.Admin.UpdateChapter)
		admin.DELETE("/chapters/:chapterId", h.Admin.DeleteChapter)

		// Categories and banners
		admin.GET("/categories", h.Admin.ListCategories)
		admin.POST("/categories", h.Admin.CreateCategory)
		admin.PUT("/categories/:categoryId", h.Admin.UpdateCategory)
		admin.DELETE("/categories/:categoryId", h.Admin.DeleteCategory)
		admin.GET("/banners", h.Admin.ListBanners)
		admin.POST("/banners", h.Admin.CreateBanner)
		admin.PUT("/banners/:bannerId", h.Admin.UpdateBanner)
		admin.DELETE("/banners/:bannerId", h.Admin.DeleteBanner)
		admin.POST("/uploads", h.Admin.UploadImage)

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
