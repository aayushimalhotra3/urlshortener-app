package middleware

import (
	"net/http"
	"strconv"
	"time"

	"github.com/urlshortener/internal/metrics"
)

// responseWriter wraps http.ResponseWriter to capture response size and status code
type responseWriter struct {
	http.ResponseWriter
	statusCode int
	size       int
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}

func (rw *responseWriter) Write(b []byte) (int, error) {
	size, err := rw.ResponseWriter.Write(b)
	rw.size += size
	return size, err
}

// MetricsMiddleware creates a middleware that records HTTP metrics
func MetricsMiddleware(m *metrics.Metrics) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			
			// Wrap the response writer to capture metrics
			wrapped := &responseWriter{
				ResponseWriter: w,
				statusCode:     http.StatusOK, // Default status code
			}
			
			// Process the request
			next.ServeHTTP(wrapped, r)
			
			// Record metrics
			duration := time.Since(start).Seconds()
			endpoint := getEndpointName(r.URL.Path)
			statusCode := strconv.Itoa(wrapped.statusCode)
			
			m.RecordHTTPRequest(
				r.Method,
				endpoint,
				statusCode,
				duration,
				float64(wrapped.size),
			)
		})
	}
}

// getEndpointName normalizes URL paths for metrics
func getEndpointName(path string) string {
	switch {
	case path == "/shorten":
		return "/shorten"
	case path == "/metrics":
		return "/metrics"
	case path == "/health":
		return "/health"
	case path == "/":
		return "/"
	case len(path) > 1 && path[0] == '/':
		// This is likely a redirect endpoint like /{code}
		return "/{code}"
	default:
		return "unknown"
	}
}