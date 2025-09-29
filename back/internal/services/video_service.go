package services

import (
	"database/sql"
	"fmt"
	"mime/multipart"
	"time"

	"back/internal/config"
	"back/internal/database/models"
	"back/internal/services/storage"

	"github.com/google/uuid"
)

// VideoServiceInterface define el contrato para las operaciones de video
type VideoServiceInterface interface {
	CreateVideo(userID int64, title string, file multipart.File, filename string, isPublic bool) (string, error)
	GetVideosByUser(userID int64) ([]models.Video, error)
	GetVideoByID(videoID string, userID int64) (*models.Video, error)
	MarkProcessing(videoID string) error
	MarkProcessed(videoID, processedPath string) error
	MarkFailed(videoID, reason string) error
	DeleteVideo(videoID string, userID int64) error
}

type VideoService struct {
	db      *sql.DB
	cfg     *config.Config
	storage storage.Storage
}

func NewVideoService(db *sql.DB, cfg *config.Config, st storage.Storage) *VideoService {
	return &VideoService{db: db, cfg: cfg, storage: st}
}

// CreateVideo guarda metadata y guarda archivo en storage local
func (s *VideoService) CreateVideo(userID int64, title string, file multipart.File, filename string, isPublic bool) (string, error) {
	id := uuid.New().String()
	uploadedAt := time.Now().UTC()

	origPath := fmt.Sprintf("%s_%s", id, filename)
	if err := s.storage.SaveFile(file, origPath); err != nil {
		return "", err
	}

	_, err := s.db.Exec(`INSERT INTO videos (id, user_id, title, original_filename, original_url, status, uploaded_at, is_public) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
		id, userID, title, filename, origPath, "uploaded", uploadedAt, isPublic)
	if err != nil {
		return "", err
	}

	return id, nil
}

// GetVideosByUser lista videos de un usuario
func (s *VideoService) GetVideosByUser(userID int64) ([]models.Video, error) {
	rows, err := s.db.Query(`SELECT id, title, original_filename, original_url, status, uploaded_at, processed_at, processed_url, COALESCE(votes_count, 0), COALESCE(is_public, false) FROM videos WHERE user_id=$1 ORDER BY uploaded_at DESC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var videos []models.Video
	for rows.Next() {
		var v models.Video
		err := rows.Scan(&v.ID, &v.Title, &v.OriginalFilename, &v.OriginalURL, &v.Status, &v.UploadedAt, &v.ProcessedAt, &v.ProcessedURL, &v.VotesCount, &v.IsPublic)
		if err != nil {
			return nil, err
		}
		videos = append(videos, v)
	}
	return videos, nil
}

// GetVideoByID obtiene el video por id y user ownership check (userID 0 -> no check)
func (s *VideoService) GetVideoByID(videoID string, userID int64) (*models.Video, error) {
	row := s.db.QueryRow(`SELECT id, user_id, title, original_filename, original_url, status, uploaded_at, processed_at, processed_url, COALESCE(votes_count, 0), COALESCE(is_public, false) FROM videos WHERE id=$1`, videoID)
	var v models.Video
	if err := row.Scan(&v.ID, &v.UserID, &v.Title, &v.OriginalFilename, &v.OriginalURL, &v.Status, &v.UploadedAt, &v.ProcessedAt, &v.ProcessedURL, &v.VotesCount, &v.IsPublic); err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	if userID != 0 && int64(v.UserID) != userID {
		return nil, fmt.Errorf("forbidden")
	}

	return &v, nil
}

// MarkProcessing marca el video como 'en proceso'
func (s *VideoService) MarkProcessing(videoID string) error {
	_, err := s.db.Exec(`UPDATE videos SET status=$1 WHERE id=$2`, "processing", videoID)
	return err
}

// MarkProcessed actualiza el estado y processed_url y processed_at
func (s *VideoService) MarkProcessed(videoID, processedPath string) error {
	processedAt := time.Now().UTC()
	_, err := s.db.Exec(`UPDATE videos SET status=$1, processed_url=$2, processed_at=$3 WHERE id=$4`, "processed", processedPath, processedAt, videoID)
	return err
}

// MarkFailed anota fallos
func (s *VideoService) MarkFailed(videoID, reason string) error {
	_, err := s.db.Exec(`UPDATE videos SET status=$1 WHERE id=$2`, "failed", videoID)
	// opcional: insertar en tabla de logs
	return err
}

// DeleteVideo borra registros y archivos (solo si estado permitido)
func (s *VideoService) DeleteVideo(videoID string, userID int64) error {
	row := s.db.QueryRow(`SELECT user_id, status, original_url, processed_url FROM videos WHERE id=$1`, videoID)
	var owner int64
	var status, orig, proc sql.NullString
	if err := row.Scan(&owner, &status, &orig, &proc); err != nil {
		return err
	}
	if owner != userID {
		return fmt.Errorf("forbidden")
	}
	if status.String == "processed" {
		return fmt.Errorf("video processed or published; cannot delete")
	}
	if orig.Valid && orig.String != "" {
		_ = s.storage.DeleteFile(orig.String)
	}
	if proc.Valid && proc.String != "" {
		_ = s.storage.DeleteFile(proc.String)
	}
	_, err := s.db.Exec(`DELETE FROM videos WHERE id=$1`, videoID)
	return err
}
