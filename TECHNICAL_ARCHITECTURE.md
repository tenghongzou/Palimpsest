# Palimpsest — 技術架構文件

## 1. 系統架構總覽

```
                         ┌─────────────────────┐
                         │      CDN (靜態資源)    │
                         └──────────┬──────────┘
                                    │
            ┌───────────────────────┼───────────────────────┐
            │                       │                       │
   ┌────────▼────────┐   ┌────────▼────────┐   ┌────────▼────────┐
   │   Nuxt 3 Web    │   │  Flutter Android │   │  Flutter iOS    │
   │   (SSR/SSG)     │   │      App         │   │     App         │
   │   Vue 3 + TS    │   │  Riverpod        │   │  Riverpod       │
   │   Pinia         │   │  sqflite         │   │  sqflite        │
   └────────┬────────┘   └────────┬────────┘   └────────┬────────┘
            │                      │                      │
            └──────────────────────┼──────────────────────┘
                                   │
                          ┌────────▼────────┐
                          │  Nginx / Traefik │
                          │  (Reverse Proxy) │
                          │  + Rate Limiting │
                          └────────┬────────┘
                                   │
                          ┌────────▼────────┐
                          │   Go (Gin)       │
                          │   REST API       │
                          │   Port: 8080     │
                          └────────┬────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              │                    │                    │
     ┌────────▼────────┐ ┌────────▼────────┐ ┌────────▼────────┐
     │   PostgreSQL     │ │     Redis       │ │   Meilisearch   │
     │   (主資料庫)      │ │   (緩存/排行)    │ │   (全文搜尋)     │
     │   Port: 5432    │ │   Port: 6379    │ │   Port: 7700    │
     └─────────────────┘ └─────────────────┘ └─────────────────┘
              │
     ┌────────▼────────┐
     │     MinIO        │
     │  (物件儲存)       │
     │  封面圖/靜態資源   │
     │   Port: 9000    │
     └─────────────────┘
```

## 2. 技術選型

### 2.1 後端

| 技術 | 版本 | 用途 | 選擇原因 |
|------|------|------|----------|
| **Go** | 1.22+ | 主要後端語言 | 高效能、低記憶體、原生併發 |
| **Gin** | v1.9+ | HTTP 框架 | 輕量、高效能、生態豐富 |
| **GORM** | v2 | ORM | Go 最成熟的 ORM |
| **PostgreSQL** | 16+ | 主資料庫 | 強大的 JSON、全文搜尋、擴展性 |
| **Redis** | 7+ | 緩存/Session | 高效能、Sorted Set 適合排行榜 |
| **Meilisearch** | 1.6+ | 全文搜尋 | 比 Elasticsearch 輕量、中文支援好 |
| **MinIO** | latest | 物件儲存 | S3 相容、自建部署 |
| **OpenCC** | latest | 繁簡轉換 | 高品質中文繁簡轉換 |

### 2.2 Web 前端

| 技術 | 版本 | 用途 | 選擇原因 |
|------|------|------|----------|
| **Nuxt 3** | 3.x | Web 框架 | Vue 生態系 SSR/SSG 最佳方案 |
| **Vue 3** | 3.4+ | UI 框架 | Composition API、輕量、高效能 |
| **TypeScript** | 5.x | 型別系統 | 提升開發體驗與程式碼品質 |
| **Pinia** | 2.x | 狀態管理 | Vue 官方推薦、輕量直覺 |
| **Naive UI** | 2.x | UI 元件庫 | 完整的 Vue 3 元件庫、TypeScript 原生支援 |
| **UnoCSS** | latest | CSS 引擎 | 比 Tailwind 更快、按需生成、相容 Tailwind 語法 |
| **VueUse** | latest | 工具庫 | 豐富的 Composition API 工具函式 |
| **sql.js** | latest | 瀏覽器端 SQLite | WebAssembly 版 SQLite |
| **ofetch** | latest | HTTP 客戶端 | Nuxt 官方推薦、同構 |

### 2.3 Mobile / Desktop

