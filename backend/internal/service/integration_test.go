package service

import (
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/alicebob/miniredis/v2"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
	"github.com/tenghongzou/palimpsest/backend/internal/config"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/repository"
	"github.com/tenghongzou/palimpsest/backend/internal/testutil"
	"gorm.io/gorm"
)

// These tests run against Postgres (TEST_DATABASE_URL) and skip without it.

func testRedis(t *testing.T) *redis.Client {
	t.Helper()
	mr := miniredis.RunT(t)
	return redis.NewClient(&redis.Options{Addr: mr.Addr()})
}

func reload[T any](t *testing.T, db *gorm.DB, id interface{}) T {
	t.Helper()
	var v T
	if err := db.First(&v, "id = ?", id).Error; err != nil {
		t.Fatalf("reload: %v", err)
	}
	return v
}

func TestChapterStatsNavigationAndViews(t *testing.T) {
	db := testutil.DB(t)
	rdb := testRedis(t)
	novelRepo := repository.NewNovelRepository(db)
	ranking := NewRankingService(rdb, novelRepo)
	svc := NewNovelService(novelRepo, repository.NewCacheRepository(rdb), ranking)

	novel, chapters := testutil.Novel(t, db, 3)
	draft := model.Chapter{NovelID: novel.ID, Title: "草稿", ChapterNumber: 4, Content: "還沒發布"}
	if err := db.Create(&draft).Error; err != nil {
		t.Fatal(err)
	}
	if err := svc.ChaptersChanged(novel.ID); err != nil {
		t.Fatalf("ChaptersChanged: %v", err)
	}

	got := reload[model.Novel](t, db, novel.ID)
	if got.TotalChapters != 3 {
		t.Errorf("total_chapters = %d, want 3 (drafts excluded)", got.TotalChapters)
	}
	if want := int64(3 * model.CountWords("第1章的內容")); got.TotalWords != want {
		t.Errorf("total_words = %d, want %d", got.TotalWords, want)
	}
	if got.LatestChapterID == nil || *got.LatestChapterID != chapters[2].ID || got.LatestChapterAt == nil {
		t.Errorf("latest chapter = %v, want %s", got.LatestChapterID, chapters[2].ID)
	}

	detail, err := svc.GetChapter(chapters[1].ID, true)
	if err != nil {
		t.Fatalf("GetChapter: %v", err)
	}
	if detail.PrevChapter == nil || detail.PrevChapter.ID != chapters[0].ID ||
		detail.NextChapter == nil || detail.NextChapter.ID != chapters[2].ID {
		t.Errorf("neighbours = %+v / %+v", detail.PrevChapter, detail.NextChapter)
	}
	last, _ := svc.GetChapter(chapters[2].ID, true)
	if _, err := svc.GetChapter(chapters[0].ID, false); err != nil {
		t.Fatalf("GetChapter without counting: %v", err)
	}
	if last.NextChapter != nil {
		t.Errorf("last chapter links to unpublished draft %+v", last.NextChapter)
	}
	if _, err := svc.GetChapter(draft.ID, true); err == nil {
		t.Error("unpublished chapter was readable")
	}

	if v := reload[model.Novel](t, db, novel.ID).ViewCount; v != 2 {
		t.Errorf("view_count = %d, want 2", v)
	}
	ranked, total, err := ranking.GetRanking("views", "daily", 1, 10)
	if err != nil || total != 1 || len(ranked) != 1 || ranked[0].ID != novel.ID {
		t.Errorf("daily views ranking = %v (total %d, err %v)", ranked, total, err)
	}
	if _, _, err := ranking.GetRanking("bogus", "daily", 1, 10); !errors.Is(err, ErrNotFound) {
		t.Errorf("unknown ranking type: err = %v", err)
	}

	// An unpublished novel hides its chapters too.
	db.Model(novel).Update("is_published", false)
	if _, err := svc.GetChapter(chapters[0].ID, true); err == nil {
		t.Error("chapter of unpublished novel was readable")
	}
}

