package service

import (
	"errors"
	"log"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// Moderation statuses of reviews and comments. Only approved ones are public.
const (
	StatusApproved = "approved"
	StatusRejected = "rejected"
	StatusHidden   = "hidden"
)

type CommunityService struct {
	db *gorm.DB
	// novelChanged is told when a novel's rating changes, to drop caches.
	novelChanged func(novelID uuid.UUID)
	// notifications, when set, tells authors about replies.
	notifications *NotificationService
}

func NewCommunityService(db *gorm.DB, novelChanged func(novelID uuid.UUID)) *CommunityService {
	return &CommunityService{db: db, novelChanged: novelChanged}
}

// WithNotifications makes replies notify the author they answer.
func (s *CommunityService) WithNotifications(n *NotificationService) *CommunityService {
	s.notifications = n
	return s
}

func withAuthor(db *gorm.DB) *gorm.DB {
	return db.Preload("User")
}

// IsUniqueViolation reports a Postgres unique constraint violation.
func IsUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}

// ------------------------------------------------------------------ reviews

type ReviewInput struct {
	Title   string  `json:"title" binding:"required,max=200"`
	Content string  `json:"content" binding:"required,max=10000"`
	Rating  float64 `json:"rating" binding:"required,min=0.5,max=5"`
}

func normalizeRating(r float64) float64 {
	// Ratings are half stars.
	return float64(int(r*2+0.5)) / 2
}

func (s *CommunityService) ListReviews(novelID uuid.UUID, viewer *uuid.UUID, sortBy string, page, pageSize int) ([]model.Review, int64, error) {
	reviews := []model.Review{}
	var total int64
	q := s.db.Model(&model.Review{}).Where("novel_id = ? AND status = ?", novelID, StatusApproved)
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	order := "created_at DESC"
	if sortBy == "popular" {
		order = "like_count DESC, created_at DESC"
	}
	err := withAuthor(q).Order(order).Offset(offset(page, pageSize)).Limit(pageSize).Find(&reviews).Error
	if err != nil {
		return nil, 0, err
	}
	ids := make([]uuid.UUID, len(reviews))
	for i := range reviews {
		ids[i] = reviews[i].ID
	}
	liked, err := s.likedSet(viewer, model.LikeTargetReview, ids)
	if err != nil {
		return nil, 0, err
	}
	for i := range reviews {
		reviews[i].LikedByMe = liked[reviews[i].ID]
	}
	return reviews, total, nil
}

// CreateReview adds the user's review of a published novel; each user may
// review a novel once (ErrConflict).
func (s *CommunityService) CreateReview(userID, novelID uuid.UUID, in ReviewInput) (*model.Review, error) {
	var count int64
	if err := s.db.Model(&model.Novel{}).Where("id = ? AND is_published", novelID).Count(&count).Error; err != nil {
		return nil, err
	}
	if count == 0 {
		return nil, ErrNotFound
	}
	review := &model.Review{
		UserID: userID, NovelID: novelID, Title: strings.TrimSpace(in.Title),
		Content: strings.TrimSpace(in.Content), Rating: normalizeRating(in.Rating), Status: StatusApproved,
	}
	if err := s.db.Create(review).Error; err != nil {
		if IsUniqueViolation(err) {
			return nil, ErrConflict
		}
		return nil, err
	}
	if err := s.refreshRating(novelID); err != nil {
		return nil, err
	}
	return s.getReview(review.ID)
}

func (s *CommunityService) getReview(id uuid.UUID) (*model.Review, error) {
	var review model.Review
	err := withAuthor(s.db).First(&review, "id = ?", id).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	return &review, err
}

// ownReview loads a review the user may change: their own, or any for admins.
func (s *CommunityService) ownReview(userID uuid.UUID, isAdmin bool, id uuid.UUID) (*model.Review, error) {
	review, err := s.getReview(id)
	if err != nil {
		return nil, err
	}
	if review.UserID != userID && !isAdmin {
		return nil, ErrForbidden
	}
	return review, nil
}

