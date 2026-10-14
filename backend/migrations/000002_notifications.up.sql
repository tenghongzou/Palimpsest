-- In-app notifications (the server also creates this table through GORM AutoMigrate)
CREATE TABLE notifications (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type        VARCHAR(30) NOT NULL,               -- chapter_update, comment_reply, system
    title       VARCHAR(200) NOT NULL,
    body        TEXT,
    novel_id    UUID,
    chapter_id  UUID,
    comment_id  UUID,
    actor_id    UUID,
    read_at     TIMESTAMPTZ,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_notifications_user ON notifications(user_id, created_at DESC);
CREATE INDEX idx_notifications_unread ON notifications(user_id) WHERE read_at IS NULL;
