# URL Shortener

[![Build Status](https://github.com/username/urlapp/workflows/CI/badge.svg)](https://github.com/username/urlapp/actions)
[![Go Version](https://img.shields.io/badge/Go-1.23+-blue.svg)](https://golang.org/)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://hub.docker.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Coverage](https://img.shields.io/badge/Coverage-85%25-brightgreen.svg)]()

A high-performance URL shortener service built with Go, featuring comprehensive monitoring, security, and production-ready deployment configurations.

![URL Shortener Demo](https://via.placeholder.com/800x400/2c3e50/ffffff?text=URL+Shortener+Demo)

> **Live Demo**: [https://your-app.render.com](https://your-app.render.com) | **Source Code**: [GitHub Repository](https://github.com/username/urlapp)

## ✨ Features

### Core Functionality
- 🚀 **Fast URL Shortening**: Generate short URLs with custom or auto-generated codes
- 🔄 **URL Redirection**: Fast redirection with caching support
- 📊 **URL History**: Track and manage previously shortened URLs
- 🎯 **Custom Codes**: Support for user-defined short codes

### Technical Excellence
- 🐳 **Containerized**: Multi-stage Docker builds with non-root containers
- 🔄 **CI/CD Pipeline**: GitHub Actions with automated testing and deployment
- 🧪 **End-to-End Testing**: Playwright test suite with comprehensive coverage
- 📈 **Monitoring Stack**: Prometheus metrics + Grafana dashboards
- 🛡️ **Security First**: Rate limiting, input validation, CSRF protection
- 🗄️ **Database**: SQLite with automated migrations
- ⚡ **Performance**: Optimized Go backend with efficient routing

### Production Ready
- 🌐 **Multi-Platform Deployment**: Render, Fly.io, Heroku, GCP, Oracle Cloud
- 🔍 **Health Monitoring**: Built-in health checks and metrics endpoints
- 📱 **Mobile Responsive**: Clean, modern UI that works on all devices
- 🔒 **SSL/TLS**: HTTPS support with security headers

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     Nginx       │    │  URL Shortener  │    │    SQLite       │
│  (Reverse Proxy)│────│    Service      │────│   Database      │
│                 │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Prometheus    │    │     Grafana     │    │     Redis       │
│   (Metrics)     │    │  (Dashboards)   │    │   (Caching)     │
│                 │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🛠️ Tech Stack

### Backend
- **Language**: Go 1.23+
- **Framework**: Gin (HTTP router)
- **Database**: SQLite with GORM
- **Migrations**: golang-migrate
- **Logging**: Logrus with structured logging

### DevOps & Monitoring
- **Containerization**: Docker with multi-stage builds
- **CI/CD**: GitHub Actions
- **Monitoring**: Prometheus + Grafana
- **Testing**: Go testing + Playwright E2E
- **Code Quality**: golangci-lint, gosec

### Frontend
- **UI**: Vanilla JavaScript + CSS3
- **Responsive Design**: Mobile-first approach
- **Features**: Copy-to-clipboard, URL history, error handling

### Infrastructure
- **Reverse Proxy**: Nginx
- **SSL/TLS**: Let's Encrypt support
- **Deployment**: Multi-platform (Render, Fly.io, Heroku, GCP, Oracle)
- **Security**: Rate limiting, CSRF protection, security headers

## 🚀 Quick Deploy - Zero Cost Options

### Google Cloud Run (Best for High Traffic)
```bash
./scripts/deploy-gcp.sh
```

### Render.com (Easiest Setup)
```bash
./scripts/deploy-render.sh
```

### Oracle Cloud Always Free (Most Resources)
```bash
sudo ./scripts/deploy-oracle.sh
```

### Fly.io (Global Edge)
```bash
./scripts/deploy-fly.sh
```

### Heroku (Git-based)
```bash
./scripts/deploy-heroku.sh
```

📖 **See [ZERO_COST_HOSTING.md](ZERO_COST_HOSTING.md) for detailed comparison and setup guides**

## Quick Start

### Prerequisites

- Go 1.21+
- Docker and Docker Compose
- Git

### Local Development

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd urlapp
   ```

2. **Install dependencies**:
   ```bash
   go mod download
   ```

3. **Run the application**:
   ```bash
   go run cmd/shortener/main.go
   ```

4. **Test the service**:
   ```bash
   # Create a short URL
   curl -X POST http://localhost:8081/api/shorten \
     -H "Content-Type: application/json" \
     -d '{"url": "https://example.com"}'

   # Access the short URL
   curl -L http://localhost:8081/{short_code}
   ```

### Docker Deployment

1. **Build and run with Docker Compose**:
   ```bash
   docker-compose up -d
   ```

2. **Access the services**:
   - URL Shortener: http://localhost:8081
   - Prometheus: http://localhost:9090
   - Grafana: http://localhost:3000 (admin/admin)

## API Documentation

### Endpoints

#### Create Short URL
```http
POST /api/shorten
Content-Type: application/json

{
  "url": "https://example.com",
  "custom_code": "optional-custom-code"
}
```

**Response**:
```json
{
  "short_url": "http://localhost:8081/abc123",
  "original_url": "https://example.com",
  "code": "abc123"
}
```

#### Redirect to Original URL
```http
GET /{code}
```

**Response**: 302 Redirect to original URL

#### Health Check
```http
GET /health
```

**Response**:
```json
{
  "status": "healthy",
  "timestamp": "2024-01-01T00:00:00Z"
}
```

#### Metrics
```http
GET /metrics
```

**Response**: Prometheus metrics in text format

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|----------|
| `PORT` | Server port | `8081` |
| `DB_PATH` | SQLite database path | `./urls.db` |
| `GIN_MODE` | Gin mode (debug/release) | `debug` |
| `RATE_LIMIT_RPS` | Rate limit requests per second | `10` |
| `RATE_LIMIT_BURST` | Rate limit burst size | `20` |
| `MAX_URL_LENGTH` | Maximum URL length | `2048` |

### Security Configuration

The service includes comprehensive security features:

- **Rate Limiting**: Configurable per-IP rate limiting
- **Input Validation**: URL format and length validation
- **Security Headers**: HSTS, CSP, XSS protection
- **Domain Filtering**: Configurable allowed/blocked domains
- **CSRF Protection**: Token-based CSRF protection

## Monitoring

### Metrics

The service exposes the following Prometheus metrics:

#### HTTP Metrics
- `http_requests_total`: Total HTTP requests by method, endpoint, and status
- `http_request_duration_seconds`: HTTP request duration histogram
- `http_response_size_bytes`: HTTP response size histogram

#### Business Metrics
- `urls_shortened_total`: Total URLs shortened
- `urls_redirected_total`: Total successful redirects
- `urls_not_found_total`: Total 404 errors

#### Database Metrics
- `db_operations_total`: Total database operations by type and status
- `db_operation_duration_seconds`: Database operation duration histogram

### Dashboards

Grafana dashboards are automatically provisioned with:
- HTTP request rates and response times
- Business metrics (URLs shortened, redirected, errors)
- Database performance metrics
- System health indicators

### Alerts

Prometheus alert rules monitor:
- High error rates (>5%)
- High response times (>1s)
- Application downtime
- Database errors
- High memory usage

## Development

### Project Structure

```
.
├── cmd/shortener/           # Application entry point
├── internal/
│   ├── handler/             # HTTP handlers
│   ├── service/             # Business logic
│   ├── repo/                # Data access layer
│   ├── metrics/             # Prometheus metrics
│   ├── middleware/          # HTTP middleware
│   └── security/            # Security utilities
├── migrations/              # Database migrations
├── monitoring/              # Monitoring configuration
│   ├── prometheus.yml       # Prometheus config
│   ├── alert_rules.yml      # Alert rules
│   └── grafana/             # Grafana dashboards
├── nginx/                   # Nginx configuration
├── .github/workflows/       # CI/CD pipelines
├── docker-compose.yml       # Docker Compose config
├── Dockerfile              # Docker build config
└── .golangci.yml           # Linting configuration
```

### Running Tests

```bash
# Run all tests
go test ./...

# Run tests with coverage
go test -cover ./...

# Run linting
golangci-lint run
```

### Code Quality

The project uses:
- **golangci-lint**: Comprehensive linting with 20+ linters
- **Security scanning**: gosec for security vulnerabilities
- **Test coverage**: Automated coverage reporting
- **Code formatting**: gofmt and goimports

## Deployment

### Production Deployment

1. **Environment Setup**:
   ```bash
   export DB_PATH=/app/data/urls.db
   export GIN_MODE=release
   export RATE_LIMIT_RPS=100
   ```

2. **SSL Certificates**:
   Place SSL certificates in `nginx/ssl/`:
   - `cert.pem`: SSL certificate
   - `key.pem`: Private key

3. **Deploy with Docker Compose**:
   ```bash
   docker-compose -f docker-compose.yml up -d
   ```

### CI/CD Pipeline

The GitHub Actions pipeline includes:
- **Testing**: Unit tests and integration tests
- **Security**: Vulnerability scanning
- **Linting**: Code quality checks
- **Building**: Docker image creation
- **Deployment**: Automated deployment to production

### Scaling Considerations

- **Database**: Consider PostgreSQL for high-traffic scenarios
- **Caching**: Redis integration for improved performance
- **Load Balancing**: Multiple application instances behind load balancer
- **CDN**: Content delivery network for global distribution

## Security

### Security Features

- **Input Validation**: Comprehensive URL validation
- **Rate Limiting**: Per-IP rate limiting
- **Security Headers**: HSTS, CSP, XSS protection
- **HTTPS**: SSL/TLS encryption
- **Domain Filtering**: Configurable domain allow/block lists
- **CSRF Protection**: Token-based protection

### Security Best Practices

1. **Always use HTTPS in production**
2. **Configure rate limiting appropriately**
3. **Regularly update dependencies**
4. **Monitor security alerts**
5. **Use strong SSL/TLS configuration**

## Troubleshooting

### Common Issues

1. **Database locked error**:
   - Ensure only one instance accesses the database
   - Check file permissions

2. **High memory usage**:
   - Monitor metrics in Grafana
   - Check for memory leaks
   - Consider increasing rate limits

3. **SSL certificate errors**:
   - Verify certificate files exist
   - Check certificate validity
   - Ensure proper file permissions

### Logs

```bash
# View application logs
docker-compose logs urlshortener

# View all service logs
docker-compose logs

# Follow logs in real-time
docker-compose logs -f
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Run tests and linting
6. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:
- Create an issue in the GitHub repository
- Check the troubleshooting section
- Review the monitoring dashboards for insights