package main

import (
	"log"

	"github.com/tenghongzou/palimpsest/backend/internal/config"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("failed to load config: %v", err)
	}

	r := setupRouter(cfg)

	addr := ":" + cfg.Server.Port
	log.Printf("Palimpsest API server starting on %s", addr)
	if err := r.Run(addr); err != nil {
		log.Fatalf("failed to start server: %v", err)
	}
}
