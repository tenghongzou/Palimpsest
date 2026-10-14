package service

import (
	"errors"

	"github.com/google/uuid"
)

// Errors shared by services; handlers map them to HTTP responses.
var (
	ErrNotFound  = errors.New("not found")
	ErrForbidden = errors.New("forbidden")
	ErrConflict  = errors.New("conflict")
)

func parseUUID(s string) (uuid.UUID, error) {
	return uuid.Parse(s)
}

// offset converts a 1-based page into a row offset.
func offset(page, pageSize int) int {
	if page < 1 {
		page = 1
	}
	return (page - 1) * pageSize
}
