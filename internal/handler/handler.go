package handler

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/sirupsen/logrus"
	"github.com/urlshortener/internal/metrics"
	"github.com/urlshortener/internal/service"
)

// URLHandler handles HTTP requests for URL shortening
type URLHandler struct {
	service service.URLService
	metrics *metrics.Metrics
	logger  *logrus.Logger
}

// NewURLHandler creates a new URLHandler
func NewURLHandler(service service.URLService, metrics *metrics.Metrics, logger *logrus.Logger) *URLHandler {
	return &URLHandler{
		service: service,
		metrics: metrics,
		logger:  logger,
	}
}

// ShortenURLRequest represents the request body for shortening a URL
type ShortenURLRequest struct {
	URL string `json:"url"`
}

// ShortenURLResponse represents the response body for a shortened URL
type ShortenURLResponse struct {
	Code     string `json:"code"`
	ShortURL string `json:"short_url"`
}

// ErrorResponse represents an error response
type ErrorResponse struct {
	Error string `json:"error"`
}

// HealthResponse represents a health check response
type HealthResponse struct {
	Status    string    `json:"status"`
	Timestamp time.Time `json:"timestamp"`
	Version   string    `json:"version,omitempty"`
}

// ShortenURL handles the POST /shorten endpoint
func (h *URLHandler) ShortenURL(w http.ResponseWriter, r *http.Request) {
	// Parse request body
	var req ShortenURLRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.logger.WithFields(logrus.Fields{
			"error":      err.Error(),
			"remote_ip":  r.RemoteAddr,
			"user_agent": r.UserAgent(),
		}).Warn("Invalid request body for URL shortening")
		respondWithError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	// Validate URL is not empty
	if req.URL == "" {
		h.logger.WithFields(logrus.Fields{
			"remote_ip":  r.RemoteAddr,
			"user_agent": r.UserAgent(),
		}).Warn("Empty URL provided for shortening")
		respondWithError(w, http.StatusBadRequest, "URL is required")
		return
	}

	// Validate URL format
	if err := validateURLFormat(req.URL); err != nil {
		h.logger.WithFields(logrus.Fields{
			"url":        req.URL,
			"error":      err.Error(),
			"remote_ip":  r.RemoteAddr,
			"user_agent": r.UserAgent(),
		}).Warn("Invalid URL format provided")
		respondWithError(w, http.StatusBadRequest, "please provide a valid URL")
		return
	}

	// Shorten URL
	code, shortURL, err := h.service.ShortenURL(req.URL)
	if err != nil {
		h.logger.WithFields(logrus.Fields{
			"url":        req.URL,
			"error":      err.Error(),
			"remote_ip":  r.RemoteAddr,
			"user_agent": r.UserAgent(),
		}).Error("Failed to shorten URL")
		respondWithError(w, http.StatusBadRequest, err.Error())
		return
	}

	// Record metrics
	h.metrics.RecordURLShortened()

	// Log successful URL shortening
	h.logger.WithFields(logrus.Fields{
		"original_url": req.URL,
		"short_code":   code,
		"short_url":    shortURL,
		"remote_ip":    r.RemoteAddr,
		"user_agent":   r.UserAgent(),
	}).Info("URL shortened successfully")

	// Respond with shortened URL
	respondWithJSON(w, http.StatusOK, ShortenURLResponse{
		Code:     code,
		ShortURL: shortURL,
	})
}

// RedirectURL handles the GET /{code} endpoint
func (h *URLHandler) RedirectURL(w http.ResponseWriter, r *http.Request) {
	// Get code from URL
	code := chi.URLParam(r, "code")
	if code == "" {
		h.logger.WithFields(logrus.Fields{
			"remote_ip":  r.RemoteAddr,
			"user_agent": r.UserAgent(),
			"path":       r.URL.Path,
		}).Warn("Empty code provided for redirect")
		w.WriteHeader(http.StatusBadRequest)
		http.ServeFile(w, r, "./web/500.html")
		return
	}

	// Get original URL
	originalURL, err := h.service.GetOriginalURL(code)
	if err != nil {
		if isNotFoundError(err) {
			h.metrics.RecordURLNotFound()
			h.logger.WithFields(logrus.Fields{
				"code":       code,
				"remote_ip":  r.RemoteAddr,
				"user_agent": r.UserAgent(),
				"referer":    r.Header.Get("Referer"),
			}).Warn("URL not found for redirect")
			w.WriteHeader(http.StatusNotFound)
			http.ServeFile(w, r, "./web/404.html")
			return
		}
		// Internal server error
		h.metrics.RecordInternalError()
		h.logger.WithFields(logrus.Fields{
			"code":       code,
			"error":      err.Error(),
			"remote_ip":  r.RemoteAddr,
			"user_agent": r.UserAgent(),
		}).Error("Internal error during URL redirect")
		w.WriteHeader(http.StatusInternalServerError)
		http.ServeFile(w, r, "./web/500.html")
		return
	}

	// Record metrics
	h.metrics.RecordURLRedirected()

	// Log successful redirect
	h.logger.WithFields(logrus.Fields{
		"code":         code,
		"original_url": originalURL,
		"remote_ip":    r.RemoteAddr,
		"user_agent":   r.UserAgent(),
		"referer":      r.Header.Get("Referer"),
	}).Info("URL redirect successful")

	// Redirect to original URL
	http.Redirect(w, r, originalURL, http.StatusFound)
}

// respondWithJSON sends a JSON response
func respondWithJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

// respondWithError sends an error response
func respondWithError(w http.ResponseWriter, status int, message string) {
	respondWithJSON(w, status, ErrorResponse{Error: message})
}

// HealthCheck handles the GET /health endpoint
func (h *URLHandler) HealthCheck(w http.ResponseWriter, r *http.Request) {
	// Perform basic health checks
	status := "healthy"
	
	// You could add more sophisticated health checks here:
	// - Database connectivity
	// - External service dependencies
	// - Memory/CPU usage
	
	response := HealthResponse{
		Status:    status,
		Timestamp: time.Now(),
		Version:   "1.0.0", // You could make this configurable
	}
	
	respondWithJSON(w, http.StatusOK, response)
}

// validateURLFormat validates the format of a URL
func validateURLFormat(rawURL string) error {
	// Check if URL is empty or just whitespace
	if strings.TrimSpace(rawURL) == "" {
		return fmt.Errorf("URL cannot be empty")
	}
	
	// Add scheme if missing
	testURL := rawURL
	if !strings.HasPrefix(testURL, "http://") && !strings.HasPrefix(testURL, "https://") {
		testURL = "http://" + testURL
	}
	
	// Parse URL
	parsedURL, err := url.ParseRequestURI(testURL)
	if err != nil {
		return err
	}
	
	// Check if URL has a valid host
	if parsedURL.Host == "" {
		return fmt.Errorf("URL must have a valid host")
	}
	
	return nil
}

// isNotFoundError checks if an error indicates a "not found" condition
func isNotFoundError(err error) bool {
	return strings.Contains(err.Error(), "not found")
}