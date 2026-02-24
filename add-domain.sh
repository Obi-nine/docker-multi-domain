#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check arguments
if [ $# -lt 2 ]; then
    echo -e "${RED}❌ Usage: ./add-domain.sh <domain> <service:port>${NC}"
    echo ""
    echo "Examples:"
    echo "  ./add-domain.sh app.yourdomain.com backend:8000"
    echo "  ./add-domain.sh yourdomain.com frontend:3000"
    echo ""
    exit 1
fi

DOMAIN=$1
SERVICE=$2

# Load environment variables
if [ ! -f .env ]; then
    echo -e "${RED}❌ .env file not found. Run ./setup.sh first${NC}"
    exit 1
fi
source .env

echo -e "${BLUE}🌐 Adding domain: $DOMAIN${NC}"
echo -e "${BLUE}📡 Service: $SERVICE${NC}"
echo ""

# Check if config already exists
CONFIG_FILE="nginx/conf.d/${DOMAIN}.conf"
if [ -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}⚠️  Configuration for $DOMAIN already exists${NC}"
    read -p "Overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Aborted${NC}"
        exit 0
    fi
fi

# Create nginx config
echo "📝 Creating nginx configuration..."
cat > "$CONFIG_FILE" << EOF
server {
    listen 443 ssl http2;
    server_name ${DOMAIN};

    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

    # HSTS
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Proxy to Docker service
    location / {
        proxy_pass http://${SERVICE};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$server_name;

        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

echo -e "${GREEN}✅ Nginx configuration created${NC}"

# Obtain SSL certificate
echo ""
echo "🔒 Obtaining SSL certificate..."

# Check if this is a dry run or production
if [ "${CERTBOT_STAGING:-0}" = "1" ]; then
    STAGING_FLAG="--staging"
    echo -e "${YELLOW}⚠️  Using Let's Encrypt staging server (test mode)${NC}"
else
    STAGING_FLAG=""
fi

# Run certbot
docker compose run --rm certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email ${EMAIL} \
    --agree-tos \
    --no-eff-email \
    ${STAGING_FLAG} \
    -d ${DOMAIN}

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ SSL certificate obtained${NC}"
else
    echo -e "${RED}❌ Failed to obtain SSL certificate${NC}"
    echo -e "${YELLOW}⚠️  Check that:${NC}"
    echo "   - DNS is pointing to this server"
    echo "   - Port 80 is accessible"
    echo "   - Domain is spelled correctly"
    exit 1
fi

# Test nginx configuration
echo ""
echo "🧪 Testing nginx configuration..."
if docker compose exec nginx nginx -t 2>/dev/null; then
    echo -e "${GREEN}✅ Nginx configuration is valid${NC}"
else
    echo -e "${RED}❌ Nginx configuration test failed${NC}"
    echo -e "${YELLOW}Rolling back...${NC}"
    rm "$CONFIG_FILE"
    exit 1
fi

# Reload nginx
echo ""
echo "🔄 Reloading nginx..."
docker compose exec nginx nginx -s reload

echo ""
echo -e "${GREEN}✅ Domain $DOMAIN configured successfully!${NC}"
echo ""
echo "📋 Next steps:"
echo "   1. Ensure your service '$SERVICE' is running"
echo "   2. Ensure it's connected to the '${DOCKER_NETWORK_NAME:-web}' network"
echo "   3. Visit https://${DOMAIN} to test"
echo ""
echo "🔍 Troubleshooting:"
echo "   - Check service: docker ps"
echo "   - Check nginx logs: docker compose logs nginx"
echo "   - Test connection: curl -I https://${DOMAIN}"
