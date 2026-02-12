package service

// TranslationService handles zh-TW/zh-CN conversion (OpenCC) and English translation (Google Translate).
type TranslationService struct {
	// TODO: inject OpenCC client, Google Translate client, CacheRepository
}

func NewTranslationService() *TranslationService {
	return &TranslationService{}
}

// TODO: implement Convert (OpenCC), TranslateChapter, TranslateText
