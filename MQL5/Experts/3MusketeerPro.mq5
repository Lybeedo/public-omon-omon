//+------------------------------------------------------------------+
//|                                              3MusketeerPro.mq5   |
//|                                            3 Musketeer Pro EA    |
//|                                                                 |
//| ================================================================|
//| RULE 1: RSI Oversold + CCI Bearish Ext + EMA5<SMMA8 → BUY       |
//|         RSI Overbought + CCI Bullish Ext + EMA5>SMMA8 → SELL     |
//|         Filter: ADX>25, ATR確認, Spread<Max                      |
//|                                                                 |
//| RULE 2: EMA10 cross SMA20 + Candle>EMA10 + RSI>50 → BUY         |
//|         EMA10 cross SMA20 + Candle<EMA10 + RSI<50 → SELL         |
//|         Filter: ADX>30, Stochastic, Min Candle Size              |
//|                                                                 |
//| RULE 3: Candle>EMA50 + EMA9 cross EMA21 + RSI>50 → BUY           |
//|         Candle<EMA50 + EMA9 cross EMA21 + RSI<50 → SELL          |
//|         - Max 3 floating per direction                          |
//|         - Close losing when profit covers loss + 30% margin      |
//|         - Stop new signals when max positions reached            |
//|                                                                 |
//| MONEY MANAGEMENT:                                               |
//| - Martingale on SL=0; Single-entry on SL>0                      |
//| - Max Lot Safety Cap                                            |
//| - Equity Protection (close all if DD%)                          |
//| - Grid Trading + Hedging + Partial TP + Trailing Stop           |
//+------------------------------------------------------------------+
#property copyright   "3 Musketeer Pro EA"
#property version      "2.00"
#property strict

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== IDENTITY ==="
input string   InpEAComment    = "3MusketeerPro";    // EA Name
input long     InpMagic        = 20250601;           // Magic Number

input group "=== LOT & MONEY MANAGEMENT ==="
input double   InpLot          = 0.01;               // Base Lot Size
input double   InpMaxLot       = 2.0;                // Max Lot Safety Cap
input double   InpMaxEquityDD  = 20;                // Max Equity Drawdown % (0=off)

input group "=== STOP LOSS & TAKE PROFIT ==="
input double   InpSL           = 0;                 // Stop Loss Points (0=Martingale)
input double   InpTP           = 50;                // Take Profit Points
input double   InpBreakevenPts = 20;                // Move to Breakeven after X pts

input group "=== TRAILING STOP ==="
input double   InpTrailStart   = 40;                // Trailing Start (Points)
input double   InpTrailStop    = 30;                // Trailing Stop (Points)
input bool     InpUseTrail     = true;              // Enable Trailing Stop

input group "=== RULE SELECTION ==="
input bool     InpUseRule1     = true;              // Use Rule 1 (RSI+CCI+MA)
input bool     InpUseRule2     = true;              // Use Rule 2 (EMA/SMA Cross)
input bool     InpUseRule3     = true;              // Use Rule 3 (EMA9/21 Cross)
input bool     InpAllRules     = false;             // Use ALL Rules simultaneously

input group "=== MARTINGALE ==="
input bool     InpUseMarti     = true;              // Enable Martingale
input double   InpMartiMult    = 1.25;              // Lot Multiplier (1.25 = +25%)
input double   InpMartiStep    = 25;                // Step Distance (Points)
input int      InpMaxMartiLvl  = 5;                 // Max Martingale Level (safety)

input group "=== GRID TRADING ==="
input bool     InpUseGrid      = true;              // Enable Grid Mode
input double   InpGridDist     = 25;                // Grid Distance (Points)
input double   InpGridTP       = 30;                // Grid TP (Total Profit Currency)
input int      InpMaxGridLvls  = 5;                 // Max Grid Levels

input group "=== HEDGING ==="
input bool     InpUseHedge     = true;              // Enable Hedging
input double   InpHedgePip     = 50;                // Trigger when float >= X pts
input double   InpHedgeDist    = 25;                // Hedge Distance (Points)
input double   InpHedgeLot     = 0.01;              // Hedge Lot
input double   InpHedgeMult    = 1.25;              // Hedge Marti Multiplier

input group "=== PARTIAL TP ==="
input bool     InpUsePartial   = true;              // Enable Partial TP
input double   InpPartialLvl   = 50;                // Close X% at 50% TP distance
input double   InpPartialPct   = 50;                // % of lot to close

input group "=== SIGNAL FILTERS ==="
input int      InpMinADX       = 25;                // Min ADX (0=disabled)
input int      InpMinSpread    = 0;                // Max Spread (0=any)
input int      InpMaxSpread    = 30;                // Max Spread Points
input double   InpMinCandleBody= 0;                // Min Candle Body Points (0=off)
input bool     InpUseATRFilt   = false;             // Use ATR Filter
input int      InpATRPeriod    = 14;               // ATR Period

input group "=== NEWS FILTER ==="
input bool     InpUseNewsFilt   = false;            // Enable News Filter
input int      InpNewsHPips    = 100;               // Pip distance from high-impact news
input int      InpNewsMinutes  = 30;               // Minutes before/after news
input string   InpNewsPairs    = "";               // Pairs to filter (blank=all)

input group "=== TRADING HOURS ==="
input bool     InpUseTimeFilt  = false;             // Use Trading Hours
input int      InpStartHour    = 9;                // Start Hour (broker time)
input int      InpEndHour      = 17;               // End Hour

input group "=== TARGET & DISPLAY ==="
input double   InpDailyTarget  = 100;              // Daily Target (Currency)
input bool     InpShowPanel     = true;             // Show Info Panel
input color    InpPanelBg      = clrDarkBlue;      // Panel BG Color
input color    InpPanelText    = clrWhite;         // Panel Text Color
input color    InpProfitColor  = clrLime;          // Profit Color
input color    InpLossColor    = clrRed;           // Loss Color

//+------------------------------------------------------------------+
//| GLOBAL HANDLES & STATE                                           |
//+------------------------------------------------------------------+
CTrade          g_trade;

// Indicator handles
int   g_hRSI, g_hCCI, g_hEMA5, g_hSMMA8;
int   g_hEMA10, g_hSMA20, g_hEMA50;
int   g_hEMA9, g_hEMA21, g_hADX;
int   g_hStochK, g_hStochD, g_hATR;

