# NovelHub — 資料庫設計文件

## 1. 資料庫架構總覽

| 層級 | 資料庫 | 用途 |
|------|--------|------|
| **中央資料庫** | PostgreSQL 16+ | 所有業務資料的主要存儲 |
| **緩存層** | Redis 7+ | 高頻讀取資料緩存、Session、排行榜 |
| **搜尋引擎** | Meilisearch | 小說全文搜尋索引 |
| **本地資料庫** | SQLite | 客戶端離線資料、閱讀緩存 |

---

## 2. 中央資料庫（PostgreSQL）Schema 設計

### 2.1 ER 關係圖

```
users ──< bookshelf_items >── novels ──< chapters
  │                             │           │
  │──< reading_progress >───────┘           │
  │                                         │
  │──< bookmarks >──────────────────────────┘
  │                             │
  │──< reviews >────────────────┘
  │
  │──< comments
  │
  └──< user_devices

novels ──< novel_tags >── tags
novels ──< novel_categories >── categories ──< categories (self-ref)
chapters ──< translation_cache
```

### 2.2 用戶相關表

#### users（用戶表）

```sql
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username        VARCHAR(50) UNIQUE NOT NULL,
    email           VARCHAR(255) UNIQUE,
    phone           VARCHAR(20) UNIQUE,
    password_hash   VARCHAR(255) NOT NULL,
    nickname        VARCHAR(50),
    avatar_url      VARCHAR(500),
    bio             TEXT,
    role            VARCHAR(20) DEFAULT 'reader',  -- reader, author, admin, super_admin
    status          VARCHAR(20) DEFAULT 'active',  -- active, suspended, deleted
    language_pref   VARCHAR(10) DEFAULT 'zh-TW',   -- zh-TW, zh-CN, en

    -- 閱讀統計
    total_read_words    BIGINT DEFAULT 0,
    total_read_seconds  BIGINT DEFAULT 0,

    -- 時間戳
    email_verified_at   TIMESTAMPTZ,
    phone_verified_at   TIMESTAMPTZ,
    last_login_at       TIMESTAMPTZ,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW(),
    deleted_at          TIMESTAMPTZ,

    CONSTRAINT chk_email_or_phone CHECK (email IS NOT NULL OR phone IS NOT NULL)
);

CREATE INDEX idx_users_email ON users(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_phone ON users(phone) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_username ON users(username) WHERE deleted_at IS NULL;
```

#### user_devices（用戶設備表）

```sql
CREATE TABLE user_devices (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_type     VARCHAR(20) NOT NULL,      -- web, android, ios, windows, mac, linux
    device_name     VARCHAR(100),
    device_id       VARCHAR(255),
    push_token      VARCHAR(500),
    last_active_at  TIMESTAMPTZ DEFAULT NOW(),
    created_at      TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(user_id, device_id)
);

CREATE INDEX idx_user_devices_user ON user_devices(user_id);
```

#### user_reading_settings（用戶閱讀設定表）

```sql
CREATE TABLE user_reading_settings (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    font_size       INT DEFAULT 18,
    line_height     DECIMAL(3,1) DEFAULT 1.8,
    letter_spacing  DECIMAL(3,1) DEFAULT 0.0,
    margin          INT DEFAULT 16,
    font_family     VARCHAR(50) DEFAULT 'system',
    theme           VARCHAR(20) DEFAULT 'white',
    reading_mode    VARCHAR(20) DEFAULT 'scroll',
    brightness      INT DEFAULT 100,
    keep_screen_on  BOOLEAN DEFAULT TRUE,
    auto_chapter    BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);
```

### 2.3 小說相關表

#### categories（分類表）

```sql
CREATE TABLE categories (
    id              SERIAL PRIMARY KEY,
    parent_id       INT REFERENCES categories(id),
    name            VARCHAR(50) NOT NULL,
    slug            VARCHAR(50) UNIQUE NOT NULL,
    icon_url        VARCHAR(500),
    sort_order      INT DEFAULT 0,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_categories_parent ON categories(parent_id);
```

#### novels（小說表）

