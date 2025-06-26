# Production Deployment Guide

## Free Hosting Options Comparison

| Platform | Free Tier | Pros | Cons | Best For |
|----------|-----------|------|------|----------|
| **Google Cloud Run** | 2M requests, 360K GB-seconds/month | Serverless, auto-scaling, global CDN | Cold starts | High-traffic apps |
| **Render.com** | 512MB RAM, 100GB bandwidth | Easy setup, auto-deploy, free SSL | Sleeps after 15min idle | Simple deployment |
| **Oracle Cloud** | 2 ARM VMs (1 OCPU + 6GB RAM each) | Most generous free tier, always on | Complex setup | Production workloads |
| **Fly.io** | 3 shared VMs, 160GB/month | Fast global deployment, persistent volumes | Limited to 3 apps | Quick deployment |
| **Heroku** | 550 dyno hours/month | Easy deployment, add-ons ecosystem | Sleeps after 30min idle | Simple apps |
| **DigitalOcean** | $200 credit (60 days) | Full VPS control, great docs | Not permanently free | Testing/development |

## 🚀 Quick Deploy Options

### Option 1: Google Cloud Run (Recommended for High Traffic)

```bash
# Install Google Cloud SDK
# macOS: brew install google-cloud-sdk
# Ubuntu: sudo apt-get install google-cloud-sdk

# Deploy
./scripts/deploy-gcp.sh
```

### Option 2: Render.com (Easiest Setup)

```bash
# No CLI needed - uses web interface
./scripts/deploy-render.sh
```

### Option 3: Oracle Cloud Always Free (Most Resources)

```bash
# Run on Oracle Cloud VM
sudo ./scripts/deploy-oracle.sh
```

### Option 4: Fly.io (Fast Global Deployment)

```bash
# Install flyctl
curl -L https://fly.io/install.sh | sh

# Deploy
./scripts/deploy-fly.sh
```

### Option 5: Heroku (Simple Git-based Deploy)

```bash
# Install Heroku CLI
# macOS: brew install heroku/brew/heroku
# Ubuntu: sudo snap install heroku --classic

# Deploy
./scripts/deploy-heroku.sh
```

## Manual Deployment Instructions

### Google Cloud Run

#### Prerequisites
```bash
# Install Google Cloud SDK
# macOS: brew install google-cloud-sdk
# Ubuntu: sudo apt-get install google-cloud-sdk

# Login and set project
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

#### Deploy
```bash
# Enable required APIs
gcloud services enable cloudbuild.googleapis.com run.googleapis.com

# Build and deploy
gcloud builds submit --config cloudbuild.yaml .

# Or manual deployment
docker build -t gcr.io/YOUR_PROJECT_ID/urlshortener .
docker push gcr.io/YOUR_PROJECT_ID/urlshortener
gcloud run deploy urlshortener --image gcr.io/YOUR_PROJECT_ID/urlshortener --region us-central1 --allow-unauthenticated
```

### Render.com

#### Prerequisites
- GitHub account
- Repository pushed to GitHub

#### Deploy
1. Go to https://render.com
2. Connect your GitHub repository
3. Choose "Web Service"
4. Configure:
   - Environment: Docker
   - Dockerfile Path: ./Dockerfile
   - Plan: Free
5. Set environment variables (see render.yaml)
6. Deploy

### Oracle Cloud Always Free

#### Prerequisites
```bash
# Create Oracle Cloud account
# Launch ARM-based compute instance (Ubuntu 20.04+)
# Connect via SSH
```

#### Deploy
```bash
# Copy application files to server
scp -r . oracle-user@your-instance-ip:/tmp/urlapp

# Run deployment script
ssh oracle-user@your-instance-ip
sudo /tmp/urlapp/scripts/deploy-oracle.sh
```

### One-Command Deploy
```bash
# Run the automated deployment script
./scripts/deploy-fly.sh
```

### Manual Fly.io Deployment
```bash
# 1. Create app
flyctl apps create urlshortener-app

# 2. Create persistent volume for SQLite
flyctl volumes create urlshortener_data --region ord --size 1

