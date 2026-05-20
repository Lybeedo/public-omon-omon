# SPEC: Omon-Omon Trading Repository

Technical specification untuk seluruh Expert Advisors dan Indicators dalam repo ini.

---

## 1. Project Overview

**Nama:** Omon-Omon Trading Repository
**Tipe:** MetaTrader 4/5 Expert Advisors + Custom Indicators
**Platform:** MT5 (MQ5 primary), MT4 (MQ4 secondary)
**Repository:** github.com/Lybeedo/public-omon-omon

---

## 2. EA Specifications

### 2.1 JavaneseTrader EA
**Filosofi:** *"Tuku ketika rego ra gelem mudun. Dol ketika rego ra gelem munggah."*
**File:** `MT5/Experts/JavaneseTrader_EA.mq5`, `MT4/Experts/JavaneseTrader_EA.mq5`

#### Strategi
- **BUY (TUKU):** Price refuses to go lower — swing low + higher low confirmation
- **SELL (DOL):** Price refuses to go higher — swing high + lower high confirmation

#### Input Parameters
| Group | Parameter | Type | Default | Deskripsi |
|-------|-----------|------|---------|-----------|
| ENTRY | LookbackPeriod | int | 20 | Candle count untuk swing detection |
| ENTRY | MinSwingSize | double | 0.5% | Minimum swing size |
| ENTRY | WaitCandles | int | 3 | Konfirmasi candle sebelum entry |
| ENTRY | UseRSIFilter | bool | true | Aktifkan RSI filter |
| ENTRY | RSIPeriod | int | 14 | RSI period |
| ENTRY | RSIBuyLevel | int | 30 | RSI oversold threshold |
| ENTRY | RSISellLevel | int | 70 | RSI overbought threshold |
| RISK | RiskPercent | double | 2.0% | Risk per trade |
| RISK | FixedLot | double | 0.0 | Fixed lot (0 = use RiskPercent) |
| RISK | StopLossPoints | int | 500 | SL dalam points (0 = ATR dynamic) |
| RISK | TakeProfitPoints | int | 1000 | TP dalam points (0 = RR ratio) |
| RISK | TakeProfitRatio | double | 2.0 | TP:SL ratio |
| RISK | UseBreakeven | bool | true | Aktifkan breakeven |
| RISK | BreakevenOffset | int | 100 | Points profit sebelum BE trigger |
| TRAILING | UseTrailing | bool | true | Aktifkan trailing stop |
| TRAILING | TrailingStart | double | 100 | Points profit untuk mulai trailing |
| TRAILING | TrailingStep | double | 50 | Step size per movement |
| TRAILING | TrailingDistance | double | 50 | Jarak dari harga |
| TRAILING | TrailingMode | enum | STEP | STEP atau LINEAR |
| FILTER | UseSessionFilter | bool | false | Aktifkan session filter |
| FILTER | StartHour | int | 9 | Trading start hour |
| FILTER | EndHour | int | 17 | Trading end hour |
| FILTER | MaxOrders | int | 1 | Max concurrent orders |
| FILTER | MagicNumber | int | 20250620 | EA magic number |

#### Position Management
- **Lot Sizing:** (Balance * Risk%) / (SL * TickValue * Point) — dinormalisasi ke broker step
- **Stop Loss:** Static (points) atau Dynamic (ATR 14 * 1.5)
- **Take Profit:** Static (points) atau Dynamic (|price-SL| * Ratio)
- **Breakeven:** Trigger profit >= BreakevenOffset points → SL = entry + spread
- **Trailing STEP:** Mulai di TrailingStart, SL naik per TrailingStep
- **Trailing LINEAR:** SL = CurrentPrice +/- TrailingDistance (terus mengikuti)

#### Known Issues
- Bug fix: `breakEvenPrice` → `breakEven` (already fixed in current version)

---

### 2.2 EA_SMC_FVG_Hybrid
**File:** `MT5/Experts/EA_SMC_FVG_Hybrid.mq5`
**Strategi:** Smart Money Concept + Fair Value Gap hybrid

