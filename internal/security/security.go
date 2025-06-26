package security

import (
	"crypto/rand"
	"crypto/subtle"
	"encoding/base64"
	"fmt"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"time"

	"github.com/sirupsen/logrus"
	"golang.org/x/time/rate"
)

// SecurityConfig holds security-related configuration
type SecurityConfig struct {
	RateLimitRPS     int
	RateLimitBurst   int
	MaxURLLength     int
	AllowedDomains   []string
	BlockedDomains   []string
	RequireHTTPS     bool
	CSRFTokenLength  int
}

// DefaultSecurityConfig returns a secure default configuration
func DefaultSecurityConfig() *SecurityConfig {
	return &SecurityConfig{
		RateLimitRPS:    10,
		RateLimitBurst:  20,
		MaxURLLength:    2048,
		AllowedDomains:  []string{}, // Empty means all domains allowed
		BlockedDomains:  []string{"localhost", "127.0.0.1", "0.0.0.0"},
		RequireHTTPS:    false, // Set to true in production
		CSRFTokenLength: 32,
	}
}

// RateLimiter provides rate limiting functionality
type RateLimiter struct {
	limiters map[string]*rate.Limiter
	config   *SecurityConfig
}

// NewRateLimiter creates a new rate limiter
func NewRateLimiter(config *SecurityConfig) *RateLimiter {
	return &RateLimiter{
		limiters: make(map[string]*rate.Limiter),
		config:   config,
	}
}

// Allow checks if the request is allowed based on rate limiting
func (rl *RateLimiter) Allow(clientIP string) bool {
	limiter, exists := rl.limiters[clientIP]
	if !exists {
		limiter = rate.NewLimiter(
			rate.Limit(rl.config.RateLimitRPS),
			rl.config.RateLimitBurst,
		)
		rl.limiters[clientIP] = limiter
	}
	return limiter.Allow()
}

// URLValidator validates URLs for security
type URLValidator struct {
	config *SecurityConfig
}

// NewURLValidator creates a new URL validator
func NewURLValidator(config *SecurityConfig) *URLValidator {
	return &URLValidator{config: config}
}

// ValidateURL validates a URL for security concerns
func (v *URLValidator) ValidateURL(rawURL string) error {
	// Check URL length
	if len(rawURL) > v.config.MaxURLLength {
		return fmt.Errorf("URL exceeds maximum length of %d characters", v.config.MaxURLLength)
	}

	// Parse URL
	parsedURL, err := url.Parse(rawURL)
	if err != nil {
		return fmt.Errorf("invalid URL format: %w", err)
	}

	// Check scheme
	if parsedURL.Scheme != "http" && parsedURL.Scheme != "https" {
		return fmt.Errorf("unsupported URL scheme: %s", parsedURL.Scheme)
	}

	// Require HTTPS in production
	if v.config.RequireHTTPS && parsedURL.Scheme != "https" {
		return fmt.Errorf("HTTPS required")
	}

	// Check for blocked domains
	hostname := strings.ToLower(parsedURL.Hostname())
	for _, blocked := range v.config.BlockedDomains {
		if hostname == strings.ToLower(blocked) {
			return fmt.Errorf("domain %s is blocked", hostname)
		}
	}

	// Check allowed domains (if specified)
	if len(v.config.AllowedDomains) > 0 {
		allowed := false
		for _, domain := range v.config.AllowedDomains {
			if hostname == strings.ToLower(domain) {
				allowed = true
				break
			}
		}
		if !allowed {
			return fmt.Errorf("domain %s is not in allowed list", hostname)
		}
	}

	// Check for suspicious patterns
	if err := v.checkSuspiciousPatterns(rawURL); err != nil {
		return err
	}

	return nil
}

// checkSuspiciousPatterns checks for potentially malicious URL patterns
func (v *URLValidator) checkSuspiciousPatterns(rawURL string) error {
	// Check for multiple redirects or suspicious characters
	suspiciousPatterns := []string{
		`javascript:`,
		`data:`,
		`vbscript:`,
		`file:`,
		`ftp:`,
	}

	lowerURL := strings.ToLower(rawURL)
	for _, pattern := range suspiciousPatterns {
		if strings.Contains(lowerURL, pattern) {
			return fmt.Errorf("suspicious URL pattern detected: %s", pattern)
		}
	}

	// Check for excessive URL encoding
	if strings.Count(rawURL, "%") > 10 {
		return fmt.Errorf("excessive URL encoding detected")
	}

	return nil
}

// CSRFProtection provides CSRF token generation and validation
type CSRFProtection struct {
	config *SecurityConfig
}

// NewCSRFProtection creates a new CSRF protection instance
func NewCSRFProtection(config *SecurityConfig) *CSRFProtection {
	return &CSRFProtection{config: config}
}

// GenerateToken generates a new CSRF token
func (c *CSRFProtection) GenerateToken() (string, error) {
	bytes := make([]byte, c.config.CSRFTokenLength)
	if _, err := rand.Read(bytes); err != nil {
		return "", fmt.Errorf("failed to generate CSRF token: %w", err)
	}
	return base64.URLEncoding.EncodeToString(bytes), nil
}

// ValidateToken validates a CSRF token
func (c *CSRFProtection) ValidateToken(provided, expected string) bool {
	return subtle.ConstantTimeCompare([]byte(provided), []byte(expected)) == 1
}

// SecurityHeaders adds security headers to HTTP responses
func SecurityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Security headers
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("X-XSS-Protection", "1; mode=block")
		w.Header().Set("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
		w.Header().Set("Content-Security-Policy", "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'")
		w.Header().Set("Referrer-Policy", "strict-origin-when-cross-origin")
		w.Header().Set("Permissions-Policy", "geolocation=(), microphone=(), camera=()")

		next.ServeHTTP(w, r)
	})
}

// RateLimitMiddleware provides rate limiting middleware
func RateLimitMiddleware(limiter *RateLimiter, logger *logrus.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			clientIP := getClientIP(r)
			if !limiter.Allow(clientIP) {
				LogSecurityEvent(logger, "rate_limit_exceeded", clientIP, 
					fmt.Sprintf("Path: %s, Method: %s, User-Agent: %s", r.URL.Path, r.Method, r.UserAgent()))
				http.Error(w, "Rate limit exceeded", http.StatusTooManyRequests)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

// getClientIP extracts the client IP from the request
func getClientIP(r *http.Request) string {
	// Check X-Forwarded-For header
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		// Take the first IP in the list
		if ips := strings.Split(xff, ","); len(ips) > 0 {
			return strings.TrimSpace(ips[0])
		}
	}

	// Check X-Real-IP header
	if xri := r.Header.Get("X-Real-IP"); xri != "" {
		return xri
	}

	// Fall back to RemoteAddr
	if ip := strings.Split(r.RemoteAddr, ":"); len(ip) > 0 {
		return ip[0]
	}

	return r.RemoteAddr
}

// SanitizeInput sanitizes user input to prevent injection attacks
func SanitizeInput(input string) string {
	// Remove potentially dangerous characters
	re := regexp.MustCompile(`[<>"'&]`)
	return re.ReplaceAllString(input, "")
}

// LogSecurityEvent logs security-related events
func LogSecurityEvent(logger *logrus.Logger, event, clientIP, details string) {
	// Log security events with structured logging
	logger.WithFields(logrus.Fields{
		"event_type": "security",
		"event":      event,
		"client_ip":  clientIP,
		"details":    details,
		"timestamp":  time.Now().Format(time.RFC3339),
	}).Warn("Security event detected")
}