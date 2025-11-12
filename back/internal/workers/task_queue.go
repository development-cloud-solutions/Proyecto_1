package workers

import (
	"context"
	"encoding/json"
	"fmt"

	"back/internal/config"
)

const (
	TypeVideoProcessing = "video:processing"
)

// TaskQueue wraps el cliente de cola y provee helpers para encolar tareas
// Compatible con Redis (Asynq) y SQS
type TaskQueue struct {
	client QueueClient
	cfg    *config.Config
}

// NewTaskQueue crea una nueva instancia de TaskQueue usando la configuración
func NewTaskQueue(cfg *config.Config) (*TaskQueue, error) {
	client, err := NewQueueClient(cfg)
	if err != nil {
		return nil, fmt.Errorf("failed to create queue client: %w", err)
	}

	return &TaskQueue{
		client: client,
		cfg:    cfg,
	}, nil
}

// EnqueueVideoProcessing encola una tarea para procesar un video
func (q *TaskQueue) EnqueueVideoProcessing(videoID string) error {
	payload, err := json.Marshal(map[string]string{"video_id": videoID})
	if err != nil {
		return err
	}

	if err := q.client.Enqueue(context.Background(), TypeVideoProcessing, payload); err != nil {
		return fmt.Errorf("enqueue failed: %w", err)
	}

	return nil
}

// GetQueueDepth retorna la cantidad de mensajes pendientes en la cola
func (q *TaskQueue) GetQueueDepth() (int64, error) {
	return q.client.GetQueueDepth(context.Background())
}

// Close cierra la conexión con la cola
func (q *TaskQueue) Close() error {
	return q.client.Close()
}

// GetClient retorna el cliente subyacente (para casos especiales)
func (q *TaskQueue) GetClient() QueueClient {
	return q.client
}
