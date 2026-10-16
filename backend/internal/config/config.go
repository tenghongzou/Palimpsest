package config

import (
	"fmt"
	"os"
	"strings"
)

type Config struct {
	Server      ServerConfig
	DB          DatabaseConfig
	Redis       RedisConfig
	JWT         JWTConfig
	MinIO       MinIOConfig
	Meili       MeilisearchConfig
	CORS        CORSConfig
	Translation TranslationConfig
	Mail        MailConfig
	Moderation  ModerationConfig
	// WebBaseURL is the public address of the web app, used in emailed links.
	WebBaseURL string
}

// MailConfig configures outgoing email over SMTP. Without a host, emails
// are logged instead of sent (development only).
type MailConfig struct {
	Host     string
	Port     string
	Username string
	Password string
	From     string
}

// ModerationConfig configures the optional AI review of reviews and
// comments. It runs only when an Anthropic API key is set.
type ModerationConfig struct {
	AIEnabled bool
	AIAPIKey  string
	AIModel   string
	// AIBaseURL overrides the Anthropic API address (for tests or proxies).
	AIBaseURL string
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
	// MetricsPort serves Prometheus metrics on a separate, internal port;
	// empty disables it.
	MetricsPort string
	// TrustedProxies are the proxies whose X-Forwarded-For header is believed
	// when determining the client IP (used for rate limiting).
	TrustedProxies []string
	// RateLimitDisabled turns every rate limit off (RATE_LIMIT_ENABLED=false),
	// for load testing only.
	RateLimitDisabled bool
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
	Secret            string
	AccessExpiryHrs   int
	RefreshExpiryDays int
}

type MinIOConfig struct {
	Endpoint  string
	AccessKey string
	SecretKey string
	Bucket    string
	UseSSL    bool
	// PublicURL is where browsers fetch uploaded objects, without a trailing slash.
	PublicURL string
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
			Port:        getEnv("SERVER_PORT", "8080"),
			Mode:        getEnv("GIN_MODE", "debug"),
			MetricsPort: os.Getenv("METRICS_PORT"),
			TrustedProxies: parseList(getEnv("TRUSTED_PROXIES",
				"127.0.0.0/8,::1/128,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16")),
			RateLimitDisabled: getEnv("RATE_LIMIT_ENABLED", "true") == "false",
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
			Secret:            getEnv("JWT_SECRET", defaultJWTSecret),
			AccessExpiryHrs:   24,
			RefreshExpiryDays: 30,
		},
		MinIO: MinIOConfig{
			Endpoint:  getEnv("MINIO_ENDPOINT", "localhost:9000"),
			AccessKey: getEnv("MINIO_ACCESS_KEY", "minioadmin"),
			SecretKey: getEnv("MINIO_SECRET_KEY", "minioadmin"),
			Bucket:    getEnv("MINIO_BUCKET", "palimpsest"),
			UseSSL:    getEnv("MINIO_USE_SSL", "false") == "true",
			PublicURL: strings.TrimRight(getEnv("MINIO_PUBLIC_URL", "http://localhost:9000/palimpsest"), "/"),
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
		Mail: MailConfig{
			Host:     getEnv("SMTP_HOST", ""),
			Port:     getEnv("SMTP_PORT", "587"),
			Username: getEnv("SMTP_USERNAME", ""),
			Password: getEnv("SMTP_PASSWORD", ""),
			From:     getEnv("SMTP_FROM", "Palimpsest <no-reply@palimpsest.local>"),
		},
		Moderation: ModerationConfig{
			AIAPIKey:  os.Getenv("ANTHROPIC_API_KEY"),
			AIModel:   getEnv("MODERATION_AI_MODEL", "claude-haiku-5-5"),
			AIBaseURL: getEnv("ANTHROPIC_BASE_URL", ""),
		},
		WebBaseURL: strings.TrimRight(getEnv("WEB_BASE_URL", "http://localhost:3000"), "/"),
	}

	// AI review is on whenever a key is set, unless explicitly disabled.
	cfg.Moderation.AIEnabled = cfg.Moderation.AIAPIKey != "" && getEnv("MODERATION_AI_ENABLED", "true") != "false"

	if cfg.Server.Mode == "release" {
		if cfg.JWT.Secret == defaultJWTSecret || len(cfg.JWT.Secret) < 32 {
			return nil, fmt.Errorf("JWT_SECRET must be set to a random value of at least 32 characters in release mode")
		}
	}

	return cfg, nil
}

const defaultJWTSecret = "change-me-in-production"

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
