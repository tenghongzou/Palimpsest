# NovelHub — 開發路線圖

## 1. 開發階段總覽

```
Phase 0                Phase 1               Phase 2              Phase 3
環境建置與設計           MVP 開發               功能擴展              全平台上線
(Month 1)              (Month 2-6)           (Month 7-10)         (Month 11-14)
   │                      │                     │                    │
   ▼                      ▼                     ▼                    ▼
┌────────┐          ┌──────────┐          ┌──────────┐         ┌──────────┐
│ 基礎設施│          │ 後端 API │          │ iOS App  │         │ Desktop  │
│ 設計系統│          │ Web App  │          │ 社群功能 │         │ 商業化   │
│ CI/CD  │          │ Android  │          │ 推薦系統 │         │ 效能優化 │
└────────┘          └──────────┘          └──────────┘         └──────────┘
```

---

## 2. Phase 0：環境建置與設計（Month 1）

### Sprint 0.1 — 專案初始化（Week 1-2）

| 任務 | 說明 |
|------|------|
| Git Repository 建立 | Monorepo 或 multi-repo 決策 |
| Go 後端專案骨架 | Gin + GORM + 分層架構 |
| Nuxt 3 Web 專案骨架 | Vue 3 + TypeScript + Pinia + Naive UI |
| Flutter 專案骨架 | Riverpod + go_router + sqflite |
| Docker Compose 開發環境 | PostgreSQL + Redis + MinIO + Meilisearch |
| CI/CD Pipeline | GitHub Actions 自動測試與建構 |
| 程式碼規範與 Linter | ESLint + Prettier (Web) / dart analyze (Flutter) / golangci-lint (Go) |
| OpenAPI 3.0 規格初版 | API 契約定義 |

### Sprint 0.2 — UI/UX 設計（Week 2-4）

| 任務 | 說明 |
|------|------|
| User Journey Map | 核心用戶旅程 |
| Wireframe | 所有核心頁面線框圖 |
| UI Design | 視覺設計、設計系統、Design Token |
| Hi-Fi Prototype | Figma 互動式原型 |
| 設計審查 | 團隊 Review + 修改 |

**核心頁面**：書城首頁、分類頁、搜尋頁、小說詳情、閱讀頁面、書架、個人中心、登入/註冊、排行榜、管理後台

---

## 3. Phase 1：MVP 開發（Month 2-6）

### Sprint 1 — 後端核心基礎（Month 2, Week 1-2）

| 任務 | 說明 |
|------|------|
| 資料庫 Schema Migration | PostgreSQL 表建立 |
| 用戶 Model / Repository / Service | 完整分層 |
| JWT 認證中介軟體 | access + refresh token |
| 認證 API | 註冊 / 登入 / 登出 / Token 刷新 / 忘記密碼 |
| 通用中介軟體 | Logger, CORS, Recovery, RateLimit |
| 單元測試 | 核心邏輯測試覆蓋 |

**里程碑**：認證系統完成

### Sprint 2 — 小說與章節 API（Month 2, Week 3-4）

| 任務 | 說明 |
|------|------|
| 分類 CRUD API | 含多級分類 |
| 小說 CRUD API | 含搜尋、篩選、排序 |
| 章節 CRUD API | 含分頁 |
| Redis 緩存層 | Cache-Aside 模式 |
| Meilisearch 搜尋整合 | 全文搜尋索引 |
| MinIO 檔案上傳 | 封面圖上傳 |
| 種子資料腳本 | 匯入測試小說 |

**里程碑**：小說 CRUD + 搜尋完成

### Sprint 3 — 互動功能 + Web 骨架（Month 3, Week 1-2）