// State tracking
datetime        g_lastBarTime   = 0;
datetime        g_lastTradeTime = 0;
datetime        g_lastTradeDay  = 0;
double          g_dailyProfit   = 0;
double          g_lastEquity    = 0;
bool            g_hedgeActive   = false;
bool            g_equityDDHit   = false;
int             g_martiLevelBuy  = 0;   // current marti level per direction
int             g_martiLevelSell = 0;
int             g_gridLevelBuy   = 0;
int             g_gridLevelSell  = 0;

//+------------------------------------------------------------------+
//| ON INIT                                                          |
//+------------------------------------------------------------------+
int OnInit()
{
   // Validate parameters
   if(InpLot < 0.01)           { Print("ERROR: Lot minimal 0.01"); return INIT_PARAMETERS_INCORRECT; }
   if(InpTP <= 0)              { Print("ERROR: TP harus > 0"); return INIT_PARAMETERS_INCORRECT; }
   if(InpMartiStep <= 0 && InpUseMarti) { Print("ERROR: MartiStep harus > 0"); return INIT_PARAMETERS_INCORRECT; }
   if(InpGridDist <= 0 && InpUseGrid)   { Print("ERROR: GridDist harus > 0"); return INIT_PARAMETERS_INCORRECT; }
   
   if(!InpUseRule1 && !InpUseRule2 && !InpUseRule3 && !InpAllRules)
   {
      Print("ERROR: Minimal satu rule harus aktif!"); return INIT_PARAMETERS_INCORRECT;
   }
   
   // Setup trade
   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetDeviationInPoints(10);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_trade.SetAsyncMode(false);
   
   // Create indicators
   if(!InitIndicators())
      return INIT_FAILED;
   
   // Reset daily tracking
   g_lastTradeDay = (datetime)MathFloor((double)TimeCurrent() / 86400.0);
   g_dailyProfit  = 0;
   g_lastEquity   = AccountInfoDouble(ACCOUNT_EQUITY);
   
   Print("==========================================");
   Print("  3 MUSKETEER PRO v2.00 INITIALIZED");
   Print("==========================================");
   Print(" EA Name    : ", InpEAComment);
   Print(" Magic      : ", InpMagic);
   Print(" Lot        : ", InpLot);
   Print(" TP         : ", InpTP, " pts | SL: ", InpSL);
   Print(" Marti      : ", InpUseMarti, " x", InpMartiMult, " step ", InpMartiStep, " pts");
   Print(" Grid       : ", InpUseGrid, " dist ", InpGridDist, " pts | TP ", InpGridTP);
   Print(" Hedge      : ", InpUseHedge, " trigger ", InpHedgePip, " pts");
   Print(" Partial TP : ", InpUsePartial, " ", InpPartialPct, "% at ", InpPartialLvl, "% TP");
   Print(" Max Equity DD: ", InpMaxEquityDD, "%");
   Print(" Rules      : R1:", InpUseRule1, " R2:", InpUseRule2, " R3:", InpUseRule3, " All:", InpAllRules);
   Print(" ADX Filter : ", InpMinADX);
   Print(" News Filter: ", InpUseNewsFilt);
   Print("==========================================");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| ON DEINIT                                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(g_hRSI);
   IndicatorRelease(g_hCCI);
   IndicatorRelease(g_hEMA5);
   IndicatorRelease(g_hSMMA8);
   IndicatorRelease(g_hEMA10);
   IndicatorRelease(g_hSMA20);
   IndicatorRelease(g_hEMA50);
   IndicatorRelease(g_hEMA9);
   IndicatorRelease(g_hEMA21);
   IndicatorRelease(g_hADX);
   IndicatorRelease(g_hStochK);
   IndicatorRelease(g_hStochD);
   IndicatorRelease(g_hATR);
   
   Comment("");
   Print("=== 3 Musketeer Pro Deinitialized ===");
}

//+------------------------------------------------------------------+
//| ON TICK (Main Loop)                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Guard: new bar only
   datetime curBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(curBar == g_lastBarTime)
      return;
   g_lastBarTime = curBar;
   
   // Check equity drawdown protection
   if(!g_equityDDHit)
      CheckEquityProtection();
   
   // Trading hours check
   if(!IsTradingAllowed()) return;
   
   // News filter
   if(InpUseNewsFilt && IsHighImpactNews()) return;
   
   // Update daily profit
   UpdateDailyProfit();
   
   // Daily target check
   if(InpDailyTarget > 0 && g_dailyProfit >= InpDailyTarget)
   {
      CloseAllPositions("Daily Target Reached");
      return;
   }
   
   // Grid TP check
   if(InpUseGrid)
      CheckGridTP();
   
   // Hedging check
   if(InpUseHedge)
      CheckHedging();
   
   // Martingale / Grid auto-open
   if((InpUseMarti || InpUseGrid) && InpSL == 0)
      AutoAddPositions();
   
   // Trailing stop
   if(InpUseTrail)
      DoTrailingStop();
   
   // Partial TP
   if(InpUsePartial)
      DoPartialTP();
   
   // Rule 3 floating management
   ManageFloatingLosses();
   
   // Main signal detection
   ProcessSignals();
   
   // Display panel
   if(InpShowPanel)
      RenderPanel();
}

