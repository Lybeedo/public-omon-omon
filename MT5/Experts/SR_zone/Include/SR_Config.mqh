//+------------------------------------------------------------------+
//|                                                 SR_Config.mqh    |
//|                          Cuancux Algo Traders • Paulus Is        |
//+------------------------------------------------------------------+
#ifndef SR_CONFIG_MQH
#define SR_CONFIG_MQH

//+------------------------------------------------------------------+
//|  RISK MANAGEMENT                                                 |
//+------------------------------------------------------------------+
input group "=== RISK MANAGEMENT ==="
input double   RiskPercent       = 2.0;           // Risk per trade (% of account)
input double   MinRiskReward     = 2.0;           // Minimum Risk:Reward ratio
input double   MaxRiskReward     = 0.0;           // Max R:R (0=disabled)

//+------------------------------------------------------------------+
//|  POSITION SETTINGS                                               |
//+------------------------------------------------------------------+
input group "=== POSITION SETTINGS ==="
input int      MaxOpenTrades     = 3;             // Maximum concurrent trades
input double   MaxSpreadPoints   = 30;            // Max spread to allow trade (points)
input double   MaxSpreadPoints2  = 50;            // Max spread for 2nd entry (points)

//+------------------------------------------------------------------+
//|  STOP LOSS / TAKE PROFIT                                         |
//+------------------------------------------------------------------+
input group "=== SL / TP ==="
input double   StopLossPoints    = 150;           // Stop loss in points (0 = auto)
input double   TakeProfitPoints  = 300;           // Take profit in points (0 = auto)
input bool     UsePartialProfit  = true;          // Enable partial profit taking
input double   PartialTPPips     = 50;            // Partial TP from breakeven (points)
input double   PartialTPPct      = 30;            // % of position to close at PartialTP
input bool     UseBreakeven      = true;          // Move SL to BE after PartialTP hit
input double   BetriggerPips     = 30;            // Price must move X pips beyond BE before BE trigger
input bool     UseTrailingStop   = true;          // Enable trailing stop
input double   TrailStartPips    = 80;            // Begin trailing after this many pips
input double   TrailStepPips     = 20;            // Trail step in points

//+------------------------------------------------------------------+
//|  ZONE DETECTION                                                  |
//+------------------------------------------------------------------+
input group "=== ZONE DETECTION ==="
input string   BuyZonePrefix     = "SR_BuyZone";  // Rectangle name prefix for buy zones
input string   SellZonePrefix    = "SR_SellZone"; // Rectangle name prefix for sell zones
input int      ZoneLookbackBars  = 100;           // Bars to scan for zone validity
input int      InvalidationBars  = 3;             // Bars to confirm zone invalidation
input double   ZoneTouchTolPips  = 10;            // Price tolerance to consider zone "touched"

//+------------------------------------------------------------------+
//|  CANDLE PATTERNS                                                  |
//+------------------------------------------------------------------+
input group "=== CANDLE PATTERNS ==="
input bool     UseBullishEngulfing   = true;     // Detect bullish engulfing
input bool     UseHammerPattern      = true;     // Detect hammer / inverted hammer
input bool     UseMorningStar        = true;     // Detect morning star
input bool     UseBearishEngulfing   = true;     // Detect bearish engulfing
input bool     UseShootingStar       = true;     // Detect shooting star
input bool     UseEveningStar        = true;     // Detect evening star
input double   MinBodyRatio          = 0.5;      // Min body size vs full candle range (0-1)

//+------------------------------------------------------------------+
//|  SESSION FILTER                                                  |
//+------------------------------------------------------------------+
input group "=== SESSION FILTER ==="
input bool     UseNYSessionFilter = true;        // Restrict trading to NY session
input int      NYStartHour       = 8;            // NY session start hour (0-23)
input int      NYStartMin        = 0;            // NY session start minute
input int      NYEndHour         = 17;           // NY session end hour (0-23)
input int      NYEndMin          = 0;            // NY session end minute

//+------------------------------------------------------------------+
//|  LOGGING & VISUAL                                               |
//+------------------------------------------------------------------+
input group "=== LOGGING & VISUAL ==="
input int      LogLevel          = 1;             // 0=None, 1=Key events, 2=All
input int      MaxLogBars        = 500;           // Bars to show in chart comment
input color    BuyZoneColor      = clrLime;       // Color for buy zones
input color    SellZoneColor     = clrRed;        // Color for sell zones
input color    ValidZoneColor    = clrDodgerBlue; // Color for validated/active zones
input color    InvalidZoneColor  = clrGray;       // Color for invalidated zones

//+------------------------------------------------------------------+
//|  MISC                                                            |
//+------------------------------------------------------------------+
input group "=== MISC ==="
input int      MagicNumber       = 20250603;     // Magic number for EA trades
input string   CommentPrefix     = "SR_EA";      // Trade comment prefix
input int      Slippage          = 3;            // Slippage in points

#endif
//+------------------------------------------------------------------+