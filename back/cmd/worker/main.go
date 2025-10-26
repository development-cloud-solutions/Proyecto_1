package main

//cmd/worker/
import (
	"log"

	"back/internal/config"
	"back/internal/database"
	"back/internal/services"
	"back/internal/services/storage"
	"back/internal/workers"

	"github.com/joho/godotenv"
	_ "github.com/lib/pq"
)

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

	log.Println("Starting in worker mode...")
	worker := workers.NewVideoProcessor(taskQueue, db, videoService, fileStorage)
	worker.Start()
}
