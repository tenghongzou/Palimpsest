package service

import (
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/repository"
	"github.com/tenghongzou/palimpsest/backend/internal/testutil"
	"gorm.io/gorm"
)

// These tests run against Postgres (TEST_DATABASE_URL) and skip without it.

type recFixture struct {
	db      *gorm.DB
	fantasy model.Category
	romance model.Category
	urban   model.Category
	xianxia model.Tag
	system  model.Tag
}

func newRecFixture(t *testing.T) *recFixture {
	t.Helper()
	db := testutil.DB(t)
	f := &recFixture{
		db:      db,
		fantasy: model.Category{Name: "玄幻", Slug: "fantasy"},
		romance: model.Category{Name: "言情", Slug: "romance"},
		urban:   model.Category{Name: "都市", Slug: "urban"},
		xianxia: model.Tag{Name: "修仙"},
		system:  model.Tag{Name: "系統"},
	}
	for _, c := range []*model.Category{&f.fantasy, &f.romance, &f.urban} {
		if err := db.Create(c).Error; err != nil {
			t.Fatalf("create category: %v", err)
		}
	}
	for _, tag := range []*model.Tag{&f.xianxia, &f.system} {
		if err := db.Create(tag).Error; err != nil {
			t.Fatalf("create tag: %v", err)
		}
	}
	return f
}

// novel creates a published novel with the given author, views, categories and tags.
func (f *recFixture) novel(t *testing.T, title, author string, views int64, cats []model.Category, tags []model.Tag) *model.Novel {
	t.Helper()
	n := &model.Novel{Title: title, AuthorName: author, ViewCount: views, IsPublished: true, Categories: cats, Tags: tags}
	if err := f.db.Create(n).Error; err != nil {
		t.Fatalf("create novel %s: %v", title, err)
	}
	return n
}

func (f *recFixture) chapter(t *testing.T, novelID uuid.UUID) *model.Chapter {
	t.Helper()
	ch := &model.Chapter{NovelID: novelID, Title: "第1章", ChapterNumber: 1, Content: "內容", IsPublished: true}
	if err := f.db.Create(ch).Error; err != nil {
		t.Fatalf("create chapter: %v", err)
	}
	return ch
}

func newRecService(t *testing.T, db *gorm.DB, cached bool) *RecommendationService {
	t.Helper()
	var cache *repository.CacheRepository
	if cached {
		cache = repository.NewCacheRepository(testRedis(t))
	}
	return NewRecommendationService(repository.NewRecommendationRepository(db), repository.NewNovelRepository(db), cache)
}

func titles(items []Recommendation) []string {
	out := make([]string, len(items))
	for i, it := range items {
		out[i] = it.Novel.Title
	}
	return out
}

func novelTitles(novels []model.Novel) []string {
	out := make([]string, len(novels))
	for i, n := range novels {
		out[i] = n.Title
	}
	return out
}

