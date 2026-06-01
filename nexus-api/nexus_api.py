"""
nexus-api: FastAPI Backend - System Orchestration
=================================================
Central API for all VicChelenge System components.
No martingale. Pure orchestration.
"""

import os
import sqlite3
import json
from datetime import datetime, timedelta
from typing import Optional, List
from pydantic import BaseModel
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

# =============================================================================
# DATABASE SETUP
# =============================================================================

DB_PATH = os.environ.get("NEXUS_DB", "/tmp/nexus.db")

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db()
    c = conn.cursor()
    
    c.execute("""
        CREATE TABLE IF NOT EXISTS trades (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ticket INTEGER UNIQUE,
            symbol TEXT,
            type TEXT,
            lots REAL,
            open_price REAL,
            close_price REAL,
            sl REAL,
            tp REAL,
            profit REAL,
            comment TEXT,
            open_time TEXT,
            close_time TEXT,
            regime TEXT,
            sms_type TEXT,
            confidence REAL,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)
    
    c.execute("""
        CREATE TABLE IF NOT EXISTS metrics (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            symbol TEXT,
            date TEXT,
            balance REAL,
            equity REAL,
            drawdown REAL,
            open_trades INTEGER,
            regime TEXT,
            regime_confidence REAL,
            notes TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)
    
    c.execute("""
        CREATE TABLE IF NOT EXISTS regime_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            symbol TEXT,
            regime INTEGER,
            regime_name TEXT,
            confidence REAL,
            price REAL,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)
    
    c.execute("""
        CREATE TABLE IF NOT EXISTS events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            event_type TEXT,
            data TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)
    
    c.execute("""
        CREATE TABLE IF NOT EXISTS params (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            symbol TEXT,
            param_key TEXT,
            param_value TEXT,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)
    
    conn.commit()
    conn.close()
    print(f"[nexus-api] Database initialized at {DB_PATH}")

init_db()

# =============================================================================
# REQUEST/RESPONSE MODELS
# =============================================================================

class TradeLogRequest(BaseModel):
    ticket: int
    symbol: str = "EURUSD"
    action: str  # "OPEN", "CLOSE", "MODIFY", "CANCEL"
    type: Optional[str] = None  # "BUY", "SELL"
    lots: Optional[float] = None
    open_price: Optional[float] = None
    close_price: Optional[float] = None
    sl: Optional[float] = None
    tp: Optional[float] = None
    profit: Optional[float] = None
    comment: Optional[str] = None
    open_time: Optional[str] = None
    close_time: Optional[str] = None
    regime: Optional[str] = None
    sms_type: Optional[str] = None
    confidence: Optional[float] = None


class MetricsRequest(BaseModel):
    symbol: str = "EURUSD"
    balance: float
    equity: float
    drawdown: float
    open_trades: int = 0
    regime: Optional[str] = None
    regime_confidence: Optional[float] = None
    notes: Optional[str] = None


class RegimeUpdate(BaseModel):
    symbol: str = "EURUSD"
    regime: int
    regime_name: str
    confidence: float
    price: float


# =============================================================================
# FASTAPI APP
# =============================================================================

app = FastAPI(
    title="nexus-api",
    version="1.0",
    description="Central API for VicChelenge System"
)

# CORS for dashboard
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Health check
@app.get("/")
async def root():
    return {
        "service": "nexus-api",
        "version": "1.0",
        "status": "running",
        "endpoints": {
            "trades": "/api/v1/trades",
            "metrics": "/api/v1/metrics",
            "regime": "/api/v1/regime",
            "llm": "http://localhost:8002",
            "optimizer": "http://localhost:8003",
            "regime_ml": "http://localhost:8001"
        }
    }


@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "service": "nexus-api",
        "database": DB_PATH
    }


# =============================================================================
# TRADES ENDPOINTS
# =============================================================================

@app.post("/api/v1/trades/log")
async def log_trade(req: TradeLogRequest):
    """Log a trade event."""
    conn = get_db()
    c = conn.cursor()
    
    try:
        c.execute("""
            INSERT OR REPLACE INTO trades 
            (ticket, symbol, type, lots, open_price, close_price, sl, tp, profit, comment,
             open_time, close_time, regime, sms_type, confidence)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            req.ticket, req.symbol, req.type, req.lots, req.open_price,
            req.close_price, req.sl, req.tp, req.profit, req.comment,
            req.open_time, req.close_time, req.regime, req.sms_type, req.confidence
        ))
        
        conn.commit()
        return {"status": "ok", "ticket": req.ticket}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        conn.close()


