package workers

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"time"

	"back/internal/config"

	"github.com/aws/aws-sdk-go-v2/aws"
	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/aws/aws-sdk-go-v2/service/sqs/types"
)

// SQSQueueClient implementa QueueClient usando Amazon SQS
type SQSQueueClient struct {
	client   *sqs.Client
	queueURL string
	cfg      *config.Config
	running  bool
}

// NewSQSQueueClient crea un nuevo cliente de cola SQS
func NewSQSQueueClient(cfg *config.Config) (*SQSQueueClient, error) {
	if cfg.SQSQueue == "" {
		return nil, fmt.Errorf("SQS_QUEUE_URL is required when QUEUE_TYPE=sqs")
	}

	awsCfg, err := awsconfig.LoadDefaultConfig(context.Background(),
		awsconfig.WithRegion(cfg.SQSRegion),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to load AWS config: %w", err)
	}

	client := sqs.NewFromConfig(awsCfg)

	return &SQSQueueClient{
		client:   client,
		queueURL: cfg.SQSQueue,
		cfg:      cfg,
	}, nil
}

// Enqueue agrega un mensaje a la cola SQS
func (q *SQSQueueClient) Enqueue(ctx context.Context, taskType string, payload []byte) error {
	// Crear mensaje con el taskType como atributo
	input := &sqs.SendMessageInput{
		QueueUrl:    aws.String(q.queueURL),
		MessageBody: aws.String(string(payload)),
		MessageAttributes: map[string]types.MessageAttributeValue{
			"TaskType": {
				DataType:    aws.String("String"),
				StringValue: aws.String(taskType),
			},
		},
	}

	_, err := q.client.SendMessage(ctx, input)
	if err != nil {
		return fmt.Errorf("failed to send message to SQS: %w", err)
	}

	log.Printf("Message enqueued to SQS: %s", taskType)
	return nil
}

// StartWorker inicia el worker de SQS con long polling
func (q *SQSQueueClient) StartWorker(ctx context.Context, handler TaskHandler) error {
	q.running = true
	log.Printf("Starting SQS worker with concurrency: %d", q.cfg.WorkerConcurrency)

	// Canal para manejar mensajes
	messageChan := make(chan *types.Message, q.cfg.WorkerConcurrency)

	// Iniciar workers concurrentes
	for i := 0; i < q.cfg.WorkerConcurrency; i++ {
		go q.processMessages(ctx, messageChan, handler)
	}

	// Loop principal de polling
	for q.running {
		select {
		case <-ctx.Done():
			log.Println("Context cancelled, stopping SQS worker...")
			q.running = false
			close(messageChan)
			return ctx.Err()
		default:
			// Long polling de SQS
			result, err := q.client.ReceiveMessage(ctx, &sqs.ReceiveMessageInput{
				QueueUrl:              aws.String(q.queueURL),
				MaxNumberOfMessages:   int32(q.cfg.WorkerConcurrency),
				WaitTimeSeconds:       20, // Long polling
				VisibilityTimeout:     300, // 5 minutos para procesar
				MessageAttributeNames: []string{"All"},
			})

			if err != nil {
				log.Printf("Error receiving messages from SQS: %v", err)
				time.Sleep(5 * time.Second)
				continue
			}

			// Enviar mensajes al canal para procesamiento
			for _, msg := range result.Messages {
				messageChan <- &msg
			}
		}
	}

	close(messageChan)
	return nil
}

// processMessages procesa mensajes del canal
func (q *SQSQueueClient) processMessages(ctx context.Context, messageChan <-chan *types.Message, handler TaskHandler) {
	for msg := range messageChan {
		if err := q.processMessage(ctx, msg, handler); err != nil {
			log.Printf("Error processing message: %v", err)
		}
	}
}

// processMessage procesa un mensaje individual
func (q *SQSQueueClient) processMessage(ctx context.Context, msg *types.Message, handler TaskHandler) error {
	// Extraer taskType de los atributos
	taskType := TypeVideoProcessing // default
	if attr, ok := msg.MessageAttributes["TaskType"]; ok && attr.StringValue != nil {
		taskType = *attr.StringValue
	}

	// Procesar mensaje
	log.Printf("Processing SQS message: %s", taskType)
	err := handler(ctx, taskType, []byte(*msg.Body))

	if err != nil {
		log.Printf("Handler error for message %s: %v", *msg.MessageId, err)
		// No eliminamos el mensaje si hubo error, SQS lo volverá a entregar
		return err
	}

	// Eliminar mensaje de la cola si se procesó exitosamente
	_, delErr := q.client.DeleteMessage(ctx, &sqs.DeleteMessageInput{
		QueueUrl:      aws.String(q.queueURL),
		ReceiptHandle: msg.ReceiptHandle,
	})

	if delErr != nil {
		log.Printf("Failed to delete message %s: %v", *msg.MessageId, delErr)
		return delErr
	}

	log.Printf("Successfully processed and deleted message: %s", *msg.MessageId)
	return nil
}

// GetQueueDepth retorna la cantidad aproximada de mensajes en la cola
func (q *SQSQueueClient) GetQueueDepth(ctx context.Context) (int64, error) {
	result, err := q.client.GetQueueAttributes(ctx, &sqs.GetQueueAttributesInput{
		QueueUrl: aws.String(q.queueURL),
		AttributeNames: []types.QueueAttributeName{
			types.QueueAttributeNameApproximateNumberOfMessages,
		},
	})

	if err != nil {
		return 0, fmt.Errorf("failed to get queue attributes: %w", err)
	}

	if count, ok := result.Attributes["ApproximateNumberOfMessages"]; ok {
		var depth int64
		fmt.Sscanf(count, "%d", &depth)
		return depth, nil
	}

	return 0, nil
}

// Close cierra el cliente SQS
func (q *SQSQueueClient) Close() error {
	q.running = false
	log.Println("SQS client closed")
	return nil
}

// EnqueueVideoProcessing es un helper específico para encolar procesamiento de video
func (q *SQSQueueClient) EnqueueVideoProcessing(videoID string) error {
	payload, err := json.Marshal(map[string]string{"video_id": videoID})
	if err != nil {
		return err
	}
	return q.Enqueue(context.Background(), TypeVideoProcessing, payload)
}