| 技術 | 版本 | 用途 | 選擇原因 |
|------|------|------|----------|
| **Flutter** | 3.x | 跨平台框架 | 一套程式碼覆蓋 Android/iOS/Desktop |
| **Dart** | 3.x | 程式語言 | Flutter 官方語言 |
| **Riverpod** | 2.x | 狀態管理 | 類型安全、可測試性強 |
| **sqflite** | latest | 本地 SQLite | Flutter 最成熟的 SQLite 套件 |
| **Dio** | 5.x | HTTP 客戶端 | 功能完整、支援攔截器 |
| **go_router** | latest | 路由 | 宣告式路由、Deep Link 支援 |

### 2.4 基礎設施

| 技術 | 用途 |
|------|------|
| **Docker** | 容器化 |
| **Kubernetes** | 容器編排（正式環境）|
| **Docker Compose** | 本地開發環境 |
| **GitHub Actions** | CI/CD |
| **Prometheus + Grafana** | 監控與告警 |
| **Loki** | 日誌收集 |
| **Nginx / Traefik** | 反向代理、負載均衡 |

## 3. 後端架構

### 3.1 分層架構

```
┌───────────────────────────────────────────────────┐
│                   Router Layer                     │
│           Gin Router + Middleware                   │
├───────────────────────────────────────────────────┤
│                  Handler Layer                      │
│       請求驗證、參數綁定、回應格式化                    │
├───────────────────────────────────────────────────┤
│                  Service Layer                      │
│            業務邏輯、跨 Repository 協調               │
├───────────────────────────────────────────────────┤
│                Repository Layer                     │
│           資料存取、GORM 查詢、Redis 緩存             │
├───────────────────────────────────────────────────┤
│                   Model Layer                       │
│           資料結構定義、驗證規則                       │
└───────────────────────────────────────────────────┘
```

### 3.2 專案目錄結構

```
backend/
├── cmd/
│   └── server/
│       └── main.go              # 應用程式入口
├── internal/
│   ├── config/                  # 設定管理
│   │   └── config.go
│   ├── middleware/               # 中介軟體
│   │   ├── auth.go              # JWT 認證
│   │   ├── cors.go              # CORS
│   │   ├── ratelimit.go         # 頻率限制
│   │   └── logger.go            # 請求日誌
│   ├── handler/                 # HTTP Handler
│   │   ├── auth_handler.go
│   │   ├── novel_handler.go
│   │   ├── chapter_handler.go
│   │   ├── bookshelf_handler.go
│   │   ├── search_handler.go
│   │   ├── translation_handler.go
│   │   └── admin_handler.go
│   ├── service/                 # 業務邏輯
│   │   ├── auth_service.go
│   │   ├── novel_service.go
│   │   ├── chapter_service.go
│   │   ├── bookshelf_service.go
│   │   ├── search_service.go
│   │   ├── translation_service.go
│   │   └── ranking_service.go
│   ├── repository/              # 資料存取
│   │   ├── user_repo.go
│   │   ├── novel_repo.go
│   │   ├── chapter_repo.go
│   │   ├── bookshelf_repo.go
│   │   └── cache_repo.go       # Redis 緩存操作
│   ├── model/                   # 資料模型
│   │   ├── user.go
│   │   ├── novel.go
│   │   ├── chapter.go
│   │   └── response.go         # 通用回應格式
│   └── pkg/                     # 內部共用套件
│       ├── jwt/
│       ├── validator/
│       ├── opencc/              # 繁簡轉換
│       └── translate/           # Google Translate 封裝
├── migrations/                  # 資料庫 Migration
├── scripts/                     # 工具腳本
├── Dockerfile
├── go.mod
└── go.sum
```

### 3.3 中介軟體鏈

```
Request
  │
  ▼
Recovery（異常恢復）
  │
  ▼
Logger（請求日誌）
  │
  ▼
CORS（跨域設定）
  │
  ▼
RateLimiter（頻率限制）
  │
  ▼
Auth（JWT 認證 — 需認證路由）
  │
  ▼
Handler → Service → Repository → DB
  │
  ▼
Response
```

## 4. Web 前端架構（Nuxt 3 + Vue 3）

### 4.1 專案目錄結構

