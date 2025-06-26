package main

import (
	"fmt"
	"github.com/urlshortener/configs"
	"github.com/urlshortener/internal/metrics"
	"github.com/urlshortener/internal/repo"
)

func main() {
	config := configs.LoadConfig()
	fmt.Printf("Trying to connect to database at: %s\n", config.DBPath)
	
	_, err := repo.NewSQLiteRepository(config.DBPath, metrics.NewMetrics())
	if err != nil {
		fmt.Printf("Database error: %v\n", err)
	} else {
		fmt.Println("Database connection successful")
	}
}