func (s *CommunityService) UpdateReview(userID, id uuid.UUID, in ReviewInput) (*model.Review, error) {
	review, err := s.ownReview(userID, false, id)
	if err != nil {
		return nil, err
	}
	err = s.db.Model(&model.Review{}).Where("id = ?", id).Updates(map[string]interface{}{
		"title": strings.TrimSpace(in.Title), "content": strings.TrimSpace(in.Content), "rating": normalizeRating(in.Rating),
	}).Error
	if err != nil {
		return nil, err
	}
	if err := s.refreshRating(review.NovelID); err != nil {
		return nil, err
	}
	return s.getReview(id)
}

func (s *CommunityService) DeleteReview(userID uuid.UUID, isAdmin bool, id uuid.UUID) error {
	review, err := s.ownReview(userID, isAdmin, id)
	if err != nil {
		return err
	}
	err = s.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Where("target_type = ? AND target_id = ?", model.LikeTargetReview, id).Delete(&model.Like{}).Error; err != nil {
			return err
		}
		return tx.Delete(&model.Review{}, "id = ?", id).Error
	})
	if err != nil {
		return err
	}
	return s.refreshRating(review.NovelID)
}

// SetReviewStatus moderates a review and updates the novel's rating.
func (s *CommunityService) SetReviewStatus(id uuid.UUID, status string) (*model.Review, error) {
	review, err := s.getReview(id)
	if err != nil {
		return nil, err
	}
	// Update by id: saving the loaded review would also try to save its author.
	if err := s.db.Model(&model.Review{}).Where("id = ?", id).Update("status", status).Error; err != nil {
		return nil, err
	}
	review.Status = status
	if err := s.refreshRating(review.NovelID); err != nil {
		return nil, err
	}
	return review, nil
}

// AdminListReviews lists reviews for moderation, optionally by status.
func (s *CommunityService) AdminListReviews(status string, page, pageSize int) ([]model.Review, int64, error) {
	reviews := []model.Review{}
	var total int64
	q := s.db.Model(&model.Review{})
	if status != "" {
		q = q.Where("status = ?", status)
	}
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	err := withAuthor(q).Preload("Novel").Order("created_at DESC").
		Offset(offset(page, pageSize)).Limit(pageSize).Find(&reviews).Error
	return reviews, total, err
}

// refreshRating recomputes a novel's average rating and review count from
// its approved reviews.
func (s *CommunityService) refreshRating(novelID uuid.UUID) error {
	err := s.db.Exec(`
		UPDATE novels SET
			avg_rating = COALESCE((SELECT ROUND(AVG(rating), 2) FROM reviews WHERE novel_id = ? AND status = ?), 0),
			review_count = (SELECT COUNT(*) FROM reviews WHERE novel_id = ? AND status = ?)
		WHERE id = ?`, novelID, StatusApproved, novelID, StatusApproved, novelID).Error
	if err == nil && s.novelChanged != nil {
		s.novelChanged(novelID)
	}
	return err
}

// ----------------------------------------------------------------- comments

type CommentInput struct {
	Content        string     `json:"content" binding:"required,max=2000"`
	ParentID       *uuid.UUID `json:"parent_id"`
	ParagraphIndex *int       `json:"paragraph_index" binding:"omitempty,min=0"`
}

// ListComments returns a page of a chapter's top-level comments with their replies.
func (s *CommunityService) ListComments(chapterID uuid.UUID, viewer *uuid.UUID, sortBy string, paragraph *int, page, pageSize int) ([]model.Comment, int64, error) {
	comments := []model.Comment{}
	var total int64
	q := s.db.Model(&model.Comment{}).Where("chapter_id = ? AND parent_id IS NULL AND status = ?", chapterID, StatusApproved)
	if paragraph != nil {
		q = q.Where("paragraph_index = ?", *paragraph)
	}
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	order := "created_at DESC"
	if sortBy == "popular" {
		order = "like_count DESC, created_at DESC"
	}
	err := withReplies(withAuthor(q)).
		Order(order).Offset(offset(page, pageSize)).Limit(pageSize).Find(&comments).Error
	if err != nil {
		return nil, 0, err
	}
	if err := s.markLiked(viewer, comments); err != nil {
		return nil, 0, err
	}
	return comments, total, nil
}

