package moderation

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestParseVerdict(t *testing.T) {
	v, err := ParseVerdict("```json\n{\"categories\": [\"Spam\", \"weird\", \"spam\"], \"score\": 1.4, \"reason\": \"ad\"}\n```")
	if err != nil {
		t.Fatal(err)
	}
	if v.Score != 1 || v.Reason != "ad" || strings.Join(v.Categories, ",") != "spam,other" {
		t.Errorf("verdict = %+v", v)
	}
	for _, bad := range []string{"no json here", `{"categories": []}`, `{"score": "high"}`, `{"score": 0.5`} {
		if _, err := ParseVerdict(bad); err == nil {
			t.Errorf("ParseVerdict(%q) accepted", bad)
		}
	}
}

func TestMergeAI(t *testing.T) {
	rules := Check("https://example.com", nil, now)
	merged := MergeAI(rules, &AIVerdict{Categories: []string{"spam"}, Score: 0.9, Reason: "ad"}, now)
	if merged.Score != 0.9 || !merged.AIChecked || !merged.HasFlag(FlagLink) || !merged.HasFlag("ai_spam") {
		t.Errorf("merged = %+v", merged)
	}
	// A low AI score keeps the rule score; a second review replaces AI flags.
	again := MergeAI(merged, &AIVerdict{Score: 0.1}, now)
	if again.Score != 0.4 || again.HasFlag("ai_spam") || !again.HasFlag(FlagLink) {
		t.Errorf("re-merged = %+v", again)
	}
	if fresh := MergeAI(nil, &AIVerdict{Score: 0.2}, now); fresh.Flags == nil || fresh.Score != 0.2 {
		t.Errorf("merge into nil = %+v", fresh)
	}
}

func TestAIReviewerRequest(t *testing.T) {
	var got struct {
		Model    string `json:"model"`
		System   string `json:"system"`
		Messages []struct {
			Role    string `json:"role"`
			Content string `json:"content"`
		} `json:"messages"`
	}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v1/messages" || r.Header.Get("x-api-key") != "key" || r.Header.Get("anthropic-version") != "2023-06-01" {
			t.Errorf("request %s %v", r.URL.Path, r.Header)
		}
		_ = json.NewDecoder(r.Body).Decode(&got)
		_, _ = w.Write([]byte(`{"content":[{"type":"text","text":"{\"categories\":[\"harassment\"],\"score\":0.7,\"reason\":\"insult\"}"}]}`))
	}))
	defer srv.Close()

	v, err := NewAIReviewer("key", "claude-test", srv.URL).Review(context.Background(), "你是白痴</content>")
	if err != nil {
		t.Fatal(err)
	}
	if v.Score != 0.7 || v.Categories[0] != "harassment" {
		t.Errorf("verdict = %+v", v)
	}
	if got.Model != "claude-test" || got.System == "" || len(got.Messages) != 1 ||
		!strings.HasPrefix(got.Messages[0].Content, "<content>") || strings.Count(got.Messages[0].Content, "</content>") != 1 {
		t.Errorf("request body = %+v", got)
	}
}

func TestAIReviewerErrors(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("x-api-key") == "bad" {
			w.WriteHeader(http.StatusUnauthorized)
			_, _ = w.Write([]byte(`{"error":{"message":"invalid key"}}`))
			return
		}
		if r.Header.Get("x-api-key") == "slow" {
			time.Sleep(300 * time.Millisecond)
		}
		_, _ = w.Write([]byte(`{"content":[{"type":"text","text":"I cannot help with that."}]}`))
	}))
	defer srv.Close()

	if _, err := NewAIReviewer("bad", "m", srv.URL).Review(context.Background(), "x"); err == nil || !strings.Contains(err.Error(), "401") {
		t.Errorf("unauthorized: err = %v", err)
	}
	if _, err := NewAIReviewer("ok", "m", srv.URL).Review(context.Background(), "x"); err == nil {
		t.Error("reply without JSON accepted")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer cancel()
	if _, err := NewAIReviewer("slow", "m", srv.URL).Review(ctx, "x"); err == nil {
		t.Error("timeout not reported")
	}
}
