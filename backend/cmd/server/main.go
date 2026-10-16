package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/meilisearch/meilisearch-go"
	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/collectors"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/redis/go-redis/v9"
	"github.com/tenghongzou/palimpsest/backend/internal/config"
	"github.com/tenghongzou/palimpsest/backend/internal/handler"
	"github.com/tenghongzou/palimpsest/backend/internal/middleware"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/pkg/mail"
	"github.com/tenghongzou/palimpsest/backend/internal/pkg/moderation"
	"github.com/tenghongzou/palimpsest/backend/internal/pkg/storage"
	"github.com/tenghongzou/palimpsest/backend/internal/pkg/translate"
	"github.com/tenghongzou/palimpsest/backend/internal/repository"
	"github.com/tenghongzou/palimpsest/backend/internal/service"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("failed to load config: %v", err)
	}

	// --- Database ---
	gormLogLevel := logger.Info
	if cfg.Server.Mode == "release" {
		gormLogLevel = logger.Warn
	}
	db, err := gorm.Open(postgres.Open(cfg.DB.DSN()), &gorm.Config{
		Logger: logger.Default.LogMode(gormLogLevel),
	})
	if err != nil {
		log.Fatalf("failed to connect database: %v", err)
	}
	sqlDB, _ := db.DB()
	sqlDB.SetMaxOpenConns(25)
	sqlDB.SetMaxIdleConns(10)
	sqlDB.SetConnMaxLifetime(5 * time.Minute)

	// Auto-migrate models
	if err := db.AutoMigrate(model.All()...); err != nil {
		log.Fatalf("failed to auto-migrate: %v", err)
	}
	dropLegacyIndexes(db)

	// --- Redis ---
	rdb := redis.NewClient(&redis.Options{
		Addr:     fmt.Sprintf("%s:%s", cfg.Redis.Host, cfg.Redis.Port),
		Password: cfg.Redis.Password,
		DB:       cfg.Redis.DB,
	})
	if err := rdb.Ping(context.Background()).Err(); err != nil {
		log.Printf("WARNING: Redis connection failed: %v (continuing without cache)", err)
	}

	// --- Meilisearch ---
	meiliClient := meilisearch.NewClient(meilisearch.ClientConfig{
		Host:   cfg.Meili.Host,
		APIKey: cfg.Meili.APIKey,
	})

	// --- MinIO ---
	minioClient, err := minio.New(cfg.MinIO.Endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.MinIO.AccessKey, cfg.MinIO.SecretKey, ""),
		Secure: cfg.MinIO.UseSSL,
	})
	var store storage.Store
	if err != nil {
		log.Printf("WARNING: MinIO client setup failed: %v (uploads disabled)", err)
	} else {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		store, err = storage.NewMinIO(ctx, minioClient, cfg.MinIO.Bucket, cfg.MinIO.PublicURL)
		cancel()
		if err != nil {
			log.Printf("WARNING: MinIO unavailable: %v (uploads disabled)", err)
		}
	}

	// --- Repositories ---
	userRepo := repository.NewUserRepository(db)
	novelRepo := repository.NewNovelRepository(db)
	bookshelfRepo := repository.NewBookshelfRepository(db)
	cacheRepo := repository.NewCacheRepository(rdb)
	recommendationRepo := repository.NewRecommendationRepository(db)

	// --- Services ---
	authSvc := service.NewAuthService(userRepo, cfg, mail.New(cfg))
	recommendationSvc := service.NewRecommendationService(recommendationRepo, novelRepo, cacheRepo)
	bookshelfSvc := service.NewBookshelfService(bookshelfRepo, db).OnChange(recommendationSvc.InvalidateUser)
	searchSvc := service.NewSearchService(meiliClient, rdb, novelRepo)
	rankingSvc := service.NewRankingService(rdb, novelRepo)
	novelSvc := service.NewNovelService(novelRepo, cacheRepo, rankingSvc)
	homeSvc := service.NewHomeService(db, rdb)
	userSvc := service.NewUserService(db)
	bookmarkSvc := service.NewBookmarkService(db)
	notificationSvc := service.NewNotificationService(db)
	moderationSvc := service.NewModerationService(db)
	if cfg.Moderation.AIEnabled {
		reviewer := moderation.NewAIReviewer(cfg.Moderation.AIAPIKey, cfg.Moderation.AIModel, cfg.Moderation.AIBaseURL)
		moderationSvc.WithAI(reviewer, 4, 20*time.Second)
		log.Printf("Moderation: AI review enabled (%s)", cfg.Moderation.AIModel)
	}
	communitySvc := service.NewCommunityService(db, novelSvc.InvalidateNovel).
		WithNotifications(notificationSvc).WithModeration(moderationSvc)
	adminSvc := service.NewAdminService(db)
	var translator translate.MachineTranslator
	if g := translate.NewGoogleTranslator(cfg.Translation.GoogleAPIKey, cfg.Translation.GoogleEndpoint); g != nil {
		translator = g
	} else {
		log.Printf("WARNING: GOOGLE_TRANSLATE_API_KEY not set; only zh-TW/zh-CN conversion is available")
	}
	translationSvc := service.NewTranslationService(cacheRepo, db, translator)

	// --- Handlers ---
	authH := handler.NewAuthHandler(authSvc)
	novelH := handler.NewNovelHandler(novelSvc)
	bookshelfH := handler.NewBookshelfHandler(bookshelfSvc)
	searchH := handler.NewSearchHandler(searchSvc)
	translationH := handler.NewTranslationHandler(translationSvc)
	adminH := handler.NewAdminHandler(handler.AdminDeps{
		NovelRepo: novelRepo, NovelSvc: novelSvc, AdminSvc: adminSvc, CommunitySvc: communitySvc, ModerationSvc: moderationSvc,
		HomeSvc: homeSvc, SearchSvc: searchSvc, Notifications: notificationSvc, Store: store, DB: db, Redis: rdb,
	})

	// Configure the search index and backfill it without blocking startup.
	go func() {
		if err := searchSvc.EnsureIndex(); err != nil {
			log.Printf("WARNING: Meilisearch index setup failed: %v", err)
			return
		}
		n, err := searchSvc.ReindexAll()
		if err != nil {
			log.Printf("WARNING: Meilisearch reindex failed after %d novels: %v", n, err)
			return
		}
		log.Printf("Meilisearch: indexed %d published novels", n)
	}()

	// --- Router ---
	handlers := &Handlers{
		Auth:           authH,
		User:           handler.NewUserHandler(userSvc, store),
		Novel:          novelH,
		Home:           handler.NewHomeHandler(homeSvc),
		Bookshelf:      bookshelfH,
		Bookmark:       handler.NewBookmarkHandler(bookmarkSvc),
		Community:      handler.NewCommunityHandler(communitySvc),
		Search:         searchH,
		Translation:    translationH,
		Admin:          adminH,
		Notification:   handler.NewNotificationHandler(notificationSvc),
		Recommendation: handler.NewRecommendationHandler(recommendationSvc),
		Ranking:        rankingSvc,
	}
	// --- Metrics (separate port, never exposed through the ingress) ---
	var metricsSrv *http.Server
	if cfg.Server.MetricsPort != "" {
		reg := prometheus.NewRegistry()
		reg.MustRegister(
			collectors.NewGoCollector(),
			collectors.NewProcessCollector(collectors.ProcessCollectorOpts{}),
			collectors.NewDBStatsCollector(sqlDB, "palimpsest"),
		)
		handlers.Metrics = middleware.NewHTTPMetrics(reg)
		mux := http.NewServeMux()
		mux.Handle("/metrics", promhttp.HandlerFor(reg, promhttp.HandlerOpts{}))
		metricsSrv = &http.Server{Addr: ":" + cfg.Server.MetricsPort, Handler: mux, ReadHeaderTimeout: 5 * time.Second}
		go func() {
			log.Printf("Metrics listening on :%s/metrics", cfg.Server.MetricsPort)
			if err := metricsSrv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
				log.Printf("WARNING: metrics server stopped: %v", err)
			}
		}()
	}

	r := setupRouter(cfg, rdb, handlers)

	// --- Server with graceful shutdown ---
	srv := &http.Server{
		Addr:    ":" + cfg.Server.Port,
		Handler: r,
		// Bounds how long a client may take to send headers (slowloris).
		ReadHeaderTimeout: 10 * time.Second,
	}

	go func() {
		log.Printf("Palimpsest API server starting on :%s", cfg.Server.Port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("failed to start server: %v", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("Shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("server forced to shutdown: %v", err)
	}
	if metricsSrv != nil {
		_ = metricsSrv.Shutdown(ctx)
	}
	// Let AI reviews already under way record their verdicts.
	waited := make(chan struct{})
	go func() { moderationSvc.Wait(); close(waited) }()
	select {
	case <-waited:
	case <-ctx.Done():
	}

	sqlDB.Close()
	rdb.Close()
	log.Println("Server exited")
}

// dropLegacyIndexes removes indexes created by earlier model definitions that
// AutoMigrate does not clean up. Chapter and volume numbers used to be unique
// across all novels instead of per novel, so only one novel could have a
// "chapter 1".
func dropLegacyIndexes(db *gorm.DB) {
	legacy := []struct {
		model interface{}
		index string
	}{
		{&model.Chapter{}, "idx_novel_chapter"},
		{&model.Volume{}, "idx_novel_volume"},
	}
	for _, l := range legacy {
		if db.Migrator().HasIndex(l.model, l.index) {
			if err := db.Migrator().DropIndex(l.model, l.index); err != nil {
				log.Printf("WARNING: failed to drop legacy index %s: %v", l.index, err)
			}
		}
	}
}
