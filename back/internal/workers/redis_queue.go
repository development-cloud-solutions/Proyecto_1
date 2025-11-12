package workers

import (
	"context"
	"encoding/json"
	"fmt"
	"log"

	"back/internal/config"

	"github.com/hibiken/asynq"
)

// RedisQueueClient implementa QueueClient usando Redis (Asynq)
type RedisQueueClient struct {
	client    *asynq.Client
	server    *asynq.Server
	inspector *asynq.Inspector
	cfg       *config.Config
}

// NewRedisQueueClient crea un nuevo cliente de cola Redis
func NewRedisQueueClient(cfg *config.Config) (*RedisQueueClient, error) {
	redisOpt := asynq.RedisClientOpt{
		Addr: cfg.RedisURL,
	}

	client := asynq.NewClient(redisOpt)
	inspector := asynq.NewInspector(redisOpt)

	return &RedisQueueClient{
		client:    client,
		inspector: inspector,
		cfg:       cfg,
	}, nil
}

// Enqueue agrega una tarea a la cola Redis
func (q *RedisQueueClient) Enqueue(ctx context.Context, taskType string, payload []byte) error {
	task := asynq.NewTask(taskType, payload)
	_, err := q.client.Enqueue(task)
	if err != nil {
		return fmt.Errorf("failed to enqueue task: %w", err)
	}
	return nil
}

// StartWorker inicia el worker de Redis
func (q *RedisQueueClient) StartWorker(ctx context.Context, handler TaskHandler) error {
	redisOpt := asynq.RedisClientOpt{
		Addr: q.cfg.RedisURL,
	}

	q.server = asynq.NewServer(redisOpt, asynq.Config{
		Concurrency: q.cfg.WorkerConcurrency,
	})

	mux := asynq.NewServeMux()

	// Wrapper para convertir TaskHandler a asynq.Handler
	mux.HandleFunc(TypeVideoProcessing, func(ctx context.Context, t *asynq.Task) error {
		return handler(ctx, t.Type(), t.Payload())
	})

	log.Println("Starting Redis worker with Asynq...")
	if err := q.server.Run(mux); err != nil {
		return fmt.Errorf("asynq server error: %w", err)
	}

	return nil
}

// GetQueueDepth retorna la cantidad de mensajes pendientes
func (q *RedisQueueClient) GetQueueDepth(ctx context.Context) (int64, error) {
	stats, err := q.inspector.GetQueueInfo("default")
	if err != nil {
		return 0, fmt.Errorf("failed to get queue stats: %w", err)
	}
	return int64(stats.Pending), nil
}

// Close cierra las conexiones
func (q *RedisQueueClient) Close() error {
	if q.client != nil {
		if err := q.client.Close(); err != nil {
			return err
		}
	}
	if q.server != nil {
		q.server.Shutdown()
	}
	if q.inspector != nil {
		if err := q.inspector.Close(); err != nil {
			return err
		}
	}
	return nil
}

// EnqueueVideoProcessing es un helper específico para encolar procesamiento de video
func (q *RedisQueueClient) EnqueueVideoProcessing(videoID string) error {
	payload, err := json.Marshal(map[string]string{"video_id": videoID})
	if err != nil {
		return err
	}
	return q.Enqueue(context.Background(), TypeVideoProcessing, payload)
}