@app.get("/api/v1/trades")
async def get_trades(
    symbol: Optional[str] = None,
    limit: int = Query(50, le=500),
    offset: int = 0
):
    """Get trade history."""
    conn = get_db()
    c = conn.cursor()
    
    where = "WHERE symbol = ?" if symbol else ""
    params = (symbol,) if symbol else ()
    
    c.execute(f"""
        SELECT * FROM trades
        {where}
        ORDER BY close_time DESC
        LIMIT ? OFFSET ?
    """, params + (limit, offset))
    
    rows = c.fetchall()
    conn.close()
    
    return {"trades": [dict(r) for r in rows], "count": len(rows)}


@app.get("/api/v1/trades/stats")
async def get_trade_stats(symbol: Optional[str] = None, days: int = 30):
    """Get trade statistics."""
    conn = get_db()
    c = conn.cursor()
    
    since = (datetime.now() - timedelta(days=days)).strftime("%Y-%m-%d")
    
    where = "WHERE symbol = ? AND close_time > ?" if symbol else "WHERE close_time > ?"
    params = (symbol, since) if symbol else (since,)
    
    c.execute(f"""
        SELECT 
            COUNT(*) as total_trades,
            SUM(CASE WHEN profit > 0 THEN 1 ELSE 0 END) as wins,
            SUM(CASE WHEN profit < 0 THEN 1 ELSE 0 END) as losses,
            SUM(profit) as net_profit,
            AVG(profit) as avg_profit,
            MAX(profit) as best_trade,
            MIN(profit) as worst_trade,
            AVG(CASE WHEN profit > 0 THEN profit ELSE 0 END) as avg_win,
            AVG(CASE WHEN profit < 0 THEN profit ELSE 0 END) as avg_loss
        FROM trades
        {where}
    """, params)
    
    row = c.fetchone()
    conn.close()
    
    if not row or row["total_trades"] == 0:
        return {"error": "No trades found"}
    
    stats = dict(row)
    stats["win_rate"] = stats["wins"] / stats["total_trades"] if stats["total_trades"] > 0 else 0
    stats["avg_win_loss_ratio"] = abs(stats["avg_win"] / stats["avg_loss"]) if stats["avg_loss"] != 0 else 0
    stats["profit_factor"] = abs(stats["avg_win"] * stats["wins"] / (stats["avg_loss"] * stats["losses"])) if stats["losses"] > 0 else 0
    
    return stats


@app.get("/api/v1/trades/recent")
async def get_recent_trades(symbol: Optional[str] = None, limit: int = 10):
    """Get recent trades."""
    conn = get_db()
    c = conn.cursor()
    
    where = "WHERE symbol = ?" if symbol else ""
    params = (symbol,) if symbol else ()
    
    c.execute(f"""
        SELECT * FROM trades
        {where}
        ORDER BY close_time DESC
        LIMIT ?
    """, params + (limit,))
    
    rows = c.fetchall()
    conn.close()
    
    return {"trades": [dict(r) for r in rows]}


# =============================================================================
# METRICS ENDPOINTS
# =============================================================================

