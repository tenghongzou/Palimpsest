package handler

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/service"
	"github.com/tenghongzou/palimpsest/backend/internal/testutil"
)

func TestIntParam(t *testing.T) {
	tests := []struct {
		query string
		want  int
	}{
		{"", 30}, {"days=abc", 30}, {"days=7", 7}, {"days=3", 7}, {"days=500", 90}, {"days=45", 45},
	}
	for _, tt := range tests {
		c, _ := gin.CreateTestContext(httptest.NewRecorder())
		c.Request = httptest.NewRequest(http.MethodGet, "/x?"+tt.query, nil)
		if got := intParam(c, "days", 30, 7, 90); got != tt.want {
			t.Errorf("intParam(%q) = %d, want %d", tt.query, got, tt.want)
		}
	}
}

func TestModerateValidation(t *testing.T) {
	h := NewAdminHandler(AdminDeps{})
	r := gin.New()
	r.PUT("/admin/moderation/:type/:id", h.Moderate)
	r.POST("/admin/moderation/terms", h.CreateModerationTerm)
	r.DELETE("/admin/moderation/terms/:termId", h.DeleteModerationTerm)

	id := uuid.NewString()
	cases := []struct{ method, path, body string }{
		{http.MethodPut, "/admin/moderation/novel/" + id, `{"status":"approved"}`},
		{http.MethodPut, "/admin/moderation/review/not-uuid", `{"status":"approved"}`},
		{http.MethodPut, "/admin/moderation/comment/" + id, `{"status":"pending"}`},
		{http.MethodPut, "/admin/moderation/comment/" + id, `{}`},
		{http.MethodPost, "/admin/moderation/terms", `{"term":"x"}`},
		{http.MethodPost, "/admin/moderation/terms", `{"term":"","severity":"block"}`},
		{http.MethodPost, "/admin/moderation/terms", `{"term":"x","severity":"ban"}`},
		{http.MethodPost, "/admin/moderation/terms", `{"term":"` + strings.Repeat("字", 51) + `","severity":"flag"}`},
		{http.MethodDelete, "/admin/moderation/terms/abc", ``},
	}
	for _, tc := range cases {
		w := httptest.NewRecorder()
		req := httptest.NewRequest(tc.method, tc.path, strings.NewReader(tc.body))
		req.Header.Set("Content-Type", "application/json")
		r.ServeHTTP(w, req)
		var resp apiResponse
		_ = json.Unmarshal(w.Body.Bytes(), &resp)
		if w.Code != http.StatusBadRequest || resp.Code != 40001 {
			t.Errorf("%s %s %s: %d %d", tc.method, tc.path, tc.body, w.Code, resp.Code)
		}
	}
}

