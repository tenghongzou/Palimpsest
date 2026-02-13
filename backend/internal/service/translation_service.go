package service

import (
	"context"
	"crypto/sha256"
	"fmt"
	"time"

	"github.com/tenghongzou/palimpsest/backend/internal/repository"
	"gorm.io/gorm"
)

type TranslationService struct {
	cacheRepo *repository.CacheRepository
	db        *gorm.DB
}

func NewTranslationService(cacheRepo *repository.CacheRepository, db *gorm.DB) *TranslationService {
	return &TranslationService{cacheRepo: cacheRepo, db: db}
}

type ConvertRequest struct {
	Text      string `json:"text" binding:"required"`
	Direction string `json:"direction" binding:"required,oneof=tw2cn cn2tw"` // tw2cn or cn2tw
}

type TranslateRequest struct {
	Text       string `json:"text" binding:"required"`
	TargetLang string `json:"target_lang" binding:"required"` // en, zh-TW, zh-CN
}

type TranslateChapterRequest struct {
	ChapterID  string `json:"chapter_id" binding:"required"`
	TargetLang string `json:"target_lang" binding:"required"`
}

// Convert performs Traditional/Simplified Chinese conversion.
// In production, this would use OpenCC library via CGo or an external service.
func (s *TranslationService) Convert(req *ConvertRequest) (string, error) {
	ctx := context.Background()
	cacheKey := fmt.Sprintf("palimpsest:translation:convert:%s:%x",
		req.Direction, sha256.Sum256([]byte(req.Text)))

	// Check cache
	if cached, err := s.cacheRepo.Get(ctx, cacheKey); err == nil && cached != "" {
		return cached, nil
	}

	// Placeholder: In production, integrate OpenCC here
	// For now, return the original text with a note
	result := req.Text // OpenCC would transform this

	// Cache for 7 days
	_ = s.cacheRepo.Set(ctx, cacheKey, result, 7*24*time.Hour)

	return result, nil
}

// TranslateText translates text to the target language.
// In production, this would call Google Cloud Translation API.
func (s *TranslationService) TranslateText(req *TranslateRequest) (string, error) {
	ctx := context.Background()
	cacheKey := fmt.Sprintf("palimpsest:translation:text:%s:%x",
		req.TargetLang, sha256.Sum256([]byte(req.Text)))

	if cached, err := s.cacheRepo.Get(ctx, cacheKey); err == nil && cached != "" {
		return cached, nil
	}

	// Placeholder: In production, call Google Translate API
	result := req.Text

	_ = s.cacheRepo.Set(ctx, cacheKey, result, 7*24*time.Hour)

	return result, nil
}

// TranslateChapter translates an entire chapter.
func (s *TranslationService) TranslateChapter(req *TranslateChapterRequest) (string, error) {
	ctx := context.Background()
	cacheKey := fmt.Sprintf("palimpsest:translation:chapter:%s:%s", req.ChapterID, req.TargetLang)

	if cached, err := s.cacheRepo.Get(ctx, cacheKey); err == nil && cached != "" {
		return cached, nil
	}

	// Fetch chapter content from DB
	var content string
	err := s.db.Raw("SELECT content FROM chapters WHERE id = ?", req.ChapterID).Scan(&content).Error
	if err != nil {
		return "", err
	}

	// Placeholder: translate the content
	translated := content

	_ = s.cacheRepo.Set(ctx, cacheKey, translated, 7*24*time.Hour)

	return translated, nil
}