func TestBookshelfFavoritesAndProgress(t *testing.T) {
	db := testutil.DB(t)
	svc := NewBookshelfService(repository.NewBookshelfRepository(db), db)
	user := testutil.User(t, db, "")
	novel, chapters := testutil.Novel(t, db, 3)
	repository.NewNovelRepository(db).RefreshStats(novel.ID)

	if _, err := svc.Add(user.ID, novel.ID, ""); err != nil {
		t.Fatalf("Add: %v", err)
	}
	if _, err := svc.Add(user.ID, novel.ID, ""); !errors.Is(err, ErrConflict) {
		t.Errorf("second Add: err = %v, want ErrConflict", err)
	}
	if _, err := svc.Add(user.ID, uuid.New(), ""); !errors.Is(err, ErrNotFound) {
		t.Errorf("Add unknown novel: err = %v, want ErrNotFound", err)
	}
	if n := reload[model.Novel](t, db, novel.ID).FavoriteCount; n != 1 {
		t.Errorf("favorite_count = %d, want 1", n)
	}

	t0 := time.Now().Add(-time.Hour)
	mustProgress := func(ch int, at time.Time, duration int) *model.ReadingProgress {
		t.Helper()
		p, err := svc.UpdateProgress(user.ID, novel.ID, ProgressUpdate{ChapterID: chapters[ch].ID, ScrollOffset: 0.5, ReadAt: at, Duration: duration})
		if err != nil {
			t.Fatalf("UpdateProgress: %v", err)
		}
		return p
	}
	mustProgress(0, t0, 100)
	mustProgress(0, t0.Add(time.Minute), 100000) // same chapter, capped duration
	p := mustProgress(1, t0.Add(2*time.Minute), 60)
	if p.ChapterID != chapters[1].ID {
		t.Fatalf("progress chapter = %s", p.ChapterID)
	}
	// A late offline report from before the latest one must not win.
	stale := mustProgress(2, t0.Add(-time.Minute), 0)
	if stale.ChapterID != chapters[1].ID {
		t.Errorf("stale update overwrote progress: %s", stale.ChapterID)
	}
	if _, err := svc.UpdateProgress(user.ID, novel.ID, ProgressUpdate{ChapterID: uuid.New()}); !errors.Is(err, ErrNotFound) {
		t.Errorf("unknown chapter: err = %v", err)
	}

	history, total, err := svc.History(user.ID, 1, 10)
	if err != nil || total != 2 {
		t.Fatalf("history total = %d (err %v), want 2 chapter changes", total, err)
	}
	if history[0].ChapterID != chapters[1].ID || history[0].Novel == nil || history[0].Chapter == nil || history[0].Chapter.Title != "第2章" {
		t.Errorf("history[0] = %+v", history[0])
	}
	u := reload[model.User](t, db, user.ID)
	if want := int64(chapters[0].WordCount + chapters[1].WordCount); u.TotalReadWords != want {
		t.Errorf("total_read_words = %d, want %d", u.TotalReadWords, want)
	}
	if want := int64(100 + maxSyncedDuration + 60); u.TotalReadSeconds != want {
		t.Errorf("total_read_seconds = %d, want %d", u.TotalReadSeconds, want)
	}

	entries, err := svc.List(user.ID, "recent")
	if err != nil || len(entries) != 1 {
		t.Fatalf("List: %v %v", entries, err)
	}
	rp := entries[0].ReadingProgress
	if rp == nil || rp.ChapterNumber != 2 || rp.Percentage < 66 || rp.Percentage > 67 {
		t.Errorf("shelf progress = %+v", rp)
	}

	if err := svc.SetGroup(user.ID, novel.ID, "收藏"); err != nil {
		t.Errorf("SetGroup: %v", err)
	}
	if err := svc.SetGroup(user.ID, uuid.New(), "x"); !errors.Is(err, ErrNotFound) {
		t.Errorf("SetGroup unknown: err = %v", err)
	}
	if err := svc.RemoveMany(user.ID, []uuid.UUID{novel.ID, uuid.New()}); err != nil {
		t.Fatalf("RemoveMany: %v", err)
	}
	if n := reload[model.Novel](t, db, novel.ID).FavoriteCount; n != 0 {
		t.Errorf("favorite_count after removal = %d, want 0", n)
	}
}

