package service

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
)

type fakeTranslator struct {
	calls [][]string
}

func (f *fakeTranslator) Translate(_ context.Context, segments []string, from, to string) ([]string, error) {
	f.calls = append(f.calls, segments)
	out := make([]string, len(segments))
	for i, s := range segments {
		out[i] = to + ":" + s
	}
	return out, nil
}

func newTestTranslationService(tr *fakeTranslator, src *chapterSource) *TranslationService {
	s := &TranslationService{}
	if tr != nil {
		s.translator = tr
	}
	s.loadChapter = func(id uuid.UUID) (*chapterSource, error) {
		if src == nil || id != src.ID {
			return nil, ErrChapterNotFound
		}
		return src, nil
	}
	return s
}

func TestConvertUsesOpenCC(t *testing.T) {
	s := newTestTranslationService(nil, nil)
	got, err := s.Convert(&ConvertRequest{Text: "鬥破蒼穹", From: "zh-TW", To: "zh-CN"})
	if err != nil {
		t.Fatal(err)
	}
	if got != "斗破苍穹" {
		t.Errorf("got %q", got)
	}
}

func TestTranslateTextChineseDoesNotNeedProvider(t *testing.T) {
	s := newTestTranslationService(nil, nil)
	got, err := s.TranslateText(&TranslateRequest{Text: "斗气", From: "zh-CN", To: "zh-TW"})
	if err != nil {
		t.Fatal(err)
	}
	if got != "鬥氣" {
		t.Errorf("got %q", got)
	}
}

func TestTranslateTextWithoutProvider(t *testing.T) {
	s := newTestTranslationService(nil, nil)
	_, err := s.TranslateText(&TranslateRequest{Text: "鬥氣", From: "zh-TW", To: "en"})
	if !errors.Is(err, ErrTranslatorUnavailable) {
		t.Fatalf("expected ErrTranslatorUnavailable, got %v", err)
	}
}

func TestTranslateChapterPreservesParagraphs(t *testing.T) {
	tr := &fakeTranslator{}
	src := &chapterSource{
		ID:        uuid.New(),
		Title:     "第一章",
		Content:   "第一段\n\n第二段\n",
		Language:  "zh-TW",
		UpdatedAt: time.Now(),
	}
	s := newTestTranslationService(tr, src)

	got, err := s.TranslateChapter(&TranslateChapterRequest{ChapterID: src.ID.String(), TargetLang: "en"})
	if err != nil {
		t.Fatal(err)
	}
	if got.TranslatedContent != "en:第一段\n\nen:第二段\n" {
		t.Errorf("content = %q", got.TranslatedContent)
	}
	if got.TranslatedTitle != "en:第一章" || got.OriginalLang != "zh-TW" || got.IsCached {
		t.Errorf("unexpected result %+v", got)
	}
	if len(tr.calls) != 1 || len(tr.calls[0]) != 3 {
		t.Errorf("expected one call with 3 non-empty segments, got %v", tr.calls)
	}
}

func TestTranslateChapterChineseConversion(t *testing.T) {
	src := &chapterSource{ID: uuid.New(), Title: "第一章", Content: "鬥氣大陸", Language: "zh-TW"}
	s := newTestTranslationService(nil, src)

	got, err := s.TranslateChapter(&TranslateChapterRequest{ChapterID: src.ID.String(), TargetLang: "zh-CN"})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(got.TranslatedContent, "斗气") {
		t.Errorf("content = %q", got.TranslatedContent)
	}
}

func TestTranslateChapterNotFound(t *testing.T) {
	s := newTestTranslationService(&fakeTranslator{}, nil)
	_, err := s.TranslateChapter(&TranslateChapterRequest{ChapterID: uuid.NewString(), TargetLang: "en"})
	if !errors.Is(err, ErrChapterNotFound) {
		t.Fatalf("expected ErrChapterNotFound, got %v", err)
	}
}
