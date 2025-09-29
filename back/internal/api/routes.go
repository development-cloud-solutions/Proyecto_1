package api

import (
	"database/sql"
	"net/http"
	"time"

	"back/internal/api/handlers"
	"back/internal/api/middleware"
	"back/internal/config"
	"back/internal/services"
	"back/internal/workers"

	"github.com/gin-gonic/gin"
)

// SetupRoutes configura todas las rutas de la aplicación
func SetupRoutes(db *sql.DB, cfg *config.Config, taskQueue *workers.TaskQueue, videoService services.VideoServiceInterface) *gin.Engine {
	router := gin.New()
	router.Use(gin.Recovery(), gin.Logger())

	router.Use(func(c *gin.Context) {
		origin := c.Request.Header.Get("Origin")
		c.Header("Access-Control-Allow-Origin", origin)
		c.Header("Access-Control-Allow-Credentials", "true")
		c.Header("Access-Control-Allow-Headers", "Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, accept, origin, Cache-Control, X-Requested-With")
		c.Header("Access-Control-Allow-Methods", "POST, OPTIONS, GET, PUT, DELETE")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	})

	// Inicializar handlers inyectando dependencias
	authHandler := handlers.NewAuthHandler(db, cfg)
	videoHandler := handlers.NewVideoHandler(db, cfg, taskQueue, videoService)
	rankingHandler := handlers.NewRankingHandler(db, cfg)

	// Health
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":    "healthy",
			"timestamp": time.Now().UTC().Format(time.RFC3339),
			"version":   "1.0.0",
		})
	})

	// Auth routes
	authGroup := router.Group("/api/auth")
	{
		authGroup.POST("/signup", authHandler.Signup)
		authGroup.POST("/login", authHandler.Login)
		authGroup.POST("/logout", middleware.AuthMiddleware(cfg), authHandler.Logout)
		authGroup.GET("/profile", middleware.AuthMiddleware(cfg), authHandler.GetProfile)
	}

	// Protected video routes
	videosGroup := router.Group("/api/videos")
	videosGroup.Use(middleware.AuthMiddleware(cfg))
	{
		videosGroup.POST("/upload", videoHandler.UploadVideo)
		videosGroup.GET("", videoHandler.GetMyVideos)
		videosGroup.GET("/:video_id", videoHandler.GetVideoDetail)
		videosGroup.DELETE("/:video_id", videoHandler.DeleteVideo)
	}

	// Protected user routes
	userGroup := router.Group("/api/user")
	userGroup.Use(middleware.AuthMiddleware(cfg))
	{
		userGroup.GET("/votes", rankingHandler.GetUserVotes)
	}

	// Rutas públicas para videos
	publicGroup := router.Group("/api/public")
	{
		// Listar videos públicos disponibles para votación
		publicGroup.GET("/videos", rankingHandler.ListPublicVideos)

		// Emitir voto por un video público (requiere autenticación)
		publicGroup.POST("/videos/:video_id/vote", middleware.AuthMiddleware(cfg), rankingHandler.VoteVideo)

		// Consultar tabla de clasificación/ranking
		publicGroup.GET("/rankings", rankingHandler.GetRankings)
	}

	return router
}
