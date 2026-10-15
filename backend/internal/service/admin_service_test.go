package service

import (
	"testing"
	"time"
)

func TestStartOfLocalDay(t *testing.T) {
	// 2026-10-14 20:30 UTC is already 10-15 04:30 in UTC+8.
	now := time.Date(2026, 10, 14, 20, 30, 0, 0, time.UTC)
	cases := []struct {
		offset int
		want   time.Time
	}{
		{0, time.Date(2026, 10, 14, 0, 0, 0, 0, time.UTC)},
		{480, time.Date(2026, 10, 14, 16, 0, 0, 0, time.UTC)},
		{-300, time.Date(2026, 10, 14, 5, 0, 0, 0, time.UTC)},
	}
	for _, c := range cases {
		if got := startOfLocalDay(now, c.offset); !got.Equal(c.want) {
			t.Errorf("offset %d: got %v, want %v", c.offset, got.UTC(), c.want)
		}
	}
}
