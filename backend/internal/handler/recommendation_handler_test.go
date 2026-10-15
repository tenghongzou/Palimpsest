package handler

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/repository"
	"github.com/tenghongzou/palimpsest/backend/internal/service"
	"github.com/tenghongzou/palimpsest/backend/internal/testutil"
)

func TestLimitParam(t *testing.T) {
	tests := []struct {
		query string
		want  int
	}{
		{"", 12}, {"limit=abc", 12}, {"limit=5", 5}, {"limit=0", 1}, {"limit=-3", 1}, {"limit=31", 30}, {"limit=30", 30},
	}
	for _, tt := range tests {
		c, _ := gin.CreateTestContext(httptest.NewRecorder())
		c.Request = httptest.NewRequest(http.MethodGet, "/recommendations?"+tt.query, nil)
		if got := limitParam(c, 12, 30); got != tt.want {
			t.Errorf("limitParam(%q) = %d, want %d", tt.query, got, tt.want)
		}
	}
}

func TestSimilarInvalidUUID(t *testing.T) {
	r := gin.New()
	r.GET("/novels/:id/similar", NewRecommendationHandler(nil).Similar)

	w := httptest.NewRecorder()
	r.ServeHTTP(w, httptest.NewRequest(http.MethodGet, "/novels/not-a-uuid/similar", nil))
	if w.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400", w.Code)
	}
	var resp apiResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil || resp.Code != 40001 {
		t.Errorf("code = %d (%v), want 40001", resp.Code, err)
	}
}

// TestRecommendationEndpoints runs against Postgres (TEST_DATABASE_URL).
func TestRecommendationEndpoints(t *testing.T) {
	db := testutil.DB(t)
	h := NewRecommendationHandler(service.NewRecommendationService(
		repository.NewRecommendationRepository(db), repository.NewNovelRepository(db), nil))
	r := gin.New()
	r.GET("/recommendations", h.Recommendations)
	r.GET("/novels/:id/similar", h.Similar)

	lonely, _ := testutil.Novel(t, db, 0)
	draft := &model.Novel{Title: "draft", AuthorName: "someone"}
	if err := db.Create(draft).Error; err != nil {
		t.Fatal(err)
	}

	get := func(path string) (int, map[string]json.RawMessage) {
		w := httptest.NewRecorder()
		r.ServeHTTP(w, httptest.NewRequest(http.MethodGet, path, nil))
		var body map[string]json.RawMessage
		if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
			t.Fatalf("%s: bad body %s", path, w.Body.String())
		}
		return w.Code, body
	}

	if code, body := get("/novels/" + lonely.ID.String() + "/similar"); code != http.StatusOK || string(body["data"]) != "[]" {
		t.Errorf("similar of lonely novel = %d %s, want 200 []", code, body["data"])
	}
	if code, body := get("/novels/" + draft.ID.String() + "/similar"); code != http.StatusNotFound || string(body["code"]) != "40401" {
		t.Errorf("similar of draft = %d code %s, want 404 40401", code, body["code"])
	}

	code, body := get("/recommendations?limit=5")
	var recs struct {
		Personalized bool `json:"personalized"`
		Items        []struct {
			Novel  model.Novel                  `json:"novel"`
			Reason service.RecommendationReason `json:"reason"`
		} `json:"items"`
	}
	if code != http.StatusOK || json.Unmarshal(body["data"], &recs) != nil {
		t.Fatalf("recommendations = %d %s", code, body["data"])
	}
	if recs.Personalized || len(recs.Items) != 1 || recs.Items[0].Novel.ID != lonely.ID || recs.Items[0].Reason.Type != service.ReasonPopular {
		t.Errorf("anonymous recommendations = %s", body["data"])
	}
}
