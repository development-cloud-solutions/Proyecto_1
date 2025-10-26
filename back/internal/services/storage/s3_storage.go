package storage

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"mime/multipart"
	"os"
	"path/filepath"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"
)

// S3Storage implementa el almacenamiento en Amazon S3
type S3Storage struct {
	client         *s3.Client
	bucketName     string
	uploadPrefix   string
	processedPrefix string
	region         string
}

// NewS3Storage crea una nueva instancia de S3Storage
// Parámetros:
// - region: Región de AWS (ej: "us-east-1")
// - bucketName: Nombre del bucket S3
// - uploadPrefix: Prefijo para archivos subidos (ej: "uploads")
// - processedPrefix: Prefijo para archivos procesados (ej: "processed")
func NewS3Storage(region, bucketName, uploadPrefix, processedPrefix string) (*S3Storage, error) {
	cfg, err := config.LoadDefaultConfig(context.TODO(), config.WithRegion(region))
	if err != nil {
		return nil, fmt.Errorf("unable to load SDK config: %w", err)
	}

	client := s3.NewFromConfig(cfg)

	return &S3Storage{
		client:          client,
		bucketName:      bucketName,
		uploadPrefix:    uploadPrefix,
		processedPrefix: processedPrefix,
		region:          region,
	}, nil
}

// SaveFile guarda un archivo en S3
// destPath es la ruta relativa dentro del bucket (ej: "video-123.mp4")
func (s *S3Storage) SaveFile(file multipart.File, destPath string) error {
	ctx := context.TODO()

	// Leer el contenido del archivo
	buf := new(bytes.Buffer)
	if _, err := io.Copy(buf, file); err != nil {
		return fmt.Errorf("error reading file: %w", err)
	}

	// Determinar el key completo en S3
	key := s.getS3Key(destPath)

	// Detectar el content type
	contentType := "application/octet-stream"
	ext := filepath.Ext(destPath)
	switch ext {
	case ".mp4":
		contentType = "video/mp4"
	case ".avi":
		contentType = "video/x-msvideo"
	case ".mov":
		contentType = "video/quicktime"
	case ".mkv":
		contentType = "video/x-matroska"
	}

	// Subir el archivo a S3
	_, err := s.client.PutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(s.bucketName),
		Key:         aws.String(key),
		Body:        bytes.NewReader(buf.Bytes()),
		ContentType: aws.String(contentType),
		Metadata: map[string]string{
			"uploaded-at": time.Now().Format(time.RFC3339),
		},
	})

	if err != nil {
		return fmt.Errorf("error uploading to S3: %w", err)
	}

	return nil
}

// DeleteFile elimina un archivo de S3
func (s *S3Storage) DeleteFile(path string) error {
	ctx := context.TODO()

	key := s.getS3Key(path)

	_, err := s.client.DeleteObject(ctx, &s3.DeleteObjectInput{
		Bucket: aws.String(s.bucketName),
		Key:    aws.String(key),
	})

	if err != nil {
		return fmt.Errorf("error deleting from S3: %w", err)
	}

	return nil
}

// GetProcessedFilePath retorna la URL presignada para acceder al video procesado
func (s *S3Storage) GetProcessedFilePath(videoID string) (string, error) {
	ctx := context.TODO()

	key := filepath.Join(s.processedPrefix, videoID+".mp4")

	// Verificar que el objeto existe
	_, err := s.client.HeadObject(ctx, &s3.HeadObjectInput{
		Bucket: aws.String(s.bucketName),
		Key:    aws.String(key),
	})

	if err != nil {
		return "", fmt.Errorf("processed file not found in S3: %w", err)
	}

	// Crear un presigned client
	presignClient := s3.NewPresignClient(s.client)

	// Generar URL presignada válida por 1 hora
	request, err := presignClient.PresignGetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(s.bucketName),
		Key:    aws.String(key),
	}, func(opts *s3.PresignOptions) {
		opts.Expires = time.Hour * 1
	})

	if err != nil {
		return "", fmt.Errorf("error generating presigned URL: %w", err)
	}

	return request.URL, nil
}

