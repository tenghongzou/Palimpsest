// Package moderation checks reviews and comments for content that should be
// held for an admin or flagged: admin-maintained terms, links, contact
// details, repetition and shouting. An optional AI review (ai.go) adds its
// own verdict afterwards.
package moderation

import (
	"errors"
	"math"
	"regexp"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"

	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/pkg/translate"
	"golang.org/x/text/unicode/norm"
)

// Rule flag codes.
const (
	FlagBlockedTerm = "blocked_term"
	FlagFlaggedTerm = "flagged_term"
	FlagLink        = "link"
	FlagContactInfo = "contact_info"
	FlagRepetition  = "repetition"
	FlagShouting    = "shouting"
)

// HoldScore is the score at or above which content is held for review.
const HoldScore = 0.8

// weights are each rule's contribution to the score. Scores combine as
// independent risks: 1 - Π(1 - w), so no single soft signal holds content
// on its own, but several together do.
var weights = map[string]float64{
	FlagBlockedTerm: 1,
	FlagFlaggedTerm: 0.5,
	FlagLink:        0.4,
	FlagContactInfo: 0.6,
	FlagRepetition:  0.3,
	FlagShouting:    0.2,
}

// maxDetail bounds a flag's detail in runes.
const maxDetail = 100

// Normalize folds text for matching: NFKC (full-width letters, digits and
// punctuation become their ASCII forms), lower case, and Traditional
// characters mapped to Simplified so zh-TW and zh-CN variants compare equal.
func Normalize(s string) string {
	s = strings.ToLower(norm.NFKC.String(s))
	if simplified, err := translate.ToSimplified(s); err == nil {
		s = simplified
	}
	return s
}

// compact keeps only letters and digits, so spacing or punctuation inserted
// into a term ("垃 圾", "垃-圾") does not hide it.
func compact(s string) string {
	var b strings.Builder
	b.Grow(len(s))
	for _, r := range s {
		if unicode.IsLetter(r) || unicode.IsNumber(r) {
			b.WriteRune(r)
		}
	}
	return b.String()
}

var wordTermPattern = regexp.MustCompile(`^[a-z0-9]+(?: [a-z0-9]+)*$`)

// ErrEmptyTerm is returned for a term with no letters or digits.
var ErrEmptyTerm = errors.New("moderation: term has no letters or digits")

// NormalizeTerm returns the form a term is matched and deduplicated by.
// Latin terms ("spam site") keep their words and match whole words only, so
// "ass" does not match "class"; other terms match anywhere, ignoring
// spacing and punctuation.
func NormalizeTerm(term string) (string, error) {
	n := strings.Join(strings.FieldsFunc(Normalize(term), func(r rune) bool {
		return !unicode.IsLetter(r) && !unicode.IsNumber(r)
	}), " ")
	if n == "" {
		return "", ErrEmptyTerm
	}
	if wordTermPattern.MatchString(n) {
		return n, nil
	}
	return strings.ReplaceAll(n, " ", ""), nil
}

// Term is a configured term ready for matching.
type Term struct {
	// Display is the term as entered, reported in flag details.
	Display    string
	Normalized string
	Severity   string
}

type compiledTerm struct {
	Term
	word *regexp.Regexp // whole-word pattern for Latin terms
}

// TermSet is a compiled list of terms. The zero value matches nothing.
type TermSet struct {
	terms []compiledTerm
}

// NewTermSet compiles terms; terms whose Normalized form is empty are skipped.
func NewTermSet(terms []Term) *TermSet {
	set := &TermSet{}
	for _, t := range terms {
		if t.Normalized == "" {
			continue
		}
		ct := compiledTerm{Term: t}
		if wordTermPattern.MatchString(t.Normalized) {
			words := strings.Split(t.Normalized, " ")
			for i := range words {
				words[i] = regexp.QuoteMeta(words[i])
			}
			ct.word = regexp.MustCompile(`(?:^|[^a-z0-9])` + strings.Join(words, `[^a-z0-9]+`) + `(?:$|[^a-z0-9])`)
		}
		set.terms = append(set.terms, ct)
	}
	return set
}

// Len is the number of terms.
func (s *TermSet) Len() int {
	if s == nil {
		return 0
	}
	return len(s.terms)
}

var (
	emailPattern  = regexp.MustCompile(`[a-z0-9._%+\-]+@[a-z0-9\-]+(?:\.[a-z0-9\-]+)*\.[a-z]{2,}`)
	urlPattern    = regexp.MustCompile(`(?:https?://|www\.)[^\s<>"'，。！？、]+`)
	domainPattern = regexp.MustCompile(`(?:^|[^a-z0-9.\-])((?:[a-z0-9](?:[a-z0-9\-]{0,61}[a-z0-9])?\.)+` +
		`(?:com|net|org|io|cc|tw|cn|hk|me|xyz|top|info|co|app|link|ly|gg|tv|vip|club|site|online|shop|biz|us|jp|ru))(?:$|[^a-z0-9])`)
	phonePattern = regexp.MustCompile(`\+?\d(?:[\s.\-]?\d){7,}`)
	// contactPattern matches invitations to talk off-site, in normalized
	// (lower case, Simplified) text: 加賴, LINE ID, 微信, vx, QQ, Telegram...
	contactPattern = regexp.MustCompile(`加\s*赖|赖\s*id|加\s*line|line\s*(?:id|@|:)|微信|威信|薇信|wechat|telegram|扣扣|` +
		`(?:^|[^a-z])(?:vx|wx|qq|tg)(?:[^a-z]|$)|加\s*v(?:[^a-z]|$)`)
)

