#!/bin/bash

# Deploy URL Shortener to Google Cloud Run
# This script automates the deployment process to Google Cloud Run's free tier

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVICE_NAME="urlshortener"
REGION="us-central1"
PLATFORM="managed"
PORT="8080"
MEMORY="512Mi"
CPU="1"
MAX_INSTANCES="10"
MIN_INSTANCES="0"

echo -e "${BLUE}🚀 Deploying URL Shortener to Google Cloud Run${NC}"
echo "==========================================="

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ Google Cloud SDK (gcloud) is not installed${NC}"
    echo "Please install it from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if user is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "."; then
    echo -e "${YELLOW}⚠️  Not authenticated with Google Cloud${NC}"
    echo "Please run: gcloud auth login"
    exit 1
fi

# Get current project
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}❌ No Google Cloud project set${NC}"
    echo "Please run: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

echo -e "${GREEN}✅ Project: $PROJECT_ID${NC}"
echo -e "${GREEN}✅ Region: $REGION${NC}"

# Enable required APIs
echo -e "\n${BLUE}📋 Enabling required APIs...${NC}"
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable containerregistry.googleapis.com

# Build and deploy using Cloud Build
echo -e "\n${BLUE}🔨 Building and deploying with Cloud Build...${NC}"
if [ -f "cloudbuild.yaml" ]; then
    gcloud builds submit --config cloudbuild.yaml .
else
    # Fallback: direct deployment
    echo -e "${YELLOW}⚠️  cloudbuild.yaml not found, using direct deployment${NC}"
    
    # Build the image
    IMAGE_NAME="gcr.io/$PROJECT_ID/$SERVICE_NAME"
    echo -e "${BLUE}🔨 Building Docker image: $IMAGE_NAME${NC}"
    docker build -t "$IMAGE_NAME" .
    
    # Push the image
    echo -e "${BLUE}📤 Pushing image to Container Registry...${NC}"
    docker push "$IMAGE_NAME"
    
    # Deploy to Cloud Run
    echo -e "${BLUE}🚀 Deploying to Cloud Run...${NC}"
    gcloud run deploy "$SERVICE_NAME" \
        --image="$IMAGE_NAME" \
        --region="$REGION" \
        --platform="$PLATFORM" \
        --allow-unauthenticated \
        --port="$PORT" \
        --memory="$MEMORY" \
        --cpu="$CPU" \
        --max-instances="$MAX_INSTANCES" \
        --min-instances="$MIN_INSTANCES" \
        --set-env-vars="GIN_MODE=release,LOG_LEVEL=info,METRICS_ENABLED=true,RATE_LIMIT_RPS=10,RATE_LIMIT_BURST=20,MAX_URL_LENGTH=2048,DB_PATH=/tmp/urlshortener.db" \
        --execution-environment=gen2
fi

# Get service URL
SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" --region="$REGION" --format="value(status.url)")

echo -e "\n${GREEN}🎉 Deployment completed successfully!${NC}"
echo "==========================================="
echo -e "${GREEN}📱 Service URL: $SERVICE_URL${NC}"
echo -e "${GREEN}🌍 Health Check: $SERVICE_URL/health${NC}"
echo -e "${GREEN}📊 Metrics: $SERVICE_URL/metrics${NC}"

# Test the deployment
echo -e "\n${BLUE}🧪 Testing deployment...${NC}"
if curl -f -s "$SERVICE_URL/health" > /dev/null; then
    echo -e "${GREEN}✅ Health check passed${NC}"
else
    echo -e "${RED}❌ Health check failed${NC}"
fi

echo -e "\n${BLUE}📋 Useful commands:${NC}"
echo "View logs:    gcloud run services logs read $SERVICE_NAME --region=$REGION"
echo "Update service: gcloud run services update $SERVICE_NAME --region=$REGION"
echo "Delete service: gcloud run services delete $SERVICE_NAME --region=$REGION"
echo "View metrics: gcloud run services describe $SERVICE_NAME --region=$REGION"

echo -e "\n${YELLOW}💡 Free Tier Limits:${NC}"
echo "• 2 million requests per month"
echo "• 360,000 GB-seconds per month"
echo "• 180,000 vCPU-seconds per month"
echo "• Automatic scaling to zero when idle"
echo "• Built-in HTTPS and global CDN"

echo -e "\n${GREEN}🎯 Your URL shortener is now live at: $SERVICE_URL${NC}"