# VicChelenge System — Service Information

Detailed documentation for each microservice in the VicChelenge System.

---

## 1. nexus-api

### Purpose
The core FastAPI backend service that handles database operations, business logic, and serves as the primary API gateway for the system. All other services communicate through nexus-api for data persistence and core functionality.

### Port
- **Internal:** 8000
- **External:** api.cuancux.com

### Dependencies
- SQLite database (`/data/nexus.db`)
- File system access for data persistence
- Docker container runtime

### Key Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Service health check — returns `{"status": "healthy"}` |
| GET | `/api/v1/status` | System-wide status information |
| GET | `/api/v1/info` | API version and service information |
| POST | `/api/v1/strategies` | Create a new trading strategy |
| GET | `/api/v1/strategies` | List all strategies with pagination |
| GET | `/api/v1/strategies/{id}` | Get strategy details by ID |
| PUT | `/api/v1/strategies/{id}` | Update existing strategy |
| DELETE | `/api/v1/strategies/{id}` | Delete a strategy |
| GET | `/api/v1/backtests` | List all backtest results |
| POST | `/api/v1/backtests` | Run a backtest on a strategy |

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `NEXUS_DB` | Yes | `/data/nexus.db` | SQLite database file path |
| `TZ` | No | `UTC` | Timezone for timestamps |
| `LOG_LEVEL` | No | `INFO` | Logging verbosity |
| `HOST` | No | `0.0.0.0` | Bind host address |
| `PORT` | No | `8000` | Bind port |

### Dockerfile Considerations
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

---

## 2. nexus-regime

### Purpose
Market regime detection service that analyzes market conditions and classifies them into distinct regimes (e.g., trending, ranging, volatile, calm). This information is used by the optimizer to adjust strategy parameters based on current market conditions.

### Port
- **Internal:** 8001
- **External:** regime.cuancux.com

### Dependencies
- nexus-api (for data retrieval)
- Market data feed (internal or external)

### Key Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Service health check |
| POST | `/api/regime/detect` | Detect current market regime from provided data |
| GET | `/api/regime/current` | Get the most recent detected regime |
| GET | `/api/regime/history` | Get historical regime detections |
| GET | `/api/regime/types` | List available regime types |

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `REGIME_API_URL` | No | `http://localhost:8000` | nexus-api base URL |
| `REGIME_UPDATE_INTERVAL` | No | `60` | Seconds between regime updates |
| `TZ` | No | `UTC` | Timezone for timestamps |
| `LOG_LEVEL` | No | `INFO` | Logging verbosity |

### Regime Types
- **BULL_TREND** — Strong upward price movement
- **BEAR_TREND** — Strong downward price movement
- **SIDEWAYS** — No clear directional movement
- **HIGH_VOLATILITY** — Elevated price fluctuations
- **LOW_VOLATILITY** — Minimal price movement
- **UNKNOWN** — Insufficient data for classification

---

## 3. nexus-llm

### Purpose
OpenRouter AI integration service that leverages large language models to generate trading strategies, evaluate existing strategies, and provide natural language insights into market conditions and strategy performance.

### Port
- **Internal:** 8002
- **External:** ai.cuancux.com

### Dependencies
- nexus-api (for strategy data)
- OpenRouter API (external)

### Key Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Service health check |
| POST | `/api/llm/generate` | Generate a new trading strategy using AI |
| POST | `/api/llm/evaluate` | Evaluate a strategy and provide feedback |
| POST | `/api/llm/explain` | Explain a strategy in natural language |
| GET | `/api/llm/models` | List available OpenRouter models |
| POST | `/api/llm/chat` | General purpose chat with AI |

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `OPENROUTER_API_KEY` | **Yes** | — | OpenRouter API authentication key |
| `OPENROUTER_BASE_URL` | No | `https://openrouter.ai/api/v1` | OpenRouter API base URL |
| `LLM_MODEL` | No | `anthropic/claude-3-haiku` | Default model to use |
| `LLM_MAX_TOKENS` | No | `2048` | Maximum response tokens |
| `LLM_TEMPERATURE` | No | `0.7` | Response randomness (0.0-1.0) |
| `REGIME_API_URL` | No | `http://localhost:8000` | nexus-api base URL |
| `LOG_LEVEL` | No | `INFO` | Logging verbosity |

### OpenRouter Models
Common models available through OpenRouter:
- `anthropic/claude-3-haiku` — Fast, cost-effective
- `anthropic/claude-3-sonnet` — Balanced performance
- `openai/gpt-4-turbo` — High capability
- `google/gemini-pro` — Google's offering

---

## 4. nexus-optimizer

### Purpose
Genetic algorithm optimization service that tunes strategy parameters to maximize performance metrics (e.g., Sharpe ratio, profit factor). It evolves candidate strategies over multiple generations to find optimal configurations.

### Port
- **Internal:** 8003
- **External:** opt.cuancux.com

### Dependencies
- nexus-api (for strategy data)
- nexus-regime (for market context)

