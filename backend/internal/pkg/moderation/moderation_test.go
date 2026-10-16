package moderation

import (
	"strings"
	"testing"
	"time"

	"github.com/tenghongzou/palimpsest/backend/internal/model"
)

var now = time.Date(2026, 10, 16, 8, 0, 0, 0, time.UTC)

func codes(r *model.ModerationResult) []string {
	var out []string
	for _, f := range r.Flags {
		out = append(out, f.Code)
	}
	return out
}

func terms(t *testing.T, entries map[string]string) *TermSet {
	t.Helper()
	var list []Term
	for term, severity := range entries {
		n, err := NormalizeTerm(term)
		if err != nil {
			t.Fatalf("NormalizeTerm(%q): %v", term, err)
		}
		list = append(list, Term{Display: term, Normalized: n, Severity: severity})
	}
	return NewTermSet(list)
}

func TestNormalize(t *testing.T) {
	cases := map[string]string{
		"ＡＢＣ１２３":    "abc123", // full width
		"HeLLo":     "hello",
		"這個軟體很好用":   "这个软体很好用", // characters only, no phrase conversion
		"简体不变":      "简体不变",
		"ｗｗｗ．ａ．ｃｏｍ": "www.a.com",
	}
	for in, want := range cases {
		if got := Normalize(in); got != want {
			t.Errorf("Normalize(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestNormalizeTerm(t *testing.T) {
	cases := []struct{ in, want string }{
		{" 垃圾 ", "垃圾"},
		{"垃 - 圾", "垃圾"},
		{"垃圾", "垃圾"},
		{"Spam  Site", "spam site"},
		{"ＳＰＡＭ", "spam"},
		{"加LINE", "加line"},
	}
	for _, c := range cases {
		got, err := NormalizeTerm(c.in)
		if err != nil || got != c.want {
			t.Errorf("NormalizeTerm(%q) = %q, %v; want %q", c.in, got, err, c.want)
		}
	}
	// Traditional and Simplified forms of a term are the same term.
	a, _ := NormalizeTerm("廣告")
	b, _ := NormalizeTerm("广告")
	if a != b {
		t.Errorf("廣告 -> %q, 广告 -> %q", a, b)
	}
	if _, err := NormalizeTerm(" !!! "); err != ErrEmptyTerm {
		t.Errorf("punctuation-only term: err = %v", err)
	}
}

func TestTerms(t *testing.T) {
	set := terms(t, map[string]string{"垃圾": model.SeverityBlock, "廣告": model.SeverityFlag, "ass": model.SeverityFlag})

	r := Check("這本書根本是垃圾", set, now)
	if !r.HasFlag(FlagBlockedTerm) || !Held(r) || r.Flags[0].Detail != "垃圾" {
		t.Errorf("blocked term: %+v", r)
	}
	// Spacing, punctuation, width and script do not hide a term.
	for _, text := range []string{"垃 圾", "垃。圾作品", "拉圾", "广 告位招租"} {
		r := Check(text, set, now)
		hit := r.HasFlag(FlagBlockedTerm) || r.HasFlag(FlagFlaggedTerm)
		if want := text != "拉圾"; hit != want {
			t.Errorf("%q: flags %v, want hit=%v", text, codes(r), want)
		}
	}
	r = Check("看到廣告了", set, now)
	if !r.HasFlag(FlagFlaggedTerm) || Held(r) || r.Score != 0.5 {
		t.Errorf("flagged term: %+v", r)
	}
	// Latin terms match whole words only.
	if r := Check("first class story", set, now); r.HasFlag(FlagFlaggedTerm) {
		t.Errorf("ass matched inside class: %v", codes(r))
	}
	if r := Check("what an ASS.", set, now); !r.HasFlag(FlagFlaggedTerm) {
		t.Errorf("whole word not matched: %v", codes(r))
	}
}

func TestLinksAndContactInfo(t *testing.T) {
	cases := []struct {
		text string
		want []string
	}{
		{"去 https://example.com/x 看", []string{FlagLink}},
		{"www.example.org 有全文", []string{FlagLink}},
		{"免費看 example.xyz", []string{FlagLink}},
		{"ＷＷＷ．ＥＸＡＭＰＬＥ．ＣＯＭ", []string{FlagLink}},
		{"寫信到 me@example.com", []string{FlagContactInfo}},
		{"電話 0912-345-678", []string{FlagContactInfo}},
		{"想要資源加賴", []string{FlagContactInfo}},
		{"LINE ID: abc", []string{FlagContactInfo}},
		{"加我微信", []string{FlagContactInfo}},
		{"vx123456", []string{FlagContactInfo}},
		{"QQ群 12345", []string{FlagContactInfo}},
		{"第100章太好看了，3.5 顆星", nil},
		{"主角在線上(online)遊戲中", nil},
		{"line 很好看", nil},
	}
	for _, c := range cases {
		r := Check(c.text, nil, now)
		if got := strings.Join(codes(r), ","); got != strings.Join(c.want, ",") {
			t.Errorf("%q: flags %q, want %q", c.text, got, strings.Join(c.want, ","))
		}
	}
}

func TestRepetitionAndShouting(t *testing.T) {
	if r := Check("好看好看好看好看好看", nil, now); !r.HasFlag(FlagRepetition) || r.Flags[0].Detail != "好看" {
		t.Errorf("word repetition: %+v", r)
	}
	if r := Check("啊啊啊啊啊啊啊啊啊啊啊", nil, now); !r.HasFlag(FlagRepetition) {
		t.Errorf("char repetition: %v", codes(r))
	}
	if r := Check("哈哈哈，笑死我了", nil, now); r.HasFlag(FlagRepetition) {
		t.Errorf("short laughter flagged: %v", codes(r))
	}
	if r := Check("THIS NOVEL IS THE BEST EVER WRITTEN", nil, now); !r.HasFlag(FlagShouting) {
		t.Errorf("shouting: %v", codes(r))
	}
	if r := Check("I LOVE IT", nil, now); r.HasFlag(FlagShouting) {
		t.Errorf("short caps flagged: %v", codes(r))
	}
	if r := Check("This novel is the best ever written, AMAZING", nil, now); r.HasFlag(FlagShouting) {
		t.Errorf("mixed case flagged: %v", codes(r))
	}
}

func TestScoreAndDecision(t *testing.T) {
	clean := Check("劇情很精彩，期待下一章", nil, now)
	if clean.Score != 0 || len(clean.Flags) != 0 || clean.Flags == nil || Held(clean) || clean.CheckedAt == nil {
		t.Errorf("clean: %+v", clean)
	}
	link := Check("https://example.com", nil, now)
	if link.Score != 0.4 || Held(link) {
		t.Errorf("link only: %+v", link)
	}
	// Link + contact details: 1 - 0.6*0.4 = 0.76, still published.
	spam := Check("全文在 https://example.com 加賴", nil, now)
	if spam.Score != 0.76 || Held(spam) {
		t.Errorf("link+contact: %+v", spam)
	}
	// Adding a flagged term crosses the threshold.
	set := terms(t, map[string]string{"免費": model.SeverityFlag})
	held := Check("免費全文在 https://example.com 加賴", set, now)
	if held.Score != 0.88 || !Held(held) || !RuleHeld(held) {
		t.Errorf("link+contact+term: %+v", held)
	}
	if Score([]model.ModerationFlag{{Code: "ai_spam"}}) != 0 {
		t.Error("AI flags count toward the rule score")
	}
}
