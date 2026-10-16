package service

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/pkg/moderation"
	"github.com/tenghongzou/palimpsest/backend/internal/testutil"
	"gorm.io/gorm"
)

func addTerm(t *testing.T, m *ModerationService, term, severity string) *model.ModerationTerm {
	t.Helper()
	created, err := m.CreateTerm(ModerationTermInput{Term: term, Severity: severity})
	if err != nil {
		t.Fatalf("CreateTerm(%q): %v", term, err)
	}
	return created
}

func TestModerationTerms(t *testing.T) {
	db := testutil.DB(t)
	m := NewModerationService(db)

	first := addTerm(t, m, "垃圾", model.SeverityBlock)
	second := addTerm(t, m, "Spam Site", model.SeverityFlag)
	for _, dup := range []string{"垃 圾", "ＳＰＡＭ site"} {
		if _, err := m.CreateTerm(ModerationTermInput{Term: dup, Severity: model.SeverityFlag}); !errors.Is(err, ErrConflict) {
			t.Errorf("duplicate %q: err = %v", dup, err)
		}
	}
	// zh-TW and zh-CN forms are one term.
	addTerm(t, m, "廣告", model.SeverityFlag)
	if _, err := m.CreateTerm(ModerationTermInput{Term: "广告", Severity: model.SeverityBlock}); !errors.Is(err, ErrConflict) {
		t.Errorf("simplified duplicate: err = %v", err)
	}
	if _, err := m.CreateTerm(ModerationTermInput{Term: "!!!", Severity: model.SeverityBlock}); !errors.Is(err, ErrInvalidTerm) {
		t.Errorf("punctuation term: err = %v", err)
	}

	terms, err := m.ListTerms()
	if err != nil || len(terms) != 3 || terms[0].Term != "廣告" || terms[2].ID != first.ID {
		t.Errorf("ListTerms = %+v, %v", terms, err)
	}
	if r, status := m.Check("全是垃圾"); status != StatusPending || !r.HasFlag(moderation.FlagBlockedTerm) {
		t.Errorf("Check with term = %+v, %s", r, status)
	}
	if err := m.DeleteTerm(first.ID); err != nil {
		t.Fatal(err)
	}
	if err := m.DeleteTerm(first.ID); !errors.Is(err, ErrNotFound) {
		t.Errorf("second delete: err = %v", err)
	}
	// Deleting takes effect immediately, without waiting for the cache.
	if _, status := m.Check("全是垃圾"); status != StatusApproved {
		t.Errorf("deleted term still holds content")
	}
	_ = second
}

type moderationFixture struct {
	db        *gorm.DB
	mod       *ModerationService
	svc       *CommunityService
	notes     *NotificationService
	changed   *int32
	alice     *model.User
	bob       *model.User
	novel     *model.Novel
	chapterID uuid.UUID
}

func newModerationFixture(t *testing.T) *moderationFixture {
	t.Helper()
	db := testutil.DB(t)
	f := &moderationFixture{db: db, mod: NewModerationService(db), notes: NewNotificationService(db), changed: new(int32)}
	f.svc = NewCommunityService(db, func(uuid.UUID) { atomic.AddInt32(f.changed, 1) }).
		WithNotifications(f.notes).WithModeration(f.mod)
	f.alice = testutil.User(t, db, "")
	f.bob = testutil.User(t, db, "")
	var chapters []model.Chapter
	f.novel, chapters = testutil.Novel(t, db, 1)
	f.chapterID = chapters[0].ID
	addTerm(t, f.mod, "垃圾", model.SeverityBlock)
	return f
}