func equalStrings(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

func TestRecommendationsPopularFallback(t *testing.T) {
	f := newRecFixture(t)
	f.novel(t, "low", "甲", 10, nil, nil)
	f.novel(t, "high", "乙", 5000, nil, nil)
	f.novel(t, "mid", "丙", 300, []model.Category{f.fantasy}, nil)
	hidden := &model.Novel{Title: "draft", AuthorName: "丁", ViewCount: 99999}
	if err := f.db.Create(hidden).Error; err != nil {
		t.Fatal(err)
	}
	svc := newRecService(t, f.db, true)

	recs, err := svc.Recommend(nil, 12)
	if err != nil {
		t.Fatalf("Recommend: %v", err)
	}
	if recs.Personalized {
		t.Error("anonymous recommendations are personalized")
	}
	if got, want := titles(recs.Items), []string{"high", "mid", "low"}; !equalStrings(got, want) {
		t.Errorf("anonymous = %v, want %v", got, want)
	}
	for _, it := range recs.Items {
		if it.Reason.Type != ReasonPopular || it.Reason.Value != "" {
			t.Errorf("reason of %s = %+v, want popular", it.Novel.Title, it.Reason)
		}
	}
	if len(recs.Items) > 0 && len(recs.Items[1].Novel.Categories) != 1 {
		t.Errorf("categories not loaded: %+v", recs.Items[1].Novel)
	}

	// Limits are clamped.
	if recs, _ := svc.Recommend(nil, 2); len(recs.Items) != 2 {
		t.Errorf("limit 2 returned %d items", len(recs.Items))
	}
	if recs, _ := svc.Recommend(nil, -5); len(recs.Items) != 1 {
		t.Errorf("limit -5 returned %d items, want 1", len(recs.Items))
	}

	// A signed-in reader without signals gets popular novels too.
	user := testutil.User(t, f.db, "")
	recs, err = svc.Recommend(&user.ID, 12)
	if err != nil {
		t.Fatalf("Recommend new user: %v", err)
	}
	if recs.Personalized || len(recs.Items) != 3 {
		t.Errorf("new user = personalized %v, %v", recs.Personalized, titles(recs.Items))
	}

	// Anonymous results are cached.
	f.novel(t, "newcomer", "戊", 1000000, nil, nil)
	if recs, _ := svc.Recommend(nil, 12); len(recs.Items) != 3 {
		t.Errorf("cached anonymous list changed: %v", titles(recs.Items))
	}
}

func TestRecommendationsPersonalized(t *testing.T) {
	f := newRecFixture(t)
	db := f.db
	user := testutil.User(t, db, "")

	shelved := f.novel(t, "shelved", "A", 100, []model.Category{f.fantasy}, []model.Tag{f.xianxia})
	read := f.novel(t, "read", "B", 100, []model.Category{f.romance}, nil)
	inProgress := f.novel(t, "in-progress", "P", 100000, []model.Category{f.fantasy}, nil)
	c1 := f.novel(t, "fantasy-xianxia", "X", 10, []model.Category{f.fantasy}, []model.Tag{f.xianxia})
	f.novel(t, "romance-popular", "Y", 1000000, []model.Category{f.romance}, nil)
	f.novel(t, "xianxia-only", "Z", 10, nil, []model.Tag{f.xianxia})
	f.novel(t, "same-author", "A", 10, nil, nil)
	f.novel(t, "unrelated", "W", 50, []model.Category{f.urban}, []model.Tag{f.system})

	bookshelf := NewBookshelfService(repository.NewBookshelfRepository(db), db)
	if _, err := bookshelf.Add(user.ID, shelved.ID, ""); err != nil {
		t.Fatal(err)
	}
	ch := f.chapter(t, read.ID)
	history := model.ReadingHistory{UserID: user.ID, NovelID: read.ID, ChapterID: ch.ID, ReadAt: time.Now().Add(-time.Hour), Duration: 600}
	if err := db.Create(&history).Error; err != nil {
		t.Fatal(err)
	}
	progress := model.ReadingProgress{UserID: user.ID, NovelID: inProgress.ID, ChapterID: f.chapter(t, inProgress.ID).ID}
	if err := db.Create(&progress).Error; err != nil {
		t.Fatal(err)
	}
	// A low rating is not a signal.
	review := model.Review{UserID: user.ID, NovelID: read.ID, Title: "meh", Content: "meh", Rating: 2}
	if err := db.Create(&review).Error; err != nil {
		t.Fatal(err)
	}

	svc := newRecService(t, db, true)
	bookshelf.OnChange(svc.InvalidateUser)

	recs, err := svc.Recommend(&user.ID, 10)
	if err != nil {
		t.Fatalf("Recommend: %v", err)
	}
	if !recs.Personalized {
		t.Error("personalized = false")
	}
	want := []string{"fantasy-xianxia", "same-author", "romance-popular", "xianxia-only", "unrelated"}
	if got := titles(recs.Items); !equalStrings(got, want) {
		t.Fatalf("recommendations = %v, want %v", got, want)
	}
	wantReasons := []RecommendationReason{
		{ReasonCategory, "玄幻"}, {ReasonAuthor, "A"}, {ReasonCategory, "言情"}, {ReasonTag, "修仙"}, {ReasonPopular, ""},
	}
	for i, it := range recs.Items {
		if it.Reason != wantReasons[i] {
			t.Errorf("reason of %s = %+v, want %+v", it.Novel.Title, it.Reason, wantReasons[i])
		}
	}

	// The limit cuts the scored list before padding.
	short, err := svc.Recommend(&user.ID, 2)
	if err != nil {
		t.Fatal(err)
	}
	if got := titles(short.Items); !equalStrings(got, want[:2]) || !short.Personalized {
		t.Errorf("limit 2 = %v (personalized %v)", got, short.Personalized)
	}

	// Shelving a recommended novel drops the cached list.
	if _, err := bookshelf.Add(user.ID, c1.ID, ""); err != nil {
		t.Fatal(err)
	}
	recs, err = svc.Recommend(&user.ID, 10)
	if err != nil {
		t.Fatal(err)
	}
	for _, it := range recs.Items {
		if it.Novel.ID == c1.ID {
			t.Errorf("shelved novel still recommended: %v", titles(recs.Items))
		}
	}
	if recs.Items[0].Novel.Title != "same-author" {
		t.Errorf("after shelving = %v", titles(recs.Items))
	}
}

func TestSimilarNovels(t *testing.T) {
	f := newRecFixture(t)
	db := f.db
	base := f.novel(t, "base", "A", 10, []model.Category{f.fantasy}, []model.Tag{f.xianxia, f.system})
	f.novel(t, "same-cat-and-tags", "X", 1, []model.Category{f.fantasy}, []model.Tag{f.xianxia, f.system})
	f.novel(t, "same-cat", "Y", 1000, []model.Category{f.fantasy}, nil)
	f.novel(t, "same-author", "A", 1, nil, nil)
	f.novel(t, "one-tag", "Z", 1, []model.Category{f.urban}, []model.Tag{f.system})
	f.novel(t, "unrelated", "W", 1000000, []model.Category{f.romance}, nil)
	draft := &model.Novel{Title: "draft", AuthorName: "A", Categories: []model.Category{f.fantasy}}
	if err := db.Create(draft).Error; err != nil {
		t.Fatal(err)
	}
	deleted := f.novel(t, "deleted", "A", 1, []model.Category{f.fantasy}, nil)
	db.Delete(deleted)
	lonely := f.novel(t, "lonely", "L", 1, nil, nil)

	svc := newRecService(t, db, false)
	novels, err := svc.Similar(base.ID, 6)
	if err != nil {
		t.Fatalf("Similar: %v", err)
	}
	want := []string{"same-cat-and-tags", "same-cat", "same-author", "one-tag"}
	if got := novelTitles(novels); !equalStrings(got, want) {
		t.Errorf("similar = %v, want %v", got, want)
	}
	if novels, _ := svc.Similar(base.ID, 2); !equalStrings(novelTitles(novels), want[:2]) {
		t.Errorf("limit 2 = %v", novelTitles(novels))
	}

	if novels, err := svc.Similar(lonely.ID, 6); err != nil || novels == nil || len(novels) != 0 {
		t.Errorf("lonely novel = %v, %v; want empty slice", novels, err)
	}
	for name, id := range map[string]uuid.UUID{"unpublished": draft.ID, "deleted": deleted.ID, "unknown": uuid.New()} {
		if _, err := svc.Similar(id, 6); !errors.Is(err, ErrNotFound) {
			t.Errorf("%s novel: err = %v, want ErrNotFound", name, err)
		}
	}
}

func TestRecommendationsFromReviews(t *testing.T) {
	f := newRecFixture(t)
	user := testutil.User(t, f.db, "")
	liked := f.novel(t, "liked", "R", 1, []model.Category{f.urban}, nil)
	f.novel(t, "urban-pick", "S", 1, []model.Category{f.urban}, nil)
	f.novel(t, "other", "T", 100, []model.Category{f.romance}, nil)
	review := model.Review{UserID: user.ID, NovelID: liked.ID, Title: "好看", Content: "好看", Rating: 4.5}
	if err := f.db.Create(&review).Error; err != nil {
		t.Fatal(err)
	}

	recs, err := newRecService(t, f.db, false).Recommend(&user.ID, 12)
	if err != nil {
		t.Fatalf("Recommend: %v", err)
	}
	// The reviewed novel itself is left out.
	if got, want := titles(recs.Items), []string{"urban-pick", "other"}; !recs.Personalized || !equalStrings(got, want) {
		t.Fatalf("recommendations = %v (personalized %v), want %v", got, recs.Personalized, want)
	}
	if r := recs.Items[0].Reason; r != (RecommendationReason{ReasonCategory, "都市"}) {
		t.Errorf("reason = %+v", r)
	}
}