func withReplies(db *gorm.DB) *gorm.DB {
	return db.Preload("Replies", func(db *gorm.DB) *gorm.DB {
		return db.Where("status = ?", StatusApproved).Order("created_at ASC")
	}).Preload("Replies.User")
}

// GetThread returns the thread a comment belongs to: its top-level comment
// with all replies.
func (s *CommunityService) GetThread(id uuid.UUID, viewer *uuid.UUID) (*model.Comment, error) {
	var c model.Comment
	err := s.db.Select("id", "parent_id").First(&c, "id = ? AND status = ?", id, StatusApproved).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	root := c.ID
	if c.ParentID != nil {
		root = *c.ParentID
	}
	threads := []model.Comment{}
	if err := withReplies(withAuthor(s.db)).Where("id = ? AND status = ?", root, StatusApproved).Find(&threads).Error; err != nil {
		return nil, err
	}
	if len(threads) == 0 {
		return nil, ErrNotFound
	}
	if err := s.markLiked(viewer, threads); err != nil {
		return nil, err
	}
	return &threads[0], nil
}

// markLiked fills liked_by_me on comments and their replies.
func (s *CommunityService) markLiked(viewer *uuid.UUID, comments []model.Comment) error {
	var ids []uuid.UUID
	for _, c := range comments {
		ids = append(ids, c.ID)
		for _, r := range c.Replies {
			ids = append(ids, r.ID)
		}
	}
	liked, err := s.likedSet(viewer, model.LikeTargetComment, ids)
	if err != nil {
		return err
	}
	for i := range comments {
		comments[i].LikedByMe = liked[comments[i].ID]
		for j := range comments[i].Replies {
			comments[i].Replies[j].LikedByMe = liked[comments[i].Replies[j].ID]
		}
	}
	return nil
}

// ParagraphCount is how many top-level comments a paragraph has.
type ParagraphCount struct {
	ParagraphIndex int `json:"paragraph_index"`
	Count          int `json:"count"`
}

// ParagraphCounts returns the comment count of each commented paragraph of
// a chapter, in paragraph order.
func (s *CommunityService) ParagraphCounts(chapterID uuid.UUID) ([]ParagraphCount, error) {
	counts := []ParagraphCount{}
	err := s.db.Model(&model.Comment{}).Select("paragraph_index, COUNT(*) AS count").
		Where("chapter_id = ? AND parent_id IS NULL AND paragraph_index IS NOT NULL AND status = ?", chapterID, StatusApproved).
		Group("paragraph_index").Order("paragraph_index").Scan(&counts).Error
	return counts, err
}

// CreateComment comments on a published chapter. Replies attach to the
// top-level comment so threads stay one level deep.
func (s *CommunityService) CreateComment(userID, chapterID uuid.UUID, in CommentInput) (*model.Comment, error) {
	var count int64
	if err := s.db.Model(&model.Chapter{}).Where("id = ? AND is_published", chapterID).Count(&count).Error; err != nil {
		return nil, err
	}
	if count == 0 {
		return nil, ErrNotFound
	}
	comment := &model.Comment{
		UserID: userID, ChapterID: chapterID, Content: strings.TrimSpace(in.Content),
		ParagraphIndex: in.ParagraphIndex, Status: StatusApproved,
	}
	var parent model.Comment
	if in.ParentID != nil {
		err := s.db.First(&parent, "id = ? AND chapter_id = ?", *in.ParentID, chapterID).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		if err != nil {
			return nil, err
		}
		root := parent.ID
		if parent.ParentID != nil {
			root = *parent.ParentID
		}
		comment.ParentID = &root
		// A reply belongs to its thread's paragraph.
		comment.ParagraphIndex = nil
	}
	if err := s.db.Create(comment).Error; err != nil {
		return nil, err
	}
	if comment.ParentID != nil && s.notifications != nil {
		if err := s.notifications.NotifyReply(comment, &parent); err != nil {
			log.Printf("community: failed to notify reply %s: %v", comment.ID, err)
		}
	}
	var created model.Comment
	err := withAuthor(s.db).First(&created, "id = ?", comment.ID).Error
	return &created, err
}