func TestModerationHoldsReviews(t *testing.T) {
	f := newModerationFixture(t)
	db, svc := f.db, f.svc

	held, err := svc.CreateReview(f.alice.ID, f.novel.ID, ReviewInput{Title: "爛", Content: "根本是垃圾", Rating: 1})
	if err != nil {
		t.Fatalf("CreateReview: %v", err)
	}
	if held.Status != StatusPending || held.Moderation != nil {
		t.Errorf("held review = status %s, moderation %+v", held.Status, held.Moderation)
	}
	flagged, err := svc.CreateReview(f.bob.ID, f.novel.ID, ReviewInput{Title: "好看", Content: "全文在 https://example.com", Rating: 4})
	if err != nil {
		t.Fatal(err)
	}
	if flagged.Status != StatusApproved || flagged.Moderation != nil {
		t.Errorf("flagged review = %+v", flagged)
	}
	stored := reload[model.Review](t, db, flagged.ID)
	if stored.Moderation == nil || !stored.Moderation.HasFlag(moderation.FlagLink) || stored.Moderation.Score != 0.4 {
		t.Errorf("stored moderation = %+v", stored.Moderation)
	}

	// Pending reviews are not public and do not count toward the rating.
	reviews, total, _ := svc.ListReviews(f.novel.ID, nil, "", 1, 10)
	if total != 1 || reviews[0].ID != flagged.ID || reviews[0].Moderation != nil {
		t.Errorf("public reviews = %+v", reviews)
	}
	if n := reload[model.Novel](t, db, f.novel.ID); n.AvgRating != 4 || n.ReviewCount != 1 {
		t.Errorf("rating = %v (%d)", n.AvgRating, n.ReviewCount)
	}
	if _, err := svc.SetLike(f.bob.ID, model.LikeTargetReview, held.ID, true); !errors.Is(err, ErrNotFound) {
		t.Errorf("liking a pending review: err = %v", err)
	}
	if _, err := svc.CreateReport(f.bob.ID, ReportInput{TargetType: "review", TargetID: held.ID, Reason: "spam"}); !errors.Is(err, ErrNotFound) {
		t.Errorf("reporting a pending review: err = %v", err)
	}
	stats, _ := NewAdminService(db).Stats(0)
	if stats.PendingModeration != 1 {
		t.Errorf("pending_moderation = %d", stats.PendingModeration)
	}

	// The admin listing shows moderation.
	admin, _, _ := svc.AdminListReviews(StatusPending, 1, 10)
	if len(admin) != 1 || admin[0].Moderation == nil || !admin[0].Moderation.HasFlag(moderation.FlagBlockedTerm) {
		t.Errorf("admin listing = %+v", admin)
	}

	// Approving publishes the review and updates the rating.
	before := atomic.LoadInt32(f.changed)
	item, err := svc.Moderate(model.LikeTargetReview, held.ID, StatusApproved)
	if err != nil {
		t.Fatalf("Moderate: %v", err)
	}
	if item.Status != StatusApproved || item.Type != "review" || item.Rating == nil || *item.Rating != 1 ||
		item.User == nil || item.Novel == nil || item.Novel.ID != f.novel.ID || item.Moderation == nil {
		t.Errorf("moderated item = %+v", item)
	}
	if n := reload[model.Novel](t, db, f.novel.ID); n.AvgRating != 2.5 || n.ReviewCount != 2 {
		t.Errorf("rating after approval = %v (%d)", n.AvgRating, n.ReviewCount)
	}
	if atomic.LoadInt32(f.changed) == before {
		t.Error("novel caches not invalidated on approval")
	}
	if _, err := svc.Moderate(model.LikeTargetReview, uuid.New(), StatusApproved); !errors.Is(err, ErrNotFound) {
		t.Errorf("moderating a missing review: err = %v", err)
	}

	// Editing a published review into a blocked term holds it again.
	edited, err := svc.UpdateReview(f.bob.ID, flagged.ID, ReviewInput{Title: "改", Content: "其實是垃圾", Rating: 2})
	if err != nil || edited.Status != StatusPending || edited.Moderation != nil {
		t.Fatalf("UpdateReview = %+v, %v", edited, err)
	}
	if n := reload[model.Novel](t, db, f.novel.ID); n.AvgRating != 1 || n.ReviewCount != 1 {
		t.Errorf("rating after held edit = %v (%d)", n.AvgRating, n.ReviewCount)
	}
	// A hidden review stays hidden when edited.
	svc.Moderate(model.LikeTargetReview, flagged.ID, StatusHidden)
	if r, _ := svc.UpdateReview(f.bob.ID, flagged.ID, ReviewInput{Title: "好", Content: "好看", Rating: 5}); r.Status != StatusHidden {
		t.Errorf("edited hidden review = %s", r.Status)
	}
}

