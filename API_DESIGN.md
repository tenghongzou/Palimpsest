# NovelHub — API 設計文件

## 1. API 設計原則

- **風格**：RESTful API
- **資料格式**：JSON (UTF-8)
- **API 版本**：URL Path 版本化 (`/api/v1/...`)
- **認證方式**：JWT Bearer Token
- **文件規格**：OpenAPI 3.0

### Base URL

```
Production:  https://api.novelhub.com/api/v1
Development: http://localhost:8080/api/v1
```

### 通用 Request Headers

```
Content-Type: application/json
Authorization: Bearer <access_token>    (需認證的 API)
Accept-Language: zh-TW                  (語言偏好)
X-Device-Type: web | android | ios      (設備類型)
X-App-Version: 1.0.0                    (客戶端版本)
```

### 通用 Response 格式

**成功**：
```json
{
  "code": 0,
  "message": "success",
  "data": { ... }
}
```

**分頁**：
```json
{
  "code": 0,
  "data": {
    "items": [ ... ],
    "pagination": {
      "page": 1,
      "page_size": 20,
      "total": 150,
      "total_pages": 8
    }
  }
}
```

**錯誤**：
```json
{
  "code": 40001,
  "message": "Invalid email format",
  "errors": [
    { "field": "email", "message": "email must be a valid email address" }
  ]
}
```

### 錯誤碼規範

| 範圍 | 類別 |
|------|------|
| 0 | 成功 |
| 40001-40099 | 驗證錯誤 |
| 40101-40199 | 認證錯誤（Token 無效/過期）|
| 40301-40399 | 授權錯誤（無權限）|
| 40401-40499 | 資源不存在 |
| 40901-40999 | 衝突（資源已存在）|
| 42901-42999 | 頻率限制 |
| 50001-50099 | 伺服器錯誤 |

---

## 2. 認證 API

### 2.1 註冊

```
POST /api/v1/auth/register
```

**Request**:
```json
{
  "username": "reader001",
  "email": "reader@example.com",
  "password": "SecurePass123",
  "nickname": "愛閱讀的人"
}
```

**Response** (201):
```json
{
  "code": 0,
  "data": {
    "user": {
      "id": "uuid-xxxx",
      "username": "reader001",
      "email": "reader@example.com",
      "nickname": "愛閱讀的人",
      "role": "reader"
    },
    "access_token": "eyJhbG...",
    "refresh_token": "uuid-refresh-xxxx",
    "expires_in": 86400
  }
}
```

### 2.2 登入

```
POST /api/v1/auth/login
```

**Request**:
```json
{
  "login": "reader@example.com",
  "password": "SecurePass123"
}
```

### 2.3 Token 刷新

```
POST /api/v1/auth/refresh
```

**Request**:
```json
{ "refresh_token": "uuid-refresh-xxxx" }
```

### 2.4 登出

```
POST /api/v1/auth/logout
Authorization: Bearer <token>
```

Response: 204 No Content

### 2.5 忘記密碼 / 重設密碼

```
POST /api/v1/auth/forgot-password
Body: { "email": "reader@example.com" }

POST /api/v1/auth/reset-password
Body: { "token": "reset-token", "new_password": "NewPass456" }
```

---

## 3. 用戶 API

```
GET    /api/v1/users/me                    -- 取得個人資訊
PATCH  /api/v1/users/me                    -- 更新個人資料
POST   /api/v1/users/me/avatar             -- 上傳頭像 (multipart/form-data)
PUT    /api/v1/users/me/password           -- 修改密碼
GET    /api/v1/users/me/reading-stats      -- 閱讀統計 (?period=daily|weekly|monthly)
GET    /api/v1/users/me/reading-settings   -- 取得閱讀設定
PUT    /api/v1/users/me/reading-settings   -- 更新閱讀設定
GET    /api/v1/users/me/devices            -- 設備列表
DELETE /api/v1/users/me/devices/:deviceId  -- 移除設備
```

---

## 4. 小說 API

### 4.1 小說列表

```
GET /api/v1/novels
```

| 參數 | 類型 | 說明 |
|------|------|------|
| page | int | 頁碼，預設 1 |
| page_size | int | 每頁筆數，預設 20，最大 50 |
| category_id | int | 分類篩選 |
| status | string | ongoing / completed |
| language | string | zh-TW / zh-CN / en |
| sort_by | string | latest / popular / rating / words |

**Response 項目**:
```json
{
  "id": "uuid-xxxx",
  "title": "鬥破蒼穹",
  "author_name": "天蠶土豆",
  "cover_url": "https://cdn.novelhub.com/covers/xxxx.jpg",
  "description": "這裡是蒼茫的鬥氣大陸...",
  "status": "completed",
  "language": "zh-CN",
  "total_words": 5300000,
  "total_chapters": 1648,
  "avg_rating": 4.5,
  "view_count": 15000000,
  "favorite_count": 500000,
  "latest_chapter_title": "第1648章 大結局",
  "latest_chapter_at": "2024-12-01T12:00:00Z",
  "categories": [{ "id": 1, "name": "玄幻" }],
  "tags": ["熱血", "升級", "鬥氣"]
}
```

