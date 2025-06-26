# Multi-stage build for production
# Stage 1: Build stage
FROM golang:1.23 AS builder

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git ca-certificates tzdata gcc libsqlite3-dev && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy go mod files first for better caching
COPY go.mod go.sum ./

# Download dependencies (this layer will be cached if go.mod/go.sum don't change)
RUN go mod download && go mod verify

# Copy source code
COPY . .

# Build the application with optimizations
RUN CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s' \
    -a -installsuffix cgo \
    -o main cmd/shortener/main.go

# Stage 2: Production stage
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates tzdata sqlite3 && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy binary from builder stage
COPY --from=builder /app/main ./main

# Copy static assets and migrations
COPY --from=builder /app/web ./web
COPY --from=builder /app/migrations ./migrations
COPY --from=builder /app/configs ./configs

# Create non-root user and data directory
RUN groupadd --system appgroup && \
    useradd --system --no-create-home --ingroup appgroup appuser && \
    mkdir -p /app/data && \
    chown -R appuser:appgroup /app && \
    chmod +x ./main

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8081

# Start the application
CMD ["./main"]