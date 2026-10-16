package service

import (
	"context"
	"errors"
	"fmt"
	"log"
	"strings"
	"sync"
	"time"

	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/pkg/moderation"
	"gorm.io/gorm"
)

// ErrInvalidTerm is returned for a moderation term with no letters or digits.
var ErrInvalidTerm = errors.New("invalid moderation term")

// AIHoldScore is the AI score at or above which published content is held
// for review after the fact.
const AIHoldScore = 0.85

// aiSlotWait bounds how long an AI review waits for a free slot before it
// is skipped.
const aiSlotWait = 30 * time.Second

// termsTTL bounds how stale the cached term list may be on other instances;
// changes made through this instance apply immediately.
const termsTTL = time.Minute

// AIReviewer gives an AI verdict on content.
type AIReviewer interface {
	Review(ctx context.Context, text string) (*moderation.AIVerdict, error)
}

// ModerationService checks reviews and comments against the moderation rules
// and terms, and runs the optional AI review in the background.
type ModerationService struct {
	db  *gorm.DB
	now func() time.Time

	mu       sync.Mutex
	terms    *moderation.TermSet
	loadedAt time.Time

	ai        AIReviewer
	aiTimeout time.Duration
	slots     chan struct{}
	pending   sync.WaitGroup
}

func NewModerationService(db *gorm.DB) *ModerationService {
	return &ModerationService{db: db, now: time.Now}
}

// WithAI enables AI review with at most concurrency calls in flight, each
// bounded by timeout.
func (s *ModerationService) WithAI(ai AIReviewer, concurrency int, timeout time.Duration) *ModerationService {
	if concurrency < 1 {
		concurrency = 1
	}
	s.ai, s.aiTimeout, s.slots = ai, timeout, make(chan struct{}, concurrency)
	return s
}

// AIEnabled reports whether AI review runs.
func (s *ModerationService) AIEnabled() bool {
	return s != nil && s.ai != nil
}

// termSet returns the cached terms, reloading them when stale. When the
// reload fails the previous list is kept.
func (s *ModerationService) termSet() *moderation.TermSet {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.terms != nil && s.now().Sub(s.loadedAt) < termsTTL {
		return s.terms
	}
	var rows []model.ModerationTerm
	if err := s.db.Find(&rows).Error; err != nil {
		log.Printf("moderation: failed to load terms: %v", err)
		if s.terms == nil {
			return &moderation.TermSet{}
		}
		return s.terms
	}
	terms := make([]moderation.Term, len(rows))
	for i, r := range rows {
		terms[i] = moderation.Term{Display: r.Term, Normalized: r.Normalized, Severity: r.Severity}
	}
	s.terms, s.loadedAt = moderation.NewTermSet(terms), s.now()
	return s.terms
}

func (s *ModerationService) invalidateTerms() {
	s.mu.Lock()
	s.terms = nil
	s.mu.Unlock()
}

// Check runs the rules over text and returns the result and the status the
// content should get: pending when held, approved otherwise.
func (s *ModerationService) Check(text string) (*model.ModerationResult, string) {
	result := moderation.Check(text, s.termSet(), s.now())
	if moderation.Held(result) {
		return result, model.ModerationPending
	}
	return result, model.ModerationApproved
}

// ReviewAsync runs the AI review of text in the background and hands a
// verdict to apply. It never blocks the caller; failures are logged.
func (s *ModerationService) ReviewAsync(text string, apply func(*moderation.AIVerdict)) {
	if !s.AIEnabled() {
		return
	}
	s.pending.Add(1)
	go func() {
		defer s.pending.Done()
		defer func() {
			if r := recover(); r != nil {
				log.Printf("moderation: AI review panicked: %v", r)
			}
		}()
		wait := time.NewTimer(aiSlotWait)
		defer wait.Stop()
		select {
		case s.slots <- struct{}{}:
			defer func() { <-s.slots }()
		case <-wait.C:
			log.Printf("moderation: AI review skipped, too many in flight")
			return
		}
		ctx, cancel := context.WithTimeout(context.Background(), s.aiTimeout)
		defer cancel()
		verdict, err := s.ai.Review(ctx, text)
		if err != nil {
			log.Printf("moderation: AI review failed: %v", err)
			return
		}
		apply(verdict)
	}()
}

// Wait blocks until background AI reviews finish (tests and shutdown).
func (s *ModerationService) Wait() {
	if s != nil {
		s.pending.Wait()
	}
}

// ------------------------------------------------------------------- terms

// ModerationTermInput adds a term.
type ModerationTermInput struct {
	Term     string `json:"term" binding:"required,min=1,max=50"`
	Severity string `json:"severity" binding:"required,oneof=block flag"`
}

// ListTerms returns all terms, newest first.
func (s *ModerationService) ListTerms() ([]model.ModerationTerm, error) {
	terms := []model.ModerationTerm{}
	err := s.db.Order("created_at DESC, id DESC").Find(&terms).Error
	return terms, err
}

// CreateTerm adds a term. A term equal to an existing one after
// normalization is ErrConflict; one with no letters or digits is ErrInvalidTerm.
func (s *ModerationService) CreateTerm(in ModerationTermInput) (*model.ModerationTerm, error) {
	display := strings.TrimSpace(in.Term)
	normalized, err := moderation.NormalizeTerm(display)
	if err != nil {
		return nil, ErrInvalidTerm
	}
	if in.Severity != model.SeverityBlock && in.Severity != model.SeverityFlag {
		return nil, fmt.Errorf("%w: severity", ErrInvalidTerm)
	}
	term := &model.ModerationTerm{Term: display, Normalized: normalized, Severity: in.Severity}
	if err := s.db.Create(term).Error; err != nil {
		if IsUniqueViolation(err) {
			return nil, ErrConflict
		}
		return nil, err
	}
	s.invalidateTerms()
	return term, nil
}

// DeleteTerm removes a term.
func (s *ModerationService) DeleteTerm(id int) error {
	res := s.db.Delete(&model.ModerationTerm{}, id)
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return ErrNotFound
	}
	s.invalidateTerms()
	return nil
}