```sql
CREATE TABLE novels (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title           VARCHAR(200) NOT NULL,
    author_name     VARCHAR(100) NOT NULL,
    author_id       UUID REFERENCES users(id),
    cover_url       VARCHAR(500),
    description     TEXT,
    status          VARCHAR(20) DEFAULT 'ongoing', -- ongoing, completed, hiatus
    language        VARCHAR(10) DEFAULT 'zh-TW',

    -- 統計資料
    total_words     BIGINT DEFAULT 0,
    total_chapters  INT DEFAULT 0,
    view_count      BIGINT DEFAULT 0,
    favorite_count  INT DEFAULT 0,
    review_count    INT DEFAULT 0,
    rating_sum      DECIMAL(10,1) DEFAULT 0,
    rating_count    INT DEFAULT 0,
    avg_rating      DECIMAL(3,2) DEFAULT 0,

    -- 狀態
    is_published    BOOLEAN DEFAULT FALSE,
    is_featured     BOOLEAN DEFAULT FALSE,

    -- 最新章節資訊（冗餘欄位，加速查詢）
    latest_chapter_id    UUID,
    latest_chapter_title VARCHAR(200),
    latest_chapter_at    TIMESTAMPTZ,

    -- 時間戳
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    published_at    TIMESTAMPTZ,
    deleted_at      TIMESTAMPTZ
);

CREATE INDEX idx_novels_published ON novels(is_published, published_at DESC);
CREATE INDEX idx_novels_rating ON novels(avg_rating DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_novels_views ON novels(view_count DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_novels_favorites ON novels(favorite_count DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_novels_latest ON novels(latest_chapter_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_novels_author ON novels(author_name);

-- 全文搜尋索引
ALTER TABLE novels ADD COLUMN search_vector tsvector;
CREATE INDEX idx_novels_search ON novels USING GIN(search_vector);
```

#### novel_categories / tags / novel_tags

```sql
CREATE TABLE novel_categories (
    novel_id        UUID NOT NULL REFERENCES novels(id) ON DELETE CASCADE,
    category_id     INT NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    PRIMARY KEY (novel_id, category_id)
);

CREATE TABLE tags (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(30) UNIQUE NOT NULL,
    usage_count     INT DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE novel_tags (
    novel_id        UUID NOT NULL REFERENCES novels(id) ON DELETE CASCADE,
    tag_id          INT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (novel_id, tag_id)
);
```

#### volumes（卷表）

```sql
CREATE TABLE volumes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    novel_id        UUID NOT NULL REFERENCES novels(id) ON DELETE CASCADE,
    title           VARCHAR(200) NOT NULL,
    volume_number   INT NOT NULL,
    sort_order      INT NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(novel_id, volume_number)
);

CREATE INDEX idx_volumes_novel ON volumes(novel_id, sort_order);
```

#### chapters（章節表）

```sql
CREATE TABLE chapters (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    novel_id        UUID NOT NULL REFERENCES novels(id) ON DELETE CASCADE,
    volume_id       UUID REFERENCES volumes(id),
    title           VARCHAR(200) NOT NULL,
    content         TEXT NOT NULL,
    chapter_number  INT NOT NULL,
    word_count      INT DEFAULT 0,
    is_published    BOOLEAN DEFAULT FALSE,
    is_free         BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    published_at    TIMESTAMPTZ,

    UNIQUE(novel_id, chapter_number)
);

CREATE INDEX idx_chapters_novel ON chapters(novel_id, chapter_number);
CREATE INDEX idx_chapters_novel_published ON chapters(novel_id, is_published, chapter_number);
```

### 2.4 互動相關表

#### bookshelf_items（書架項目表）

```sql
CREATE TABLE bookshelf_items (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    novel_id        UUID NOT NULL REFERENCES novels(id) ON DELETE CASCADE,
    group_name      VARCHAR(50) DEFAULT 'default',
    sort_order      INT DEFAULT 0,
    is_notified     BOOLEAN DEFAULT TRUE,
    added_at        TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(user_id, novel_id)
);

CREATE INDEX idx_bookshelf_user ON bookshelf_items(user_id, added_at DESC);
```

#### reading_progress（閱讀進度表）

```sql
CREATE TABLE reading_progress (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    novel_id        UUID NOT NULL REFERENCES novels(id) ON DELETE CASCADE,
    chapter_id      UUID NOT NULL REFERENCES chapters(id),
    paragraph_index INT DEFAULT 0,
    scroll_offset   DECIMAL(5,4) DEFAULT 0,
    read_duration   INT DEFAULT 0,
    read_at         TIMESTAMPTZ DEFAULT NOW(),
    synced_at       TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(user_id, novel_id)
);

CREATE INDEX idx_reading_progress_user ON reading_progress(user_id, read_at DESC);
```