#### Input Parameters
| Parameter | Default | Deskripsi |
|-----------|---------|-----------|
| InpSwingPeriod | 5 | Swing pivot period |
| InpAtrPeriod | 14 | ATR period |
| InpAtrMultSL | 1.5 | SL multiplier |
| InpAtrMultTP | 2.5 | TP multiplier |
| InpRiskPercent | 1.0% | Risk per trade |
| InpMaxPositions | 3 | Max open positions |

#### Fitur
- Auto-detect mode (Swing / Scalp / Hybrid)
- FVG detection + tracking
- BOS + CHoCH detection
- HTF bias (D1 + H4)
- Volume spike filter
- Lot sizing from risk %
- Auto breakeven move
- Live dashboard on chart

---

### 2.3 EA_JoeRoss_Hooks
**File:** `MT5/Experts/EA_JoeRoss_Hooks.mq5`
**Strategi:** Joe Ross 1-2-3 Pattern + Ross Hooks Entry

#### Input Parameters
| Parameter | Default | Deskripsi |
|-----------|---------|-----------|
| InpSwingPeriod | 5 | Swing pivot period |
| InpFibExt1 | 127% | Fibonacci TP Extension 1 |
| InpFibExt2 | 161% | Fibonacci TP Extension 2 |
| InpFibExt3 | 200% | Fibonacci TP Extension 3 |
| InpAtrMultSL | 1.5 | SL multiplier |
| InpRiskPercent | 1.0% | Risk per trade |
| InpTradeMode | HYBRID | Swing/Scalp/Hybrid mode |

#### Fitur
- Bullish & Bearish 1-2-3 detection
- Ross Hook entry (wait for hook break!)
- Reversal Hook trading
- EMA trend filter (8/21/50)
- Volume spike filter
- Fibonacci Extensions TP
- ATR-based SL with natural S/R
- Breakeven move + partial close
- Live dashboard on chart

---

### 2.4 EA Lainnya (MT5)

| EA | File | Strategi |
|----|------|----------|
| 3Musketeer | `3Musketeer.mq5` | Triple timeframe strategy |
| 3MusketeerPro | `3MusketeerPro.mq5` | Enhanced 3 Musketeer |
| AK_RPG | `AK_RPG.mq5` | RPG-based trading |
| BreakoutChannel_EA | `BreakoutChannel_EA.mq5` | Breakout channel |
| BreakoutPullback | `BreakoutPullback.mq5` | Breakout + pullback |
| CoinFlipEA | `CoinFlipEA.mq5` | 50/50 coinflip |
| EA_ChartPattern12 | `EA_ChartPattern12.mq5` | Chart pattern recognition v12 |
| KampretCoinflip | `KampretCoinflip.mq5` | Modified coinflip |
| MA_Cross_Averaging | `MA_Cross_Averaging.mq5` | MA crossover averaging |
| MTF_Integration_MQL5 | `MTF_Integration_MQL5.mq5` | Multi-timeframe |
| SevenCandleNaga | `SevenCandleNaga.mq5` | 7 candle pattern |
| SevenNagaSignal_MQ5 | `SevenNagaSignal_MQ5.mq5` | Seven Naga signal |
| SignalScalerATR | `SignalScalerATR.mq5` | ATR signal scaler |
| XAUUSD_Scalper_M1 | `XAUUSD_Scalper_M1_VirtualTrail.mq5` | M1 scalper |
| XAUUSD_SwingEMARSI | `XAUUSD_SwingEMARSI.mq5` | Swing EMA+RSI |

---

### 2.5 EA MT4

| EA | File | Deskripsi |
|----|------|-----------|
| BreakoutChannel_EA | `BreakoutChannel_EA.mq4` | Port MT4 dari MT5 |
| BreakoutPullback | `BreakoutPullback.mq4` | Port MT4 dari MT5 |
| EA_ChartPattern12 | `EA_ChartPattern12.mq4` | Port MT4 dari MT5 |
| MTF_Integration | `MTF_Integration_MQL4.ex4` | MT4 compiled binary |
| SevenCandleNaga | `SevenCandleNaga.mq4` | Port MT4 dari MT5 |
| JavaneseTrader_EA | `JavaneseTrader_EA.mq5` | (MQ5 di MT4 folder, perlu konversi MQ4) |