```
web/
├── nuxt.config.ts               # Nuxt 設定
├── app.vue                      # 根元件
├── pages/                       # 路由頁面（自動路由）
│   ├── index.vue                # 首頁 / 書城
│   ├── login.vue                # 登入
│   ├── register.vue             # 註冊
│   ├── search.vue               # 搜尋
│   ├── ranking/
│   │   └── [type].vue           # 排行榜
│   ├── category/
│   │   └── [slug].vue           # 分類頁
│   ├── novel/
│   │   └── [id]/
│   │       ├── index.vue        # 小說詳情
│   │       └── chapters.vue     # 章節列表
│   ├── read/
│   │   └── [chapterId].vue      # 閱讀頁面
│   ├── bookshelf.vue            # 書架
│   ├── profile/
│   │   ├── index.vue            # 個人中心
│   │   └── settings.vue         # 閱讀設定
│   └── admin/                   # 管理後台
│       ├── index.vue
│       ├── novels/
│       ├── users/
│       └── reviews/
├── components/                  # 元件
│   ├── common/                  # 通用元件
│   │   ├── AppHeader.vue
│   │   ├── AppFooter.vue
│   │   ├── AppSidebar.vue
│   │   └── LoadingSpinner.vue
│   ├── novel/                   # 小說相關
│   │   ├── NovelCard.vue
│   │   ├── NovelGrid.vue
│   │   ├── NovelInfo.vue
│   │   └── ChapterList.vue
│   ├── reader/                  # 閱讀器
│   │   ├── ReaderContent.vue
│   │   ├── ReaderToolbar.vue
│   │   ├── ReaderSettings.vue
│   │   └── ReaderNavigation.vue
│   ├── bookshelf/               # 書架
│   │   ├── BookshelfGrid.vue
│   │   └── BookshelfItem.vue
│   └── translation/             # 翻譯
│       ├── TranslateButton.vue
│       └── TranslatePanel.vue
├── composables/                 # 可組合函式（Vue Composition API）
│   ├── useAuth.ts               # 認證邏輯
│   ├── useNovel.ts              # 小說資料操作
│   ├── useReader.ts             # 閱讀器狀態
│   ├── useBookshelf.ts          # 書架操作
│   ├── useTranslation.ts        # 翻譯功能
│   ├── useLocalDb.ts            # 本地 SQLite 操作
│   └── useSync.ts               # 資料同步
├── stores/                      # Pinia 狀態管理
│   ├── auth.ts                  # 認證狀態
│   ├── reader.ts                # 閱讀器設定
│   └── app.ts                   # 全域應用狀態
├── server/                      # Nuxt Server API（BFF 層）
│   ├── api/
│   │   └── [...].ts             # 代理到 Go 後端
│   └── middleware/
│       └── auth.ts
├── utils/                       # 工具函式
│   ├── api.ts                   # ofetch 封裝
│   ├── format.ts                # 格式化
│   └── storage.ts               # 本地存儲
├── assets/                      # 靜態資源
│   └── css/
│       └── main.css
├── public/                      # 公開靜態檔案
├── types/                       # TypeScript 型別定義
│   ├── novel.ts
│   ├── user.ts
│   └── api.ts
└── plugins/                     # Nuxt 插件
    ├── naive-ui.ts              # Naive UI 設定
    └── sql-js.client.ts         # sql.js 初始化（僅客戶端）
```

### 4.2 狀態管理（Pinia）

```typescript
// stores/auth.ts
export const useAuthStore = defineStore('auth', () => {
  const user = ref<User | null>(null)
  const token = ref<string | null>(null)
  const isLoggedIn = computed(() => !!token.value)

  async function login(credentials: LoginPayload) { /* ... */ }
  async function logout() { /* ... */ }
  async function refreshToken() { /* ... */ }

  return { user, token, isLoggedIn, login, logout, refreshToken }
})

// stores/reader.ts
export const useReaderStore = defineStore('reader', () => {
  const settings = ref<ReaderSettings>(defaultSettings)
  const currentChapter = ref<Chapter | null>(null)

  function updateSettings(partial: Partial<ReaderSettings>) { /* ... */ }

  return { settings, currentChapter, updateSettings }
})
```

### 4.3 Composable 範例

