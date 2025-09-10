package services

import (
	"database/sql"
	"time"

	"back/internal/config"
	"back/internal/database/models"
)

type AuthService struct {
	db     *sql.DB
	config *config.Config
}

func NewAuthService(db *sql.DB, cfg *config.Config) *AuthService {
	return &AuthService{
		db:     db,
		config: cfg,
	}
}

// EmailExists verifica si un email ya está registrado
func (s *AuthService) EmailExists(email string) (bool, error) {
	var count int
	query := `SELECT COUNT(*) FROM users WHERE email = $1`

	err := s.db.QueryRow(query, email).Scan(&count)
	if err != nil {
		return false, err
	}

	return count > 0, nil
}

// CreateUser crea un nuevo usuario en la base de datos
func (s *AuthService) CreateUser(user *models.User) error {
	query := `
		INSERT INTO users (first_name, last_name, email, password_hash, city, country, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		RETURNING id`

	err := s.db.QueryRow(
		query,
		user.FirstName,
		user.LastName,
		user.Email,
		user.PasswordHash,
		user.City,
		user.Country,
		time.Now(),
		time.Now(),
	).Scan(&user.ID)

	return err
}

// GetUserByEmail busca un usuario por email
func (s *AuthService) GetUserByEmail(email string) (*models.User, error) {
	user := &models.User{}
	query := `
		SELECT id, first_name, last_name, email, password_hash, city, country, created_at, updated_at
		FROM users
		WHERE email = $1`

	err := s.db.QueryRow(query, email).Scan(
		&user.ID,
		&user.FirstName,
		&user.LastName,
		&user.Email,
		&user.PasswordHash,
		&user.City,
		&user.Country,
		&user.CreatedAt,
		&user.UpdatedAt,
	)

	if err != nil {
		return nil, err
	}

	return user, nil
}

// GetUserByID busca un usuario por ID
func (s *AuthService) GetUserByID(id int) (*models.User, error) {
	user := &models.User{}
	query := `
		SELECT id, first_name, last_name, email, password_hash, city, country, created_at, updated_at
		FROM users
		WHERE id = $1`

	err := s.db.QueryRow(query, id).Scan(
		&user.ID,
		&user.FirstName,
		&user.LastName,
		&user.Email,
		&user.PasswordHash,
		&user.City,
		&user.Country,
		&user.CreatedAt,
		&user.UpdatedAt,
	)

	if err != nil {
		return nil, err
	}

	return user, nil
}

// UpdateUser actualiza la información de un usuario
func (s *AuthService) UpdateUser(user *models.User) error {
	query := `
		UPDATE users 
		SET first_name = $1, last_name = $2, city = $3, country = $4, updated_at = $5
		WHERE id = $6`

	_, err := s.db.Exec(
		query,
		user.FirstName,
		user.LastName,
		user.City,
		user.Country,
		time.Now(),
		user.ID,
	)

	return err
}

// UpdateUserPassword actualiza la contraseña de un usuario
func (s *AuthService) UpdateUserPassword(userID int, newPasswordHash string) error {
	query := `UPDATE users SET password_hash = $1, updated_at = $2 WHERE id = $3`

	_, err := s.db.Exec(query, newPasswordHash, time.Now(), userID)
	return err
}

// DeleteUser elimina un usuario (soft delete o hard delete según configuración)
func (s *AuthService) DeleteUser(userID int) error {
	// Hard delete - en un entorno real podrías querer hacer soft delete
	query := `DELETE FROM users WHERE id = $1`

	_, err := s.db.Exec(query, userID)
	return err
}

// GetUserStats obtiene estadísticas del usuario
func (s *AuthService) GetUserStats(userID int) (map[string]interface{}, error) {
	stats := make(map[string]interface{})

	// Contar videos subidos
	var videoCount int
	err := s.db.QueryRow(`SELECT COUNT(*) FROM videos WHERE user_id = $1`, userID).Scan(&videoCount)
	if err != nil {
		return nil, err
	}
	stats["videos_uploaded"] = videoCount

	// Contar videos procesados
	var processedCount int
	err = s.db.QueryRow(`SELECT COUNT(*) FROM videos WHERE user_id = $1 AND status = 'processed'`, userID).Scan(&processedCount)
	if err != nil {
		return nil, err
	}
	stats["videos_processed"] = processedCount

	// Contar votos totales recibidos
	var totalVotes int
	err = s.db.QueryRow(`SELECT COALESCE(SUM(votes_count), 0) FROM videos WHERE user_id = $1`, userID).Scan(&totalVotes)
	if err != nil {
		return nil, err
	}
	stats["total_votes_received"] = totalVotes

	// Contar votos dados
	var votesGiven int
	err = s.db.QueryRow(`SELECT COUNT(*) FROM votes WHERE user_id = $1`, userID).Scan(&votesGiven)
	if err != nil {
		return nil, err
	}
	stats["votes_given"] = votesGiven

	return stats, nil
}
