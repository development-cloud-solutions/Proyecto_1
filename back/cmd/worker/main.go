package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"syscall"

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

	log.Printf("Starting worker with configuration:")
	log.Printf("  - Queue Type: %s", cfg.QueueType)
	log.Printf("  - Storage Type: %s", cfg.StorageType)
	log.Printf("  - Worker Concurrency: %d", cfg.WorkerConcurrency)

	// Conectar a la base de datos
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

	// Crear TaskQueue con soporte dual Redis/SQS
	taskQueue, err := workers.NewTaskQueue(cfg)
	if err != nil {
		log.Fatal("Failed to create task queue:", err)
	}
	defer taskQueue.Close()

	// Crear el procesador de videos
	worker := workers.NewVideoProcessor(taskQueue, db, videoService, fileStorage)

	// Context con cancelación para shutdown graceful
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Manejar señales para shutdown graceful
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

	go func() {
		<-sigChan
		log.Println("Received shutdown signal, stopping worker...")
		cancel()
	}()

	// Iniciar el worker (bloqueante)
	log.Println("Starting video processing worker...")
	if err := worker.Start(ctx); err != nil {
		if err == context.Canceled {
			log.Println("Worker stopped gracefully")
		} else {
			log.Fatal("Worker error:", err)
		}
	}
}
