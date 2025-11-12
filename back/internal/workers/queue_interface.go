package workers

import (
	"context"
)

// QueueClient es la interfaz genérica para diferentes tipos de colas
type QueueClient interface {
	// Enqueue agrega un mensaje a la cola
	Enqueue(ctx context.Context, taskType string, payload []byte) error

	// StartWorker inicia el worker para procesar mensajes
	StartWorker(ctx context.Context, handler TaskHandler) error

	// Close cierra la conexión con la cola
	Close() error

	// GetQueueDepth retorna la cantidad de mensajes pendientes en la cola
	GetQueueDepth(ctx context.Context) (int64, error)
}

// TaskHandler es la función que procesa una tarea
type TaskHandler func(ctx context.Context, taskType string, payload []byte) error
