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

### 2.6 GBPUSD_BreakoutBox_EA
**File:** `MT5/Experts/GBPUSD_BreakoutBox_EA.mq5`, `MT4/Experts/GBPUSD_BreakoutBox_EA.mq4`
**Strategi:** Deni Dollar (Bandung) — Break 4-Candle HL Box

#### Konsep
- Identifikasi 4 candle pertama setelah jam mulai (InpStartHour)
- High & Low 4 candle tersebut = box boundary
- Break ke atas box → BUY | Break ke bawah box → SELL
- TP fix: 30 pips
- **No SL** — gunakan metode **Switch**: jika price balik arah break box, close posisi, masuk lagi arah sebaliknya dengan lot 2x
- Visual box ditampilkan di chart

#### Input Parameters
| Group | Parameter | Default | Deskripsi |
|-------|-----------|---------|-----------|
| SESSION | InpTradingDay | 1 (Mon) | Hari trading aktif (0=all) |
| SESSION | InpStartHour | 7 | Jam mulai build box |
| SESSION | InpCandleCount | 4 | Jumlah candle untuk HL box |
| TRADE | InpBaseLot | 0.1 | Lot dasar |
| TRADE | InpTPPips | 30.0 | TP dalam pips |
| TRADE | InpMaxSpread | 30 | Max spread (pips) |
| TRADE | InpMaxSwitch | 3 | Max switch count (0=unlimited) |
| TRADE | InpMagicNumber | 77777 | Magic number |
| RISK | InpMaxEquityRisk | 50% | Equity protection (% drawdown) |
| RISK | InpRiskPerLot | $50 | USD risk per 0.1 lot |
| RISK | InpEnableSwitch | true | Aktifkan switch method |
| FILTER | InpAllowSameDir | false | Allow same direction after TP |

#### State Machine
```
BSTATE_IDLE → BSTATE_BUILD_BOX → BSTATE_READY
    → BSTATE_PENDING_BREAK → BSTATE_ACTIVE_LONG/SHORT
    → (switch) → BSTATE_READY (loop)
    → BSTATE_COMPLETE → BSTATE_IDLE
```

#### Switch Logic
- BUY tapi Bid < BoxLow → Close BUY, execute SELL dengan lot 2x
- SELL tapi Ask > BoxHigh → Close SELL, execute BUY dengan lot 2x
- Max switch dibatasi InpMaxSwitch untuk prevent lot explosion
- Equity protection close semua jika drawdown > InpMaxEquityRisk

---

### 2.7 GoldTradePro EA
**File:** `MT4/Experts/GoldTradePro_EA.mq4`, `MT5/Experts/GoldTradePro_EA.mq5`
**Platform:** MT4 & MT5 (dual version)
**Strategi:** Multi-Strategy Fractal Breakout untuk XAUUSD/GOLD

#### Filosofi
EA ini dirancang khusus untuk trading **Gold (XAUUSD)** dengan menganalisis fractal high/low pada daily timeframe sebagai sinyal utama, dikonfirmasi dengan SMA(20) untuk trend direction. Setiap strategi memiliki parameter SL/TP/Trail yang berbeda untuk menangkap berbagai kondisi pasar.

#### Arsitektur
```
GoldTradePro EA
├── 8 Strategi Independen (A-H)
│   ├── Each punya Magic Number sendiri
│   ├── Each punya parameter SL/TP/Trail unik
│   └── Can be enabled/disabled via input
├── Signal Engine
│   ├── Fractal Detection (iFractals)
│   ├── SMA Trend Confirmation
│   └── Breakout Confirmation
├── Order Management
│   ├── Trailing SL
│   ├── Break-Even
│   ├── Zone Recovery
│   └── Virtual Expiration
└── Risk Management
    ├── Manual Lot
    ├── RPT (Risk Per Trade %)
    └── Lots Per Balance
```

#### Strategi Detail

