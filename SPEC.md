# 7NAGA — Specification

## Overview
- **Name:** 7NAGA
- **Symbol:** GOLD (XAUUSD)
- **Timeframe:** Intraday (H1/M5)
- **Method:** Buy Stop + Sell Stop
- **Analysis:** 09:30 WIB | **Expiry:** 17:00 WIB
- **Platforms:** MQL4 + MQL5

---

## Core Rules

### Order Logic
```
HIGH -> Round UP (kelipatan 5) -> +100 pts -> BUY STOP
LOW  -> Round DOWN (kelipatan 5) -> -25 pts -> SELL STOP
```

### Rounding (Kelipatan 5)
```
HIGH UP:  02-05 -> 05 | 07-10 -> 10
LOW DOWN: 03-00 -> 00 | 07-05 -> 05 | 02-00 -> 00
```

### TP Zones
| Zone | Pips |
|------|------|
| TP1 | 10 |
| TP2 | **15 (MIN)** |
| TP3 | 30 |
| TP4 | 50 |
| TP5 | 100 |
| TP6 | 200 |

### TP Ideal
```
Spread = Buy Stop - Sell Stop
TP Ideal = Spread / 2 -> nearest zone
```

### Stop Loss (Oneshot)
```
Buy Stop  SL = Sell Stop
Sell Stop SL = Buy Stop
```

### Distance
```
MIN: 70 pips | MAX: 200 pips
Outside -> SKIP DAY
```

### Forbidden
- Monday, NFP, FOMC, Powell, US CPI, US Federal Holidays

---

## State Machine
```
IDLE -> ANALYZING -> PLACING -> ACTIVE -> COMPLETED/SKIPPED
```

## Files
```
public-omon-omon/
├── README.md
├── SPEC.md
├── soul.md
├── MQL4/Experts/SevenCandleNaga.mq4
└── MQL5/Experts/SevenCandleNaga.mq5
```