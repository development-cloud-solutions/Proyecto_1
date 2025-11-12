package storage

import (
	"io"
	"mime/multipart"
	"os"

	"path/filepath"
)

type LocalStorage struct {
	UploadDir    string
	ProcessedDir string
}

func NewLocalStorage(uploadDir, processedDir string) *LocalStorage {
	return &LocalStorage{
		UploadDir:    uploadDir,
		ProcessedDir: processedDir,
	}
}

func (s *LocalStorage) fullPath(rel string) string {
	if filepath.IsAbs(rel) {
		return rel
	}

	// Detectar si es un archivo procesado por el prefijo "processed/"
	if filepath.HasPrefix(rel, "processed/") || filepath.HasPrefix(rel, "processed\\") {
		// Remover el prefijo "processed/" y unir con ProcessedDir
		relPath := filepath.Base(rel)
		return filepath.Join(s.ProcessedDir, relPath)
	}

	// Por defecto, usar UploadDir
	return filepath.Join(s.UploadDir, rel)
}

func (s *LocalStorage) SaveFile(file multipart.File, destPath string) error {
	full := s.fullPath(destPath)
	if err := os.MkdirAll(filepath.Dir(full), 0o755); err != nil {
		return err
	}
	out, err := os.Create(full)
	if err != nil {
		return err
	}
	defer out.Close()
	_, err = io.Copy(out, file)
	return err
}

func (s *LocalStorage) DeleteFile(path string) error { return os.Remove(s.fullPath(path)) }

func (s *LocalStorage) GetProcessedFilePath(videoID string) (string, error) {
	path := filepath.Join(s.ProcessedDir, videoID+".mp4")
	_, err := os.Stat(path)
	if err != nil {
		return "", err
	}
	return path, nil
}

// DownloadToFile para LocalStorage solo copia el archivo (compatibilidad con S3Storage)
// sourcePath: ruta relativa (ej: "video-123.mp4" o "uploads/video-123.mp4")
// destPath: ruta absoluta de destino (ej: "/tmp/video-123.mp4")
func (s *LocalStorage) DownloadToFile(sourcePath string, destPath string) error {
	srcPath := s.fullPath(sourcePath)

	// Verificar que el archivo fuente existe
	if _, err := os.Stat(srcPath); err != nil {
		return err
	}

	// Abrir archivo fuente
	srcFile, err := os.Open(srcPath)
	if err != nil {
		return err
	}
	defer srcFile.Close()

	// Crear archivo destino
	destFile, err := os.Create(destPath)
	if err != nil {
		return err
	}
	defer destFile.Close()

	// Copiar contenido
	_, err = io.Copy(destFile, srcFile)
	return err
}

// UploadFromFile para LocalStorage solo copia el archivo (compatibilidad con S3Storage)
// sourcePath: ruta absoluta local (ej: "/tmp/video-123_processed.mp4")
// destPath: ruta relativa (ej: "video-123_processed.mp4" o "processed/video-123_processed.mp4")
func (s *LocalStorage) UploadFromFile(sourcePath string, destPath string) error {
	dstPath := s.fullPath(destPath)

	// Crear directorio si no existe
	if err := os.MkdirAll(filepath.Dir(dstPath), 0o755); err != nil {
		return err
	}

	// Abrir archivo fuente
	srcFile, err := os.Open(sourcePath)
	if err != nil {
		return err
	}
	defer srcFile.Close()

	// Crear archivo destino
	destFile, err := os.Create(dstPath)
	if err != nil {
		return err
	}
	defer destFile.Close()

	// Copiar contenido
	_, err = io.Copy(destFile, srcFile)
	return err
}

// GetPublicURL retorna la ruta relativa que sirve Nginx para videos locales
// processedPath: ruta guardada en BD (ej: "/videos/video-123_processed.mp4")
func (s *LocalStorage) GetPublicURL(processedPath string) (string, error) {
	// En local, simplemente retornar la ruta tal cual
	// Nginx la servirá desde /videos/
	return processedPath, nil
}
