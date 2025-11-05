package workers

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"

	"back/internal/config"
	"back/internal/services"
	"back/internal/services/storage"
	"back/internal/utils"
)

// VideoProcessPayload corresponde al payload de la tarea
type VideoProcessPayload struct {
	VideoID string `json:"video_id"`
}

// VideoProcessor gestiona el worker y el procesamiento de videos
type VideoProcessor struct {
	queueClient  QueueClient
	db           *sql.DB
	config       *config.Config
	videoService services.VideoServiceInterface
	storage      storage.Storage
}

// NewVideoProcessor crea un procesador listo para Start()
func NewVideoProcessor(taskQueue *TaskQueue, db *sql.DB, videoService services.VideoServiceInterface, fileStorage storage.Storage) *VideoProcessor {
	return &VideoProcessor{
		queueClient:  taskQueue.GetClient(),
		db:           db,
		config:       taskQueue.cfg,
		videoService: videoService,
		storage:      fileStorage,
	}
}

// Start arranca el worker (bloqueante)
func (vp *VideoProcessor) Start(ctx context.Context) error {
	log.Printf("Starting video processor with queue type: %s", vp.config.QueueType)

	// Crear el handler que procesará los mensajes
	handler := func(ctx context.Context, taskType string, payload []byte) error {
		switch taskType {
		case TypeVideoProcessing:
			return vp.HandleVideoProcessing(ctx, payload)
		default:
			return fmt.Errorf("unknown task type: %s", taskType)
		}
	}

	// Iniciar el worker según el tipo de cola
	if err := vp.queueClient.StartWorker(ctx, handler); err != nil {
		return fmt.Errorf("worker error: %w", err)
	}

	return nil
}

