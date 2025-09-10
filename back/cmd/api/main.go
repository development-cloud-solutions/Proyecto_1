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
)

func main() {
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found")
	}

	cfg := config.Load()

	db, err := database.Connect(cfg.GetDatabaseDSN())
	if err != nil {
		log.Fatal("Failed to connect to database:", err)
	}
	defer db.Close()

	// Inicializar dependencias compartidas
	fileStorage := storage.NewLocalStorage(cfg.UploadPath)
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
