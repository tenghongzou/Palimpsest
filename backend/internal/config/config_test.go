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

func TestLoadCORSDefault(t *testing.T) {
	os.Unsetenv("CORS_ALLOWED_ORIGINS")
	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() error: %v", err)
	}
	if len(cfg.CORS.AllowedOrigins) != 1 || cfg.CORS.AllowedOrigins[0] != "*" {
		t.Errorf("expected default CORS origins [*], got %v", cfg.CORS.AllowedOrigins)
	}
}

func TestLoadCORSCustomOrigins(t *testing.T) {
	os.Setenv("CORS_ALLOWED_ORIGINS", "https://palimpsest.app, https://admin.palimpsest.app")
	defer os.Unsetenv("CORS_ALLOWED_ORIGINS")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() error: %v", err)
	}
	if len(cfg.CORS.AllowedOrigins) != 2 {
		t.Fatalf("expected 2 CORS origins, got %d: %v", len(cfg.CORS.AllowedOrigins), cfg.CORS.AllowedOrigins)
	}
	if cfg.CORS.AllowedOrigins[0] != "https://palimpsest.app" {
		t.Errorf("expected first origin https://palimpsest.app, got %s", cfg.CORS.AllowedOrigins[0])
	}
	if cfg.CORS.AllowedOrigins[1] != "https://admin.palimpsest.app" {
		t.Errorf("expected second origin https://admin.palimpsest.app, got %s", cfg.CORS.AllowedOrigins[1])
	}
}

func TestParseOriginsEdgeCases(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected []string
	}{
		{"empty string", "", []string{"*"}},
		{"wildcard", "*", []string{"*"}},
		{"single origin", "https://example.com", []string{"https://example.com"}},
		{"multiple with spaces", " https://a.com , https://b.com ", []string{"https://a.com", "https://b.com"}},
		{"trailing comma", "https://a.com,", []string{"https://a.com"}},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := parseOrigins(tt.input)
			if len(result) != len(tt.expected) {
				t.Fatalf("parseOrigins(%q): got %d items, want %d: %v", tt.input, len(result), len(tt.expected), result)
			}
			for i, v := range result {
				if v != tt.expected[i] {
					t.Errorf("parseOrigins(%q)[%d] = %q, want %q", tt.input, i, v, tt.expected[i])
				}
			}
		})
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