#### reading_history（閱讀歷史表）

```sql
CREATE TABLE reading_history (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    novel_id        UUID NOT NULL REFERENCES novels(id) ON DELETE CASCADE,
    chapter_id      UUID NOT NULL REFERENCES chapters(id),
    read_at         TIMESTAMPTZ DEFAULT NOW(),
    duration        INT DEFAULT 0
);

CREATE INDEX idx_reading_history_user ON reading_history(user_id, read_at DESC);
```

#### bookmarks（書籤表）

```sql
CREATE TABLE bookmarks (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    novel_id        UUID NOT NULL REFERENCES novels(id) ON DELETE CASCADE,
    chapter_id      UUID NOT NULL REFERENCES chapters(id),
    paragraph_index INT DEFAULT 0,
    note            VARCHAR(500),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    synced_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_bookmarks_user ON bookmarks(user_id, created_at DESC);
CREATE INDEX idx_bookmarks_user_novel ON bookmarks(user_id, novel_id);
```

#### reviews（書評表）

```sql
CREATE TABLE reviews (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    novel_id        UUID NOT NULL REFERENCES novels(id) ON DELETE CASCADE,
    title           VARCHAR(200) NOT NULL,
    content         TEXT NOT NULL,
    rating          DECIMAL(2,1) NOT NULL CHECK (rating >= 0.5 AND rating <= 5.0),
    like_count      INT DEFAULT 0,
    status          VARCHAR(20) DEFAULT 'approved',
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(user_id, novel_id)
);

CREATE INDEX idx_reviews_novel ON reviews(novel_id, created_at DESC);
```

#### comments（章節留言表）

```sql
CREATE TABLE comments (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    chapter_id      UUID NOT NULL REFERENCES chapters(id) ON DELETE CASCADE,
    parent_id       UUID REFERENCES comments(id),
    content         TEXT NOT NULL,
    paragraph_index INT,
    like_count      INT DEFAULT 0,
    status          VARCHAR(20) DEFAULT 'approved',
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ
);

CREATE INDEX idx_comments_chapter ON comments(chapter_id, created_at DESC);
CREATE INDEX idx_comments_parent ON comments(parent_id);
```

#### likes / reports

```sql
CREATE TABLE likes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    target_type     VARCHAR(20) NOT NULL,       -- review, comment
    target_id       UUID NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, target_type, target_id)
);

CREATE TABLE reports (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id     UUID NOT NULL REFERENCES users(id),
    target_type     VARCHAR(20) NOT NULL,
    target_id       UUID NOT NULL,
    reason          VARCHAR(50) NOT NULL,
    description     TEXT,
    status          VARCHAR(20) DEFAULT 'pending',
    resolved_by     UUID REFERENCES users(id),
    resolved_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_reports_status ON reports(status, created_at DESC);
```

### 2.5 翻譯緩存表

```sql
CREATE TABLE translation_cache (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chapter_id      UUID NOT NULL REFERENCES chapters(id) ON DELETE CASCADE,
    source_lang     VARCHAR(10) NOT NULL,
    target_lang     VARCHAR(10) NOT NULL,
    content_hash    VARCHAR(64) NOT NULL,
    translated_text TEXT NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(chapter_id, source_lang, target_lang)
);

CREATE INDEX idx_translation_cache_lookup ON translation_cache(chapter_id, source_lang, target_lang);
```

### 2.6 系統管理表

```sql
CREATE TABLE banners (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title           VARCHAR(200) NOT NULL,
    image_url       VARCHAR(500) NOT NULL,
    link_type       VARCHAR(20),
    link_value      VARCHAR(500),
    sort_order      INT DEFAULT 0,
    is_active       BOOLEAN DEFAULT TRUE,
    start_at        TIMESTAMPTZ,
    end_at          TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE search_keywords (
    id              SERIAL PRIMARY KEY,
    keyword         VARCHAR(100) UNIQUE NOT NULL,
    search_count    BIGINT DEFAULT 1,
    last_searched   TIMESTAMPTZ DEFAULT NOW(),
    is_hot          BOOLEAN DEFAULT FALSE
);

CREATE TABLE admin_logs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id        UUID NOT NULL REFERENCES users(id),
    action          VARCHAR(50) NOT NULL,
    target_type     VARCHAR(50),
    target_id       VARCHAR(100),
    detail          JSONB,
    ip_address      INET,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_admin_logs_admin ON admin_logs(admin_id, created_at DESC);
```

