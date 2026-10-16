// Package translate converts between Traditional and Simplified Chinese
// (OpenCC) and calls a machine translation provider for other language pairs.
package translate

import (
	"fmt"
	"sync"

	"github.com/longbridgeapp/opencc"
)

// Supported language codes.
const (
	LangTraditional = "zh-TW"
	LangSimplified  = "zh-CN"
	LangEnglish     = "en"
)

// IsChinese reports whether lang is one of the Chinese variants OpenCC handles.
func IsChinese(lang string) bool {
	return lang == LangTraditional || lang == LangSimplified
}

// Converters are expensive to build (they load dictionaries), so each
// conversion is built once on first use and shared; Convert is read-only.
var (
	convertersMu sync.Mutex
	converters   = map[string]*opencc.OpenCC{}
)

func converter(conversion string) (*opencc.OpenCC, error) {
	convertersMu.Lock()
	defer convertersMu.Unlock()
	if cc, ok := converters[conversion]; ok {
		return cc, nil
	}
	cc, err := opencc.New(conversion)
	if err != nil {
		return nil, err
	}
	converters[conversion] = cc
	return cc, nil
}

// ConvertChinese converts text between zh-TW and zh-CN. Taiwan phrase
// conversion is used (e.g. 软件 <-> 軟體), not just character mapping.
func ConvertChinese(text, from, to string) (string, error) {
	if from == to {
		return text, nil
	}
	var conversion string
	switch {
	case from == LangSimplified && to == LangTraditional:
		conversion = "s2twp"
	case from == LangTraditional && to == LangSimplified:
		conversion = "tw2sp"
	default:
		return "", fmt.Errorf("translate: unsupported Chinese conversion %s -> %s", from, to)
	}
	cc, err := converter(conversion)
	if err != nil {
		return "", err
	}
	return cc.Convert(text)
}

// ToSimplified maps Traditional characters to Simplified ones (OpenCC t2s)
// and leaves everything else alone. Several Traditional characters can map to
// one Simplified character, so it suits comparing text regardless of script.
func ToSimplified(text string) (string, error) {
	cc, err := converter("t2s")
	if err != nil {
		return "", err
	}
	return cc.Convert(text)
}
