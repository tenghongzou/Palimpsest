package service

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/tenghongzou/palimpsest/backend/internal/pkg/translate"
	"github.com/tenghongzou/palimpsest/backend/internal/repository"
	"gorm.io/gorm"
)

const translationCacheTTL = 7 * 24 * time.Hour

var (
	// ErrTranslatorUnavailable means a non-Chinese pair was requested but no
	// machine translation provider is configured.
	ErrTranslatorUnavailable = errors.New("machine translation is not configured")
	ErrChapterNotFound       = errors.New("chapter not found")
)

type TranslationService struct {
	cacheRepo   *repository.CacheRepository
	translator  translate.MachineTranslator
	loadChapter func(id uuid.UUID) (*chapterSource, error)
}

// chapterSource is the data needed to translate a chapter.
type chapterSource struct {
	ID        uuid.UUID
	Title     string
	Content   string
	Language  string
	UpdatedAt time.Time
}

// NewTranslationService creates the service. translator may be nil, in which
// case only zh-TW <-> zh-CN conversion is available.
func NewTranslationService(cacheRepo *repository.CacheRepository, db *gorm.DB, translator translate.MachineTranslator) *TranslationService {
	s := &TranslationService{cacheRepo: cacheRepo, translator: translator}
	s.loadChapter = func(id uuid.UUID) (*chapterSource, error) {
		var src chapterSource
		err := db.Raw(`SELECT c.id, c.title, c.content, n.language, c.updated_at
			FROM chapters c JOIN novels n ON n.id = c.novel_id
			WHERE c.id = ? AND c.is_published = true AND n.deleted_at IS NULL`, id).Scan(&src).Error
		if err != nil {
			return nil, err
		}
		if src.ID == uuid.Nil {
			return nil, ErrChapterNotFound
		}
		return &src, nil
	}
	return s
}

type ConvertRequest struct {
	Text string `json:"text" binding:"required,max=50000"`
	From string `json:"from" binding:"required,oneof=zh-TW zh-CN"`
	To   string `json:"to" binding:"required,oneof=zh-TW zh-CN"`
}

type TranslateRequest struct {
	Text string `json:"text" binding:"required,max=5000"`
	From string `json:"from" binding:"omitempty,oneof=zh-TW zh-CN en"`
	To   string `json:"to" binding:"required,oneof=zh-TW zh-CN en"`
}

type TranslateChapterRequest struct {
	ChapterID  string `json:"chapter_id" binding:"required,uuid"`
	TargetLang string `json:"target_lang" binding:"required,oneof=zh-TW zh-CN en"`
}

type ChapterTranslation struct {
	ChapterID         string `json:"chapter_id"`
	OriginalLang      string `json:"original_lang"`
	TargetLang        string `json:"target_lang"`
	TranslatedTitle   string `json:"translated_title"`
	TranslatedContent string `json:"translated_content"`
	IsCached          bool   `json:"is_cached"`
}

// Convert performs Traditional/Simplified Chinese conversion with OpenCC.
func (s *TranslationService) Convert(req *ConvertRequest) (string, error) {
	ctx := context.Background()
	cacheKey := fmt.Sprintf("palimpsest:translation:convert:%s:%s:%x",
		req.From, req.To, sha256.Sum256([]byte(req.Text)))

	if cached, ok := s.cacheGet(ctx, cacheKey); ok {
		return cached, nil
	}

	result, err := translate.ConvertChinese(req.Text, req.From, req.To)
	if err != nil {
		return "", err
	}
	s.cacheSet(ctx, cacheKey, result)
	return result, nil
}

// TranslateText translates a short text to the target language.
func (s *TranslationService) TranslateText(req *TranslateRequest) (string, error) {
	ctx := context.Background()
	cacheKey := fmt.Sprintf("palimpsest:translation:text:%s:%s:%x",
		req.From, req.To, sha256.Sum256([]byte(req.Text)))

	if cached, ok := s.cacheGet(ctx, cacheKey); ok {
		return cached, nil
	}

	out, err := s.translateSegments(ctx, []string{req.Text}, req.From, req.To)
	if err != nil {
		return "", err
	}
	s.cacheSet(ctx, cacheKey, out[0])
	return out[0], nil
}

// TranslateChapter translates a chapter's title and content paragraph by
// paragraph. Results are cached per chapter revision.
func (s *TranslationService) TranslateChapter(req *TranslateChapterRequest) (*ChapterTranslation, error) {
	ctx := context.Background()
	id, err := uuid.Parse(req.ChapterID)
	if err != nil {
		return nil, ErrChapterNotFound
	}

	src, err := s.loadChapter(id)
	if err != nil {
		return nil, err
	}

	result := &ChapterTranslation{
		ChapterID:    src.ID.String(),
		OriginalLang: src.Language,
		TargetLang:   req.TargetLang,
	}

	// The revision timestamp in the key invalidates the cache when the chapter is edited.
	cacheKey := fmt.Sprintf("palimpsest:translation:chapter:%s:%s:%d",
		src.ID, req.TargetLang, src.UpdatedAt.Unix())
	if cached, ok := s.cacheGet(ctx, cacheKey); ok {
		if json.Unmarshal([]byte(cached), result) == nil {
			result.IsCached = true
			return result, nil
		}
	}

	lines := strings.Split(src.Content, "\n")
	var segments []string
	for _, line := range lines {
		if strings.TrimSpace(line) != "" {
			segments = append(segments, line)
		}
	}
	segments = append(segments, src.Title)

	translated, err := s.translateSegments(ctx, segments, src.Language, req.TargetLang)
	if err != nil {
		return nil, err
	}

	// Put translated paragraphs back in place, keeping blank lines.
	next := 0
	for i, line := range lines {
		if strings.TrimSpace(line) != "" {
			lines[i] = translated[next]
			next++
		}
	}
	result.TranslatedTitle = translated[len(translated)-1]
	result.TranslatedContent = strings.Join(lines, "\n")

	if data, err := json.Marshal(result); err == nil {
		s.cacheSet(ctx, cacheKey, string(data))
	}
	return result, nil
}

// translateSegments routes a language pair to OpenCC or the machine translator.
func (s *TranslationService) translateSegments(ctx context.Context, segments []string, from, to string) ([]string, error) {
	if from == to {
		return segments, nil
	}
	if translate.IsChinese(from) && translate.IsChinese(to) {
		out := make([]string, len(segments))
		for i, seg := range segments {
			converted, err := translate.ConvertChinese(seg, from, to)
			if err != nil {
				return nil, err
			}
			out[i] = converted
		}
		return out, nil
	}
	if s.translator == nil {
		return nil, ErrTranslatorUnavailable
	}
	return s.translator.Translate(ctx, segments, from, to)
}

func (s *TranslationService) cacheGet(ctx context.Context, key string) (string, bool) {
	if s.cacheRepo == nil {
		return "", false
	}
	v, err := s.cacheRepo.Get(ctx, key)
	return v, err == nil && v != ""
}

func (s *TranslationService) cacheSet(ctx context.Context, key, value string) {
	if s.cacheRepo == nil {
		return
	}
	_ = s.cacheRepo.Set(ctx, key, value, translationCacheTTL)
}
