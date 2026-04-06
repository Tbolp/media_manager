package config

import (
	"os"
	"strconv"

	"github.com/joho/godotenv"
)

type Config struct {
	JWTSecret        string
	TokenExpireHours int
	DataDir          string
	ThumbnailsDir    string
	GinMode          string
	ListenAddr       string
}

var C Config

func Load() {
	// .env is optional; missing file is not an error
	_ = godotenv.Load()

	C = Config{
		JWTSecret:        getEnv("JWT_SECRET", "change-me-to-a-random-string"),
		TokenExpireHours: getEnvInt("TOKEN_EXPIRE_HOURS", 72),
		DataDir:          getEnv("DATA_DIR", "./data"),
		ThumbnailsDir:    getEnv("THUMBNAILS_DIR", "./thumbnails"),
		GinMode:          getEnv("GIN_MODE", "release"),
		ListenAddr:       getEnv("LISTEN_ADDR", ":8080"),
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func getEnvInt(key string, fallback int) int {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return fallback
}
