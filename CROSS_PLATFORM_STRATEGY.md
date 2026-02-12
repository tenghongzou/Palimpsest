# NovelHub — 跨平台策略文件

## 1. 需求分析

### 1.1 目標平台

| 平台 | 優先級 | 階段 |
|------|--------|------|
| **Web** | 第一階段 | Phase 1 (MVP) |
| **Android** | 第一階段 | Phase 1 (MVP) |
| iOS | 第二階段 | Phase 2 |
| Windows | 第三階段 | Phase 3 |
| macOS | 第三階段 | Phase 3 |
| Linux | 第三階段 | Phase 3 |

### 1.2 各平台特殊需求

| 平台 | 特殊需求 |
|------|----------|
| Web | SEO、SSR/SSG、PWA 離線、鍵盤快捷鍵 |
| Android | Material Design、離線下載、Push Notification |
| iOS | Human Interface Guidelines、Apple Sign-In、Haptic Feedback |
| Desktop | 鍵盤快捷鍵、多視窗、系統匣、大螢幕 Layout |

---

## 2. 跨平台方案評估

### 2.1 候選方案

#### 方案 A：Nuxt 3（Web）+ Flutter（Mobile/Desktop）

```
Web ──────▶ Nuxt 3 + Vue 3 + TypeScript
Android ──▶ Flutter
iOS ──────▶ Flutter
Windows ──▶ Flutter Desktop
macOS ────▶ Flutter Desktop
Linux ────▶ Flutter Desktop
```

**優點**：
- Web 有最佳 SEO 和效能（SSR/ISR）
- Flutter 一套程式碼覆蓋 5 個平台
- 各平台都用最適合的工具
- Vue 3 生態系成熟、學習曲線低

**缺點**：
- 需維護兩套前端（Vue + Flutter）
- UI 元件需要各自實作

#### 方案 B：Flutter 全平台（含 Flutter Web）

```
所有平台 ──▶ Flutter
```

**優點**：
- 一套程式碼全覆蓋
- UI 完全一致

**缺點**：
- Flutter Web SEO 極差（Canvas 渲染）
- Flutter Web 初始載入大（2-5MB WASM）
- Flutter Web 無法做 SSR
- 文字密集型應用在 Flutter Web 上體驗差

#### 方案 C：Nuxt 3（Web）+ 各平台原生

```
Web ──────▶ Nuxt 3
Android ──▶ Kotlin / Jetpack Compose
iOS ──────▶ Swift / SwiftUI
Desktop ──▶ Tauri / Electron
```

**優點**：
- 各平台最佳體驗
- 效能最優

**缺點**：
- 開發成本極高（4+ 套程式碼）
- 需要多種技術棧的工程師

#### 方案 D：PWA + Capacitor 全平台

```
所有平台 ──▶ Nuxt 3 + Vue 3 + Capacitor
```

**優點**：
- 一套 Web 程式碼全覆蓋
- Vue 3 開發效率高

**缺點**：
- 原生功能受限
- 效能不如原生（特別是閱讀器動畫）
- App Store 審核可能被拒

### 2.2 評分矩陣

| 評估維度（權重） | 方案 A | 方案 B | 方案 C | 方案 D |
|-----------------|--------|--------|--------|--------|
| Web SEO & 效能 (25%) | 9 | 3 | 9 | 8 |
| Mobile 體驗 (25%) | 8 | 9 | 10 | 6 |
| 開發效率 (20%) | 7 | 9 | 4 | 9 |
| Desktop 覆蓋 (10%) | 8 | 7 | 7 | 6 |
| 維護成本 (10%) | 7 | 9 | 4 | 8 |
| 長期擴展性 (10%) | 8 | 7 | 9 | 6 |
| **加權總分** | **7.9** | **6.8** | **7.5** | **7.2** |

### 2.3 決策

**選擇方案 A：Nuxt 3（Web）+ Flutter（Mobile/Desktop）**

理由：
1. 小說閱讀是**文字密集型**應用，Web 端 SEO 極為重要
2. Nuxt 3 的 SSR/ISR 能力是 Flutter Web 無法比擬的
3. Flutter 在 Mobile/Desktop 端表現優秀
4. Vue 3 學習曲線低、開發效率高
5. 兩套前端的額外成本可透過共用 API 和設計系統降低

