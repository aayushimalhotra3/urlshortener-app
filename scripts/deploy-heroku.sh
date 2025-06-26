#!/bin/bash

# Heroku Deployment Script for URL Shortener
# Free tier deployment with Docker container

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="urlshortener-$(date +%s)"  # Unique app name
REGION="us"  # or "eu" for Europe

echo -e "${BLUE}🚀 Deploying URL Shortener to Heroku${NC}"
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

# Check if Heroku CLI is installed
print_status "Checking Heroku CLI installation..."
if ! command -v heroku > /dev/null 2>&1; then
    print_error "Heroku CLI is not installed. Please install it from: https://devcenter.heroku.com/articles/heroku-cli"
    exit 1
else
    print_success "Heroku CLI is available"
fi

# Check if user is logged in
print_status "Checking Heroku authentication..."
if ! heroku auth:whoami > /dev/null 2>&1; then
    print_warning "Not logged in to Heroku. Please log in:"
    heroku login
fi
print_success "Authenticated with Heroku"

# Check if git repo is initialized
print_status "Checking git repository..."
if [ ! -d ".git" ]; then
    print_status "Initializing git repository..."
    git init
    git add .
    git commit -m "Initial commit for Heroku deployment"
    print_success "Git repository initialized"
else
    print_success "Git repository exists"
fi

# Create Heroku app
print_status "Creating Heroku app..."
if heroku create "$APP_NAME" --region "$REGION" --stack container; then
    print_success "App $APP_NAME created"
else
    print_error "Failed to create app. Trying with auto-generated name..."
    APP_NAME=$(heroku create --region "$REGION" --stack container | grep -o 'https://[^.]*' | sed 's/https:\/\///')
    print_success "App $APP_NAME created"
fi

# Set environment variables
print_status "Setting environment variables..."
heroku config:set \
    PORT=8081 \
    GIN_MODE=release \
    LOG_LEVEL=info \
    METRICS_ENABLED=true \
    RATE_LIMIT_RPS=10 \
    RATE_LIMIT_BURST=20 \
    MAX_URL_LENGTH=2048 \
    DB_PATH=/app/data/urls.db \
    --app "$APP_NAME"
print_success "Environment variables configured"

# Deploy to Heroku
print_status "Deploying to Heroku..."
git add .
if git diff --staged --quiet; then
    print_status "No changes to commit"
else
    git commit -m "Deploy to Heroku"
fi

heroku git:remote -a "$APP_NAME"
git push heroku main
print_success "Deployment completed"

# Wait for deployment to be ready
print_status "Waiting for application to be ready..."
sleep 15

# Get app URL
APP_URL=$(heroku info -a "$APP_NAME" | grep "Web URL" | awk '{print $3}')
if [ -z "$APP_URL" ]; then
    APP_URL="https://$APP_NAME.herokuapp.com"
fi

# Test deployment
print_status "Testing deployment..."
if curl -f "$APP_URL/health" > /dev/null 2>&1; then
    print_success "Health check passed"
else
    print_warning "Health check failed - app might still be starting"
    print_status "Checking logs..."
    heroku logs --tail --num 50 -a "$APP_NAME"
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
echo "📋 View logs: heroku logs --tail -a $APP_NAME"
echo "📊 App info: heroku info -a $APP_NAME"
echo "🔧 SSH access: heroku run bash -a $APP_NAME"
echo "📈 Scale app: heroku ps:scale web=1 -a $APP_NAME"
echo "🔄 Redeploy: git push heroku main"
echo "🗑️  Delete app: heroku apps:destroy $APP_NAME"
echo ""
echo -e "${BLUE}Free Tier Limits:${NC}"
echo "• 550-1000 dyno hours per month"
echo "• App sleeps after 30 minutes of inactivity"
echo "• 10,000 rows in Postgres (if using Postgres addon)"
echo ""
echo -e "${YELLOW}Note: SQLite data will be lost on dyno restart.${NC}"
echo -e "${YELLOW}Consider upgrading to Postgres addon for persistence.${NC}"
echo ""
echo -e "${GREEN}✅ Your URL shortener is now live on Heroku!${NC}"

# Optional: Open in browser
read -p "Open application in browser? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    heroku open -a "$APP_NAME"
fi