package workers

import (
	"fmt"
	"strings"

	"back/internal/config"
)

// NewQueueClient crea una instancia de QueueClient según la configuración
func NewQueueClient(cfg *config.Config) (QueueClient, error) {
	queueType := strings.ToLower(cfg.QueueType)

	switch queueType {
	case "sqs":
		return NewSQSQueueClient(cfg)
	case "redis":
		return NewRedisQueueClient(cfg)
	default:
		return nil, fmt.Errorf("unsupported queue type: %s (supported: redis, sqs)", cfg.QueueType)
	}
}
