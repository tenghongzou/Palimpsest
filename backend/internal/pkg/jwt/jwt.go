package jwt

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

// Token types. Only access tokens are accepted by the Auth middleware.
const (
	TypeAccess        = "access"
	TypeRefresh       = "refresh"
	TypePasswordReset = "password_reset"
)

// ErrWrongTokenType is returned when a token is valid but of an unexpected type.
var ErrWrongTokenType = errors.New("wrong token type")

type Claims struct {
	UserID uuid.UUID `json:"user_id"`
	Role   string    `json:"role"`
	Type   string    `json:"typ"`
	jwt.RegisteredClaims
}

// GenerateAccessToken creates a JWT access token valid for the given duration.
func GenerateAccessToken(secret string, userID uuid.UUID, role string, expiry time.Duration) (string, error) {
	return GenerateToken(secret, userID, role, TypeAccess, expiry)
}

// GenerateToken creates a JWT of the given type valid for the given duration.
func GenerateToken(secret string, userID uuid.UUID, role, tokenType string, expiry time.Duration) (string, error) {
	claims := Claims{
		UserID: userID,
		Role:   role,
		Type:   tokenType,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(expiry)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Issuer:    "palimpsest",
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(secret))
}

// ValidateToken parses and validates a JWT token string.
func ValidateToken(secret, tokenString string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		return []byte(secret), nil
	}, jwt.WithValidMethods([]string{jwt.SigningMethodHS256.Alg()}))
	if err != nil {
		return nil, err
	}

	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, jwt.ErrSignatureInvalid
	}

	return claims, nil
}

// ValidateTokenType validates a token and ensures it has the expected type.
func ValidateTokenType(secret, tokenString, tokenType string) (*Claims, error) {
	claims, err := ValidateToken(secret, tokenString)
	if err != nil {
		return nil, err
	}
	if claims.Type != tokenType {
		return nil, ErrWrongTokenType
	}
	return claims, nil
}
