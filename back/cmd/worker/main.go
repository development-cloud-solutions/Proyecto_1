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
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found")
	}

	cfg := config.Load()

	db, err := database.Connect(cfg.GetDatabaseDSN())
	if err != nil {
		log.Fatal("Failed to connect to database:", err)
	}
	defer db.Close()

	fileStorage := storage.NewLocalStorage(cfg.UploadPath)
	videoService := services.NewVideoService(db, cfg, fileStorage)
	taskQueue := workers.NewTaskQueue(cfg)

	log.Println("Starting in worker mode...")
	worker := workers.NewVideoProcessor(taskQueue, db, videoService)
	worker.Start()
}
