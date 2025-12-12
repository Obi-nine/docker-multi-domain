# Adding Services

This guide explains how to add new services/domains to your infrastructure.

## Prerequisites

- Infrastructure is set up and running (`./setup.sh` completed)
- Your service is containerized with Docker
- DNS is pointing to your server

## Quick Start

### 1. Prepare Your Service

Your service's `docker-compose.yml` must connect to the shared network:
```yaml
services:
  myapp:
    image: myapp:latest
    # ... other config ...
    networks:
      - web  # Connect to shared network

networks:
  web:
    external: true  # Use the existing network
```

### 2. Start Your Service
```bash
cd /path/to/your/service
docker compose up -d
```

Verify it's running and on the correct network:
```bash
docker ps
docker network inspect web
```

### 3. Add Domain Configuration

Run the add-domain script:
```bash
cd /path/to/docker-multi-domain
./add-domain.sh myapp.yourdomain.com myapp:3000
```

Replace:
- `myapp.yourdomain.com` with your actual domain
- `myapp:3000` with your service name and port

The script will:
- Create nginx configuration
- Obtain SSL certificate
- Reload nginx

### 4. Verify

Visit your domain:
```bash
curl -I https://myapp.yourdomain.com
```

Check logs if issues:
```bash
docker compose logs nginx
docker logs myapp
```

## Advanced Configuration

### Custom Nginx Config

If you need custom configuration, manually create or edit the config file:
```bash
nano nginx/conf.d/myapp.yourdomain.com.conf
```

See `nginx/conf.d/example.conf` for examples.

After editing, reload nginx:
```bash
docker compose exec nginx nginx -t  # Test config
docker compose exec nginx nginx -s reload  # Reload
```

### Multiple Services on Same Domain

Edit your domain's config to route different paths to different services:
```nginx
server {
    listen 443 ssl http2;
    server_name myapp.yourdomain.com;
    
    # ... SSL config ...
    
    location / {
        proxy_pass http://frontend:3000;
    }
    
    location /api/ {
        rewrite ^/api/(.*)$ /$1 break;
        proxy_pass http://backend:8000;
    }
}
```

### WebSocket Applications

WebSocket support is included by default. For applications like Home Assistant, Socket.io, or live updates, no extra configuration needed.

### Static File Serving

To serve static files directly (faster than proxying):
```nginx
location /static/ {
    alias /var/www/static/;
    expires 30d;
    add_header Cache-Control "public, immutable";
}
```

Mount the directory in `docker-compose.yml`:
```yaml
services:
  nginx:
    volumes:
      - ./static:/var/www/static:ro
```

## Real-World Examples

### Example 1: SvelteKit Frontend + FastAPI Backend
```yaml
# your-app/docker-compose.yml
services:
  frontend:
    build: ./frontend
    networks:
      - app-internal
      - web
  
  backend:
    build: ./backend
    networks:
      - app-internal
      - web
  
  db:
    image: postgres:15
    networks:
      - app-internal  # Not exposed to web

networks:
  app-internal:
    driver: bridge
  web:
    external: true
```

Then run:
```bash
./add-domain.sh myapp.com frontend:3000
```

### Example 2: Home Assistant
```yaml
# home/docker-compose.yml
services:
  homeassistant:
    image: homeassistant/home-assistant:latest
    ports:
      - "8123:8123"
    networks:
      - web

networks:
  web:
    external: true
```

Then run:
```bash
./add-domain.sh home.yourdomain.com homeassistant:8123
```

### Example 3: MQTT Broker (WebSocket)
```yaml
# mqtt/docker-compose.yml
services:
  mosquitto:
    image: eclipse-mosquitto:latest
    ports:
      - "1883:1883"  # MQTT (local network only)
      - "9001:9001"  # WebSocket
    networks:
      - web

networks:
  web:
    external: true
```

Then run:
```bash
./add-domain.sh mqtt.yourdomain.com mosquitto:9001
```

## Troubleshooting

### Service Not Reachable

**Check if service is running:**
```bash
docker ps | grep myapp
```

**Check if on correct network:**
```bash
docker network inspect web | grep myapp
```

**Test connection from nginx container:**
```bash
docker compose exec nginx wget -O- http://myapp:3000
```

### SSL Certificate Issues

**Test certificate renewal:**
```bash
docker compose run --rm certbot renew --dry-run
```

**Check certificate expiration:**
```bash
docker compose exec nginx openssl x509 -in /etc/nginx/ssl/live/yourdomain.com/fullchain.pem -noout -dates
```

**Force certificate renewal:**
```bash
docker compose run --rm certbot renew --force-renewal
docker compose exec nginx nginx -s reload
```

### Nginx Configuration Errors

**Test configuration:**
```bash
docker compose exec nginx nginx -t
```

**View error logs:**
```bash
docker compose logs nginx
tail -f nginx/logs/error.log
```

**Common issues:**
- Missing semicolon in config file
- Service name typo
- Port mismatch
- SSL certificate path wrong

### DNS Not Resolving

**Check DNS propagation:**
```bash
dig yourdomain.com
nslookup yourdomain.com
```

**Force DNS refresh (local):**
```bash
# Linux/Mac
sudo systemd-resolve --flush-caches

# Windows
ipconfig /flushdns
```

## Security Best Practices

### 1. Don't Expose Database Ports

Only expose services that need to be accessible via web:
```yaml
services:
  db:
    image: postgres
    networks:
      - internal  # NOT web
    # No ports mapping

  backend:
    networks:
      - internal  # Can access DB
      - web       # Accessible via nginx
```

### 2. Use Environment Variables

Never hardcode secrets in docker-compose.yml:
```yaml
services:
  backend:
    environment:
      - DATABASE_URL=${DATABASE_URL}
      - SECRET_KEY=${SECRET_KEY}
    env_file:
      - .env
```

### 3. Restrict Admin Interfaces

For admin tools (pgAdmin, monitoring dashboards), consider IP restrictions:
```nginx
location /admin/ {
    allow 192.168.1.0/24;  # Your IP range
    deny all;
    
    proxy_pass http://admin:5000/;
}
```

### 4. Regular Updates

Keep images updated:
```bash
docker compose pull
docker compose up -d
```

## Removing a Domain

1. **Remove nginx config:**
```bash
   rm nginx/conf.d/yourdomain.com.conf
```

2. **Reload nginx:**
```bash
   docker compose exec nginx nginx -s reload
```

3. **Optionally revoke certificate:**
```bash
   docker compose run --rm certbot revoke --cert-path /etc/letsencrypt/live/yourdomain.com/cert.pem
   docker compose run --rm certbot delete --cert-name yourdomain.com
```

## Getting Help

- Check nginx logs: `docker compose logs nginx`
- Check certbot logs: `cat certbot/logs/letsencrypt.log`
- Test nginx config: `docker compose exec nginx nginx -t`
- Inspect network: `docker network inspect web`
