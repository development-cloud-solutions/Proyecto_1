package middleware

import (
	"back/internal/config"
	"back/internal/database/models"
	"back/internal/utils"
	"net/http"

	"github.com/gin-gonic/gin"
)

// AuthMiddleware valida el token JWT y guarda el user_id en el contexto de Gin.
func AuthMiddleware(cfg *config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, models.APIResponse{Error: "Authorization header required"})
			c.Abort()
			return
		}

		tokenString, err := utils.ExtractTokenFromHeader(authHeader)
		if err != nil {
			c.JSON(http.StatusUnauthorized, models.APIResponse{Error: "Invalid authorization header format"})
			c.Abort()
			return
		}

		claims, err := utils.ValidateJWT(tokenString, cfg.JWTSecret)
		if err != nil {
			c.JSON(http.StatusUnauthorized, models.APIResponse{Error: "Invalid or expired token"})
			c.Abort()
			return
		}

		c.Set("user_id", int64(claims.UserID))
		c.Next()
	}
}