### 4.2 其他小說端點

```
GET /api/v1/novels/:novelId                -- 小說詳情
GET /api/v1/novels/:novelId/chapters       -- 章節列表 (?order=asc|desc)
GET /api/v1/novels/:novelId/chapters/:id   -- 章節內容（含 prev/next 章節資訊）
GET /api/v1/categories                     -- 分類列表（含子分類）
```

---

## 5. 搜尋 API

```
GET /api/v1/search/novels              -- 搜尋小說 (?q=鬥破&sort_by=relevance)
GET /api/v1/search/suggestions?q=鬥破  -- 搜尋建議（自動完成）
GET /api/v1/search/hot-keywords        -- 熱門搜尋
```

**搜尋建議 Response**:
```json
{
  "code": 0,
  "data": {
    "suggestions": [
      { "type": "novel", "text": "鬥破蒼穹", "id": "uuid-xxxx" },
      { "type": "author", "text": "鬥破小天才" },
      { "type": "keyword", "text": "鬥破" }
    ]
  }
}
```

---

## 6. 排行榜 API

```
GET /api/v1/rankings/:type
```

**Path**: type = views | favorites | rating | latest | completed
**Query**: period = daily | weekly | monthly | all, category_id, page, page_size

**Response 項目**:
```json
{
  "rank": 1,
  "novel": { ... },
  "value": 1500000,
  "change": 2
}
```

---

## 7. 書架 API

```
GET    /api/v1/bookshelf                   -- 書架列表 (?sort_by=recent|added|title)
POST   /api/v1/bookshelf                   -- 加入書架 { novel_id, group_name }
DELETE /api/v1/bookshelf/:novelId          -- 移出書架
POST   /api/v1/bookshelf/batch-remove      -- 批量移出 { novel_ids: [] }
PATCH  /api/v1/bookshelf/:novelId          -- 更新分組 { group_name }
```

**書架列表項目**:
```json
{
  "id": "uuid-shelf-item",
  "novel": {
    "id": "uuid-novel",
    "title": "鬥破蒼穹",
    "cover_url": "...",
    "latest_chapter_title": "第1648章"
  },
  "reading_progress": {
    "chapter_title": "第500章",
    "chapter_number": 500,
    "percentage": 30.3
  },
  "has_update": true,
  "group_name": "default"
}
```

---

## 8. 閱讀進度 API

```
PUT  /api/v1/reading-progress/:novelId     -- 同步進度
GET  /api/v1/reading-progress/:novelId     -- 取得進度
POST /api/v1/reading-progress/batch        -- 批量取得 { novel_ids: [] }
GET  /api/v1/reading-history               -- 閱讀歷史（分頁）
```

**同步進度 Request**:
```json
{
  "chapter_id": "uuid-chap-500",
  "paragraph_index": 42,
  "scroll_offset": 0.35,
  "read_at": "2025-01-01T12:00:00Z"
}
```

---

## 9. 書籤 API

```
GET    /api/v1/bookmarks                   -- 列表 (?novel_id=xxx)
POST   /api/v1/bookmarks                   -- 新增
PATCH  /api/v1/bookmarks/:bookmarkId       -- 更新
DELETE /api/v1/bookmarks/:bookmarkId       -- 刪除
POST   /api/v1/bookmarks/sync             -- 批量同步（離線資料）
```

---

## 10. 社群 API

### 書評

```
GET    /api/v1/novels/:novelId/reviews     -- 書評列表
POST   /api/v1/novels/:novelId/reviews     -- 建立書評 { title, content, rating }
PUT    /api/v1/reviews/:reviewId           -- 更新書評
DELETE /api/v1/reviews/:reviewId           -- 刪除書評
POST   /api/v1/reviews/:reviewId/like      -- 按讚
DELETE /api/v1/reviews/:reviewId/like      -- 取消按讚
```

### 章節留言

```
GET    /api/v1/chapters/:chapterId/comments -- 留言列表 (?sort_by=latest|popular)
POST   /api/v1/chapters/:chapterId/comments -- 建立留言 { content, parent_id?, paragraph_index? }
DELETE /api/v1/comments/:commentId          -- 刪除留言
POST   /api/v1/comments/:commentId/like     -- 按讚
DELETE /api/v1/comments/:commentId/like     -- 取消按讚
```

### 舉報

```
POST /api/v1/reports
Body: { target_type, target_id, reason, description }
```

---

## 11. 翻譯 API

### 繁簡轉換

```
POST /api/v1/translation/convert
Body: { "text": "鬥破蒼穹", "from": "zh-TW", "to": "zh-CN" }
```

### 翻譯章節

```
POST /api/v1/translation/chapter
Authorization: Bearer <token>
Body: { "chapter_id": "uuid", "target_lang": "en" }
```

**Response**:
```json
{
  "code": 0,
  "data": {
    "chapter_id": "uuid",
    "original_lang": "zh-TW",
    "target_lang": "en",
    "translated_content": "Battle Through the Heavens...",
    "is_cached": false
  }
}
```

### 翻譯選取文字