// DeleteComment soft-deletes a comment and its replies.
func (s *CommunityService) DeleteComment(userID uuid.UUID, isAdmin bool, id uuid.UUID) error {
	var comment model.Comment
	err := s.db.First(&comment, "id = ?", id).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return ErrNotFound
	}
	if err != nil {
		return err
	}
	if comment.UserID != userID && !isAdmin {
		return ErrForbidden
	}
	return s.db.Where("id = ? OR parent_id = ?", id, id).Delete(&model.Comment{}).Error
}

// -------------------------------------------------------------------- likes

// LikeResult is the state of a like after a like or unlike.
type LikeResult struct {
	Liked     bool `json:"liked"`
	LikeCount int  `json:"like_count"`
}

func likeTable(targetType string) interface{} {
	if targetType == model.LikeTargetReview {
		return &model.Review{}
	}
	return &model.Comment{}
}

// SetLike likes or unlikes an approved review or comment. Repeating either
// is harmless, and the target's like_count only moves when the state changes.
func (s *CommunityService) SetLike(userID uuid.UUID, targetType string, targetID uuid.UUID, like bool) (*LikeResult, error) {
	table := likeTable(targetType)
	var result LikeResult
	err := s.db.Transaction(func(tx *gorm.DB) error {
		var count int64
		if err := tx.Model(table).Where("id = ? AND status = ?", targetID, StatusApproved).Count(&count).Error; err != nil {
			return err
		}
		if count == 0 {
			return ErrNotFound
		}

		var changed int64
		var delta string
		if like {
			res := tx.Clauses(clause.OnConflict{DoNothing: true}).
				Create(&model.Like{UserID: userID, TargetType: targetType, TargetID: targetID})
			changed, delta = res.RowsAffected, "like_count + 1"
			if res.Error != nil {
				return res.Error
			}
		} else {
			res := tx.Where("user_id = ? AND target_type = ? AND target_id = ?", userID, targetType, targetID).Delete(&model.Like{})
			changed, delta = res.RowsAffected, "GREATEST(like_count - 1, 0)"
			if res.Error != nil {
				return res.Error
			}
		}
		if changed > 0 {
			if err := tx.Model(table).Where("id = ?", targetID).UpdateColumn("like_count", gorm.Expr(delta)).Error; err != nil {
				return err
			}
		}
		result.Liked = like
		return tx.Model(table).Select("like_count").Where("id = ?", targetID).Scan(&result.LikeCount).Error
	})
	if err != nil {
		return nil, err
	}
	return &result, nil
}

// likedSet reports which of ids the viewer has liked.
func (s *CommunityService) likedSet(viewer *uuid.UUID, targetType string, ids []uuid.UUID) (map[uuid.UUID]bool, error) {
	liked := map[uuid.UUID]bool{}
	if viewer == nil || len(ids) == 0 {
		return liked, nil
	}
	var found []uuid.UUID
	err := s.db.Model(&model.Like{}).Where("user_id = ? AND target_type = ? AND target_id IN ?", *viewer, targetType, ids).
		Pluck("target_id", &found).Error
	for _, id := range found {
		liked[id] = true
	}
	return liked, err
}

// ------------------------------------------------------------------ reports

// ReportTargets are the things users may report.
var ReportTargets = map[string]interface{}{
	"review":  &model.Review{},
	"comment": &model.Comment{},
	"novel":   &model.Novel{},
	"chapter": &model.Chapter{},
	"user":    &model.User{},
}

