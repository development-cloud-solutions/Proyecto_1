package main

import (
	"log"
	"os"

	"back/internal/api"
	"back/internal/config"
	"back/internal/database"
	"back/internal/services"
	"back/internal/services/storage"
	"back/internal/workers"

	"github.com/joho/godotenv"
	_ "github.com/lib/pq"

	_ "back/docs" // Importar documentos generados por swag
)

// @title ANB Rising Stars Showcase API
// @version 1.0
// @description API para la plataforma ANB Rising Stars donde los usuarios pueden subir videos y participar en votaciones
// @termsOfService http://swagger.io/terms/

// @contact.name Soporte API
// @contact.url http://www.swagger.io/support
// @contact.email support@swagger.io

// @license.name MIT
// @license.url https://opensource.org/licenses/MIT

// @host localhost
// @BasePath /api

// @securityDefinitions.apikey BearerAuth
// @in header
// @name Authorization
// @description Ingresa 'Bearer ' seguido de tu JWT token

func main() {
	// Intentar cargar .env si existe
	_ = godotenv.Load()

	cfg := config.Load()

	db, err := database.Connect(cfg.GetDatabaseDSN())
	if err != nil {
		log.Fatal("Failed to connect to database:", err)
	}
	defer db.Close()

	// Inicializar storage según configuración (local o S3)
	fileStorage, err := storage.NewStorage(cfg)
	if err != nil {
		log.Fatal("Failed to initialize storage:", err)
	}

	videoService := services.NewVideoService(db, cfg, fileStorage)
	taskQueue := workers.NewTaskQueue(cfg)

	// Inicializar worker si está en modo worker
	if os.Getenv("WORKER_MODE") == "true" {
		log.Println("Starting in worker mode...")
		worker := workers.NewVideoProcessor(taskQueue, db, videoService)
		worker.Start()
		return
	}

	// Configurar rutas de la API
	router := api.SetupRoutes(db, cfg, taskQueue, videoService)

	log.Printf("Server starting on port %s", cfg.Port)
	if err := router.Run(":" + cfg.Port); err != nil {
		log.Fatal("Failed to start server:", err)
	}
}