// Check runs the rules over text with the given terms. The result's score
// is in 0..1; Held reports whether it should be held for review.
func Check(text string, terms *TermSet, now time.Time) *model.ModerationResult {
	nfkc := norm.NFKC.String(text)
	normalized := Normalize(text)
	packed := compact(normalized)
	var flags []model.ModerationFlag

	if terms != nil {
		for _, t := range terms.terms {
			var hit bool
			if t.word != nil {
				hit = t.word.MatchString(normalized)
			} else {
				hit = strings.Contains(packed, t.Normalized)
			}
			if !hit {
				continue
			}
			code := FlagFlaggedTerm
			if t.Severity == model.SeverityBlock {
				code = FlagBlockedTerm
			}
			flags = append(flags, model.ModerationFlag{Code: code, Detail: t.Display})
		}
	}

	// Emails are contact details, not links; take them out before looking
	// for domains.
	rest := normalized
	var contact []string
	if m := emailPattern.FindAllString(rest, -1); len(m) > 0 {
		contact = append(contact, m...)
		rest = emailPattern.ReplaceAllString(rest, " ")
	}
	if m := urlPattern.FindString(rest); m != "" {
		flags = append(flags, model.ModerationFlag{Code: FlagLink, Detail: clip(m)})
		rest = urlPattern.ReplaceAllString(rest, " ")
	} else if m := domainPattern.FindStringSubmatch(rest); m != nil {
		flags = append(flags, model.ModerationFlag{Code: FlagLink, Detail: clip(m[1])})
	}
	if m := phonePattern.FindString(rest); m != "" {
		contact = append(contact, m)
	}
	if m := contactPattern.FindString(normalized); m != "" {
		contact = append(contact, strings.TrimFunc(m, func(r rune) bool { return !unicode.IsLetter(r) && !unicode.IsNumber(r) }))
	}
	if len(contact) > 0 {
		flags = append(flags, model.ModerationFlag{Code: FlagContactInfo, Detail: clip(strings.Join(contact, ", "))})
	}

	if unit := repeatedUnit(packed); unit != "" {
		flags = append(flags, model.ModerationFlag{Code: FlagRepetition, Detail: clip(unit)})
	}
	if shouting(nfkc) {
		flags = append(flags, model.ModerationFlag{Code: FlagShouting})
	}

	if flags == nil {
		flags = []model.ModerationFlag{}
	}
	checkedAt := now.UTC()
	return &model.ModerationResult{Score: Score(flags), Flags: flags, CheckedAt: &checkedAt}
}

// Score combines the rule flags; AI flags are scored by the AI review itself.
func Score(flags []model.ModerationFlag) float64 {
	keep := 1.0
	for _, f := range flags {
		if w, ok := weights[f.Code]; ok {
			keep *= 1 - w
		}
	}
	return round2(1 - keep)
}

func round2(v float64) float64 {
	return math.Round(v*100) / 100
}

// Held reports whether a result holds content for review: a blocked term, or
// a score of HoldScore or more.
func Held(r *model.ModerationResult) bool {
	if r == nil {
		return false
	}
	return r.HasFlag(FlagBlockedTerm) || r.Score >= HoldScore
}

// RuleHeld reports whether the rule flags alone hold the content, ignoring
// any AI review: that is, whether the content was held when it was created.
func RuleHeld(r *model.ModerationResult) bool {
	if r == nil {
		return false
	}
	return r.HasFlag(FlagBlockedTerm) || Score(r.Flags) >= HoldScore
}

// repeatedUnit finds a letter or digit repeated 10+ times in a row, or a
// short sequence (2-6 runes) repeated 5+ times in a row, and returns it.
func repeatedUnit(s string) string {
	r := []rune(s)
	for p := 1; p <= 6; p++ {
		need := 5
		if p == 1 {
			need = 10
		}
		for start := 0; start+p*need <= len(r); start++ {
			run := 1
			for i := start + p; i+p <= len(r) && equalRunes(r[i:i+p], r[i-p:i]); i += p {
				run++
				if run >= need && (p == 1 || !uniform(r[i:i+p])) {
					return string(r[i : i+p])
				}
			}
		}
	}
	return ""
}

func equalRunes(a, b []rune) bool {
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

// uniform reports a unit made of one rune, already covered by period 1.
func uniform(r []rune) bool {
	for _, c := range r[1:] {
		if c != r[0] {
			return false
		}
	}
	return true
}

// shouting reports long Latin text in mostly capital letters.
func shouting(s string) bool {
	letters, upper := 0, 0
	for _, r := range s {
		if r >= 'a' && r <= 'z' {
			letters++
		} else if r >= 'A' && r <= 'Z' {
			letters++
			upper++
		}
	}
	return letters >= 20 && float64(upper) >= 0.7*float64(letters)
}

func clip(s string) string {
	s = strings.TrimSpace(s)
	if utf8.RuneCountInString(s) <= maxDetail {
		return s
	}
	return string([]rune(s)[:maxDetail]) + "…"
}
