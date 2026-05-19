# Guppy MMA Indicator

MetaTrader 5 (MQL5) indicator implementing the **Guppy Multiple Moving Averages** system.

**Source:** [mql5.com/en/code/16711](https://www.mql5.com/en/code/16711) by **mladen**, 2016-10-28

**Original description:** "It is made more up-to-date and multi time frame option added."

## What It Does

The Guppy MMA uses 12 EMAs (3, 5, 8, 10, 12, 15, 30, 35, 40, 45, 50, 60 periods) divided into two groups:

- **Short-term group** (3-15): Captures short-term trend changes
- **Long-term group** (30-60): Captures longer-term trend direction

When both groups align (both compressed or both expanded), it signals strong trend conditions.

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `TimeFrame` | ENUM_TIMEFRAMES | PERIOD_CURRENT | Timeframe for multi-timeframe mode |
| `Price` | ENUM_APPLIED_PRICE | PRICE_CLOSE | Price type for MAs |
| `Method` | ENUM_MA_METHOD | MODE_EMA | Moving average method |
| `ColorFrom` | color | Lime | Starting gradient color |
| `ColorTo` | color | MediumVioletRed | Ending gradient color |
| `Interpolate` | bool | true | Interpolate in MTF mode |

## Features

- Multi-timeframe support (reads from a higher timeframe indicator)
- Color gradient across the 12 lines (Lime to MediumVioletRed)
- Interpolation for smooth MTF display
- Designed for scalping, day trading, and swing trading

## Installation

1. Copy `guppy_mma.mq5` to your MetaTrader 5 `MQL5/Indicators/` folder
2. Restart MetaEditor or refresh the Indicators list in MT5
3. Drag onto a chart

## License

See header in source code — copyright © mladen, 2016, MetaQuotes Software Corp.