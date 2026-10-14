package middleware

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/alicebob/miniredis/v2"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
)

func TestRejectBanned(t *testing.T) {
	mr := miniredis.RunT(t)
	rdb := redis.NewClient(&redis.Options{Addr: mr.Addr()})
	banned, active := uuid.New(), uuid.New()
	rdb.Set(context.Background(), BannedUserKey(banned), "1", BanTTL)

	for _, tc := range []struct {
		user *uuid.UUID
		want int
	}{
		{&banned, http.StatusForbidden},
		{&active, http.StatusOK},
		{nil, http.StatusOK},
	} {
		r := gin.New()
		r.GET("/", func(c *gin.Context) {
			if tc.user != nil {
				c.Set("userID", *tc.user)
			}
		}, RejectBanned(rdb), func(c *gin.Context) { c.Status(http.StatusOK) })
		w := httptest.NewRecorder()
		r.ServeHTTP(w, httptest.NewRequest(http.MethodGet, "/", nil))
		if w.Code != tc.want {
			t.Errorf("user %v: status %d, want %d", tc.user, w.Code, tc.want)
		}
	}
}
