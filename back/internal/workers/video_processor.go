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
	"back/internal/utils"

	"github.com/hibiken/asynq"
)

// VideoProcessPayload corresponde al payload de la tarea
type VideoProcessPayload struct {
	VideoID string `json:"video_id"`
}

// VideoProcessor gestiona el worker y el procesamiento de videos
type VideoProcessor struct {
	server       *asynq.Server
	mux          *asynq.ServeMux
	db           *sql.DB
	config       *config.Config
	videoService services.VideoServiceInterface
}

// NewVideoProcessor crea un procesador listo para Start()
func NewVideoProcessor(queue *TaskQueue, db *sql.DB, videoService services.VideoServiceInterface) *VideoProcessor {
	redisOpt := asynq.RedisClientOpt{
		Addr: queue.cfg.RedisURL,
	}
	server := asynq.NewServer(redisOpt, asynq.Config{
		Concurrency: queue.cfg.WorkerConcurrency,
	})

	mux := asynq.NewServeMux()

	vp := &VideoProcessor{
		server:       server,
		mux:          mux,
		db:           db,
		config:       queue.cfg,
		videoService: videoService,
	}

	mux.HandleFunc(TypeVideoProcessing, vp.HandleVideoProcessing)

	return vp
}

// Start arranca el server asynq (bloqueante).
func (vp *VideoProcessor) Start() {
	if vp.server == nil {
		log.Println("video processor: server no inicializado")
		return
	}

	log.Println("video processor: iniciando server")
	if err := vp.server.Run(vp.mux); err != nil {
		log.Printf("asynq server error: %v", err)
	}
}

// HandleVideoProcessing procesa una tarea de video
func (vp *VideoProcessor) HandleVideoProcessing(ctx context.Context, t *asynq.Task) error {
	var payload VideoProcessPayload
	if err := json.Unmarshal(t.Payload(), &payload); err != nil {
		return fmt.Errorf("failed to unmarshal payload: %v", err)
	}

	log.Printf("Processing video: %s", payload.VideoID)

	// Marcar como "en proceso" al inicio
	if err := vp.videoService.MarkProcessing(payload.VideoID); err != nil {
		return fmt.Errorf("failed to mark as processing: %v", err)
	}

	// Obtener el video de la base de datos para obtener su ruta original
	video, err := vp.videoService.GetVideoByID(payload.VideoID, 0) // El 0 indica que no se verifica el usuario
	if err != nil || video == nil {
		_ = vp.videoService.MarkFailed(payload.VideoID, "video not found")
		return fmt.Errorf("video not found or database error: %v", err)
	}

	// Rutas de archivo
	srcPath := filepath.Join(vp.config.UploadPath, *video.OriginalURL)
	dstPath := filepath.Join(vp.config.ProcessedPath, fmt.Sprintf("%s_processed.mp4", payload.VideoID))

	// 1. Validar duración del video
	duration, err := utils.GetVideoDuration(srcPath)
	if err != nil {
		_ = vp.videoService.MarkFailed(payload.VideoID, "failed to get video duration")
		return fmt.Errorf("failed to get video duration: %v", err)
	}
	if duration > float64(vp.config.MaxVideoDuration) {
		log.Printf("Trimming video %s from %.2f seconds to %d seconds", payload.VideoID, duration, vp.config.MaxVideoDuration)
		tmpPath := filepath.Join(os.TempDir(), fmt.Sprintf("%s_trimmed.mp4", payload.VideoID))
		if err := utils.TrimVideo(srcPath, tmpPath, vp.config.MaxVideoDuration); err != nil {
			_ = vp.videoService.MarkFailed(payload.VideoID, "failed to trim video")
			return fmt.Errorf("failed to trim video: %v", err)
		}
		srcPath = tmpPath
		defer os.Remove(tmpPath) // Elimina el archivo temporal
	}

	// 2. Eliminar audio
	log.Printf("Removing audio from video %s", payload.VideoID)
	tmpNoAudio := filepath.Join(os.TempDir(), fmt.Sprintf("%s_noaudio.mp4", payload.VideoID))
	if err := utils.RemoveAudio(srcPath, tmpNoAudio); err != nil {
		_ = vp.videoService.MarkFailed(payload.VideoID, "failed to remove audio")
		return fmt.Errorf("failed to remove audio: %v", err)
	}
	defer os.Remove(tmpNoAudio)

	// 3. Conversión optimizada a 720p + watermark en un solo paso
	log.Printf("Converting video %s to 720p with watermark ", payload.VideoID)
	watermarkPath := "/app/assets/anb_watermark.png"

	// Usar la función optimizada que combina conversión y watermark
	if err := utils.OptimizedConvertAndWatermark(tmpNoAudio, dstPath, watermarkPath); err != nil {
		log.Printf("Optimized processing failed, falling back to step-by-step: %v", err)

		// Fallback: procesamiento por pasos si falla el optimizado
		tmpConverted := filepath.Join(os.TempDir(), fmt.Sprintf("%s_converted.mp4", payload.VideoID))
		if err := utils.ConvertTo720p(tmpNoAudio, tmpConverted); err != nil {
			_ = vp.videoService.MarkFailed(payload.VideoID, "failed to convert video to 720p")
			return fmt.Errorf("failed to convert video: %v", err)
		}
		defer os.Remove(tmpConverted)

		// Intentar watermark como paso separado
		if utils.FileExists(watermarkPath) {
			if err := utils.AddWatermark(tmpConverted, dstPath, watermarkPath); err != nil {
				log.Printf("Warning: failed to add watermark, continuing without it: %v", err)
				if err := utils.CopyFile(tmpConverted, dstPath); err != nil {
					_ = vp.videoService.MarkFailed(payload.VideoID, "failed to copy final video")
					return fmt.Errorf("failed to copy video: %v", err)
				}
			}
		} else {
			if err := utils.CopyFile(tmpConverted, dstPath); err != nil {
				_ = vp.videoService.MarkFailed(payload.VideoID, "failed to copy final video")
				return fmt.Errorf("failed to copy video: %v", err)
			}
		}
	}

	// 5. Marcar video como procesado con URL web en lugar de ruta del sistema
	webURL := fmt.Sprintf("/videos/%s_processed.mp4", payload.VideoID)
	if err := vp.videoService.MarkProcessed(payload.VideoID, webURL); err != nil {
		return fmt.Errorf("failed to mark processed: %v", err)
	}

	log.Printf("Processed video: %s", payload.VideoID)
	return nil
}
