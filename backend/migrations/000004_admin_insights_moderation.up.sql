-- Dashboard trends and content moderation (the server also creates these
-- through GORM AutoMigrate)

-- Daily activity series scan these columns by time range
CREATE INDEX IF NOT EXISTS idx_reading_history_read_at ON reading_history(read_at);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);
CREATE INDEX IF NOT EXISTS idx_reviews_created_at ON reviews(created_at);
CREATE INDEX IF NOT EXISTS idx_comments_created_at ON comments(created_at);
CREATE INDEX IF NOT EXISTS idx_bookshelf_items_added_at ON bookshelf_items(added_at);

-- What automated moderation found: {score, flags: [{code, detail}], ai_checked, checked_at}
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS moderation JSONB;
ALTER TABLE comments ADD COLUMN IF NOT EXISTS moderation JSONB;

-- The pending queue (content held for an admin), oldest first
CREATE INDEX IF NOT EXISTS idx_reviews_pending ON reviews(created_at) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_comments_pending ON comments(created_at) WHERE status = 'pending';

-- Words and phrases checked in reviews and comments. normalized is the
-- matching form (NFKC, lower case, Simplified characters, no punctuation).
CREATE TABLE IF NOT EXISTS moderation_terms (
    id          SERIAL PRIMARY KEY,
    term        VARCHAR(50) NOT NULL,
    normalized  VARCHAR(200) NOT NULL,
    severity    VARCHAR(10) NOT NULL,               -- block, flag
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_moderation_terms_normalized ON moderation_terms(normalized);
