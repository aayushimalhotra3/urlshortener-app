#!/bin/bash

# Deploy URL Shortener to Render.com
# This script helps set up deployment to Render's free tier

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Setting up URL Shortener for Render.com${NC}"
echo "============================================"

# Check if git is initialized
if [ ! -d ".git" ]; then
    echo -e "${YELLOW}⚠️  Git repository not initialized${NC}"
    echo "Initializing git repository..."
    git init
    git add .
    git commit -m "Initial commit for URL shortener"
fi

# Check if remote origin exists
if ! git remote get-url origin &> /dev/null; then
    echo -e "${RED}❌ No git remote 'origin' found${NC}"
    echo -e "${YELLOW}Please add your GitHub repository as origin:${NC}"
    echo "git remote add origin https://github.com/YOUR_USERNAME/urlapp.git"
    echo "git push -u origin main"
    echo ""
    echo -e "${BLUE}Then follow these steps to deploy on Render:${NC}"
else
    REPO_URL=$(git remote get-url origin)
    echo -e "${GREEN}✅ Git remote found: $REPO_URL${NC}"
    
    # Push latest changes
    echo -e "${BLUE}📤 Pushing latest changes...${NC}"
    git add .
    if git diff --staged --quiet; then
        echo -e "${GREEN}✅ No changes to commit${NC}"
    else
        git commit -m "Update for Render deployment" || true
    fi
    git push origin main || git push origin master
fi

echo -e "\n${BLUE}📋 Render.com Deployment Steps:${NC}"
echo "1. Go to https://render.com and sign up/login"
echo "2. Click 'New +' → 'Web Service'"
echo "3. Connect your GitHub repository"
echo "4. Configure the service:"
echo "   • Name: urlshortener"
echo "   • Environment: Docker"
echo "   • Region: Oregon (or closest to you)"
echo "   • Branch: main (or master)"
echo "   • Dockerfile Path: ./Dockerfile"
echo "   • Plan: Free"
echo ""
echo "5. Set Environment Variables:"
echo "   PORT=10000"
echo "   GIN_MODE=release"
echo "   LOG_LEVEL=info"
echo "   METRICS_ENABLED=true"
echo "   RATE_LIMIT_RPS=5"
echo "   RATE_LIMIT_BURST=10"
echo "   MAX_URL_LENGTH=2048"
echo "   DB_PATH=/tmp/urlshortener.db"
echo "   REQUIRE_HTTPS=true"
echo ""
echo "6. Set Health Check Path: /health"
echo "7. Click 'Create Web Service'"

echo -e "\n${BLUE}📋 Alternative: Blueprint Deployment${NC}"
echo "1. Go to https://render.com/deploy"
echo "2. Connect your repository"
echo "3. Render will automatically detect render.yaml"
echo "4. Review and deploy"

echo -e "\n${YELLOW}💡 Free Tier Limits:${NC}"
echo "• 512 MB RAM"
echo "• Sleeps after 15 minutes of inactivity"
echo "• 100 GB bandwidth per month"
echo "• Free SSL certificate"
echo "• Custom domains supported"
echo "• Automatic deploys on git push"

echo -e "\n${BLUE}🔧 Useful Render Features:${NC}"
echo "• Automatic HTTPS"
echo "• Environment variable management"
echo "• Build and deploy logs"
echo "• Health checks"
echo "• Custom domains"
echo "• GitHub integration"

echo -e "\n${GREEN}📁 Files created for Render deployment:${NC}"
echo "• render.yaml - Service configuration"
echo "• Dockerfile - Container definition"
echo "• This script - Deployment helper"

echo -e "\n${BLUE}🧪 After deployment, test your service:${NC}"
echo "curl https://your-service-name.onrender.com/health"

echo -e "\n${GREEN}🎯 Your URL shortener will be available at:${NC}"
echo "https://your-service-name.onrender.com"

echo -e "\n${YELLOW}⚠️  Note: Free tier services sleep after 15 minutes of inactivity${NC}"
echo "First request after sleep may take 30-60 seconds to wake up"