-- Users
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username        VARCHAR(50) UNIQUE NOT NULL,
    email           VARCHAR(255) UNIQUE,
    phone           VARCHAR(20) UNIQUE,
    password_hash   VARCHAR(255) NOT NULL,
    nickname        VARCHAR(50),
    avatar_url      VARCHAR(500),
    bio             TEXT,
    role            VARCHAR(20) DEFAULT 'reader',
    status          VARCHAR(20) DEFAULT 'active',
    language_pref   VARCHAR(10) DEFAULT 'zh-TW',
    total_read_words    BIGINT DEFAULT 0,
    total_read_seconds  BIGINT DEFAULT 0,
    email_verified_at   TIMESTAMPTZ,
    phone_verified_at   TIMESTAMPTZ,
    last_login_at       TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,
    CONSTRAINT chk_email_or_phone CHECK (email IS NOT NULL OR phone IS NOT NULL)
);

CREATE INDEX idx_users_email ON users(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_phone ON users(phone) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_username ON users(username) WHERE deleted_at IS NULL;

-- User devices
CREATE TABLE user_devices (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_type     VARCHAR(20) NOT NULL,
    device_name     VARCHAR(100),
    device_id       VARCHAR(255),
    push_token      VARCHAR(500),
    last_active_at  TIMESTAMPTZ DEFAULT NOW(),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, device_id)
);

CREATE INDEX idx_user_devices_user ON user_devices(user_id);

-- User reading settings
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

-- Categories
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

-- Novels
CREATE TABLE novels (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title           VARCHAR(200) NOT NULL,
    author_name     VARCHAR(100) NOT NULL,
    author_id       UUID REFERENCES users(id),
    cover_url       VARCHAR(500),
    description     TEXT,
    status          VARCHAR(20) DEFAULT 'ongoing',
    language        VARCHAR(10) DEFAULT 'zh-TW',
    total_words     BIGINT DEFAULT 0,
    total_chapters  INT DEFAULT 0,
    view_count      BIGINT DEFAULT 0,
    favorite_count  INT DEFAULT 0,
    review_count    INT DEFAULT 0,
    rating_sum      DECIMAL(10,1) DEFAULT 0,
    rating_count    INT DEFAULT 0,
    avg_rating      DECIMAL(3,2) DEFAULT 0,
    is_published    BOOLEAN DEFAULT FALSE,
    is_featured     BOOLEAN DEFAULT FALSE,
    latest_chapter_id    UUID,
    latest_chapter_title VARCHAR(200),
    latest_chapter_at    TIMESTAMPTZ,
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

ALTER TABLE novels ADD COLUMN search_vector tsvector;
CREATE INDEX idx_novels_search ON novels USING GIN(search_vector);

-- Novel-category and tag relations
CREATE TABLE novel_categories (
    novel_id    UUID NOT NULL REFERENCES novels(id) ON DELETE CASCADE,
    category_id INT NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    PRIMARY KEY (novel_id, category_id)
);

CREATE TABLE tags (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(30) UNIQUE NOT NULL,
    usage_count INT DEFAULT 0,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE novel_tags (
    novel_id    UUID NOT NULL REFERENCES novels(id) ON DELETE CASCADE,
    tag_id      INT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (novel_id, tag_id)
);

-- Volumes and chapters
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

-- Bookshelf
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

-- Reading progress
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

-- Reading history
CREATE TABLE reading_history (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    novel_id    UUID NOT NULL REFERENCES novels(id) ON DELETE CASCADE,
    chapter_id  UUID NOT NULL REFERENCES chapters(id),
    read_at     TIMESTAMPTZ DEFAULT NOW(),
    duration    INT DEFAULT 0
);

CREATE INDEX idx_reading_history_user ON reading_history(user_id, read_at DESC);

-- Bookmarks
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

-- Reviews
CREATE TABLE reviews (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    novel_id    UUID NOT NULL REFERENCES novels(id) ON DELETE CASCADE,
    title       VARCHAR(200) NOT NULL,
    content     TEXT NOT NULL,
    rating      DECIMAL(2,1) NOT NULL CHECK (rating >= 0.5 AND rating <= 5.0),
    like_count  INT DEFAULT 0,
    status      VARCHAR(20) DEFAULT 'approved',
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, novel_id)
);

CREATE INDEX idx_reviews_novel ON reviews(novel_id, created_at DESC);

-- Comments
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

-- Likes
CREATE TABLE likes (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    target_type VARCHAR(20) NOT NULL,
    target_id   UUID NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, target_type, target_id)
);

-- Reports
CREATE TABLE reports (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES users(id),
    target_type VARCHAR(20) NOT NULL,
    target_id   UUID NOT NULL,
    reason      VARCHAR(50) NOT NULL,
    description TEXT,
    status      VARCHAR(20) DEFAULT 'pending',
    resolved_by UUID REFERENCES users(id),
    resolved_at TIMESTAMPTZ,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_reports_status ON reports(status, created_at DESC);

-- Translation cache
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

-- Banners
CREATE TABLE banners (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title       VARCHAR(200) NOT NULL,
    image_url   VARCHAR(500) NOT NULL,
    link_type   VARCHAR(20),
    link_value  VARCHAR(500),
    sort_order  INT DEFAULT 0,
    is_active   BOOLEAN DEFAULT TRUE,
    start_at    TIMESTAMPTZ,
    end_at      TIMESTAMPTZ,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Search keywords
CREATE TABLE search_keywords (
    id           SERIAL PRIMARY KEY,
    keyword      VARCHAR(100) UNIQUE NOT NULL,
    search_count BIGINT DEFAULT 1,
    last_searched TIMESTAMPTZ DEFAULT NOW(),
    is_hot       BOOLEAN DEFAULT FALSE
);

-- Admin logs
CREATE TABLE admin_logs (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id    UUID NOT NULL REFERENCES users(id),
    action      VARCHAR(50) NOT NULL,
    target_type VARCHAR(50),
    target_id   VARCHAR(100),
    detail      JSONB,
    ip_address  INET,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_admin_logs_admin ON admin_logs(admin_id, created_at DESC);
