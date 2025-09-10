package workers

import (
	"database/sql"
	"encoding/json"
	"fmt"

	"back/internal/config"
	"back/internal/services"

	"github.com/hibiken/asynq"
)

const (
	TypeVideoProcessing = "video:processing"
)

// TaskQueue wraps el cliente asynq y provee helpers para encolar tareas
type TaskQueue struct {
	client *asynq.Client
	cfg    *config.Config
}

func NewTaskQueue(cfg *config.Config) *TaskQueue {
	redisOpt := asynq.RedisClientOpt{
		Addr: cfg.RedisURL, // Corregido: usa RedisURL
	}
	client := asynq.NewClient(redisOpt)
	return &TaskQueue{
		client: client,
		cfg:    cfg,
	}
}

// EnqueueVideoProcessing encola una tarea para procesar un video
func (q *TaskQueue) EnqueueVideoProcessing(videoID string) error {
	payload, err := json.Marshal(map[string]string{"video_id": videoID})
	if err != nil {
		return err
	}
	task := asynq.NewTask(TypeVideoProcessing, payload)
	_, err = q.client.Enqueue(task)
	if err != nil {
		return fmt.Errorf("enqueue failed: %w", err)
	}
	return nil
}

// NewServer crea un server asynq y registra handlers (retorna el server para Start)
func NewServer(cfg *config.Config, videoService services.VideoServiceInterface, db *sql.DB) *asynq.Server {
	redisOpt := asynq.RedisClientOpt{
		Addr: cfg.RedisURL, // Corregido: usa RedisURL
	}

	mux := asynq.NewServeMux()

	processor := &VideoProcessor{
		config:       cfg,
		videoService: videoService,
		db:           db,
	}

	mux.HandleFunc(TypeVideoProcessing, processor.HandleVideoProcessing)

	srv := asynq.NewServer(redisOpt, asynq.Config{
		Concurrency: cfg.WorkerConcurrency, // Corregido: usa WorkerConcurrency
	})

	return srv
}
