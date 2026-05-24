"""
nexus-regime: Market Regime Detection Engine
============================================
Machine learning-based market state classification.
No martingale. No grid. Pure adaptive intelligence.
"""

from pydantic import BaseModel
from fastapi import FastAPI
from typing import Literal
import numpy as np
import uvicorn

# =============================================================================
# REGIME DEFINITIONS
# =============================================================================

REGIME_STATES = {
    0: "TRENDING_STRONG",   # ADX > 25, EMA aligned, high volume
    1: "TRENDING_WEAK",     # ADX 15-25, EMA diverging
    2: "RANGING",           # ADX < 15, MA sandwiched
    3: "VOLATILE",          # ATR > 2x moving average
    4: "LOW_VOLUME",        # Volume < 50% average
    5: "BREAKOUT",          # Pump & dump pattern
    6: "UNKNOWN"
}


class MarketFeatures(BaseModel):
    symbol: str = "EURUSD"
    tf: str = "H4"
    adx: float
    atr: float
    atr_ma: float
    rsi: float
    volume_ratio: float
    ema_fast: float
    ema_slow: float
    price: float
    high_20: float
    low_20: float
    close_prices: list[float] = []


class RegimeResponse(BaseModel):
    regime: int
    regime_name: str
    confidence: float
    features: dict
    strategy_recommendation: str
    position_sizing: str
    risk_adjustment: float


# =============================================================================
# REGIME CLASSIFIER
# =============================================================================

class RegimeClassifier:
    """
    Custom regime classifier based on technical indicators.
    No ML model needed — rule-based with weighted scoring.
    """
    
    def classify(self, f: MarketFeatures) -> RegimeResponse:
        scores = {}
        
        # === TRENDING STRONG (0) ===
        trend_score = 0.0
        if f.adx > 30:
            trend_score += 0.4
        elif f.adx > 25:
            trend_score += 0.3
        else:
            trend_score += 0.0
            
        # EMA alignment
        if f.ema_fast > f.ema_slow:
            trend_score += 0.3  # Bullish alignment
        else:
            trend_score += 0.3  # Bearish alignment
            
        # Volume confirmation
        if f.volume_ratio > 1.2:
            trend_score += 0.3
        elif f.volume_ratio > 0.8:
            trend_score += 0.1
        
        scores[0] = min(trend_score, 1.0)
        
        # === TRENDING WEAK (1) ===
        weak_score = 0.0
        if 15 <= f.adx <= 25:
            weak_score += 0.4
        if 0.8 <= f.volume_ratio <= 1.2:
            weak_score += 0.3
        # EMA diverging
        ema_dev = abs(f.price - f.ema_slow) / f.ema_slow
        if 0.002 < ema_dev < 0.01:
            weak_score += 0.3
        scores[1] = min(weak_score, 1.0)
        
        # === RANGING (2) ===
        range_score = 0.0
        if f.adx < 15:
            range_score += 0.4
        range_width = (f.high_20 - f.low_20) / f.price
        if range_width < 0.015:  # Price in tight range
            range_score += 0.3
        if f.volume_ratio < 0.8:
            range_score += 0.3
        scores[2] = min(range_score, 1.0)
        
        # === VOLATILE (3) ===
        vol_score = 0.0
        if f.atr > f.atr_ma * 2.0:
            vol_score += 0.5
        elif f.atr > f.atr_ma * 1.5:
            vol_score += 0.3
        if f.adx > 30:
            vol_score += 0.2
        if f.volume_ratio > 1.5:
            vol_score += 0.3
        scores[3] = min(vol_score, 1.0)
        
        # === LOW VOLUME (4) ===
        lv_score = 0.0
        if f.volume_ratio < 0.5:
            lv_score += 0.5
        if f.adx < 15:
            lv_score += 0.3
        if f.atr < f.atr_ma * 0.8:
            lv_score += 0.2
        scores[4] = min(lv_score, 1.0)
        
        # === BREAKOUT (5) ===
        br_score = 0.0
        # Recent price momentum
        if len(f.close_prices) >= 5:
            recent_moves = [abs(f.close_prices[i] - f.close_prices[i+1]) / f.close_prices[i+1] 
                           for i in range(len(f.close_prices)-1)]
            avg_move = np.mean(recent_moves)
            max_move = np.max(recent_moves)
            if max_move > avg_move * 3:
                br_score += 0.5
        if f.volume_ratio > 2.0:
            br_score += 0.3
        if f.adx > 35:
            br_score += 0.2
        scores[5] = min(br_score, 1.0)
        
        # === SELECT WINNING REGIME ===
        regime_id = max(scores, key=scores.get)
        confidence = scores[regime_id]
        
        # Secondary signal if confidence is low
        if confidence < 0.4:
            regime_id = 6  # UNKNOWN
            confidence = 0.5
        
        # Strategy recommendation based on regime
        recs = {
            0: "Ride trend. Add on pullback. Trail SL aggressively.",
            1: "Small entries only. Tight SL. Avoid averaging.",
            2: "Mean reversion at SR levels. Small sizing.",
            3: "Reduce size 50%. Widen SL. Wait for stabilization.",
            4: "Sit out or micro entries only.",
            5: "Avoid chasing. Wait for retest before entry.",
            6: "Ultra-conservative. Skip or micro lots only."
        }
        
        # Position sizing recommendation
        sizing = {
            0: "Full risk (1-2%) — high conviction",
            1: "Reduced (0.5-1%) — lower conviction",
            2: "Small (0.25-0.5%) — SR play",
            3: "Micro (0.1-0.25%) — high volatility",
            4: "Avoid or micro (<0.1%)",
            5: "Medium (0.5%) — wait retest",
            6: "Ultra-micro (<0.1%) or skip"
        }
        
        # Risk adjustment multiplier
        risk_adj = {
            0: 1.0,
            1: 0.7,
            2: 0.5,
            3: 0.3,
            4: 0.1,
            5: 0.5,
            6: 0.2
        }
        
        return RegimeResponse(
            regime=regime_id,
            regime_name=REGIME_STATES[regime_id],
            confidence=round(confidence, 3),
            features={
                "adx": f.adx,
                "atr_ratio": round(f.atr / f.atr_ma, 3) if f.atr_ma > 0 else 0,
                "volume_ratio": f.volume_ratio,
                "rsi": f.rsi,
                "ema_deviation": round(abs(f.price - f.ema_slow) / f.ema_slow, 5),
                "scores": {REGIME_STATES[k]: round(v, 3) for k, v in scores.items()}
            },
            strategy_recommendation=recs[regime_id],
            position_sizing=sizing[regime_id],
            risk_adjustment=risk_adj[regime_id]
        )


