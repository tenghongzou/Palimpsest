-- Values clients build a notification's text from in their UI language
-- (the server also adds this column through GORM AutoMigrate)
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS params JSONB;
