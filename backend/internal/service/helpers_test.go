package service

import (
	"testing"

	"github.com/google/uuid"
)

func TestParseUUIDValid(t *testing.T) {
	tests := []struct {
		name  string
		input string
	}{
		{
			name:  "standard UUID",
			input: "11111111-1111-1111-1111-111111111111",
		},
		{
			name:  "random UUID",
			input: "550e8400-e29b-41d4-a716-446655440000",
		},
		{
			name:  "nil UUID",
			input: "00000000-0000-0000-0000-000000000000",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := parseUUID(tt.input)
			if err != nil {
				t.Fatalf("parseUUID(%q) returned unexpected error: %v", tt.input, err)
			}

			expected, _ := uuid.Parse(tt.input)
			if result != expected {
				t.Errorf("parseUUID(%q) = %s, want %s", tt.input, result, expected)
			}
		})
	}
}

func TestParseUUIDInvalid(t *testing.T) {
	tests := []struct {
		name  string
		input string
	}{
		{
			name:  "random string",
			input: "not-a-uuid",
		},
		{
			name:  "too short",
			input: "11111111-1111",
		},
		{
			name:  "invalid characters",
			input: "zzzzzzzz-zzzz-zzzz-zzzz-zzzzzzzzzzzz",
		},
		{
			name:  "missing dashes",
			input: "111111111111111111111111111111111111",
		},
		{
			name:  "extra characters",
			input: "11111111-1111-1111-1111-111111111111-extra",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := parseUUID(tt.input)
			if err == nil {
				t.Errorf("parseUUID(%q) expected error, got nil", tt.input)
			}
		})
	}
}

func TestParseUUIDEmpty(t *testing.T) {
	_, err := parseUUID("")
	if err == nil {
		t.Error("parseUUID(\"\") expected error, got nil")
	}
}
