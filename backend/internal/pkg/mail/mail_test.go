package mail

import (
	"strings"
	"testing"
	"time"
)

func TestMessageEncodesSubjectAndNormalisesLineEndings(t *testing.T) {
	msg := string(Message("a@example.com", "b@example.com", "重設密碼", "line1\nline2", time.Unix(0, 0)))
	if !strings.Contains(msg, "Subject: =?UTF-8?b?") {
		t.Errorf("subject not encoded: %q", msg)
	}
	if !strings.HasSuffix(msg, "\r\n\r\nline1\r\nline2") {
		t.Errorf("body not CRLF-normalised: %q", msg)
	}
}