---

## 3. Indicators

### 3.1 guppy_mma.mq5
**File:** `MT5/Indicators/guppy_mma.mq5`
**Source:** mql5.com/en/code/16711 by mladen, 2016

**Guppy Multiple Moving Averages** — 12 EMAs dibagi dua grup:
- **Short-term (3-15):** Captures short-term trend
- **Long-term (30-60):** Captures longer-term trend

| Parameter | Default | Deskripsi |
|-----------|---------|-----------|
| TimeFrame | PERIOD_CURRENT | Multi-timeframe mode |
| Price | PRICE_CLOSE | Price type |
| Method | MODE_EMA | MA method |
| ColorFrom | Lime | Gradient start |
| ColorTo | MediumVioletRed | Gradient end |
| Interpolate | true | Interpolate MTF |

---

### 3.2 DarvasBox_Indicator.mq5
**File:** `MT5/Indicators/DarvasBox_Indicator.mq5`
**Strategi:** Darvas box breakout system

### 3.3 iCPattern12
**File:** `MT5/Indicators/iCPattern12.mq5`, `MT4/Indicators/iCPattern12.mq4`
**Strategi:** Chart pattern recognition v12

### 3.4 VPA Indicators (MT5)
| File | Deskripsi |
|------|-----------|
| `VPA_BDTL_Volume_V10.mq5` | VPA Volume + BDTL analysis |
| `VPA_BDTL_Volume_V10_Enhanced.mq5` | Enhanced VPA version |
| `VPA_Coulling_Textbook.mq5` | VPA based on Anna Coulling |

---

## 4. Include Headers

### MT5
| File | Fungsi |
|------|--------|
| `JavaneseTrader_Config.mqh` | Signal enum, lot calc, price normalize |

### MT4
| File | Fungsi |
|------|--------|
| `CPattern12.mqh` | Chart Pattern v12 core |
| `CPattern12.mq4` | Chart Pattern v12 impl |
| `MTF_Filter.mqh` | Multi-timeframe filter |
| `MTF_Filter_MS.mqh` | MTF filter multi-symbol |
| `PriceChannel.mqh` | Price channel utilities |
| `SMC_Filter.mqh` | SMC filter helpers |
| `JavaneseTrader_Config.mqh` | Shared config |

---

## 5. Scripts

| File | Fungsi |
|------|--------|
| `MT5/Scripts/CloseAllPositions.mq5` | Mass close all positions |

---

## 6. Dokumentasi

| File | Fungsi |
|------|--------|
| `MT5/Dokumentasi/Prompts/01_analysis_report.md` | AI analysis prompt template |
| `MT5/Dokumentasi/TradingView/smc_fvg_hybrid_analyzer.pine` | Pine Script v6 analyzer |
| `MT5/Dokumentasi/README.md` | SMC_Lee documentation |

---

## 7. Known Limitations

- MT4: beberapa EA belum dikonversi (masih MQ5 di folder MT4)
- Breakeven: spread adjustment hardcoded
- RSI filter: hanya single timeframe
- Max 1 posisi per symbol per EA instance
- Trailing LINEAR: tidak menyimpan highest/lowest tracker

---

## 8. Future Improvements

- [ ] MT4 MQ4 conversion untuk seluruh EA
- [ ] Multi-timeframe RSI filter
- [ ] Trend filter (EMA cross, ADX)
- [ ] News filter (high-impact avoidance)
- [ ] Equity protection (max daily drawdown)
- [ ] Session-specific SL sizing
- [ ] Partial TP (50% at 1R, trail rest)
- [ ] Dashboard panel visual
- [ ] Backtest framework otomatis

---

## 9. Version History

| Versi | Tanggal | Perubahan |
|-------|---------|-----------|
| v1.00 | 2025-05-20 | Initial commit — JavaneseTrader + SMC_Lee EAs |
| v1.01 | 2025-05-20 | Folder restructure: MQ5→MT5, MQL4→MT4, guppy_mma merged |

---

**Built by Omon-Omon Algo Traders for Cuancux Algo Traders**
*"Sabar lan disiplin ngenteni momentum sing bener."*
