package service

import (
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/tenghongzou/palimpsest/backend/internal/config"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	jwtpkg "github.com/tenghongzou/palimpsest/backend/internal/pkg/jwt"
	"github.com/tenghongzou/palimpsest/backend/internal/repository"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

var (
	ErrUserNotFound       = errors.New("user not found")
	ErrInvalidCredentials = errors.New("invalid credentials")
	ErrUsernameExists     = errors.New("username already exists")
	ErrEmailExists        = errors.New("email already exists")
	ErrInvalidToken       = errors.New("invalid token")
	ErrUserBanned         = errors.New("user account is banned")
)

type RegisterRequest struct {
	Username string `json:"username" binding:"required,min=3,max=50"`
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=8,max=72"`
	Nickname string `json:"nickname" binding:"max=50"`
}

type LoginRequest struct {
	// Login accepts either a username or an email address.
	Login    string `json:"login" binding:"required"`
	Password string `json:"password" binding:"required"`
}

type RefreshRequest struct {
	RefreshToken string `json:"refresh_token" binding:"required"`
}

type ForgotPasswordRequest struct {
	Email string `json:"email" binding:"required,email"`
}

type ResetPasswordRequest struct {
	Token       string `json:"token" binding:"required"`
	NewPassword string `json:"new_password" binding:"required,min=8,max=72"`
}

type TokenPair struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int    `json:"expires_in"`
}

// AuthResult is returned by register, login and refresh.
type AuthResult struct {
	User *model.User `json:"user"`
	TokenPair
}

type AuthService struct {
	userRepo *repository.UserRepository
	cfg      *config.Config
}

func NewAuthService(userRepo *repository.UserRepository, cfg *config.Config) *AuthService {
	return &AuthService{userRepo: userRepo, cfg: cfg}
}

func (s *AuthService) Register(req *RegisterRequest) (*model.User, *TokenPair, error) {
	if _, err := s.userRepo.FindByUsername(req.Username); err == nil {
		return nil, nil, ErrUsernameExists
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil, err
	}

	if _, err := s.userRepo.FindByEmail(req.Email); err == nil {
		return nil, nil, ErrEmailExists
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil, err
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, nil, err
	}

	nickname := req.Nickname
	if nickname == "" {
		nickname = req.Username
	}

	email := req.Email
	user := &model.User{
		Username:     req.Username,
		Email:        &email,
		PasswordHash: string(hash),
		Nickname:     nickname,
		Role:         "reader",
		Status:       "active",
		LanguagePref: "zh-TW",
	}

	if err := s.userRepo.Create(user); err != nil {
		return nil, nil, err
	}

	tokens, err := s.generateTokenPair(user.ID, user.Role)
	if err != nil {
		return nil, nil, err
	}

	return user, tokens, nil
}

func (s *AuthService) Login(req *LoginRequest) (*model.User, *TokenPair, error) {
	user, err := s.userRepo.FindByUsername(req.Login)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		user, err = s.userRepo.FindByEmail(req.Login)
	}
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil, ErrInvalidCredentials
		}
		return nil, nil, err
	}

	if user.Status == "banned" {
		return nil, nil, ErrUserBanned
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		return nil, nil, ErrInvalidCredentials
	}

	now := time.Now()
	user.LastLoginAt = &now
	_ = s.userRepo.Update(user)

	tokens, err := s.generateTokenPair(user.ID, user.Role)
	if err != nil {
		return nil, nil, err
	}

	return user, tokens, nil
}

func (s *AuthService) RefreshToken(req *RefreshRequest) (*model.User, *TokenPair, error) {
	claims, err := jwtpkg.ValidateTokenType(s.cfg.JWT.Secret, req.RefreshToken, jwtpkg.TypeRefresh)
	if err != nil {
		return nil, nil, ErrInvalidToken
	}

	user, err := s.userRepo.FindByID(claims.UserID)
	if err != nil {
		return nil, nil, ErrUserNotFound
	}
	if user.Status == "banned" {
		return nil, nil, ErrUserBanned
	}

	tokens, err := s.generateTokenPair(user.ID, user.Role)
	if err != nil {
		return nil, nil, err
	}
	return user, tokens, nil
}

func (s *AuthService) ForgotPassword(req *ForgotPasswordRequest) (string, error) {
	user, err := s.userRepo.FindByEmail(req.Email)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return "", nil // prevent email enumeration
		}
		return "", err
	}

	return jwtpkg.GenerateToken(s.cfg.JWT.Secret, user.ID, user.Role, jwtpkg.TypePasswordReset, time.Hour)
}

func (s *AuthService) ResetPassword(req *ResetPasswordRequest) error {
	claims, err := jwtpkg.ValidateTokenType(s.cfg.JWT.Secret, req.Token, jwtpkg.TypePasswordReset)
	if err != nil {
		return ErrInvalidToken
	}

	user, err := s.userRepo.FindByID(claims.UserID)
	if err != nil {
		return ErrUserNotFound
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), bcrypt.DefaultCost)
	if err != nil {
		return err
	}

	user.PasswordHash = string(hash)
	return s.userRepo.Update(user)
}

func (s *AuthService) generateTokenPair(userID uuid.UUID, role string) (*TokenPair, error) {
	accessExpiry := time.Duration(s.cfg.JWT.AccessExpiryHrs) * time.Hour
	refreshExpiry := time.Duration(s.cfg.JWT.RefreshExpiryDays) * 24 * time.Hour

	accessToken, err := jwtpkg.GenerateAccessToken(s.cfg.JWT.Secret, userID, role, accessExpiry)
	if err != nil {
		return nil, err
	}

	refreshToken, err := jwtpkg.GenerateToken(s.cfg.JWT.Secret, userID, role, jwtpkg.TypeRefresh, refreshExpiry)
	if err != nil {
		return nil, err
	}

	return &TokenPair{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresIn:    s.cfg.JWT.AccessExpiryHrs * 3600,
	}, nil
}