func TestBookmarksOfflineSync(t *testing.T) {
	db := testutil.DB(t)
	svc := NewBookmarkService(db)
	alice := testutil.User(t, db, "")
	bob := testutil.User(t, db, "")
	novel, chapters := testutil.Novel(t, db, 2)

	created, err := svc.Create(alice.ID, BookmarkInput{ChapterID: chapters[0].ID, ParagraphIndex: 3, Note: "好句"})
	if err != nil {
		t.Fatalf("Create: %v", err)
	}
	if created.NovelID != novel.ID || created.Chapter == nil || created.Chapter.Title != "第1章" ||
		created.Novel == nil || created.Novel.Title != novel.Title {
		t.Errorf("created = %+v", created)
	}

	offlineID := uuid.New()
	list, err := svc.Sync(alice.ID, BookmarkSync{
		Upserts: []BookmarkInput{
			{ID: &offlineID, ChapterID: chapters[1].ID, Note: "離線"},
			{ChapterID: uuid.New()}, // chapter gone: skipped
		},
		Deletes: []uuid.UUID{created.ID},
	})
	if err != nil {
		t.Fatalf("Sync: %v", err)
	}
	if len(list) != 1 || list[0].ID != offlineID || list[0].Note != "離線" {
		t.Errorf("after sync = %+v", list)
	}

	// Bob cannot take over Alice's bookmark by reusing its id.
	if _, err := svc.Create(bob.ID, BookmarkInput{ID: &offlineID, ChapterID: chapters[0].ID}); !errors.Is(err, ErrForbidden) {
		t.Errorf("foreign id: err = %v, want ErrForbidden", err)
	}
	note := "改過"
	if _, err := svc.Update(bob.ID, offlineID, BookmarkPatch{Note: &note}); !errors.Is(err, ErrNotFound) {
		t.Errorf("Bob updating Alice's bookmark: err = %v", err)
	}
	if b, err := svc.Update(alice.ID, offlineID, BookmarkPatch{Note: &note}); err != nil || b.Note != note {
		t.Errorf("Update = %+v, %v", b, err)
	}
	if err := svc.Delete(alice.ID, offlineID); err != nil {
		t.Errorf("Delete: %v", err)
	}
}

