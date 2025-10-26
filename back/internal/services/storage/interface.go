package storage

import (
	"mime/multipart"
)

// Storage define la interfaz para almacenamiento de archivos
// Incluye métodos para upload, descarga y procesamiento de videos
type Storage interface {
	// Métodos básicos de storage
	SaveFile(file multipart.File, destPath string) error
	DeleteFile(path string) error
	GetProcessedFilePath(videoID string) (string, error)

	// Métodos para procesamiento de videos
	// DownloadToFile descarga un archivo desde storage a un path local temporal
	// sourcePath: ruta relativa en el storage (ej: "video-123.mp4")
	// destPath: ruta absoluta local donde guardar (ej: "/tmp/video-123.mp4")
	DownloadToFile(sourcePath string, destPath string) error

	// UploadFromFile sube un archivo local al storage
	// sourcePath: ruta absoluta local del archivo (ej: "/tmp/video-123_processed.mp4")
	// destPath: ruta relativa en el storage (ej: "video-123_processed.mp4")
	UploadFromFile(sourcePath string, destPath string) error

	// GetPublicURL obtiene una URL pública para acceder al video procesado
	// Para S3: retorna URL presignada válida por 1 hora
	// Para Local: retorna la ruta relativa que sirve Nginx
	GetPublicURL(processedPath string) (string, error)
}
