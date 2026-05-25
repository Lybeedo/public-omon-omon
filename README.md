# Murray Math EA

**MT4/MT5 Expert Advisor** — Murray Math 8-Level + Fibonacci + Anchored VWAP

## Sistem

Murray Math membagi range harga menjadi **8 level** (0/8 – 8/8) sebagai support/resistance berbasis matematika. Dipadukan dengan Fibonacci retracement/extension dan Anchored VWAP sebagai konfirmasi arah.

### Level Murray Math

| Level | Arti | Arti Trading |
|-------|------|-------------|
| 0/8 | Lower Extension | Reversal ekstrem bawah |
| 1/8 | Lower Weak | Zona balik arah lemah |
| 2/8 | Buy TP | Target take profit BUY |
| **3/8** | **Decision Zone** | **Tembus = trend naik** |
| **4/8** | **PIVOT / Magnet** | **Level paling penting** |
| **5/8** | **Decision Zone** | **Tembus = trend turun** |
| 6/8 | Sell TP | Target take profit SELL |
| 7/8 | Upper Weak | Zona balik arah lemah |
| 8/8 | Upper Extension | Reversal ekstrem atas |

### Konfirmasi dengan VWAP

- **Harga di atas VWAP** + zona 0-2/8 → konfirmasi BUY kuat
- **Harga di bawah VWAP** + zona 6-8/8 → konfirmasi SELL kuat
- **VWAP sebagai dynamic SL** — candle close di atas/ bawah VWAP = kemungkinan reversal
- VWAP reset per: Daily / Session (NY/London/Asia) / Weekly / Custom

### Konfirmasi dengan Fibonacci

- **Zone 38.2% – 61.8%** (Golden Zone) → zona buy/sell valid
- **Zone 78.6%** → retracement dalam, hampir reversal
- **Overlap Fibo + Murray** → zona entry paling kuat
- Extension 127.2%, 161.8%, 261.8% → target setelah breakout

## Folder Structure

```
MurrayMathEA/
├── MT4/
│   ├── Experts/
│   │   └── MurrayMathEA.mq4
│   └── Include/
│       ├── Utils.mqh
│       ├── MurrayMath.mqh
│       ├── FiboLevels.mqh
│       └── VWAP.mqh
├── MT5/
│   ├── Experts/
│   │   └── MurrayMathEA.mq5
│   └── Include/
│       ├── Utils.mqh
│       ├── MurrayMath.mqh
│       ├── FiboLevels.mqh
│       └── VWAP.mqh
├── include/               (source)
└── README.md
```

## Input Parameters

### General
- `EA_Comment` — Order comment
- `MaxSpread` — Max spread (points) untuk entry
- `UseTradeFilter` — Enable spread & trading hour filter
- `MaxOpenOrders` — Max concurrent orders per direction

### Murray Math
- `MM_LookbackBars` — Bars untuk kalkulasi swing range (default: 100)
- `MM_LineStyle` — Line style untuk level
- `MM_ShowLabels` — Show level labels on chart
- `MM_ShowZones` — Show colored zones antara level

### Fibonacci
- `Fibo_Lookback` — Bars untuk detect swing high/low (default: 50)
- `Fibo_MinSwingPips` — Minimum swing size (pips, default: 30)
- `Fibo_ShowRetrace` — Show retracement levels
- `Fibo_ShowExtension` — Show extension levels

### Anchored VWAP
- `VWAP_ResetMode` — VWAP reset mode (Daily / Session NY/London/Asia / Weekly / Custom)
- `VWAP_SessionHour` — Session start hour (broker time)
- `VWAP_ShowBands` — Show ±1σ / ±2σ bands

### Entry & Risk
- `RiskPercent` — Risk per trade % (default: 2%)
- `SL_Pips` — Stop loss (pips)
- `TP_Pips` — Take profit (pips)
- `TrailingStart` — Start trailing setelah (pips)
- `TrailingStep` — Trailing step (pips)

### Filters
- `Filter_VWAPConfirm` — Require VWAP confirmation
- `Filter_FiboConfirm` — Require Fibo zone confirmation
- `Filter_ZoneConfirm` — Require Murray zone filter
- `Filter_MinTrendBars` — Min bars price harus stay di atas/bawah VWAP

## Installation

### MT5
1. Copy semua file dari `MT5/Include/` ke `MQL5/Include/`
2. Copy `MT5/Experts/MurrayMathEA.mq5` ke `MQL5/Experts/`
3. Compile di MetaEditor (F7)
4. Attach ke chart

### MT4
1. Copy semua file dari `MT4/Include/` ke `MQL4/Include/`
2. Copy `MT4/Experts/MurrayMathEA.mq4` ke `MQL4/Experts/`
3. Compile di MetaEditor (F7)
4. Attach ke chart

## Signal Flow

```
Harga baru -> Update Murray Math levels -> Update Fibo levels -> Update VWAP
     ↓
Check spread filter -> Check trading hours -> Generate signal
     ↓
Score: Murray zone + VWAP position + Fibo zone + trend bars
     ↓
Score >= 5 → BUY | Score <= -5 → SELL | else → No trade
     ↓
Adjust SL dengan Fibo overlap -> Place order -> Trailing -> Equity protection
```

## Chart Dashboard

EA menampilkan info real-time:
- **Zone** — Murray level saat ini (0/8 s/d 8/8)
- **VWAP** — Current VWAP value + trend (BULL/BEAR/NEUT)
- **Fibo Zone** — Retracement zone (Golden, Deep, Extension)
- **Spread** — Spread saat ini
- **OHLC** — High/Low candle saat ini

## Known Limitations

- VWAP menggunakan tick volume (bisa tidak akurat di broker tertentu tanpa real volume)
- Fibonacci swing detection bersifat automatic — bisa tidak akurat di market sideways
- Disarankan backtest dulu sebelum live trading
- Max spread filter aktif per candle baru

## Backtest

Disarankan test di MT5 Strategy Tester dengan:
- Symbol: GBPUSD, EURUSD, USDJPY
- Period: H1, H4
- Date range: minimal 3 bulan
- Initial deposit: $1000

## Credits

Based on T.H. Murray's Octave System
Built with Claude Code (Anthropic)