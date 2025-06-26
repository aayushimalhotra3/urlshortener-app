package metrics

import (
	"sync"
	"github.com/prometheus/client_golang/prometheus"
)

// Metrics holds all the Prometheus metrics for the URL shortener
type Metrics struct {
	// HTTP metrics
	HTTPRequestsTotal    *prometheus.CounterVec
	HTTPRequestDuration  *prometheus.HistogramVec
	HTTPResponseSize     *prometheus.HistogramVec

	// Business metrics
	URLsShortenedTotal     prometheus.Counter
	URLsRedirectedTotal    prometheus.Counter
	URLsNotFoundTotal      prometheus.Counter
	InternalErrorsTotal    prometheus.Counter

	// Database metrics
	DBOperationsTotal    *prometheus.CounterVec
	DBOperationDuration  *prometheus.HistogramVec
}

var (
	metricsInstance *Metrics
	metricsOnce     sync.Once
)

// NewMetrics creates and registers all Prometheus metrics (singleton)
func NewMetrics() *Metrics {
	metricsOnce.Do(func() {
		metricsInstance = &Metrics{
			// HTTP metrics
			HTTPRequestsTotal: prometheus.NewCounterVec(
				prometheus.CounterOpts{
					Name: "http_requests_total",
					Help: "Total number of HTTP requests",
				},
				[]string{"method", "endpoint", "status_code"},
			),
			HTTPRequestDuration: prometheus.NewHistogramVec(
				prometheus.HistogramOpts{
					Name:    "http_request_duration_seconds",
					Help:    "Duration of HTTP requests in seconds",
					Buckets: prometheus.DefBuckets,
				},
				[]string{"method", "endpoint"},
			),
			HTTPResponseSize: prometheus.NewHistogramVec(
				prometheus.HistogramOpts{
					Name:    "http_response_size_bytes",
					Help:    "Size of HTTP responses in bytes",
					Buckets: []float64{100, 500, 1000, 5000, 10000, 50000},
				},
				[]string{"method", "endpoint"},
		),

		// Business metrics
		URLsShortenedTotal: prometheus.NewCounter(
			prometheus.CounterOpts{
				Name: "urls_shortened_total",
				Help: "Total number of URLs shortened",
			},
		),
		URLsRedirectedTotal: prometheus.NewCounter(
			prometheus.CounterOpts{
				Name: "urls_redirected_total",
				Help: "Total number of successful URL redirects",
			},
		),
		URLsNotFoundTotal: prometheus.NewCounter(
			prometheus.CounterOpts{
				Name: "urls_not_found_total",
				Help: "Total number of URL not found errors",
			},
		),
		InternalErrorsTotal: prometheus.NewCounter(
			prometheus.CounterOpts{
				Name: "internal_errors_total",
				Help: "Total number of internal server errors",
			},
		),

		// Database metrics
		DBOperationsTotal: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Name: "db_operations_total",
				Help: "Total number of database operations",
			},
			[]string{"operation", "status"},
		),
		DBOperationDuration: prometheus.NewHistogramVec(
			prometheus.HistogramOpts{
				Name:    "db_operation_duration_seconds",
				Help:    "Duration of database operations in seconds",
				Buckets: []float64{0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1.0},
			},
			[]string{"operation"},
		),
		}

		// Register all metrics
		prometheus.MustRegister(
			metricsInstance.HTTPRequestsTotal,
			metricsInstance.HTTPRequestDuration,
			metricsInstance.HTTPResponseSize,
			metricsInstance.URLsShortenedTotal,
			metricsInstance.URLsRedirectedTotal,
			metricsInstance.URLsNotFoundTotal,
			metricsInstance.InternalErrorsTotal,
			metricsInstance.DBOperationsTotal,
			metricsInstance.DBOperationDuration,
		)
	})

	return metricsInstance
}

// RecordHTTPRequest records metrics for an HTTP request
func (m *Metrics) RecordHTTPRequest(method, endpoint, statusCode string, duration float64, responseSize float64) {
	m.HTTPRequestsTotal.WithLabelValues(method, endpoint, statusCode).Inc()
	m.HTTPRequestDuration.WithLabelValues(method, endpoint).Observe(duration)
	m.HTTPResponseSize.WithLabelValues(method, endpoint).Observe(responseSize)
}

// RecordURLShortened increments the URLs shortened counter
func (m *Metrics) RecordURLShortened() {
	m.URLsShortenedTotal.Inc()
}

// RecordURLRedirected increments the URLs redirected counter
func (m *Metrics) RecordURLRedirected() {
	m.URLsRedirectedTotal.Inc()
}

// RecordURLNotFound increments the URLs not found counter
func (m *Metrics) RecordURLNotFound() {
	m.URLsNotFoundTotal.Inc()
}

// RecordInternalError increments the internal errors counter
func (m *Metrics) RecordInternalError() {
	m.InternalErrorsTotal.Inc()
}

// RecordDBOperation records metrics for a database operation
func (m *Metrics) RecordDBOperation(operation, status string, duration float64) {
	m.DBOperationsTotal.WithLabelValues(operation, status).Inc()
	m.DBOperationDuration.WithLabelValues(operation).Observe(duration)
}