// TestModerationEndpoints runs against Postgres (TEST_DATABASE_URL).
func TestModerationEndpoints(t *testing.T) {
	db := testutil.DB(t)
	mod := service.NewModerationService(db)
	community := service.NewCommunityService(db, nil).WithModeration(mod)
	admin := NewAdminHandler(AdminDeps{AdminSvc: service.NewAdminService(db), CommunitySvc: community, ModerationSvc: mod, DB: db})
	public := NewCommunityHandler(community)
	user := testutil.User(t, db, "")
	novel, _ := testutil.Novel(t, db, 1)

	r := gin.New()
	// Requests are the user's unless marked anonymous.
	r.Use(func(c *gin.Context) {
		if c.GetHeader("X-Test-Anonymous") == "" {
			c.Set("userID", user.ID)
		}
	})
	r.GET("/admin/moderation/queue", admin.ModerationQueue)
	r.PUT("/admin/moderation/:type/:id", admin.Moderate)
	r.GET("/admin/moderation/terms", admin.ListModerationTerms)
	r.POST("/admin/moderation/terms", admin.CreateModerationTerm)
	r.DELETE("/admin/moderation/terms/:termId", admin.DeleteModerationTerm)
	r.GET("/admin/reviews", admin.ListReviews)
	r.GET("/admin/stats", admin.StatsOverview)
	r.GET("/admin/stats/trends", admin.StatsTrends)
	r.GET("/admin/stats/top-novels", admin.StatsTopNovels)
	r.GET("/admin/stats/categories", admin.StatsCategories)
	r.POST("/novels/:id/reviews", public.CreateReview)
	r.GET("/novels/:id/reviews", public.ListReviews)

	anonymous := false
	do := func(method, path, body string) (int, map[string]json.RawMessage) {
		w := httptest.NewRecorder()
		req := httptest.NewRequest(method, path, bytes.NewBufferString(body))
		req.Header.Set("Content-Type", "application/json")
		if anonymous {
			req.Header.Set("X-Test-Anonymous", "1")
		}
		r.ServeHTTP(w, req)
		var out map[string]json.RawMessage
		if w.Body.Len() > 0 {
			if err := json.Unmarshal(w.Body.Bytes(), &out); err != nil {
				t.Fatalf("%s %s: bad body %s", method, path, w.Body.String())
			}
		}
		return w.Code, out
	}

	code, body := do(http.MethodPost, "/admin/moderation/terms", `{"term":"垃圾","severity":"block"}`)
	var term model.ModerationTerm
	if code != http.StatusCreated || json.Unmarshal(body["data"], &term) != nil || term.ID == 0 || term.Term != "垃圾" {
		t.Fatalf("create term = %d %s", code, body["data"])
	}
	if code, body := do(http.MethodPost, "/admin/moderation/terms", `{"term":"垃 圾","severity":"flag"}`); code != http.StatusConflict || string(body["code"]) != "40906" {
		t.Errorf("duplicate term = %d %s", code, body["code"])
	}
	if code, _ := do(http.MethodPost, "/admin/moderation/terms", `{"term":"！？","severity":"flag"}`); code != http.StatusBadRequest {
		t.Errorf("punctuation term = %d", code)
	}
	if code, body := do(http.MethodGet, "/admin/moderation/terms", ""); code != http.StatusOK || !strings.Contains(string(body["data"]), `"severity":"block"`) {
		t.Errorf("list terms = %d %s", code, body["data"])
	}

	// A held review is created (201) as pending, without moderation details.
	code, body = do(http.MethodPost, "/novels/"+novel.ID.String()+"/reviews", `{"title":"爛","content":"垃圾","rating":1}`)
	var review map[string]json.RawMessage
	if code != http.StatusCreated || json.Unmarshal(body["data"], &review) != nil || string(review["status"]) != `"pending"` {
		t.Fatalf("create review = %d %s", code, body["data"])
	}
	if _, ok := review["moderation"]; ok {
		t.Errorf("public response exposes moderation: %s", body["data"])
	}
	id := strings.Trim(string(review["id"]), `"`)
	anonymous = true
	if _, body := do(http.MethodGet, "/novels/"+novel.ID.String()+"/reviews", ""); strings.Contains(string(body["data"]), id) {
		t.Errorf("pending review listed publicly: %s", body["data"])
	}
	anonymous = false
	// Its author still sees it, as pending.
	if _, body := do(http.MethodGet, "/novels/"+novel.ID.String()+"/reviews", ""); !strings.Contains(string(body["data"]), id) ||
		!strings.Contains(string(body["data"]), `"status":"pending"`) || strings.Contains(string(body["data"]), "moderation") {
		t.Errorf("author's listing: %s", body["data"])
	}
	if _, body := do(http.MethodGet, "/admin/reviews?status=pending", ""); !strings.Contains(string(body["data"]), `"moderation":{"score":1`) {
		t.Errorf("admin listing lacks moderation: %s", body["data"])
	}
	if _, body := do(http.MethodGet, "/admin/stats", ""); !strings.Contains(string(body["data"]), `"pending_moderation":1`) {
		t.Errorf("stats = %s", body["data"])
	}

	code, body = do(http.MethodGet, "/admin/moderation/queue?type=review", "")
	if code != http.StatusOK || !strings.Contains(string(body["data"]), `"type":"review"`) || !strings.Contains(string(body["data"]), `"total":1`) {
		t.Errorf("queue = %d %s", code, body["data"])
	}
	if code, body := do(http.MethodPut, "/admin/moderation/review/"+id, `{"status":"approved"}`); code != http.StatusOK || !strings.Contains(string(body["data"]), `"status":"approved"`) {
		t.Errorf("approve = %d %s", code, body["data"])
	}
	if code, body := do(http.MethodPut, "/admin/moderation/comment/"+id, `{"status":"approved"}`); code != http.StatusNotFound || string(body["code"]) != "40405" {
		t.Errorf("approve missing comment = %d %s", code, body["code"])
	}

	if code, _ := do(http.MethodDelete, "/admin/moderation/terms/"+jsonInt(term.ID), ""); code != http.StatusNoContent {
		t.Errorf("delete term = %d", code)
	}
	if code, _ := do(http.MethodDelete, "/admin/moderation/terms/"+jsonInt(term.ID), ""); code != http.StatusNotFound {
		t.Errorf("delete term again = %d", code)
	}

	code, body = do(http.MethodGet, "/admin/stats/trends?days=500&utc_offset=480", "")
	var trends service.AdminTrends
	if code != http.StatusOK || json.Unmarshal(body["data"], &trends) != nil || len(trends.Days) != 90 {
		t.Errorf("trends = %d (%d days)", code, len(trends.Days))
	}
	for _, path := range []string{"/admin/stats/top-novels", "/admin/stats/categories"} {
		if code, body := do(http.MethodGet, path, ""); code != http.StatusOK || string(body["data"]) != "[]" {
			t.Errorf("%s = %d %s", path, code, body["data"])
		}
	}
}

func jsonInt(n int) string {
	b, _ := json.Marshal(n)
	return string(b)
}