func TestModerationHoldsComments(t *testing.T) {
	f := newModerationFixture(t)
	db, svc, ch := f.db, f.svc, f.chapterID
	p := 3

	root, err := svc.CreateComment(f.alice.ID, ch, CommentInput{Content: "精彩", ParagraphIndex: &p})
	if err != nil || root.Status != StatusApproved {
		t.Fatalf("CreateComment = %+v, %v", root, err)
	}
	held, err := svc.CreateComment(f.bob.ID, ch, CommentInput{Content: "垃圾作者", ParagraphIndex: &p})
	if err != nil || held.Status != StatusPending || held.Moderation != nil {
		t.Fatalf("held comment = %+v, %v", held, err)
	}
	// A pending comment is invisible: lists, threads, counts, likes and replies.
	comments, total, _ := svc.ListComments(ch, nil, "", nil, 1, 10)
	if total != 1 || comments[0].ID != root.ID {
		t.Errorf("public comments = %+v", comments)
	}
	if _, err := svc.GetThread(held.ID, nil); !errors.Is(err, ErrNotFound) {
		t.Errorf("thread of pending comment: err = %v", err)
	}
	if counts, _ := svc.ParagraphCounts(ch); len(counts) != 1 || counts[0].Count != 1 {
		t.Errorf("paragraph counts = %+v", counts)
	}
	if _, err := svc.SetLike(f.alice.ID, model.LikeTargetComment, held.ID, true); !errors.Is(err, ErrNotFound) {
		t.Errorf("liking a pending comment: err = %v", err)
	}
	if _, err := svc.CreateComment(f.alice.ID, ch, CommentInput{Content: "回覆", ParentID: &held.ID}); !errors.Is(err, ErrNotFound) {
		t.Errorf("replying to a pending comment: err = %v", err)
	}

	// A held reply notifies nobody until approved, then the parent's author.
	reply, err := svc.CreateComment(f.bob.ID, ch, CommentInput{Content: "你才是垃圾", ParentID: &root.ID})
	if err != nil || reply.Status != StatusPending {
		t.Fatalf("held reply = %+v, %v", reply, err)
	}
	if thread, _ := svc.GetThread(root.ID, nil); len(thread.Replies) != 0 {
		t.Errorf("pending reply listed: %+v", thread.Replies)
	}
	if n, _ := f.notes.UnreadCount(f.alice.ID); n != 0 {
		t.Errorf("notified about a held reply (%d)", n)
	}
	item, err := svc.Moderate(model.LikeTargetComment, reply.ID, StatusApproved)
	if err != nil {
		t.Fatalf("Moderate comment: %v", err)
	}
	if item.Type != "comment" || item.Chapter == nil || item.Chapter.ID != ch || item.Novel == nil ||
		item.Novel.ID != f.novel.ID || item.Rating != nil || item.User == nil || item.User.ID != f.bob.ID {
		t.Errorf("moderated comment = %+v", item)
	}
	if n, _ := f.notes.UnreadCount(f.alice.ID); n != 1 {
		t.Errorf("approval notifications = %d, want 1", n)
	}
	if thread, _ := svc.GetThread(root.ID, nil); len(thread.Replies) != 1 || thread.Replies[0].Moderation != nil {
		t.Errorf("approved reply = %+v", thread.Replies)
	}
	if _, err := svc.Moderate(model.LikeTargetComment, uuid.New(), StatusHidden); !errors.Is(err, ErrNotFound) {
		t.Errorf("moderating a missing comment: err = %v", err)
	}
	_ = db
}

