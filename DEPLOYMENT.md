# Deployment Guide

## Prerequisites

- Docker and Docker Compose installed
- Go 1.21+ (for local development)
- Node.js 18+ (for E2E tests)

## Local Development with Docker

### 1. Build and Run with Docker Compose

```bash
# Start all services (app + monitoring)
docker-compose up -d

# Start only the application
docker-compose up -d urlshortener

# View logs
docker-compose logs -f urlshortener

# Stop services
docker-compose down
```

### 2. Access the Application

- **Application**: http://localhost:8081
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (admin/admin)
- **Health Check**: http://localhost:8081/health
- **Metrics**: http://localhost:8081/metrics

## Production Deployment

### 1. Build Production Image

```bash
# Build optimized production image
docker build -t urlshortener:latest .

# Test the image
docker run -d --name test-app -p 8081:8081 urlshortener:latest
curl http://localhost:8081/health
docker stop test-app && docker rm test-app
```

### 2. Environment Variables

Create a `.env` file for production:

```env
# Application
PORT=8081
DB_PATH=/app/data/urls.db
GIN_MODE=release

# Security
RATE_LIMIT_RPS=10
RATE_LIMIT_BURST=20
MAX_URL_LENGTH=2048
REQUIRE_HTTPS=true

# Monitoring
METRICS_ENABLED=true
LOG_LEVEL=info
```

### 3. Docker Compose Production

```bash
# Use production compose file
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

## Cloud Deployment Options

### Fly.io

```bash
# Install flyctl
curl -L https://fly.io/install.sh | sh

# Login and create app
fly auth login
fly launch

# Deploy
fly deploy
```

### Heroku

```bash
# Install Heroku CLI and login
heroku login

# Create app
heroku create your-url-shortener

# Set environment variables
heroku config:set PORT=8081
heroku config:set GIN_MODE=release

# Deploy
git push heroku main
```

### DigitalOcean App Platform

1. Connect your GitHub repository
2. Configure build settings:
   - **Build Command**: `go build -o main cmd/shortener/main.go`
   - **Run Command**: `./main`
   - **Port**: 8081
3. Set environment variables
4. Deploy

## CI/CD Pipeline

The GitHub Actions workflow automatically:

1. **Tests**: Runs unit tests, linting, and security scans
2. **Build**: Creates optimized Docker image
3. **E2E Tests**: Runs Playwright tests against containerized app
4. **Deploy**: Pushes to GitHub Container Registry on main branch

### Setting up CI/CD

1. **GitHub Secrets** (if using external registries):
   ```
   DOCKER_USERNAME=your-username
   DOCKER_PASSWORD=your-password
   ```

2. **Enable GitHub Container Registry**:
   - Images are automatically pushed to `ghcr.io/your-username/urlapp`
   - No additional setup required

## Monitoring and Observability

### Prometheus Metrics

- `http_requests_total`: Total HTTP requests
- `http_request_duration_seconds`: Request duration
- `urls_shortened_total`: Total URLs shortened
- `urls_redirected_total`: Total redirects
- `urls_not_found_total`: Total 404s
- `internal_errors_total`: Total internal errors

### Grafana Dashboards

1. Import the provided dashboard from `monitoring/grafana/dashboards/`
2. Configure Prometheus data source: `http://prometheus:9090`
3. View metrics and set up alerts

### Structured Logging

Logs are in JSON format for easy parsing:

```json
{
  "level": "info",
  "msg": "URL shortened successfully",
  "original_url": "https://example.com",
  "short_code": "abc123",
  "remote_ip": "127.0.0.1",
  "time": "2025-06-25T18:19:52-04:00"
}
```

## Health Checks

- **Endpoint**: `/health`
- **Docker**: Built-in healthcheck every 30s
- **Kubernetes**: Configure readiness/liveness probes

## Security Considerations

1. **Rate Limiting**: Configured per IP
2. **Input Validation**: URL format and length validation
3. **Security Headers**: CSP, HSTS, X-Frame-Options, etc.
4. **Non-root User**: Container runs as non-root user
5. **Minimal Image**: Alpine-based production image

## Troubleshooting

### Common Issues

1. **Database Permission Errors**:
   ```bash
   # Fix data directory permissions
   sudo chown -R 1001:1001 ./data
   ```

2. **Port Already in Use**:
   ```bash
   # Change port in docker-compose.yml or stop conflicting service
   docker-compose down
   lsof -ti:8081 | xargs kill -9
   ```

3. **Build Failures**:
   ```bash
   # Clean Docker cache
   docker system prune -a
   docker-compose build --no-cache
   ```

### Logs and Debugging

```bash
# View application logs
docker-compose logs -f urlshortener

# Enter container for debugging
docker-compose exec urlshortener sh

# Check health status
curl http://localhost:8081/health

# View metrics
curl http://localhost:8081/metrics
```