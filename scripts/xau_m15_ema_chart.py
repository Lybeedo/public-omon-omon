#!/usr/bin/env python3
"""
xau_m15_ema_chart.py
Reusable script untuk menggambar chart XAUUSD M15 + EMA 9/21.

Data harga spot diambil dari gold-api (https://api.gold-api.com/price/XAU).
Data candle M15 diambil dari Binance XAUTUSDT (tokenized gold, spot-like).
Karena gold-api gratis tidak menyediakan OHLC intraday, XAUTUSDT dipakai sebagai
proxy spot untuk bentuk candle dan perhitungan EMA.

Usage:
    python xau_m15_ema_chart.py
    python xau_m15_ema_chart.py --output /tmp/xau_m15.png
    python xau_m15_ema_chart.py --symbol XAUTUSDT --bars 200
"""

import argparse
import sys
from datetime import datetime, timezone

import requests
import pandas as pd
import mplfinance as mpf

GOLD_API_URL = "https://api.gold-api.com/price/XAU"
BINANCE_KLINES_URL = "https://api.binance.com/api/v3/klines"


def fetch_gold_api_spot(timeout: int = 10) -> dict:
    """Fetch current spot XAU/USD from gold-api."""
    headers = {"User-Agent": "Mozilla/5.0"}
    r = requests.get(GOLD_API_URL, headers=headers, timeout=timeout)
    r.raise_for_status()
    data = r.json()
    return {
        "price": float(data["price"]),
        "currency": data.get("currency", "USD"),
        "updated_at": data.get("updatedAt"),
    }


def fetch_binance_klines(symbol: str, interval: str = "15m", limit: int = 200, timeout: int = 10) -> pd.DataFrame:
    """Fetch klines from Binance and return OHLCV DataFrame."""
    params = {"symbol": symbol, "interval": interval, "limit": limit}
    r = requests.get(BINANCE_KLINES_URL, params=params, timeout=timeout)
    r.raise_for_status()
    rows = r.json()
    # Binance kline fields: [open_time, open, high, low, close, volume, close_time, ...]
    df = pd.DataFrame(rows, columns=[
        "open_time", "open", "high", "low", "close", "volume",
        "close_time", "quote_asset_volume", "n_trades",
        "taker_buy_base", "taker_buy_quote", "ignore"
    ])
    df["open_time"] = pd.to_datetime(df["open_time"], unit="ms", utc=True)
    df.set_index("open_time", inplace=True)
    for col in ["open", "high", "low", "close", "volume"]:
        df[col] = pd.to_numeric(df[col], errors="coerce")
    df.rename(columns={"open": "Open", "high": "High", "low": "Low", "close": "Close", "volume": "Volume"}, inplace=True)
    return df[["Open", "High", "Low", "Close", "Volume"]]


def plot_chart(df: pd.DataFrame, spot: dict, symbol: str, output_path: str):
    """Plot candlestick chart with EMA 9/21 and save to output_path."""
    df = df.copy()
    df["EMA9"] = df["Close"].ewm(span=9, adjust=False).mean()
    df["EMA21"] = df["Close"].ewm(span=21, adjust=False).mean()
    df = df.dropna(subset=["EMA9", "EMA21"])

    title = (
        f"XAUUSD M15 Spot Proxy ({symbol}) — EMA 9 / 21\n"
        f"Gold-API spot: {spot['price']:.2f} {spot['currency']} @ {spot['updated_at']}"
    )

    ap = [
        mpf.make_addplot(df["EMA9"], color="dodgerblue", width=1.2),
        mpf.make_addplot(df["EMA21"], color="orangered", width=1.2),
    ]

    mpf.plot(
        df,
        type="candle",
        style="charles",
        title=title,
        ylabel="Price (USD)",
        addplot=ap,
        volume=False,
        figsize=(14, 7),
        savefig=dict(fname=output_path, dpi=150, bbox_inches="tight"),
        tight_layout=True,
    )

    latest = df.iloc[-1]
    print(f"Saved chart to {output_path}")
    print(f"Latest close: {latest['Close']:.2f} | EMA9: {latest['EMA9']:.2f} | EMA21: {latest['EMA21']:.2f}")
    print(f"Gold-API spot: {spot['price']:.2f} {spot['currency']} | updatedAt={spot['updated_at']}")


def main():
    parser = argparse.ArgumentParser(description="Draw XAUUSD M15 + EMA 9/21 chart")
    parser.add_argument("--symbol", default="XAUTUSDT", help="Binance spot-like symbol (default: XAUTUSDT)")
    parser.add_argument("--interval", default="15m", help="Kline interval (default: 15m)")
    parser.add_argument("--bars", type=int, default=200, help="Number of bars to fetch (default: 200)")
    parser.add_argument("--output", default="xau_m15_ema_chart.png", help="Output PNG path")
    args = parser.parse_args()

    try:
        spot = fetch_gold_api_spot()
    except Exception as e:
        print(f"Failed to fetch gold-api spot: {e}", file=sys.stderr)
        spot = {"price": float("nan"), "currency": "USD", "updated_at": "n/a"}

    try:
        df = fetch_binance_klines(args.symbol, args.interval, args.bars)
    except Exception as e:
        print(f"Failed to fetch Binance klines: {e}", file=sys.stderr)
        sys.exit(1)

    plot_chart(df, spot, args.symbol, args.output)


if __name__ == "__main__":
    main()
