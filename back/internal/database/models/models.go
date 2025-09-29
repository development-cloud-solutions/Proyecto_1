// anb-rising-stars\internal\database\models\models.go
package models

import (
	"time"

	"github.com/google/uuid"
)

// User representa un usuario/jugador en el sistema
type User struct {
	ID           int       `json:"id" db:"id" example:"1"`
	FirstName    string    `json:"first_name" db:"first_name" validate:"required,min=2,max=50" example:"Juan"`
	LastName     string    `json:"last_name" db:"last_name" validate:"required,min=2,max=50" example:"Pérez"`
	Email        string    `json:"email" db:"email" validate:"required,email" example:"juan.perez@email.com"`
	PasswordHash string    `json:"-" db:"password_hash"`
	City         string    `json:"city" db:"city" validate:"required,min=2,max=50" example:"Bogotá"`
	Country      string    `json:"country" db:"country" validate:"required,min=2,max=50" example:"Colombia"`
	CreatedAt    time.Time `json:"created_at" db:"created_at" example:"2024-01-15T10:30:00Z"`
	UpdatedAt    time.Time `json:"updated_at" db:"updated_at" example:"2024-01-15T10:30:00Z"`
}

// UserRegistration representa los datos para registro de usuario
type UserRegistration struct {
	FirstName string `json:"first_name" validate:"required,min=2,max=50" example:"Juan"`
	LastName  string `json:"last_name" validate:"required,min=2,max=50" example:"Pérez"`
	Email     string `json:"email" validate:"required,email" example:"juan.perez@email.com"`
	Password1 string `json:"password1" validate:"required,min=8" example:"password123"`
	Password2 string `json:"password2" validate:"required,min=8" example:"password123"`
	City      string `json:"city" validate:"required,min=2,max=50" example:"Bogotá"`
	Country   string `json:"country" validate:"required,min=2,max=50" example:"Colombia"`
}

// UserLogin representa los datos para login
type UserLogin struct {
	Email    string `json:"email" validate:"required,email" example:"juan.perez@email.com"`
	Password string `json:"password" validate:"required" example:"password123"`
}

// Video representa un video en el sistema
type Video struct {
	ID               uuid.UUID  `json:"video_id" db:"id"`
	UserID           int        `json:"user_id" db:"user_id"`
	Title            string     `json:"title" db:"title" validate:"required,min=5,max=100"`
	OriginalFilename string     `json:"original_filename" db:"original_filename"`
	OriginalURL      *string    `json:"original_url,omitempty" db:"original_url"`
	ProcessedURL     *string    `json:"processed_url,omitempty" db:"processed_url"`
	Status           string     `json:"status" db:"status"`
	UploadedAt       time.Time  `json:"uploaded_at" db:"uploaded_at"`
	ProcessedAt      *time.Time `json:"processed_at,omitempty" db:"processed_at"`
	VotesCount       int        `json:"votes" db:"votes_count"`
	IsPublic         bool       `json:"is_public" db:"is_public"`

	// Campos adicionales para joins
	UserFirstName string `json:"user_first_name,omitempty" db:"user_first_name"`
	UserLastName  string `json:"user_last_name,omitempty" db:"user_last_name"`
	UserCity      string `json:"user_city,omitempty" db:"user_city"`
}

// VideoUpload representa los datos para subir un video
type VideoUpload struct {
	Title    string `form:"title" validate:"required,min=5,max=100"`
	IsPublic bool   `form:"is_public"`
}

// Vote representa un voto en el sistema
type Vote struct {
	ID        int       `json:"id" db:"id"`
	UserID    int       `json:"user_id" db:"user_id"`
	VideoID   uuid.UUID `json:"video_id" db:"video_id"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
}

// TaskResult representa el resultado de una tarea asíncrona
type TaskResult struct {
	ID           int        `json:"id" db:"id"`
	TaskID       string     `json:"task_id" db:"task_id"`
	VideoID      *uuid.UUID `json:"video_id,omitempty" db:"video_id"`
	Status       string     `json:"status" db:"status"`
	ErrorMessage *string    `json:"error_message,omitempty" db:"error_message"`
	CreatedAt    time.Time  `json:"created_at" db:"created_at"`
	CompletedAt  *time.Time `json:"completed_at,omitempty" db:"completed_at"`
}

// RankingEntry representa una entrada en el ranking
type RankingEntry struct {
	Position int       `json:"position"`
	VideoID  uuid.UUID `json:"video_id"`
	Username string    `json:"username"`
	Title    string    `json:"title"`
	City     string    `json:"city"`
	Votes    int       `json:"votes"`
	VideoURL string    `json:"video_url,omitempty"`
}

// APIResponse representa una respuesta genérica de la API
type APIResponse struct {
	Message string      `json:"message" example:"Operación exitosa"`
	Data    interface{} `json:"data,omitempty"`
	Error   string      `json:"error,omitempty" example:"Error en la validación"`
}

// LoginResponse representa la respuesta del login
type LoginResponse struct {
	AccessToken string `json:"access_token" example:"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."`
	TokenType   string `json:"token_type" example:"Bearer"`
	ExpiresIn   int    `json:"expires_in" example:"3600"`
}

// VideoStatus constants
const (
	VideoStatusUploaded   = "uploaded"
	VideoStatusProcessing = "processing"
	VideoStatusProcessed  = "processed"
	VideoStatusFailed     = "failed"
)

// TaskStatus constants
const (
	TaskStatusPending   = "pending"
	TaskStatusRunning   = "running"
	TaskStatusCompleted = "completed"
	TaskStatusFailed    = "failed"
)