---

## 3. 最終技術方案

### 3.1 架構概覽

```
┌─────────────── 共用層 ──────────────────┐
│                                          │
│  ┌──────────────────────────────────┐   │
│  │        Go REST API (後端)         │   │
│  │   共用資料模型、業務邏輯、驗證      │   │
│  └──────────────────────────────────┘   │
│                                          │
│  ┌──────────────────────────────────┐   │
│  │      SQLite Schema (共用定義)      │   │
│  │   Web (sql.js) & Flutter (sqflite) │  │
│  └──────────────────────────────────┘   │
│                                          │
│  ┌──────────────────────────────────┐   │
│  │      Design Token (共用設計)       │   │
│  │   色彩、字體、間距、主題定義        │   │
│  └──────────────────────────────────┘   │
│                                          │
└──────────────────────────────────────────┘
         │                    │
  ┌──────▼──────┐     ┌──────▼──────┐
  │  Nuxt 3     │     │  Flutter    │
  │  Vue 3 + TS │     │  Dart       │
  │  Pinia      │     │  Riverpod   │
  │  ──────     │     │  ──────     │
  │  Web        │     │  Android    │
  │             │     │  iOS        │
  │             │     │  Windows    │
  │             │     │  macOS      │
  │             │     │  Linux      │
  └─────────────┘     └─────────────┘
```

### 3.2 程式碼共用策略

#### API 契約共用

```
shared/
├── api-spec/
│   └── openapi.yaml           # OpenAPI 3.0 規格（唯一真理來源）
├── sqlite-schema/
│   └── migrations/            # SQLite Migration SQL 檔案
│       ├── v001_initial.sql
│       └── v002_xxx.sql
└── design-tokens/
    ├── tokens.json            # Design Token 原始定義
    ├── css/                   # 產生的 CSS 變數
    └── dart/                  # 產生的 Dart 常數
```

#### TypeScript 型別自動產生（Web 端）

```bash
# 從 OpenAPI spec 產生 TypeScript 型別
npx openapi-typescript ./shared/api-spec/openapi.yaml -o ./web/types/api.d.ts
```

#### Dart 型別自動產生（Flutter 端）

```bash
# 從 OpenAPI spec 產生 Dart model
dart run build_runner build  # 使用 json_serializable
```

### 3.3 Design Token 系統

```json
{
  "color": {
    "primary": { "value": "#1890FF" },
    "reader": {
      "theme-white": { "bg": "#FFFFFF", "text": "#333333" },
      "theme-yellow": { "bg": "#F5F0E0", "text": "#4A4A4A" },
      "theme-green": { "bg": "#E0F0E0", "text": "#3A4A3A" },
      "theme-dark": { "bg": "#2C2C2C", "text": "#C0C0C0" },
      "theme-black": { "bg": "#000000", "text": "#808080" }
    }
  },
  "typography": {
    "reader-default-size": { "value": 18 },
    "reader-min-size": { "value": 12 },
    "reader-max-size": { "value": 36 },
    "reader-line-height": { "value": 1.8 }
  },
  "spacing": {
    "reader-margin": { "value": 16 }
  }
}
```

---

## 4. 各平台開發細節

### 4.1 Web 平台（Nuxt 3 + Vue 3）

**框架**：Nuxt 3
**UI 庫**：Naive UI + UnoCSS
**狀態管理**：Pinia
**本地 DB**：sql.js（WebAssembly SQLite）
**HTTP**：ofetch（Nuxt 內建）

**Web 專屬功能**：
- SSR/ISR 渲染（SEO 優化）
- Service Worker（PWA 離線快取）
- 鍵盤快捷鍵（方向鍵翻頁、Esc 返回）
- 響應式設計（Mobile Web 適配）
- URL 分享（書城/小說/章節 可直接分享連結）

**SSR 策略**：
```
書城首頁    → ISR (10min 重新驗證)
小說詳情    → ISR (5min 重新驗證)
分類/排行   → ISR (10min 重新驗證)
閱讀頁面    → CSR (不需 SEO)
個人中心    → CSR (私人內容)
管理後台    → CSR (內部使用)
```

### 4.2 Android 平台（Flutter）

