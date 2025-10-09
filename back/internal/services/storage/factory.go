package storage

import (
	"fmt"
	"log"

	"back/internal/config"
)

// NewStorage crea una instancia de Storage basada en la configuración
// Si STORAGE_TYPE=s3, usa S3Storage, de lo contrario usa LocalStorage
func NewStorage(cfg *config.Config) (Storage, error) {
	if cfg.StorageType == "s3" {
		log.Printf("Initializing S3 storage: bucket=%s, region=%s", cfg.S3BucketName, cfg.AWSRegion)

		if cfg.S3BucketName == "" {
			return nil, fmt.Errorf("S3_BUCKET_NAME is required when STORAGE_TYPE=s3")
		}

		s3Storage, err := NewS3Storage(
			cfg.AWSRegion,
			cfg.S3BucketName,
			cfg.S3UploadPrefix,
			cfg.S3ProcessedPrefix,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to initialize S3 storage: %w", err)
		}

		// Verificar que el bucket existe
		if err := s3Storage.EnsureBucketExists(); err != nil {
			log.Printf("Warning: S3 bucket verification failed: %v", err)
		}

		return s3Storage, nil
	}

	// Default: local storage
	log.Printf("Initializing local storage: uploadPath=%s", cfg.UploadPath)
	return NewLocalStorage(cfg.UploadPath), nil
}