//+------------------------------------------------------------------+
//| INIT INDICATORS                                                  |
//+------------------------------------------------------------------+
bool InitIndicators()
{
   g_hRSI   = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
   g_hCCI   = iCCI(_Symbol, PERIOD_CURRENT, 14, PRICE_TYPICAL);
   g_hEMA5  = iMA(_Symbol, PERIOD_CURRENT, 5, 0, MODE_EMA, PRICE_CLOSE);
   g_hSMMA8 = iMA(_Symbol, PERIOD_CURRENT, 8, 0, MODE_SMMA, PRICE_TYPICAL);
   g_hEMA10 = iMA(_Symbol, PERIOD_CURRENT, 10, 0, MODE_EMA, PRICE_CLOSE);
   g_hSMA20 = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_SMA, PRICE_CLOSE);
   g_hEMA50 = iMA(_Symbol, PERIOD_CURRENT, 50, 0, MODE_EMA, PRICE_CLOSE);
   g_hEMA9  = iMA(_Symbol, PERIOD_CURRENT, 9, 0, MODE_EMA, PRICE_CLOSE);
   g_hEMA21 = iMA(_Symbol, PERIOD_CURRENT, 21, 0, MODE_EMA, PRICE_CLOSE);
   g_hADX   = iADX(_Symbol, PERIOD_CURRENT, 14);
   g_hATR   = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   
   // Stochastic
   g_hStochK = iStochastic(_Symbol, PERIOD_CURRENT, 14, 3, 3, MODE_SMA, STO_LOWHIGH);
   g_hStochD = iStochastic(_Symbol, PERIOD_CURRENT, 14, 3, 3, MODE_SMA, STO_LOWHIGH);
   
   string errors = "";
   if(g_hRSI   == INVALID_HANDLE) errors += "RSI ";
   if(g_hCCI   == INVALID_HANDLE) errors += "CCI ";
   if(g_hEMA5  == INVALID_HANDLE) errors += "EMA5 ";
   if(g_hSMMA8 == INVALID_HANDLE) errors += "SMMA8 ";
   if(g_hEMA10 == INVALID_HANDLE) errors += "EMA10 ";
   if(g_hSMA20 == INVALID_HANDLE) errors += "SMA20 ";
   if(g_hEMA50 == INVALID_HANDLE) errors += "EMA50 ";
   if(g_hEMA9  == INVALID_HANDLE) errors += "EMA9 ";
   if(g_hEMA21 == INVALID_HANDLE) errors += "EMA21 ";
   if(g_hADX   == INVALID_HANDLE) errors += "ADX ";
   if(g_hATR   == INVALID_HANDLE) errors += "ATR ";
   if(g_hStochK== INVALID_HANDLE) errors += "StochK ";
   if(g_hStochD== INVALID_HANDLE) errors += "StochD ";
   
   if(errors != "")
   {
      Print("INDICATOR ERRORS: ", errors);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| GET INDICATOR VALUES                                             |
//+------------------------------------------------------------------+
double GetVal(int handle, int shift=0)
{
   double buf[];
   if(CopyBuffer(handle, 0, shift, 1, buf) <= 0) return 0;
   return buf[0];
}
double GetVal2(int handle, int buffer=0, int shift=0)
{
   double buf[];
   if(CopyBuffer(handle, buffer, shift, 1, buf) <= 0) return 0;
   return buf[0];
}

#define RSI(shift)       GetVal(g_hRSI, shift)
#define CCI(shift)       GetVal(g_hCCI, shift)
#define EMA5(shift)      GetVal(g_hEMA5, shift)
#define SMMA8(shift)     GetVal(g_hSMMA8, shift)
#define EMA10(shift)     GetVal(g_hEMA10, shift)
#define SMA20(shift)     GetVal(g_hSMA20, shift)
#define EMA50(shift)     GetVal(g_hEMA50, shift)
#define EMA9(shift)      GetVal(g_hEMA9, shift)
#define EMA21(shift)     GetVal(g_hEMA21, shift)
#define ADX(shift)       GetVal(g_hADX, shift)
#define ATR(shift)        GetVal(g_hATR, shift)
#define STO_K(shift)     GetVal2(g_hStochK, 0, shift)
#define STO_D(shift)     GetVal2(g_hStochD, 0, shift)

bool GetRates(MqlRates &r[], int count=2)
{
   ArraySetAsSeries(r, true);
   return (CopyRates(_Symbol, PERIOD_CURRENT, 0, count, r) >= count);
}

//+------------------------------------------------------------------+
//| COMMON FILTERS (used by all rules)                                |
//+------------------------------------------------------------------+
bool PassCommonFilters(bool isBuy)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   
   // Spread filter
   if(InpMaxSpread > 0 && spread > InpMaxSpread)
   {
      //Print("BLOCKED: Spread ", spread, " > max ", InpMaxSpread);
      return false;
   }
   
   // ADX filter (trend strength)
   if(InpMinADX > 0)
   {
      double adx = ADX(0);
      if(adx < InpMinADX)
         return false;
   }
   
   // ATR filter
   if(InpUseATRFilt)
   {
      double atr = ATR(0);
      double atrPrev = ATR(1);
      if(atr < atrPrev * 0.8)  // ATR sedang menyusut = low volatility
         return false;
   }
   
   // Candle body minimum
   if(InpMinCandleBody > 0)
   {
      MqlRates r[];
      if(!GetRates(r, 1)) return false;
      double body = MathAbs(r[0].close - r[0].open);
      if(body < InpMinCandleBody * point)
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| NEWS FILTER (Simple Pip-based check)                             |
//+------------------------------------------------------------------+
bool IsHighImpactNews()
{
   // Simplified news filter based on high-impact trading hours
   // For production, integrate with a news indicator or CSV data
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   // Major news windows (UTC) - adjust to your broker time
   // NY Session High Impact: 13:30-14:00 UTC
   // London High Impact: 08:00-09:00 UTC
   // These are approximations - in production use an actual news database
   
   int utcHour = dt.hour + (int)((datetime)TimeCurrent() % 86400) / 3600;
   
   // Simple: block during typically high-volatility windows
   // You should replace this with actual news data integration
   bool blocked = false;
   
   // Note: This is a placeholder. In production, use an actual 
   // news event CSV or an indicator like ForexFactory parser.
   // The proper implementation would read from a news data file.
   
   return blocked;
}

//+------------------------------------------------------------------+
//| TRADING HOURS CHECK                                              |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
   if(!InpUseTimeFilt) return true;
   
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   if(dt.hour >= InpStartHour && dt.hour < InpEndHour)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| EQUITY PROTECTION                                                |
//+------------------------------------------------------------------+
void CheckEquityProtection()
{
   if(InpMaxEquityDD <= 0) return;
   
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   if(balance <= 0) return;
   
   double ddPct = (balance - equity) / balance * 100.0;
   
   if(ddPct >= InpMaxEquityDD)
   {
      Print("!!! EQUITY DRAWDOWN ", DoubleToString(ddPct,1), 
            "% TRIGGERED - CLOSING ALL POSITIONS !!!");
      CloseAllPositions("Equity DD: " + DoubleToString(ddPct,1) + "%");
      g_equityDDHit = true;
   }
}

//+------------------------------------------------------------------+
//| PROCESS SIGNALS (Rule-based entry logic)                         |
//+------------------------------------------------------------------+
void ProcessSignals()
{
   bool buySignal  = false;
   bool sellSignal = false;
   string ruleName = "";
   int buyCount = 0, sellCount = 0;
   CountPositions(buyCount, sellCount);
   
   // Determine if we're at max positions for Rule 3 floating management
   bool maxBuyReached  = (buyCount >= 3);
   bool maxSellReached = (sellCount >= 3);
   
   // Stop new signals if we've reached max floating positions (Rule 3)
   bool allowNewBuy  = !(InpUseRule3 && maxBuyReached);
   bool allowNewSell = !(InpUseRule3 && maxSellReached);
   
   // -- Rule 1 --
   if(InpUseRule1 || InpAllRules)
   {
      if(allowNewBuy && CheckRule1Buy())
         { buySignal = true; ruleName = "R1"; }
      
      if(allowNewSell && CheckRule1Sell())
         { sellSignal = true; ruleName = "R1"; }
   }
   
   // -- Rule 2 --
   if((InpUseRule2 || InpAllRules) && !buySignal && !sellSignal)
   {
      if(allowNewBuy && CheckRule2Buy())
         { buySignal = true; ruleName = "R2"; }
      
      if(allowNewSell && CheckRule2Sell())
         { sellSignal = true; ruleName = "R2"; }
   }
   
   // -- Rule 3 (most aggressive - opens even during floating) --
   if(InpUseRule3 || InpAllRules)
   {
      // Rule 3 still respects max position count
      if(CheckRule3Buy() && buyCount < 3)
         { buySignal = true; ruleName = "R3"; }
      
      if(CheckRule3Sell() && sellCount < 3)
         { sellSignal = true; ruleName = "R3"; }
   }
   
   // -- Execute --
   if(buySignal)
      OpenPosition(ORDER_TYPE_BUY, ruleName);
   
   if(sellSignal)
      OpenPosition(ORDER_TYPE_SELL, ruleName);
}

//+------------------------------------------------------------------+
//| RULE 1: RSI + CCI + MA Crossover                                 |
//+------------------------------------------------------------------+
bool CheckRule1Buy()
{
   // RSI 25-30 (tuned from 20), CCI -150 (stricter), EMA5<SMMA8
   // Confirmed by ADX filter already applied
   double rsi0   = RSI(0);
   double cci0   = CCI(0);
   double ema5_0 = EMA5(0);
   double ema5_1 = EMA5(1);
   double smma8_0 = SMMA8(0);
   double smma8_1 = SMMA8(1);
   double adx = ADX(0);
   
   bool rsiOK  = (rsi0 >= 25 && rsi0 < 50);    // Oversold but recovering
   bool cciOK  = (cci0 < -100);               // Extreme bearish
   bool maOK   = (ema5_0 < smma8_0);          // Downtrend confirmed
   bool adxOK  = (adx >= InpMinADX);
   
   // MA cross into downtrend (was above, now below)
   bool cross = (ema5_1 >= smma8_1) && (ema5_0 < smma8_0);
   
   if(rsiOK && cciOK && maOK && adxOK)
   {
      Print("[R1 BUY] RSI=", rsi0, " CCI=", cci0, 
            " EMA5=", ema5_0, " SMMA8=", smma8_0, " ADX=", adx);
      return true;
   }
   return false;
}

bool CheckRule1Sell()
{
   double rsi0   = RSI(0);
   double cci0   = CCI(0);
   double ema5_0 = EMA5(0);
   double ema5_1 = EMA5(1);
   double smma8_0 = SMMA8(0);
   double smma8_1 = SMMA8(1);
   double adx = ADX(0);
   
   bool rsiOK = (rsi0 <= 75 && rsi0 > 50);     // Overbought but reversing
   bool cciOK = (cci0 > 100);                  // Extreme bullish
   bool maOK  = (ema5_0 > smma8_0);            // Uptrend confirmed
   bool adxOK = (adx >= InpMinADX);
   bool cross = (ema5_1 <= smma8_1) && (ema5_0 > smma8_0);
   
   if(rsiOK && cciOK && maOK && adxOK)
   {
      Print("[R1 SELL] RSI=", rsi0, " CCI=", cci0,
            " EMA5=", ema5_0, " SMMA8=", smma8_0, " ADX=", adx);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| RULE 2: EMA10 Cross SMA20 + Candle + RSI                         |
//+------------------------------------------------------------------+
bool CheckRule2Buy()
{
   MqlRates r[];
   if(!GetRates(r, 2)) return false;
   
   double ema10_0 = EMA10(0);
   double ema10_1 = EMA10(1);
   double sma20_0 = SMA20(0);
   double sma20_1 = SMA20(1);
   double rsi0    = RSI(0);
   double adx     = ADX(0);
   double stoK    = STO_K(0);
   double stoD    = STO_D(0);
   
   // EMA10 crosses above SMA20
   bool crossUp = (ema10_1 < sma20_1) && (ema10_0 >= sma20_0);
   
   // Candle closes above EMA10
   bool candleAbove = (r[0].close > ema10_0);
   
   // RSI > 50 with confirmation
   bool rsiOK = (rsi0 > 50);
   
   // ADX trend filter (stricter for Rule 2)
   bool adxOK = (adx >= MathMax(InpMinADX, 30));
   
   // Stochastic oversold filter
   bool stochOK = (stoK < 50);  // Below midline = bullish confirmation
   
   if(crossUp && candleAbove && rsiOK && adxOK && stochOK)
   {
      Print("[R2 BUY] EMA10=", ema10_0, " SMA20=", sma20_0,
            " RSI=", rsi0, " Stoch=", stoK, "/", stoD, " ADX=", adx);
      return true;
   }
   return false;
}

bool CheckRule2Sell()
{
   MqlRates r[];
   if(!GetRates(r, 2)) return false;
   
   double ema10_0 = EMA10(0);
   double ema10_1 = EMA10(1);
   double sma20_0 = SMA20(0);
   double sma20_1 = SMA20(1);
   double rsi0    = RSI(0);
   double adx     = ADX(0);
   double stoK    = STO_K(0);
   double stoD    = STO_D(0);
   
   bool crossDown = (ema10_1 > sma20_1) && (ema10_0 <= sma20_0);
   bool candleBelow = (r[0].close < ema10_0);
   bool rsiOK = (rsi0 < 50);
   bool adxOK = (adx >= MathMax(InpMinADX, 30));
   bool stochOK = (stoK > 50);  // Above midline = bearish confirmation
   
   if(crossDown && candleBelow && rsiOK && adxOK && stochOK)
   {
      Print("[R2 SELL] EMA10=", ema10_0, " SMA20=", sma20_0,
            " RSI=", rsi0, " Stoch=", stoK, "/", stoD, " ADX=", adx);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| RULE 3: Candle>EMA50 + EMA9 cross EMA21 + RSI                     |
//+------------------------------------------------------------------+
bool CheckRule3Buy()
{
   MqlRates r[];
   if(!GetRates(r, 2)) return false;
   
   double ema50_0 = EMA50(0);
   double ema9_0  = EMA9(0);
   double ema9_1  = EMA9(1);
   double ema21_0 = EMA21(0);
   double ema21_1 = EMA21(1);
   double rsi0    = RSI(0);
   double adx     = ADX(0);
   
   // Candle above EMA50
   bool candleAbove = (r[0].close > ema50_0);
   
   // EMA9 crosses above EMA21
   bool crossUp = (ema9_1 < ema21_1) && (ema9_0 >= ema21_0);
   
   // RSI > 50
   bool rsiOK = (rsi0 > 50);
   
   // ADX filter
   bool adxOK = (adx >= InpMinADX);
   
   if(candleAbove && crossUp && rsiOK && adxOK)
   {
      Print("[R3 BUY] EMA9=", ema9_0, " EMA21=", ema21_0,
            " EMA50=", ema50_0, " RSI=", rsi0, " ADX=", adx);
      return true;
   }
   return false;
}

bool CheckRule3Sell()
{
   MqlRates r[];
   if(!GetRates(r, 2)) return false;
   
   double ema50_0 = EMA50(0);
   double ema9_0  = EMA9(0);
   double ema9_1  = EMA9(1);
   double ema21_0 = EMA21(0);
   double ema21_1 = EMA21(1);
   double rsi0    = RSI(0);
   double adx     = ADX(0);
   
   bool candleBelow = (r[0].close < ema50_0);
   bool crossDown = (ema9_1 > ema21_1) && (ema9_0 <= ema21_0);
   bool rsiOK = (rsi0 < 50);
   bool adxOK = (adx >= InpMinADX);
   
   if(candleBelow && crossDown && rsiOK && adxOK)
   {
      Print("[R3 SELL] EMA9=", ema9_0, " EMA21=", ema21_0,
            " EMA50=", ema50_0, " RSI=", rsi0, " ADX=", adx);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| OPEN POSITION                                                    |
//+------------------------------------------------------------------+
void OpenPosition(ENUM_ORDER_TYPE type, string ruleName)
{
   // Prevent rapid-fire same-direction entries
   datetime now = TimeCurrent();
   if(now - g_lastTradeTime < 30)  // min 30 sec between trades
      return;
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double price = (type == ORDER_TYPE_BUY) ? ask : bid;
   
   double lot = InpLot;
   
   // Martingale lot sizing (only when SL=0)
   if(InpUseMarti && InpSL == 0)
   {
      lot = GetMartingaleLot(type);
   }
   
   // Safety cap
   lot = MathMin(lot, InpMaxLot);
   
   // Calculate SL and TP
   double slPts   = InpSL * point;
   double tpPts   = InpTP * point;
   double sl = 0, tp = 0;
   
   if(type == ORDER_TYPE_BUY)
   {
      sl = (InpSL > 0) ? price - slPts : 0;
      tp = price + tpPts;
      
      if(InpUseMarti && InpSL == 0)
         tp = price + InpMartiStep * point;
      
      if(InpUseGrid && InpSL == 0)
         tp = price + InpGridDist * point;
   }
   else
   {
      sl = (InpSL > 0) ? price + slPts : 0;
      tp = price - tpPts;
      
      if(InpUseMarti && InpSL == 0)
         tp = price - InpMartiStep * point;
      
      if(InpUseGrid && InpSL == 0)
         tp = price - InpGridDist * point;
   }
   
   string comment = InpEAComment + " [" + ruleName + "]";
   
   bool result;
   if(type == ORDER_TYPE_BUY)
      result = g_trade.Buy(lot, _Symbol, price, sl, tp, comment);
   else
      result = g_trade.Sell(lot, _Symbol, price, sl, tp, comment);
   
   if(result)
   {
      ulong ticket = g_trade.ResultOrder();
      Print(">>> ", ruleName, " ", (type==ORDER_TYPE_BUY?"BUY":"SELL"),
            " OPEN | Lot=", DoubleToString(lot,2),
            " Price=", price, " SL=", sl, " TP=", tp,
            " Ticket=", ticket);
      g_lastTradeTime = now;
      
      // Update marti/grid level
      if(type == ORDER_TYPE_BUY) g_martiLevelBuy++;
      else                       g_martiLevelSell++;
   }
   else
   {
      Print("!!! ORDER FAILED !!! Code:", g_trade.ResultRetCode(),
            " Desc:", g_trade.ResultRetCodeDescription());
   }
}

//+------------------------------------------------------------------+
//| MARTINGALE LOT CALCULATION (FIXED BUG)                            |
//+------------------------------------------------------------------+
double GetMartingaleLot(ENUM_ORDER_TYPE type)
{
   // Find the most recent position of the same type
   double lastLot = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      // Match direction
      bool sameDirection = (type == ORDER_TYPE_BUY && posType == POSITION_TYPE_BUY) ||
                           (type == ORDER_TYPE_SELL && posType == POSITION_TYPE_SELL);
      
      if(sameDirection)
      {
         lastLot = MathMax(lastLot, PositionGetDouble(POSITION_VOLUME));
      }
   }
   
   if(lastLot > 0)
   {
      // Progressive: more conservative at higher levels
      double mult = InpMartiMult;
      // Level-based multiplier decay (safer)
      int level = (type == ORDER_TYPE_BUY) ? g_martiLevelBuy : g_martiLevelSell;
      if(level >= 3)
         mult = MathMax(1.1, InpMartiMult - 0.05 * (level - 2));
      
      return MathMin(lastLot * mult, InpMaxLot);
   }
   
   return InpLot;
}

//+------------------------------------------------------------------+
//| AUTO ADD POSITIONS (Martingale / Grid)                            |
//+------------------------------------------------------------------+
void AutoAddPositions()
{
   if(InpSL > 0) return;  // Single entry mode, no auto-add
   
   double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double bid      = SymbolInfoDouble(_Symbol, BID);
   double ask      = SymbolInfoDouble(_Symbol, ASK);
   
   // Get average price and count of positions per direction
   int buyCount = 0, sellCount = 0;
   double buyAvgPrice = 0, sellAvgPrice = 0;
   double totalBuyLots = 0, totalSellLots = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double lot = PositionGetDouble(POSITION_VOLUME);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      
      if(posType == POSITION_TYPE_BUY)
      {
         buyAvgPrice += openPrice * lot;
         totalBuyLots += lot;
         buyCount++;
      }
      else
      {
         sellAvgPrice += openPrice * lot;
         totalSellLots += lot;
         sellCount++;
      }
   }
   
   if(totalBuyLots > 0)  buyAvgPrice  /= totalBuyLots;
   if(totalSellLots > 0) sellAvgPrice /= totalSellLots;
   
   // Martingale / Grid auto-open logic
   double step = (InpUseGrid && InpSL == 0) ? InpGridDist : InpMartiStep;
   step *= point;
   
   // BUY side: if price dropped below avg by step distance
   if(buyCount > 0 && buyCount < InpMaxMartiLvl && buyCount < InpMaxGridLvls)
   {
      if(bid <= buyAvgPrice - step)
      {
         // Check ADX for trend continuation
         if(ADX(0) >= InpMinADX && !PassCommonFilters(true))
            return;
         
         // Marti level for buy direction
         int currentLvl = g_martiLevelBuy;
         if(currentLvl < InpMaxMartiLvl)
            OpenPosition(ORDER_TYPE_BUY, (InpUseGrid ? "R3-GRID" : "R3-MARTI"));
      }
   }
   
   // SELL side
   if(sellCount > 0 && sellCount < InpMaxMartiLvl && sellCount < InpMaxGridLvls)
   {
      if(ask >= sellAvgPrice + step)
      {
         if(ADX(0) >= InpMinADX && !PassCommonFilters(false))
            return;
         
         int currentLvl = g_martiLevelSell;
         if(currentLvl < InpMaxMartiLvl)
            OpenPosition(ORDER_TYPE_SELL, (InpUseGrid ? "R3-GRID" : "R3-MARTI"));
      }
   }
}

//+------------------------------------------------------------------+
//| COUNT POSITIONS                                                  |
//+------------------------------------------------------------------+
void CountPositions(int &buyCnt, int &sellCnt)
{
   buyCnt  = 0;
   sellCnt = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(posType == POSITION_TYPE_BUY)  buyCnt++;
      else                              sellCnt++;
   }
}

//+------------------------------------------------------------------+
//| TOTAL FLOATING PROFIT                                             |
//+------------------------------------------------------------------+
double GetTotalFloatingPL()
{
   double total = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      
      total += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return total;
}

//+------------------------------------------------------------------+
//| FLOATING LOSS (negative)                                         |
//+------------------------------------------------------------------+
double GetTotalFloatingLoss()
{
   double loss = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      
      double p = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(p < 0) loss += MathAbs(p);
   }
   return loss;
}

//+------------------------------------------------------------------+
//| FLOATING PIP (Points distance)                                   |
//+------------------------------------------------------------------+
double GetFloatingPips(bool isBuy)
{
   double totalPts = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool matchDir = (isBuy && posType == POSITION_TYPE_BUY) ||
                      (!isBuy && posType == POSITION_TYPE_SELL);
      if(!matchDir) continue;
      
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double curPrice  = PositionGetDouble(POSITION_PRICE_CURRENT);
      totalPts += MathAbs(curPrice - openPrice);
   }
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return (point > 0) ? totalPts / point : 0;
}

//+------------------------------------------------------------------+
//| GRID TP                                                          |
//+------------------------------------------------------------------+
void CheckGridTP()
{
   double total = GetTotalFloatingPL();
   if(total >= InpGridTP)
   {
      Print("=== GRID TP TRIGGERED: Total=", total, " >= Target=", InpGridTP, " ===");
      CloseAllPositions("GridTP");
   }
}

//+------------------------------------------------------------------+
//| HEDGING                                                          |
//+------------------------------------------------------------------+
void CheckHedging()
{
   if(!InpUseHedge) return;
   
   bool isBuy;
   double avgPrice;
   double floatPts = GetFloatingPips(isBuy);
   
   if(floatPts >= InpHedgePip)
   {
      if(g_hedgeActive) return;  // Already hedged
      if(!IsTradingAllowed()) return;
      if(InpUseNewsFilt && IsHighImpactNews()) return;
      
      ENUM_ORDER_TYPE hedgeType = isBuy ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
      double price = (hedgeType == ORDER_TYPE_BUY) ?
                     SymbolInfoDouble(_Symbol, SYMBOL_ASK) :
                     SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      double lot = InpHedgeLot;
      
      // Marti hedge
      if(InpUseMarti)
         lot = MathMin(InpHedgeLot * InpHedgeMult, InpMaxLot);
      
      string comment = InpEAComment + " [HEDGE]";
      bool result;
      
      if(hedgeType == ORDER_TYPE_BUY)
         result = g_trade.Buy(lot, _Symbol, price, 0, 0, comment);
      else
         result = g_trade.Sell(lot, _Symbol, price, 0, 0, comment);
      
      if(result)
      {
         Print(">>> HEDGE ", (isBuy?"SELL":"BUY"), " Lot=", lot,
               " Price=", price, " Ticket=", g_trade.ResultOrder());
         g_hedgeActive = true;
      }
   }
   else
   {
      g_hedgeActive = false;
   }
}

//+------------------------------------------------------------------+
//| TRAILING STOP                                                    |
//+------------------------------------------------------------------+
void DoTrailingStop()
{
   if(InpTrailStop <= 0 || InpTrailStart <= 0) return;
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double startPts = InpTrailStart * point;
   double stopPts  = InpTrailStop  * point;
   double ask = SymbolInfoDouble(_Symbol, ASK);
   double bid = SymbolInfoDouble(_Symbol, BID);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      
      ulong ticket     = PositionGetTicket(i);
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double openPrice  = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl         = PositionGetDouble(POSITION_SL);
      double tp         = PositionGetDouble(POSITION_TP);
      
      if(posType == POSITION_TYPE_BUY)
      {
         double profit = bid - openPrice;
         if(profit >= startPts)
         {
            double newSL = bid - stopPts;
            if(newSL > sl && sl != 0)
               g_trade.PositionModify(ticket, newSL, tp);
            else if(sl == 0)
               g_trade.PositionModify(ticket, newSL, tp);  // Set initial SL
         }
      }
      else
      {
         double profit = openPrice - ask;
         if(profit >= startPts)
         {
            double newSL = ask + stopPts;
            if((newSL < sl || sl == 0) && sl != 0)
               g_trade.PositionModify(ticket, newSL, tp);
            else if(sl == 0)
               g_trade.PositionModify(ticket, newSL, tp);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| PARTIAL TP                                                       |
//+------------------------------------------------------------------+
void DoPartialTP()
{
   if(InpPartialPct <= 0) return;
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double ask   = SymbolInfoDouble(_Symbol, ASK);
   double bid   = SymbolInfoDouble(_Symbol, BID);
   double pct   = InpPartialPct / 100.0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      
      ulong ticket     = PositionGetTicket(i);
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double openPrice  = PositionGetDouble(POSITION_PRICE_OPEN);
      double tp         = PositionGetDouble(POSITION_TP);
      double lot        = PositionGetDouble(POSITION_VOLUME);
      double closeLot   = NormalizeDouble(lot * pct, 2);
      
      if(closeLot < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) continue;
      
      if(posType == POSITION_TYPE_BUY)
      {
         if(tp <= 0) continue;
         
         double tpDist      = tp - openPrice;
         double currentDist = bid - openPrice;
         
         // Trigger at 50% of TP distance (or InpPartialLvl %)
         double triggerDist = tpDist * (InpPartialLvl / 100.0);
         
         if(currentDist >= triggerDist && lot > closeLot * 1.1)
         {
            if(g_trade.PositionClose(ticket, closeLot))
            {
               Print(">>> PARTIAL TP BUY: Ticket=", ticket, " ClosedLot=", closeLot,
                     " Bid=", bid, " TP=", tp);
               
               // Move TP for remaining position
               double remaining = lot - closeLot;
               if(remaining > 0)
               {
                  double newTP = tp + (tpDist * 0.5);  // Extend TP by 50%
                  double newSL = PositionGetDouble(POSITION_SL);
                  g_trade.PositionModify(ticket, newSL, newTP);
               }
            }
         }
      }
      else  // SELL
      {
         if(tp <= 0) continue;
         
         double tpDist      = openPrice - tp;
         double currentDist = openPrice - ask;
         double triggerDist = tpDist * (InpPartialLvl / 100.0);
         
         if(currentDist >= triggerDist && lot > closeLot * 1.1)
         {
            if(g_trade.PositionClose(ticket, closeLot))
            {
               Print(">>> PARTIAL TP SELL: Ticket=", ticket, " ClosedLot=", closeLot,
                     " Ask=", ask, " TP=", tp);
               
               double remaining = lot - closeLot;
               if(remaining > 0)
               {
                  double newTP = tp - (tpDist * 0.5);
                  double newSL = PositionGetDouble(POSITION_SL);
                  g_trade.PositionModify(ticket, newSL, newTP);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| MANAGE FLOATING LOSSES (Rule 3 Feature)                          |
//| - Close losing positions when other positions profit enough     |
//| - Profit must exceed loss by 30% margin (2x → 2.3x in v2)      |
//+------------------------------------------------------------------+
void ManageFloatingLosses()
{
   if(!InpUseRule3) return;
   
   double totalProfit = GetTotalFloatingPL();
   double totalLoss   = GetTotalFloatingLoss();
   
   if(totalProfit <= 0) return;  // No overall profit yet
   if(totalLoss <= 0)   return;  // No losses to recover
   
   // Profit must EXCEED loss by 30% margin before cutting losses
   // e.g., Loss = $50, Need Profit > $65 to close losing positions
   double threshold = totalLoss * 2.3;
   
   if(totalProfit >= threshold)
   {
      Print("[R3 FLOATING MGMT] Profit=", totalProfit, 
            " Loss=", totalLoss, " Threshold=", threshold);
      
      // Close the most negative positions first (up to 2 per check)
      int closedCount = 0;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionGetSymbol(i) != _Symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
         if(closedCount >= 2) break;  // Max 2 closes per tick
         
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         
         if(profit < 0)
         {
            ulong ticket = PositionGetTicket(i);
            if(g_trade.PositionClose(ticket))
            {
               Print(">>> R3 FLOATING CLOSE: Ticket=", ticket,
                     " Loss=", DoubleToString(profit,2),
                     " Rule=R3");
               
               // Update marti levels
               if(posType == POSITION_TYPE_BUY)  g_martiLevelBuy--;
               else                               g_martiLevelSell--;
               
               totalLoss -= MathAbs(profit);
               closedCount++;
            }
         }
      }
      
      // After closing, check if we still have excess profit
      double remainingProfit = GetTotalFloatingPL();
      if(remainingProfit < 0)
      {
         // Turned negative, stop closing
         Print("WARNING: Floating management overclosed, remaining=", remainingProfit);
      }
   }
}

//+------------------------------------------------------------------+
//| CLOSE ALL POSITIONS                                              |
//+------------------------------------------------------------------+
void CloseAllPositions(string reason)
{
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      
      ulong ticket = PositionGetTicket(i);
      if(g_trade.PositionClose(ticket))
         closed++;
   }
   
   Print("=== CLOSED ", closed, " positions. Reason: ", reason, " ===");
   g_hedgeActive = false;
   g_martiLevelBuy  = 0;
   g_martiLevelSell = 0;
}

//+------------------------------------------------------------------+
//| UPDATE DAILY PROFIT                                              |
//+------------------------------------------------------------------+
void UpdateDailyProfit()
{
   datetime today = (datetime)MathFloor((double)TimeCurrent() / 86400.0);
   if(today != g_lastTradeDay)
   {
      g_lastTradeDay = today;
      g_dailyProfit = 0;
      g_equityDDHit = false;
      g_martiLevelBuy  = 0;
      g_martiLevelSell = 0;
   }
   
   HistorySelect(0, TimeCurrent());
   double todayProfit = 0;
   
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(deal, DEAL_MAGIC) != InpMagic) continue;
      
      datetime dealDay = (datetime)MathFloor((double)HistoryDealGetInteger(deal, DEAL_TIME) / 86400.0);
      if(dealDay == today)
      {
         todayProfit += HistoryDealGetDouble(deal, DEAL_PROFIT)
                     + HistoryDealGetDouble(deal, DEAL_COMMISSION)
                     + HistoryDealGetDouble(deal, DEAL_SWAP);
      }
   }
   g_dailyProfit = todayProfit;
}

//+------------------------------------------------------------------+
//| RENDER INFO PANEL                                                |
//+------------------------------------------------------------------+
void RenderPanel()
{
   string sym   = _Symbol;
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   double ask   = SymbolInfoDouble(sym, SYMBOL_ASK);
   double bid   = SymbolInfoDouble(sym, SYMBOL_BID);
   double spread= SymbolInfoInteger(sym, SYMBOL_SPREAD);
   double bal   = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq    = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // Indicators
   double rsi   = RSI(0),    cci   = CCI(0);
   double ema5  = EMA5(0),  smma8 = SMMA8(0);
   double ema10 = EMA10(0), sma20 = SMA20(0);
   double ema9  = EMA9(0),  ema21 = EMA21(0);
   double ema50 = EMA50(0), adx   = ADX(0);
   double stoK  = STO_K(0), stoD  = STO_D(0);
   
   // Positions
   int buyCnt = 0, sellCnt = 0;
   CountPositions(buyCnt, sellCnt);
   double totalPL = GetTotalFloatingPL();
   double totalLots = 0;
   for(int i = PositionsTotal()-1; i>=0; i--)
   {
      if(PositionGetSymbol(i)==sym && PositionGetInteger(POSITION_MAGIC)==InpMagic)
         totalLots += PositionGetDouble(POSITION_VOLUME);
   }
   
   // Active rules
   string rules = "";
   if(InpUseRule1) rules += "R1 ";
   if(InpUseRule2) rules += "R2 ";
   if(InpUseRule3) rules += "R3 ";
   if(InpAllRules) rules = "ALL";
   
   // Trend
   string trend = "NEUTRAL";
   if(rsi > 55 && adx > 25) trend = "BULL ";
   if(rsi < 45 && adx > 25) trend = "BEAR ";
   if(adx < 20) trend = "RANGE";
   
   // Signals
   bool r1b=CheckRule1Buy(), r1s=CheckRule1Sell();
   bool r2b=CheckRule2Buy(), r2s=CheckRule2Sell();
   bool r3b=CheckRule3Buy(), r3s=CheckRule3Sell();
   
   string signals = "";
   if(r1b) signals="[R1 BUY] "; else if(r1s) signals="[R1 SELL] ";
   else if(r2b) signals="[R2 BUY] "; else if(r2s) signals="[R2 SELL] ";
   else if(r3b) signals="[R3 BUY] "; else if(r3s) signals="[R3 SELL] ";
   else signals="--";
   
   string plColor = (totalPL >= 0) ? "\n" : "";  // will use in text
   string plStr = (totalPL >= 0) ? "+" : "";
   
   string txt = "";
   txt += "========================================\n";
   txt += "     3 MUSKETEER PRO v2.00\n";
   txt += "========================================\n";
   txt += "Symbol   : " + sym + "\n";
   txt += "Ask      : " + DoubleToString(ask, _Digits) + "\n";
   txt += "Bid      : " + DoubleToString(bid, _Digits) + "\n";
   txt += "Spread   : " + IntegerToString((int)spread) + " pts\n";
   txt += "----------------------------------------\n";
   txt += "INDICATORS:\n";
   txt += "RSI(14)  : " + DoubleToString(rsi, 1) + 
          (rsi < 30 ? " [OS]" : rsi > 70 ? " [OB]" : "") + "\n";
   txt += "CCI(14)  : " + DoubleToString(cci, 1) + "\n";
   txt += "ADX(14)  : " + DoubleToString(adx, 1) + 
          (adx >= InpMinADX ? " [OK]" : " [LOW]") + "\n";
   txt += "STO(14)  : " + DoubleToString(stoK, 1) + "/" + DoubleToString(stoD, 1) + "\n";
   txt += "EMA5     : " + DoubleToString(ema5, _Digits) + "\n";
   txt += "SMMA8    : " + DoubleToString(smma8, _Digits) + "\n";
   txt += "EMA9     : " + DoubleToString(ema9, _Digits) + "\n";
   txt += "EMA21    : " + DoubleToString(ema21, _Digits) + "\n";
   txt += "EMA10    : " + DoubleToString(ema10, _Digits) + "\n";
   txt += "SMA20    : " + DoubleToString(sma20, _Digits) + "\n";
   txt += "EMA50    : " + DoubleToString(ema50, _Digits) + "\n";
   txt += "----------------------------------------\n";
   txt += "STATUS   : " + trend + "\n";
   txt += "Rules    : " + rules + "\n";
   txt += "----------------------------------------\n";
   txt += "POSITIONS (" + IntegerToString(buyCnt+sellCnt) + "):\n";
   txt += "Buy      : " + IntegerToString(buyCnt) + " | Sell: " + IntegerToString(sellCnt) + "\n";
   txt += "Total Lot: " + DoubleToString(totalLots, 2) + "\n";
   txt += "Floating : " + plStr + DoubleToString(totalPL, 2) + " " + 
          AccountInfoString(ACCOUNT_CURRENCY) + "\n";
   txt += "----------------------------------------\n";
   txt += "MONEY MGMT:\n";
   txt += "Lot      : " + DoubleToString(InpLot, 2) + 
          " | Max: " + DoubleToString(InpMaxLot, 2) + "\n";
   txt += "TP       : " + DoubleToString(InpTP, 0) + " pts\n";
   txt += "SL       : " + (InpSL==0?"MARTI":DoubleToString(InpSL,0)+" pts") + "\n";
   txt += "Trail    : " + DoubleToString(InpTrailStart,0) + "/" + 
          DoubleToString(InpTrailStop,0) + " pts\n";
   txt += "Marti    : " + (InpUseMarti?"ON x"+DoubleToString(InpMartiMult,2)+
          " Lvl:"+IntegerToString(g_martiLevelBuy)+"/"+IntegerToString(g_martiLevelSell):"OFF") + "\n";
   txt += "Grid     : " + (InpUseGrid?"ON "+DoubleToString(InpGridDist,0)+"pts":
          "OFF") + " | GridTP: "+DoubleToString(InpGridTP,0)+"\n";
   txt += "Hedge    : " + (InpUseHedge?"ON >="+DoubleToString(InpHedgePip,0)+"pts":
          "OFF") + " | Active: " + (g_hedgeActive?"YES":"NO") + "\n";
   txt += "PartialTP: " + (InpUsePartial?DoubleToString(InpPartialPct,0)+"% at "+
          DoubleToString(InpPartialLvl,0)+"% TP":"OFF") + "\n";
   txt += "ADX Filter: Min=" + IntegerToString(InpMinADX) + " | Current=" + 
          DoubleToString(adx, 1) + "\n";
   txt += "----------------------------------------\n";
   txt += "ACCOUNT:\n";
   txt += "Balance  : " + DoubleToString(bal, 2) + " " + 
          AccountInfoString(ACCOUNT_CURRENCY) + "\n";
   txt += "Equity   : " + DoubleToString(eq, 2) + "\n";
   txt += "DD Limit : " + DoubleToString(InpMaxEquityDD, 1) + "%" +
          (g_equityDDHit?" [TRIGGERED]":"") + "\n";
   txt += "Daily P/L: " + plStr + DoubleToString(g_dailyProfit, 2) + "\n";
   txt += "Target   : " + DoubleToString(InpDailyTarget, 0) + "\n";
   txt += "----------------------------------------\n";
   txt += "SIGNAL   : " + signals + "\n";
   txt += "========================================\n";
   
   Comment(txt);
}

//+------------------------------------------------------------------+
//| CHART EVENT                                                      |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, 
                  const double &dparam, const string &sparam)
{
   // Reserved for future expansion (button clicks, etc.)
}