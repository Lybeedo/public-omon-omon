"""
nexus-llm: AI Analysis Engine via OpenRouter
============================================
Unlimited AI analysis using OpenRouter API.
No martingale. Pure intelligence.
"""

import os
import httpx
import json
from pydantic import BaseModel
from fastapi import FastAPI
from typing import Optional
import uvicorn

# =============================================================================
# OPENROUTER CONFIG
# =============================================================================

OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY", "")
OPENROUTER_BASE_URL = "https://openrouter.ai/api/v1"
OPENROUTER_SITE_URL = "https://cuancux.com"
OPENROUTER_SITE_NAME = "Cuancux Algo Traders"

# Default model - unlimited token plan
DEFAULT_MODEL = "anthropic/claude-opus-4-5"

# Available models for different tasks
MODELS = {
    "analysis": DEFAULT_MODEL,      # Market analysis
    "insight": "anthropic/claude-sonnet-4-5",  # Quick insights
    "strategy": DEFAULT_MODEL,       # Strategy review
    "summary": "google/gemini-2.5-pro-preview-06-05",  # Daily summary
}


# =============================================================================
# REQUEST/RESPONSE MODELS
# =============================================================================

class MarketAnalysisRequest(BaseModel):
    symbol: str = "EURUSD"
    regime: int = 0
    regime_name: str = "TRENDING_STRONG"
    confidence: float = 0.75
    price: float = 1.0850
    trend: str = "bullish"
    key_levels: dict = {}
    recent_trades: list = []
    volume_profile: dict = {}


class LLMInsightRequest(BaseModel):
    symbol: str = "EURUSD"
    regime: int = 0
    price: float = 1.0850
    trend: str = "bullish"
    context: str = ""


class StrategyReviewRequest(BaseModel):
    symbol: str = "EURUSD"
    equity_curve: list = []
    trade_log: list = []
    params: dict = {}


# =============================================================================
# LLM CLIENT
# =============================================================================

class OpenRouterClient:
    """
    Wrapper for OpenRouter API with unlimited token handling.
    """
    
    def __init__(self, api_key: str):
        self.api_key = api_key
        self.client = httpx.Client(
            base_url=OPENROUTER_BASE_URL,
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
                "HTTP-Referer": OPENROUTER_SITE_URL,
                "X-Title": OPENROUTER_SITE_NAME,
            },
            timeout=120.0
        )
    
    def chat(self, messages: list, model: str = DEFAULT_MODEL, 
             temperature: float = 0.7, max_tokens: int = 8192) -> dict:
        """
        Send chat request to OpenRouter.
        
        Args:
            messages: List of message dicts [{"role": "user", "content": "..."}]
            model: Model to use
            temperature: Response creativity (0.1 = focused, 1.0 = creative)
            max_tokens: Max response tokens
        
        Returns:
            Response dict with choices and usage
        """
        if not self.api_key:
            return {"error": "OPENROUTER_API_KEY not set", "choices": []}
        
        payload = {
            "model": model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": max_tokens,
        }
        
        try:
            resp = self.client.post("/chat/completions", json=payload)
            resp.raise_for_status()
            return resp.json()
        except httpx.HTTPStatusError as e:
            return {"error": f"HTTP {e.response.status_code}", "choices": []}
        except Exception as e:
            return {"error": str(e), "choices": []}
    
    def analyze_market(self, req: MarketAnalysisRequest) -> dict:
        """Generate market narrative using AI."""
        
        prompt = f"""You are a senior institutional trader analyzing market conditions for {req.symbol}.

CURRENT STATE:
- Price: {req.price}
- Regime: {req.regime_name} (confidence: {req.confidence*100:.0f}%)
- Trend: {req.trend}

Provide a concise, actionable analysis:
1. What's happening in {req.symbol} right now?
2. Key levels to watch (support/resistance)
3. Best trade setup given the regime
4. Risk factors
5. One sentence trade rationale

Be direct. No fluff. Think like a bank trader."""
        
        messages = [
            {"role": "system", "content": "You are a senior institutional FX trader. Be direct, concise, and actionable."},
            {"role": "user", "content": prompt}
        ]
        
        return self.chat(messages, model=MODELS["analysis"], temperature=0.3)
    
    def generate_insight(self, req: LLMInsightRequest) -> dict:
        """Quick market insight."""
        
        prompt = f"""Quick analysis for {req.symbol} at {req.price} ({req.trend}).

Regime {req.regime}: {req.context}

Give ONE actionable insight. Max 100 words. Focus on:
- Direction bias
- Key level to watch
- Risk:Reward setup

Example format:
"BULLISH BIAS | Watch 1.0900 as next target | R:R 1:2 if pullback to 1.0830 | Risk: NFP on Friday"
"""
        
        messages = [
            {"role": "user", "content": prompt}
        ]
        
        return self.chat(messages, model=MODELS["insight"], temperature=0.5, max_tokens=512)
    
    def review_strategy(self, req: StrategyReviewRequest) -> dict:
        """AI-powered strategy review and improvement suggestions."""
        
        equity_str = json.dumps(req.equity_curve[-20:]) if req.equity_curve else "[]"
        trades_str = json.dumps(req.trade_log[-10:]) if req.trade_log else "[]"
        params_str = json.dumps(req.params, indent=2)
        
        prompt = f"""Review this trading strategy for {req.symbol}.

EQUITY CURVE (recent 20 values):
{equity_str}

RECENT TRADES:
{trades_str}

PARAMETERS:
{params_str}

Provide:
1. Performance assessment (good/bad/needs work)
2. Key metrics evaluation
3. Specific parameter adjustment suggestions
4. Identified problems (if any)
5. Strategy improvement ideas

Be constructive but honest. This is for a VicChelenge System challenge."""
        
        messages = [
            {"role": "system", "content": "You are a quantitative trading strategist reviewing an algorithmic trading system."},
            {"role": "user", "content": prompt}
        ]
        
        return self.chat(messages, model=MODELS["strategy"], temperature=0.4)
    
    def daily_summary(self, trades: list, metrics: dict) -> dict:
        """Generate end-of-day summary."""
        
        trades_str = json.dumps(trades, indent=2) if trades else "[]"
        metrics_str = json.dumps(metrics, indent=2)
        
        prompt = f"""Generate a brief daily trading summary for VicChelenge System.

TODAY'S TRADES:
{trades_str}

METRICS:
{metrics_str}

Format as:
- WIN/LOSS count
- Net P&L
- Best trade
- Mistakes made
- Tomorrow's focus
- One key insight

Max 300 words."""
        
        messages = [
            {"role": "user", "content": prompt}
        ]
        
        return self.chat(messages, model=MODELS["summary"], temperature=0.3, max_tokens=1024)


