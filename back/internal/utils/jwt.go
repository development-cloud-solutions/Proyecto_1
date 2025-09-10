package utils

import (
	"fmt"
	"os"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

type Claims struct {
	UserID int    `json:"user_id"`
	Email  string `json:"email"`
	jwt.RegisteredClaims
}

// GenerateJWT genera un token JWT para un usuario
func GenerateJWT(userID int, email, secretKey string, expiration time.Duration) (string, error) {
	// Crear claims
	claims := &Claims{
		UserID: userID,
		Email:  email,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(expiration)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			NotBefore: jwt.NewNumericDate(time.Now()),
			Issuer:    "anb-rising-stars",
			Subject:   fmt.Sprintf("user:%d", userID),
			ID:        fmt.Sprintf("%d_%d", userID, time.Now().Unix()),
		},
	}

	// Crear token
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)

	// Firmar token
	tokenString, err := token.SignedString([]byte(secretKey))
	if err != nil {
		return "", fmt.Errorf("failed to sign token: %v", err)
	}

	return tokenString, nil
}

// ValidateJWT valida un token JWT y retorna los claims
func ValidateJWT(tokenString, secretKey string) (*Claims, error) {
	// Parsear token
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		// Verificar método de firma
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return []byte(secretKey), nil
	})

	if err != nil {
		return nil, fmt.Errorf("failed to parse token: %v", err)
	}

	// Verificar validez del token
	if !token.Valid {
		return nil, fmt.Errorf("invalid token")
	}

	// Extraer claims
	claims, ok := token.Claims.(*Claims)
	if !ok {
		return nil, fmt.Errorf("invalid token claims")
	}

	return claims, nil
}

// RefreshJWT genera un nuevo token basado en uno existente (si está cerca de expirar)
func RefreshJWT(tokenString, secretKey string, expiration time.Duration) (string, error) {
	// Validar token actual
	claims, err := ValidateJWT(tokenString, secretKey)
	if err != nil {
		return "", fmt.Errorf("invalid token for refresh: %v", err)
	}

	// Verificar si el token está cerca de expirar (dentro de los próximos 15 minutos)
	timeUntilExp := time.Until(claims.ExpiresAt.Time)
	if timeUntilExp > 15*time.Minute {
		return "", fmt.Errorf("token is not eligible for refresh yet")
	}

	// Generar nuevo token
	return GenerateJWT(claims.UserID, claims.Email, secretKey, expiration)
}

// ExtractTokenFromHeader extrae el token del header Authorization
func ExtractTokenFromHeader(authHeader string) (string, error) {
	if authHeader == "" {
		return "", fmt.Errorf("authorization header is empty")
	}

	// Formato esperado: "Bearer <token>"
	if len(authHeader) < 7 || authHeader[:7] != "Bearer " {
		return "", fmt.Errorf("invalid authorization header format")
	}

	token := authHeader[7:]
	if token == "" {
		return "", fmt.Errorf("empty token")
	}

	return token, nil
}

// GetUserIDFromToken extrae el ID del usuario de un token válido
func GetUserIDFromToken(tokenString, secretKey string) (int, error) {
	claims, err := ValidateJWT(tokenString, secretKey)
	if err != nil {
		return 0, err
	}

	return claims.UserID, nil
}

// GetEmailFromToken extrae el email del usuario de un token válido
func GetEmailFromToken(tokenString, secretKey string) (string, error) {
	claims, err := ValidateJWT(tokenString, secretKey)
	if err != nil {
		return "", err
	}

	return claims.Email, nil
}

func GetJWTSecret() string {
	return os.Getenv("JWT_SECRET")
}
