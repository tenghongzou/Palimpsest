// Package testutil provides database fixtures for integration tests.
package testutil

import (
	"fmt"
	"net/url"
	"os"
	"strings"
	"testing"

	"github.com/google/uuid"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// DB returns a migrated database in a schema of its own, dropped when the
// test ends. It needs TEST_DATABASE_URL (a postgres:// URL) and skips the
// test when that is not set, so unit test runs stay self-contained.
func DB(t *testing.T) *gorm.DB {
	t.Helper()
	raw := os.Getenv("TEST_DATABASE_URL")
	if raw == "" {
		t.Skip("TEST_DATABASE_URL not set; skipping database test")
	}
	u, err := url.Parse(raw)
	if err != nil {
		t.Fatalf("parse TEST_DATABASE_URL: %v", err)
	}

	admin, err := gorm.Open(postgres.Open(raw), &gorm.Config{Logger: logger.Discard})
	if err != nil {
		t.Fatalf("connect test database: %v", err)
	}
	schema := "test_" + strings.ReplaceAll(uuid.NewString(), "-", "")[:12]
	if err := admin.Exec("CREATE SCHEMA " + schema).Error; err != nil {
		t.Fatalf("create schema: %v", err)
	}

	q := u.Query()
	q.Set("search_path", schema)
	u.RawQuery = q.Encode()
	db, err := gorm.Open(postgres.Open(u.String()), &gorm.Config{Logger: logger.Discard})
	if err != nil {
		t.Fatalf("connect test schema: %v", err)
	}
	t.Cleanup(func() {
		if sqlDB, err := db.DB(); err == nil {
			sqlDB.Close()
		}
		admin.Exec("DROP SCHEMA " + schema + " CASCADE")
		if sqlDB, err := admin.DB(); err == nil {
			sqlDB.Close()
		}
	})

	if err := db.AutoMigrate(model.All()...); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	return db
}

// User creates an active reader whose password is "password123".
func User(t *testing.T, db *gorm.DB, role string) *model.User {
	t.Helper()
	hash, _ := bcrypt.GenerateFromPassword([]byte("password123"), bcrypt.MinCost)
	name := "u" + strings.ReplaceAll(uuid.NewString(), "-", "")[:10]
	email := name + "@example.com"
	if role == "" {
		role = "reader"
	}
	u := &model.User{Username: name, Email: &email, PasswordHash: string(hash), Nickname: name, Role: role, Status: "active"}
	if err := db.Create(u).Error; err != nil {
		t.Fatalf("create user: %v", err)
	}
	return u
}

// Novel creates a published novel with n published chapters numbered from 1.
func Novel(t *testing.T, db *gorm.DB, n int) (*model.Novel, []model.Chapter) {
	t.Helper()
	novel := &model.Novel{Title: "測試小說", AuthorName: "作者", IsPublished: true}
	if err := db.Create(novel).Error; err != nil {
		t.Fatalf("create novel: %v", err)
	}
	chapters := make([]model.Chapter, n)
	for i := range chapters {
		chapters[i] = model.Chapter{
			NovelID: novel.ID, Title: fmt.Sprintf("第%d章", i+1), ChapterNumber: i + 1,
			Content: fmt.Sprintf("第%d章的內容", i+1), IsPublished: true,
		}
	}
	if n > 0 {
		if err := db.Create(&chapters).Error; err != nil {
			t.Fatalf("create chapters: %v", err)
		}
	}
	return novel, chapters
}
