package translate

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"html"
	"io"
	"net/http"
	"net/url"
	"time"
	"unicode/utf8"
)

const defaultGoogleEndpoint = "https://translation.googleapis.com/language/translate/v2"

// Request limits recommended by the Cloud Translation v2 API.
const (
	maxSegmentsPerRequest = 100
	maxRunesPerRequest    = 5000
)

// ErrUpstream wraps failures returned by the translation provider.
var ErrUpstream = errors.New("translate: upstream provider error")

// MachineTranslator translates batches of text segments.
// from may be empty to let the provider detect the source language.
type MachineTranslator interface {
	Translate(ctx context.Context, segments []string, from, to string) ([]string, error)
}

// GoogleTranslator calls the Google Cloud Translation v2 REST API with an API key.
type GoogleTranslator struct {
	apiKey   string
	endpoint string
	client   *http.Client
}

// NewGoogleTranslator returns nil when apiKey is empty, meaning machine
// translation is not configured.
func NewGoogleTranslator(apiKey, endpoint string) *GoogleTranslator {
	if apiKey == "" {
		return nil
	}
	if endpoint == "" {
		endpoint = defaultGoogleEndpoint
	}
	return &GoogleTranslator{
		apiKey:   apiKey,
		endpoint: endpoint,
		client:   &http.Client{Timeout: 30 * time.Second},
	}
}

type googleRequest struct {
	Q      []string `json:"q"`
	Target string   `json:"target"`
	Source string   `json:"source,omitempty"`
	Format string   `json:"format"`
}

type googleResponse struct {
	Data struct {
		Translations []struct {
			TranslatedText string `json:"translatedText"`
		} `json:"translations"`
	} `json:"data"`
	Error *struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
	} `json:"error"`
}

// Translate splits segments into API-sized batches and returns the
// translations in the same order.
func (g *GoogleTranslator) Translate(ctx context.Context, segments []string, from, to string) ([]string, error) {
	out := make([]string, 0, len(segments))
	for _, batch := range batchSegments(segments, maxSegmentsPerRequest, maxRunesPerRequest) {
		translated, err := g.translateBatch(ctx, batch, from, to)
		if err != nil {
			return nil, err
		}
		out = append(out, translated...)
	}
	return out, nil
}

func (g *GoogleTranslator) translateBatch(ctx context.Context, segments []string, from, to string) ([]string, error) {
	body, err := json.Marshal(googleRequest{Q: segments, Target: to, Source: from, Format: "text"})
	if err != nil {
		return nil, err
	}
	endpoint := g.endpoint + "?key=" + url.QueryEscape(g.apiKey)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := g.client.Do(req)
	if err != nil {
		// Do not wrap err: *url.Error would echo the URL including the API key.
		return nil, fmt.Errorf("%w: request failed", ErrUpstream)
	}
	defer resp.Body.Close()

	raw, err := io.ReadAll(io.LimitReader(resp.Body, 10<<20))
	if err != nil {
		return nil, fmt.Errorf("%w: reading response: %v", ErrUpstream, err)
	}
	var parsed googleResponse
	if err := json.Unmarshal(raw, &parsed); err != nil {
		return nil, fmt.Errorf("%w: status %d, invalid response", ErrUpstream, resp.StatusCode)
	}
	if resp.StatusCode != http.StatusOK || parsed.Error != nil {
		msg := ""
		if parsed.Error != nil {
			msg = parsed.Error.Message
		}
		return nil, fmt.Errorf("%w: status %d: %s", ErrUpstream, resp.StatusCode, msg)
	}
	if len(parsed.Data.Translations) != len(segments) {
		return nil, fmt.Errorf("%w: expected %d translations, got %d",
			ErrUpstream, len(segments), len(parsed.Data.Translations))
	}

	out := make([]string, len(segments))
	for i, t := range parsed.Data.Translations {
		// format=text should return plain text, but entities still appear occasionally.
		out[i] = html.UnescapeString(t.TranslatedText)
	}
	return out, nil
}

// batchSegments groups segments so each batch stays within both limits.
// A single segment longer than maxRunes gets a batch of its own.
func batchSegments(segments []string, maxCount, maxRunes int) [][]string {
	var batches [][]string
	var current []string
	runes := 0
	for _, s := range segments {
		n := utf8.RuneCountInString(s)
		if len(current) > 0 && (len(current) >= maxCount || runes+n > maxRunes) {
			batches = append(batches, current)
			current, runes = nil, 0
		}
		current = append(current, s)
		runes += n
	}
	if len(current) > 0 {
		batches = append(batches, current)
	}
	return batches
}
