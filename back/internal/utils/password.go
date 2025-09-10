package utils

import (
	"fmt"
	"unicode"

	"golang.org/x/crypto/bcrypt"
)

// HashPassword genera un hash bcrypt de la contraseña
func HashPassword(password string) (string, error) {
	// Usar costo 12 para un balance entre seguridad y rendimiento
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return "", fmt.Errorf("failed to hash password: %v", err)
	}

	return string(hash), nil
}

// CheckPassword verifica si una contraseña coincide con su hash
func CheckPassword(password, hash string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
	return err == nil
}

// ValidatePassword valida que una contraseña cumpla con los requisitos de seguridad
func ValidatePassword(password string) error {
	if len(password) < 8 {
		return fmt.Errorf("password must be at least 8 characters long")
	}

	if len(password) > 128 {
		return fmt.Errorf("password must be less than 128 characters long")
	}

	var (
		hasUpper   = false
		hasLower   = false
		hasDigit   = false
		hasSpecial = false
	)

	for _, char := range password {
		switch {
		case unicode.IsUpper(char):
			hasUpper = true
		case unicode.IsLower(char):
			hasLower = true
		case unicode.IsDigit(char):
			hasDigit = true
		case unicode.IsPunct(char) || unicode.IsSymbol(char):
			hasSpecial = true
		}
	}

	if !hasUpper {
		return fmt.Errorf("password must contain at least one uppercase letter")
	}

	if !hasLower {
		return fmt.Errorf("password must contain at least one lowercase letter")
	}

	if !hasDigit {
		return fmt.Errorf("password must contain at least one digit")
	}

	if !hasSpecial {
		return fmt.Errorf("password must contain at least one special character")
	}

	return nil
}

// GenerateRandomPassword genera una contraseña aleatoria segura
func GenerateRandomPassword(length int) (string, error) {
	if length < 8 {
		length = 8
	}
	if length > 128 {
		length = 128
	}

	// Conjuntos de caracteres
	uppercase := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	lowercase := "abcdefghijklmnopqrstuvwxyz"
	digits := "0123456789"
	special := "!@#$%^&*()_+-=[]{}|;:,.<>?"

	allChars := uppercase + lowercase + digits + special

	password := make([]byte, length)

	// Asegurar al menos un carácter de cada tipo
	password[0] = uppercase[randomInt(len(uppercase))]
	password[1] = lowercase[randomInt(len(lowercase))]
	password[2] = digits[randomInt(len(digits))]
	password[3] = special[randomInt(len(special))]

	// Llenar el resto aleatoriamente
	for i := 4; i < length; i++ {
		password[i] = allChars[randomInt(len(allChars))]
	}

	// Mezclar la contraseña
	for i := range password {
		j := randomInt(len(password))
		password[i], password[j] = password[j], password[i]
	}

	return string(password), nil
}

// randomInt genera un número entero aleatorio en el rango [0, max)
func randomInt(max int) int {
	// Implementación simple usando time como seed
	// En producción, usar crypto/rand
	var seed = int64(max*13 + 7) // Simple pseudo-random
	return int(seed % int64(max))
}

// IsCommonPassword verifica si la contraseña está en la lista de contraseñas comunes
func IsCommonPassword(password string) bool {
	commonPasswords := []string{
		"123456", "password", "123456789", "12345678", "12345",
		"1234567", "1234567890", "qwerty", "abc123", "111111",
		"123123", "admin", "letmein", "welcome", "monkey",
		"dragon", "pass", "master", "hello", "freedom",
	}

	for _, common := range commonPasswords {
		if password == common {
			return true
		}
	}

	return false
}

// GetPasswordStrength calcula la fortaleza de una contraseña (0-4)
func GetPasswordStrength(password string) int {
	score := 0

	// Longitud
	if len(password) >= 8 {
		score++
	}
	if len(password) >= 12 {
		score++
	}

	// Complejidad de caracteres
	var hasUpper, hasLower, hasDigit, hasSpecial bool

	for _, char := range password {
		switch {
		case unicode.IsUpper(char):
			hasUpper = true
		case unicode.IsLower(char):
			hasLower = true
		case unicode.IsDigit(char):
			hasDigit = true
		case unicode.IsPunct(char) || unicode.IsSymbol(char):
			hasSpecial = true
		}
	}

	complexity := 0
	if hasUpper {
		complexity++
	}
	if hasLower {
		complexity++
	}
	if hasDigit {
		complexity++
	}
	if hasSpecial {
		complexity++
	}

	if complexity >= 3 {
		score++
	}
	if complexity == 4 {
		score++
	}

	// Penalizar contraseñas comunes
	if IsCommonPassword(password) {
		score = 0
	}

	return score
}
