package config

import (
	"fmt"
	"os"
	"strings"
)

type Config struct {
	Server   ServerConfig
	DB       DatabaseConfig
	Redis    RedisConfig
	JWT      JWTConfig
	MinIO    MinIOConfig
	Meili    MeilisearchConfig
	CORS     CORSConfig
	Translation TranslationConfig
}

type TranslationConfig struct {
	GoogleAPIKey string
	// GoogleEndpoint overrides the Cloud Translation v2 URL (for tests or proxies).
	GoogleEndpoint string
}

type CORSConfig struct {
	AllowedOrigins []string
}

type ServerConfig struct {
	Port string
	Mode string // debug, release, test
	// TrustedProxies are the proxies whose X-Forwarded-For header is believed
	// when determining the client IP (used for rate limiting).
	TrustedProxies []string
}

type DatabaseConfig struct {
	Host     string
	Port     string
	User     string
	Password string
	DBName   string
	SSLMode  string
}

type RedisConfig struct {
	Host     string
	Port     string
	Password string
	DB       int
}

type JWTConfig struct {
	Secret           string
	AccessExpiryHrs  int
	RefreshExpiryDays int
}

type MinIOConfig struct {
	Endpoint  string
	AccessKey string
	SecretKey string
	Bucket    string
	UseSSL    bool
}

type MeilisearchConfig struct {
	Host   string
	APIKey string
}

func (d DatabaseConfig) DSN() string {
	return fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		d.Host, d.Port, d.User, d.Password, d.DBName, d.SSLMode,
	)
}

func Load() (*Config, error) {
	cfg := &Config{
		Server: ServerConfig{
			Port: getEnv("SERVER_PORT", "8080"),
			Mode: getEnv("GIN_MODE", "debug"),
			TrustedProxies: parseList(getEnv("TRUSTED_PROXIES",
				"127.0.0.0/8,::1/128,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16")),
		},
		DB: DatabaseConfig{
			Host:     getEnv("DB_HOST", "localhost"),
			Port:     getEnv("DB_PORT", "5432"),
			User:     getEnv("DB_USER", "palimpsest"),
			Password: getEnv("DB_PASSWORD", "palimpsest"),
			DBName:   getEnv("DB_NAME", "palimpsest"),
			SSLMode:  getEnv("DB_SSLMODE", "disable"),
		},
		Redis: RedisConfig{
			Host:     getEnv("REDIS_HOST", "localhost"),
			Port:     getEnv("REDIS_PORT", "6379"),
			Password: getEnv("REDIS_PASSWORD", ""),
			DB:       0,
		},
		JWT: JWTConfig{
			Secret:            getEnv("JWT_SECRET", "change-me-in-production"),
			AccessExpiryHrs:   24,
			RefreshExpiryDays: 30,
		},
		MinIO: MinIOConfig{
			Endpoint:  getEnv("MINIO_ENDPOINT", "localhost:9000"),
			AccessKey: getEnv("MINIO_ACCESS_KEY", "minioadmin"),
			SecretKey: getEnv("MINIO_SECRET_KEY", "minioadmin"),
			Bucket:    getEnv("MINIO_BUCKET", "palimpsest"),
			UseSSL:    false,
		},
		Meili: MeilisearchConfig{
			Host:   getEnv("MEILI_HOST", "http://localhost:7700"),
			APIKey: getEnv("MEILI_API_KEY", ""),
		},
		CORS: CORSConfig{
			AllowedOrigins: parseOrigins(getEnv("CORS_ALLOWED_ORIGINS", "*")),
		},
		Translation: TranslationConfig{
			GoogleAPIKey:   getEnv("GOOGLE_TRANSLATE_API_KEY", ""),
			GoogleEndpoint: getEnv("GOOGLE_TRANSLATE_ENDPOINT", ""),
		},
	}

	return cfg, nil
}

func parseOrigins(raw string) []string {
	if raw == "" || raw == "*" {
		return []string{"*"}
	}
	parts := strings.Split(raw, ",")
	origins := make([]string, 0, len(parts))
	for _, p := range parts {
		if o := strings.TrimSpace(p); o != "" {
			origins = append(origins, o)
		}
	}
	if len(origins) == 0 {
		return []string{"*"}
	}
	return origins
}

// parseList splits a comma-separated value, dropping empty entries.
func parseList(raw string) []string {
	var out []string
	for _, p := range strings.Split(raw, ",") {
		if v := strings.TrimSpace(p); v != "" {
			out = append(out, v)
		}
	}
	return out
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
