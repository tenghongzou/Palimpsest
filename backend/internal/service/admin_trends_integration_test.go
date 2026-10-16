package service

import (
	"math"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/testutil"
	"gorm.io/gorm"
)

func readAt(t *testing.T, db *gorm.DB, userID, novelID, chapterID uuid.UUID, at time.Time, seconds int) {
	t.Helper()
	h := model.ReadingHistory{UserID: userID, NovelID: novelID, ChapterID: chapterID, ReadAt: at, Duration: seconds}
	if err := db.Create(&h).Error; err != nil {
		t.Fatalf("create reading history: %v", err)
	}
}

func TestAdminTrends(t *testing.T) {
	db := testutil.DB(t)
	svc := NewAdminService(db)
	novel, chapters := testutil.Novel(t, db, 1)
	ch := chapters[0].ID
	a := testutil.User(t, db, "")
	b := testutil.User(t, db, "")
	c := testutil.User(t, db, "")

	// 2026-10-14 20:30 UTC is 10-15 04:30 in UTC+8.
	now := time.Date(2026, 10, 14, 20, 30, 0, 0, time.UTC)
	lateUTC := time.Date(2026, 10, 14, 17, 0, 0, 0, time.UTC)  // 10-15 01:00 in UTC+8
	earlyUTC := time.Date(2026, 10, 14, 15, 0, 0, 0, time.UTC) // 10-14 23:00 in UTC+8
	earlier := time.Date(2026, 10, 5, 3, 0, 0, 0, time.UTC)

	readAt(t, db, a.ID, novel.ID, ch, lateUTC, 60)
	readAt(t, db, a.ID, novel.ID, ch, lateUTC.Add(time.Minute), 30)
	readAt(t, db, b.ID, novel.ID, ch, earlyUTC, 10)
	// Before the last 7 days: A comes back, B does too (above), C does not.
	readAt(t, db, a.ID, novel.ID, ch, earlier, 5)
	readAt(t, db, c.ID, novel.ID, ch, earlier, 5)
	// 10-08 23:00 in UTC+8: outside a 7-day window, inside the earlier week.
	readAt(t, db, c.ID, novel.ID, ch, time.Date(2026, 10, 8, 15, 0, 0, 0, time.UTC), 5)
	readAt(t, db, b.ID, novel.ID, ch, earlier, 5)

	db.Model(&model.User{}).Where("id = ?", a.ID).UpdateColumn("created_at", lateUTC)
	db.Model(&model.User{}).Where("id = ?", b.ID).UpdateColumn("created_at", earlier)
	db.Model(&model.User{}).Where("id = ?", c.ID).UpdateColumn("created_at", earlier)
	review := model.Review{UserID: a.ID, NovelID: novel.ID, Title: "t", Content: "c", Rating: 4, Status: StatusApproved, CreatedAt: earlyUTC}
	comment := model.Comment{UserID: a.ID, ChapterID: ch, Content: "c", Status: StatusApproved, CreatedAt: lateUTC}
	gone := model.Comment{UserID: b.ID, ChapterID: ch, Content: "deleted", Status: StatusApproved, CreatedAt: lateUTC}
	shelf := model.BookshelfItem{UserID: a.ID, NovelID: novel.ID, AddedAt: lateUTC}
	for _, v := range []interface{}{&review, &comment, &gone, &shelf} {
		if err := db.Create(v).Error; err != nil {
			t.Fatal(err)
		}
	}
	db.Delete(&gone)

	day := func(tr *AdminTrends, date string) AdminTrendDay {
		for _, d := range tr.Days {
			if d.Date == date {
				return d
			}
		}
		t.Fatalf("no entry for %s in %+v", date, tr.Days)
		return AdminTrendDay{}
	}

	local, err := svc.trendsAt(now, 7, 480)
	if err != nil {
		t.Fatalf("trends: %v", err)
	}
	if len(local.Days) != 7 || local.Days[0].Date != "2026-10-09" || local.Days[6].Date != "2026-10-15" {
		t.Fatalf("days = %+v", local.Days)
	}
	want15 := AdminTrendDay{Date: "2026-10-15", NewUsers: 1, ActiveReaders: 1, Reads: 2, ReadingSeconds: 90, NewComments: 1, BookshelfAdds: 1}
	if got := day(local, "2026-10-15"); got != want15 {
		t.Errorf("10-15 = %+v, want %+v", got, want15)
	}
	want14 := AdminTrendDay{Date: "2026-10-14", ActiveReaders: 1, Reads: 1, ReadingSeconds: 10, NewReviews: 1}
	if got := day(local, "2026-10-14"); got != want14 {
		t.Errorf("10-14 = %+v, want %+v", got, want14)
	}
	if got := day(local, "2026-10-10"); got != (AdminTrendDay{Date: "2026-10-10"}) {
		t.Errorf("quiet day = %+v", got)
	}
	// A and B read in the earlier week and again in the last 7 days; C did not.
	if math.Abs(local.ReturningRate-2.0/3) > 1e-9 {
		t.Errorf("returning_rate = %v, want 2/3", local.ReturningRate)
	}

	// In UTC every read of the last two days falls on 10-14.
	utc, err := svc.trendsAt(now, 30, 0)
	if err != nil {
		t.Fatal(err)
	}
	if len(utc.Days) != 30 || utc.Days[29].Date != "2026-10-14" {
		t.Fatalf("utc days = %d, last %s", len(utc.Days), utc.Days[len(utc.Days)-1].Date)
	}
	if got := day(utc, "2026-10-14"); got.Reads != 3 || got.ActiveReaders != 2 || got.NewUsers != 1 {
		t.Errorf("utc 10-14 = %+v", got)
	}
	if got := day(utc, "2026-10-05"); got.Reads != 3 || got.NewUsers != 2 {
		t.Errorf("utc 10-05 = %+v", got)
	}

	// No readers in the earlier week means a rate of 0.
	if empty, _ := svc.trendsAt(now.AddDate(1, 0, 0), 7, 0); empty.ReturningRate != 0 {
		t.Errorf("rate without readers = %v", empty.ReturningRate)
	}
}

