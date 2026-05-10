# 7NAGA — 7 Candle GOLD Intraday Trading System

**Symbol:** GOLD (XAUUSD) | **Method:** Buy Stop + Sell Stop | **Version:** MQL4 + MQL5

---

## Trading Rules

### Time Settings
- **Analysis:** 09:30 WIB (UTC+7)
- **Expiry:** 17:00 WIB
- **No trading on Monday**

### Order Placement
| Order | Source | Offset | Direction |
|-------|--------|--------|-----------|
| **Buy Stop** | HIGH (rounded UP to x5) | +100 points | Above |
| **Sell Stop** | LOW (rounded DOWN to x5) | -25 points | Below |

### Rounding Rule — KELIPATAN 5

**HIGH -> Round UP (Buy Stop):**
```
02 -> 05 | 03 -> 05 | 04 -> 05 | 05 -> 05
07 -> 10 | 08 -> 10 | 09 -> 10
```

**LOW -> Round DOWN (Sell Stop):**
```
03 -> 00 | 04 -> 00 | 05 -> 00
07 -> 05 | 08 -> 05 | 09 -> 05
```

### TP Zones (6 Zones — 0.01 lot per zone)
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
TP Ideal = Spread / 2
-> Rounded to nearest TP zone
```

### Stop Loss (Oneshot)
```
Buy Stop  -> SL = Sell Stop price
Sell Stop -> SL = Buy Stop price
```

### Distance Filter
```
MIN: 70 pips | MAX: 200 pips
Outside range -> SKIP DAY
```

### Forbidden Conditions
1. Monday — no open positions
2. NFP release days
3. FOMC Meeting days
4. Powell speeches
5. US CPI release days
6. US Federal Holidays

---

## Example

```
HIGH = 2600.02 -> Rounded UP = 2600.05
LOW  = 2590.03 -> Rounded DOWN = 2590.00

Buy Stop  = 2600.05 + 100 = 2601.05
Sell Stop = 2590.00 - 25  = 2589.75

Spread = 113 pips
TP Ideal = 113 / 2 = 56.5 -> TP4 (50 pips)
```

---

## EA Features

- Broker-agnostic virtual order system (broker cannot see SL/TP)
- 6 TP zones with progressive partial close (0.01 per zone)
- Virtual BE trigger at TP2+
- Switching mode: cancel opposite pending when one triggers
- News / US Holiday / Forbidden date filters
- Auto-expire all positions at 17:00 WIB
- Magic Number: `77777`

---

## File Structure

```
public-omon-omon/
├── README.md
├── SPEC.md
├── soul.md
├── MQL4/Experts/SevenCandleNaga.mq4
└── MQL5/Experts/SevenCandleNaga.mq5
```

---

## State Machine

```
IDLE -> ANALYZING -> PLACING -> ACTIVE -> COMPLETED
                    |
              SKIPPED (forbidden/skip)
```

---

*7 candles. 1 direction. Zero compromise.*