```
POST /api/v1/translation/text
Body: { "text": "鬥氣大陸", "from": "zh-TW", "to": "en" }
```

---

## 12. 公共 API

### 書城首頁

```
GET /api/v1/home
```

**Response**:
```json
{
  "code": 0,
  "data": {
    "banners": [ ... ],
    "featured": [ ... ],
    "latest_updates": [ ... ],
    "popular": [ ... ],
    "new_arrivals": [ ... ],
    "completed": [ ... ]
  }
}
```

### Banner

```
GET /api/v1/banners
```

---

## 13. 管理後台 API

所有需要 `admin` 或 `super_admin` 角色。

### 小說管理

```
GET    /api/v1/admin/novels                        -- 列表（含搜尋/篩選）
POST   /api/v1/admin/novels                        -- 建立小說
PUT    /api/v1/admin/novels/:novelId               -- 更新
DELETE /api/v1/admin/novels/:novelId               -- 刪除
PATCH  /api/v1/admin/novels/:novelId/publish       -- 上架/下架
POST   /api/v1/admin/novels/:novelId/chapters      -- 新增章節
PUT    /api/v1/admin/novels/:id/chapters/:id       -- 更新章節
DELETE /api/v1/admin/novels/:id/chapters/:id       -- 刪除章節
POST   /api/v1/admin/novels/:id/chapters/batch     -- 批量匯入章節
```

### 用戶管理

```
GET   /api/v1/admin/users                          -- 用戶列表
GET   /api/v1/admin/users/:userId                  -- 用戶詳情
PATCH /api/v1/admin/users/:userId/status           -- 封禁/解封
```

### 內容審核

```
GET   /api/v1/admin/reviews                        -- 待審核書評
PATCH /api/v1/admin/reviews/:reviewId/status       -- 審核書評
GET   /api/v1/admin/reports                        -- 舉報列表
PATCH /api/v1/admin/reports/:reportId/resolve      -- 處理舉報
```

### 分類 / Banner / 統計

```
CRUD  /api/v1/admin/categories
CRUD  /api/v1/admin/banners
GET   /api/v1/admin/stats/overview                 -- 總覽統計
GET   /api/v1/admin/stats/users                    -- 用戶統計
GET   /api/v1/admin/stats/novels                   -- 小說統計
GET   /api/v1/admin/stats/reading                  -- 閱讀統計
```

---

## 14. 頻率限制

| API 類別 | 限制 | 說明 |
|----------|------|------|
| 公開 API | 60 req/min per IP | 未登入用戶 |
| 認證 API | 120 req/min per User | 登入用戶 |
| 登入/註冊 | 5 req/min per IP | 防暴力破解 |
| 搜尋 API | 30 req/min per User | 防濫用 |
| 翻譯 API | 20 req/min per User | 控制 API 費用 |
| 管理 API | 300 req/min per User | 管理員 |

---

## 15. API 端點清單

| 方法 | 路徑 | 認證 | 說明 |
|------|------|------|------|
| POST | /auth/register | 否 | 註冊 |
| POST | /auth/login | 否 | 登入 |
| POST | /auth/refresh | 否 | 刷新 Token |
| POST | /auth/logout | 是 | 登出 |
| POST | /auth/forgot-password | 否 | 忘記密碼 |
| POST | /auth/reset-password | 否 | 重設密碼 |
| GET/PATCH | /users/me | 是 | 個人資訊 |
| POST | /users/me/avatar | 是 | 上傳頭像 |
| PUT | /users/me/password | 是 | 修改密碼 |
| GET | /users/me/reading-stats | 是 | 閱讀統計 |
| GET/PUT | /users/me/reading-settings | 是 | 閱讀設定 |
| GET | /home | 否 | 書城首頁 |
| GET | /novels | 否 | 小說列表 |
| GET | /novels/:id | 否 | 小說詳情 |
| GET | /novels/:id/chapters | 否 | 章節列表 |
| GET | /novels/:id/chapters/:id | 可選 | 章節內容 |
| GET | /categories | 否 | 分類列表 |
| GET | /search/novels | 否 | 搜尋 |
| GET | /search/suggestions | 否 | 搜尋建議 |
| GET | /search/hot-keywords | 否 | 熱搜 |
| GET | /rankings/:type | 否 | 排行榜 |
| GET/POST | /bookshelf | 是 | 書架 |
| DELETE | /bookshelf/:novelId | 是 | 移出書架 |
| PUT/GET | /reading-progress/:novelId | 是 | 閱讀進度 |
| GET | /reading-history | 是 | 閱讀歷史 |
| CRUD | /bookmarks | 是 | 書籤 |
| POST | /bookmarks/sync | 是 | 同步書籤 |
| GET/POST | /novels/:id/reviews | 可選/是 | 書評 |
| GET/POST | /chapters/:id/comments | 可選/是 | 留言 |
| POST | /translation/convert | 否 | 繁簡轉換 |
| POST | /translation/chapter | 是 | 翻譯章節 |
| POST | /translation/text | 是 | 翻譯文字 |
| * | /admin/* | Admin | 管理後台 |
