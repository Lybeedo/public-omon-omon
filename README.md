# Omon-Omon Trading Repository

**Cuancux Algo Traders | Omon-Omon Repo**

```
╔════════════════════════════════════════════════════════════════╗
║              Omon-Omon Automated Trading System                ║
║           MetaTrader 4/5 Expert Advisors & Indicators         ║
╚════════════════════════════════════════════════════════════════╝
```

---

## Built Your Own Trading System

Join our community and chat with our AI agent:
https://t.me/cuancux_help_bot

More projects:
- https://linktr.ee/lybeedo
- https://www.timesynctrading.com/

---

---

## Struktur Folder

```
omon-omon/
├── MT5/                    # MetaTrader 5 — MQL5 source
│   ├── Experts/            # Expert Advisors (19 EAs)
│   ├── Indicators/          # Custom Indicators (8 files)
│   ├── Scripts/            # Utility scripts
│   ├── Include/            # Shared headers
│   └── Dokumentasi/        # Prompt templates & Pine scripts
├── MT4/                    # MetaTrader 4 — MQL4 source
│   ├── Experts/            # Expert Advisors (6 EAs)
│   ├── Indicators/          # Custom Indicators
│   ├── Include/            # Shared headers (7 files)
│   └── Scripts/
├── Mentahan/               # File mentah / raw resources
├── Skills/                 # Dokumentasi skill & workflow
├── README.md               # (ini file)
└── SPEC.md                 # Technical specification & parameter reference
```

---

## Experts (EA) — MT5

| EA | Strategi | Status |
|----|----------|--------|
| `JavaneseTrader_EA.mq5` | Price refuses to go down/up (Tuku/Dol) | utama |
| `EA_SMC_FVG_Hybrid.mq5` | Smart Money Concept + FVG hybrid auto-trading | utama |
| `EA_JoeRoss_Hooks.mq5` | Joe Ross 1-2-3 + Ross Hooks | utama |
| `3Musketeer.mq5` | Triple timeframe strategy | |
| `3MusketeerPro.mq5` | Enhanced 3 Musketeer | |
| `AK_RPG.mq5` | RPG-based trading EA | |
| `BreakoutChannel_EA.mq5` | Breakout channel strategy | |
| `BreakoutPullback.mq5` | Breakout + pullback entry | |
| `CoinFlipEA.mq5` | 50/50 coinflip EA | |
| `EA_ChartPattern12.mq5` | Chart pattern recognition v12 | |
| `KampretCoinflip.mq5` | Modified coinflip variant | |
| `MA_Cross_Averaging.mq5` | MA crossover averaging | |
| `MTF_Integration_MQL5.mq5` | Multi-timeframe integration | |
| `SevenCandleNaga.mq5` | 7 candle pattern EA | |
| `SevenNagaSignal_MQ5.mq5` | Seven Naga signal EA | |
| `SignalScalerATR.mq5` | ATR-based signal scaler | |
| `XAUUSD_Scalper_M1_VirtualTrail.mq5` | M1 scalper with virtual trail | |
| `XAUUSD_SwingEMARSI.mq5` | Swing trade with EMA + RSI | |

## Experts (EA) — MT4

| EA | Strategi |
|----|----------|
| `BreakoutChannel_EA.mq4` | Breakout channel strategy |
| `BreakoutPullback.mq4` | Breakout + pullback entry |
| `EA_ChartPattern12.mq4` | Chart pattern recognition v12 |
| `MTF_Integration_MQL4.ex4` | Multi-timeframe integration (compiled) |
| `SevenCandleNaga.mq4` | 7 candle pattern EA |
| `JavaneseTrader_EA.mq5` | Price refuses to go down/up (Tuku/Dol) |

---

## Indicators — MT5

| Indicator | Deskripsi |
|-----------|-----------|
| `guppy_mma.mq5` | **Guppy MMA** — 12 EMAs (short/long groups) by mladen |
| `DarvasBox_Indicator.mq5` | Darvas box breakout system |
| `iCPattern12.mq5` | Chart pattern indicator v12 |
| `VPA_BDTL_Volume_V10.mq5` | VPA Volume + BDTL analysis |
| `VPA_BDTL_Volume_V10_Enhanced.mq5` | Enhanced VPA version |
| `VPA_Coulling_Textbook.mq5` | VPA based on Anna Coulling |

