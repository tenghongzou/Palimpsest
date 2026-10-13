package main

import (
	"bufio"
	"os"
	"regexp"
	"sort"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/tenghongzou/palimpsest/backend/internal/config"
)

var (
	specPathLine   = regexp.MustCompile(`^  (/[^:]*):\s*$`)
	specMethodLine = regexp.MustCompile(`^    (get|post|put|patch|delete):\s*$`)
	specParam      = regexp.MustCompile(`\{[^}]+\}`)
	ginParam       = regexp.MustCompile(`:[^/]+`)
)

// specRoutes reads "METHOD /path" pairs from the OpenAPI spec, with path
// parameters normalised to "{}" so names do not need to match.
func specRoutes(t *testing.T) []string {
	t.Helper()
	f, err := os.Open("../../../shared/api-spec/openapi.yaml")
	if err != nil {
		t.Fatalf("open spec: %v", err)
	}
	defer f.Close()

	var routes []string
	var current string
	inPaths := false
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimRight(scanner.Text(), "\r")
		switch {
		case line == "paths:":
			inPaths = true
		case inPaths && len(line) > 0 && line[0] != ' ' && line[0] != '#':
			inPaths = false
		case inPaths:
			if m := specPathLine.FindStringSubmatch(line); m != nil {
				current = specParam.ReplaceAllString(m[1], "{}")
			} else if m := specMethodLine.FindStringSubmatch(line); m != nil && current != "" {
				routes = append(routes, strings.ToUpper(m[1])+" "+current)
			}
		}
	}
	if err := scanner.Err(); err != nil {
		t.Fatalf("read spec: %v", err)
	}
	sort.Strings(routes)
	return routes
}

func TestOpenAPISpecMatchesRouter(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := setupRouter(&config.Config{}, nil, &Handlers{})

	var routes []string
	for _, ri := range r.Routes() {
		if !strings.HasPrefix(ri.Path, "/api/v1/") {
			continue
		}
		path := ginParam.ReplaceAllString(strings.TrimPrefix(ri.Path, "/api/v1"), "{}")
		routes = append(routes, ri.Method+" "+path)
	}
	sort.Strings(routes)

	inSpec := map[string]bool{}
	for _, r := range specRoutes(t) {
		inSpec[r] = true
	}
	inRouter := map[string]bool{}
	for _, r := range routes {
		inRouter[r] = true
		if !inSpec[r] {
			t.Errorf("route %s is registered but missing from openapi.yaml", r)
		}
	}
	for r := range inSpec {
		if !inRouter[r] {
			t.Errorf("route %s is in openapi.yaml but not registered", r)
		}
	}
}
