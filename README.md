# Docker Multi-Domain Infrastructure

A lightweight nginx-based infrastructure for hosting multiple Docker projects on a single server with automatic SSL and subdomain routing.

## Problem It Solves

Running multiple web applications on one server typically requires:
- Managing complex nginx configurations
- Handling SSL certificates for each domain
- Configuring Docker networks manually
- Repeating the same setup for each new project

This infrastructure simplifies that into a single shared reverse proxy that routes traffic based on subdomains.

## Features

- 🔒 Automatic SSL with Let's Encrypt
- 🌐 Easy subdomain routing (app1.yourdomain.com, app2.yourdomain.com)
- 🐳 Shared Docker network for service discovery
- 📝 Modular nginx configs (one file per subdomain)
- 🔄 Zero-downtime configuration reloads
- 🛡️ Production-ready security headers

## Use Cases

Perfect for hobbyists and small projects running:
- Personal websites + APIs
- Home automation (Home Assistant, MQTT)
- Development tools (Git server, CI/CD)
- Multiple client projects on one VPS

## Quick Start

- Create custom .env file from tempalte
- Run setup.sh  
- Run add-domain.sh ./add-domain.sh examle.com frontend:3000 


## Architecture

Coming soon...

## License

MIT