func TestReviewsCommentsLikesAndReports(t *testing.T) {
	db := testutil.DB(t)
	changed := 0
	svc := NewCommunityService(db, func(uuid.UUID) { changed++ })
	alice := testutil.User(t, db, "")
	bob := testutil.User(t, db, "")
	admin := testutil.User(t, db, "admin")
	novel, chapters := testutil.Novel(t, db, 1)

	r1, err := svc.CreateReview(alice.ID, novel.ID, ReviewInput{Title: "好看", Content: "推薦", Rating: 4.8})
	if err != nil {
		t.Fatalf("CreateReview: %v", err)
	}
	if r1.Rating != 5 || r1.User == nil || r1.User.Username != alice.Username {
		t.Errorf("review = %+v", r1)
	}
	if _, err := svc.CreateReview(alice.ID, novel.ID, ReviewInput{Title: "再一次", Content: "x", Rating: 1}); !errors.Is(err, ErrConflict) {
		t.Errorf("duplicate review: err = %v", err)
	}
	if _, err := svc.CreateReview(bob.ID, novel.ID, ReviewInput{Title: "普通", Content: "還行", Rating: 3}); err != nil {
		t.Fatal(err)
	}
	if n := reload[model.Novel](t, db, novel.ID); n.AvgRating != 4 || n.ReviewCount != 2 {
		t.Errorf("avg_rating = %v, review_count = %d", n.AvgRating, n.ReviewCount)
	}
	if _, err := svc.UpdateReview(bob.ID, r1.ID, ReviewInput{Title: "x", Content: "x", Rating: 1}); !errors.Is(err, ErrForbidden) {
		t.Errorf("editing someone else's review: err = %v", err)
	}

	for i := 0; i < 2; i++ {
		res, err := svc.SetLike(bob.ID, model.LikeTargetReview, r1.ID, true)
		if err != nil || !res.Liked || res.LikeCount != 1 {
			t.Errorf("like #%d = %+v, %v", i+1, res, err)
		}
	}
	reviews, total, err := svc.ListReviews(novel.ID, &bob.ID, "popular", 1, 10)
	if err != nil || total != 2 || reviews[0].ID != r1.ID || !reviews[0].LikedByMe || reviews[1].LikedByMe {
		t.Errorf("ListReviews = %+v (total %d, err %v)", reviews, total, err)
	}
	if res, _ := svc.SetLike(bob.ID, model.LikeTargetReview, r1.ID, false); res.LikeCount != 0 {
		t.Errorf("unlike count = %d", res.LikeCount)
	}

	// Reports: a repeat report returns the pending one; hiding a review
	// removes it from the public list and from the rating.
	rep, err := svc.CreateReport(bob.ID, ReportInput{TargetType: "review", TargetID: r1.ID, Reason: "spoiler"})
	if err != nil {
		t.Fatalf("CreateReport: %v", err)
	}
	again, _ := svc.CreateReport(bob.ID, ReportInput{TargetType: "review", TargetID: r1.ID, Reason: "spam"})
	if again.ID != rep.ID {
		t.Error("duplicate pending report created")
	}
	if _, err := svc.CreateReport(bob.ID, ReportInput{TargetType: "comment", TargetID: uuid.New(), Reason: "spam"}); !errors.Is(err, ErrNotFound) {
		t.Errorf("report of missing target: err = %v", err)
	}
	views, total, err := svc.AdminListReports(model.ReportPending, 1, 10)
	if err != nil || total != 1 || !strings.HasPrefix(views[0].TargetPreview, "好看: ") || views[0].Reporter == nil {
		t.Errorf("AdminListReports = %+v (total %d, err %v)", views, total, err)
	}
	if _, err := svc.ResolveReport(admin.ID, rep.ID, model.ReportResolved, true); err != nil {
		t.Fatalf("ResolveReport: %v", err)
	}
	if _, total, _ := svc.ListReviews(novel.ID, nil, "", 1, 10); total != 1 {
		t.Errorf("hidden review still listed (total %d)", total)
	}
	if n := reload[model.Novel](t, db, novel.ID); n.AvgRating != 3 || n.ReviewCount != 1 {
		t.Errorf("after hiding: avg_rating = %v, review_count = %d", n.AvgRating, n.ReviewCount)
	}
	if changed == 0 {
		t.Error("novel cache was never invalidated")
	}

	// Comments: replies to replies attach to the thread root.
	root, err := svc.CreateComment(alice.ID, chapters[0].ID, CommentInput{Content: "第一"})
	if err != nil {
		t.Fatalf("CreateComment: %v", err)
	}
	reply, _ := svc.CreateComment(bob.ID, chapters[0].ID, CommentInput{Content: "回覆", ParentID: &root.ID})
	nested, _ := svc.CreateComment(alice.ID, chapters[0].ID, CommentInput{Content: "再回覆", ParentID: &reply.ID})
	if nested.ParentID == nil || *nested.ParentID != root.ID {
		t.Errorf("nested reply parent = %v, want root", nested.ParentID)
	}
	svc.SetLike(alice.ID, model.LikeTargetComment, reply.ID, true)
	comments, total, err := svc.ListComments(chapters[0].ID, &alice.ID, "", nil, 1, 10)
	if err != nil || total != 1 || len(comments[0].Replies) != 2 || !comments[0].Replies[0].LikedByMe {
		t.Errorf("ListComments = %+v (total %d, err %v)", comments, total, err)
	}
	if err := svc.DeleteComment(bob.ID, false, root.ID); !errors.Is(err, ErrForbidden) {
		t.Errorf("deleting someone else's comment: err = %v", err)
	}
	if err := svc.DeleteComment(admin.ID, true, root.ID); err != nil {
		t.Fatalf("admin DeleteComment: %v", err)
	}
	if _, total, _ := svc.ListComments(chapters[0].ID, nil, "", nil, 1, 10); total != 0 {
		t.Errorf("deleted thread still listed")
	}
	var remaining int64
	db.Model(&model.Comment{}).Count(&remaining)
	if remaining != 0 {
		t.Errorf("%d replies survived deleting their thread", remaining)
	}
}