##### Strategy A - Conservative Daily Breakout
| Parameter | Value | Deskripsi |
|-----------|-------|-----------|
| Magic Offset | 0 | Offset dari base magic |
| Signal TF | D1 | Daily sebagai timeframe sinyal |
| SL (points) | 150.0 | ~$15/lot untuk gold |
| TP (points) | 680.0 | ~$68/lot |
| Trail Start | 50.0 | Mulai trailing di 50 points profit |
| Trail Step | 30.0 | Step trailing 30 points |
| Expiry | 408h (17d) | Virtual expiry 17 hari |

##### Strategy B - Aggressive Breakout
| Parameter | Value | Deskripsi |
|-----------|-------|-----------|
| Magic Offset | 1 | |
| Signal TF | D1 | |
| SL (points) | 400.0 | Wide SL untuk volatilitas tinggi |
| TP (points) | 380.0 | Moderate TP |
| Trail Start | 80.0 | |
| Trail Step | 40.0 | |
| Expiry | 168h (7d) | |

##### Strategy C - Swing
| Parameter | Value | Deskripsi |
|-----------|-------|-----------|
| Magic Offset | 2 | |
| Signal TF | D1 | |
| Fractal Period | 2 | Check fractal 2 candle ago |
| SL (points) | 900.0 | Wide SL untuk swing |
| TP (points) | 980.0 | |
| Expiry | 408h (17d) | |

##### Strategy D - Trend Following
| Parameter | Value | Deskripsi |
|-----------|-------|-----------|
| Magic Offset | 3 | |
| SL (points) | 900.0 | |
| TP (points) | 680.0 | |
| Expiry | 48h (2d) | Short expiry untuk cepat cut |

##### Strategy E - Scalping
| Parameter | Value | Deskripsi |
|-----------|-------|-----------|
| Magic Offset | 4 | |
| Fractal Period | 2 | |
| SL (points) | 550.0 | |
| TP (points) | 480.0 | |
| Expiry | 480h (20d) | Long expiry |

##### Strategy F - Quick Breakout
| Parameter | Value | Deskripsi |
|-----------|-------|-----------|
| Magic Offset | 5 | |
| SL (points) | 700.0 | |
| TP (points) | 30.0 | Quick TP (early exit) |
| Expiry | 384h (16d) | |

##### Strategy G - Reversal
| Parameter | Value | Deskripsi |
|-----------|-------|-----------|
| Magic Offset | 6 | |
| SL (points) | 150.0 | Tight SL |
| TP (points) | 280.0 | |
| Expiry | 240h (10d) | |

##### Strategy H - Multi-Timeframe
| Parameter | Value | Deskripsi |
|-----------|-------|-----------|
| Magic Offset | 7 | |
| SL (points) | 250.0 | |
| TP (points) | 980.0 | Large TP |
| Expiry | 432h (18d) | |

#### Input Parameters

| Group | Parameter | Default | Deskripsi |
|-------|-----------|---------|-----------|
| General | Gen_MagicNumber | 1000 | Base magic number |
| General | Gen_Comment | "Gold Trade Pro v2" | Order comment |
| General | Gen_ShowInfoPanel | true | Show dashboard |
| Strategy | Strat_EnableA-H | true | Enable/disable masing-masing strategi |
| Filters | Filter_MaxSpread | 500 | Max spread (points) |
| Filters | Filter_UseVirtualExpiry | true | Virtual order expiry |
| MM | MM_RiskMode | 0 | 0=Manual, 1=RPT, 2=LotsPerBalance |
| MM | MM_StartLots | 0.01 | Starting lot size |
| MM | MM_RiskPerTrade | 2.0 | Risk % (untuk mode RPT) |
| MM | MM_LotPerBalanceStep | 600 | Balance per lot step |
| Trade Filter | Filter_HighLowBreakout | true | Enable breakout filter |
| Trade Filter | Filter_Reversal | false | Close on reversal signal |
| Trade Filter | Filter_MATrend | false | MA trend confirmation |
| Trade Filter | Filter_Volatility | true | ATR volatility filter |
| Trailing | Trail_Enable | false | Enable trailing SL |
| Trailing | Trail_StartPoints | 10.0 | Activate trailing |
| Trailing | Trail_StepPoints | 10.0 | Trail step size |
| Zone Recovery | ZR_Enable | false | Enable zone recovery |
| Zone Recovery | ZR_LotMultiplier | 1.0 | Lot multiplier for recovery |
| Trading Hours | TH_Enable | false | Enable time filter |
| Trading Hours | TH_StartDay/Hour | 0/0 | Start day & hour |
| Trading Hours | TH_EndDay/Hour | 6/24 | End day & hour |

