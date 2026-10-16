package service

import (
	"time"

	"github.com/google/uuid"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
)

// AdminTrendDay is one local day of dashboard activity.
type AdminTrendDay struct {
	Date           string `json:"date"`
	NewUsers       int64  `json:"new_users"`
	ActiveReaders  int64  `json:"active_readers"`
	Reads          int64  `json:"reads"`
	ReadingSeconds int64  `json:"reading_seconds"`
	NewReviews     int64  `json:"new_reviews"`
	NewComments    int64  `json:"new_comments"`
	BookshelfAdds  int64  `json:"bookshelf_adds"`
}

// AdminTrends is the dashboard's daily series.
type AdminTrends struct {
	Days []AdminTrendDay `json:"days"`
	// ReturningRate is the share of readers active in the 7 days before the
	// last 7 who read again in the last 7 days.
	ReturningRate float64 `json:"returning_rate"`
}

// AdminTopNovel is a novel's reading activity over a window.
type AdminTopNovel struct {
	Novel         model.Novel `json:"novel"`
	Reads         int64       `json:"reads"`
	Readers       int64       `json:"readers"`
	BookshelfAdds int64       `json:"bookshelf_adds"`
}

// AdminCategoryRef identifies a category in statistics.
type AdminCategoryRef struct {
	ID   int    `json:"id"`
	Name string `json:"name"`
	Slug string `json:"slug"`
}

// AdminCategoryStat is a category's reading activity over a window.
type AdminCategoryStat struct {
	Category AdminCategoryRef `json:"category"`
	Reads    int64            `json:"reads"`
	Readers  int64            `json:"readers"`
}

// localWindow is the span of the last days local days, ending with today,
// for a client utcOffsetMinutes east of UTC.
func localWindow(now time.Time, days, utcOffsetMinutes int) (from, to time.Time) {
	today := startOfLocalDay(now, utcOffsetMinutes)
	return today.AddDate(0, 0, -(days - 1)), today.AddDate(0, 0, 1)
}

// localDay is the SQL for the client's local date of a timestamptz column,
// as YYYY-MM-DD; the offset in minutes is its single parameter.
func localDay(column string) string {
	return "to_char((" + column + " AT TIME ZONE 'UTC') + make_interval(mins => ?), 'YYYY-MM-DD')"
}

// Trends returns one entry per local day for the last days days, oldest
// first, with days without activity included.
func (s *AdminService) Trends(days, utcOffsetMinutes int) (*AdminTrends, error) {
	return s.trendsAt(time.Now(), days, utcOffsetMinutes)
}

func (s *AdminService) trendsAt(now time.Time, days, utcOffsetMinutes int) (*AdminTrends, error) {
	from, to := localWindow(now, days, utcOffsetMinutes)
	zone := time.FixedZone("", utcOffsetMinutes*60)
	series := make([]AdminTrendDay, days)
	index := make(map[string]*AdminTrendDay, days)
	for i := range series {
		series[i].Date = from.In(zone).AddDate(0, 0, i).Format("2006-01-02")
		index[series[i].Date] = &series[i]
	}

	type count struct {
		Day string
		N   int64
	}
	counts := []struct {
		table, column, extra string
		set                  func(d *AdminTrendDay, n int64)
	}{
		{"users", "created_at", "deleted_at IS NULL", func(d *AdminTrendDay, n int64) { d.NewUsers = n }},
		{"reviews", "created_at", "", func(d *AdminTrendDay, n int64) { d.NewReviews = n }},
		{"comments", "created_at", "deleted_at IS NULL", func(d *AdminTrendDay, n int64) { d.NewComments = n }},
		{"bookshelf_items", "added_at", "", func(d *AdminTrendDay, n int64) { d.BookshelfAdds = n }},
	}
	for _, c := range counts {
		var rows []count
		q := s.db.Table(c.table).Select(localDay(c.column)+" AS day, COUNT(*) AS n", utcOffsetMinutes).
			Where(c.column+" >= ? AND "+c.column+" < ?", from, to)
		if c.extra != "" {
			q = q.Where(c.extra)
		}
		if err := q.Group("day").Scan(&rows).Error; err != nil {
			return nil, err
		}
		for _, r := range rows {
			if d := index[r.Day]; d != nil {
				c.set(d, r.N)
			}
		}
	}

	var reading []struct {
		Day     string
		Reads   int64
		Readers int64
		Seconds int64
	}
	err := s.db.Table("reading_history").
		Select(localDay("read_at")+" AS day, COUNT(*) AS reads, COUNT(DISTINCT user_id) AS readers, COALESCE(SUM(duration), 0) AS seconds", utcOffsetMinutes).
		Where("read_at >= ? AND read_at < ?", from, to).Group("day").Scan(&reading).Error
	if err != nil {
		return nil, err
	}
	for _, r := range reading {
		if d := index[r.Day]; d != nil {
			d.Reads, d.ActiveReaders, d.ReadingSeconds = r.Reads, r.Readers, r.Seconds
		}
	}

	rate, err := s.returningRate(now, utcOffsetMinutes)
	if err != nil {
		return nil, err
	}
	return &AdminTrends{Days: series, ReturningRate: rate}, nil
}

