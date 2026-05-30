# VicChelenge System — Deployment Guide

## Overview

The VicChelenge System is a modular trading strategy optimization platform composed of multiple microservices that work together to analyze market regimes, generate trading strategies using AI, and optimize them via genetic algorithms. The system exposes a unified dashboard for monitoring and control.

**Core Components:**
- **nexus-api** (Port 8000) — FastAPI backend handling core business logic and SQLite database management
- **nexus-regime** (Port 8001) — Market regime detection service for identifying market conditions
- **nexus-llm** (Port 8002) — OpenRouter AI integration for strategy generation
- **nexus-optimizer** (Port 8003) — Genetic algorithm optimizer for strategy parameter tuning
- **nexus-dashboard** (Port 80) — HTML/JS frontend for user interaction
- **Caddy** — Reverse proxy with automatic HTTPS for all services

## Prerequisites

- **Contabo VPS** with minimum 4 CPU cores, 8GB RAM, and 80GB SSD
- **Domain** configured with DNS A records for all subdomains (cuancux.com)
- **Coolify** installed on the VPS (self-hosted deployment platform)
- **GitHub account** with access to the repository: https://github.com/Lybeedo/public-omon-omon
- **SSH key** configured on the VPS for GitHub access
- **Docker** and **Docker Compose** available on the VPS (via Coolify)

## Architecture

```
                                    ┌─────────────────────────────────────────┐
                                    │           Contabo VPS                   │
                                    │                                         │
   Internet ───► Caddy ─────────────┼────────────────────────────────────   │
   (HTTPS :443)     Reverse Proxy    │   ┌────────────┐  ┌────────────┐      │
                                    │   │  nexus-api │  │nexus-regime│      │
                                    │   │  :8000     │  │  :8001     │      │
                                    │   └─────┬──────┘  └─────┬──────┘      │
                                    │         │                │             │
   Domain Routing ──────────────────┼─────────┼────────────────┤             │
   api.cuancux.com ───────────────► │    ┌───┴────────────────┘             │
   regime.cuancux.com ────────────► │    │                                  │
   ai.cuancux.com ─────────────────► │    │   ┌────────────┐  ┌────────────┐│
   opt.cuancux.com ─────────────────► │    └──►│  nexus-llm │  │nexus-optimizer│
   dash.cuancux.com ───────────────► │        │  :8002     │  │  :8003     ││
   nexus.cuancux.com ───────────────► │        └────────────┘  └────────────┘│
                                    │                                         │
                                    │        ┌─────────────────────┐        │
                                    │        │  nexus-dashboard    │        │
                                    │        │  :80 (internal)     │        │
                                    │        └─────────────────────┘        │
                                    │                                         │
                                    │        ┌─────────────────────┐        │
                                    │        │  SQLite Database    │        │
                                    │        │  /data/nexus.db     │        │
                                    │        └─────────────────────┘        │
                                    └─────────────────────────────────────────┘
```

## Step-by-Step Deployment

### Step 1: Prepare Contabo VPS

**OS Requirements:**
- Ubuntu 22.04 LTS (recommended) or 20.04 LTS
- Fresh installation with root access
- Minimum 4 vCPU, 8GB RAM, 80GB SSD

**Install Coolify:**
```bash
# SSH into your VPS as root
ssh root@your-vps-ip

# Run the official Coolify installer
curl -fsSL https://get.coolify.io | bash

# Coolify will be available at https://your-vps-ip:3000
# Follow the initial setup wizard to create your admin account
```

**Configure Firewall:**
```bash
# Allow HTTP and HTTPS traffic
ufw allow 80/tcp
ufw allow 443/tcp

# Allow SSH
ufw allow 22/tcp

# Enable firewall
ufw enable

# Verify status
ufw status
```

### Step 2: Connect GitHub Repo to Coolify

**Fork/Clone the Repository:**
1. Navigate to: https://github.com/Lybeedo/public-omon-omon
2. Fork the repository to your GitHub account
3. Note the clone URL for use in Coolify

**Add Repository to Coolify:**
1. Log in to Coolify at `https://your-vps-ip:3000`
2. Navigate to **Sources** → **Add New Source** → **GitHub**
3. Authenticate with your GitHub account
4. Grant repository access to Coolify

**Create New Project:**
1. Go to **Projects** → **Create New Project**
2. Name it "VicChelenge System"
3. Click **Add New Resource** → **Application**
4. Select your forked repository
5. Configure the following:
   - **Branch:** `vicchelenge/v1`
   - **Build Pack:** Docker (or Auto-detect)
   - **Port:** 8000 (for nexus-api)

### Step 3: Configure Environment Variables

Create the following environment variables in Coolify for each service:

| Variable | Description | Example |
|----------|-------------|---------|
| `OPENROUTER_API_KEY` | OpenRouter API key for AI model access | `sk-or-v1-xxxxxxxxxxxxxxxx` |
| `NEXUS_DB` | SQLite database file path | `/data/nexus.db` |
| `TZ` | Server timezone (UTC recommended) | `UTC` |
| `LOG_LEVEL` | Application logging level | `INFO` |
| `CADDY_DOMAIN` | Primary domain for Caddy | `cuancux.com` |
| `API_BASE_URL` | Base URL for API service | `http://localhost:8000` |