# 3. Set environment variables
flyctl secrets set \
    GIN_MODE=release \
    LOG_LEVEL=info \
    METRICS_ENABLED=true \
    RATE_LIMIT_RPS=10 \
    RATE_LIMIT_BURST=20

# 4. Deploy
flyctl deploy

# 5. Open app
flyctl open
```

## 🔄 Alternative: Heroku Deployment

### Prerequisites
```bash
# Install Heroku CLI
# macOS: brew tap heroku/brew && brew install heroku
# Or download from: https://devcenter.heroku.com/articles/heroku-cli

# Login
heroku login
```

### Deploy to Heroku
```bash
# Run the automated deployment script
./scripts/deploy-heroku.sh
```

### Manual Heroku Deployment
```bash
# 1. Create app with container stack
heroku create your-app-name --stack container

# 2. Set environment variables
heroku config:set \
    PORT=8081 \
    GIN_MODE=release \
    LOG_LEVEL=info

# 3. Deploy
git push heroku main

# 4. Open app
heroku open
```

## 🌊 DigitalOcean App Platform

### Via Web Interface
1. Go to [DigitalOcean Apps](https://cloud.digitalocean.com/apps)
2. Click "Create App"
3. Connect your GitHub repository
4. Upload the `.do/app.yaml` specification
5. Review and deploy

### Via CLI (doctl)
```bash
# Install doctl
# macOS: brew install doctl

# Authenticate
doctl auth init

# Create app from spec
doctl apps create --spec .do/app.yaml

# Get app info
doctl apps list
```

## 🔧 Environment Configuration

### Required Environment Variables
```bash
PORT=8081                    # Application port
GIN_MODE=release            # Production mode
DB_PATH=/app/data/urls.db   # Database path
LOG_LEVEL=info              # Logging level
METRICS_ENABLED=true        # Enable metrics
RATE_LIMIT_RPS=10           # Rate limiting
RATE_LIMIT_BURST=20         # Rate limit burst
MAX_URL_LENGTH=2048         # Max URL length
```

### Optional Environment Variables
```bash
REQUIRE_HTTPS=true          # Force HTTPS redirects
TRUSTED_PROXIES=*           # Trusted proxy IPs
SECURITY_HEADERS=true       # Enable security headers
```

## 🌐 Custom Domain & HTTPS

### Fly.io Custom Domain
```bash
# Add custom domain
flyctl certs create your-domain.com

# Add DNS record
# A record: your-domain.com -> [Fly.io IP]
# Or CNAME: your-domain.com -> your-app.fly.dev

# Check certificate status
flyctl certs show your-domain.com
```

### Heroku Custom Domain
```bash
# Add domain (requires paid dyno)
heroku domains:add your-domain.com

# Get DNS target
heroku domains

# Add CNAME record in your DNS provider
# CNAME: your-domain.com -> your-app.herokuapp.com
```

## 📊 Monitoring & Observability

### Application Monitoring
```bash
# Health check
curl https://your-app.fly.dev/health

# Metrics endpoint
curl https://your-app.fly.dev/metrics

# View logs
flyctl logs -a your-app
```

### External Monitoring Services (Free Tiers)
- **UptimeRobot**: 50 monitors, 5-minute intervals
- **Pingdom**: 1 monitor, 1-minute intervals
- **StatusCake**: 10 monitors, 5-minute intervals

### Log Aggregation (Free Tiers)
- **Logtail**: 1GB/month
- **Papertrail**: 16MB/day, 7-day retention
- **LogDNA**: 500MB/day, 1-day retention

## 🔄 Zero-Downtime Deployments

### Fly.io Rolling Updates
```bash
# Deploy with health checks
flyctl deploy --strategy rolling

# Monitor deployment
flyctl status

# Rollback if needed
flyctl releases list
flyctl rollback [version]
```

### Blue-Green Deployment
```bash
# Create staging app
flyctl apps create urlshortener-staging

# Deploy to staging
flyctl deploy -a urlshortener-staging

# Test staging
curl https://urlshortener-staging.fly.dev/health