// returningRate is the share of readers of the 7 local days before the last
// 7 who read again in the last 7 (today included); 0 without such readers.
func (s *AdminService) returningRate(now time.Time, utcOffsetMinutes int) (float64, error) {
	recentFrom, recentTo := localWindow(now, 7, utcOffsetMinutes)
	earlierFrom := recentFrom.AddDate(0, 0, -7)
	var r struct {
		Earlier  int64
		Returned int64
	}
	err := s.db.Raw(`
		SELECT COUNT(*) AS earlier,
			COUNT(*) FILTER (WHERE EXISTS (
				SELECT 1 FROM reading_history r
				WHERE r.user_id = e.user_id AND r.read_at >= ? AND r.read_at < ?)) AS returned
		FROM (SELECT DISTINCT user_id FROM reading_history WHERE read_at >= ? AND read_at < ?) e`,
		recentFrom, recentTo, earlierFrom, recentFrom).Scan(&r).Error
	if err != nil || r.Earlier == 0 {
		return 0, err
	}
	return float64(r.Returned) / float64(r.Earlier), nil
}

// TopNovels returns the most-read existing novels over the last days local
// days, by reads, then readers.
func (s *AdminService) TopNovels(days, limit, utcOffsetMinutes int) ([]AdminTopNovel, error) {
	from, to := localWindow(time.Now(), days, utcOffsetMinutes)
	var rows []struct {
		NovelID uuid.UUID
		Reads   int64
		Readers int64
	}
	err := s.db.Table("reading_history AS rh").
		Select("rh.novel_id, COUNT(*) AS reads, COUNT(DISTINCT rh.user_id) AS readers").
		Joins("JOIN novels n ON n.id = rh.novel_id AND n.deleted_at IS NULL").
		Where("rh.read_at >= ? AND rh.read_at < ?", from, to).
		Group("rh.novel_id").Order("reads DESC, readers DESC, rh.novel_id").Limit(limit).Scan(&rows).Error
	if err != nil {
		return nil, err
	}
	top := []AdminTopNovel{}
	if len(rows) == 0 {
		return top, nil
	}
	ids := make([]uuid.UUID, len(rows))
	for i, r := range rows {
		ids[i] = r.NovelID
	}
	var novels []model.Novel
	if err := s.db.Preload("Categories").Preload("Tags").Where("id IN ?", ids).Find(&novels).Error; err != nil {
		return nil, err
	}
	byID := make(map[uuid.UUID]model.Novel, len(novels))
	for _, n := range novels {
		byID[n.ID] = n
	}
	var adds []struct {
		NovelID uuid.UUID
		N       int64
	}
	err = s.db.Table("bookshelf_items").Select("novel_id, COUNT(*) AS n").
		Where("added_at >= ? AND added_at < ? AND novel_id IN ?", from, to, ids).
		Group("novel_id").Scan(&adds).Error
	if err != nil {
		return nil, err
	}
	addsByID := make(map[uuid.UUID]int64, len(adds))
	for _, a := range adds {
		addsByID[a.NovelID] = a.N
	}
	for _, r := range rows {
		novel, ok := byID[r.NovelID]
		if !ok {
			continue // deleted meanwhile
		}
		top = append(top, AdminTopNovel{Novel: novel, Reads: r.Reads, Readers: r.Readers, BookshelfAdds: addsByID[r.NovelID]})
	}
	return top, nil
}

// CategoryStats returns reads per category over the last days local days;
// a read counts once for each category of its novel.
func (s *AdminService) CategoryStats(days, utcOffsetMinutes int) ([]AdminCategoryStat, error) {
	from, to := localWindow(time.Now(), days, utcOffsetMinutes)
	var rows []struct {
		ID      int
		Name    string
		Slug    string
		Reads   int64
		Readers int64
	}
	err := s.db.Table("reading_history AS rh").
		Select("c.id, c.name, c.slug, COUNT(*) AS reads, COUNT(DISTINCT rh.user_id) AS readers").
		Joins("JOIN novels n ON n.id = rh.novel_id AND n.deleted_at IS NULL").
		Joins("JOIN novel_categories nc ON nc.novel_id = rh.novel_id").
		Joins("JOIN categories c ON c.id = nc.category_id").
		Where("rh.read_at >= ? AND rh.read_at < ?", from, to).
		Group("c.id, c.name, c.slug").Order("reads DESC, readers DESC, c.id").Scan(&rows).Error
	if err != nil {
		return nil, err
	}
	stats := make([]AdminCategoryStat, len(rows))
	for i, r := range rows {
		stats[i] = AdminCategoryStat{Category: AdminCategoryRef{ID: r.ID, Name: r.Name, Slug: r.Slug}, Reads: r.Reads, Readers: r.Readers}
	}
	return stats, nil
}
