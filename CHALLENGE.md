# VicChelenge System - Challenge Rules & Grading Rubric

## Challenge Name: VicChelenge System
## Challenge Edition: v1.0
## Target: Coder Senior / Full-Stack Developer

---

## System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    VICCHELENGE SYSTEM                        │
│              "Out of the Box" AI Trading Engine              │
└─────────────────────────────────────────────────────────────┘
      │
      ├── nexus-core    (MT4 EA - MQL4)
      ├── nexus-regime  (Python - Regime Detection)
      ├── nexus-llm     (Python - OpenRouter AI)
      ├── nexus-api     (Python - FastAPI Backend)
      ├── nexus-optimizer (Python - Genetic Algorithm)
      ├── nexus-dashboard (React/HTML - Web Monitor)
      └── deploy        (Docker + Coolify)
```

**NO MARTINGALE. NO GRID. NO GAMBLE.**
**PURE INSTITUTIONAL FLOW + ADAPTIVE AI.**

---

## Challenge Levels

### Level 1: EA Developer (MT4/MT5)
Build / improve `nexus-core.nexus-mq4`

### Level 2: Backend Developer (Python)
Build / improve `nexus-regime` or `nexus-api`

### Level 3: AI/ML Engineer
Build / improve `nexus-llm` or `nexus-optimizer`

### Level 4: Frontend Developer
Build / improve `nexus-dashboard`

### Level 5: DevOps / Full-Stack
Deploy the entire system on Coolify + Contabo VPS

---

## Rules

### 1. Submission
- Fork repo, create branch: `challenge/{your-name}`
- Submit via PR to main repo
- Deadline: Check group thread #777
- All code must be original (no copy-paste from internet)

### 2. Evaluation
- Points awarded per level
- Bonus points for cross-level contributions
- Passing grade: 60 pts per level

### 3. Deployment
- System must run on Contabo VPS via Coolify
- Docker Compose must pass `docker compose config`
- All services must pass health checks

---

## Grading Per Component

### nexus-core (EA) - 100 pts

| Category | Points | Criteria |
|---|---|---|
| SMS Detection | 25 | Order Blocks, FVGs, Liquidity Sweeps working |
| Regime Integration | 20 | API calls to nexus-regime functional |
| Signal Generation | 20 | At least 3 regime-based strategies |
| Risk Management | 25 | ATR-based sizing, drawdown guard, breakeven |
| Code Quality | 10 | Clean OOP, well-commented, no magic numbers |

### nexus-regime - 80 pts

| Category | Points | Criteria |
|---|---|---|
| Regime Classification | 30 | At least 6 regime states |
| API Endpoint | 20 | /classify endpoint working |
| Confidence Scoring | 15 | Multi-factor confidence output |
| Strategy Recommendations | 15 | Per-regime strategy advice |

### nexus-llm - 80 pts

| Category | Points | Criteria |
|---|---|---|
| OpenRouter Integration | 25 | API key handling, error handling |
| Market Analysis | 20 | /analyze endpoint working |
| Insight Generation | 15 | /insight endpoint concise & actionable |
| Strategy Review | 10 | /review endpoint with suggestions |
| Prompt Engineering | 10 | Good prompts, bank trader persona |

### nexus-api - 80 pts

| Category | Points | Criteria |
|---|---|---|
| Trade Logging | 20 | POST /trades/log working |
| Metrics API | 20 | GET /metrics and equity curve |
| Trade Stats | 15 | /trades/stats with win rate, PF |
| Regime Logging | 10 | /regime/update and /current |
| Database | 15 | SQLite persistence, no data loss |

### nexus-optimizer - 80 pts

| Category | Points | Criteria |
|---|---|---|
| Genetic Algorithm | 25 | Population, crossover, mutation |
| Fitness Function | 20 | Multi-objective (WR, PF, DD, Sharpe) |
| Hall of Fame | 15 | Best params tracked |
| API Integration | 10 | /evolve endpoint working |
| Parameter Space | 10 | All EA params covered |

### nexus-dashboard - 80 pts

| Category | Points | Criteria |
|---|---|---|
| Equity Curve | 20 | Canvas chart rendering |
| Trade Table | 15 | Recent trades display |
| Regime Display | 15 | Visual regime badge |
| AI Insights Feed | 15 | LLM response display |
| Responsiveness | 15 | Mobile-friendly layout |

### Deploy (DevOps) - 80 pts

| Category | Points | Criteria |
|---|---|---|
| Docker Compose | 20 | All services defined |
| Health Checks | 15 | All services have checks |
| Environment Vars | 10 | .env.example + handling |
| Reverse Proxy | 15 | Caddy/Traefik config |
| Coolify Integration | 20 | Deploy via Coolify UI |

---

## Bonus Points

| Bonus | Pts | Description |
|---|---|---|
| WebSocket Real-time | +10 | Live updates without polling |
| Backtest Automation | +10 | EA auto-backtest via API |
| Custom SMS Algorithm | +10 | Your own OB/FVG detection logic |
| LLM Strategy Evolution | +10 | LLM suggests param changes |
| Multi-Symbol Support | +10 | EA trades EURUSD + GBPUSD |
| Volume Profile | +10 | POC / VAH / VAL detection |
| Order Flow Delta | +10 | Real tick volume analysis |
| Walk-Forward Analysis | +10 | Genetic optimizer runs auto |

---

## Key Pitfalls (Auto-Fail)

```
[ ] HARDCODED LOT         --> MUST use risk-based sizing
[ ] NO SL/TP             --> EVERY trade MUST have SL and TP
[ ] NO SPREAD CHECK      --> Wide spreads = slippage losses
[ ] NO TREND FILTER      --> Counter-trend trades destroy equity
[ ] NO DRAWDOWN GUARD    --> One bad streak = account wipeout
[ ] NO NEWS FILTER       --> High-impact events = gaps
[ ] SAME-BAR RE-ENTRY    --> Need bar-time check
[ ] MEMORY LEAKS         --> All new objects delete in OnDeinit
[ ] NO ERROR HANDLING    --> OrderSend failures must be caught
[ ] API KEY IN CODE      --> Keys must be in env vars only
[ ] NO HEALTH CHECKS     --> Docker healthchecks missing
[ ] COPY-PASTE CODE      --> Must be original implementation
```

---

## System Architecture

### Data Flow

```
MT4 Terminal
    │
    ├── OnTick() → nexus-core EA
    │              │
    │              ├── Detect SMS (OB/FVG/Liquidity)
    │              ├── Get Regime ← HTTP → nexus-regime:8001
    │              ├── Generate Signal (regime-adaptive)
    │              └── Open Order → MT4 Server
    │
    └── Every 30s → nexus-api:8000
                      │
                      ├── Log Trade
                      ├── Log Metrics
                      │
                      ← nexus-dashboard:3000 (polling)
                      │
                      ← nexus-llm:8002 (on-demand insights)