# =============================================================================
# FASTAPI APP
# =============================================================================

app = FastAPI(title="nexus-llm", version="1.0")

# Initialize client (lazy)
_llm_client: Optional[OpenRouterClient] = None

def get_llm_client() -> OpenRouterClient:
    global _llm_client
    if _llm_client is None:
        _llm_client = OpenRouterClient(OPENROUTER_API_KEY)
    return _llm_client


@app.get("/")
async def root():
    return {
        "service": "nexus-llm",
        "version": "1.0",
        "status": "running",
        "api_key_configured": bool(OPENROUTER_API_KEY),
        "models": MODELS
    }


@app.get("/health")
async def health():
    return {
        "status": "healthy", 
        "service": "nexus-llm",
        "api_key_set": bool(OPENROUTER_API_KEY)
    }


@app.post("/api/v1/llm/analyze")
async def analyze_market(req: MarketAnalysisRequest):
    """
    Generate comprehensive market analysis.
    """
    client = get_llm_client()
    result = client.analyze_market(req)
    
    # Parse response
    if "choices" in result and len(result["choices"]) > 0:
        content = result["choices"][0]["message"]["content"]
        return {
            "analysis": content,
            "model": result.get("model", "unknown"),
            "usage": result.get("usage", {})
        }
    
    return {"error": result.get("error", "Unknown error"), "analysis": ""}


@app.post("/api/v1/llm/insight")
async def get_insight(req: LLMInsightRequest):
    """
    Quick market insight (short response).
    """
    client = get_llm_client()
    result = client.generate_insight(req)
    
    if "choices" in result and len(result["choices"]) > 0:
        content = result["choices"][0]["message"]["content"]
        return {"insight": content, "model": result.get("model", "unknown")}
    
    return {"error": result.get("error", "Unknown error"), "insight": ""}


@app.post("/api/v1/llm/review")
async def review_strategy(req: StrategyReviewRequest):
    """
    Strategy performance review and improvement suggestions.
    """
    client = get_llm_client()
    result = client.review_strategy(req)
    
    if "choices" in result and len(result["choices"]) > 0:
        content = result["choices"][0]["message"]["content"]
        return {"review": content, "model": result.get("model", "unknown")}
    
    return {"error": result.get("error", "Unknown error"), "review": ""}


@app.post("/api/v1/llm/summary")
async def daily_summary(trades: list, metrics: dict):
    """
    End-of-day summary generation.
    """
    client = get_llm_client()
    result = client.daily_summary(trades, metrics)
    
    if "choices" in result and len(result["choices"]) > 0:
        content = result["choices"][0]["message"]["content"]
        return {"summary": content}
    
    return {"error": result.get("error", "Unknown error"), "summary": ""}


@app.get("/api/v1/llm/models")
async def list_models():
    """List available models."""
    return {"models": MODELS}


# =============================================================================
# STANDALONE RUN
# =============================================================================

if __name__ == "__main__":
    print("=== nexus-llm starting on port 8002 ===")
    print(f"OpenRouter API Key configured: {bool(OPENROUTER_API_KEY)}")
    uvicorn.run(app, host="0.0.0.0", port=8002)