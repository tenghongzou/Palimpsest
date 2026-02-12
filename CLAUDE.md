# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Palimpsest is a cross-platform Chinese novel reading application (similar to Qidian/起點中文網). It supports Traditional Chinese, Simplified Chinese, and English, with real-time translation (OpenCC for zh-TW/zh-CN conversion, Google Translate for English). The project is currently in the documentation/planning phase (Phase 0) with no source code yet.

## Tech Stack

- **Backend:** Go 1.22+ (Gin framework), GORM v2, PostgreSQL 16+, Redis 7+, Meilisearch 1.6+, MinIO
- **Web Frontend:** Nuxt 3, Vue 3, TypeScript 5.x, Pinia, Naive UI, UnoCSS, sql.js (WebAssembly SQLite)
- **Mobile/Desktop:** Flutter 3.x, Dart 3.x, Riverpod 2.x, sqflite, Dio 5.x, go_router
- **Infrastructure:** Docker Compose (dev), Kubernetes (prod), GitHub Actions CI/CD

## Planned Build & Dev Commands

### Backend (Go)
```bash
go build ./cmd/server            # Build server
go test ./...                    # Run all tests
go test ./internal/service/...   # Run tests for a specific package
golangci-lint run                # Lint
```

### Web Frontend (Nuxt 3)
```bash
npm run dev                      # Dev server
npm run build                    # Production build
npx vitest                       # Run unit tests
npx vitest run path/to/test      # Run single test
npx playwright test              # E2E tests
```

### Flutter (Mobile/Desktop)
```bash
flutter run                      # Run dev build
flutter build apk               # Build Android APK
flutter test                     # Run all tests
flutter test test/path_test.dart # Run single test
dart analyze                     # Lint
```

### Infrastructure
```bash
docker-compose up -d             # Start local dev services (PostgreSQL, Redis, MinIO, Meilisearch)
```

### Type Generation from OpenAPI Spec
```bash
npx openapi-typescript ./shared/api-spec/openapi.yaml -o ./web/types/api.d.ts  # Web types
dart run build_runner build      # Flutter models (json_serializable)
```

## Architecture

### System Layers
```
Clients (Nuxt 3 Web / Flutter Mobile+Desktop)
  → Nginx/Traefik (reverse proxy, rate limiting)
    → Go Gin REST API (:8080)
      → PostgreSQL (primary data), Redis (cache/rankings), Meilisearch (search), MinIO (object storage)
```

### Backend Layered Architecture
Router (Gin + middleware) → Handler (request validation, response formatting) → Service (business logic) → Repository (data access via GORM, Redis caching) → Model (data structures)

Middleware chain order: Recovery → Logger → CORS → RateLimiter → Auth (on protected routes)

### Web Frontend Architecture
- **Pages** use Nuxt file-based routing with mixed rendering: SSR+ISR for public/SEO pages (home, novel detail, categories, rankings), CSR for private pages (reader, bookshelf, profile, admin)
- **State** via Pinia stores (`auth`, `reader`, `app`)
- **Composables** for feature logic (`useAuth`, `useNovel`, `useReader`, `useBookshelf`, `useTranslation`, `useLocalDb`, `useSync`)
- **BFF layer** in `server/api/` proxies to Go backend
- **Offline:** sql.js (WebAssembly SQLite) mirrors server data for offline reading

### Flutter Architecture
- **Clean Architecture** with feature-based modules under `lib/features/`
- Each feature has `data/`, `domain/`, `presentation/` layers
- **Riverpod** for state management, **go_router** for navigation
- **sqflite** for local SQLite cache with same schema as web sql.js

### Shared Across Platforms
- OpenAPI 3.0 spec (`shared/api-spec/openapi.yaml`) is the single source of truth for API contracts
- SQLite migration SQL files (`shared/sqlite-schema/migrations/`) shared between web and Flutter
- Design tokens (`shared/design-tokens/tokens.json`) generate CSS variables and Dart constants

## API Conventions

- REST API versioned at `/api/v1/...`
- JSON responses: `{ "code": 0, "message": "success", "data": { ... } }` (code 0 = success)
- Error codes: 40001-40099 (validation), 40101-40199 (auth), 40301-40399 (authorization), 40401-40499 (not found), 40901-40999 (conflict), 42901-42999 (rate limit), 50001-50099 (server error)
- Pagination: `{ "items": [...], "pagination": { "page", "page_size", "total", "total_pages" } }`
- Auth: JWT Bearer tokens (access 24hr + refresh 30 days)
- Rate limits: 60 req/min (public), 120 req/min (authenticated), 20 req/min (translation)

## Database Conventions

- PostgreSQL: UUID primary keys, snake_case columns, `created_at`/`updated_at`/`deleted_at` timestamps
- Soft deletes via `deleted_at` with partial indexes (`WHERE deleted_at IS NULL`)
- Redis key pattern: `palimpsest:{entity}:{id}:{field}`
- Cache-Aside pattern with TTLs: novel details 10min, chapters 1hr, categories 24hr, rankings 10min, translations 7 days

## Git Conventions

- Branch strategy: GitHub Flow (main + feature branches)
- Commit format: Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`)
- Merge strategy: Squash merge
- Code review: at least 1 approval required

## Testing

| Layer | Framework | Scope |
|-------|-----------|-------|
| Backend | `go test` + testcontainers | Unit (service/repo), integration (API endpoints) |
| Web | Vitest + Vue Test Utils | Unit (composables, stores, utils), component tests |
| Web E2E | Playwright | Core user flows, visual regression |
| Flutter | `flutter_test` | Unit (providers, repos), widget tests, golden tests |
| Flutter E2E | `integration_test` | Core user flows |
| Load | k6 | API performance benchmarks |

## Project Structure (Planned)

```
backend/          # Go REST API server
  cmd/server/     # Entry point
  internal/       # config/, middleware/, handler/, service/, repository/, model/, pkg/
  migrations/     # PostgreSQL migrations
web/              # Nuxt 3 web app
  pages/          # File-based routing
  components/     # Vue components (common/, novel/, reader/, bookshelf/, translation/)
  composables/    # Vue composition functions
  stores/         # Pinia stores
  server/api/     # BFF proxy to Go backend
  types/          # TypeScript type definitions
mobile/           # Flutter app (Android, iOS, Desktop)
  lib/core/       # Config, theme, router, network, database
  lib/features/   # Feature modules (auth, bookstore, reader, bookshelf, search, translation, profile)
  lib/shared/     # Shared widgets, providers, models
shared/           # Cross-platform shared definitions
  api-spec/       # OpenAPI 3.0 spec
  sqlite-schema/  # SQLite migration SQL
  design-tokens/  # Design token JSON → CSS/Dart
```