```

### Ports

| Service | Port | Description |
|---|---|---|
| nexus-api | 8000 | Central API + DB |
| nexus-regime | 8001 | Regime classification |
| nexus-llm | 8002 | OpenRouter AI |
| nexus-optimizer | 8003 | Genetic algorithm |
| nexus-dashboard | 3000 | Web UI (via nginx) |
| Caddy | 80/443 | Reverse proxy |

---

## Environment Variables

Create `.env` file:

```bash
# OpenRouter API Key (get from openrouter.ai)
OPENROUTER_API_KEY=sk-or-v1-xxxxx

# Database path
NEXUS_DB=/data/nexus.db

# Timezone
TZ=UTC
```

---

## Getting Started

### 1. Clone & Setup

```bash
git clone https://github.com/cuancux/VicChelenge-System
cd VicChelenge-System
cp .env.example .env
# Edit .env with your OpenRouter API key
```

### 2. Local Development

```bash
cd nexus-api && pip install -r requirements.txt && python nexus_api.py &
cd nexus-regime && pip install -r requirements.txt && python nexus_regime.py &
cd nexus-llm && pip install -r requirements.txt && python nexus_llm.py &
cd nexus-optimizer && pip install -r requirements.txt && python nexus_optimizer.py &
```

### 3. Deploy on Coolify

```
1. Login to Coolify dashboard
2. Create new application
3. Connect GitHub repo
4. Set environment variables (OPENROUTER_API_KEY)
5. Deploy via docker-compose
```

### 4. Load EA in MT4

```
1. Copy nexus-core.nexus-mq4 to MT4/MQL4/Experts/
2. Compile in MetaEditor (F7)
3. Attach to chart
4. Configure inputs (API URL = your VPS IP)
5. Enable API in inputs
```

---

## Scoring

| Total Points | Grade | Label |
|---|---|---|
| 90-100 | A+ | Sangat Superior |
| 80-89 | A | Superior |
| 70-79 | B | Baik |
| 60-69 | C | Cukup |
| < 60 | D | Perlu Perbaikan |

---

## Leaderboard

Peringkat di umumkan di grup setiap akhir bulan.
Top 3 akan mendapat:
- Code review personal dari admin
- Free API key OpenRouter (1 bulan)
- Badge "VicChelenge Master"

---

*Challenge by Cuancux Algo Traders - May 2026*
*"Think Out of the Box"*