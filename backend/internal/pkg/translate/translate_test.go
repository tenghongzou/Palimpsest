package translate

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestConvertChinese(t *testing.T) {
	cases := []struct {
		text, from, to, want string
	}{
		{"鬥破蒼穹", LangTraditional, LangSimplified, "斗破苍穹"},
		{"斗破苍穹", LangSimplified, LangTraditional, "鬥破蒼穹"},
		// Taiwan phrase conversion, not just character mapping.
		{"软件", LangSimplified, LangTraditional, "軟體"},
		{"軟體", LangTraditional, LangSimplified, "软件"},
		{"不變", LangTraditional, LangTraditional, "不變"},
	}
	for _, c := range cases {
		got, err := ConvertChinese(c.text, c.from, c.to)
		if err != nil {
			t.Fatalf("ConvertChinese(%q, %s, %s): %v", c.text, c.from, c.to, err)
		}
		if got != c.want {
			t.Errorf("ConvertChinese(%q, %s, %s) = %q, want %q", c.text, c.from, c.to, got, c.want)
		}
	}
}

func TestConvertChineseUnsupported(t *testing.T) {
	if _, err := ConvertChinese("hello", LangEnglish, LangTraditional); err == nil {
		t.Error("expected error for non-Chinese pair")
	}
}

func TestBatchSegments(t *testing.T) {
	segs := []string{"aaa", "bbb", "cccc", "d"}
	got := batchSegments(segs, 10, 6)
	want := [][]string{{"aaa", "bbb"}, {"cccc", "d"}}
	if len(got) != len(want) {
		t.Fatalf("got %v, want %v", got, want)
	}
	for i := range want {
		if strings.Join(got[i], ",") != strings.Join(want[i], ",") {
			t.Errorf("batch %d = %v, want %v", i, got[i], want[i])
		}
	}

	// Count limit and oversized segments.
	got = batchSegments([]string{"a", "b", "c", strings.Repeat("x", 20)}, 2, 10)
	if len(got) != 3 || len(got[2]) != 1 {
		t.Errorf("unexpected batches %v", got)
	}
}

func TestNewGoogleTranslatorWithoutKey(t *testing.T) {
	if NewGoogleTranslator("", "") != nil {
		t.Error("expected nil translator without API key")
	}
}

func TestGoogleTranslate(t *testing.T) {
	var calls int
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		if r.URL.Query().Get("key") != "test-key" {
			t.Errorf("missing API key in request")
		}
		var req googleRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			t.Fatalf("decode request: %v", err)
		}
		if req.Target != "en" || req.Source != "zh-TW" || req.Format != "text" {
			t.Errorf("unexpected request %+v", req)
		}
		var resp googleResponse
		for _, q := range req.Q {
			resp.Data.Translations = append(resp.Data.Translations, struct {
				TranslatedText string `json:"translatedText"`
			}{TranslatedText: "EN(" + q + ")&amp;"})
		}
		_ = json.NewEncoder(w).Encode(resp)
	}))
	defer srv.Close()

	g := NewGoogleTranslator("test-key", srv.URL)
	segs := make([]string, maxSegmentsPerRequest+5)
	for i := range segs {
		segs[i] = "段"
	}
	segs[0] = "鬥氣"
	out, err := g.Translate(context.Background(), segs, "zh-TW", "en")
	if err != nil {
		t.Fatalf("Translate: %v", err)
	}
	if calls != 2 {
		t.Errorf("expected 2 batched requests, got %d", calls)
	}
	if len(out) != len(segs) || out[0] != "EN(鬥氣)&" {
		t.Errorf("unexpected output: len=%d first=%q", len(out), out[0])
	}
}

func TestGoogleTranslateUpstreamError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusForbidden)
		_, _ = w.Write([]byte(`{"error":{"code":403,"message":"API key not valid"}}`))
	}))
	defer srv.Close()

	_, err := NewGoogleTranslator("bad", srv.URL).Translate(context.Background(), []string{"x"}, "", "en")
	if !errors.Is(err, ErrUpstream) {
		t.Fatalf("expected ErrUpstream, got %v", err)
	}
	if strings.Contains(err.Error(), "key=bad") {
		t.Error("error message must not leak the API key")
	}
}
