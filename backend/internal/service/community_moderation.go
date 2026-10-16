package service

import (
	"encoding/json"
	"errors"
	"log"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/pkg/moderation"
	"gorm.io/gorm"
)

// Moderation queues.
const (
	QueuePending = "pending"
	QueueFlagged = "flagged"
)

// jsonbValue renders a moderation result for a map update, where GORM does
// not apply the field's serializer.
func jsonbValue(r *model.ModerationResult) (interface{}, error) {
	if r == nil {
		return gorm.Expr("NULL"), nil
	}
	b, err := json.Marshal(r)
	if err != nil {
		return nil, err
	}
	return gorm.Expr("?::jsonb", string(b)), nil
}

// markReviewed is the update recording an admin decision in a moderation
// column; content without moderation results stays without.
func markReviewed(at time.Time) interface{} {
	return gorm.Expr("CASE WHEN moderation IS NULL THEN NULL ELSE jsonb_set(moderation, '{reviewed_at}', to_jsonb(?::text)) END",
		at.Format(time.RFC3339Nano))
}

// reviewWithAI starts the background AI review of content just saved with
// status. The verdict is recorded with the rule findings; a confident one
// takes published content back to pending.
func (s *CommunityService) reviewWithAI(kind string, id uuid.UUID, text, status string) {
	if !s.moderation.AIEnabled() {
		return
	}
	s.moderation.ReviewAsync(text, func(v *moderation.AIVerdict) {
		if err := s.applyAIVerdict(kind, id, text, status, v); err != nil {
			log.Printf("moderation: failed to record AI review of %s %s: %v", kind, id, err)
		}
	})
}

// applyAIVerdict merges a verdict into a review or comment, unless the
// content changed or an admin moderated it since it was checked.
func (s *CommunityService) applyAIVerdict(kind string, id uuid.UUID, text, status string, v *moderation.AIVerdict) error {
	var current struct {
		NovelID    uuid.UUID
		Title      string
		Content    string
		Status     string
		Moderation *string
	}
	table := "comments"
	columns := "content, status, moderation"
	if kind == model.LikeTargetReview {
		table, columns = "reviews", "novel_id, title, content, status, moderation"
	}
	q := s.db.Table(table).Select(columns).Where("id = ?", id)
	if table == "comments" {
		q = q.Where("deleted_at IS NULL")
	}
	res := q.Limit(1).Scan(&current)
	if res.Error != nil {
		return res.Error
	}
	checked := current.Content
	if kind == model.LikeTargetReview {
		checked = reviewText(current.Title, current.Content)
	}
	if res.RowsAffected == 0 || checked != text || current.Status != status {
		return nil
	}

	var previous *model.ModerationResult
	if current.Moderation != nil {
		previous = &model.ModerationResult{}
		if err := json.Unmarshal([]byte(*current.Moderation), previous); err != nil {
			previous = nil
		}
	}
	merged := moderation.MergeAI(previous, v, s.moderation.now())
	value, err := jsonbValue(merged)
	if err != nil {
		return err
	}
	updates := map[string]interface{}{"moderation": value}
	// An admin's decision stands.
	hold := status == StatusApproved && v.Score >= AIHoldScore && (previous == nil || previous.ReviewedAt == nil)
	if hold {
		updates["status"] = StatusPending
	}
	res = s.db.Table(table).Where("id = ? AND status = ?", id, status).Updates(updates)
	if res.Error != nil || res.RowsAffected == 0 {
		return res.Error
	}
	if hold && kind == model.LikeTargetReview {
		return s.refreshRating(current.NovelID)
	}
	return nil
}

