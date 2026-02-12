package main

import (
	"github.com/gin-gonic/gin"
	"github.com/tenghongzou/palimpsest/backend/internal/config"
	"github.com/tenghongzou/palimpsest/backend/internal/middleware"
)

func setupRouter(cfg *config.Config) *gin.Engine {
	r := gin.New()

	// Middleware chain: Recovery → Logger → CORS → RateLimiter
	r.Use(gin.Recovery())
	r.Use(middleware.Logger())
	r.Use(middleware.CORS(cfg))
	r.Use(middleware.RateLimiter())

	// Health check
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})

	// API v1
	v1 := r.Group("/api/v1")
	{
		// Public routes
		auth := v1.Group("/auth")
		{
			_ = auth // TODO: register auth handlers
		}

		// Public content routes
		v1.GET("/home", nil)           // TODO: home handler
		v1.GET("/novels", nil)         // TODO: novels list
		v1.GET("/novels/:id", nil)     // TODO: novel detail
		v1.GET("/categories", nil)     // TODO: categories
		v1.GET("/search/novels", nil)  // TODO: search
		v1.GET("/rankings/:type", nil) // TODO: rankings

		// Protected routes
		protected := v1.Group("")
		protected.Use(middleware.Auth(cfg))
		{
			_ = protected // TODO: register protected handlers
		}

		// Admin routes
		admin := v1.Group("/admin")
		admin.Use(middleware.Auth(cfg))
		{
			_ = admin // TODO: register admin handlers
		}
	}

	return r
}
