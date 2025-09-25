package utils

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

type VideoInfo struct {
	Duration float64 `json:"duration"`
	Width    int     `json:"width"`
	Height   int     `json:"height"`
}

// RunCmd helper
func runCmd(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("%v: %s", err, stderr.String())
	}
	return nil
}

// GetVideoDuration usa ffprobe para obtener la duración en segundos
func GetVideoDuration(path string) (float64, error) {
	out, err := exec.Command("ffprobe", "-v", "error", "-show_entries", "format=duration",
		"-of", "default=noprint_wrappers=1:nokey=1", path).Output()
	if err != nil {
		return 0, fmt.Errorf("ffprobe error: %v", err)
	}
	s := strings.TrimSpace(string(out))
	if s == "" {
		return 0, fmt.Errorf("empty duration")
	}
	d, err := strconv.ParseFloat(s, 64)
	if err != nil {
		return 0, err
	}
	return d, nil
}

// GetVideoResolution usa ffprobe para ancho/alto
func GetVideoResolution(path string) (int, int, error) {
	out, err := exec.Command("ffprobe", "-v", "error", "-select_streams", "v:0",
		"-show_entries", "stream=width,height", "-of", "json", path).Output()
	if err != nil {
		return 0, 0, fmt.Errorf("ffprobe error: %v", err)
	}
	var data map[string][]map[string]interface{}
	if err := json.Unmarshal(out, &data); err != nil {
		return 0, 0, err
	}
	streams, ok := data["streams"]
	if !ok || len(streams) == 0 {
		return 0, 0, fmt.Errorf("no video stream")
	}
	w := int(streams[0]["width"].(float64))
	h := int(streams[0]["height"].(float64))
	return w, h, nil
}

// TrimVideo recorta a durationSeconds (desde 0)
func TrimVideo(src, dst string, durationSeconds int) error {
	// -y sobreescribe
	args := []string{"-i", src, "-ss", "0", "-t", strconv.Itoa(durationSeconds), "-c", "copy", "-y", dst}
	return runCmd("ffmpeg", args...)
}

// RemoveAudio remueve el audio track
func RemoveAudio(src, dst string) error {
	args := []string{"-i", src, "-c", "copy", "-an", "-y", dst}
	return runCmd("ffmpeg", args...)
}

// ConvertTo720p convierte video a 1280x720 manteniendo aspect ratio
func ConvertTo720p(src, dst string) error {
	args := []string{
		"-i", src,
		"-vf", "scale='min(1280,iw)':'min(720,ih)':force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2",
		"-c:v", "libx264",
		"-preset", "ultrafast", // Cambiado de "fast" a "ultrafast" para máxima velocidad
		"-crf", "28", // Cambiado de "23" a "28" para reducir calidad pero ganar velocidad
		"-threads", "0", // Usar todos los cores disponibles
		"-tune", "fastdecode", // Optimizar para decodificación rápida
		"-movflags", "+faststart", // Optimizar para streaming
		"-an", // Sin audio
		"-y", dst,
	}
	return runCmd("ffmpeg", args...)
}

// AddWatermark overlay watermarkImage at top-right with 10px padding
func AddWatermark(src, dst, watermarkImage string) error {
	args := []string{
		"-i", src,
		"-i", watermarkImage,
		"-filter_complex", "overlay=main_w-overlay_w-10:10",
		"-c:v", "libx264",
		"-preset", "ultrafast", // Preset más rápido
		"-crf", "28", // Calidad equilibrada para velocidad
		"-threads", "0", // Usar todos los cores
		"-movflags", "+faststart", // Optimizar para streaming
		"-an", // Sin audio
		"-y", dst,
	}
	return runCmd("ffmpeg", args...)
}

// AddOpeningClosing adds opening and closing clips (optional) concatenating them (they should be short mp4s)
func AddOpeningClosing(src, dst, opening, closing string) error {
	// Create a txt file list for ffmpeg concat
	tmpList := filepath.Join(os.TempDir(), fmt.Sprintf("concat_%d.txt", time.Now().UnixNano()))
	f, err := os.Create(tmpList)
	if err != nil {
		return err
	}
	defer os.Remove(tmpList)
	defer f.Close()

	// order: opening, src, closing (if provided)
	if opening != "" {
		fmt.Fprintf(f, "file '%s'\n", opening)
	}
	fmt.Fprintf(f, "file '%s'\n", src)
	if closing != "" {
		fmt.Fprintf(f, "file '%s'\n", closing)
	}
	f.Sync()

	// concat demuxer
	if err := runCmd("ffmpeg", "-f", "concat", "-safe", "0", "-i", tmpList, "-c", "copy", "-y", dst); err != nil {
		// As fallback, try re-encoding
		return runCmd("ffmpeg", "-f", "concat", "-safe", "0", "-i", tmpList, "-c:v", "libx264", "-c:a", "aac", "-y", dst)
	}
	return nil
}

// OptimizedConvertAndWatermark combina conversión y watermark en un solo paso FFmpeg
func OptimizedConvertAndWatermark(src, dst, watermarkImage string) error {
	// Si no hay watermark, solo convertir
	if !FileExists(watermarkImage) {
		return ConvertTo720p(src, dst)
	}

	// Combinar conversión y watermark en un solo paso para máxima eficiencia
	args := []string{
		"-i", src,
		"-i", watermarkImage,
		"-filter_complex",
		"[0:v]scale='min(1280,iw)':'min(720,ih)':force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2[scaled];[scaled][1:v]overlay=main_w-overlay_w-10:10[out]",
		"-map", "[out]",
		"-c:v", "libx264",
		"-preset", "ultrafast", // Preset más rápido
		"-crf", "28", // Calidad equilibrada
		"-threads", "0", // Usar todos los cores disponibles
		"-tune", "fastdecode", // Optimizar para decodificación rápida
		"-movflags", "+faststart", // Optimizar para streaming
		"-an", // Sin audio
		"-y", dst,
	}
	return runCmd("ffmpeg", args...)
}

// FileExists verifica si un archivo existe
func FileExists(path string) bool {
	_, err := os.Stat(path)
	return !os.IsNotExist(err)
}

// CopyFile copia un archivo de src a dst
func CopyFile(src, dst string) error {
	return runCmd("cp", src, dst)
}