// HandleVideoProcessing procesa una tarea de video
func (vp *VideoProcessor) HandleVideoProcessing(ctx context.Context, payload []byte) error {
	var videoPayload VideoProcessPayload
	if err := json.Unmarshal(payload, &videoPayload); err != nil {
		return fmt.Errorf("failed to unmarshal payload: %v", err)
	}

	log.Printf("Processing video: %s", videoPayload.VideoID)

	// Marcar como "en proceso" al inicio
	if err := vp.videoService.MarkProcessing(videoPayload.VideoID); err != nil {
		return fmt.Errorf("failed to mark as processing: %v", err)
	}

	// Obtener el video de la base de datos para obtener su ruta original
	video, err := vp.videoService.GetVideoByID(videoPayload.VideoID, 0) // El 0 indica que no se verifica el usuario
	if err != nil || video == nil {
		_ = vp.videoService.MarkFailed(videoPayload.VideoID, "video not found")
		return fmt.Errorf("video not found or database error: %v", err)
	}

	// === Descargar video desde storage (S3 o local) a /tmp ===
	tmpInputPath := filepath.Join(os.TempDir(), fmt.Sprintf("%s_input.mp4", videoPayload.VideoID))
	tmpOutputPath := filepath.Join(os.TempDir(), fmt.Sprintf("%s_output.mp4", videoPayload.VideoID))

	// Limpiar archivos temporales al final
	defer os.Remove(tmpInputPath)
	defer os.Remove(tmpOutputPath)

	log.Printf("Downloading video from storage: %s", *video.OriginalURL)
	if err := vp.storage.DownloadToFile(*video.OriginalURL, tmpInputPath); err != nil {
		_ = vp.videoService.MarkFailed(videoPayload.VideoID, "failed to download video from storage")
		return fmt.Errorf("failed to download video: %v", err)
	}

	// Ahora usamos el archivo temporal descargado
	srcPath := tmpInputPath
	dstPath := tmpOutputPath

	// 1. Validar duración del video
	duration, err := utils.GetVideoDuration(srcPath)
	if err != nil {
		_ = vp.videoService.MarkFailed(videoPayload.VideoID, "failed to get video duration")
		return fmt.Errorf("failed to get video duration: %v", err)
	}
	if duration > float64(vp.config.MaxVideoDuration) {
		log.Printf("Trimming video %s from %.2f seconds to %d seconds", videoPayload.VideoID, duration, vp.config.MaxVideoDuration)
		tmpPath := filepath.Join(os.TempDir(), fmt.Sprintf("%s_trimmed.mp4", videoPayload.VideoID))
		if err := utils.TrimVideo(srcPath, tmpPath, vp.config.MaxVideoDuration); err != nil {
			_ = vp.videoService.MarkFailed(videoPayload.VideoID, "failed to trim video")
			return fmt.Errorf("failed to trim video: %v", err)
		}
		srcPath = tmpPath
		defer os.Remove(tmpPath) // Elimina el archivo temporal
	}

	// 2. Eliminar audio
	log.Printf("Removing audio from video %s", videoPayload.VideoID)
	tmpNoAudio := filepath.Join(os.TempDir(), fmt.Sprintf("%s_noaudio.mp4", videoPayload.VideoID))
	if err := utils.RemoveAudio(srcPath, tmpNoAudio); err != nil {
		_ = vp.videoService.MarkFailed(videoPayload.VideoID, "failed to remove audio")
		return fmt.Errorf("failed to remove audio: %v", err)
	}
	defer os.Remove(tmpNoAudio)

	// 3. Conversión optimizada a 720p + watermark en un solo paso
	log.Printf("Converting video %s to 720p with watermark ", videoPayload.VideoID)
	watermarkPath := "/app/assets/anb_watermark.png"

	// Usar la función optimizada que combina conversión y watermark
	if err := utils.OptimizedConvertAndWatermark(tmpNoAudio, dstPath, watermarkPath); err != nil {
		log.Printf("Optimized processing failed, falling back to step-by-step: %v", err)

		// Fallback: procesamiento por pasos si falla el optimizado
		tmpConverted := filepath.Join(os.TempDir(), fmt.Sprintf("%s_converted.mp4", videoPayload.VideoID))
		if err := utils.ConvertTo720p(tmpNoAudio, tmpConverted); err != nil {
			_ = vp.videoService.MarkFailed(videoPayload.VideoID, "failed to convert video to 720p")
			return fmt.Errorf("failed to convert video: %v", err)
		}
		defer os.Remove(tmpConverted)

		// Intentar watermark como paso separado
		if utils.FileExists(watermarkPath) {
			if err := utils.AddWatermark(tmpConverted, dstPath, watermarkPath); err != nil {
				log.Printf("Warning: failed to add watermark, continuing without it: %v", err)
				if err := utils.CopyFile(tmpConverted, dstPath); err != nil {
					_ = vp.videoService.MarkFailed(videoPayload.VideoID, "failed to copy final video")
					return fmt.Errorf("failed to copy video: %v", err)
				}
			}
		} else {
			if err := utils.CopyFile(tmpConverted, dstPath); err != nil {
				_ = vp.videoService.MarkFailed(videoPayload.VideoID, "failed to copy final video")
				return fmt.Errorf("failed to copy video: %v", err)
			}
		}
	}

	// === Subir video procesado al storage (S3 o local) ===
	// Usar el prefijo "processed/" para que el storage detecte automáticamente
	// dónde guardar según la configuración (PROCESSED_PATH o S3_PROCESSED_PREFIX)
	processedRelativePath := fmt.Sprintf("processed/%s_processed.mp4", videoPayload.VideoID)
	log.Printf("Uploading processed video to storage: %s", processedRelativePath)

	if err := vp.storage.UploadFromFile(dstPath, processedRelativePath); err != nil {
		_ = vp.videoService.MarkFailed(videoPayload.VideoID, "failed to upload processed video to storage")
		return fmt.Errorf("failed to upload processed video: %v", err)
	}

	// Marcar video como procesado con la ruta web relativa
	// Para local: nginx sirve /videos/ desde /app/processed/
	// Para S3: se generará presigned URL en el handler
	webURL := fmt.Sprintf("/videos/%s_processed.mp4", videoPayload.VideoID)
	if err := vp.videoService.MarkProcessed(videoPayload.VideoID, webURL); err != nil {
		return fmt.Errorf("failed to mark processed: %v", err)
	}

	log.Printf("Successfully processed video: %s", videoPayload.VideoID)
	return nil
}
