package handlers

import (
	"database/sql"
	"fmt"
	"net/http"
	"path/filepath"
	"strings"

	"back/internal/config"
	"back/internal/database/models"
	"back/internal/services"
	"back/internal/workers"

	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"
)

type VideoHandler struct {
	db           *sql.DB
	config       *config.Config
	validator    *validator.Validate
	videoService services.VideoServiceInterface
	taskQueue    *workers.TaskQueue
}

// NewVideoHandler crea una instancia del handler para inyectar dependencias
func NewVideoHandler(db *sql.DB, cfg *config.Config, taskQueue *workers.TaskQueue, videoService services.VideoServiceInterface) *VideoHandler {
	return &VideoHandler{
		db:           db,
		config:       cfg,
		validator:    validator.New(),
		videoService: videoService,
		taskQueue:    taskQueue,
	}
}

// UploadVideo maneja la subida de videos
// @Summary Subir video
// @Description Permite a un usuario autenticado subir un video para participar en la competencia
// @Tags videos
// @Accept multipart/form-data
// @Produce json
// @Security BearerAuth
// @Param video_file formData file true "Archivo de video"
// @Param title formData string true "Título del video"
// @Param is_public formData boolean false "Si el video es público para votación"
// @Success 201 {object} models.APIResponse
// @Failure 400 {object} models.APIResponse
// @Failure 401 {object} models.APIResponse
// @Failure 500 {object} models.APIResponse
// @Router /videos/upload [post]
func (h *VideoHandler) UploadVideo(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, models.APIResponse{
			Error: "User not authenticated",
		})
		return
	}
	userIDInt64 := userID.(int64)

	file, header, err := c.Request.FormFile("video_file")
	if err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Error: "No video file provided",
		})
		return
	}
	defer file.Close()

	if header.Size > h.config.MaxFileSize {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Error: fmt.Sprintf("File size exceeds maximum allowed (%dMB)", h.config.MaxFileSize/1024/1024),
		})
		return
	}

	if !isValidVideoFile(header.Filename) {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Error: "Invalid file type. Only MP4 files are allowed",
		})
		return
	}

	var upload models.VideoUpload
	if err := c.ShouldBind(&upload); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Error: "Invalid form data",
		})
		return
	}
	
	// Parse is_public manually since ShouldBind doesn't handle boolean from form correctly
	isPublicStr := c.PostForm("is_public")
	upload.IsPublic = isPublicStr == "true"
	
	if err := h.validator.Struct(upload); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Error: "Validation failed: " + err.Error(),
		})
		return
	}

	videoID, err := h.videoService.CreateVideo(userIDInt64, upload.Title, file, header.Filename, upload.IsPublic)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Error: "Failed to create video record or save file: " + err.Error(),
		})
		return
	}

	if err := h.taskQueue.EnqueueVideoProcessing(videoID); err != nil {
		fmt.Printf("Failed to enqueue video processing task: %v\n", err)
	}

	c.JSON(http.StatusCreated, gin.H{
		"message": "Video subido correctamente. Procesamiento en curso.",
		"task_id": videoID,
	})
}

// GetMyVideos lista los videos del usuario autenticado
// @Summary Obtener mis videos
// @Description Lista todos los videos subidos por el usuario autenticado
// @Tags videos
// @Accept json
// @Produce json
// @Security BearerAuth
// @Success 200 {array} models.Video
// @Failure 401 {object} models.APIResponse
// @Failure 500 {object} models.APIResponse
// @Router /videos [get]
func (h *VideoHandler) GetMyVideos(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, models.APIResponse{
			Error: "User not authenticated",
		})
		return
	}
	userIDInt64 := userID.(int64)

	videos, err := h.videoService.GetVideosByUser(userIDInt64)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Error: "Failed to retrieve videos",
		})
		return
	}

	c.JSON(http.StatusOK, videos)
}

// GetVideoDetail obtiene el detalle de un video específico
// @Summary Obtener detalles de video
// @Description Obtiene los detalles de un video específico del usuario autenticado
// @Tags videos
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param video_id path string true "ID del video"
// @Success 200 {object} models.Video
// @Failure 401 {object} models.APIResponse
// @Failure 404 {object} models.APIResponse
// @Failure 500 {object} models.APIResponse
// @Router /videos/{video_id} [get]
func (h *VideoHandler) GetVideoDetail(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, models.APIResponse{
			Error: "User not authenticated",
		})
		return
	}
	userIDInt64 := userID.(int64)

	videoIDStr := c.Param("video_id")
	video, err := h.videoService.GetVideoByID(videoIDStr, userIDInt64)
	if err != nil {
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, models.APIResponse{
				Error: "Video not found",
			})
			return
		}
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Error: "Failed to retrieve video",
		})
		return
	}

	c.JSON(http.StatusOK, video)
}

// DeleteVideo elimina un video
// @Summary Eliminar video
// @Description Elimina un video específico del usuario autenticado
// @Tags videos
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param video_id path string true "ID del video"
// @Success 200 {object} models.APIResponse
// @Failure 401 {object} models.APIResponse
// @Failure 404 {object} models.APIResponse
// @Failure 500 {object} models.APIResponse
// @Router /videos/{video_id} [delete]
func (h *VideoHandler) DeleteVideo(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, models.APIResponse{
			Error: "User not authenticated",
		})
		return
	}
	userIDInt64 := userID.(int64)

	videoIDStr := c.Param("video_id")
	if err := h.videoService.DeleteVideo(videoIDStr, userIDInt64); err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Error: "Failed to delete video",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":  "El video ha sido eliminado exitosamente.",
		"video_id": videoIDStr,
	})
}

// Función auxiliar para validar archivos de video
func isValidVideoFile(filename string) bool {
	ext := strings.ToLower(filepath.Ext(filename))
	return ext == ".mp4"
}
