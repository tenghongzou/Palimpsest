package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/testutil"
)

func TestHTTPMetricsUseRouteTemplates(t *testing.T) {
	reg := prometheus.NewRegistry()
	m := NewHTTPMetrics(reg)
	r := gin.New()
	r.Use(m.Middleware())
	r.GET("/novels/:id", func(c *gin.Context) { c.Status(http.StatusOK) })

	for _, path := range []string{"/novels/1", "/novels/2", "/missing"} {
		r.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(http.MethodGet, path, nil))
	}

	if got := testutil.ToFloat64(m.requests.WithLabelValues("GET", "/novels/:id", "200")); got != 2 {
		t.Errorf("requests for /novels/:id = %v, want 2", got)
	}
	if got := testutil.ToFloat64(m.requests.WithLabelValues("GET", "unmatched", "404")); got != 1 {
		t.Errorf("unmatched requests = %v, want 1", got)
	}
	if n := testutil.CollectAndCount(m.duration); n != 2 {
		t.Errorf("duration series = %d, want 2 (one per route)", n)
	}
}