```typescript
// composables/useReader.ts
export function useReader(chapterId: string) {
  const chapter = ref<Chapter | null>(null)
  const loading = ref(true)
  const readerStore = useReaderStore()
  const { translateText } = useTranslation()

  async function loadChapter() { /* ... */ }
  function goNextChapter() { /* ... */ }
  function goPrevChapter() { /* ... */ }
  function saveProgress() { /* ... */ }
  function changeTheme(theme: string) { /* ... */ }

  onMounted(() => loadChapter())

  return {
    chapter, loading,
    goNextChapter, goPrevChapter,
    saveProgress, changeTheme
  }
}
```

### 4.4 渲染策略

| 頁面 | 渲染模式 | 原因 |
|------|----------|------|
| 首頁 / 書城 | SSR + ISR (10min) | SEO + 即時性 |
| 小說詳情 | SSR + ISR (5min) | SEO + 更新頻率中等 |
| 分類 / 排行榜 | SSR + ISR (10min) | SEO |
| 閱讀頁面 | CSR (SPA) | 互動性優先、不需 SEO |
| 書架 / 個人中心 | CSR (SPA) | 私人內容、不需 SEO |
| 管理後台 | CSR (SPA) | 純後台 |

```typescript
// nuxt.config.ts
export default defineNuxtConfig({
  routeRules: {
    '/': { isr: 600 },
    '/novel/**': { isr: 300 },
    '/category/**': { isr: 600 },
    '/ranking/**': { isr: 600 },
    '/read/**': { ssr: false },
    '/bookshelf': { ssr: false },
    '/profile/**': { ssr: false },
    '/admin/**': { ssr: false },
  }
})
```

## 5. Flutter 架構（Mobile / Desktop）

### 5.1 Clean Architecture + Riverpod

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── config/
│   ├── theme/
│   ├── router/                   # go_router 設定
│   ├── network/                  # Dio 封裝
│   ├── database/                 # SQLite Helper
│   └── utils/
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   ├── models/
│   │   │   └── repositories/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   ├── repositories/
│   │   │   └── usecases/
│   │   └── presentation/
│   │       ├── providers/        # Riverpod Providers
│   │       ├── pages/
│   │       └── widgets/
│   ├── bookstore/
│   ├── reader/
│   ├── bookshelf/
│   ├── search/
│   ├── translation/
│   └── profile/
└── shared/
    ├── widgets/
    ├── providers/
    └── models/
```

## 6. 認證流程

```
┌─────────┐     POST /auth/login     ┌─────────────┐
│  Client  │ ──────────────────────▶  │  Go Backend  │
│          │                          │              │
│          │  ◀──────────────────────  │  驗證密碼     │
│          │  { access_token (24hr),  │  產生 JWT     │
│          │    refresh_token (30d) } │              │
└────┬─────┘                          └──────────────┘
     │
     │  access_token 過期時
     │
     │  POST /auth/refresh
     │  { refresh_token }
     │  ──────────────────────▶  驗證 refresh_token
     │                           產生新的 token pair
     │  ◀──────────────────────
     │  { new_access_token,
     │    new_refresh_token }
```

## 7. 緩存策略

### 7.1 Cache-Aside Pattern

```
Client Request
      │
      ▼