func TestUserSettingsPasswordAndStats(t *testing.T) {
	db := testutil.DB(t)
	svc := NewUserService(db)
	user := testutil.User(t, db, "")

	def, err := svc.ReadingSettings(user.ID)
	if err != nil || def.FontSize != 18 || !def.KeepScreenOn {
		t.Fatalf("defaults = %+v, %v", def, err)
	}
	in := *def
	in.FontSize, in.Theme, in.KeepScreenOn, in.AutoChapter = 24, "dark", false, false
	saved, err := svc.SaveReadingSettings(user.ID, in)
	if err != nil || saved.FontSize != 24 || saved.Theme != "dark" || saved.KeepScreenOn || saved.AutoChapter {
		t.Errorf("saved settings = %+v, %v", saved, err)
	}
	in.FontSize = 20
	if again, _ := svc.SaveReadingSettings(user.ID, in); again.FontSize != 20 || again.KeepScreenOn {
		t.Errorf("updated settings = %+v", again)
	}

	nick := "新暱稱"
	if u, err := svc.UpdateProfile(user.ID, ProfileUpdate{Nickname: &nick}); err != nil || u.Nickname != nick {
		t.Errorf("UpdateProfile = %+v, %v", u, err)
	}
	if err := svc.ChangePassword(user.ID, "wrong-password", "newpassword1"); !errors.Is(err, ErrInvalidCredentials) {
		t.Errorf("wrong current password: err = %v", err)
	}
	if err := svc.ChangePassword(user.ID, "password123", "newpassword1"); err != nil {
		t.Errorf("ChangePassword: %v", err)
	}
	if reload[model.User](t, db, user.ID).PasswordChangedAt == nil {
		t.Error("password_changed_at not set")
	}

	_, chapters := testutil.Novel(t, db, 1)
	db.Create(&model.ReadingHistory{UserID: user.ID, NovelID: chapters[0].NovelID, ChapterID: chapters[0].ID, ReadAt: time.Now(), Duration: 30})
	stats, err := svc.ReadingStats(user.ID, "daily")
	if err != nil {
		t.Fatalf("ReadingStats: %v", err)
	}
	if len(stats.Buckets) != 7 || stats.ChaptersRead != 1 || stats.NovelsRead != 1 {
		t.Fatalf("stats = %+v", stats)
	}
	if b := stats.Buckets[6]; b.Chapters != 1 || b.Seconds != 30 || b.Words != int64(chapters[0].WordCount) {
		t.Errorf("today's bucket = %+v", b)
	}
	if monthly, _ := svc.ReadingStats(user.ID, "monthly"); len(monthly.Buckets) != 12 {
		t.Errorf("monthly buckets = %d", len(monthly.Buckets))
	}
}

func TestAdminCatalogue(t *testing.T) {
	db := testutil.DB(t)
	svc := NewAdminService(db)
	novel, _ := testutil.Novel(t, db, 0)

	inactive := false
	parent, err := svc.SaveCategory(0, CategoryInput{Name: "玄幻", Slug: "xuanhuan", IsActive: &inactive})
	if err != nil {
		t.Fatalf("SaveCategory: %v", err)
	}
	if reload[model.Category](t, db, parent.ID).IsActive {
		t.Error("category saved as active despite is_active=false")
	}
	child, err := svc.SaveCategory(0, CategoryInput{Name: "東方玄幻", Slug: "oriental", ParentID: &parent.ID})
	if err != nil {
		t.Fatalf("child category: %v", err)
	}
	if _, err := svc.SaveCategory(0, CategoryInput{Name: "重複", Slug: "xuanhuan"}); !errors.Is(err, ErrConflict) {
		t.Errorf("duplicate slug: err = %v", err)
	}
	if _, err := svc.SaveCategory(0, CategoryInput{Name: "孫", Slug: "grandchild", ParentID: &child.ID}); !errors.Is(err, ErrNotFound) {
		t.Errorf("third level: err = %v", err)
	}

	ids := []int{child.ID}
	tags := []string{"熱血", " 升級 ", "熱血"}
	if err := svc.SetTaxonomy(novel, &ids, &tags); err != nil {
		t.Fatalf("SetTaxonomy: %v", err)
	}
	loaded, _ := repository.NewNovelRepository(db).FindByID(novel.ID)
	if len(loaded.Categories) != 1 || len(loaded.Tags) != 2 {
		t.Errorf("taxonomy = %v / %v", loaded.Categories, loaded.Tags)
	}
	bad := []int{9999}
	if err := svc.SetTaxonomy(novel, &bad, nil); !errors.Is(err, ErrNotFound) {
		t.Errorf("unknown category: err = %v", err)
	}

	if err := svc.DeleteCategory(parent.ID); !errors.Is(err, ErrHasChildren) {
		t.Errorf("deleting a parent: err = %v", err)
	}
	if err := svc.DeleteCategory(child.ID); err != nil {
		t.Errorf("DeleteCategory: %v", err)
	}

	novels, total, err := svc.ListNovels(AdminNovelFilter{Query: "測試"}, 1, 10)
	if err != nil || total != 1 || len(novels) != 1 {
		t.Errorf("ListNovels = %d, %v", total, err)
	}
	if _, total, _ := svc.ListNovels(AdminNovelFilter{Query: "100%"}, 1, 10); total != 0 {
		t.Errorf("LIKE wildcard not escaped: %d matches", total)
	}
	if stats, err := svc.Stats(); err != nil || stats.Novels != 1 {
		t.Errorf("Stats = %+v, %v", stats, err)
	}
}