**Setting Environment Variables in Coolify:**
1. Select your deployed application
2. Navigate to **Environment Variables**
3. Add each variable with its value
4. Redeploy the application for changes to take effect

### Step 4: Deploy Services

Deploy each service individually in Coolify. Repeat the process for each component:

**1. nexus-api (Port 8000)**
- Main FastAPI backend service
- Handles database operations and core API logic
- Health endpoint: `http://localhost:8000/health`

**2. nexus-regime (Port 8001)**
- Market regime detection and classification
- Depends on: nexus-api
- Health endpoint: `http://localhost:8001/health`

**3. nexus-llm (Port 8002)**
- OpenRouter AI integration for strategy generation
- Depends on: nexus-api
- Requires: `OPENROUTER_API_KEY`
- Health endpoint: `http://localhost:8002/health`

**4. nexus-optimizer (Port 8003)**
- Genetic algorithm for parameter optimization
- Depends on: nexus-api, nexus-regime
- Health endpoint: `http://localhost:8003/health`

**5. nexus-dashboard (Port 80)**
- Static HTML/JS frontend
- Internal port maps to 80 for Caddy routing
- Access via: `http://localhost:80` (internal) or `dash.cuancux.com` (external)

**Deployment Process for Each Service:**
1. In Coolify, go to your project → **Add New Resource** → **Application**
2. Select the repository and branch `vicchelenge/v1`
3. Set the service name (e.g., "nexus-api")
4. Configure the Dockerfile path if not in root
5. Set the exposed port
6. Add environment variables
7. Click **Deploy**

### Step 5: Configure Caddy Reverse Proxy

Caddy handles automatic HTTPS and routes traffic to each service based on subdomain.

**Caddyfile Configuration:**
```caddy
# Global configuration
{
    email admin@cuancux.com
    admin off
}

# Main API
api.cuancux.com {
    reverse_proxy localhost:8000
    handle_path /ws/* {
        reverse_proxy localhost:8000
    }
}

# Market Regime Detection
regime.cuancux.com {
    reverse_proxy localhost:8001
}

# AI/LLM Service
ai.cuancux.com {
    reverse_proxy localhost:8002
}

# Optimizer Service
opt.cuancux.com {
    reverse_proxy localhost:8003
}

# Dashboard
dash.cuancux.com {
    reverse_proxy localhost:80
}

# Legacy domain alias
nexus.cuancux.com {
    reverse_proxy localhost:8000
}
```

**Auto HTTPS Setup:**
- Caddy automatically provisions TLS certificates via Let's Encrypt
- Certificate files are stored in `/data/caddy/certs/`
- Automatic renewal occurs 30 days before expiration

**DNS Configuration:**
Ensure the following A records are set in your DNS provider:
```
A  api.cuancux.com      → your-vps-ip
A  regime.cuancux.com   → your-vps-ip
A  ai.cuancux.com        → your-vps-ip
A  opt.cuancux.com       → your-vps-ip
A  dash.cuancux.com      → your-vps-ip
A  nexus.cuancux.com     → your-vps-ip
```

### Step 6: Verify Deployment

**Health Check Endpoints:**
```bash
# Check each service individually
curl http://localhost:8000/health
curl http://localhost:8001/health
curl http://localhost:8002/health
curl http://localhost:8003/health

# Expected response: {"status": "healthy"} or similar JSON
```

**Docker Compose Validation:**
```bash
# Navigate to deployment directory
cd /opt/vicchelenge

# Validate compose file
docker compose -f deploy/docker-compose.yml config

# View service status
docker compose -f deploy/docker-compose.yml ps
```

**Dashboard Access:**
1. Open browser to `https://dash.cuancux.com`
2. Verify TLS certificate is valid (green padlock)
3. Confirm dashboard loads without errors

**System-wide Health Check:**
Run the provided quickstart script:
```bash
chmod +x deploy/QUICKSTART.sh
./deploy/QUICKSTART.sh
```

## Service Endpoints

