# URL Shortener Makefile

# Variables
APP_NAME := urlshortener
GO_VERSION := 1.21
DOCKER_IMAGE := $(APP_NAME):latest
DOCKER_REGISTRY := your-registry.com
PORT := 8081

# Colors for output
RED := \033[31m
GREEN := \033[32m
YELLOW := \033[33m
BLUE := \033[34m
RESET := \033[0m

.PHONY: help build run test clean docker-build docker-run docker-push lint fmt vet deps migrate dev prod logs

# Default target
help: ## Show this help message
	@echo "$(BLUE)URL Shortener - Available Commands$(RESET)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-20s$(RESET) %s\n", $$1, $$2}'

# Development Commands
build: ## Build the application binary
	@echo "$(BLUE)Building application...$(RESET)"
	go build -o bin/$(APP_NAME) cmd/shortener/main.go
	@echo "$(GREEN)Build completed: bin/$(APP_NAME)$(RESET)"

run: ## Run the application locally
	@echo "$(BLUE)Starting application on port $(PORT)...$(RESET)"
	go run cmd/shortener/main.go

dev: ## Run the application in development mode with hot reload
	@echo "$(BLUE)Starting development server...$(RESET)"
	@if command -v air > /dev/null; then \
		air; \
	else \
		echo "$(YELLOW)Air not found. Install with: go install github.com/cosmtrek/air@latest$(RESET)"; \
		go run cmd/shortener/main.go; \
	fi

# Testing Commands
test: ## Run all tests
	@echo "$(BLUE)Running tests...$(RESET)"
	go test -v ./...

test-coverage: ## Run tests with coverage report
	@echo "$(BLUE)Running tests with coverage...$(RESET)"
	go test -v -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html
	@echo "$(GREEN)Coverage report generated: coverage.html$(RESET)"

test-race: ## Run tests with race detection
	@echo "$(BLUE)Running tests with race detection...$(RESET)"
	go test -race -v ./...

bench: ## Run benchmarks
	@echo "$(BLUE)Running benchmarks...$(RESET)"
	go test -bench=. -benchmem ./...

# Code Quality Commands
lint: ## Run linter
	@echo "$(BLUE)Running linter...$(RESET)"
	@if command -v golangci-lint > /dev/null; then \
		golangci-lint run; \
	else \
		echo "$(RED)golangci-lint not found. Install from: https://golangci-lint.run/usage/install/$(RESET)"; \
		exit 1; \
	fi

fmt: ## Format code
	@echo "$(BLUE)Formatting code...$(RESET)"
	go fmt ./...
	goimports -w .
	@echo "$(GREEN)Code formatted$(RESET)"

vet: ## Run go vet
	@echo "$(BLUE)Running go vet...$(RESET)"
	go vet ./...

sec: ## Run security scan
	@echo "$(BLUE)Running security scan...$(RESET)"
	@if command -v gosec > /dev/null; then \
		gosec ./...; \
	else \
		echo "$(YELLOW)gosec not found. Install with: go install github.com/securecodewarrior/gosec/v2/cmd/gosec@latest$(RESET)"; \
	fi

# Dependency Management
deps: ## Download and tidy dependencies
	@echo "$(BLUE)Managing dependencies...$(RESET)"
	go mod download
	go mod tidy
	@echo "$(GREEN)Dependencies updated$(RESET)"

deps-update: ## Update all dependencies
	@echo "$(BLUE)Updating dependencies...$(RESET)"
	go get -u ./...
	go mod tidy
	@echo "$(GREEN)Dependencies updated$(RESET)"

deps-vendor: ## Create vendor directory
	@echo "$(BLUE)Creating vendor directory...$(RESET)"
	go mod vendor
	@echo "$(GREEN)Vendor directory created$(RESET)"

# Database Commands
migrate-up: ## Run database migrations up
	@echo "$(BLUE)Running migrations up...$(RESET)"
	@if command -v migrate > /dev/null; then \
		migrate -path migrations -database "sqlite3://urls.db" up; \
	else \
		echo "$(YELLOW)migrate not found. Install from: https://github.com/golang-migrate/migrate$(RESET)"; \
	fi

migrate-down: ## Run database migrations down
	@echo "$(BLUE)Running migrations down...$(RESET)"
	@if command -v migrate > /dev/null; then \
		migrate -path migrations -database "sqlite3://urls.db" down; \
	else \
		echo "$(YELLOW)migrate not found. Install from: https://github.com/golang-migrate/migrate$(RESET)"; \
	fi

migrate-create: ## Create a new migration (usage: make migrate-create NAME=migration_name)
	@echo "$(BLUE)Creating migration: $(NAME)...$(RESET)"
	@if [ -z "$(NAME)" ]; then \
		echo "$(RED)Error: NAME is required. Usage: make migrate-create NAME=migration_name$(RESET)"; \
		exit 1; \
	fi
	@if command -v migrate > /dev/null; then \
		migrate create -ext sql -dir migrations $(NAME); \
	else \
		echo "$(YELLOW)migrate not found. Install from: https://github.com/golang-migrate/migrate$(RESET)"; \
	fi

# Docker Commands
docker-build: ## Build Docker image
	@echo "$(BLUE)Building Docker image...$(RESET)"
	docker build -t $(DOCKER_IMAGE) .
	@echo "$(GREEN)Docker image built: $(DOCKER_IMAGE)$(RESET)"

docker-run: ## Run application in Docker container
	@echo "$(BLUE)Running Docker container...$(RESET)"
	docker run -p $(PORT):$(PORT) --name $(APP_NAME) $(DOCKER_IMAGE)

docker-stop: ## Stop Docker container
	@echo "$(BLUE)Stopping Docker container...$(RESET)"
	docker stop $(APP_NAME) || true
	docker rm $(APP_NAME) || true

docker-push: ## Push Docker image to registry
	@echo "$(BLUE)Pushing Docker image to registry...$(RESET)"
	docker tag $(DOCKER_IMAGE) $(DOCKER_REGISTRY)/$(DOCKER_IMAGE)
	docker push $(DOCKER_REGISTRY)/$(DOCKER_IMAGE)
	@echo "$(GREEN)Docker image pushed$(RESET)"

# Docker Compose Commands
compose-up: ## Start all services with Docker Compose
	@echo "$(BLUE)Starting services with Docker Compose...$(RESET)"
	docker-compose up -d
	@echo "$(GREEN)Services started$(RESET)"

compose-down: ## Stop all services
	@echo "$(BLUE)Stopping services...$(RESET)"
	docker-compose down
	@echo "$(GREEN)Services stopped$(RESET)"

compose-logs: ## View logs from all services
	@echo "$(BLUE)Viewing logs...$(RESET)"
	docker-compose logs -f

compose-build: ## Build and start services
	@echo "$(BLUE)Building and starting services...$(RESET)"
	docker-compose up -d --build
	@echo "$(GREEN)Services built and started$(RESET)"

compose-restart: ## Restart all services
	@echo "$(BLUE)Restarting services...$(RESET)"
	docker-compose restart
	@echo "$(GREEN)Services restarted$(RESET)"

# Monitoring Commands
monitor: ## Open monitoring dashboards
	@echo "$(BLUE)Opening monitoring dashboards...$(RESET)"
	@echo "$(GREEN)Prometheus: http://localhost:9090$(RESET)"
	@echo "$(GREEN)Grafana: http://localhost:3000 (admin/admin)$(RESET)"
	@echo "$(GREEN)Application: http://localhost:$(PORT)$(RESET)"

metrics: ## View application metrics
	@echo "$(BLUE)Fetching application metrics...$(RESET)"
	curl -s http://localhost:$(PORT)/metrics | head -20

health: ## Check application health
	@echo "$(BLUE)Checking application health...$(RESET)"
	curl -s http://localhost:$(PORT)/health | jq .

# Load Testing Commands
load-test: ## Run basic load test
	@echo "$(BLUE)Running load test...$(RESET)"
	@if command -v ab > /dev/null; then \
		ab -n 1000 -c 10 http://localhost:$(PORT)/health; \
	else \
		echo "$(YELLOW)Apache Bench (ab) not found. Install apache2-utils$(RESET)"; \
	fi

stress-test: ## Run stress test with hey
	@echo "$(BLUE)Running stress test...$(RESET)"
	@if command -v hey > /dev/null; then \
		hey -n 10000 -c 100 -t 30 http://localhost:$(PORT)/health; \
	else \
		echo "$(YELLOW)hey not found. Install with: go install github.com/rakyll/hey@latest$(RESET)"; \
	fi

# Cleanup Commands
clean: ## Clean build artifacts and temporary files
	@echo "$(BLUE)Cleaning up...$(RESET)"
	rm -rf bin/
	rm -f coverage.out coverage.html
	rm -f *.db
	go clean -cache
	go clean -testcache
	@echo "$(GREEN)Cleanup completed$(RESET)"

clean-docker: ## Clean Docker images and containers
	@echo "$(BLUE)Cleaning Docker resources...$(RESET)"
	docker system prune -f
	docker image prune -f
	@echo "$(GREEN)Docker cleanup completed$(RESET)"

# Production Commands
prod-deploy: ## Deploy to production
	@echo "$(BLUE)Deploying to production...$(RESET)"
	@echo "$(YELLOW)This would typically trigger your deployment pipeline$(RESET)"
	@echo "$(GREEN)Production deployment initiated$(RESET)"

prod-rollback: ## Rollback production deployment
	@echo "$(BLUE)Rolling back production deployment...$(RESET)"
	@echo "$(YELLOW)This would typically trigger your rollback pipeline$(RESET)"
	@echo "$(GREEN)Production rollback initiated$(RESET)"

# CI/CD Commands
ci: ## Run CI pipeline locally
	@echo "$(BLUE)Running CI pipeline...$(RESET)"
	make deps
	make fmt
	make vet
	make lint
	make test
	make build
	@echo "$(GREEN)CI pipeline completed$(RESET)"

release: ## Create a new release
	@echo "$(BLUE)Creating release...$(RESET)"
	@if [ -z "$(VERSION)" ]; then \
		echo "$(RED)Error: VERSION is required. Usage: make release VERSION=v1.0.0$(RESET)"; \
		exit 1; \
	fi
	git tag $(VERSION)
	git push origin $(VERSION)
	@echo "$(GREEN)Release $(VERSION) created$(RESET)"

# Installation Commands
install-tools: ## Install development tools
	@echo "$(BLUE)Installing development tools...$(RESET)"
	go install github.com/cosmtrek/air@latest
	go install github.com/securecodewarrior/gosec/v2/cmd/gosec@latest
	go install github.com/rakyll/hey@latest
	go install golang.org/x/tools/cmd/goimports@latest
	@echo "$(GREEN)Development tools installed$(RESET)"

setup: ## Setup development environment
	@echo "$(BLUE)Setting up development environment...$(RESET)"
	make install-tools
	make deps
	make migrate-up
	@echo "$(GREEN)Development environment ready$(RESET)"

# Documentation Commands
docs: ## Generate documentation
	@echo "$(BLUE)Generating documentation...$(RESET)"
	go doc -all ./... > docs/api.md
	@echo "$(GREEN)Documentation generated$(RESET)"

# Quick Commands
quick-start: ## Quick start for new developers
	@echo "$(BLUE)Quick start setup...$(RESET)"
	make setup
	make test
	make run

all: ## Run all checks and build
	make ci
	make docker-build
	@echo "$(GREEN)All tasks completed$(RESET)"