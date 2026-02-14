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
	"github.com/redis/go-redis/v9"
	"github.com/tenghongzou/palimpsest/backend/internal/config"
	"github.com/tenghongzou/palimpsest/backend/internal/handler"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
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
	if err := db.AutoMigrate(
		&model.User{},
		&model.Category{},
		&model.Tag{},
		&model.Novel{},
		&model.Volume{},
		&model.Chapter{},
		&model.BookshelfItem{},
		&model.ReadingProgress{},
		&model.Bookmark{},
		&model.Review{},
		&model.Comment{},
	); err != nil {
		log.Fatalf("failed to auto-migrate: %v", err)
	}

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
	if err != nil {
		log.Printf("WARNING: MinIO connection failed: %v (continuing without object storage)", err)
	}
	_ = minioClient // used by future upload handlers

	// --- Repositories ---
	userRepo := repository.NewUserRepository(db)
	novelRepo := repository.NewNovelRepository(db)
	bookshelfRepo := repository.NewBookshelfRepository(db)
	cacheRepo := repository.NewCacheRepository(rdb)

	// --- Services ---
	authSvc := service.NewAuthService(userRepo, cfg)
	novelSvc := service.NewNovelService(novelRepo, cacheRepo)
	bookshelfSvc := service.NewBookshelfService(bookshelfRepo, db)
	searchSvc := service.NewSearchService(meiliClient, novelRepo)
	rankingSvc := service.NewRankingService(rdb, novelRepo)
	translationSvc := service.NewTranslationService(cacheRepo, db)

	// --- Handlers ---
	authH := handler.NewAuthHandler(authSvc)
	novelH := handler.NewNovelHandler(novelSvc)
	bookshelfH := handler.NewBookshelfHandler(bookshelfSvc)
	searchH := handler.NewSearchHandler(searchSvc)
	translationH := handler.NewTranslationHandler(translationSvc)
	adminH := handler.NewAdminHandler(novelRepo, db)

	// --- Router ---
	handlers := &Handlers{
		Auth:        authH,
		Novel:       novelH,
		Bookshelf:   bookshelfH,
		Search:      searchH,
		Translation: translationH,
		Admin:       adminH,
		Ranking:     rankingSvc,
	}
	r := setupRouter(cfg, rdb, handlers)

	// --- Server with graceful shutdown ---
	srv := &http.Server{
		Addr:    ":" + cfg.Server.Port,
		Handler: r,
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

	sqlDB.Close()
	rdb.Close()
	log.Println("Server exited")
}
