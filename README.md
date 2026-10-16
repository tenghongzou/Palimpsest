# Palimpsest

> 跨平台中文小說閱讀應用程式：Web、Android、iOS、Desktop 一套後端通吃，支援繁體中文 / 簡體中文 / 英文閱讀、即時翻譯與離線閱讀。

Palimpsest 的定位類似「起點中文網」。讀者可以逛書城、搜尋、排行榜，在自訂的閱讀器裡看書，並在多個裝置之間同步書架與閱讀進度。系統以 OpenCC 做繁簡轉換、以 Google Translate 做英文翻譯，並把章節快取在本地 SQLite，沒有網路也能繼續閱讀。

> [!NOTE]
> 本專案目前處於 **MVP 開發階段（v0.1.0）**。Phase 1 的功能已在後端、Web 與 Flutter 實作完成，尚未完成的是正式環境部署與少數 App 端設定，詳見[開發進度](#開發進度)。

---

## 目錄

- [功能特色](#功能特色)
- [技術棧](#技術棧)
- [系統架構](#系統架構)
- [專案結構](#專案結構)
- [快速開始](#快速開始)
- [環境變數](#環境變數)
- [API 概覽](#api-概覽)
- [測試與 CI](#測試與-ci)
- [部署](#部署)
- [開發進度](#開發進度)
- [設計文件](#設計文件)
- [開發規範](#開發規範)

---

## 功能特色

| 模組 | 說明 |
|------|------|
| 👤 **會員系統** | Email 註冊 / 登入、JWT 驗證（Access 24 小時 + Refresh 30 天）、忘記密碼 |
| 📚 **書城** | 小說列表、分類瀏覽、小說詳情、章節目錄、排行榜（Redis Sorted Set） |
| 🔍 **搜尋** | 以 Meilisearch 做全文搜尋，含搜尋建議與熱門關鍵字 |
| 📖 **閱讀器** | 捲動 / 翻頁模式，可調整字級（12–36）、行距（1.2–3.0），內建白、米黃、護眼綠、深色、純黑五種主題 |
| 🗂️ **書架** | 收藏小說、跨裝置同步閱讀進度 |
| 🌐 **翻譯** | 繁 ⇄ 簡轉換（OpenCC）、中文 → 英文翻譯（Google Translate），結果快取 7 天 |
| 📴 **離線閱讀** | Web 使用 sql.js（WebAssembly SQLite），App 使用 sqflite，兩端共用同一套 Schema |
| 🛠️ **管理後台** | 小說與章節 CRUD、批次匯入章節、用戶管理、書評審核、檢舉處理、統計總覽 |

---

## 技術棧

| 層級 | 技術 |
|------|------|
| **後端** | Go 1.27+、[Gin](https://github.com/gin-gonic/gin)、GORM v2、golang-jwt v5、bcrypt |
| **資料庫 / 中介服務** | PostgreSQL 16、Redis 7、Meilisearch 1.6、MinIO（S3 相容） |
| **Web 前端** | Nuxt 3、Vue 3、TypeScript 5、Pinia、Naive UI、UnoCSS、VueUse、sql.js |
| **Mobile / Desktop** | Flutter 3、Dart 3、Riverpod 2、go_router、Dio 5、sqflite |
| **測試** | `go test`、Vitest + Vue Test Utils、Playwright、`flutter_test` |
| **基礎設施** | Docker Compose（開發）、Kubernetes（正式環境規劃）、GitHub Actions |

---

## 系統架構

```mermaid
flowchart TD
    subgraph Clients["用戶端"]
        Web["Nuxt 3 Web<br/>SSR/ISR + CSR<br/>sql.js 離線快取"]
        App["Flutter App<br/>Android / iOS / Desktop<br/>sqflite 離線快取"]
    end

    Web -->|"BFF 代理 /api/**"| Proxy
    App --> Proxy
    Proxy["Nginx / Traefik<br/>反向代理、限流"] --> API

    subgraph Backend["Go Gin REST API :8080"]
        API["Router → Handler → Service → Repository → Model"]
    end

    API --> PG[("PostgreSQL<br/>主要資料")]
    API --> RD[("Redis<br/>快取 / 排行榜 / 限流")]
    API --> MS[("Meilisearch<br/>全文搜尋")]
    API --> MI[("MinIO<br/>封面等物件")]
```

### 後端分層

```
Router (Gin + middleware)
  → Handler     請求驗證、回應格式化
  → Service     商業邏輯
  → Repository  資料存取（GORM）、Redis 快取
  → Model       資料結構
```

Middleware 順序：`Recovery → Logger → CORS → Auth（受保護路由）→ AdminOnly（管理路由）`。翻譯路由另外套用以 Redis 為基礎的限流（每分鐘 20 次）。

### Web 渲染策略

| 路由 | 渲染方式 | 原因 |
|------|----------|------|
| `/`、`/category/**`、`/ranking/**` | SSR + ISR（600 秒） | SEO、公開頁面 |
| `/novel/**` | SSR + ISR（300 秒） | SEO、內容更新較頻繁 |
| `/read/**`、`/bookshelf`、`/profile/**`、`/admin/**` | CSR | 私人或高度互動頁面 |

Nuxt 的 `server/api/[...].ts` 是 BFF 層，把 `/api/**` 轉發到 Go 後端。

### 快取策略（Cache-Aside）

Redis Key 格式為 `palimpsest:{entity}:{id}:{field}`。

| 資料 | TTL |
|------|-----|
| 小說詳情 / 排行榜 | 10 分鐘 |
| 章節內容 | 1 小時 |
| 分類 | 24 小時 |
| 翻譯結果 | 7 天 |

---

## 專案結構

```
Palimpsest/
├── backend/                    # Go REST API
│   ├── cmd/server/             # 進入點（main.go、router.go）
│   ├── internal/
│   │   ├── config/             # 環境變數設定
│   │   ├── middleware/         # auth、cors、logger、ratelimit
│   │   ├── handler/            # auth、novel、bookshelf、search、translation、admin
│   │   ├── service/            # 商業邏輯（含 ranking、translation）
│   │   ├── repository/         # user、novel、bookshelf、cache
│   │   ├── model/              # GORM 模型與統一回應格式
│   │   └── pkg/jwt/            # JWT 簽發與驗證
│   ├── migrations/             # PostgreSQL migration SQL
│   └── Dockerfile
├── web/                        # Nuxt 3 Web App
│   ├── pages/                  # 檔案式路由（首頁、小說、分類、排行、閱讀、書架、搜尋、個人、後台）
│   ├── components/             # common/、novel/、reader/
│   ├── composables/            # useAuth、useNovel、useReader、useBookshelf、useTranslation、useLocalDb、useSync
│   ├── stores/                 # Pinia：auth、reader、app
│   ├── layouts/                # default、reader、auth、admin
│   ├── middleware/             # auth、admin 路由守衛
│   ├── plugins/                # naive-ui、sql.js（client-only）
│   ├── server/api/             # BFF 代理
│   ├── tests/unit/             # Vitest 單元測試
│   └── Dockerfile
├── mobile/                     # Flutter App（Clean Architecture）
│   ├── lib/core/               # config、database、network、router、theme
│   ├── lib/features/           # auth、bookstore、reader、bookshelf、search、profile
│   │   └── <feature>/          # data/ → domain/ → presentation/
│   └── test/
├── shared/                     # 跨平台共用定義
│   ├── api-spec/openapi.yaml   # OpenAPI 3.0 規格（API 契約的唯一來源）
│   ├── sqlite-schema/          # Web 與 Flutter 共用的本地 SQLite Schema
│   └── design-tokens/          # 設計 Token（色彩、字型、間距、斷點）
├── docs/                       # 規劃與設計文件
├── .github/workflows/          # backend / web / flutter CI
└── docker-compose.yml          # 本地開發用基礎服務
```

---

## 快速開始

### 前置需求

| 工具 | 版本 |
|------|------|
| Docker / Docker Compose | 最新穩定版 |
| Go | 1.27.1+（見 `backend/go.mod`） |
| Node.js | 22+（pnpm 12 的最低需求） |
| pnpm | 12.4.1（見 `web/package.json` 的 `packageManager`，可用 `corepack enable` 自動切換；若 corepack 回報找不到 `bin/pnpm.cjs`，改用 `npx pnpm@12.4.1`） |
| Flutter | 3.x（CI 使用 3.47.2） |

### 1. 啟動基礎服務

```bash
docker-compose up -d
```

主機上的埠已被其他服務占用時，可用環境變數改對外埠（容器內不變），後端再以對應的 `DB_PORT`、`REDIS_PORT` 等連線：

```bash
POSTGRES_PORT=55432 docker compose up -d   # 另有 REDIS_PORT、MEILI_PORT、MINIO_PORT、MINIO_CONSOLE_PORT
cd backend && DB_PORT=55432 go run ./cmd/server
```

| 服務 | 位址 | 預設帳密 |
|------|------|----------|
| PostgreSQL | `localhost:5432` | `palimpsest` / `palimpsest`，DB：`palimpsest` |
| Redis | `localhost:6379` | 無密碼 |
| Meilisearch | http://localhost:7700 | 開發模式，無 API Key |
| 物件儲存（S3 相容） | http://localhost:9000 | `minioadmin` / `minioadmin` |

> [!NOTE]
> MinIO 已不再發布容器映像檔，`docker-compose.yml` 的 `minio` 服務改用 API 相容的 [RustFS](https://github.com/rustfs/rustfs)（固定在 `rustfs/rustfs:1.0.0`）。後端仍透過 MinIO 用戶端存取，啟動時會自動建立 Bucket，並讓 `public/` 底下的頭像與封面可匿名讀取。

### 2. 啟動後端

```bash
cd backend
go run ./cmd/server
```

預設的環境變數值已經對應 `docker-compose.yml`，本地開發不需額外設定即可啟動。伺服器啟動時會用 GORM `AutoMigrate` 建立資料表（清單見 `internal/model/models.go`），並在背景重建 Meilisearch 索引。可用 `curl http://localhost:8080/health` 做健康檢查。

要填入示範資料（分類、管理員帳號、三本範例小說），執行種子指令。重複執行不會產生重複資料：

```bash
cd backend
SEED_ADMIN_PASSWORD=<至少 8 碼> go run ./cmd/seed   # 管理員帳號預設為 admin
```

搜尋索引在伺服器啟動時重建，所以第一次填入種子資料後要重新啟動 API 伺服器，範例小說才搜尋得到。

> [!TIP]
> `backend/migrations/` 是早期規劃的完整 PostgreSQL Schema，目前程式不會套用。實際使用的資料表以 Go Model 為準；`translation_cache`、`search_keywords`、`admin_logs` 等尚未使用的表不會被建立。

Redis 或物件儲存連線失敗時，伺服器只會印出警告並繼續執行（此時沒有快取，上傳頭像與封面會回傳 503）；PostgreSQL 連線失敗則會直接結束。

### 3. 啟動 Web 前端

```bash
cd web
pnpm install
pnpm dev          # http://localhost:3000
```

### 4. 啟動 Flutter App

`mobile/` 已包含 Android、iOS 與桌面版（Windows、macOS、Linux）原生專案（以 Flutter 3.47.2 產生，與 CI 相同版本；套件名稱 `cc.palimpsest.palimpsest`）。請使用 Flutter 3.47.x：

```bash
cd mobile
flutter pub get
flutter run
```

App 在 Android 上預設連到 `http://10.0.2.2:8080/api/v1`（Android 模擬器對應的主機位址），桌面版與 iOS 模擬器預設連到 `http://localhost:8080/api/v1`。其他環境請用 `--dart-define` 覆寫：

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:8080/api/v1
```

建置 Android 安裝檔：

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://api.palimpsest.cc/api/v1
```

正式簽章使用 `mobile/android/key.properties`（已列入 `.gitignore`，不要提交），格式如下；沒有這個檔案時，release 版會改用 debug 金鑰簽章，只適合本機測試：

```properties
storeFile=/path/to/upload-keystore.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

> [!NOTE]
> `android/gradle.properties` 關閉了 Kotlin 增量編譯：專案與 pub 快取位於不同磁碟時（Windows 常見），增量快取會讓建置失敗。

#### 桌面版（Windows / macOS / Linux）

```bash
cd mobile
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:8080/api/v1   # 或 -d macos、-d linux
flutter build windows --release --dart-define=API_BASE_URL=https://api.palimpsest.cc/api/v1
flutter build macos --release --dart-define=API_BASE_URL=https://api.palimpsest.cc/api/v1
flutter build linux --release --dart-define=API_BASE_URL=https://api.palimpsest.cc/api/v1
```

| 平台 | 建置需求 | 輸出 |
|------|----------|------|
| Windows | Visual Studio 2022（「使用 C++ 的桌面開發」工作負載） | `build/windows/x64/runner/Release/`（整個資料夾一起發佈） |
| macOS | Xcode（只能在 macOS 上建置） | `build/macos/Build/Products/Release/Palimpsest.app` |
| Linux | `clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev` | `build/linux/x64/release/bundle/` |

- **本地資料庫**：sqflite 沒有 Windows／Linux 實作，這兩個平台改用 `sqflite_common_ffi`（啟動時設定 `databaseFactory`），SQLite 本身由 `package:sqlite3` 的 build hook 自動下載並打包（Windows 為 `sqlite3.dll`），不需要另外安裝。資料庫位於使用者的 Application Support 資料夾（Windows：`%APPDATA%\cc.palimpsest\palimpsest\palimpsest.db`）。Android、iOS、macOS 仍使用原本的 sqflite。
- **版面**：視窗寬度 ≥ 840 時，首頁／書架／我的改用左側 NavigationRail（≥ 1200 時展開並顯示文字）；詳情、個人、設定與登入表單限制最大寬度並置中，閱讀器內文欄寬最多 800（捲動與翻頁模式皆同）。
- **頭像上傳**：桌面版以檔案對話框選擇圖片；超過 2 MB 的圖片會先在本機縮小到 512 px 再上傳。
- **視窗**：標題「Palimpsest」，預設 1280×800，最小 800×600。圖示由 `assets/icon/app_icon.png` 產生：`python tool/gen_desktop_icons.py`（需要 Pillow）。

#### 鍵盤快捷鍵

所有平台只要有實體鍵盤即可使用；焦點在文字輸入框時不會觸發（Esc 只會離開輸入框）。

| 範圍 | 按鍵 | 動作 |
|------|------|------|
| 全域 | `Ctrl+F`（macOS 為 `Cmd+F`）、`/` | 開啟搜尋 |
| 全域 | `Esc` | 關閉對話框／底部面板；否則返回上一頁 |
| 全域 | `Alt+←` | 返回上一頁 |
| 閱讀器 | `←` `→`、`PageUp` `PageDown` | 上一頁／下一頁（翻頁模式）；捲動一個畫面（捲動模式） |
| 閱讀器 | `Space`／`Shift+Space` | 下一頁／上一頁（或捲動一個畫面） |
| 閱讀器 | `↑` `↓` | 捲動一小段（翻頁模式為翻頁） |
| 閱讀器 | `[` `]`、`Ctrl+←` `Ctrl+→` | 上一章／下一章 |
| 閱讀器 | `Esc` | 關閉工具列與設定面板；沒有開啟時離開閱讀器 |
| 閱讀器 | 滑鼠滾輪 | 翻頁模式下每一格翻一頁 |

### 從 OpenAPI 產生型別

```bash
pnpm --dir web generate:api-types      # 產生 web/types/api.d.ts
cd mobile && dart run build_runner build   # 產生 json_serializable 模型
```

---

## 環境變數

### 後端（`backend/internal/config/config.go`）

| 變數 | 預設值 | 說明 |
|------|--------|------|
| `SERVER_PORT` | `8080` | HTTP 監聽埠 |
| `GIN_MODE` | `debug` | `debug` / `release` / `test` |
| `METRICS_PORT` | （空） | 在另一個埠提供 Prometheus 指標（`/metrics`）；未設定時不啟用 |
| `TRUSTED_PROXIES` | 私有網段（`127.0.0.0/8`、`10.0.0.0/8`、`172.16.0.0/12`、`192.168.0.0/16`、`::1`） | 只信任這些代理送來的 `X-Forwarded-For`，用來判斷限流的用戶端 IP |
| `DB_HOST` / `DB_PORT` | `localhost` / `5432` | PostgreSQL 位址 |
| `DB_USER` / `DB_PASSWORD` | `palimpsest` / `palimpsest` | PostgreSQL 帳密 |
| `DB_NAME` / `DB_SSLMODE` | `palimpsest` / `disable` | 資料庫名稱與 SSL 模式 |
| `REDIS_HOST` / `REDIS_PORT` | `localhost` / `6379` | Redis 位址 |
| `REDIS_PASSWORD` | （空） | Redis 密碼 |
| `JWT_SECRET` | `change-me-in-production` | JWT 簽章金鑰。`release` 模式下若仍是預設值或少於 32 字元，伺服器會拒絕啟動 |
| `MINIO_ENDPOINT` | `localhost:9000` | 物件儲存（S3 相容）位址 |
| `MINIO_ACCESS_KEY` / `MINIO_SECRET_KEY` | `minioadmin` / `minioadmin` | 物件儲存金鑰 |
| `MINIO_BUCKET` | `palimpsest` | Bucket 名稱 |
| `MINIO_USE_SSL` | `false` | 是否以 HTTPS 連線物件儲存 |
| `MINIO_PUBLIC_URL` | `http://localhost:9000/palimpsest` | 瀏覽器讀取上傳檔案的網址前綴（正式環境通常是 CDN） |
| `MEILI_HOST` | `http://localhost:7700` | Meilisearch 位址 |
| `MEILI_API_KEY` | （空） | Meilisearch API Key |
| `CORS_ALLOWED_ORIGINS` | `*` | 允許的來源，以逗號分隔，例如 `https://a.com,https://b.com` |
| `GOOGLE_TRANSLATE_API_KEY` | （空） | Google Cloud Translation v2 API Key。未設定時只提供繁簡轉換，英文翻譯回傳 503 |
| `GOOGLE_TRANSLATE_ENDPOINT` | （空） | 覆寫翻譯 API 位址（測試或代理用） |
| `SMTP_HOST` / `SMTP_PORT` | （空）/ `587` | 寄送重設密碼信的 SMTP 伺服器。未設定時不寄信，`debug` 模式下會把重設連結印在日誌中 |
| `SMTP_USERNAME` / `SMTP_PASSWORD` | （空） | SMTP 帳密 |
| `SMTP_FROM` | `Palimpsest <no-reply@palimpsest.local>` | 寄件者 |
| `WEB_BASE_URL` | `http://localhost:3000` | Web 前端的公開網址，用於信中的重設密碼連結 |
| `RATE_LIMIT_ENABLED` | `true` | 設為 `false` 時關閉所有限流（只用於壓力測試） |
| `ANTHROPIC_API_KEY` | （空） | 書評與留言的 AI 輔助審核（Anthropic Messages API）。未設定時只執行規則審核 |
| `MODERATION_AI_ENABLED` | 有 Key 時為 `true` | 設為 `false` 可在有 Key 時關閉 AI 審核 |
| `MODERATION_AI_MODEL` | `claude-haiku-5-5` | AI 審核使用的模型 |
| `ANTHROPIC_BASE_URL` | `https://api.anthropic.com` | 覆寫 Anthropic API 位址（測試或代理用） |

#### 內容審核

新增或修改的書評、新留言會先經過規則檢查，結果（`score` 0–1 與 `flags`）存在 `moderation` 欄位，只有管理員看得到：

- **詞庫**（`/admin/moderation/terms`，預設為空）：比對時忽略大小寫、全形／半形、繁簡差異與夾雜的空白標點；純英文詞只比對完整單字。`block` 級的詞直接把內容轉為 `pending`（待審），`flag` 級只標記。
- **其他規則**：連結、聯絡方式（Email、電話、「加賴」、LINE ID、微信、vx、QQ 等）、大量重複字詞、全大寫英文。各規則的風險合併成分數，分數 ≥ 0.8 時同樣轉為 `pending`。
- `pending` 的內容不公開、不計入評分與留言數，只有作者本人看得到（狀態顯示為 `pending`），作者可以刪除；待審留言不能被回覆，被擱置的回覆在核准後才通知對方。
- **AI 審核**（選用）：設定 `ANTHROPIC_API_KEY` 後，內容建立後在背景送交 AI 判斷（最多 4 個同時進行、每次 20 秒逾時），不影響回應速度；結果併入 `moderation`（`ai_*` 標記），AI 分數 ≥ 0.85 時把已公開的內容撤回 `pending`。AI 失敗只記錄日誌。
- 管理員在 `/admin/moderation/queue` 處理：`pending` 依時間先後列出待審內容；`flagged` 依分數列出已公開但有標記的內容。任何處理（核准、退回、隱藏）都會記錄 `moderation.reviewed_at`，項目即離開 `flagged` 佇列。

### Web（`web/nuxt.config.ts`）

| 變數 | 預設值 | 說明 |
|------|--------|------|
| `API_BASE_URL` | `http://localhost:8080` | BFF 在伺服器端轉發的 Go 後端位址（建置時讀取） |
| `NUXT_API_BASE_URL` | （同上） | 在執行期覆寫 BFF 的後端位址；以 Docker 映像檔或 Kubernetes 部署時用這個 |
| `NUXT_PUBLIC_API_BASE_URL` | `/api` | 瀏覽器端呼叫的 API 前綴 |

### Flutter（`--dart-define`）

| 變數 | 預設值 |
|------|--------|
| `API_BASE_URL` | Android：`http://10.0.2.2:8080/api/v1`；其他平台：`http://localhost:8080/api/v1` |

---

## API 概覽

所有 API 都以 `/api/v1` 為前綴，完整規格見 [`shared/api-spec/openapi.yaml`](shared/api-spec/openapi.yaml) 與 [`docs/API_DESIGN.md`](docs/API_DESIGN.md)。

### 回應格式

```jsonc
// 成功
{ "code": 0, "message": "success", "data": { /* ... */ } }

// 分頁
{
  "code": 0,
  "message": "success",
  "data": {
    "items": [ /* ... */ ],
    "pagination": { "page": 1, "page_size": 20, "total": 128, "total_pages": 7 }
  }
}
```

### 錯誤碼

| 範圍 | 類別 |
|------|------|
| `40001–40099` | 參數驗證錯誤 |
| `40101–40199` | 驗證失敗（未登入、Token 失效） |
| `40301–40399` | 權限不足 |
| `40401–40499` | 資源不存在 |
| `40901–40999` | 資源衝突 |
| `42901–42999` | 請求過於頻繁 |
| `50001–50099` | 伺服器錯誤 |

### 端點一覽

| 權限 | 方法與路徑 | 說明 |
|------|-----------|------|
| 公開 · 限流 | `POST /auth/register`、`/auth/login`、`/auth/forgot-password`、`/auth/reset-password` | 註冊、登入、忘記密碼、重設密碼（各自每 IP 每分鐘 5 次） |
| 公開 | `POST /auth/refresh`、`/auth/logout` | 刷新 Token、登出 |
| 公開 | `GET /home`、`/banners` | 書城首頁區塊、輪播 |
| 公開 | `GET /novels`、`/novels/:id` | 小說列表（可依分類 `category` slug、狀態、語言篩選與排序）、詳情 |
| 公開 | `GET /novels/:id/chapters`、`/chapters/:chapterId` | 章節目錄、章節內容（含上一章／下一章） |
| 公開 | `GET /categories` | 分類列表 |
| 公開 | `GET /rankings/:type?period=weekly` | 排行榜（點閱榜依日／週／月統計） |
| 公開 | `GET /search/novels`、`/search/suggestions`、`/search/hot-keywords` | 搜尋 |
| 公開（登入可選） | `GET /novels/:id/reviews`、`/chapters/:chapterId/comments` | 書評、章節留言（登入時標示自己按過讚的項目） |
| 登入 | `GET` / `PATCH /users/me`、`POST /users/me/avatar`、`PUT /users/me/password` | 個人資料、頭像、修改密碼 |
| 登入 | `GET /users/me/reading-stats`、`GET` / `PUT /users/me/reading-settings` | 閱讀統計、閱讀設定同步 |
| 登入 | `/bookshelf`（含 `PATCH` 分組、`POST /bookshelf/batch-remove`） | 書架 |
| 登入 | `/reading-progress`、`/reading-progress/batch`、`GET /reading-history` | 閱讀進度、閱讀紀錄 |
| 登入 | `/bookmarks`、`POST /bookmarks/sync` | 書籤、離線書籤同步 |
| 登入 | `POST /novels/:id/reviews`、`/reviews/:id`、`/chapters/:chapterId/comments`、`/comments/:id`、`.../like`、`POST /reports` | 撰寫書評與留言、按讚、檢舉 |
| 登入 · 限流 | `POST /translation/convert`、`/translation/chapter`、`/translation/text` | 繁簡轉換、翻譯 |
| 管理員 | `/admin/novels`、`/admin/chapters`、`/admin/novels/:id/chapters/batch`、`POST /admin/uploads` | 小說、章節、封面上傳 |
| 管理員 | `/admin/categories`、`/admin/banners` | 分類、輪播 |
| 管理員 | `/admin/users`、`/admin/reviews`、`/admin/reports`、`/admin/stats` | 用戶、審核、檢舉、統計 |
| 管理員 | `GET /admin/stats/trends`、`/admin/stats/top-novels`、`/admin/stats/categories` | 每日趨勢、熱門小說、分類閱讀統計（依 `utc_offset` 的當地日期） |
| 管理員 | `GET /admin/moderation/queue`、`PUT /admin/moderation/:type/:id`、`/admin/moderation/terms` | 內容審核佇列、審核決定、審核詞庫 |

受保護的端點需帶上 `Authorization: Bearer <access_token>`。完整規格見 [`shared/api-spec/openapi.yaml`](shared/api-spec/openapi.yaml)，`go test ./cmd/server` 會檢查規格與 Router 是否一致。

---

## 測試與 CI

### 在本地執行測試

```bash
# 後端：單元測試；設定 TEST_DATABASE_URL 時也會跑 PostgreSQL 整合測試
# （每個測試使用獨立的 schema，結束後刪除）
cd backend
go test ./...
TEST_DATABASE_URL='postgres://palimpsest:palimpsest@localhost:5432/palimpsest_test?sslmode=disable' go test ./...

# Web
cd web
pnpm test:run      # 單次執行 Vitest
pnpm test          # 監看模式
pnpm test:e2e      # Playwright E2E（預設會建置並以 pnpm preview 啟動 http://localhost:3000）
pnpm typecheck     # vue-tsc 型別檢查（含 .vue 檔）

# 對已在執行的站台跑 E2E（需要後端與種子資料；管理員帳密以 E2E_ADMIN_LOGIN / E2E_ADMIN_PASSWORD 指定）
PLAYWRIGHT_BASE_URL=http://localhost:3000 pnpm test:e2e
pnpm lint          # ESLint

# Flutter
cd mobile
flutter test
dart analyze
dart run tool/sync_sqlite_schema.dart   # 共用 SQLite Schema 變更後重新產生 Dart 檔
flutter test integration_test           # 需要連接裝置或模擬器
```

### 測試範圍

| 層級 | 框架 | 目前涵蓋 |
|------|------|----------|
| 後端 | `go test` | config、handler、middleware、model、jwt、mail、translate、service；PostgreSQL 整合測試涵蓋書架、進度、書籤、社群、使用者設定、後台、密碼重設、首頁 |
| Web | Vitest + Vue Test Utils | composables、stores、utils（API、本機 DB 與 sql.js 兩種建置、Schema 漂移、章節批次匯入解析等） |
| Web E2E | Playwright | 註冊登入、忘記密碼、瀏覽與閱讀、書籤（含離線）、留言、翻譯、閱讀設定、書架、書評與檢舉、個人設定、管理後台 |
| Flutter | `flutter_test` | 資料庫 migration 與 Schema 漂移、同步、repositories、離線下載、閱讀設定、各頁面 widget 測試，以及以假後端跑完整閱讀流程 |

### GitHub Actions

各 Workflow 依路徑觸發（push 到 `main` 或對 `main` 發 PR 時）：

| Workflow | 觸發路徑 | 內容 |
|----------|----------|------|
| [`backend.yml`](.github/workflows/backend.yml) | `backend/**` | `go build`、`go vet`，並以 PostgreSQL 服務容器執行 `go test ./...`（含整合測試） |
| [`web.yml`](.github/workflows/web.yml) | `web/**`、`shared/**` | Node + pnpm：Vitest、`pnpm typecheck`（vue-tsc）、正式建置 |
| [`flutter.yml`](.github/workflows/flutter.yml) | `mobile/**`、`shared/**` | Flutter 3.47.2：`flutter analyze`、檢查 SQLite Schema 產生檔、`flutter test`，並建置 release APK、Windows 與 Linux 版上傳為 artifact |
| [`docker.yml`](.github/workflows/docker.yml) | `backend/**`、`web/**` | 建置後端與 Web 映像檔；PR 只建置，`main` 與 `v*` 標籤會推送到 GHCR |

---

## 部署

`backend/` 與 `web/` 各有 Dockerfile，兩者都以非 root 使用者執行；後端映像檔另含 `./seed` 指令。推送到 `main` 或建立 `v*` 標籤時，[`docker.yml`](.github/workflows/docker.yml) 會建置並發布到 GHCR（`ghcr.io/tenghongzou/palimpsest-backend`、`palimpsest-web`），標籤為 `main`、commit SHA，以及版本號（例如 `v0.1.0` 標籤會產生 `0.1.0`）。

```bash
docker build -t palimpsest-backend backend
docker build -t palimpsest-web web
```

Kubernetes 設定以 Kustomize 撰寫，位於 [`deploy/k8s/`](deploy/k8s)：

| 路徑 | 內容 |
|------|------|
| `base/` | Namespace、後端與 Web 的 Deployment / Service / HPA / PDB、ConfigMap、Ingress（`palimpsest.cc` 與行動端用的 `api.palimpsest.cc`，憑證由 cert-manager 簽發） |
| `components/in-cluster-deps/` | 叢集內的 PostgreSQL、Redis、Meilisearch、RustFS（單一副本，供 staging 使用），以及每晚 03:00（台北時間）以 `pg_dump` 備份資料庫、保留 7 天的 CronJob |
| `components/monitoring/` | 給使用 Prometheus Operator 的叢集：ServiceMonitor 與告警規則（服務中斷、5xx 比例、p95 延遲、資料庫連線池飽和、大量限流） |
| `overlays/staging/` | base + 叢集內依賴，各服務一個副本，另開放圖片網域 |
| `overlays/production/` | base 搭配外部的託管服務；套用前請改成實際的服務位址並固定映像檔版本 |

```bash
# 1. 依 deploy/k8s/secret.example.yaml 建立 palimpsest-secrets（不要提交真實的值）
kubectl create namespace palimpsest
kubectl -n palimpsest apply -f my-secret.yaml

# 2. 部署
kubectl apply -k deploy/k8s/overlays/staging

# 3. （選用）匯入範例資料
kubectl -n palimpsest exec deploy/backend -- env SEED_ADMIN_PASSWORD=... ./seed
```

### 監控

後端在 `METRICS_PORT`（Kubernetes 設定中為 9090）提供 Prometheus 指標，這個埠不會經過 Ingress 對外開放：

| 指標 | 說明 |
|------|------|
| `palimpsest_http_requests_total{method,route,status}` | 請求數；`route` 是路由樣板（例如 `/api/v1/novels/:id`），避免標籤數量無限增長 |
| `palimpsest_http_request_duration_seconds{method,route}` | 請求延遲分布 |
| `go_sql_*{db_name="palimpsest"}` | 資料庫連線池（使用中、閒置、等待次數等） |
| `go_*`、`process_*` | Go runtime 與行程資源 |

Pod 帶有 `prometheus.io/scrape` 註解，以註解自動探索的 Prometheus 可直接抓取；使用 Prometheus Operator 時，在 overlay 加入 `components/monitoring`。

---

## 開發進度

目前處於 Roadmap 的 **Phase 1（MVP）**。

| 項目 | 狀態 | 備註 |
|------|:----:|------|
| 後端分層架構、設定、優雅關機 | ✅ | |
| 會員註冊 / 登入 / JWT / 忘記密碼 | ✅ | 重設密碼信透過 SMTP 寄出，連結只能用一次；改密碼會撤銷舊的 Refresh Token；封禁立即生效 |
| 個人資料、頭像、閱讀設定同步、閱讀統計 | ✅ | 頭像存放於 S3 相容物件儲存 |
| 小說、章節、分類 API（含 Redis 快取） | ✅ | 章節數、字數、最新章節自動維護；後台編輯會立即清除快取 |
| 書架、閱讀進度、閱讀紀錄、書籤 API | ✅ | 進度以最後閱讀者為準；書籤支援離線批次同步 |
| 書城首頁與輪播 | ✅ | |
| 排行榜 | ✅ | 點閱榜依日 / 週 / 月統計（Redis 每日計數），其他榜單由資料庫排序 |
| Meilisearch 搜尋與索引 | ✅ | 啟動時重建索引，後台新增 / 修改 / 發布 / 刪除時同步；熱門關鍵字以 Redis Sorted Set 統計 |
| 社群功能（書評、留言、按讚、檢舉） | ✅ | 書評會更新小說評分；檢舉可在後台處理並隱藏內容 |
| 管理後台 API | ✅ | 小說、章節（含批次匯入）、分類、輪播、上傳、用戶、書評審核、檢舉、統計 |
| 翻譯 API | ✅ | 繁簡轉換用 OpenCC（台灣用語）；英文用 Google Cloud Translation v2，未設定 API Key 時回傳 503 |
| API 限流 | ✅ | 公開 60 / 登入 120 / 管理員 300 次/分；搜尋 30 次/分；翻譯共用 20 次/分；登入、註冊、密碼重設各 5 次/分 |
| OpenAPI 規格 | ✅ | 涵蓋所有路由，`go test` 會檢查規格與 Router 是否一致 |
| 種子資料 | ✅ | `go run ./cmd/seed`：分類、管理員、三本範例小說 |
| Web 讀者端 | ✅ | 首頁、分類、排行、搜尋、小說頁（書評）、閱讀器（書籤、留言、翻譯、翻頁模式）、書架（分組）、個人中心、設定、閱讀紀錄 |
| Web 管理後台 | ✅ | 儀表板、小說與章節、分類、輪播、用戶、書評審核、檢舉處理 |
| Web Token 自動刷新、離線快取（sql.js） | ✅ | 章節、進度與書籤可離線使用，恢復連線後同步 |
| Flutter 書城、閱讀器、書架、搜尋、個人頁 | ✅ | 閱讀器含上下章、目錄、書籤、翻譯、留言；新增排行、分類、閱讀紀錄、設定頁 |
| Flutter 離線閱讀 | ✅ | 章節快取、整本下載與下載管理、離線進度與書籤同步；本機 Schema 由共用 SQL 產生 |
| Flutter 頭像上傳、翻頁模式、螢幕常亮 | ✅ | 翻頁模式點擊左右翻頁，翻到章節首尾可自動換章 |
| Flutter 原生平台專案目錄 | ✅ | Android、iOS、Windows、macOS、Linux |
| Flutter 桌面版 | ✅ | 寬視窗側邊欄（NavigationRail）＋主內容、限制閱讀寬度、全面鍵盤快捷鍵與滑鼠滾輪翻頁；Windows／Linux 以 FFI 使用 SQLite |
| Docker 映像檔、Kubernetes 部署設定 | ✅ | Kustomize：staging（含叢集內依賴）與 production overlay |
| 監控與告警 | ✅ | Prometheus 指標（獨立埠）、ServiceMonitor 與告警規則 |
| 資料庫備份 | ✅ | staging 叢集內 PostgreSQL 每晚備份、保留 7 天；正式環境依託管服務的備份機制 |
| 映像檔發布 | ✅ | GitHub Actions 建置並推送到 GHCR |
| CDN | 📋 | 依部署平台設定；圖片網址由 `MINIO_PUBLIC_URL` 指定，可直接指向 CDN |
| App 與網站圖示 | ✅ | Android adaptive／themed、iOS AppIcon、favicon 與 PWA 尺寸圖示 |

**Phase 2 進度**

| 項目 | 狀態 | 備註 |
|------|------|------|
| 站內通知 | ✅ | 書架更新（可逐本關閉）、留言回覆、系統公告；Web 與 Flutter 皆有通知中心與未讀數 |
| 段落評論 | ✅ | 段落尾端顯示留言數，可針對單一段落留言；回覆通知直接開啟對應段落 |
| 裝置管理 | ✅ | 登入時註冊、登出時移除，可在設定中檢視與移除登入裝置 |
| 推播通知（FCM / APNs） | 📋 | 裝置已可帶 `push_token`，待建立 Firebase 專案後串接 |
| 閱讀統計視覺化 | ✅ | Web 與 Flutter 皆有日／週／月圖表 |
| iOS App 上架、Apple Sign-In | 📋 | 需 macOS 與 Apple Developer 帳號 |
| PWA | ✅ | Web 可安裝；離線時閱讀、書架等頁面從本機資料庫載入；有新版本時提示重新整理 |
| 翻頁動畫 | ✅ | 無／滑動／覆蓋三種，設定跨裝置同步；仿真翻頁（`curl`）尚未實作，Flutter 以覆蓋顯示 |
| 多語言介面 | ✅ | 繁中、簡中、英文；跟隨帳號 `language_pref`，Web 與 Flutter 切換即時生效 |
| 第三方登入 | 📋 | 待取得 Google／Facebook／LINE 等平台憑證 |

✅ 完成　🚧 進行中 / 部分完成　📋 規劃中

### 後續階段

| 階段 | 內容 |
|------|------|
| **Phase 1** | MVP：Web App + Android App |
| **Phase 2** | iOS App、社群功能強化、功能優化 |
| **Phase 3** | Desktop App（Windows / macOS / Linux）與進階功能 |
| **Phase 4** | 商業化功能 |

完整時程見 [`docs/DEVELOPMENT_ROADMAP.md`](docs/DEVELOPMENT_ROADMAP.md)。

---

## 設計文件

| 文件 | 內容 |
|------|------|
| [PROJECT_OVERVIEW.md](docs/PROJECT_OVERVIEW.md) | 專案願景、範圍、目標用戶、KPI、風險評估 |
| [FEATURE_SPEC.md](docs/FEATURE_SPEC.md) | 功能模組、優先級與 P0 詳細規格、非功能性需求 |
| [TECHNICAL_ARCHITECTURE.md](docs/TECHNICAL_ARCHITECTURE.md) | 系統架構、各端技術設計 |
| [API_DESIGN.md](docs/API_DESIGN.md) | REST API 設計規範與端點細節 |
| [DATABASE_DESIGN.md](docs/DATABASE_DESIGN.md) | PostgreSQL、Redis、本地 SQLite 設計 |
| [CROSS_PLATFORM_STRATEGY.md](docs/CROSS_PLATFORM_STRATEGY.md) | 跨平台共用策略（API 規格、Schema、設計 Token） |
| [DEVELOPMENT_ROADMAP.md](docs/DEVELOPMENT_ROADMAP.md) | 開發階段、Sprint 規劃、里程碑 |

---

## 開發規範

- **分支策略**：GitHub Flow（`main` + feature branch），以 Squash Merge 合併，至少需要 1 位 Reviewer 核准
- **Commit 格式**：[Conventional Commits](https://www.conventionalcommits.org/)，例如 `feat:`、`fix:`、`docs:`、`refactor:`、`test:`、`chore:`
- **API 契約**：先修改 `shared/api-spec/openapi.yaml`，再重新產生 Web 與 Flutter 的型別
- **資料庫**：UUID 主鍵、snake_case 欄位、`created_at` / `updated_at` / `deleted_at`，軟刪除搭配 `WHERE deleted_at IS NULL` 部分索引
- **本地 Schema**：`shared/sqlite-schema/migrations/` 同時供 Web（sql.js）與 Flutter（sqflite）使用，修改時須兩端一起驗證
- **設計 Token**：色彩、字型、間距統一定義在 `shared/design-tokens/tokens.json`

使用 AI 程式助理協作時，請參考 [`CLAUDE.md`](CLAUDE.md) 與 [`AGENTS.md`](AGENTS.md)。
