# SMC + FVG Hybrid Trading System
**Omon-Omon Algo Traders — Cuancux Community**

```
╔══════════════════════════════════════════════════════════════╗
║       SMC + FVG HYBRID ANALYSIS ENGINE v1.0                ║
║       Institutional-Grade Smart Money Concept Trading        ║
╚══════════════════════════════════════════════════════════════╝
```

## 📁 Project Structure

```
smc-fvg-hybrid/
├── README.md                          ← Dokumen utama
├── smc_fvg_hybrid_analyzer.pine       ← Pine Script v6 (TradingView)
├── EA_SMC_FVG_Hybrid.mq5              ← MQL5 EA (MT5)
├── PROMPTS/
│   ├── 01_analysis_report.md          ← Prompt utama: full report
│   ├── 02_mtf_structure_table.md      ← Prompt: Multi-TF table
│   ├── 03_fvg_reliability.md          ← Prompt: FVG reliability
│   ├── 04_micro_tf_plan.md            ← Prompt: Micro TF plan
│   └── 05_teaching_notes.md           ← Prompt: Teaching notes
└── IMAGES/
    └── (screenshot M15, M5, M1 charts paste di sini)
```

---

## 🎯 Quick Start

### TradingView (Pine Script)
1. Copy isi `smc_fvg_hybrid_analyzer.pine`
2. Buka TradingView → Pine Editor → Paste
3. Add to Chart
4. Konfigurasi parameter di Settings (gear icon)

### MetaTrader 5 (MQL5 EA)
1. Copy `EA_SMC_FVG_Hybrid.mq5` ke `MQL5/Experts/`
2. Compile di MetaEditor
3. Drag ke chart, set parameters
4. Enable auto-trading

---

## 🧠 Sistem Analysis

### 1. Smart Money Concept (SMC) Core

| Komponen | Fungsi |
|----------|--------|
| **Swing High/Low** | Deteksi titik pembalikan institutional |
| **BOS (Break of Structure)** | Arah trend utama — Bull/Bear |
| **CHoCH (Change of Character)** | Signal reversal / invalidasi trend |
| **Order Blocks** | Zona accumulation/distribution institutional |
| **Liquidity Sweeps** | Deteksi stop hunt / stop run |

### 2. Fair Value Gap (FVG)

```
Bullish FVG:  Low candle N    >    High candle N-2
              [Gap hijau]           [Terisi]
              ↓
              Price cenderung retrace ke FVG, then continue UP

Bearish FVG:  High candle N   <    Low candle N-2
              [Gap merah]          [Terisi]
              ↓
              Price cenderung retrace ke FVG, then continue DOWN
```

### 3. Multi-Timeframe (MTF) Analysis

| Timeframe | Fungsi | Interval |
|-----------|--------|----------|
| **D1 (HTF-1)** | Bias utama, trend mayor | Daily bias |
| **H4 (HTF-2)** | Struktur intermediate | 4-hour context |
| **H1/M15/M5/M1** | Entry zone, execution | Current TF |

### 4. Mode Detection

| Mode | Kondisi | Strategi |
|------|---------|----------|
| **HYBRID** | HTF aligned + low vol (<0.3%) | HTF bias + LTF execution |
| **SWING** | Low volatility, wide SL | Hold 1-5 hari |
| **SCALP** | High volatility (>=0.3%) | Quick in/out, tight SL |

---

## 📊 Indikator yang Dipakai

```
EMA Ribbon     → 8, 21, 50, 200
ATR            → SL/TP base (default: 14)
Volume MA      → 20-period SMA
HTF EMA        → 50, 200 on D1 & H4
```

---

## 📋 Analysis Report Template

Gunakan prompt di folder `PROMPTS/` untuk generate full markdown report dari 3 screenshot chart (M15, M5, M1).

**Langkah:**
1. Ambil screenshot M15, M5, M1 di TradingView
2. Paste ke ChatGPT/Claude dengan prompt `PROMPTS/01_analysis_report.md`
3. Dapat full report: Setup, MTF Table, FVG Table, Micro TF Plan, dll

---

## ⚙️ Parameter Utama

### Pine Script (TradingView)

| Parameter | Default | Deskripsi |
|-----------|---------|-----------|
| `Volume Spike Factor` | 1.5 | Kelipatan volume vs MA |
| `ATR Length` | 14 | Periode ATR |
| `ATR SL Mult` | 1.5 | SL = ATR * SL_mult |
| `ATR TP Mult` | 2.5 | TP = ATR * TP_mult |
| `Risk %` | 1.0% | Risk per trade |
| `Max Lot` | 2.0 | Maksimum lot |
| `HTF-1` | D | Higher timeframe bias |
| `HTF-2` | 4H | Higher timeframe structure |

### MQL5 EA (MT5)

| Parameter | Default | Deskripsi |
|-----------|---------|-----------|
| `InpSwingPeriod` | 5 | Swing pivot period |
| `InpAtrPeriod` | 14 | ATR period |
| `InpRiskPercent` | 1.0% | Risk per trade |
| `InpMaxPositions` | 3 | Max open positions |
| `InpMagicNumber` | 2026001 | EA identifier |

---

## 🚨 Rules of Engagement

### Entry Rules (Bullish Example)
```
✅ Bias: BULLISH (score >= +3)
✅ HTF Bias: BULLISH (D1)
✅ FVG Bullish terdeteksi
✅ Volume spike confirmed
✅ BOS: Bull (break of last swing high)
⬜ SL: Below swing low or ATR-based
⬜ TP: ATR * TP_mult from entry
⬜ R:R: Minimum 1:1.5 (rekomendasi 1:2+)
```

### Invalidation Rules
```
❌ Price close below SL level
❌ CHoCH detected (trend reversal signal)
❌ HTF bias shifts opposite
❌ Spread > 50 points (high cost environment)
❌ News event active (捂住捂住捂住!)
```

### Session Trading
```
🟢 PRIMARY: London Open (08:00-12:00 GMT)
🟢 PRIMARY: NY Open (13:00-17:00 GMT)
🟡 SECONDARY: Asia Session (00:00-03:00 GMT) - flat/sideways
🔴 AVOID: High-impact news events
```

---

## 🎓 Fitur Edukasi

### Teaching Note Sections (via prompt)
Setiap report includes:
- Institutional reasoning di balik setup
- Invalidasi — kenapa setup gagal
- Psychological aspects
- Risk management principles

---

## 📈 Confidence Meter

| Score | Level | Keterangan |
|-------|-------|------------|
| 8-10 | HIGH ✅ | Strong setup, multi-confirmation |
| 5-7 | MEDIUM ⚠️ | Valid setup, kurang konfirmasi |
| 1-4 | LOW ❌ | Weak, avoid atau small size only |

---

## 🔧 Troubleshooting

| Problem | Solution |
|---------|---------|
| No FVG detected | Adjust `FVG Threshold` (try 0.3 or 0.8) |
| Too many signals | Increase `Volume Spike Factor` to 2.0+ |
| EA not trading | Check: AutoTrading enabled? Spread within limit? |
| Wrong direction | Check HTF bias alignment — don't fight D1 |
| SL hit too often | Increase `ATR SL Mult` to 2.0 or higher |

---

## 📜 Lisensi

**MIT License** — Free to use, modify, distribute.
Built by **Omon-Omon Algo Traders** for **Cuancux Algo Traders** community.

*"Trading Bukan Judi, Ini Skill!"* 💪

---

## 🔗 Related

- Cuancux Algo Traders Telegram: https://t.me/cuancuxalgotraders
- RAISO Trading Landing Page (fiktif)
- Join community untuk signal & analysis