func TestModerationQueue(t *testing.T) {
	f := newModerationFixture(t)
	db, svc := f.db, f.svc
	carol := testutil.User(t, db, "")

	oldReview, _ := svc.CreateReview(f.alice.ID, f.novel.ID, ReviewInput{Title: "a", Content: "垃圾", Rating: 1})
	pendingComment, _ := svc.CreateComment(f.bob.ID, f.chapterID, CommentInput{Content: "垃圾"})
	db.Model(&model.Review{}).Where("id = ?", oldReview.ID).UpdateColumn("created_at", time.Now().Add(-time.Hour))
	// Flagged: published with flags, ordered by score.
	low, _ := svc.CreateReview(f.bob.ID, f.novel.ID, ReviewInput{Title: "b", Content: "https://example.com", Rating: 4})
	high, _ := svc.CreateComment(carol.ID, f.chapterID, CommentInput{Content: "https://example.com 加賴"})
	clean, _ := svc.CreateComment(carol.ID, f.chapterID, CommentInput{Content: "好看"})
	deleted, _ := svc.CreateComment(carol.ID, f.chapterID, CommentInput{Content: "垃圾!"})
	svc.DeleteComment(carol.ID, false, deleted.ID)

	ids := func(items []ModerationItem) []uuid.UUID {
		out := make([]uuid.UUID, len(items))
		for i, it := range items {
			out[i] = it.ID
		}
		return out
	}
	items, total, err := svc.ModerationQueue(QueuePending, "", 1, 10)
	if err != nil || total != 2 || len(items) != 2 || items[0].ID != oldReview.ID || items[1].ID != pendingComment.ID {
		t.Errorf("pending queue = %v (total %d, err %v)", ids(items), total, err)
	}
	if items, total, _ := svc.ModerationQueue(QueuePending, model.LikeTargetComment, 1, 10); total != 1 || items[0].ID != pendingComment.ID {
		t.Errorf("pending comments = %v", ids(items))
	}
	if items, total, _ := svc.ModerationQueue(QueuePending, "", 2, 1); total != 2 || len(items) != 1 || items[0].ID != pendingComment.ID {
		t.Errorf("page 2 = %v", ids(items))
	}

	items, total, err = svc.ModerationQueue(QueueFlagged, "", 1, 10)
	if err != nil || total != 2 || items[0].ID != high.ID || items[1].ID != low.ID {
		t.Errorf("flagged queue = %v (total %d, err %v)", ids(items), total, err)
	}
	if items[0].Moderation == nil || items[0].Moderation.Score != 0.76 || items[0].Status != StatusApproved {
		t.Errorf("flagged item = %+v", items[0])
	}
	if items, _, _ := svc.ModerationQueue(QueueFlagged, model.LikeTargetReview, 1, 10); len(items) != 1 || items[0].ID != low.ID {
		t.Errorf("flagged reviews = %v", ids(items))
	}
	// Hiding takes an item out of the flagged queue.
	svc.Moderate(model.LikeTargetComment, high.ID, StatusHidden)
	if _, total, _ := svc.ModerationQueue(QueueFlagged, "", 1, 10); total != 1 {
		t.Errorf("flagged after hiding = %d", total)
	}
	_ = clean
}

// fakeAI answers depending on the content: "SPAM" is confidently spam,
// "BROKEN" gets a malformed reply and "SLOW" outlasts the timeout.
func fakeAIServer(t *testing.T) *httptest.Server {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var req struct {
			Messages []struct{ Content string } `json:"messages"`
		}
		_ = json.NewDecoder(r.Body).Decode(&req)
		text := req.Messages[0].Content
		reply := `{"categories": [], "score": 0.05, "reason": "fine"}`
		switch {
		case strings.Contains(text, "SPAM"):
			reply = `Here you go: {"categories": ["spam"], "score": 0.92, "reason": "advertising"}`
		case strings.Contains(text, "BROKEN"):
			reply = `{"categories": ["spam"], "score": `
		case strings.Contains(text, "SLOW"):
			select {
			case <-time.After(2 * time.Second):
			case <-r.Context().Done():
			}
		case strings.Contains(text, "MILD"):
			reply = `{"categories": ["harassment"], "score": 0.5, "reason": "rude"}`
		}
		body, _ := json.Marshal(map[string]interface{}{"content": []map[string]string{{"type": "text", "text": reply}}})
		_, _ = w.Write(body)
	}))
	t.Cleanup(srv.Close)
	return srv
}

func TestModerationAIReview(t *testing.T) {
	f := newModerationFixture(t)
	db, svc := f.db, f.svc
	srv := fakeAIServer(t)
	f.mod.WithAI(moderation.NewAIReviewer("key", "claude-test", srv.URL), 2, 300*time.Millisecond)

	spamReview, _ := svc.CreateReview(f.alice.ID, f.novel.ID, ReviewInput{Title: "讚", Content: "SPAM 好書", Rating: 5})
	mild, _ := svc.CreateComment(f.bob.ID, f.chapterID, CommentInput{Content: "MILD 白痴"})
	broken, _ := svc.CreateComment(f.bob.ID, f.chapterID, CommentInput{Content: "BROKEN"})
	slow, _ := svc.CreateComment(f.bob.ID, f.chapterID, CommentInput{Content: "SLOW"})
	heldFirst, _ := svc.CreateComment(f.alice.ID, f.chapterID, CommentInput{Content: "垃圾 SPAM"})
	// The requests return before the AI review finishes.
	if spamReview.Status != StatusApproved {
		t.Fatalf("review held before the AI review: %s", spamReview.Status)
	}
	f.mod.Wait()

	// A confident verdict takes published content back to pending and out
	// of the rating; flags are merged and the score raised.
	r := reload[model.Review](t, db, spamReview.ID)
	if r.Status != StatusPending || r.Moderation == nil || !r.Moderation.AIChecked ||
		!r.Moderation.HasFlag("ai_spam") || r.Moderation.Score != 0.92 {
		t.Errorf("spam review = %s %+v", r.Status, r.Moderation)
	}
	if n := reload[model.Novel](t, db, f.novel.ID); n.ReviewCount != 0 || n.AvgRating != 0 {
		t.Errorf("rating after AI hold = %v (%d)", n.AvgRating, n.ReviewCount)
	}
	// Below the threshold: flagged but still published.
	c := reload[model.Comment](t, db, mild.ID)
	if c.Status != StatusApproved || !c.Moderation.HasFlag("ai_harassment") || c.Moderation.Score != 0.5 {
		t.Errorf("mild comment = %s %+v", c.Status, c.Moderation)
	}
	// Malformed replies and timeouts change nothing.
	for _, id := range []uuid.UUID{broken.ID, slow.ID} {
		c := reload[model.Comment](t, db, id)
		if c.Status != StatusApproved || c.Moderation == nil || c.Moderation.AIChecked {
			t.Errorf("comment %s = %s %+v", id, c.Status, c.Moderation)
		}
	}
	// Content held by the rules gets the AI findings, and stays pending.
	h := reload[model.Comment](t, db, heldFirst.ID)
	if h.Status != StatusPending || !h.Moderation.AIChecked || !h.Moderation.HasFlag(moderation.FlagBlockedTerm) || !h.Moderation.HasFlag("ai_spam") {
		t.Errorf("held comment = %s %+v", h.Status, h.Moderation)
	}
}

