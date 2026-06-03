//+------------------------------------------------------------------+
//|                                                    SOUL.md       |
//|  VicChelenge System — XAUUSD S/R Zone EA                         |
//|  Cuancux Algo Traders • Paulus Is                                 |
//|                                                                  |
//|  Strategy: Discretionary Supply/Demand Zones                     |
//|  - Manual rectangles on chart = trade triggers                   |
//|  - Reversal candle patterns + confirmation candle                |
//|  - Fixed % risk position sizing                                  |
//|  - RR validation, partial TP, BE, trailing adjustments            |
//|  - NY session filter only                                        |
//|  - Full visual feedback + logging                                |
//+------------------------------------------------------------------+
//
//  FILE STRUCTURE
//  ──────────────
//  Include/
//    SR_Config.mqh        ← all input parameters
//    SR_Zones.mqh         ← zone detection, validity, invalidation
//    SR_Candles.mqh       ← reversal + confirmation candle patterns
//    SR_TradeManager.mqh  ← position sizing, SL/TP, partials, BE, trailing
//    SR_Session.mqh       ← NY session time filter
//    SR_Logger.mqh        ← Print / Comment logging + chart info
//  XAUUSD_SR_EA.mq5       ← main EA
//
//  HOW ZONES WORK
//  ───────────────
//  User draws TWO types of rectangle objects on chart:
//    "SR_BuyZone"   → demand zone (bullish reactions)
//    "SR_SellZone"  → supply zone  (bearish reactions)
//  The EA reads rectangle price ranges (High/Low), tracks price触碰,
//  validates with candle patterns, then enters trade.
//
//  ZONE INVALIDATION RULES
//  ─────────────────────────
//  Buy Zone invalidated when price closes BELOW zone low for 3+ bars
//  Sell Zone invalidated when price closes ABOVE zone high for 3+ bars
//  Zone also invalidated on major news event filter (configurable)
//
//  ENTRY CONDITIONS
//  ────────────────
//  BUY:
///   1. Price enters BuyZone rectangle area
//   2. Reversal candle forms (bullish engulfing / hammer / morning star)
//   3. Confirmation candle closes above reversal candle high
//   4. RR ≥ MinRiskReward (configured)
//   5. Within NY session window
//
//   SELL:
//   1. Price enters SellZone rectangle area
//   2. Reversal candle forms (bearish engulfing / shooting star / evening star)
//   3. Confirmation candle closes below reversal candle low
//   4. RR ≥ MinRiskReward (configured)
//   5. Within NY session window
//
//  MONEY MANAGEMENT
//  ─────────────────
//  Position Size = AccountRisk% / (SL pips × PipValue)
//  Partial TP1: configurable pips above BE (e.g. +50 pips)
//  Partial TP2: R:R based (e.g. 2R)
//  Breakeven: price moves to entry after TP1 hit
//  Trailing: lock more profit as price moves
//
//+------------------------------------------------------------------+

## Architecture Overview

```
User draws rectangles on chart
         │
         ▼
  ┌──────────────────┐
  │   SR_Zones.mqh   │  ← reads rectangle objects, tracks validity
  └────────┬─────────┘
           │ price + validity
           ▼
  ┌──────────────────┐
  │  SR_Candles.mqh  │  ← identifies reversal + confirmation candles
  └────────┬─────────┘
           │ signal
           ▼
  ┌────────────────────────┐
  │    SR_TradeManager.mqh  │  ← position sizing, SL/TP, partials, BE
  └────────┬─────────────────┘
           │
     ┌─────┴─────┐
     ▼           ▼
  ┌──────┐  ┌──────────┐
  │ BUY  │  │   SELL   │  ← only within NY session (SR_Session.mqh)
  └──────┘  └──────────┘
             │
             ▼
  ┌──────────────────┐
  │   SR_Logger.mqh  │  ← chart comment + Print logs
  └──────────────────┘
```

## Testing Workflow

1. **Visual backtest**: attach EA to XAUUSD M5 chart, draw zones, observe
2. **Strategy Tester**: same EA, configurable date range, zone input
3. **Forward test**: live demo account with small lot

## Revision History
- v1.0 — initial build, full EA with all modules