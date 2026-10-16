package service

import (
	"sync"
	"testing"

	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/repository"
	"github.com/tenghongzou/palimpsest/backend/internal/testutil"
)

// Several devices reporting the first progress of a novel at once must not
// fail on the (user, novel) unique index.
func TestUpdateProgressConcurrentFirstReports(t *testing.T) {
	db := testutil.DB(t)
	svc := NewBookshelfService(repository.NewBookshelfRepository(db), db)
	user := testutil.User(t, db, "")
	novel, chapters := testutil.Novel(t, db, 2)

	const n = 8
	var wg sync.WaitGroup
	errs := make([]error, n)
	for i := range n {
		wg.Add(1)
		go func() {
			defer wg.Done()
			_, errs[i] = svc.UpdateProgress(user.ID, novel.ID, ProgressUpdate{ChapterID: chapters[i%2].ID, Duration: 10})
		}()
	}
	wg.Wait()
	for i, err := range errs {
		if err != nil {
			t.Errorf("report %d: %v", i, err)
		}
	}

	var rows int64
	db.Model(&model.ReadingProgress{}).Where("user_id = ? AND novel_id = ?", user.ID, novel.ID).Count(&rows)
	if rows != 1 {
		t.Errorf("progress rows = %d, want 1", rows)
	}
	if secs := reload[model.User](t, db, user.ID).TotalReadSeconds; secs != n*10 {
		t.Errorf("total_read_seconds = %d, want %d", secs, n*10)
	}
}
