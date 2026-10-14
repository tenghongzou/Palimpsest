// Package mail sends transactional email.
package mail

import (
	"fmt"
	"log"
	"mime"
	"net"
	"net/mail"
	"net/smtp"
	"strings"
	"time"

	"github.com/tenghongzou/palimpsest/backend/internal/config"
)

// Sender delivers a plain-text email.
type Sender interface {
	Send(to, subject, body string) error
}

// New returns an SMTP sender, or a sender that only logs when no SMTP host
// is configured. The log sender prints message bodies (which may contain
// reset links) only outside release mode.
func New(cfg *config.Config) Sender {
	if cfg.Mail.Host == "" {
		return logSender{verbose: cfg.Server.Mode != "release"}
	}
	return &smtpSender{cfg: cfg.Mail}
}

type logSender struct{ verbose bool }

func (s logSender) Send(to, subject, body string) error {
	if s.verbose {
		log.Printf("mail (SMTP_HOST not set, not sent) to=%s subject=%q\n%s", to, subject, body)
	} else {
		log.Printf("WARNING: SMTP_HOST not set; dropped email %q", subject)
	}
	return nil
}

type smtpSender struct{ cfg config.MailConfig }

func (s *smtpSender) Send(to, subject, body string) error {
	from, err := mail.ParseAddress(s.cfg.From)
	if err != nil {
		return fmt.Errorf("invalid SMTP_FROM: %w", err)
	}
	rcpt, err := mail.ParseAddress(to)
	if err != nil {
		return fmt.Errorf("invalid recipient: %w", err)
	}
	msg := Message(from.String(), rcpt.Address, subject, body, time.Now())

	var auth smtp.Auth
	if s.cfg.Username != "" {
		auth = smtp.PlainAuth("", s.cfg.Username, s.cfg.Password, s.cfg.Host)
	}
	addr := net.JoinHostPort(s.cfg.Host, s.cfg.Port)
	return smtp.SendMail(addr, auth, from.Address, []string{rcpt.Address}, msg)
}

// Message builds an RFC 5322 message with a UTF-8 subject and body.
func Message(from, to, subject, body string, date time.Time) []byte {
	var b strings.Builder
	b.WriteString("From: " + from + "\r\n")
	b.WriteString("To: " + to + "\r\n")
	b.WriteString("Subject: " + mime.BEncoding.Encode("UTF-8", subject) + "\r\n")
	b.WriteString("Date: " + date.Format(time.RFC1123Z) + "\r\n")
	b.WriteString("MIME-Version: 1.0\r\n")
	b.WriteString("Content-Type: text/plain; charset=UTF-8\r\n")
	b.WriteString("Content-Transfer-Encoding: 8bit\r\n\r\n")
	b.WriteString(strings.ReplaceAll(strings.ReplaceAll(body, "\r\n", "\n"), "\n", "\r\n"))
	return []byte(b.String())
}
