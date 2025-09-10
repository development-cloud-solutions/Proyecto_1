package handlers

import (
	"database/sql"
	"net/http"
	"strconv"

	"back/internal/config"
	"back/internal/database/models"
	"back/internal/services"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// RankingHandler gestiona las peticiones de ranking y votación
type RankingHandler struct {
	db             *sql.DB
	config         *config.Config
	videoService   services.VideoServiceInterface
	rankingService *services.RankingService
}

// NewRankingHandler crea una instancia del handler para inyectar dependencias
func NewRankingHandler(db *sql.DB, cfg *config.Config) *RankingHandler {
	return &RankingHandler{
		db:             db,
		config:         cfg,
		rankingService: services.NewRankingService(db, cfg),
	}
}

// ListPublicVideos devuelve una lista de videos públicamente disponibles para votación
func (h *RankingHandler) ListPublicVideos(c *gin.Context) {
	query := `
		SELECT 
			v.id,
			v.user_id,
			v.title,
			v.original_filename,
			v.original_url,
			v.processed_url,
			v.status,
			v.uploaded_at,
			v.processed_at,
			v.votes_count,
			v.is_public,
			u.first_name,
			u.last_name,
			u.city
		FROM videos v
		JOIN users u ON v.user_id = u.id
		WHERE v.is_public = true 
		  AND v.status = 'processed' 
		  AND v.processed_url IS NOT NULL
		ORDER BY v.votes_count DESC, v.uploaded_at DESC`

	rows, err := h.db.Query(query)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Error: "Failed to retrieve public videos",
		})
		return
	}
	defer rows.Close()

	var videos []models.Video
	for rows.Next() {
		var video models.Video
		err := rows.Scan(
			&video.ID,
			&video.UserID,
			&video.Title,
			&video.OriginalFilename,
			&video.OriginalURL,
			&video.ProcessedURL,
			&video.Status,
			&video.UploadedAt,
			&video.ProcessedAt,
			&video.VotesCount,
			&video.IsPublic,
			&video.UserFirstName,
			&video.UserLastName,
			&video.UserCity,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, models.APIResponse{
				Error: "Failed to scan video data",
			})
			return
		}
		videos = append(videos, video)
	}

	c.JSON(http.StatusOK, videos)
}

// VoteVideo permite a un usuario votar por un video público
func (h *RankingHandler) VoteVideo(c *gin.Context) {
	videoIDStr := c.Param("video_id")
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, models.APIResponse{
			Error: "User not authenticated",
		})
		return
	}

	userIDInt := int(userID.(int64))

	// Validar que el video_id sea un UUID válido
	videoID, err := uuid.Parse(videoIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Error: "Invalid video ID format",
		})
		return
	}

	// Verificar que el video existe, está procesado y es público
	var videoExists bool
	var videoOwnerID int
	checkVideoQuery := `
		SELECT EXISTS(
			SELECT 1 FROM videos 
			WHERE id = $1 
			  AND status = 'processed' 
			  AND is_public = true
		), COALESCE((SELECT user_id FROM videos WHERE id = $1), 0)`

	err = h.db.QueryRow(checkVideoQuery, videoID).Scan(&videoExists, &videoOwnerID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Error: "Failed to verify video",
		})
		return
	}

	if !videoExists {
		c.JSON(http.StatusNotFound, models.APIResponse{
			Error: "Video not found or not available for voting",
		})
		return
	}

	// Prevenir que un usuario vote por su propio video
	if videoOwnerID == userIDInt {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Error: "You cannot vote for your own video",
		})
		return
	}

	// Verificar si el usuario ya votó por este video
	var alreadyVoted bool
	checkVoteQuery := `SELECT EXISTS(SELECT 1 FROM votes WHERE user_id = $1 AND video_id = $2)`
	err = h.db.QueryRow(checkVoteQuery, userIDInt, videoID).Scan(&alreadyVoted)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Error: "Failed to check existing vote",
		})
		return
	}

	if alreadyVoted {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Error: "You have already voted for this video",
		})
		return
	}

	// Iniciar transacción para insertar voto y actualizar contador
	tx, err := h.db.Begin()
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Error: "Failed to start transaction",
		})
		return
	}
	defer tx.Rollback()

	// Insertar el voto
	insertVoteQuery := `INSERT INTO votes (user_id, video_id, created_at) VALUES ($1, $2, NOW())`
	_, err = tx.Exec(insertVoteQuery, userIDInt, videoID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Error: "Failed to register vote",
		})
		return
	}

	// Actualizar el contador de votos en el video
	updateCountQuery := `UPDATE videos SET votes_count = votes_count + 1 WHERE id = $1`
	_, err = tx.Exec(updateCountQuery, videoID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Error: "Failed to update vote count",
		})
		return
	}

	// Confirmar transacción
	err = tx.Commit()
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Error: "Failed to commit vote",
		})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Message: "Vote registered successfully",
	})
}

// GetRankings obtiene el ranking de jugadores
func (h *RankingHandler) GetRankings(c *gin.Context) {
	page := getRankingIntParam(c, "page", 1)
	limit := getRankingIntParam(c, "limit", 50)
	city := c.Query("city")

	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 100 {
		limit = 50
	}

	rankings, err := h.rankingService.GetRankings(page, limit, city)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Error: "Failed to retrieve rankings",
		})
		return
	}

	c.JSON(http.StatusOK, rankings)
}

// GetTopRankings obtiene el top de rankings (más eficiente, con caché)
func (h *RankingHandler) GetTopRankings(c *gin.Context) {
	limit := getRankingIntParam(c, "limit", 10)
	city := c.Query("city")

	if limit < 1 || limit > 50 {
		limit = 10
	}

	rankings, err := h.rankingService.GetTopRankings(limit, city)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Error: "Failed to retrieve top rankings",
		})
		return
	}

	c.JSON(http.StatusOK, rankings)
}

// GetUserVotes obtiene los IDs de videos por los que el usuario ya votó
func (h *RankingHandler) GetUserVotes(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, models.APIResponse{
			Error: "User not authenticated",
		})
		return
	}

	userIDInt := int(userID.(int64))

	query := `SELECT video_id FROM votes WHERE user_id = $1`
	rows, err := h.db.Query(query, userIDInt)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Error: "Failed to retrieve user votes",
		})
		return
	}
	defer rows.Close()

	var votedVideoIDs []string
	for rows.Next() {
		var videoID string
		if err := rows.Scan(&videoID); err != nil {
			c.JSON(http.StatusInternalServerError, models.APIResponse{
				Error: "Failed to scan vote data",
			})
			return
		}
		votedVideoIDs = append(votedVideoIDs, videoID)
	}

	c.JSON(http.StatusOK, votedVideoIDs)
}

func getRankingIntParam(c *gin.Context, key string, defaultValue int) int {
	if value := c.Query(key); value != "" {
		if intValue, err := strconv.Atoi(value); err == nil {
			return intValue
		}
	}
	return defaultValue
}