// SetCommentStatus moderates a comment and marks it as reviewed by an admin,
// which takes it out of the flagged queue. Approving a reply that was held
// when it was posted tells the parent's author about it.
func (s *CommunityService) SetCommentStatus(id uuid.UUID, status string) (*model.Comment, error) {
	var comment model.Comment
	err := s.db.First(&comment, "id = ?", id).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	previous := comment.Status
	reviewedAt := time.Now().UTC()
	if err := s.db.Model(&model.Comment{}).Where("id = ?", id).
		Updates(map[string]interface{}{"status": status, "moderation": markReviewed(reviewedAt)}).Error; err != nil {
		return nil, err
	}
	comment.Status = status
	if comment.Moderation != nil {
		comment.Moderation.ReviewedAt = &reviewedAt
	}
	// Replies published on creation were announced then; only replies held
	// from the start are announced on approval.
	if previous == StatusPending && status == StatusApproved && comment.ParentID != nil && moderation.RuleHeld(comment.Moderation) {
		var parent model.Comment
		if err := s.db.First(&parent, "id = ?", *comment.ParentID).Error; err == nil {
			s.notifyReply(&comment, &parent)
		}
	}
	return &comment, nil
}

// ModerationItem is a review or comment as the moderation queue shows it.
type ModerationItem struct {
	Type       string                  `json:"type"`
	ID         uuid.UUID               `json:"id"`
	Title      string                  `json:"title,omitempty"`
	Content    string                  `json:"content"`
	Rating     *float64                `json:"rating,omitempty"`
	Status     string                  `json:"status"`
	Moderation *model.ModerationResult `json:"moderation,omitempty"`
	User       *model.UserBrief        `json:"user"`
	Novel      *model.NovelBrief       `json:"novel,omitempty"`
	Chapter    *model.ChapterRef       `json:"chapter,omitempty"`
	CreatedAt  time.Time               `json:"created_at"`
}

type queueRef struct {
	Type string
	ID   uuid.UUID
}

// ModerationQueue lists held content (QueuePending, oldest first) or
// published content with moderation flags (QueueFlagged, highest score
// first, until an admin has decided on it). kind limits it to "review" or "comment"; empty lists both.
func (s *CommunityService) ModerationQueue(queue, kind string, page, pageSize int) ([]ModerationItem, int64, error) {
	cond, order := "status = 'pending'", "created_at ASC, id ASC"
	if queue == QueueFlagged {
		// An array containing any object: at least one flag.
		cond = "status = 'approved' AND moderation->'flags' @> '[{}]'::jsonb AND moderation->'reviewed_at' IS NULL"
		order = "score DESC, created_at DESC, id ASC"
	}
	var parts []string
	if kind != model.LikeTargetComment {
		parts = append(parts, "SELECT 'review' AS type, id, created_at, COALESCE((moderation->>'score')::float8, 0) AS score FROM reviews WHERE "+cond)
	}
	if kind != model.LikeTargetReview {
		parts = append(parts, "SELECT 'comment' AS type, id, created_at, COALESCE((moderation->>'score')::float8, 0) AS score FROM comments WHERE deleted_at IS NULL AND "+cond)
	}
	union := strings.Join(parts, " UNION ALL ")

	var total int64
	if err := s.db.Raw("SELECT COUNT(*) FROM (" + union + ") q").Scan(&total).Error; err != nil {
		return nil, 0, err
	}
	var refs []queueRef
	err := s.db.Raw("SELECT type, id FROM ("+union+") q ORDER BY "+order+" LIMIT ? OFFSET ?",
		pageSize, offset(page, pageSize)).Scan(&refs).Error
	if err != nil {
		return nil, 0, err
	}
	items, err := s.moderationItems(refs)
	return items, total, err
}

