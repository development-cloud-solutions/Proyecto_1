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
	args := []string{"-i", src, "-vf", "scale='min(1280,iw)':'min(720,ih)':force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2", "-c:v", "libx264", "-preset", "fast", "-crf", "23", "-c:a", "aac", "-y", dst}
	return runCmd("ffmpeg", args...)
}

// AddWatermark overlay watermarkImage at top-right with 10px padding
func AddWatermark(src, dst, watermarkImage string) error {
	args := []string{"-i", src, "-i", watermarkImage, "-filter_complex", "overlay=main_w-overlay_w-10:10", "-codec:a", "copy", "-y", dst}
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
		// As fallback, try re-encoding (safer)
		return runCmd("ffmpeg", "-f", "concat", "-safe", "0", "-i", tmpList, "-c:v", "libx264", "-c:a", "aac", "-y", dst)
	}
	return nil
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
