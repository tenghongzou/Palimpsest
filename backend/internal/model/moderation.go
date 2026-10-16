package model

import "time"

// Moderation statuses of reviews and comments. Only approved ones are public;
// pending ones were held back by automated moderation until an admin decides.
const (
	ModerationPending  = "pending"
	ModerationApproved = "approved"
	ModerationRejected = "rejected"
	ModerationHidden   = "hidden"
)

// Moderation term severities.
const (
	// SeverityBlock holds matching content for review.
	SeverityBlock = "block"
	// SeverityFlag publishes matching content with a flag.
	SeverityFlag = "flag"
)

// ModerationFlag is one finding of automated moderation.
type ModerationFlag struct {
	// Code is a rule (blocked_term, flagged_term, link, contact_info,
	// repetition, shouting) or an AI category (ai_harassment, ...).
	Code string `json:"code"`
	// Detail is the matched term or a short reason.
	Detail string `json:"detail,omitempty"`
}

// ModerationResult is what automated moderation found in a review or
// comment. It is only shown to admins.
type ModerationResult struct {
	// Score is the estimated risk, 0..1.
	Score float64          `json:"score"`
	Flags []ModerationFlag `json:"flags"`
	// AIChecked is set once an AI review has run on the content.
	AIChecked bool       `json:"ai_checked"`
	CheckedAt *time.Time `json:"checked_at,omitempty"`
	// ReviewedAt is when an admin last decided on the content; reviewed
	// content leaves the flagged queue until it is edited.
	ReviewedAt *time.Time `json:"reviewed_at,omitempty"`
}

// HasFlag reports whether the result has a flag with the code.
func (r *ModerationResult) HasFlag(code string) bool {
	if r == nil {
		return false
	}
	for _, f := range r.Flags {
		if f.Code == code {
			return true
		}
	}
	return false
}

// ModerationTerm is a word or phrase checked in reviews and comments.
type ModerationTerm struct {
	ID int `gorm:"primaryKey;autoIncrement" json:"id"`
	// Term is the term as the admin entered it.
	Term string `gorm:"size:50;not null" json:"term"`
	// Normalized is the form matched against normalized text; it is unique,
	// so variants of a term (case, width, zh-TW/zh-CN) cannot be added twice.
	Normalized string    `gorm:"size:200;not null;uniqueIndex:idx_moderation_terms_normalized" json:"-"`
	Severity   string    `gorm:"size:10;not null" json:"severity"`
	CreatedAt  time.Time `json:"created_at"`
}