// moderationItems loads queue entries in the order given; entries that no
// longer exist are skipped.
func (s *CommunityService) moderationItems(refs []queueRef) ([]ModerationItem, error) {
	var reviewIDs, commentIDs []uuid.UUID
	for _, r := range refs {
		if r.Type == model.LikeTargetReview {
			reviewIDs = append(reviewIDs, r.ID)
		} else {
			commentIDs = append(commentIDs, r.ID)
		}
	}
	byID := map[uuid.UUID]ModerationItem{}
	if len(reviewIDs) > 0 {
		var reviews []model.Review
		if err := withAuthor(s.db).Preload("Novel").Where("id IN ?", reviewIDs).Find(&reviews).Error; err != nil {
			return nil, err
		}
		for _, r := range reviews {
			rating := r.Rating
			byID[r.ID] = ModerationItem{
				Type: model.LikeTargetReview, ID: r.ID, Title: r.Title, Content: r.Content, Rating: &rating,
				Status: r.Status, Moderation: r.Moderation, User: r.User, Novel: r.Novel, CreatedAt: r.CreatedAt,
			}
		}
	}
	if len(commentIDs) > 0 {
		var comments []model.Comment
		if err := withAuthor(s.db).Where("id IN ?", commentIDs).Find(&comments).Error; err != nil {
			return nil, err
		}
		chapterIDs := make([]uuid.UUID, 0, len(comments))
		for _, c := range comments {
			chapterIDs = append(chapterIDs, c.ChapterID)
		}
		var chapters []struct {
			ID            uuid.UUID
			NovelID       uuid.UUID
			Title         string
			ChapterNumber int
			NovelTitle    string
		}
		err := s.db.Table("chapters AS ch").
			Select("ch.id, ch.novel_id, ch.title, ch.chapter_number, n.title AS novel_title").
			Joins("JOIN novels n ON n.id = ch.novel_id").
			Where("ch.id IN ?", chapterIDs).Scan(&chapters).Error
		if err != nil {
			return nil, err
		}
		type place struct {
			chapter model.ChapterRef
			novel   model.NovelBrief
		}
		where := map[uuid.UUID]place{}
		for _, ch := range chapters {
			where[ch.ID] = place{
				chapter: model.ChapterRef{ID: ch.ID, Title: ch.Title, ChapterNumber: ch.ChapterNumber},
				novel:   model.NovelBrief{ID: ch.NovelID, Title: ch.NovelTitle},
			}
		}
		for _, c := range comments {
			item := ModerationItem{
				Type: model.LikeTargetComment, ID: c.ID, Content: c.Content, Status: c.Status,
				Moderation: c.Moderation, User: c.User, CreatedAt: c.CreatedAt,
			}
			if p, ok := where[c.ChapterID]; ok {
				chapter, novel := p.chapter, p.novel
				item.Chapter, item.Novel = &chapter, &novel
			}
			byID[c.ID] = item
		}
	}
	items := make([]ModerationItem, 0, len(refs))
	for _, r := range refs {
		if item, ok := byID[r.ID]; ok {
			items = append(items, item)
		}
	}
	return items, nil
}

// Moderate decides on a review or comment. Reviews go through
// SetReviewStatus, so the novel's rating and caches follow.
func (s *CommunityService) Moderate(kind string, id uuid.UUID, status string) (*ModerationItem, error) {
	switch kind {
	case model.LikeTargetReview:
		if _, err := s.SetReviewStatus(id, status); err != nil {
			return nil, err
		}
	case model.LikeTargetComment:
		if _, err := s.SetCommentStatus(id, status); err != nil {
			return nil, err
		}
	default:
		return nil, ErrNotFound
	}
	items, err := s.moderationItems([]queueRef{{Type: kind, ID: id}})
	if err != nil {
		return nil, err
	}
	if len(items) == 0 {
		return nil, ErrNotFound
	}
	return &items[0], nil
}

// PendingModeration counts reviews and comments held for moderation.
func PendingModeration(db *gorm.DB) (int64, error) {
	var n int64
	err := db.Raw(`SELECT (SELECT COUNT(*) FROM reviews WHERE status = ?) +
		(SELECT COUNT(*) FROM comments WHERE status = ? AND deleted_at IS NULL)`, StatusPending, StatusPending).Scan(&n).Error
	return n, err
}