type panickyAI struct{}

func (panickyAI) Review(context.Context, string) (*moderation.AIVerdict, error) { panic("boom") }

type countingAI struct{ calls int32 }

func (a *countingAI) Review(ctx context.Context, _ string) (*moderation.AIVerdict, error) {
	atomic.AddInt32(&a.calls, 1)
	<-ctx.Done()
	return nil, ctx.Err()
}

func TestModerationAIIsContained(t *testing.T) {
	f := newModerationFixture(t)
	f.mod.WithAI(panickyAI{}, 1, time.Second)
	c, err := f.svc.CreateComment(f.alice.ID, f.chapterID, CommentInput{Content: "好看"})
	if err != nil || c.Status != StatusApproved {
		t.Fatalf("CreateComment = %+v, %v", c, err)
	}
	f.mod.Wait() // a panicking reviewer does not take the server down

	// Concurrency is bounded: with one slot busy, others wait for it or give up.
	ai := &countingAI{}
	f.mod.WithAI(ai, 1, 100*time.Millisecond)
	for i := 0; i < 3; i++ {
		f.mod.ReviewAsync("x", func(*moderation.AIVerdict) { t.Error("verdict from a failed review") })
	}
	f.mod.Wait()
	if n := atomic.LoadInt32(&ai.calls); n < 1 || n > 3 {
		t.Errorf("calls = %d", n)
	}
}