### Key Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Service health check |
| POST | `/api/optimize/start` | Start a new optimization run |
| GET | `/api/optimize/status/{run_id}` | Get current optimization status |
| GET | `/api/optimize/results/{run_id}` | Get completed optimization results |
| POST | `/api/optimize/stop` | Stop a running optimization |
| GET | `/api/optimize/population/{run_id}` | View current generation population |
| GET | `/api/optimize/history` | List past optimization runs |

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `OPTIMIZER_POPULATION_SIZE` | No | `50` | Number of candidates per generation |
| `OPTIMIZER_GENERATIONS` | No | `100` | Maximum generations to run |
| `OPTIMIZER_MUTATION_RATE` | No | `0.1` | Genetic mutation probability |
| `OPTIMIZER_CROSSOVER_RATE` | No | `0.7` | Genetic crossover probability |
| `OPTIMIZER_ELITE_COUNT` | No | `5` | Top performers preserved each generation |
| `OPTIMIZER_OBJECTIVE` | No | `sharpe_ratio` | Optimization target metric |
| `REGIME_API_URL` | No | `http://localhost:8000` | nexus-api base URL |
| `LOG_LEVEL` | No | `INFO` | Logging verbosity |

### Optimization Objectives
- `sharpe_ratio` — Risk-adjusted returns (default)
- `total_return` — Raw profit/loss percentage
- `profit_factor` — Gross profit / Gross loss
- `max_drawdown` — Minimum (lower is better)
- `win_rate` — Percentage of profitable trades

### Genetic Algorithm Parameters
| Parameter | Recommended Range | Description |
|-----------|-------------------|-------------|
| Population Size | 30-100 | Diversity of candidate solutions |
| Generations | 50-200 | Evolution time |
| Mutation Rate | 0.05-0.2 | Exploration vs exploitation |
| Crossover Rate | 0.6-0.9 | Combination of solutions |
| Elite Count | 3-10 | Survival of best performers |

---

## 5. nexus-dashboard

### Purpose
The user-facing web dashboard built with HTML, CSS, and JavaScript that provides a visual interface for monitoring all system components, viewing strategies, launching optimizations, and analyzing results.

### Port
- **Internal:** 80
- **External:** dash.cuancux.com

### Dependencies
- nexus-api (primary data source)
- nexus-regime (regime display)
- nexus-llm (strategy generation UI)
- nexus-optimizer (optimization control)

### Key Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | Main dashboard HTML page |
| GET | `/index.html` | Alternative entry point |
| GET | `/api/proxy/status` | Aggregated system status |
| GET | `/api/proxy/strategies` | List strategies via proxy |
| POST | `/api/proxy/generate` | Trigger AI strategy generation |
| GET | `/static/*` | Static assets (CSS, JS, images) |

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `API_BASE_URL` | No | `http://localhost:8000` | Backend API base URL |
| `DASHBOARD_PORT` | No | `80` | Internal container port |
| `ENABLE_PROXY` | No | `true` | Enable API proxying through dashboard |

### Dashboard Features
- **Strategy Management** — Create, edit, delete trading strategies
- **Real-time Monitoring** — Live status of all microservices
- **Optimization Control** — Start/stop/monitor optimization runs
- **Results Visualization** — Charts and metrics for strategy performance
- **Regime Display** — Current market regime indicator
- **AI Interaction** — Interface for LLM-based strategy generation

---

## Caddy Reverse Proxy

### Purpose
Automatic HTTPS reverse proxy that routes incoming traffic to the appropriate microservice based on subdomain. Handles TLS certificate provisioning and renewal via Let's Encrypt.

### Port
- **Internal:** 80 (HTTP redirect)
- **External:** 443 (HTTPS)

### Configuration File
`Caddyfile` — Located at `/opt/vicchelenge/Caddyfile` or within the Docker compose configuration.

### Routing Rules

| Domain | Destination | Description |
|--------|--------------|-------------|
| `api.cuancux.com` | `localhost:8000` | Main API service |
| `regime.cuancux.com` | `localhost:8001` | Regime detection |
| `ai.cuancux.com` | `localhost:8002` | LLM integration |
| `opt.cuancux.com` | `localhost:8003` | Optimizer service |
| `dash.cuancux.com` | `localhost:80` | Web dashboard |
| `nexus.cuancux.com` | `localhost:8000` | API alias |

### TLS Configuration
- **Provider:** Let's Encrypt (automatic)
- **Certificate Path:** `/data/caddy/certs/`
- **Renewal:** Automatic 30 days before expiration
- **Protocols:** TLS 1.2, TLS 1.3

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `CADDY_DOMAIN` | No | `cuancux.com` | Primary domain |
| `CADDY_EMAIL` | No | — | Email for certificate notifications |
| `CADDY_ADMIN_OFF` | No | `true` | Disable admin API |

---

## Database

### Type
SQLite (file-based)

### Location
`/data/nexus.db`

### Schema Overview

**strategies** table:
| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER PRIMARY KEY | Unique identifier |
| name | TEXT | Strategy name |
| description | TEXT | Strategy description |
| parameters | JSON | Strategy parameters |
| created_at | TIMESTAMP | Creation timestamp |
| updated_at | TIMESTAMP | Last update timestamp |

**optimization_runs** table:
| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER PRIMARY KEY | Unique identifier |
| strategy_id | INTEGER | Foreign key to strategies |
| status | TEXT | run status |
| best_fitness | REAL | Best fitness score |
| started_at | TIMESTAMP | Start time |
| completed_at | TIMESTAMP | Completion time |

**regime_history** table:
| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER PRIMARY KEY | Unique identifier |
| regime_type | TEXT | Regime classification |
| confidence | REAL | Detection confidence |
| detected_at | TIMESTAMP | Detection timestamp |

### Backup
```bash
cp /data/nexus.db /opt/backups/nexus_$(date +%Y%m%d).db
```