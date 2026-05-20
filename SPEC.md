# SPEC: JavaneseTrader EA

## 1. Project Overview

**Nama:** JavaneseTrader EA
**Tipe:** MetaTrader Expert Advisor (MT4/MQ4 + MT5/MQ5)
**Filosofi:** "Tuku ketika rego ra gelem mudun. Dol ketika rego ra gelem munggah."
**Sifat:** Price action + momentum filter

---

## 2. Trading Logic

### 2.1 BUY Setup (TUKU)
**Trigger:** Price refuses to go lower (bounce / reversal)

Preconditions:
- Harga sudah turun (swing low terbentuk)
- Setelah swing low, harga TIDAK bikin low baru (higher low)
- Tunggu N candle konfirmasi (WaitCandles)
- RSI filter: RSI <= RSIBuyLevel (jika UseRSIFilter = true)

Entry: Buy at Ask price
SL: Dynamic ATR-based atau fixed points
TP: Dynamic RR-based atau fixed points

### 2.2 SELL Setup (DOL)
**Trigger:** Price refuses to go higher (rejection / reversal)

Preconditions:
- Harga sudah naik (swing high terbentuk)
- Setelah swing high, harga TIDAK bikin high baru (lower high)
- Tunggu N candle konfirmasi (WaitCandles)
- RSI filter: RSI >= RSISellLevel (jika UseRSIFilter = true)

Entry: Sell at Bid price
SL: Dynamic ATR-based atau fixed points
TP: Dynamic RR-based atau fixed points

---

## 3. Position Management

### 3.1 Lot Sizing
- **Mode 1 (RiskPercent):** Lot = (Balance * Risk%) / (SL_Points * TickValue * Point)
- **Mode 2 (FixedLot):** Lot = FixedLot
- Normalize ke broker lot step
- Clamp ke min/max broker

### 3.2 Stop Loss
- Static: `StopLossPoints * Point`
- Dynamic: `ATR(14) * 1.5`
- Jika `StopLossPoints = 0` -> pakai dynamic

### 3.3 Take Profit
- Static: `TakeProfitPoints * Point`
- Dynamic: `|price - SL| * TakeProfitRatio`
- Jika `TakeProfitPoints = 0` -> pakai dynamic

### 3.4 Breakeven
- Trigger: profit >= BreakevenOffset points
- SL dipindah ke entry price + spread

### 3.5 Trailing Stop
**STEP Mode:**
- Mulai: profit >= TrailingStart points
- Setiap kelipatan TrailingStep: SL naik TrailingStep - TrailingDistance

**LINEAR Mode:**
- SL = CurrentPrice -/+ TrailingDistance (terus mengikuti)

---

## 4. Input Parameters

```
// ENTRY
LookbackPeriod    : int    = 20
MinSwingSize      : double = 0.5 (%)
WaitCandles       : int    = 3
UseRSIFilter      : bool   = true
RSIPeriod          : int    = 14
RSIBuyLevel        : int    = 30
RSISellLevel       : int    = 70

// RISK
RiskPercent        : double = 2.0
FixedLot           : double = 0.0
StopLossPoints     : int    = 500
TakeProfitPoints   : int    = 1000
TakeProfitRatio    : double = 2.0
UseBreakeven       : bool   = true
BreakevenOffset    : int    = 100

// TRAILING
UseTrailing        : bool   = true
TrailingStart      : double = 100
TrailingStep       : double = 50
TrailingDistance   : double = 50
TrailingMode       : enum   = TRAILING_STEP

// FILTERS
UseSessionFilter   : bool   = false
StartHour          : int    = 9
EndHour            : int    = 17
MaxOrders          : int    = 1
MagicNumber        : int    = 20250620
Slippage           : int    = 30
Comment            : string = "JavaneseTrader"
```

---

## 5. File Structure

```
omon-omon/
  MT4/               # MQ4 source files
    Experts/
      JavaneseTrader_EA.mq4
    Include/
      JavaneseTrader_Config.mq4
    Indicators/
    Scripts/
  MT5/               # MQ5 source files
    Experts/
      JavaneseTrader_EA.mq5
    Include/
      JavaneseTrader_Config.mq5
    Indicators/
    Scripts/
  Mentahan/          # Raw / unprocessed files
  Skills/            # Dokumentasi skill & workflow
  README.md
  SPEC.md
```

---

## 6. Compatibility

- **MT5:** MQL5 native (CTrade class, ORDER_FILLING_FOK, dll)
- **MT4:** MQL4 (perlu konversi manual - berbeda syntax)
- **Timeframes:** ALL (direkomendasikan M30+)
- **Symbols:** ALL (Forex, Commodities, Crypto, Index, Stocks)

---

## 7. Known Limitations

- Breakeven pada MT5: spread adjustment sudah hardcoded
- RSI filter hanya single timeframe
- Max 1 posisi per symbol per EA instance
- Trailing LINEAR mode tidak menyimpan "highest/lowest" price tracker

---

## 8. Future Improvements (v1.1+)

- [ ] Multi-timeframe RSI filter (HF + LF alignment)
- [ ] Trend filter (EMA cross, ADX)
- [ ] News filter (high-impact event avoidance)
- [ ] Equity protection (max daily drawdown)
- [ ] Session-specific SL sizing (Asia vs London vs NY)
- [ ] Partial TP (close 50% at 1R, trail rest)
- [ ] Dashboard panel (visual entry signals)
- [ ] MT4 version (.mq4 conversion)

---

## 9. Version

- **v1.00** - Initial release (2025-05-20)