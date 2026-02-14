package jwt

import (
	"testing"
	"time"

	"github.com/google/uuid"
)

const testSecret = "test-secret-key-for-unit-tests"

func TestGenerateAndValidateToken(t *testing.T) {
	userID := uuid.New()
	role := "user"
	expiry := 1 * time.Hour

	tokenStr, err := GenerateAccessToken(testSecret, userID, role, expiry)
	if err != nil {
		t.Fatalf("GenerateAccessToken() error: %v", err)
	}
	if tokenStr == "" {
		t.Fatal("GenerateAccessToken() returned empty token")
	}

	claims, err := ValidateToken(testSecret, tokenStr)
	if err != nil {
		t.Fatalf("ValidateToken() error: %v", err)
	}
	if claims.UserID != userID {
		t.Errorf("expected userID %s, got %s", userID, claims.UserID)
	}
	if claims.Role != role {
		t.Errorf("expected role %s, got %s", role, claims.Role)
	}
	if claims.Issuer != "palimpsest" {
		t.Errorf("expected issuer 'palimpsest', got %s", claims.Issuer)
	}
}

func TestValidateTokenInvalidSecret(t *testing.T) {
	userID := uuid.New()
	tokenStr, _ := GenerateAccessToken(testSecret, userID, "user", 1*time.Hour)

	_, err := ValidateToken("wrong-secret", tokenStr)
	if err == nil {
		t.Error("expected error for wrong secret, got nil")
	}
}

func TestValidateTokenExpired(t *testing.T) {
	userID := uuid.New()
	tokenStr, _ := GenerateAccessToken(testSecret, userID, "user", -1*time.Hour)

	_, err := ValidateToken(testSecret, tokenStr)
	if err == nil {
		t.Error("expected error for expired token, got nil")
	}
}
