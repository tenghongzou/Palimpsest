package service

// AuthService handles authentication business logic.
type AuthService struct {
	// TODO: inject UserRepository, JWTHelper, RedisClient
}

func NewAuthService() *AuthService {
	return &AuthService{}
}

// TODO: implement Register, Login, RefreshToken, Logout, ForgotPassword, ResetPassword
