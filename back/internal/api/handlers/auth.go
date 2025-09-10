package handlers

import (
	"database/sql"
	"net/http"
	"time"

	"back/internal/config"
	"back/internal/database/models"
	"back/internal/services"
	"back/internal/utils"

	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"
)

type AuthHandler struct {
	db          *sql.DB
	config      *config.Config
	validator   *validator.Validate
	authService *services.AuthService
}

func NewAuthHandler(db *sql.DB, cfg *config.Config) *AuthHandler {
	return &AuthHandler{
		db:          db,
		config:      cfg,
		validator:   validator.New(),
		authService: services.NewAuthService(db, cfg),
	}
}

// Signup maneja el registro de nuevos usuarios
func (h *AuthHandler) Signup(c *gin.Context) {
	var req models.UserRegistration

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Error: "Invalid request format",
		})
		return
	}

	// Validar datos de entrada
	if err := h.validator.Struct(req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Error: "Validation failed: " + err.Error(),
		})
		return
	}

	// Validar que las contraseñas coincidan
	if req.Password1 != req.Password2 {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Error: "Passwords do not match",
		})
		return
	}

	// Verificar si el email ya existe
	if exists, err := h.authService.EmailExists(req.Email); err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Error: "Internal server error",
		})
		return
	} else if exists {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Error: "Email already registered",
		})
		return
	}

	// Hash de la contraseña
	hashedPassword, err := utils.HashPassword(req.Password1)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Error: "Internal server error",
		})
		return
	}

	// Crear usuario
	user := &models.User{
		FirstName:    req.FirstName,
		LastName:     req.LastName,
		Email:        req.Email,
		PasswordHash: hashedPassword,
		City:         req.City,
		Country:      req.Country,
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}

	if err := h.authService.CreateUser(user); err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Error: "Failed to create user",
		})
		return
	}

	c.JSON(http.StatusCreated, models.APIResponse{
		Message: "User created successfully",
	})
}

// Login maneja la autenticación de usuarios
func (h *AuthHandler) Login(c *gin.Context) {
	var req models.UserLogin

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Error: "Invalid request format",
		})
		return
	}

	// Validar datos de entrada
	if err := h.validator.Struct(req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Error: "Validation failed: " + err.Error(),
		})
		return
	}

	// Buscar usuario por email
	user, err := h.authService.GetUserByEmail(req.Email)
	if err != nil {
		c.JSON(http.StatusUnauthorized, models.APIResponse{
			Error: "Invalid credentials",
		})
		return
	}

	// Verificar contraseña
	if !utils.CheckPassword(req.Password, user.PasswordHash) {
		c.JSON(http.StatusUnauthorized, models.APIResponse{
			Error: "Invalid credentials",
		})
		return
	}

	// Generar JWT token
	token, err := utils.GenerateJWT(user.ID, user.Email, h.config.JWTSecret, h.config.JWTExpiration)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Error: "Failed to generate token",
		})
		return
	}

	response := models.LoginResponse{
		AccessToken: token,
		TokenType:   "Bearer",
		ExpiresIn:   int(h.config.JWTExpiration.Seconds()),
	}

	c.JSON(http.StatusOK, response)
}

// GetProfile retorna el perfil del usuario autenticado
func (h *AuthHandler) GetProfile(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, models.APIResponse{
			Error: "User not authenticated",
		})
		return
	}

	user, err := h.authService.GetUserByID(int(userID.(int64)))
	if err != nil {
		c.JSON(http.StatusNotFound, models.APIResponse{
			Error: "User not found",
		})
		return
	}

	c.JSON(http.StatusOK, user)
}
