# Breakout & Pullback EA

**Gold (XAUUSD) | H1 Timeframe | MQL4 + MQL5**

## Strategy Overview

**Breakout + Pullback Entry** — Menunggu konfigurasi range, breakout level high/low, lalu retest sebagai entry signal.

```
Range Detection (20 bars) → Breakout Confirmed → Pullback Entry → SL/2TP
```

## Rules

1. **Range Detection**: Ambil 20 bar terakhir, cari HIGH dan LOW
2. **Breakout**: Candle close di atas Highest High (buy) atau di bawah Lowest Low (sell)
3. **Pullback**: Price retest level breakout + confirm candle direction
4. **Entry**: Market order saat pullback terkonfirmasi
5. **SL**: ATR-based (1.5x multiplier dari ATR period 14)
6. **TP**: Split lot — TP1 di 1R (50% close + move BE), TP2 di 2R (50% remaining)

## Parameters

| Parameter | Default | Deskripsi |
|-----------|---------|-----------|
| `InpRangeBars` | 20 | Jumlah bar untuk deteksi range |
| `InpMinRange` | 100 pips | Min jarak HIGH-LOW |
| `InpRetestBars` | 5 | Max candle untuk retest |
| `InpATROffset` | 1.5 | ATR multiplier untuk SL |
| `InpATRPeriod` | 14 | Period ATR |
| `InpRiskPercent` | 2% | Risk per trade |
| `InpMaxSpread` | 30 | Max spread untuk eksekusi |
| `InpMagicNumber` | 99999 | EA ID |
| `InpMaxTrades` | 1 | Max open posisi |

## Files

```
MQL4/Experts/BreakoutPullback.mq4  — MT4 version
MQL5/Experts/BreakoutPullback.mq5  — MT5 version
```

## Disclaimer

EA ini NON-GARANSI. Backtest dulu sebelum live. Pasti ada drawdown.

---

## Other EAs in this repo

- **7NAGA** — 7 Candle GOLD Intraday EA (buy stop / sell stop system)
- **CoinFlipEA** — Simple Martingale flip coin system

