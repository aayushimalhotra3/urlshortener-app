#!/bin/bash

# Fly.io Deployment Script for URL Shortener
# This script handles complete deployment with zero-downtime updates

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="urlshortener-app"
REGION="ord"  # Chicago - change as needed
VOLUME_NAME="urlshortener_data"
VOLUME_SIZE="1"  # 1GB for free tier

echo -e "${BLUE}🚀 Deploying URL Shortener to Fly.io${NC}"
echo "================================================"

# Function to print status
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if flyctl is installed
print_status "Checking flyctl installation..."
if ! command -v flyctl > /dev/null 2>&1; then
    print_error "flyctl is not installed. Installing..."
    curl -L https://fly.io/install.sh | sh
    export PATH="$HOME/.fly/bin:$PATH"
    print_success "flyctl installed"
else
    print_success "flyctl is available"
fi

# Check if user is logged in
print_status "Checking Fly.io authentication..."
if ! flyctl auth whoami > /dev/null 2>&1; then
    print_warning "Not logged in to Fly.io. Please log in:"
    flyctl auth login
fi
print_success "Authenticated with Fly.io"

# Check if app exists
print_status "Checking if app exists..."
if flyctl apps list | grep -q "$APP_NAME"; then
    print_success "App $APP_NAME already exists"
    EXISTING_APP=true
else
    print_status "Creating new app: $APP_NAME"
    flyctl apps create "$APP_NAME" --org personal
    print_success "App $APP_NAME created"
    EXISTING_APP=false
fi

# Create volume if it doesn't exist
print_status "Checking persistent volume..."
if flyctl volumes list -a "$APP_NAME" | grep -q "$VOLUME_NAME"; then
    print_success "Volume $VOLUME_NAME already exists"
else
    print_status "Creating persistent volume for database..."
    flyctl volumes create "$VOLUME_NAME" --region "$REGION" --size "$VOLUME_SIZE" -a "$APP_NAME"
    print_success "Volume $VOLUME_NAME created"
fi

# Set secrets (environment variables)
print_status "Setting application secrets..."
flyctl secrets set \
    GIN_MODE=release \
    LOG_LEVEL=info \
    METRICS_ENABLED=true \
    RATE_LIMIT_RPS=10 \
    RATE_LIMIT_BURST=20 \
    MAX_URL_LENGTH=2048 \
    DB_PATH=/app/data/urls.db \
    -a "$APP_NAME"
print_success "Secrets configured"

# Build and deploy
print_status "Building and deploying application..."
if [ "$EXISTING_APP" = true ]; then
    print_status "Performing zero-downtime deployment..."
    flyctl deploy --ha=false -a "$APP_NAME"
else
    print_status "Performing initial deployment..."
    flyctl deploy --ha=false -a "$APP_NAME"
fi
print_success "Deployment completed"

# Wait for deployment to be ready
print_status "Waiting for application to be ready..."
sleep 10

# Get app URL
APP_URL=$(flyctl info -a "$APP_NAME" | grep "Hostname" | awk '{print $2}')
if [ -n "$APP_URL" ]; then
    APP_URL="https://$APP_URL"
else
    APP_URL="https://$APP_NAME.fly.dev"
fi

# Test deployment
print_status "Testing deployment..."
if curl -f "$APP_URL/health" > /dev/null 2>&1; then
    print_success "Health check passed"
else
    print_warning "Health check failed - app might still be starting"
fi

# Show deployment info
echo ""
echo "================================================"
print_success "Deployment completed successfully!"
echo ""
echo -e "${BLUE}Application URLs:${NC}"
echo "🌐 Main App: $APP_URL"
echo "❤️  Health: $APP_URL/health"
echo "📊 Metrics: $APP_URL/metrics"
echo ""
echo -e "${BLUE}Useful Commands:${NC}"
echo "📋 View logs: flyctl logs -a $APP_NAME"
echo "📊 App status: flyctl status -a $APP_NAME"
echo "🔧 SSH access: flyctl ssh console -a $APP_NAME"
echo "📈 Scale app: flyctl scale count 2 -a $APP_NAME"
echo "🔄 Redeploy: flyctl deploy -a $APP_NAME"
echo ""
echo -e "${BLUE}Free Tier Limits:${NC}"
echo "• 3 shared-cpu-1x 256MB VMs"
echo "• 3GB persistent volume storage"
echo "• 160GB outbound data transfer"
echo ""
echo -e "${GREEN}✅ Your URL shortener is now live!${NC}"

# Optional: Open in browser
read -p "Open application in browser? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    flyctl open -a "$APP_NAME"
fi