---

## 3. 本地資料庫（SQLite）Schema 設計

### 3.1 設計原則

- 本地 SQLite 為伺服器端資料的**子集與緩存**
- 主要用於離線閱讀和減少網路請求
- 資料以伺服器為準，衝突時以伺服器勝出
- Web 端使用 sql.js (WebAssembly)，Flutter 端使用 sqflite
- 兩端共用相同的 Migration SQL 定義

### 3.2 Schema 定義

#### local_novels

```sql
CREATE TABLE local_novels (
    id              TEXT PRIMARY KEY,
    title           TEXT NOT NULL,
    author_name     TEXT NOT NULL,
    cover_url       TEXT,
    cover_local_path TEXT,
    description     TEXT,
    status          TEXT DEFAULT 'ongoing',
    language        TEXT DEFAULT 'zh-TW',
    total_words     INTEGER DEFAULT 0,
    total_chapters  INTEGER DEFAULT 0,
    avg_rating      REAL DEFAULT 0,
    latest_chapter_title TEXT,
    latest_chapter_at TEXT,
    cached_at       TEXT DEFAULT (datetime('now')),
    updated_at      TEXT DEFAULT (datetime('now'))
);
```

#### local_chapters

```sql
CREATE TABLE local_chapters (
    id              TEXT PRIMARY KEY,
    novel_id        TEXT NOT NULL,
    title           TEXT NOT NULL,
    content         TEXT NOT NULL,
    chapter_number  INTEGER NOT NULL,
    word_count      INTEGER DEFAULT 0,
    is_downloaded   INTEGER DEFAULT 0,         -- 0=自動緩存, 1=手動下載
    cached_at       TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (novel_id) REFERENCES local_novels(id) ON DELETE CASCADE
);

CREATE INDEX idx_local_chapters_novel ON local_chapters(novel_id, chapter_number);
```

#### local_reading_progress

```sql
CREATE TABLE local_reading_progress (
    id              TEXT PRIMARY KEY,
    novel_id        TEXT NOT NULL UNIQUE,
    chapter_id      TEXT NOT NULL,
    paragraph_index INTEGER DEFAULT 0,
    scroll_offset   REAL DEFAULT 0,
    read_at         TEXT DEFAULT (datetime('now')),
    is_synced       INTEGER DEFAULT 0
);
```

#### local_bookmarks

```sql
CREATE TABLE local_bookmarks (
    id              TEXT PRIMARY KEY,
    novel_id        TEXT NOT NULL,
    chapter_id      TEXT NOT NULL,
    chapter_title   TEXT,
    paragraph_index INTEGER DEFAULT 0,
    note            TEXT,
    created_at      TEXT DEFAULT (datetime('now')),
    is_synced       INTEGER DEFAULT 0,
    is_deleted      INTEGER DEFAULT 0
);

CREATE INDEX idx_local_bookmarks_novel ON local_bookmarks(novel_id);
```

#### local_bookshelf

```sql
CREATE TABLE local_bookshelf (
    id              TEXT PRIMARY KEY,
    novel_id        TEXT NOT NULL UNIQUE,
    group_name      TEXT DEFAULT 'default',
    sort_order      INTEGER DEFAULT 0,
    added_at        TEXT DEFAULT (datetime('now')),
    is_synced       INTEGER DEFAULT 0,
    is_deleted      INTEGER DEFAULT 0
);
```

#### local_reading_settings

```sql
CREATE TABLE local_reading_settings (
    id              INTEGER PRIMARY KEY CHECK (id = 1),
    font_size       INTEGER DEFAULT 18,
    line_height     REAL DEFAULT 1.8,
    letter_spacing  REAL DEFAULT 0.0,
    margin          INTEGER DEFAULT 16,
    font_family     TEXT DEFAULT 'system',
    theme           TEXT DEFAULT 'white',
    reading_mode    TEXT DEFAULT 'scroll',
    brightness      INTEGER DEFAULT 100,
    keep_screen_on  INTEGER DEFAULT 1,
    auto_chapter    INTEGER DEFAULT 1,
    updated_at      TEXT DEFAULT (datetime('now'))
);
```