#### Signal Logic (Buy Example)

```
1. Price > SMA(20) on D1
2. Fractal High[1] > High[1] + buffer
3. Fractal High[1] > Fractal High[2] (new high)
4. SMA[1] > SMA[2] (MA rising)
5. No existing open positions for this strategy
6. Spread <= MaxSpread
7. Within trading hours
→ EXECUTE BUY at Ask
```

#### Signal Logic (Sell Example)

```
1. Price < SMA(20) on D1
2. Fractal Low[1] < Low[1] - buffer
3. Fractal Low[1] < Fractal Low[2] (new low)
4. SMA[1] < SMA[2] (MA falling)
5. No existing open positions for this strategy
6. Spread <= MaxSpread
7. Within trading hours
→ EXECUTE SELL at Bid
```

#### Order Flow

```
OnTick()
├── Check new bar (D1 timeframe)
├── For each enabled strategy (A-H)
│   ├── UpdateStrategyState() — get fractal, MA, HL data
│   ├── CheckSignalConditions() — evaluate buy/sell
│   ├── ExecuteBuy/Sell() — open order if signal valid
│   └── ManageOrders() — trailing, BE, close, expiry
└── UpdateInfoPanel()
```

#### Position Management

| Feature | Logic |
|---------|-------|
| **Trailing SL** | Profit >= TrailStart → SL = CurrentPrice - TrailStep |
| **Break-Even** | Profit >= BEProfit → SL = EntryPrice + BEOffset |
| **Zone Recovery** | Price against position by 50% SL → add recovery lot |
| **Virtual Expiry** | Position > ExpiryHours → force close |
| **Reversal Close** | Opposite signal while position open → close |

#### Notes untuk Backtesting

- **Timeframe:** EA berjalan di timeframe berapapun, tapi check D1 bar untuk sinyal
- **Symbol:** Optimized untuk XAUUSD/GOLD (auto-detect)
- **Spread:** Default 500 points (= 50 pips untuk 5-digit broker)
- **Point:** Auto-adjust untuk 3/5 digit broker (gold = 0.01)
- **Commission:** Perlu setting komisi untuk gold (biasanya $5-10/lot)
- **Slippage:** Default 3 points (sesuaikan dengan broker)

#### Known Issues / Limitations

- Setiap strategi buka MAX 1 posisi per instance
- Zone Recovery bisa buka posisi tambahan di luar limit
- Virtual Expiry hanya untuk manage existing, bukan cancel pending
- Tidak ada news filter — perlu tambahkan manual
- Backtest dengan spread tinggi akan trigger skip

---

## 9. Version History

| Versi | Tanggal | Perubahan |
|-------|---------|-----------|
| v1.00 | 2025-05-20 | Initial commit — JavaneseTrader + SMC_Lee EAs |
| v1.01 | 2025-05-20 | Folder restructure: MQ5→MT5, MQL4→MT4, guppy_mma merged |
| v1.02 | 2025-05-23 | GBPUSD_BreakoutBox_EA — Deni Dollar 4-candle HL Box + Switch method |
| v2.00 | 2025-05-27 | GoldTradePro EA — Clean MT4/MT5 port dari obfuscated source, 8 strategi (A-H) |

---

**Built by Omon-Omon Algo Traders for Cuancux Algo Traders**
*"Sabar lan disiplin ngenteni momentum sing bener."*
