package middleware

import (
	"net/http"
	"time"

	"github.com/sirupsen/logrus"
)

// LoggingMiddleware creates a middleware that logs HTTP requests with structured logging
func LoggingMiddleware(logger *logrus.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			
			// Wrap the response writer to capture status code
			wrapped := &responseWriter{
				ResponseWriter: w,
				statusCode:     http.StatusOK,
			}
			
			// Process the request
			next.ServeHTTP(wrapped, r)
			
			// Log the request with structured fields
			duration := time.Since(start)
			
			logger.WithFields(logrus.Fields{
				"method":       r.Method,
				"path":         r.URL.Path,
				"remote_ip":    getClientIP(r),
				"user_agent":   r.UserAgent(),
				"status_code":  wrapped.statusCode,
				"duration_ms":  duration.Milliseconds(),
				"response_size": wrapped.size,
			}).Info("HTTP request processed")
		})
	}
}

// getClientIP extracts the client IP from the request
func getClientIP(r *http.Request) string {
	// Check X-Forwarded-For header first (for proxies)
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		return xff
	}
	
	// Check X-Real-IP header
	if xri := r.Header.Get("X-Real-IP"); xri != "" {
		return xri
	}
	
	// Fall back to RemoteAddr
	return r.RemoteAddr
}