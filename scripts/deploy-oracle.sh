#!/bin/bash

# Deploy URL Shortener to Oracle Cloud Always Free
# This script helps set up the application on Oracle's free ARM instances

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Setting up URL Shortener for Oracle Cloud Always Free${NC}"
echo "========================================================"

# Configuration
APP_DIR="/opt/urlshortener"
SERVICE_NAME="urlshortener"
DOMAIN="your-domain.com"  # Update this

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Please run this script as root (sudo)${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Running as root${NC}"

# Detect OS and update system
echo -e "\n${BLUE}📦 Detecting operating system...${NC}"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    if command -v apt &> /dev/null; then
        echo -e "${GREEN}✅ Detected Ubuntu/Debian${NC}"
        echo -e "\n${BLUE}📦 Updating system packages...${NC}"
        apt update && apt upgrade -y
        
        echo -e "\n${BLUE}📦 Installing required packages...${NC}"
        apt install -y \
            docker.io \
            docker-compose \
            nginx \
            certbot \
            python3-certbot-nginx \
            ufw \
            curl \
            wget \
            git \
            htop \
            unzip
    elif command -v yum &> /dev/null; then
        echo -e "${GREEN}✅ Detected CentOS/RHEL${NC}"
        echo -e "\n${BLUE}📦 Updating system packages...${NC}"
        yum update -y
        
        echo -e "\n${BLUE}📦 Installing required packages...${NC}"
        yum install -y \
            docker \
            docker-compose \
            nginx \
            certbot \
            python3-certbot-nginx \
            firewalld \
            curl \
            wget \
            git \
            htop \
            unzip
    else
        echo -e "${RED}❌ Unsupported Linux distribution${NC}"
        exit 1
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "${RED}❌ This script is designed for Oracle Cloud Linux instances${NC}"
    echo -e "${YELLOW}⚠️  You're running macOS. This script should be run on your Oracle Cloud VM.${NC}"
    echo -e "\n${BLUE}📋 To deploy on Oracle Cloud:${NC}"
    echo "1. Create an Oracle Cloud Always Free account"
    echo "2. Launch an ARM-based compute instance (Ubuntu 20.04+)"
    echo "3. Copy this project to the instance:"
    echo "   scp -r . oracle-user@your-instance-ip:/tmp/urlapp"
    echo "4. SSH to the instance and run:"
    echo "   ssh oracle-user@your-instance-ip"
    echo "   sudo /tmp/urlapp/scripts/deploy-oracle.sh"
    exit 1
else
    echo -e "${RED}❌ Unsupported operating system: $OSTYPE${NC}"
    exit 1
fi

# Start and enable Docker
echo -e "\n${BLUE}🐳 Setting up Docker...${NC}"
systemctl start docker
systemctl enable docker

# Add current user to docker group (if not root)
if [ "$SUDO_USER" ]; then
    usermod -aG docker "$SUDO_USER"
    echo -e "${GREEN}✅ Added $SUDO_USER to docker group${NC}"
fi

# Configure firewall
echo -e "\n${BLUE}🔥 Configuring firewall...${NC}"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 22/tcp
# Allow monitoring ports (restrict to local network)
ufw allow from 10.0.0.0/8 to any port 3000
ufw allow from 10.0.0.0/8 to any port 9090
ufw --force enable

echo -e "${GREEN}✅ Firewall configured${NC}"

# Create application directory
echo -e "\n${BLUE}📁 Setting up application directory...${NC}"
mkdir -p "$APP_DIR"
cd "$APP_DIR"

# Clone or copy application files
if [ -d "/tmp/urlapp" ]; then
    echo -e "${BLUE}📋 Copying application files...${NC}"
    cp -r /tmp/urlapp/* "$APP_DIR/"
else
    echo -e "${YELLOW}⚠️  Application files not found in /tmp/urlapp${NC}"
    echo "Please copy your application files to $APP_DIR"
    echo "Or clone from git: git clone YOUR_REPO_URL ."
fi

# Create necessary directories
mkdir -p logs ssl

# Generate self-signed SSL certificate (for testing)
echo -e "\n${BLUE}🔐 Generating self-signed SSL certificate...${NC}"
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout ssl/selfsigned.key \
    -out ssl/selfsigned.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=$DOMAIN"

echo -e "${GREEN}✅ Self-signed certificate created${NC}"
echo -e "${YELLOW}⚠️  For production, use Let's Encrypt: certbot --nginx -d $DOMAIN${NC}"

# Set up Docker Compose
echo -e "\n${BLUE}🐳 Setting up Docker Compose...${NC}"
cp oracle-cloud/docker-compose.yml .
cp oracle-cloud/nginx.conf .

# Update nginx config with SSL paths
sed -i 's|# ssl_certificate /etc/nginx/ssl/selfsigned.crt;|ssl_certificate /etc/nginx/ssl/selfsigned.crt;|' nginx.conf
sed -i 's|# ssl_certificate_key /etc/nginx/ssl/selfsigned.key;|ssl_certificate_key /etc/nginx/ssl/selfsigned.key;|' nginx.conf

# Build and start services
echo -e "\n${BLUE}🔨 Building and starting services...${NC}"
docker-compose build
docker-compose up -d

# Wait for services to start
echo -e "\n${BLUE}⏳ Waiting for services to start...${NC}"
sleep 30

# Check service health
echo -e "\n${BLUE}🧪 Checking service health...${NC}"
if curl -f -s http://localhost/health > /dev/null; then
    echo -e "${GREEN}✅ Service is healthy${NC}"
else
    echo -e "${RED}❌ Service health check failed${NC}"
    echo "Checking logs..."
    docker-compose logs urlshortener
fi

# Create systemd service for auto-start
echo -e "\n${BLUE}⚙️  Creating systemd service...${NC}"
cat > /etc/systemd/system/urlshortener.service << EOF
[Unit]
Description=URL Shortener Docker Compose
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable urlshortener.service

echo -e "${GREEN}✅ Systemd service created and enabled${NC}"

# Set up log rotation
echo -e "\n${BLUE}📝 Setting up log rotation...${NC}"
cat > /etc/logrotate.d/urlshortener << EOF
$APP_DIR/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        docker-compose -f $APP_DIR/docker-compose.yml restart urlshortener
    endscript
}
EOF

# Create backup script
echo -e "\n${BLUE}💾 Creating backup script...${NC}"
cat > /usr/local/bin/backup-urlshortener.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/backups/urlshortener"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

# Backup database
docker-compose -f /opt/urlshortener/docker-compose.yml exec -T urlshortener cp /data/urlshortener.db /tmp/backup.db
docker cp urlshortener:/tmp/backup.db "$BACKUP_DIR/urlshortener_$DATE.db"

# Backup configuration
tar -czf "$BACKUP_DIR/config_$DATE.tar.gz" -C /opt/urlshortener .

# Keep only last 7 days of backups
find "$BACKUP_DIR" -name "*.db" -mtime +7 -delete
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: $DATE"
EOF

chmod +x /usr/local/bin/backup-urlshortener.sh

# Set up daily backup cron job
echo -e "\n${BLUE}⏰ Setting up daily backups...${NC}"
echo "0 2 * * * root /usr/local/bin/backup-urlshortener.sh >> /var/log/urlshortener-backup.log 2>&1" > /etc/cron.d/urlshortener-backup

# Get public IP
PUBLIC_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || echo "unknown")

echo -e "\n${GREEN}🎉 Deployment completed successfully!${NC}"
echo "========================================"
echo -e "${GREEN}🌍 Public IP: $PUBLIC_IP${NC}"
echo -e "${GREEN}📱 HTTP URL: http://$PUBLIC_IP${NC}"
echo -e "${GREEN}🔒 HTTPS URL: https://$PUBLIC_IP${NC}"
echo -e "${GREEN}🏥 Health Check: http://$PUBLIC_IP/health${NC}"
echo -e "${GREEN}📊 Metrics: http://$PUBLIC_IP/metrics${NC}"
echo -e "${GREEN}📈 Grafana: http://$PUBLIC_IP:3000 (admin/admin123)${NC}"
echo -e "${GREEN}🔍 Prometheus: http://$PUBLIC_IP:9090${NC}"

echo -e "\n${BLUE}📋 Useful commands:${NC}"
echo "View logs:        docker-compose -f $APP_DIR/docker-compose.yml logs -f"
echo "Restart service:  systemctl restart urlshortener"
echo "Stop service:     systemctl stop urlshortener"
echo "Update app:       cd $APP_DIR && git pull && docker-compose build && docker-compose up -d"
echo "Backup data:      /usr/local/bin/backup-urlshortener.sh"
echo "SSL certificate:  certbot --nginx -d $DOMAIN"

echo -e "\n${YELLOW}💡 Oracle Cloud Always Free Limits:${NC}"
echo "• 2 ARM-based Compute VMs (1 OCPU + 6 GB RAM each)"
echo "• 200 GB Block Storage"
echo "• 10 GB Object Storage"
echo "• 1 Flexible Load Balancer"
echo "• Always free as long as you use it monthly"

echo -e "\n${YELLOW}🔧 Next steps:${NC}"
echo "1. Point your domain to $PUBLIC_IP"
echo "2. Run: certbot --nginx -d $DOMAIN"
echo "3. Update firewall rules if needed"
echo "4. Configure monitoring alerts"
echo "5. Set up automated backups to Object Storage"

echo -e "\n${GREEN}🎯 Your URL shortener is now live!${NC}"