package config

import (
	"fmt"
	"os"
	"strconv"
	"time"
)

type Config struct {
	// Server
	Port        string
	Environment string

	// Database
	DBDriver   string
	DBHost     string
	DBPort     string
	DBName     string
	DBUser     string
	DBPassword string
	DBSSLMode  string

	// Redis
	RedisURL string

	// JWT
	JWTSecret     string
	JWTExpiration time.Duration

	// File Storage
	UploadPath    string
	ProcessedPath string
	MaxFileSize   int64

	// Video Processing
	MaxVideoDuration  int
	OutputResolution  string
	OutputAspectRatio string

	// Worker
	WorkerConcurrency int
}

func Load() *Config {
	return &Config{
		Port:        getEnv("PORT", "8080"),
		Environment: getEnv("ENVIRONMENT", "development"),

		DBDriver:   getEnv("DB_DRIVER", "postgres"),
		DBHost:     getEnv("DB_HOST", "localhost"),
		DBPort:     getEnv("DB_PORT", "5432"),
		DBName:     getEnv("DB_NAME", "proyecto_1"),
		DBUser:     getEnv("DB_USER", "postgres"),
		DBPassword: getEnv("DB_PASSWORD", "password"),
		DBSSLMode:  getEnv("DB_SSL_MODE", "disable"),

		RedisURL: getEnv("REDIS_URL", "redis:6379"),

		JWTSecret:     getEnv("JWT_SECRET", "local-development-secret-key"),
		JWTExpiration: getDurationEnv("JWT_EXPIRATION", "24h"),

		UploadPath:    getEnv("UPLOAD_PATH", "./uploads"),
		ProcessedPath: getEnv("PROCESSED_PATH", "./processed"),
		MaxFileSize:   getInt64Env("MAX_FILE_SIZE", "104857600"), // 100MB

		MaxVideoDuration:  getIntEnv("MAX_VIDEO_DURATION", "30"),
		OutputResolution:  getEnv("OUTPUT_RESOLUTION", "1280x720"),
		OutputAspectRatio: getEnv("OUTPUT_ASPECT_RATIO", "16:9"),

		WorkerConcurrency: getIntEnv("WORKER_CONCURRENCY", "5"),
	}
}

// GetDatabaseDSN builds the DSN string from individual config values
func (c *Config) GetDatabaseDSN() string {
	return fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		c.DBHost, c.DBPort, c.DBUser, c.DBPassword, c.DBName, c.DBSSLMode,
	)
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getIntEnv(key string, defaultValue string) int {
	if value := os.Getenv(key); value != "" {
		if intValue, err := strconv.Atoi(value); err == nil {
			return intValue
		}
	}
	defaultInt, _ := strconv.Atoi(defaultValue)
	return defaultInt
}

func getInt64Env(key string, defaultValue string) int64 {
	if value := os.Getenv(key); value != "" {
		if intValue, err := strconv.ParseInt(value, 10, 64); err == nil {
			return intValue
		}
	}
	defaultInt, _ := strconv.ParseInt(defaultValue, 10, 64)
	return defaultInt
}

func getDurationEnv(key string, defaultValue string) time.Duration {
	if value := os.Getenv(key); value != "" {
		if duration, err := time.ParseDuration(value); err == nil {
			return duration
		}
	}
	defaultDuration, _ := time.ParseDuration(defaultValue)
	return defaultDuration
}
