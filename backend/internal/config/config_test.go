package config

import (
	"os"
	"testing"
)

func TestLoad(t *testing.T) {
	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() returned error: %v", err)
	}
	if cfg == nil {
		t.Fatal("Load() returned nil config")
	}
	if cfg.Server.Port != "8080" {
		t.Errorf("expected default port 8080, got %s", cfg.Server.Port)
	}
	if cfg.Server.Mode != "debug" {
		t.Errorf("expected default mode debug, got %s", cfg.Server.Mode)
	}
}

func TestLoadWithEnv(t *testing.T) {
	os.Setenv("SERVER_PORT", "9090")
	os.Setenv("GIN_MODE", "release")
	defer func() {
		os.Unsetenv("SERVER_PORT")
		os.Unsetenv("GIN_MODE")
	}()

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() returned error: %v", err)
	}
	if cfg.Server.Port != "9090" {
		t.Errorf("expected port 9090, got %s", cfg.Server.Port)
	}
	if cfg.Server.Mode != "release" {
		t.Errorf("expected mode release, got %s", cfg.Server.Mode)
	}
}

func TestDatabaseDSN(t *testing.T) {
	cfg := DatabaseConfig{
		Host:     "localhost",
		Port:     "5432",
		User:     "test",
		Password: "pass",
		DBName:   "testdb",
		SSLMode:  "disable",
	}
	expected := "host=localhost port=5432 user=test password=pass dbname=testdb sslmode=disable"
	if dsn := cfg.DSN(); dsn != expected {
		t.Errorf("DSN() = %q, want %q", dsn, expected)
	}
}