func TestOwnPendingContentIsVisibleToItsAuthor(t *testing.T) {
	f := newModerationFixture(t)
	svc, ch := f.svc, f.chapterID
	carol := testutil.User(t, f.db, "")

	review, _ := svc.CreateReview(f.bob.ID, f.novel.ID, ReviewInput{Title: "x", Content: "垃圾", Rating: 1})
	if _, total, _ := svc.ListReviews(f.novel.ID, nil, "", 1, 10); total != 0 {
		t.Errorf("anonymous sees %d reviews", total)
	}
	if _, total, _ := svc.ListReviews(f.novel.ID, &carol.ID, "", 1, 10); total != 0 {
		t.Errorf("another user sees %d reviews", total)
	}
	own, total, _ := svc.ListReviews(f.novel.ID, &f.bob.ID, "", 1, 10)
	if total != 1 || own[0].ID != review.ID || own[0].Status != StatusPending || own[0].Moderation != nil {
		t.Errorf("author's reviews = %+v", own)
	}

	root, _ := svc.CreateComment(f.alice.ID, ch, CommentInput{Content: "好看"})
	heldRoot, _ := svc.CreateComment(f.bob.ID, ch, CommentInput{Content: "垃圾"})
	heldReply, _ := svc.CreateComment(f.bob.ID, ch, CommentInput{Content: "垃圾", ParentID: &root.ID})
	comments, total, _ := svc.ListComments(ch, &f.bob.ID, "", nil, 1, 10)
	if total != 2 || len(comments) != 2 {
		t.Fatalf("author's comments = %+v", comments)
	}
	for _, c := range comments {
		if c.ID == root.ID && (len(c.Replies) != 1 || c.Replies[0].ID != heldReply.ID || c.Replies[0].Status != StatusPending) {
			t.Errorf("author's view of replies = %+v", c.Replies)
		}
	}
	if comments, total, _ := svc.ListComments(ch, &carol.ID, "", nil, 1, 10); total != 1 || len(comments[0].Replies) != 0 {
		t.Errorf("another user's view = %+v", comments)
	}
	if thread, err := svc.GetThread(heldReply.ID, &f.bob.ID); err != nil || len(thread.Replies) != 1 {
		t.Errorf("author's thread = %+v, %v", thread, err)
	}
	if _, err := svc.GetThread(heldReply.ID, &carol.ID); !errors.Is(err, ErrNotFound) {
		t.Errorf("another user's thread: err = %v", err)
	}
	if _, err := svc.GetThread(heldRoot.ID, &f.bob.ID); err != nil {
		t.Errorf("author's held thread: %v", err)
	}
	if thread, _ := svc.GetThread(root.ID, nil); len(thread.Replies) != 0 {
		t.Errorf("anonymous thread replies = %+v", thread.Replies)
	}
	// Nobody can reply to held content, the author included.
	if _, err := svc.CreateComment(f.bob.ID, ch, CommentInput{Content: "補充", ParentID: &heldRoot.ID}); !errors.Is(err, ErrNotFound) {
		t.Errorf("reply to own held comment: err = %v", err)
	}

	// Authors can delete what is held.
	if err := svc.DeleteComment(f.bob.ID, false, heldRoot.ID); err != nil {
		t.Errorf("delete own pending comment: %v", err)
	}
	if err := svc.DeleteReview(f.bob.ID, false, review.ID); err != nil {
		t.Errorf("delete own pending review: %v", err)
	}
	if _, total, _ := svc.ListReviews(f.novel.ID, &f.bob.ID, "", 1, 10); total != 0 {
		t.Errorf("deleted review still listed")
	}
	_, pending, _ := svc.ModerationQueue(QueuePending, "", 1, 10)
	stats, _ := NewAdminService(f.db).Stats(0)
	if pending != 1 || stats.PendingModeration != pending {
		t.Errorf("pending queue %d, pending_moderation %d", pending, stats.PendingModeration)
	}
}

func TestDecisionsLeaveTheFlaggedQueue(t *testing.T) {
	f := newModerationFixture(t)
	svc := f.svc
	review, _ := svc.CreateReview(f.alice.ID, f.novel.ID, ReviewInput{Title: "x", Content: "https://example.com", Rating: 3})
	comment, _ := svc.CreateComment(f.bob.ID, f.chapterID, CommentInput{Content: "https://example.com"})
	if _, total, _ := svc.ModerationQueue(QueueFlagged, "", 1, 10); total != 2 {
		t.Fatalf("flagged = %d", total)
	}
	item, err := svc.Moderate(model.LikeTargetComment, comment.ID, StatusApproved)
	if err != nil || item.Moderation == nil || item.Moderation.ReviewedAt == nil || !item.Moderation.HasFlag(moderation.FlagLink) {
		t.Fatalf("approved flagged comment = %+v, %v", item, err)
	}
	// The legacy review endpoint records the decision too.
	if _, err := svc.SetReviewStatus(review.ID, StatusApproved); err != nil {
		t.Fatal(err)
	}
	if _, total, _ := svc.ModerationQueue(QueueFlagged, "", 1, 10); total != 0 {
		t.Errorf("flagged after approval = %d", total)
	}
	// Editing the review checks it afresh, so it is flagged again.
	svc.UpdateReview(f.alice.ID, review.ID, ReviewInput{Title: "x", Content: "www.example.org", Rating: 3})
	if _, total, _ := svc.ModerationQueue(QueueFlagged, "", 1, 10); total != 1 {
		t.Errorf("flagged after edit = %d", total)
	}

	// The legacy endpoint also publishes held reviews.
	held, _ := svc.CreateReview(f.bob.ID, f.novel.ID, ReviewInput{Title: "x", Content: "垃圾", Rating: 5})
	if _, err := svc.SetReviewStatus(held.ID, StatusApproved); err != nil {
		t.Fatal(err)
	}
	if n := reload[model.Novel](t, f.db, f.novel.ID); n.ReviewCount != 2 || n.AvgRating != 4 {
		t.Errorf("rating after legacy approval = %v (%d)", n.AvgRating, n.ReviewCount)
	}
}