┌──────────┐  Cache Hit   ┌───────┐
│  Handler  │ ──────────▶  │ Redis │ ──▶ Response
│           │              └───────┘
│           │  Cache Miss
│           │ ──────────▶  PostgreSQL
│           │              │
│           │  ◀──────────  Query Result
│           │
│           │  Write Cache ▶ Redis (設定 TTL)
│           │
│           │ ──▶ Response
└──────────┘
```

### 7.2 TTL 策略

| 資料類型 | TTL | 原因 |
|----------|-----|------|
| 小說詳情 | 10 分鐘 | 更新頻率低 |
| 章節內容 | 1 小時 | 內容穩定 |
| 分類列表 | 24 小時 | 幾乎不變 |
| 排行榜 | 10 分鐘 | 定期更新 |
| 搜尋熱詞 | 1 小時 | 中等頻率 |
| 翻譯結果 | 7 天 | 內容固定 |
| User Session | 24 小時 | 安全性 |

## 8. 翻譯服務架構

```
┌─────────────────────────────────────────┐
│             Translation Service          │
├─────────────────────────────────────────┤
│                                          │
│  Request ──▶ 檢查 Redis 緩存             │
│              │                           │
│              ├── Cache Hit ──▶ 回傳結果   │
│              │                           │
│              └── Cache Miss              │
│                   │                      │
│                   ├── 繁簡轉換?           │
│                   │   └── OpenCC 本地轉換  │
│                   │                      │
│                   └── 英文翻譯?           │
│                       └── Google API     │
│                           │              │
│                   結果寫入 Redis (7d TTL) │
│                   結果寫入 PostgreSQL      │
│                   回傳結果                │
│                                          │
└─────────────────────────────────────────┘
```

## 9. 安全架構

### 9.1 四層安全防護

| 層級 | 措施 |
|------|------|
| **網路層** | HTTPS (TLS 1.3)、WAF、DDoS 防護 |
| **應用層** | JWT 認證、RBAC 權限、Rate Limiting、Input Validation |
| **資料層** | 密碼 bcrypt 加密、敏感資料 AES-256、SQL Injection 防護 (ORM) |
| **基礎設施** | K8s Network Policies、Container 最小權限、Secrets 管理 |

### 9.2 API 安全措施

| 措施 | 實作方式 |
|------|----------|
| 認證 | JWT Bearer Token |
| 授權 | RBAC (Role-Based Access Control) |
| 頻率限制 | Token Bucket，每用戶 100 req/min |
| 輸入驗證 | Go Validator + 自訂規則 |
| XSS 防護 | HTML 輸出轉義 |
| CSRF 防護 | SameSite Cookie + CSRF Token |
| CORS | 白名單域名 |
| SQL Injection | GORM 參數化查詢 |

## 10. 效能優化策略

### 10.1 後端

- **資料庫**：讀寫分離、索引優化、查詢分析
- **緩存**：多層緩存（Redis + 本地記憶體）
- **連線池**：資料庫 + Redis 連線池
- **壓縮**：gzip 回應壓縮
- **分頁**：Cursor-based 分頁（大資料量）

### 10.2 Web 前端（Nuxt 3 + Vue 3）

- **SSR + ISR**：首屏快速載入、SEO 友好
- **程式碼分割**：Nuxt 自動路由級分割
- **圖片優化**：Nuxt Image 模組、WebP、lazy loading
- **Service Worker**：離線頁面快取（PWA）
- **Vue 優化**：`v-once`、`shallowRef`、虛擬列表

### 10.3 Flutter

- **Widget 優化**：`const` 建構子、`ListView.builder` 虛擬列表
- **圖片緩存**：`cached_network_image`
- **章節預載**：提前載入前後章節
- **離線緩存**：SQLite 儲存已讀章節

### 10.4 內容分發

- **CDN**：靜態資源（封面圖、CSS、JS）走 CDN
- **圖片優化**：WebP 格式、響應式尺寸
- **文字壓縮**：章節內容 gzip 壓縮傳輸

## 11. 部署架構

```
┌────────────────── Kubernetes Cluster ──────────────────┐
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │ Nuxt 3 Web   │  │ Go API       │  │ Go API       │ │
│  │ (Pod x2)     │  │ (Pod x3)     │  │ (Pod x3)     │ │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘ │
│         │                  │                  │         │
│  ┌──────▼──────────────────▼──────────────────▼──────┐ │
│  │              Ingress Controller                    │ │
│  └───────────────────────┬───────────────────────────┘ │
│                          │                              │
│  ┌─────────┐  ┌─────────┐  ┌────────────┐             │
│  │PostgreSQL│  │  Redis  │  │Meilisearch │             │
│  │(StatefulSet)│(StatefulSet)│(Deployment)│             │
│  └─────────┘  └─────────┘  └────────────┘             │
│                                                         │
│  ┌─────────┐  ┌────────────────┐                       │
│  │  MinIO  │  │ Prometheus +   │                       │
│  │         │  │ Grafana + Loki │                       │
│  └─────────┘  └────────────────┘                       │
└─────────────────────────────────────────────────────────┘
```