type ReportInput struct {
	TargetType  string    `json:"target_type" binding:"required,oneof=review comment novel chapter user"`
	TargetID    uuid.UUID `json:"target_id" binding:"required"`
	Reason      string    `json:"reason" binding:"required,oneof=spam abuse spoiler copyright inappropriate other"`
	Description string    `json:"description" binding:"max=1000"`
}

// CreateReport files a report. Reporting the same target again while the
// first report is pending returns the pending report.
func (s *CommunityService) CreateReport(userID uuid.UUID, in ReportInput) (*model.Report, error) {
	var count int64
	if err := s.db.Model(ReportTargets[in.TargetType]).Where("id = ?", in.TargetID).Count(&count).Error; err != nil {
		return nil, err
	}
	if count == 0 {
		return nil, ErrNotFound
	}
	var existing model.Report
	err := s.db.Where("reporter_id = ? AND target_type = ? AND target_id = ? AND status = ?",
		userID, in.TargetType, in.TargetID, model.ReportPending).First(&existing).Error
	if err == nil {
		return &existing, nil
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}
	report := &model.Report{
		ReporterID: userID, TargetType: in.TargetType, TargetID: in.TargetID,
		Reason: in.Reason, Description: strings.TrimSpace(in.Description), Status: model.ReportPending,
	}
	return report, s.db.Create(report).Error
}

// ReportView is a report with a short preview of what was reported.
type ReportView struct {
	model.Report
	TargetPreview string `json:"target_preview"`
}

func (s *CommunityService) AdminListReports(status string, page, pageSize int) ([]ReportView, int64, error) {
	var reports []model.Report
	var total int64
	q := s.db.Model(&model.Report{})
	if status != "" {
		q = q.Where("status = ?", status)
	}
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	err := q.Preload("Reporter").Order("created_at DESC").Offset(offset(page, pageSize)).Limit(pageSize).Find(&reports).Error
	if err != nil {
		return nil, 0, err
	}
	views := make([]ReportView, len(reports))
	for i, r := range reports {
		views[i] = ReportView{Report: r, TargetPreview: s.preview(r.TargetType, r.TargetID)}
	}
	return views, total, nil
}

func (s *CommunityService) preview(targetType string, id uuid.UUID) string {
	var text string
	q := s.db.Unscoped().Model(ReportTargets[targetType]).Where("id = ?", id)
	switch targetType {
	case "review":
		q = q.Select("title || ': ' || content")
	case "comment":
		q = q.Select("content")
	case "novel", "chapter":
		q = q.Select("title")
	case "user":
		q = q.Select("nickname || ' (@' || username || ')'")
	}
	if q.Scan(&text).Error != nil {
		return ""
	}
	if r := []rune(text); len(r) > 120 {
		text = string(r[:120]) + "…"
	}
	return text
}

// ResolveReport closes a report. With hideTarget, a reported review or
// comment is hidden from readers.
func (s *CommunityService) ResolveReport(adminID, id uuid.UUID, status string, hideTarget bool) (*model.Report, error) {
	var report model.Report
	err := s.db.First(&report, "id = ?", id).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	now := time.Now()
	err = s.db.Model(&model.Report{}).Where("id = ?", id).
		Updates(map[string]interface{}{"status": status, "resolved_by": adminID, "resolved_at": now}).Error
	if err != nil {
		return nil, err
	}
	report.Status, report.ResolvedBy, report.ResolvedAt = status, &adminID, &now
	if hideTarget {
		switch report.TargetType {
		case "review":
			if _, err := s.SetReviewStatus(report.TargetID, StatusHidden); err != nil && !errors.Is(err, ErrNotFound) {
				return nil, err
			}
		case "comment":
			if err := s.db.Model(&model.Comment{}).Where("id = ?", report.TargetID).Update("status", StatusHidden).Error; err != nil {
				return nil, err
			}
		}
	}
	return &report, nil
}
