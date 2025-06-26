FROM golang:1.20-alpine AS builder

WORKDIR /app

# Copy go.mod and go.sum files
COPY go.mod ./

# Download dependencies
RUN go mod download

# Copy the source code
COPY . .

# Build the application
RUN CGO_ENABLED=1 GOOS=linux go build -a -o shortener ./cmd/shortener

# Use a smaller image for the final container
FROM alpine:latest

# Install required dependencies for SQLite
RUN apk --no-cache add ca-certificates libc6-compat

WORKDIR /app

# Copy the binary from the builder stage
COPY --from=builder /app/shortener /app/

# Copy migrations and web files
COPY --from=builder /app/migrations /app/migrations
COPY --from=builder /app/web /app/web

# Expose the port
EXPOSE 8080

# Run the application
CMD ["/app/shortener"]