func TestAdminTopNovelsAndCategories(t *testing.T) {
	db := testutil.DB(t)
	svc := NewAdminService(db)
	fantasy := model.Category{Name: "玄幻", Slug: "fantasy"}
	urban := model.Category{Name: "都市", Slug: "urban"}
	db.Create(&fantasy)
	db.Create(&urban)
	novel := func(title string, cats ...model.Category) (*model.Novel, uuid.UUID) {
		n := &model.Novel{Title: title, AuthorName: "A", IsPublished: true, Categories: cats}
		if err := db.Create(n).Error; err != nil {
			t.Fatal(err)
		}
		ch := model.Chapter{NovelID: n.ID, Title: "1", ChapterNumber: 1, Content: "x", IsPublished: true}
		db.Create(&ch)
		return n, ch.ID
	}
	first, ch1 := novel("一", fantasy, urban)
	second, ch2 := novel("二", urban)
	deleted, ch3 := novel("三", fantasy)
	u1, u2 := testutil.User(t, db, ""), testutil.User(t, db, "")
	recent := time.Now().Add(-time.Hour)
	readAt(t, db, u1.ID, first.ID, ch1, recent, 10)
	readAt(t, db, u1.ID, first.ID, ch1, recent, 10)
	readAt(t, db, u2.ID, second.ID, ch2, recent, 10)
	readAt(t, db, u2.ID, second.ID, ch2, recent, 10)
	readAt(t, db, u1.ID, first.ID, ch1, time.Now().AddDate(0, 0, -20), 10) // outside 7 days
	for i := 0; i < 5; i++ {
		readAt(t, db, u1.ID, deleted.ID, ch3, recent, 10)
	}
	db.Delete(deleted)
	db.Create(&model.BookshelfItem{UserID: u2.ID, NovelID: second.ID})

	top, err := svc.TopNovels(7, 10, 0)
	if err != nil {
		t.Fatalf("TopNovels: %v", err)
	}
	// Equal reads: second has as many readers, so the id breaks the tie;
	// what matters is that both appear and the deleted novel does not.
	if len(top) != 2 {
		t.Fatalf("top = %+v", top)
	}
	for _, e := range top {
		switch e.Novel.ID {
		case first.ID:
			if e.Reads != 2 || e.Readers != 1 || e.BookshelfAdds != 0 || len(e.Novel.Categories) != 2 {
				t.Errorf("first = %+v", e)
			}
		case second.ID:
			if e.Reads != 2 || e.Readers != 1 || e.BookshelfAdds != 1 {
				t.Errorf("second = %+v", e)
			}
		default:
			t.Errorf("unexpected novel %s", e.Novel.Title)
		}
	}
	readAt(t, db, u2.ID, first.ID, ch1, recent, 10)
	if top, _ := svc.TopNovels(30, 1, 480); len(top) != 1 || top[0].Novel.ID != first.ID || top[0].Reads != 4 || top[0].Readers != 2 {
		t.Errorf("top 1 over 30 days = %+v", top)
	}

	cats, err := svc.CategoryStats(7, 0)
	if err != nil {
		t.Fatalf("CategoryStats: %v", err)
	}
	// urban: first (3 reads) + second (2); fantasy: first only (deleted novel ignored).
	if len(cats) != 2 || cats[0].Category.Slug != "urban" || cats[0].Reads != 5 || cats[0].Readers != 2 ||
		cats[1].Category.Slug != "fantasy" || cats[1].Reads != 3 || cats[1].Readers != 2 {
		t.Errorf("categories = %+v", cats)
	}
}

func TestAdminStatsOneDayIsToday(t *testing.T) {
	db := testutil.DB(t)
	svc := NewAdminService(db)
	fantasy := model.Category{Name: "玄幻", Slug: "fantasy"}
	db.Create(&fantasy)
	novel := &model.Novel{Title: "一", AuthorName: "A", IsPublished: true, Categories: []model.Category{fantasy}}
	db.Create(novel)
	ch := model.Chapter{NovelID: novel.ID, Title: "1", ChapterNumber: 1, Content: "x", IsPublished: true}
	db.Create(&ch)
	user := testutil.User(t, db, "")

	// days=1 starts at the client's local midnight, not 24 hours ago.
	const offset = 480
	midnight := startOfLocalDay(time.Now(), offset)
	readAt(t, db, user.ID, novel.ID, ch.ID, midnight.Add(-time.Second), 10)
	want := int64(0)
	if since := time.Since(midnight); since > 2*time.Second {
		readAt(t, db, user.ID, novel.ID, ch.ID, midnight.Add(since/2), 10)
		want = 1
	}
	top, err := svc.TopNovels(1, 10, offset)
	if err != nil || int64(len(top)) != want || (want == 1 && top[0].Reads != 1) {
		t.Errorf("today's top = %+v, %v", top, err)
	}
	cats, err := svc.CategoryStats(1, offset)
	if err != nil || int64(len(cats)) != want || (want == 1 && cats[0].Reads != 1) {
		t.Errorf("today's categories = %+v, %v", cats, err)
	}
}
