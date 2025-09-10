package storage

import (
	"io"
	"mime/multipart"
	"os"

	"path/filepath"
)

type LocalStorage struct {
	BaseDir string
}

func NewLocalStorage(baseDir string) *LocalStorage { return &LocalStorage{BaseDir: baseDir} }

func (s *LocalStorage) fullPath(rel string) string {
	if filepath.IsAbs(rel) {
		return rel
	}
	return filepath.Join(s.BaseDir, rel)
}

func (s *LocalStorage) SaveFile(file multipart.File, destPath string) error {
	full := s.fullPath(destPath)
	if err := os.MkdirAll(filepath.Dir(full), 0o755); err != nil {
		return err
	}
	out, err := os.Create(full)
	if err != nil { return err }
	defer out.Close()
	_, err = io.Copy(out, file)
	return err
}

func (s *LocalStorage) DeleteFile(path string) error { return os.Remove(s.fullPath(path)) }

func (s *LocalStorage) GetProcessedFilePath(videoID string) (string, error) {
	path := filepath.Join(s.BaseDir, "processed", videoID+".mp4")
	_, err := os.Stat(path)
	if err != nil { return "", err }
	return path, nil
}
