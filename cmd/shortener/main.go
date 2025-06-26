package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/golang-migrate/migrate/v4"
	"github.com/golang-migrate/migrate/v4/database/sqlite3"
	_ "github.com/golang-migrate/migrate/v4/source/file"
	"github.com/joho/godotenv"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/sirupsen/logrus"
	"github.com/urlshortener/configs"
	"github.com/urlshortener/internal/handler"
	"github.com/urlshortener/internal/metrics"
	middlewareMetrics "github.com/urlshortener/internal/middleware"
	"github.com/urlshortener/internal/repo"
	"github.com/urlshortener/internal/service"
)

func main() {
	// Initialize structured logger
	logger := logrus.New()
	logger.SetFormatter(&logrus.JSONFormatter{})
	logger.SetLevel(logrus.InfoLevel)
	
	logger.Info("Starting URL Shortener application...")
	
	// Load environment variables
	if err := godotenv.Load(); err != nil {
		logger.Warn("Warning: .env file not found, using environment variables")
	}

	// Load configuration
	config := configs.LoadConfig()
	logger.WithFields(logrus.Fields{
		"port":     config.ServerPort,
		"db_path":  config.DBPath,
		"base_url": config.BaseURL,
	}).Info("Configuration loaded successfully")

	// Initialize metrics
	logger.Info("Initializing metrics...")
	metricsInstance := metrics.NewMetrics()
	logger.Info("Metrics initialized successfully")

	// Initialize repository
	logger.Info("Initializing repository...")
	repository, err := repo.NewSQLiteRepository(config.DBPath, metricsInstance)
	if err != nil {
		logger.WithError(err).Fatal("Failed to initialize repository")
	}
	defer repository.Close()
	logger.Info("Repository initialized successfully")

	// Run migrations
	logger.Info("Running migrations...")
	if err := runMigrations(config.DBPath); err != nil {
		logger.WithError(err).Fatal("Failed to run migrations")
	}
	logger.Info("Migrations completed successfully")

	// Initialize service
	logger.Info("Initializing service and handler...")
	urlService := service.NewURLService(repository, config.BaseURL)

	// Initialize handler
	urlHandler := handler.NewURLHandler(urlService, metricsInstance, logger)
	logger.Info("Service and handler initialized")

	// Set up router
	logger.Info("Setting up router...")
	r := chi.NewRouter()
	r.Use(middleware.Recoverer)
	r.Use(middlewareMetrics.LoggingMiddleware(logger))
	r.Use(middlewareMetrics.MetricsMiddleware(metricsInstance))

	// Serve static files
	workDir, _ := os.Getwd()
	webDir := filepath.Join(workDir, "web")
	
	// Static file routes
	r.Get("/", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, filepath.Join(webDir, "index.html"))
	})
	r.Get("/styles.css", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, filepath.Join(webDir, "styles.css"))
	})
	r.Get("/script.js", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, filepath.Join(webDir, "script.js"))
	})

	// Health check endpoint
	r.Get("/health", urlHandler.HealthCheck)

	// Metrics endpoint
	r.Handle("/metrics", promhttp.Handler())

	// API routes
	r.Post("/shorten", urlHandler.ShortenURL)
	r.Get("/{code}", urlHandler.RedirectURL)

	// Start server
	serverAddr := fmt.Sprintf(":%s", config.ServerPort)
	server := &http.Server{
		Addr:    serverAddr,
		Handler: r,
	}

	// Channel to listen for interrupt signal to terminate server
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	// Start server in a goroutine
	go func() {
		logger.WithFields(logrus.Fields{
			"address": serverAddr,
			"url":     fmt.Sprintf("http://localhost:%s", config.ServerPort),
		}).Info("Starting HTTP server")
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.WithError(err).Fatal("Server failed to start")
		}
	}()

	logger.Info("Server started successfully. Press Ctrl+C to stop.")

	// Wait for interrupt signal
	<-sigChan
	logger.Info("Shutting down server...")

	// Create a context with timeout for graceful shutdown
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Attempt graceful shutdown
	if err := server.Shutdown(ctx); err != nil {
		logger.WithError(err).Error("Server shutdown error")
	}
	logger.Info("Server stopped gracefully")
}

func runMigrations(dbPath string) error {
	// Ensure migrations directory exists
	migrationsDir := "file://migrations"

	// Connect to SQLite database
	db, err := repo.OpenDatabase(dbPath)
	if err != nil {
		return fmt.Errorf("failed to open database: %w", err)
	}
	defer db.Close()

	// Initialize database driver for migrations
	driver, err := sqlite3.WithInstance(db, &sqlite3.Config{})
	if err != nil {
		return fmt.Errorf("failed to create database driver: %w", err)
	}

	// Initialize migrator
	m, err := migrate.NewWithDatabaseInstance(migrationsDir, "sqlite3", driver)
	if err != nil {
		return fmt.Errorf("failed to create migrator: %w", err)
	}

	// Run migrations
	if err := m.Up(); err != nil && err != migrate.ErrNoChange {
		return fmt.Errorf("failed to run migrations: %w", err)
	}

	return nil
}