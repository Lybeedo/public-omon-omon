# SMC_Lee — Omon-Omon MQL5 Trading System
**Cuancux Algo Traders | Omon-Omon Repo**

```
╔════════════════════════════════════════════════════════════╗
║         SMC_Lee — Smart Money Concept + Joe Ross           ║
║            Institutional Grade Trading System              ║
╚════════════════════════════════════════════════════════════╝
```

## 📁 Struktur Folder

```
MQ5/SMC_Lee/
├── Experts/                     ← EA (Expert Advisors) — 17 files
├── Indicators/                  ← Custom Indicators
├── Include/indi/                ← VPA Include indicators
├── Scripts/                     ← Utility scripts
├── Prompts/                     ← AI analysis prompt templates
└── TradingView/                  ← Pine Script v6
```

---

## 📦 Experts (EA) — 17 Files

| EA | Deskripsi |
|----|-----------|
| `EA_SMC_FVG_Hybrid.mq5` | **MAIN** — SMC + FVG hybrid auto-trading |
| `EA_JoeRoss_Hooks.mq5` | **NEW** — Joe Ross 1-2-3 + Ross Hooks EA |
| `3Musketeer.mq5` | Triple timeframe strategy EA |
| `3MusketeerPro.mq5` | Enhanced 3 Musketeer version |
| `AK_RPG.mq5` | RPG-based trading EA |
| `BreakoutChannel_EA.mq5` | Breakout channel strategy |
| `BreakoutPullback.mq5` | Breakout + pullback entry |
| `CoinFlipEA.mq5` | 50/50 coinflip EA |
| `EA_ChartPattern12.mq5` | Chart pattern recognition EA |
| `KampretCoinflip.mq5` | Modified coinflip variant |
| `MA_Cross_Averaging.mq5` | MA crossover averaging EA |
| `MTF_Integration_MQL5.mq5` | Multi-timeframe integration |
| `SevenCandleNaga.mq5` | 7 candle pattern EA |
| `SevenNagaSignal_MQ5.mq5` | Seven Naga signal EA |
| `SignalScalerATR.mq5` | ATR-based signal scaler |
| `XAUUSD_Scalper_M1_VirtualTrail.mq5` | M1 scalper with virtual trail |
| `XAUUSD_SwingEMARSI.mq5` | Swing trade with EMA + RSI |

---

## 📊 Indicators

| Indicator | Deskripsi |
|-----------|-----------|
| `DarvasBox_Indicator.mq5` | Darvas box breakout system |
| `iCPattern12.mq5` | Chart pattern indicator v12 |

---

## 🔧 Include / Indicators (VPA)

| File | Deskripsi |
|------|-----------|
| `VPA_BDTL_Volume_V10.mq5` | VPA Volume + BDTL analysis |
| `VPA_BDTL_Volume_V10_Enhanced.mq5` | Enhanced VPA version |
| `VPA_Coulling_Textbook.mq5` | VPA based on Anna Coulling |

---

## 📝 Scripts

| Script | Deskripsi |
|--------|-----------|
| `CloseAllPositions.mq5` | Mass close all positions |

---

## 📈 TradingView (Pine Script)

| File | Deskripsi |
|------|-----------|
| `smc_fvg_hybrid_analyzer.pine` | **MAIN** — Full SMC+FVG analyzer v1.0 |

---

## 🎯 Cara Pakai

### MQL5 / MetaTrader 5
```bash
# Copy folder Experts ke:
C:/Users/[USER]/AppData/Roaming/MetaQuotes/Terminal/[ID]/MQL5/Experts/

# Compile di MetaEditor → Restart MT5
```

### TradingView
```bash
# Copy paste smc_fvg_hybrid_analyzer.pine
# ke Pine Editor → Add to Chart
```

---

## 🤖 EA_SMC_FVG_Hybrid — Quick Start

**Parameter utama:**
- `InpSwingPeriod` = 5 (swing pivot)
- `InpAtrPeriod` = 14
- `InpAtrMultSL` = 1.5 (SL multiplier)
- `InpAtrMultTP` = 2.5 (TP multiplier)
- `InpRiskPercent` = 1.0%
- `InpMaxPositions` = 3

**Fitur:**
- ✅ Auto-detect mode (Swing / Scalp / Hybrid)
- ✅ FVG detection + tracking
- ✅ BOS + CHoCH detection
- ✅ HTF bias (D1 + H4)
- ✅ Volume spike filter
- ✅ Lot sizing from risk %
- ✅ Auto breakeven move
- ✅ Live dashboard on chart

---

## 🤖 EA_JoeRoss_Hooks — Quick Start

**Strategi:** Joe Ross 1-2-3 Pattern + Ross Hooks Entry

**Parameter utama:**
- `InpSwingPeriod` = 5
- `InpFibExt1/2/3` = 127% / 161% / 200% (Fibonacci TP)
- `InpAtrMultSL` = 1.5
- `InpRiskPercent` = 1.0%
- `InpTradeMode` = HYBRID

**Fitur:**
- ✅ Bullish & Bearish 1-2-3 detection
- ✅ Ross Hook entry (wait for hook break!)
- ✅ Reversal Hook trading
- ✅ EMA trend filter (8/21/50)
- ✅ Volume spike filter
- ✅ Fibonacci Extensions TP
- ✅ ATR-based SL with natural S/R
- ✅ Swing/Scalp/Hybrid mode
- ✅ Breakeven move + partial close
- ✅ Live dashboard on chart

---

## 🤖 AI Analysis Prompts

Gunakan `Prompts/01_analysis_report.md` untuk generate
full institutional analysis report dari 3 screenshot chart (M15, M5, M1).

---

## ⚠️ Disclaimer

*"This is educational/automated trading content. Not financial advice. Always use proper risk management. Past performance does not guarantee future results."*

---

**Built by Omon-Omon Algo Traders for Cuancux Algo Traders**

*"Trading Bukan Judi, Ini Skill!"* 💪