| 任務 | 說明 |
|------|------|
| 書架 API | 加入/移出/列表 |
| 閱讀進度 API | 同步/取得/批量 |
| 書籤 API | CRUD + 批量同步 |
| 排行榜 API | Redis Sorted Set |
| **Nuxt 3 路由與 Layout** | 頁面結構、自動路由 |
| **Naive UI 設定** | 全域主題、元件配置 |
| **API 客戶端封裝** | ofetch 封裝、攔截器 |
| **登入/註冊頁面** | Vue 3 表單驗證 |
| **Pinia 認證 Store** | 登入狀態管理 |

**里程碑**：後端 API 核心完成；Web 可登入

### Sprint 4 — Web 書城與閱讀器（Month 3 Week 3 - Month 4 Week 2）

| 任務 | 說明 |
|------|------|
| 書城首頁 | SSR + ISR、Banner、推薦區塊 |
| 小說分類頁 | 篩選、排序 |
| 小說詳情頁 | 書籍資訊、評分、加入書架 |
| 搜尋頁面 | 即時搜尋 + 建議 + 熱搜 |
| 排行榜頁面 | 多類型、多週期 |
| **閱讀器核心** | 捲動模式、文字渲染 |
| 閱讀設定面板 | 字體、主題、行高 |
| 閱讀進度顯示 | 記錄 + 恢復位置 |
| 章節導航 | 上一章/下一章/目錄 |

**里程碑**：Web 書城可瀏覽、閱讀器可閱讀

### Sprint 5 — Web 書架 + 離線 + Flutter 啟動（Month 4 Week 3 - Month 5 Week 2）

| 任務 | 說明 |
|------|------|
| 書架頁面 | 宮格/列表模式 |
| 書籤功能 | 新增/管理書籤 |
| sql.js 整合 | 瀏覽器端 SQLite |
| 離線緩存機制 | 已讀章節本地緩存 |
| 個人中心頁面 | 設定、統計 |
| **Flutter 基礎架構** | Clean Architecture + Riverpod |
| **Flutter 認證** | 登入/註冊/Token 管理 |
| **Flutter SQLite** | sqflite 整合、Migration |
| **Flutter 書城首頁** | 首頁 UI + API 串接 |
| **Flutter 小說詳情** | 詳情頁 |

**里程碑**：Web 功能基本完整；Flutter 可瀏覽書城

### Sprint 6 — Flutter 閱讀器 + 翻譯（Month 5 Week 3 - Month 6 Week 2）

| 任務 | 說明 |
|------|------|
| Flutter 閱讀器 | 捲動 + 翻頁模式 |
| Flutter 閱讀設定 | 字體、主題、行高 |
| Flutter 書架 | 收藏、進度同步 |
| Flutter 書籤 | CRUD |
| Flutter 離線下載 | 章節下載管理 |
| **翻譯 API — OpenCC** | 繁簡轉換 |
| **翻譯 API — Google Translate** | 英文翻譯 |
| **翻譯緩存** | Redis + PostgreSQL + SQLite |
| Web 翻譯功能 | 閱讀器內翻譯按鈕 |
| Flutter 翻譯功能 | 閱讀器內翻譯 |

**里程碑**：Flutter 閱讀完成；翻譯系統可用

### Sprint 7 — 社群功能 + 品質保證（Month 6, Week 1-2）

| 任務 | 說明 |
|------|------|
| 書評 / 留言 / 評分 API | 後端 |
| Web 書評/留言 UI | Vue 元件 |
| Flutter 書評/留言 UI | Flutter Widget |
| 管理後台 | Nuxt 3 管理介面（小說/用戶/審核）|
| E2E 測試 (Web) | Playwright |
| 整合測試 (Flutter) | integration_test |
| Bug 修復 | 全面修復 |

**里程碑**：MVP 功能完成

### Sprint 8 — MVP 發佈（Month 6, Week 3-4）

