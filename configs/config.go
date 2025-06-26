package configs

import (
	"os"
)

// Config holds the application configuration
type Config struct {
	ServerPort string
	DBPath     string
	BaseURL    string
}

// LoadConfig loads configuration from environment variables
func LoadConfig() *Config {
	serverPort := getEnv("SERVER_PORT", "8080")
	dbPath := getEnv("DB_PATH", "./urlshortener.db")
	baseURL := getEnv("BASE_URL", "http://localhost:8080")

	return &Config{
		ServerPort: serverPort,
		DBPath:     dbPath,
		BaseURL:    baseURL,
	}
}

// getEnv retrieves an environment variable or returns a default value
func getEnv(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}