package service

import (
	"crypto/rand"
	"fmt"
	"math/big"
	"net/url"
	"strings"

	"github.com/urlshortener/internal/repo"
)

// URLService defines the interface for URL shortening operations
type URLService interface {
	ShortenURL(originalURL string) (string, string, error)
	GetOriginalURL(code string) (string, error)
}

// URLServiceImpl implements URLService
type URLServiceImpl struct {
	repo    repo.URLRepository
	baseURL string
}

// NewURLService creates a new URL service
func NewURLService(repo repo.URLRepository, baseURL string) URLService {
	return &URLServiceImpl{
		repo:    repo,
		baseURL: baseURL,
	}
}

// ShortenURL shortens a URL and returns the code and full short URL
func (s *URLServiceImpl) ShortenURL(originalURL string) (string, string, error) {
	// Validate URL
	if err := validateURL(originalURL); err != nil {
		return "", "", err
	}

	// Generate a unique code
	code, err := generateUniqueCode(6)
	if err != nil {
		return "", "", fmt.Errorf("failed to generate code: %w", err)
	}

	// Store the URL
	if err := s.repo.StoreURL(originalURL, code); err != nil {
		return "", "", fmt.Errorf("failed to store URL: %w", err)
	}

	// Construct the short URL
	shortURL := fmt.Sprintf("%s/%s", strings.TrimSuffix(s.baseURL, "/"), code)

	return code, shortURL, nil
}

// GetOriginalURL retrieves the original URL for a given code
func (s *URLServiceImpl) GetOriginalURL(code string) (string, error) {
	return s.repo.GetOriginalURL(code)
}

// validateURL checks if the provided URL is valid
func validateURL(rawURL string) error {
	// Add scheme if missing
	if !strings.HasPrefix(rawURL, "http://") && !strings.HasPrefix(rawURL, "https://") {
		rawURL = "http://" + rawURL
	}

	// Parse URL
	parsedURL, err := url.Parse(rawURL)
	if err != nil {
		return fmt.Errorf("invalid URL: %w", err)
	}

	// Check if URL has a host
	if parsedURL.Host == "" {
		return fmt.Errorf("invalid URL: missing host")
	}

	return nil
}

// generateUniqueCode generates a random alphanumeric code
func generateUniqueCode(length int) (string, error) {
	const charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	charsetLength := big.NewInt(int64(len(charset)))

	result := make([]byte, length)
	for i := 0; i < length; i++ {
		index, err := rand.Int(rand.Reader, charsetLength)
		if err != nil {
			return "", err
		}
		result[i] = charset[index.Int64()]
	}

	return string(result), nil
}