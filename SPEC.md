# Breakout & Pullback EA — SPEC.md

## Concept & Vision
EA Gold (XAUUSD) berbasis strategi Breakout and Pullback. Menunggu konfigurasi range/breakout candle, lalu pullback ke level yang di-break sebagai entry. Target: risk-reward 1:2, single trade per sinyal, no averaging. Sederhana, robust, tidak over-optimized.

---

## Strategy Rules

### Setup Detection (Range)
- Ambil **N bars** terakhir (default: 20) sebagai range period
- Tentukan **Highest High** dan **Lowest Low** dari range tersebut
- Range valid jika: High - Low >= MinRange pips (default: 100 pips XAUUSD)

### Breakout Confirmation
- candle saat ini (close) BREAK acima Highest High = breakout atas
- candle saat ini (close) BREAK abaixo Lowest Low = breakout bawah
- Hanya sinyal pertama yang diproses per bar (no repaint)

### Pullback Entry (yang valid)
- Setelah breakout terjadi, tunggu price RETEST level yang di-break
- Retest: price kembali menyentuh/mendekati level highest/lowest dalam 1-5 candle setelah breakout
- Entry dilakukan saat price confirm retest (close candle retest)

### Entry Types
- **Buy**: Breakout atas + retest ke atas (price halten + naik)
- **Sell**: Breakout bawah + retest ke bawah (price halten + turun)

### Stop Loss
- Buy SL: below retest low atau lowest low - atr_offset pips
- Sell SL: above retest high atau highest high + atr_offset pips
- Default ATR multiplier: 1.5x

### Take Profit
- TP1: 1R (risk reward 1:1)
- TP2: 2R (risk reward 1:2)
- Split lot: 50% di TP1 (move BE), 50% di TP2

---

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `InpRangeBars` | 20 | Jumlah bars untuk deteksi range |
| `InpMinRange` | 100.0 | Min jarak HIGH-LOW (pips) |
| `InpRetestBars` | 5 | Max candle untuk retest setelah breakout |
| `InpATROffset` | 1.5 | ATR multiplier untuk SL |
| `InpATRPeriod` | 14 | Period ATR |
| `InpRiskPercent` | 2.0 | Risk per trade (%) |
| `InpMaxSpread` | 30 | Max spread (pips) untuk eksekusi |
| `InpMagicNumber` | 99999 | ID EA |
| `InpMaxTrades` | 1 | Max open trade |

---

## Time Filter
- Trading aktif: 00:00 - 23:00 (all sessions)
- Skip news alto-impact: NFP, FOMC, US CPI (opsional, ditandai komentar)

---

## State Machine
```
IDLE → SETUP_DETECTED → BREAKOUT_CONFIRMED → PULLBACK_ENTRY → ACTIVE → TP1_HIT → TP2_HIT
```

---

## File Layout
```
public-omon-omon/
├── README.md
├── SPEC.md
├── MQL4/Experts/BreakoutPullback.mq4
└── MQL5/Experts/BreakoutPullback.mq5
```

---

## Auto-Detect Digit & Pip (MANDATORY)
**MQL5:**
```cpp
int    GDigits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
double GPoint  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
double GPip    = (GDigits == 3 || GDigits == 5) ? GPoint * 10 : GPoint;
```

**MQL4:**
```mql4
#define GDigits ((int)MarketInfo(_Symbol, MODE_DIGITS))
#define GPoint  (MarketInfo(_Symbol, MODE_POINT))
#define GPip    ((GDigits == 3 || GDigits == 5) ? GPoint * 10 : GPoint)
```

---

## Risk Management
- Lot dihitung: `Risk = AccountEquity * (InpRiskPercent / 100)` → lot = Risk / (distance_SL * GPip)
- Max 1 posisi aktif per magic
- SL wajib selalu ada, TP per split-lot

---

## Disclaimer
Stratégia ini NON-GARANSI. Backtest dulu sebelum live. Pasti ada drawdown.