# =============================================================================
# FASTAPI APP
# =============================================================================

app = FastAPI(title="nexus-regime", version="1.0")
classifier = RegimeClassifier()


@app.get("/")
async def root():
    return {
        "service": "nexus-regime",
        "version": "1.0",
        "status": "running",
        "description": "Market Regime Detection Engine - VicChelenge System"
    }


@app.get("/health")
async def health():
    return {"status": "healthy", "service": "nexus-regime"}


@app.post("/api/v1/regime/classify", response_model=RegimeResponse)
async def classify_regime(features: MarketFeatures):
    """
    Classify market regime based on technical features.
    
    Features needed:
    - adx: ADX indicator value
    - atr: Current ATR value
    - atr_ma: ATR moving average
    - rsi: RSI value
    - volume_ratio: Current vol / average vol
    - ema_fast: Fast EMA value
    - ema_slow: Slow EMA value
    - price: Current price
    - high_20: 20-bar high
    - low_20: 20-bar low
    """
    return classifier.classify(features)


@app.get("/api/v1/regime/states")
async def get_regime_states():
    """Get all possible regime states."""
    return {"regimes": REGIME_STATES}


@app.get("/api/v1/regime/{symbol}")
async def quick_regime(symbol: str, tf: str = "H4"):
    """
    Quick regime lookup (will fetch data internally in production).
    For now, returns a placeholder.
    """
    # In production, this would fetch MT4 data via WebSocket/API
    return {
        "symbol": symbol,
        "tf": tf,
        "regime": 0,
        "regime_name": "TRENDING_STRONG",
        "confidence": 0.75,
        "note": "Quick lookup requires data feed connection"
    }


# =============================================================================
# STANDALONE RUN
# =============================================================================

if __name__ == "__main__":
    print("=== nexus-regime starting on port 8001 ===")
    uvicorn.run(app, host="0.0.0.0", port=8001)