// GetFileURL retorna una URL presignada para cualquier archivo en S3
func (s *S3Storage) GetFileURL(path string, expiresIn time.Duration) (string, error) {
	ctx := context.TODO()

	key := s.getS3Key(path)

	presignClient := s3.NewPresignClient(s.client)

	request, err := presignClient.PresignGetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(s.bucketName),
		Key:    aws.String(key),
	}, func(opts *s3.PresignOptions) {
		opts.Expires = expiresIn
	})

	if err != nil {
		return "", fmt.Errorf("error generating presigned URL: %w", err)
	}

	return request.URL, nil
}

// DownloadFile descarga un archivo de S3 a un writer
func (s *S3Storage) DownloadFile(path string, writer io.Writer) error {
	ctx := context.TODO()

	key := s.getS3Key(path)

	result, err := s.client.GetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(s.bucketName),
		Key:    aws.String(key),
	})

	if err != nil {
		return fmt.Errorf("error downloading from S3: %w", err)
	}
	defer result.Body.Close()

	_, err = io.Copy(writer, result.Body)
	if err != nil {
		return fmt.Errorf("error reading S3 object: %w", err)
	}

	return nil
}

// UploadProcessedFile sube un archivo procesado a S3
func (s *S3Storage) UploadProcessedFile(localPath, videoID string) error {
	ctx := context.TODO()

	// Abrir el archivo local
	file, err := os.Open(localPath)
	if err != nil {
		return fmt.Errorf("error opening local file: %w", err)
	}
	defer file.Close()

	// Leer el contenido del archivo
	data, err := io.ReadAll(file)
	if err != nil {
		return fmt.Errorf("error reading local file: %w", err)
	}

	key := filepath.Join(s.processedPrefix, videoID+".mp4")

	_, err = s.client.PutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(s.bucketName),
		Key:         aws.String(key),
		Body:        bytes.NewReader(data),
		ContentType: aws.String("video/mp4"),
		Metadata: map[string]string{
			"processed-at": time.Now().Format(time.RFC3339),
			"video-id":     videoID,
		},
		// Hacer el archivo público para lectura si es necesario
		ACL: types.ObjectCannedACLPublicRead,
	})

	if err != nil {
		return fmt.Errorf("error uploading processed file to S3: %w", err)
	}

	return nil
}

// getS3Key construye el key completo en S3 basado en el path
func (s *S3Storage) getS3Key(path string) string {
	// Si ya tiene un prefijo conocido (uploads o processed), retornarlo tal cual
	if filepath.HasPrefix(path, s.uploadPrefix) || filepath.HasPrefix(path, s.processedPrefix) {
		return path
	}

	// Detectar si usa el prefijo genérico "processed/"
	if filepath.HasPrefix(path, "processed/") || filepath.HasPrefix(path, "processed\\") {
		// Remover "processed/" y construir con el prefijo S3 configurado
		fileName := filepath.Base(path)
		return filepath.Join(s.processedPrefix, fileName)
	}

	// Detectar si usa el prefijo genérico "uploads/"
	if filepath.HasPrefix(path, "uploads/") || filepath.HasPrefix(path, "uploads\\") {
		// Remover "uploads/" y construir con el prefijo S3 configurado
		fileName := filepath.Base(path)
		return filepath.Join(s.uploadPrefix, fileName)
	}

	// Por defecto, asumir que es un archivo de upload
	if filepath.Ext(path) != "" {
		return filepath.Join(s.uploadPrefix, filepath.Base(path))
	}

	return path
}

// EnsureBucketExists verifica que el bucket existe y es accesible
func (s *S3Storage) EnsureBucketExists() error {
	ctx := context.TODO()

	_, err := s.client.HeadBucket(ctx, &s3.HeadBucketInput{
		Bucket: aws.String(s.bucketName),
	})

	if err != nil {
		return fmt.Errorf("bucket %s does not exist or is not accessible: %w", s.bucketName, err)
	}

	return nil
}

