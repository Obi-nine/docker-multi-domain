#!/bin/bash
set -e

echo "🚀 Setting up Docker Multi-Domain Infrastructure..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}⚠️  .env file not found. Creating from .env.example...${NC}"
    if [ -f .env.example ]; then
        cp .env.example .env
        echo -e "${GREEN}✅ Created .env file. Please edit it with your domain and email.${NC}"
        echo -e "${YELLOW}⚠️  Run this script again after updating .env${NC}"
        exit 0
    else
        echo -e "${RED}❌ .env.example not found!${NC}"
        exit 1
    fi
fi

# Load environment variables
source .env

# Validate required variables
if [ -z "$PRIMARY_DOMAIN" ] || [ "$PRIMARY_DOMAIN" = "yourdomain.com" ]; then
    echo -e "${RED}❌ Please set PRIMARY_DOMAIN in .env file${NC}"
    exit 1
fi

if [ -z "$EMAIL" ] || [ "$EMAIL" = "admin@yourdomain.com" ]; then
    echo -e "${RED}❌ Please set EMAIL in .env file${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Environment variables loaded${NC}"
echo "   Domain: $PRIMARY_DOMAIN"
echo "   Email: $EMAIL"

# Create necessary directories
echo ""
echo "📁 Creating directory structure..."
mkdir -p nginx/conf.d
mkdir -p nginx/ssl
mkdir -p nginx/logs
mkdir -p certbot/logs
echo -e "${GREEN}✅ Directories created${NC}"

# Generate self-signed certificate for default server
echo ""
echo "🔒 Generating self-signed certificate for default server..."
if [ ! -f nginx/ssl/default.crt ] || [ ! -f nginx/ssl/default.key ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout nginx/ssl/default.key \
        -out nginx/ssl/default.crt \
        -subj "/CN=default" \
        2>/dev/null
    echo -e "${GREEN}✅ Self-signed certificate created${NC}"
else
    echo -e "${YELLOW}⚠️  Default certificate already exists, skipping...${NC}"
fi

# Start services
echo ""
echo "🐳 Starting Docker services..."
docker compose up -d

# Wait for nginx to be healthy
echo ""
echo "⏳ Waiting for nginx to be ready..."
sleep 5

if docker compose ps | grep -q "infrastructure-nginx.*Up"; then
    echo -e "${GREEN}✅ Nginx is running!${NC}"
else
    echo -e "${RED}❌ Nginx failed to start. Check logs with: docker compose logs nginx${NC}"
    exit 1
fi

# Instructions
echo ""
echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
echo "📋 Next steps:"
echo "   1. Add your first subdomain config to nginx/conf.d/"
echo "      Example: cp nginx/conf.d/example.conf nginx/conf.d/app.yourdomain.com.conf"
echo ""
echo "   2. Obtain SSL certificate:"
echo "      ./add-domain.sh app.yourdomain.com container-name:port"
echo ""
echo "   3. Your other Docker projects should include:"
echo "      networks:"
echo "        ${DOCKER_NETWORK_NAME:-infrastructure-web}:"
echo "          external: true"
echo ""
echo "📊 Check status: docker compose ps"
echo "📝 View logs: docker compose logs -f"