| 任務 | 說明 |
|------|------|
| K8s 正式環境部署 | Production 環境 |
| SSL + CDN | HTTPS + 靜態資源 CDN |
| 監控告警 | Prometheus + Grafana + Loki |
| 資料備份 | PostgreSQL 自動備份 |
| 種子資料匯入 | 正式內容 |
| Google Play 上架 | APK 準備、商店頁面 |
| Web 上線 | Nuxt 3 部署 |
| 上線監控 + Hotfix | 觀察 + 緊急修復 |

**里程碑：MVP 正式上線（Web + Android）**

---

## 4. Phase 2：功能擴展（Month 7-10）

### iOS App（Month 7-8）

- Flutter iOS 平台適配與測試
- Apple Sign-In 整合
- iOS 特有功能適配
- App Store 審核與上架

### 社群功能增強（Month 8-9）

- 段落評論（類似 Kindle）
- 通知系統（Push Notification）
- 閱讀統計視覺化

### 功能優化（Month 9-10）

- PWA 增強（Service Worker 離線體驗）
- 閱讀器翻頁動畫優化
- 第三方登入（Google, Facebook）
- 效能優化（API 回應、前端載入速度）
- 多語言介面（i18n）

---

## 5. Phase 3：全平台上線（Month 11-14）

### Desktop App（Month 11-12）

- Flutter Desktop 適配（Windows / macOS / Linux）
- 桌面端專屬 Layout（側邊欄 + 主內容）
- 鍵盤快捷鍵全面支援
- 打包與分發

### 進階功能（Month 13-14）

- 個性化推薦系統
- 數據分析儀表板增強
- 內容審核 AI 輔助
- 效能深度優化

---

## 6. Phase 4：商業化（Month 15+）

- VIP 會員訂閱制
- 章節付費機制
- 作者投稿平台
- 即時通訊/私訊

---

## 7. 關鍵里程碑

```
Month  1  │ ■ 開發環境就緒 ■ 設計稿完成
Month  2  │ ■ 認證系統完成 ■ 小說 CRUD 完成
Month  3  │ ■ 後端 API 核心完成 ■ Web 可登入瀏覽
Month  4  │ ■ Web 閱讀器完成 ■ Flutter 開發啟動
Month  5  │ ■ Web 離線功能完成 ■ Flutter 書城完成
Month  6  │ ■ 翻譯系統完成 ■ ★ MVP 上線（Web + Android）
Month  8  │ ■ ★ iOS App 上線
Month 10  │ ■ 社群增強 + 效能優化完成
Month 12  │ ■ ★ Desktop 上線（Windows + macOS）
Month 14  │ ■ ★ 全平台覆蓋完成
```

---

## 8. 風險與應對

| 風險 | 影響 | 應對 |
|------|------|------|
| MVP 延期 | 高 | 砍 P1 功能，確保 P0 準時上線 |
| Flutter 閱讀器效能不佳 | 中 | 提前做 POC 驗證 |
| Google Translate 費用超標 | 中 | 翻譯額度限制 + 積極緩存 |
| 團隊人手不足 | 高 | 優先後端 + Web，Android 延後 |
| 安全漏洞 | 高 | 上線前安全審計 |

---

## 9. 團隊協作

### Sprint 節奏

- **Sprint 長度**：2 週
- **Sprint Planning**：Sprint 首日 (2hr)
- **Daily Standup**：每日 15min
- **Sprint Review**：Sprint 最後一天
- **Sprint Retro**：Review 後 30min

### 代碼管理

- **分支策略**：GitHub Flow (main + feature branches)
- **Commit 規範**：Conventional Commits (feat:, fix:, docs:)
- **Code Review**：至少 1 人 Approve
- **合併策略**：Squash Merge

### 版本規劃

| 版本 | 階段 | 說明 |
|------|------|------|
| v0.x | Phase 0 | 開發中 |
| v1.0.0 | Phase 1 | MVP 發佈 |
| v1.1.0 | Phase 2 | iOS + 功能擴展 |
| v2.0.0 | Phase 3 | 全平台上線 |
| v3.0.0 | Phase 4 | 商業化版本 |