#### local_translation_cache

```sql
CREATE TABLE local_translation_cache (
    id              TEXT PRIMARY KEY,
    chapter_id      TEXT NOT NULL,
    source_lang     TEXT NOT NULL,
    target_lang     TEXT NOT NULL,
    translated_text TEXT NOT NULL,
    cached_at       TEXT DEFAULT (datetime('now')),

    UNIQUE(chapter_id, source_lang, target_lang)
);
```

#### local_search_history

```sql
CREATE TABLE local_search_history (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    keyword         TEXT NOT NULL,
    searched_at     TEXT DEFAULT (datetime('now'))
);
-- 限制最多保留 50 筆
```

#### local_sync_queue

```sql
CREATE TABLE local_sync_queue (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    action          TEXT NOT NULL,              -- create, update, delete
    entity_type     TEXT NOT NULL,              -- bookmark, progress, bookshelf
    entity_id       TEXT NOT NULL,
    payload         TEXT,                       -- JSON
    retry_count     INTEGER DEFAULT 0,
    created_at      TEXT DEFAULT (datetime('now'))
);
```

#### local_meta

```sql
CREATE TABLE local_meta (
    key             TEXT PRIMARY KEY,
    value           TEXT,
    updated_at      TEXT DEFAULT (datetime('now'))
);

-- 預設資料：
-- key: 'db_version', value: '1'
-- key: 'last_sync_at', value: null
-- key: 'cache_size_bytes', value: '0'
-- key: 'max_cache_size_bytes', value: '524288000' (500MB)
```

### 3.3 資料同步策略

```
觸發時機：
  1. App 啟動時
  2. 網路恢復在線時
  3. 定時同步（每 5 分鐘）
  4. 用戶手動觸發

同步順序：
  1. 上傳 local_sync_queue 中的待同步資料
  2. 拉取伺服器最新閱讀進度（比較時間戳）
  3. 拉取書架變更
  4. 拉取書籤變更

衝突策略：
  - 閱讀進度：時間戳較新者勝出
  - 書籤：合併策略（兩端新增的都保留）
  - 書架：以伺服器為準
  - 閱讀設定：時間戳較新者勝出

錯誤處理：
  - 同步失敗：保留在 sync_queue，retry_count++
  - retry_count > 5：標記為失敗，等待手動重試
  - 網路錯誤：靜默失敗，下次同步時重試
```

---

## 4. Redis 資料結構設計

### 4.1 Key 命名規範

```
格式：novelhub:{entity}:{id}:{field}
```

### 4.2 關鍵資料結構

| Key Pattern | Type | TTL | 說明 |
|-------------|------|-----|------|
| `novel:{id}` | Hash | 10min | 小說詳情 |
| `chapter:{id}` | String | 1hr | 章節內容 |
| `ranking:views:daily` | Sorted Set | 10min | 日閱讀量排行 |
| `ranking:views:weekly` | Sorted Set | 10min | 週閱讀量排行 |
| `ranking:favorites:all` | Sorted Set | 10min | 總收藏排行 |
| `user:{id}:session` | String | 24hr | 用戶 Session |
| `user:{id}:refresh` | String | 30d | Refresh Token |
| `categories:all` | String | 24hr | 分類列表 |
| `search:hot` | List | 1hr | 熱門搜尋詞 |
| `translation:{chapterId}:{lang}` | String | 7d | 翻譯結果 |
| `ratelimit:{ip}` | String | 1min | IP 頻率限制 |

---

## 5. 效能優化

### 5.1 索引策略

- 複合索引根據查詢模式建立，注意欄位順序
- 部分索引使用 `WHERE deleted_at IS NULL` 過濾已刪除資料
- GIN 索引用於全文搜尋
- 定期透過 `EXPLAIN ANALYZE` 檢查查詢效能

### 5.2 讀寫分離（未來擴展）

```
寫入流量 → PostgreSQL Primary
讀取流量 → PostgreSQL Replica(s)
高頻讀取 → Redis Cache
```