// DownloadToFile descarga un archivo de S3 a un path local (para procesamiento de videos)
// sourcePath: ruta relativa en S3 (ej: "video-123.mp4" o "uploads/video-123.mp4")
// destPath: ruta absoluta local donde guardar (ej: "/tmp/video-123.mp4")
func (s *S3Storage) DownloadToFile(sourcePath string, destPath string) error {
	ctx := context.TODO()

	key := s.getS3Key(sourcePath)

	// Descargar desde S3
	result, err := s.client.GetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(s.bucketName),
		Key:    aws.String(key),
	})
	if err != nil {
		return fmt.Errorf("error downloading from S3 (key=%s): %w", key, err)
	}
	defer result.Body.Close()

	// Crear el archivo local
	outFile, err := os.Create(destPath)
	if err != nil {
		return fmt.Errorf("error creating local file %s: %w", destPath, err)
	}
	defer outFile.Close()

	// Copiar contenido de S3 al archivo local
	_, err = io.Copy(outFile, result.Body)
	if err != nil {
		return fmt.Errorf("error writing to local file: %w", err)
	}

	return nil
}

// UploadFromFile sube un archivo local a S3 (para videos procesados)
// sourcePath: ruta absoluta local del archivo (ej: "/tmp/video-123_processed.mp4")
// destPath: ruta relativa en S3 donde guardar (ej: "video-123_processed.mp4" o "processed/video-123_processed.mp4")
func (s *S3Storage) UploadFromFile(sourcePath string, destPath string) error {
	ctx := context.TODO()

	// Abrir el archivo local
	file, err := os.Open(sourcePath)
	if err != nil {
		return fmt.Errorf("error opening local file %s: %w", sourcePath, err)
	}
	defer file.Close()

	// Leer todo el contenido del archivo
	data, err := io.ReadAll(file)
	if err != nil {
		return fmt.Errorf("error reading local file: %w", err)
	}

	key := s.getS3Key(destPath)

	// Subir a S3
	_, err = s.client.PutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(s.bucketName),
		Key:         aws.String(key),
		Body:        bytes.NewReader(data),
		ContentType: aws.String("video/mp4"),
		Metadata: map[string]string{
			"processed-at": time.Now().Format(time.RFC3339),
		},
	})

	if err != nil {
		return fmt.Errorf("error uploading to S3 (key=%s): %w", key, err)
	}

	return nil
}

// GetPublicURL genera una URL presignada de S3 para acceder al video procesado
// processedPath: ruta guardada en BD (ej: "/videos/video-123_processed.mp4")
func (s *S3Storage) GetPublicURL(processedPath string) (string, error) {
	ctx := context.TODO()

	// Extraer el nombre del archivo desde la ruta
	// Si viene como "/videos/video-123_processed.mp4", extraer "video-123_processed.mp4"
	filename := filepath.Base(processedPath)

	// Construir el key de S3
	key := filepath.Join(s.processedPrefix, filename)

	// Verificar que el objeto existe
	_, err := s.client.HeadObject(ctx, &s3.HeadObjectInput{
		Bucket: aws.String(s.bucketName),
		Key:    aws.String(key),
	})

	if err != nil {
		return "", fmt.Errorf("processed file not found in S3: %w", err)
	}

	// Crear un presigned client
	presignClient := s3.NewPresignClient(s.client)

	// Generar URL presignada válida por 1 hora
	request, err := presignClient.PresignGetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(s.bucketName),
		Key:    aws.String(key),
	}, func(opts *s3.PresignOptions) {
		opts.Expires = time.Hour * 1
	})

	if err != nil {
		return "", fmt.Errorf("error generating presigned URL: %w", err)
	}

	return request.URL, nil
}