**特殊考量**：
- Material Design 3 設計語言
- 返回鍵處理（閱讀器返回 vs 系統返回）
- 狀態列/導航列沈浸模式（閱讀時全螢幕）
- 下載管理（背景下載章節）
- Push Notification（書架更新通知）
- 最低版本：Android 7.0 (API 24)
- APK 大小目標：< 30MB

### 4.3 iOS 平台（Flutter — Phase 2）

**特殊考量**：
- Human Interface Guidelines 適配
- Apple Sign-In 必須支援（App Store 規範）
- Haptic Feedback（翻頁等操作）
- 劉海/Dynamic Island 適配
- App Store 審核：需注意內容政策
- 最低版本：iOS 15.0

### 4.4 Desktop 平台（Flutter — Phase 3）

**特殊考量**：
- 大螢幕 Layout（側邊欄 + 主內容區域）
- 鍵盤快捷鍵全面支援
- 滑鼠懸停效果
- 多視窗支援（同時看兩本書）
- 系統匣/Menubar 整合
- 視窗尺寸記憶
- 最小視窗尺寸：800 x 600

**Desktop Layout 設計**：
```
┌──────────────────────────────────────────────┐
│  Menu Bar                                     │
├────────┬─────────────────────────────────────┤
│        │                                      │
│ 側邊欄  │          主內容區域                   │
│        │                                      │
│ 書架    │    書城 / 閱讀器 / 設定               │
│ 分類    │                                      │
│ 排行    │                                      │
│ 搜尋    │                                      │
│ 設定    │                                      │
│        │                                      │
└────────┴─────────────────────────────────────┘
```

---

## 5. 響應式設計斷點

| 斷點 | 寬度 | 目標設備 |
|------|------|----------|
| xs | < 640px | 手機（直向）|
| sm | 640-768px | 手機（橫向）、小平板 |
| md | 768-1024px | 平板 |
| lg | 1024-1280px | 小筆電 |
| xl | 1280-1536px | 桌面 |
| 2xl | > 1536px | 大螢幕桌面 |

**閱讀器特殊處理**：
- xs-sm：全螢幕閱讀、底部工具列
- md+：限制內容最大寬度 (800px)、側邊工具列
- lg+：可選側邊章節目錄

---

## 6. 測試策略

### 6.1 Web 端測試

| 測試類型 | 工具 | 覆蓋範圍 |
|----------|------|----------|
| 單元測試 | Vitest | Composables、Store、工具函式 |
| 元件測試 | Vue Test Utils + Vitest | Vue 元件 |
| E2E 測試 | Playwright | 核心用戶流程 |
| 視覺回歸 | Playwright Screenshots | 頁面截圖比對 |

### 6.2 Flutter 端測試

| 測試類型 | 工具 | 覆蓋範圍 |
|----------|------|----------|
| 單元測試 | flutter_test | Provider、Repository、Service |
| Widget 測試 | flutter_test | UI 元件 |
| 整合測試 | integration_test | 核心用戶流程 |
| Golden 測試 | flutter_test | UI 截圖比對 |

### 6.3 後端測試

| 測試類型 | 工具 | 覆蓋範圍 |
|----------|------|----------|
| 單元測試 | go test | Service、Repository |
| 整合測試 | go test + testcontainers | API 端點 |
| 負載測試 | k6 | API 效能基準 |

---

## 7. 建議團隊配置

### MVP 階段最小團隊

| 角色 | 人數 | 負責範圍 |
|------|------|----------|
| 後端工程師 | 1-2 | Go API、資料庫、基礎設施 |
| Web 前端工程師 | 1-2 | Nuxt 3 + Vue 3 Web 應用 |
| Flutter 工程師 | 1-2 | Android App（後續覆蓋 iOS/Desktop）|
| UI/UX 設計師 | 1 | 設計系統、頁面設計 |
| **總計** | **4-7** | |

### 技能需求

| 角色 | 必備技能 | 加分技能 |
|------|----------|----------|
| 後端 | Go, PostgreSQL, Redis | Docker, K8s |
| Web 前端 | Vue 3, TypeScript, Nuxt 3 | UnoCSS, PWA |
| Flutter | Dart, Flutter, SQLite | 原生 Android/iOS |
| 設計 | Figma, 設計系統 | Motion Design |