type fakeMailer struct{ bodies []string }

func (m *fakeMailer) Send(_, _, body string) error {
	m.bodies = append(m.bodies, body)
	return nil
}

func TestPasswordResetLinkWorksOnce(t *testing.T) {
	db := testutil.DB(t)
	user := testutil.User(t, db, "")
	cfg := &config.Config{JWT: config.JWTConfig{Secret: "test-secret", AccessExpiryHrs: 1, RefreshExpiryDays: 1}, WebBaseURL: "https://web.test"}
	mailer := &fakeMailer{}
	svc := NewAuthService(repository.NewUserRepository(db), cfg, mailer)

	if err := svc.ForgotPassword(&ForgotPasswordRequest{Email: "nobody@example.com"}); err != nil || len(mailer.bodies) != 0 {
		t.Fatalf("unknown email: err %v, %d mails", err, len(mailer.bodies))
	}
	if err := svc.ForgotPassword(&ForgotPasswordRequest{Email: *user.Email}); err != nil || len(mailer.bodies) != 1 {
		t.Fatalf("ForgotPassword: err %v, %d mails", err, len(mailer.bodies))
	}
	_, after, ok := strings.Cut(mailer.bodies[0], "https://web.test/reset-password?token=")
	if !ok {
		t.Fatalf("no reset link in %q", mailer.bodies[0])
	}
	token := strings.Fields(after)[0]

	// The token is issued with second precision; make sure the change below
	// lands in a later second, as it would for a real user.
	time.Sleep(1100 * time.Millisecond)
	if err := svc.ResetPassword(&ResetPasswordRequest{Token: token, NewPassword: "brandnew123"}); err != nil {
		t.Fatalf("ResetPassword: %v", err)
	}
	if err := svc.ResetPassword(&ResetPasswordRequest{Token: token, NewPassword: "another1234"}); !errors.Is(err, ErrInvalidToken) {
		t.Errorf("reused reset link: err = %v, want ErrInvalidToken", err)
	}
	if _, _, err := svc.Login(&LoginRequest{Login: user.Username, Password: "brandnew123"}); err != nil {
		t.Errorf("login with new password: %v", err)
	}
}

func TestHomePage(t *testing.T) {
	db := testutil.DB(t)
	svc := NewHomeService(db, testRedis(t))
	novel, _ := testutil.Novel(t, db, 1)
	db.Model(novel).Updates(map[string]interface{}{"is_featured": true, "status": "completed"})
	repository.NewNovelRepository(db).RefreshStats(novel.ID)
	past := time.Now().Add(-time.Hour)
	db.Create(&model.Banner{Title: "現在", ImageURL: "x", IsActive: true})
	db.Create(&model.Banner{Title: "過期", ImageURL: "x", IsActive: true, EndAt: &past})

	page, err := svc.Home()
	if err != nil {
		t.Fatalf("Home: %v", err)
	}
	if len(page.Banners) != 1 || page.Banners[0].Title != "現在" {
		t.Errorf("banners = %+v", page.Banners)
	}
	for name, list := range map[string][]model.Novel{
		"featured": page.Featured, "latest": page.LatestUpdates, "popular": page.Popular,
		"new": page.NewArrivals, "completed": page.Completed,
	} {
		if len(list) != 1 {
			t.Errorf("%s section has %d novels", name, len(list))
		}
	}
}