| Service | Port | Domain | Endpoint | Description |
|---------|------|--------|----------|-------------|
| nexus-api | 8000 | api.cuancux.com | /health | Core API health check |
| nexus-api | 8000 | api.cuancux.com | /api/v1/* | Main API endpoints |
| nexus-regime | 8001 | regime.cuancux.com | /health | Regime detection health |
| nexus-regime | 8001 | regime.cuancux.com | /api/regime/* | Regime analysis endpoints |
| nexus-llm | 8002 | ai.cuancux.com | /health | LLM service health |
| nexus-llm | 8002 | ai.cuancux.com | /api/llm/* | AI strategy generation |
| nexus-optimizer | 8003 | opt.cuancux.com | /health | Optimizer health |
| nexus-optimizer | 8003 | opt.cuancux.com | /api/optimize/* | Parameter optimization |
| nexus-dashboard | 80 | dash.cuancux.com | / | Main dashboard UI |
| nexus-dashboard | 80 | dash.cuancux.com | /api/* | Dashboard API proxy |

## Troubleshooting

### Health Check Failing

**Symptoms:** Service returns non-200 status or connection refused.

**Solutions:**
1. Check if container is running:
   ```bash
   docker ps | grep nexus-
   ```
2. View container logs:
   ```bash
   docker logs <container_name>
   ```
3. Verify port binding:
   ```bash
   netstat -tlnp | grep <port>
   ```
4. Restart the service in Coolify dashboard

### CORS Errors

**Symptoms:** Browser console shows CORS policy errors.

**Solutions:**
1. Verify CORS origins are configured in nexus-api
2. Check that reverse proxy sends proper CORS headers
3. Ensure frontend URL matches allowed origins:
   ```
   CORS_ORIGINS=https://dash.cuancux.com
   ```
4. Clear browser cache and retry

### OpenRouter API Errors

**Symptoms:** AI endpoints return 500 or 502 errors.

**Solutions:**
1. Verify `OPENROUTER_API_KEY` is set correctly
2. Check API key has sufficient credits at openrouter.ai
3. Test API key directly:
   ```bash
   curl https://openrouter.ai/api/v1/models \
     -H "Authorization: Bearer $OPENROUTER_API_KEY"
   ```
4. Check rate limits and quotas

### Database Permission Issues

**Symptoms:** "Permission denied" errors when accessing SQLite database.

**Solutions:**
1. Verify database file ownership:
   ```bash
   ls -la /data/nexus.db
   ```
2. Fix permissions:
   ```bash
   chown 1000:1000 /data/nexus.db
   chmod 644 /data/nexus.db
   ```
3. Check directory permissions:
   ```bash
   chmod 755 /data
   ```
4. Ensure Docker user has write access to parent directory

## API Reference

### nexus-api (Core API)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Service health check |
| GET | `/api/v1/status` | System status |
| POST | `/api/v1/strategies` | Create new strategy |
| GET | `/api/v1/strategies` | List all strategies |
| GET | `/api/v1/strategies/{id}` | Get strategy by ID |
| PUT | `/api/v1/strategies/{id}` | Update strategy |
| DELETE | `/api/v1/strategies/{id}` | Delete strategy |

### nexus-regime (Market Regime)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Service health check |
| POST | `/api/regime/detect` | Detect current market regime |
| GET | `/api/regime/history` | Get regime detection history |

### nexus-llm (AI Integration)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Service health check |
| POST | `/api/llm/generate` | Generate strategy using AI |
| POST | `/api/llm/evaluate` | Evaluate strategy with AI |
| GET | `/api/llm/models` | List available models |

### nexus-optimizer (Genetic Algorithm)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Service health check |
| POST | `/api/optimize/start` | Start optimization run |
| GET | `/api/optimize/status/{run_id}` | Get optimization status |
| GET | `/api/optimize/results/{run_id}` | Get optimization results |
| POST | `/api/optimize/stop` | Stop running optimization |

## Maintenance

### Updating Services

**Via Coolify Dashboard:**
1. Navigate to your application in Coolify
2. Click **Redeploy** or push to the configured branch
3. Coolify will automatically rebuild and deploy

**Manual Update:**
```bash
cd /opt/vicchelenge
git pull origin vicchelenge/v1
docker compose -f deploy/docker-compose.yml up -d --build
```

### Backup Database

**Automated Backup Script:**
```bash
#!/bin/bash
# Save as /opt/vicchelenge/backup.sh
BACKUP_DIR="/opt/backups"
DATE=$(date +%Y%m%d_%H%M%S)
DB_PATH="/data/nexus.db"

mkdir -p $BACKUP_DIR
cp $DB_PATH $BACKUP_DIR/nexus_$DATE.db
find $BACKUP_DIR -name "nexus_*.db" -mtime +7 -delete
echo "Backup created: nexus_$DATE.db"
```

**Restore from Backup:**
```bash
# Stop services
docker compose -f deploy/docker-compose.yml down

# Restore database
cp /opt/backups/nexus_YYYYMMDD_HHMMSS.db /data/nexus.db

# Restart services
docker compose -f deploy/docker-compose.yml up -d
```

### Monitoring Logs

**View All Service Logs:**
```bash
docker compose -f deploy/docker-compose.yml logs -f
```

**View Specific Service Logs:**
```bash
docker logs -f nexus-api
docker logs -f nexus-regime
docker logs -f nexus-llm
docker logs -f nexus-optimizer
```

**Coolify Built-in Logs:**
1. Navigate to your application in Coolify
2. Click on the deployment
3. View real-time logs in the dashboard

**Log Rotation:**
Configure log rotation in `/etc/docker/daemon.json`:
```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

---

For additional support, review the repository at: https://github.com/Lybeedo/public-omon-omon