# Swap domains (manual DNS update)
```

## 🚨 Incident Response

### Quick Diagnostics
```bash
# Check app status
flyctl status -a your-app

# View recent logs
flyctl logs -a your-app --tail

# Check resource usage
flyctl vm status -a your-app

# Scale up if needed
flyctl scale count 2 -a your-app
```

### Common Issues & Solutions

#### App Won't Start
```bash
# Check logs for errors
flyctl logs -a your-app

# Verify environment variables
flyctl secrets list -a your-app

# Check volume mounts
flyctl volumes list -a your-app
```

#### Database Issues
```bash
# SSH into container
flyctl ssh console -a your-app

# Check database file
ls -la /app/data/
sqlite3 /app/data/urls.db ".tables"

# Check permissions
ls -la /app/data/urls.db
```

#### High Memory Usage
```bash
# Scale to larger instance
flyctl scale vm shared-cpu-2x -a your-app

# Or add more instances
flyctl scale count 2 -a your-app
```

## 🔒 Security Considerations

### Production Security Checklist
- [ ] HTTPS enforced (handled by platform)
- [ ] Security headers enabled
- [ ] Rate limiting configured
- [ ] Input validation in place
- [ ] Database file permissions secured
- [ ] Secrets properly managed
- [ ] Regular security updates

### Security Headers
The application automatically sets:
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `X-XSS-Protection: 1; mode=block`
- `Strict-Transport-Security` (when HTTPS)
- `Content-Security-Policy`

## 📈 Scaling Strategies

### Vertical Scaling (Fly.io)
```bash
# Upgrade VM size
flyctl scale vm shared-cpu-2x -a your-app  # 2 vCPU, 512MB
flyctl scale vm shared-cpu-4x -a your-app  # 4 vCPU, 1GB
```

### Horizontal Scaling
```bash
# Add more instances
flyctl scale count 3 -a your-app

# Auto-scaling (paid plans)
flyctl autoscale set min=1 max=5 -a your-app
```

### Database Scaling
For high traffic, consider:
1. **PostgreSQL**: Migrate from SQLite
2. **Redis**: Add caching layer
3. **CDN**: Cache static assets

## 💰 Cost Optimization

### Free Tier Limits
- **Fly.io**: 3 VMs, 3GB storage, 160GB transfer
- **Heroku**: 550-1000 dyno hours, app sleeps
- **Railway**: $5 credit/month

### Cost-Effective Strategies
1. Use SQLite for low-traffic apps
2. Implement efficient caching
3. Optimize Docker image size
4. Monitor resource usage
5. Scale down during low traffic

## 🎯 Performance Optimization

### Application Performance
```bash
# Enable Gin release mode
export GIN_MODE=release

# Optimize database queries
# Use connection pooling
# Implement caching
```

### Infrastructure Performance
```bash
# Choose region closest to users
flyctl regions list
flyctl regions set ord dfw -a your-app

# Use CDN for static assets
# Implement HTTP/2
# Enable gzip compression
```

## 🔄 Backup & Recovery

### Database Backup (SQLite)
```bash
# SSH into container
flyctl ssh console -a your-app

# Create backup
sqlite3 /app/data/urls.db ".backup /tmp/backup.db"

# Download backup
flyctl sftp get /tmp/backup.db ./backup-$(date +%Y%m%d).db
```

### Automated Backups
```bash
# Create backup script
#!/bin/bash
flyctl ssh console -a your-app -C "sqlite3 /app/data/urls.db '.backup /tmp/backup.db'"
flyctl sftp get /tmp/backup.db ./backups/backup-$(date +%Y%m%d-%H%M%S).db

# Schedule with cron
0 2 * * * /path/to/backup-script.sh
```

## 📚 Additional Resources

- [Fly.io Documentation](https://fly.io/docs/)
- [Heroku Dev Center](https://devcenter.heroku.com/)
- [DigitalOcean App Platform](https://docs.digitalocean.com/products/app-platform/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Go Production Checklist](https://github.com/golang/go/wiki/Production)

---

**🎉 Congratulations! Your URL shortener is now production-ready and deployed to the cloud!**