package repo

import (
	"database/sql"
	"errors"
	"fmt"
	"time"

	_ "github.com/mattn/go-sqlite3"
	"github.com/urlshortener/internal/metrics"
)

// URLRepository defines the interface for URL storage operations
type URLRepository interface {
	StoreURL(originalURL, code string) error
	GetOriginalURL(code string) (string, error)
	Close() error
}

// SQLiteRepository implements URLRepository using SQLite
type SQLiteRepository struct {
	db      *sql.DB
	metrics *metrics.Metrics
}

// NewSQLiteRepository creates a new SQLite repository
func NewSQLiteRepository(dbPath string, metrics *metrics.Metrics) (*SQLiteRepository, error) {
	db, err := OpenDatabase(dbPath)
	if err != nil {
		return nil, err
	}

	return &SQLiteRepository{
		db:      db,
		metrics: metrics,
	}, nil
}

// OpenDatabase opens a connection to the SQLite database
func OpenDatabase(dbPath string) (*sql.DB, error) {
	db, err := sql.Open("sqlite3", dbPath)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	// Set connection parameters
	db.SetMaxOpenConns(10)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(time.Hour)

	// Test connection
	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	return db, nil
}

// StoreURL stores a URL with its generated code
func (r *SQLiteRepository) StoreURL(originalURL, code string) error {
	start := time.Now()
	query := `INSERT INTO urls (original_url, code, created_at) VALUES (?, ?, ?)`
	_, err := r.db.Exec(query, originalURL, code, time.Now().UTC())
	
	// Record metrics
	duration := time.Since(start).Seconds()
	if err != nil {
		r.metrics.RecordDBOperation("store_url", "error", duration)
		return fmt.Errorf("failed to store URL: %w", err)
	}
	r.metrics.RecordDBOperation("store_url", "success", duration)
	return nil
}

// GetOriginalURL retrieves the original URL for a given code
func (r *SQLiteRepository) GetOriginalURL(code string) (string, error) {
	start := time.Now()
	query := `SELECT original_url FROM urls WHERE code = ?`
	var originalURL string
	err := r.db.QueryRow(query, code).Scan(&originalURL)
	
	// Record metrics
	duration := time.Since(start).Seconds()
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			r.metrics.RecordDBOperation("get_url", "not_found", duration)
			return "", fmt.Errorf("URL not found for code: %s", code)
		}
		r.metrics.RecordDBOperation("get_url", "error", duration)
		return "", fmt.Errorf("failed to get URL: %w", err)
	}
	r.metrics.RecordDBOperation("get_url", "success", duration)
	return originalURL, nil
}

// Close closes the database connection
func (r *SQLiteRepository) Close() error {
	return r.db.Close()
}