@app.post("/api/v1/metrics")
async def log_metrics(req: MetricsRequest):
    """Log daily metrics snapshot."""
    conn = get_db()
    c = conn.cursor()
    
    today = datetime.now().strftime("%Y-%m-%d")
    
    c.execute("""
        INSERT INTO metrics (symbol, date, balance, equity, drawdown, open_trades, regime, regime_confidence, notes)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (req.symbol, today, req.balance, req.equity, req.drawdown, req.open_trades,
          req.regime, req.regime_confidence, req.notes))
    
    conn.commit()
    conn.close()
    
    return {"status": "ok"}


@app.get("/api/v1/metrics")
async def get_metrics(
    symbol: Optional[str] = None,
    days: int = 30,
    limit: int = Query(100, le=1000)
):
    """Get metrics history."""
    conn = get_db()
    c = conn.cursor()
    
    since = (datetime.now() - timedelta(days=days)).strftime("%Y-%m-%d")
    
    where = "WHERE symbol = ? AND date > ?" if symbol else "WHERE date > ?"
    params = (symbol, since) if symbol else (since,)
    
    c.execute(f"""
        SELECT * FROM metrics
        {where}
        ORDER BY date DESC
        LIMIT ?
    """, params + (limit,))
    
    rows = c.fetchall()
    conn.close()
    
    return {"metrics": [dict(r) for r in rows], "count": len(rows)}


@app.get("/api/v1/metrics/equity_curve")
async def get_equity_curve(symbol: Optional[str] = None, days: int = 30):
    """Get equity curve data for dashboard."""
    conn = get_db()
    c = conn.cursor()
    
    since = (datetime.now() - timedelta(days=days)).strftime("%Y-%m-%d")
    
    where = "WHERE symbol = ? AND date > ?" if symbol else "WHERE date > ?"
    params = (symbol, since) if symbol else (since,)
    
    c.execute(f"""
        SELECT date, equity, drawdown, regime FROM metrics
        {where}
        ORDER BY date ASC
    """, params)
    
    rows = c.fetchall()
    conn.close()
    
    return {
        "equity_curve": [
            {"date": r["date"], "equity": r["equity"], "drawdown": r["drawdown"], "regime": r["regime"]}
            for r in rows
        ]
    }


# =============================================================================
# REGIME ENDPOINTS (Proxy to nexus-regime)
# =============================================================================

@app.post("/api/v1/regime/classify")
async def classify_regime_endpoint():
    """
    Proxy to nexus-regime service.
    In production, this would call the actual service.
    """
    # For now, return a placeholder response
    return {
        "regime": 0,
        "regime_name": "TRENDING_STRONG",
        "confidence": 0.75,
        "note": "Proxy to nexus-regime (port 8001) not configured"
    }


@app.post("/api/v1/regime/update")
async def update_regime(req: RegimeUpdate):
    """Log regime changes."""
    conn = get_db()
    c = conn.cursor()
    
    c.execute("""
        INSERT INTO regime_log (symbol, regime, regime_name, confidence, price)
        VALUES (?, ?, ?, ?, ?)
    """, (req.symbol, req.regime, req.regime_name, req.confidence, req.price))
    
    conn.commit()
    conn.close()
    
    return {"status": "ok"}


@app.get("/api/v1/regime/current")
async def get_current_regime(symbol: str = "EURUSD"):
    """Get current regime from latest log."""
    conn = get_db()
    c = conn.cursor()
    
    c.execute("""
        SELECT * FROM regime_log
        WHERE symbol = ?
        ORDER BY created_at DESC
        LIMIT 1
    """, (symbol,))
    
    row = c.fetchone()
    conn.close()
    
    if not row:
        return {"regime": 6, "regime_name": "UNKNOWN", "confidence": 0.5}
    
    return dict(row)


# =============================================================================
# PARAM ENDPOINTS
# =============================================================================

@app.get("/api/v1/params")
async def get_params(symbol: str = "EURUSD"):
    """Get current parameters."""
    conn = get_db()
    c = conn.cursor()
    
    c.execute("""
        SELECT param_key, param_value FROM params
        WHERE symbol = ?
        ORDER BY param_key
    """, (symbol,))
    
    rows = c.fetchall()
    conn.close()
    
    return {"params": {r["param_key"]: r["param_value"] for r in rows}}


@app.post("/api/v1/params")
async def update_param(symbol: str, key: str, value: str):
    """Update a parameter."""
    conn = get_db()
    c = conn.cursor()
    
    c.execute("""
        INSERT OR REPLACE INTO params (symbol, param_key, param_value, updated_at)
        VALUES (?, ?, ?, ?)
    """, (symbol, key, value, datetime.now().isoformat()))
    
    conn.commit()
    conn.close()
    
    return {"status": "ok"}


# =============================================================================
# EVENTS ENDPOINTS
# =============================================================================

@app.post("/api/v1/events")
async def log_event(event_type: str, data: dict):
    """Log a system event."""
    conn = get_db()
    c = conn.cursor()
    
    c.execute("""
        INSERT INTO events (event_type, data)
        VALUES (?, ?)
    """, (event_type, json.dumps(data)))
    
    conn.commit()
    conn.close()
    
    return {"status": "ok"}


@app.get("/api/v1/events")
async def get_events(
    event_type: Optional[str] = None,
    limit: int = Query(50, le=500),
    offset: int = 0
):
    """Get system events."""
    conn = get_db()
    c = conn.cursor()
    
    where = "WHERE event_type = ?" if event_type else ""
    params = (event_type,) if event_type else ()
    
    c.execute(f"""
        SELECT * FROM events
        {where}
        ORDER BY created_at DESC
        LIMIT ? OFFSET ?
    """, params + (limit, offset))
    
    rows = c.fetchall()
    conn.close()
    
    return {"events": [dict(r) for r in rows]}


# =============================================================================
# STANDALONE RUN
# =============================================================================

if __name__ == "__main__":
    print("=== nexus-api starting on port 8000 ===")
    uvicorn.run(app, host="0.0.0.0", port=8000)