## Indicators — MT4

| Indicator | Deskripsi |
|-----------|-----------|
| `iCPattern12.mq4` | Chart pattern indicator v12 |

---

## Scripts — MT5

| Script | Deskripsi |
|--------|-----------|
| `CloseAllPositions.mq5` | Mass close all positions |

---

## Dokumentasi / TradingView

| File | Deskripsi |
|------|-----------|
| `smc_fvg_hybrid_analyzer.pine` | Full SMC+FVG analyzer (Pine Script v6) |
| `01_analysis_report.md` | AI analysis prompt template |

---

## Include Headers

### MT5
| File | Deskripsi |
|------|-----------|
| `JavaneseTrader_Config.mqh` | Shared config (signals, lot calc, price norm) |

### MT4
| File | Deskripsi |
|------|-----------|
| `CPattern12.mqh` | Chart Pattern v12 core |
| `CPattern12.mq4` | Chart Pattern v12 implementation |
| `MTF_Filter.mqh` | Multi-timeframe filter |
| `MTF_Filter_MS.mqh` | MTF filter (multi-symbol) |
| `PriceChannel.mqh` | Price channel utilities |
| `SMC_Filter.mqh` | SMC filter helpers |
| `JavaneseTrader_Config.mqh` | Shared config |

---

## EA Unggulan

### JavaneseTrader EA
**Filosofi:** *"Tuku ketika rego ra gelem mudun. Dol ketika rego ra gelem munggah."*

Buy ketika harga tidak mau turun lagi. Sell ketika harga tidak mau naik lagi.

Fitur: Swing detection, RSI filter, Trailing Stop, Breakeven, Session filter, Dynamic lot sizing.

Detail parameter: lihat `SPEC.md`

### EA_SMC_FVG_Hybrid (MT5)
Auto-detect mode (Swing/Scalp/Hybrid), FVG detection, BOS+CHoCH, HTF bias (D1+H4), Volume spike filter.

Parameter utama: `InpSwingPeriod=5`, `InpAtrMultSL=1.5`, `InpAtrMultTP=2.5`, `InpRiskPercent=1.0%`

### EA_JoeRoss_Hooks (MT5)
Joe Ross 1-2-3 Pattern + Ross Hooks Entry, EMA trend filter (8/21/50), Fibonacci Extensions TP.

Parameter utama: `InpSwingPeriod=5`, `InpFibExt1/2/3=127%/161%/200%`

---

## Instalasi

### MT5
```
Copy MT5/Experts/*.mq5 ke:
%APPDATA%\MetaQuotes\Terminal\<ID>\MQL5\Experts\

Copy MT5/Indicators/*.mq5 ke:
%APPDATA%\MetaQuotes\Terminal\<ID>\MQL5\Indicators\

Copy MT5/Include/*.mqh ke:
%APPDATA%\MetaQuotes\Terminal\<ID>\MQL5\Include\

Restart MT5 → Compile → Drag ke chart
```

### MT4
```
Copy MT4/Experts/*.mq4 ke:
%APPDATA%\MetaQuotes\Terminal\<ID>\MQL4\Experts\

Copy MT4/Indicators/*.mq4 ke:
%APPDATA%\MetaQuotes\Terminal\<ID>\MQL4\Indicators\

Restart MT4 → Drag ke chart
```

### TradingView
Copy paste file `.pine` ke Pine Editor → Add to Chart

---

## Catatan Penting

- **Backtest dulu** sebelum live trading
- Direkomendasikan TF M30+ untuk hasil lebih stabil
- Kombinasi dengan trend filter (EMA cross, ADX) meningkatkan akurasi
- Jangan lupa set `MaxOrders` sesuai strategi
- Perhatikan `MagicNumber` jika pakai multiple EA

---

## ⚠️ Disclaimer

*This is educational/automated trading content. Not financial advice. Always use proper risk management. Past performance does not guarantee future results.*

---

**Built by Omon-Omon Algo Traders for Cuancux Algo Traders**