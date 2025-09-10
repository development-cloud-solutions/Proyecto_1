package storage

import (
	"mime/multipart"
)

type Storage interface {
	SaveFile(file multipart.File, destPath string) error
	DeleteFile(path string) error
	GetProcessedFilePath(videoID string) (string, error)
}
