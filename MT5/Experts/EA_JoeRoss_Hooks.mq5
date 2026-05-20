//+------------------------------------------------------------------+
//|           EA_JoeRoss_Hooks.mq5                                   |
//|        Joe Ross 1-2-3 + Ross Hooks Trading System                |
//|        v1.0 — Omon-Omon Algo Traders | Cuancux Community          |
//|                                                                 |
//|  Strategy Reference:                                            |
//|  https://blog.roboforex.com/blog/2019/12/26/joe-ross-trading-    |
//|  strategy-using-hooks/                                          |
//+------------------------------------------------------------------+
#property copyright "Omon-Omon Algo Traders"
#property version   "1.00"
#property strict
#property description "Joe Ross 1-2-3 + Ross Hooks EA v1.0"
#property description "Pattern 1-2-3 reversal + Ross Hook entry + Reversal Hook"
#property description "SL: Natural S/R | TP: Fib Extension | Modes: Swing/Scalp/Hybrid"

//+------------------------------------------------------------------+
//| INCLUDES                                                         |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
#include <Indicators/Indicators.mqh>

//+------------------------------------------------------------------+
//| INPUTS — PATTERN SETTINGS                                         |
//+------------------------------------------------------------------+
group("1-2-3 Pattern Settings")
input int      InpSwingPeriod    = 5;          // Swing Pivot Period
input int      InpMinSwingSize   = 30;         // Min Swing Size (points * 10^digits)
input bool     InpAllowReversal  = true;       // Allow Reversal Hook trades
input int      InpHookLookback   = 10;         // Hook detection lookback bars
input double   InpHookRetraceMax = 0.618;      // Max retrace for valid Hook (Fib)

group("Fibonacci Settings")
input int      InpFibExt1        = 127;        // Fibonacci Extension 1 (%)
input int      InpFibExt2        = 161;        // Fibonacci Extension 2 (%)
input int      InpFibExt3        = 200;        // Fibonacci Extension 3 (%)

group("Trend Filter (EMA)")
input bool     InpUseTrendFilter = true;       // Use EMA trend filter
input int      InpEmaFast        = 8;          // Fast EMA period
input int      InpEmaSlow        = 21;         // Slow EMA period
input int      InpEmaTrend        = 50;         // Trend EMA period

group("Stop Loss & Take Profit")
input double   InpAtrMultSL      = 1.5;        // SL = ATR * multiplier
input int      InpAtSLPeriod      = 14;         // ATR period for SL
input int      InpSLBuffer        = 2;          // SL buffer (points)
input bool     InpUseFibTP        = true;       // Use Fib TP levels
input double   InpAtrMultTP       = 2.5;        // Alternative: ATR-based TP
input int      InpTPDivisions     = 3;          // TP divisions (1/2/3)

group("Volume Filter")
input bool     InpUseVolFilter    = true;       // Require volume confirmation
input double   InpVolMultiplier   = 1.3;        // Volume must be > MA * mult

group("Trade Management")
input double   InpRiskPercent     = 1.0;        // Risk per trade (%)
input double   InpMaxLot          = 2.0;        // Max lot size
input int      InpMaxPositions    = 3;          // Max open positions
input int      InpMagicNumber     = 20261219;   // Magic number
input int      InpSlippage        = 3;          // Slippage (points)
input int      InpTradeCooldown    = 300;        // Trade cooldown (seconds)

group("Trade Mode")
input ENUM_JR_MODE InpTradeMode   = JR_MODE_HYBRID; // Trading mode
input bool     InpAllowSwing      = true;       // Allow Swing mode trades
input bool     InpAllowScalp      = true;       // Allow Scalp mode trades

group("EA Control")
input bool     InpAutoTrading     = true;        // Enable auto trading
input bool     InpShowDashboard   = true;        // Show dashboard comment

//+------------------------------------------------------------------+
//| ENUMS & STRUCTS                                                  |
//+------------------------------------------------------------------+
enum ENUM_JR_MODE {
   JR_MODE_SWING,   // Hold 1-5 days, wider SL
   JR_MODE_SCALP,   // Quick in/out, tight SL
   JR_MODE_HYBRID   // HTF bias + LTF execution (default)
};

enum ENUM_JR_PATTERN {
   PATTERN_NONE,
   PATTERN_BULL_123,    // Bullish 1-2-3
   PATTERN_BEAR_123,   // Bearish 1-2-3
   PATTERN_BULL_REVERSAL, // Bullish Reversal Hook
   PATTERN_BEAR_REVERSAL  // Bearish Reversal Hook
};

enum ENUM_JR_HOOK_STATE {
   HOOK_NONE,
   HOOK_FORMING,    // Retracement in progress
   HOOK_ACTIVE,     // Hook formed, waiting for breakout
   HOOK_BROKEN      // Hook broken, entry triggered
};

struct SPivotPoint {
   datetime time;
   double   price;
   int      barIdx;
   int      type;     // 1=high, -1=low
};

struct SPattern123 {
   ENUM_JR_PATTERN pattern;
   SPivotPoint     p1;     // Point 1 (origin)
   SPivotPoint     p2;     // Point 2 (impulse end)
   SPivotPoint     p3;     // Point 3 (retrace)
   SPivotPoint     hook;   // Ross Hook point
   ENUM_JR_HOOK_STATE hookState;
   datetime        hookBreakTime;
   double          entryPrice;
   double          stopLoss;
   double          takeProfit1;
   double          takeProfit2;
   double          takeProfit3;
   double          rrRatio;
   int             confidence;
   bool            triggered;
   bool            invalid;
   datetime        detectionTime;
};

struct SFibLevels {
   double   level0;    // 100%
   double   level127;
   double   level161;
   double   level200;
   double   level261;
};

//+------------------------------------------------------------------+
//| GLOBAL OBJECTS                                                   |
//+------------------------------------------------------------------+
CTrade          gTrade;
CPositionInfo   gPosition;
COrderInfo      gOrder;

CiATR          *gAtrHandle;
CiEMA          *gEmaFastHandle;
CiEMA          *gEmaSlowHandle;
CiEMA          *gEmaTrendHandle;
CiMA           *gVolMaHandle;

SPattern123     gCurrentPattern;
SPattern123     gHistoricalPatterns[];
datetime        gLastBarTime      = 0;
datetime        gLastTradeTime    = 0;
int             gSpreadFilter     = 50;
bool            gNewPatternAlert  = false;
string          gAlertMessage     = "";

//+------------------------------------------------------------------+
//| INIT                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- CTrade setup
   gTrade.SetExpertMagicNumber(InpMagicNumber);
   gTrade.SetDeviationInPoints(InpSlippage);
   gTrade.SetTypeFilling(ORDER_FILLING_FOK);
   gTrade.SetComment("JoeRoss_Hooks v1.0");

   //--- Create indicator handles
   gAtrHandle       = new CiATR(InpAtSLPeriod);
   gEmaFastHandle   = new CiEMA(InpEmaFast);
   gEmaSlowHandle   = new CiEMA(InpEmaSlow);
   gEmaTrendHandle  = new CiEMA(InpEmaTrend);
   gVolMaHandle     = new CiMA(20, MODE_SMA, PRICE_VOLUME);

   if(!CheckAllHandles()) {
      Print("ERROR: Failed to create indicator handles!");
      return INIT_FAILED;
   }

   //--- Initialize pattern
   ZeroMemory(gCurrentPattern);
   gCurrentPattern.pattern    = PATTERN_NONE;
   gCurrentPattern.hookState = HOOK_NONE;
   gCurrentPattern.triggered = false;
   gCurrentPattern.invalid   = false;

   //--- Initial detection on bar 0
   DetectPatterns();

   Print("=== Joe Ross 1-2-3 + Ross Hooks EA v1.0 Initialized ===");
   Print("   Symbol: ", Symbol());
   Print("   Mode: ", EnumToString(InpTradeMode));
   Print("   Trend Filter: ", InpUseTrendFilter ? "ON" : "OFF");
   Print("   Reversal Hook: ", InpAllowReversal ? "ON" : "OFF");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINIT                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   SafeDelete(gAtrHandle);
   SafeDelete(gEmaFastHandle);
   SafeDelete(gEmaSlowHandle);
   SafeDelete(gEmaTrendHandle);
   SafeDelete(gVolMaHandle);
   Comment("");
}

//+------------------------------------------------------------------+
//| ONTICK                                                           |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Wait for new bar
   if(!IsNewBar()) return;

   //--- Spread filter
   if(CheckSpreadTooHigh()) return;

   //--- Detect patterns
   DetectPatterns();

   //--- Update hook state
   UpdateHookState();

   //--- Check invalidations
   CheckPatternInvalidation();

   //--- Manage existing trades
   ManageOpenTrades();

   //--- Execute new trades
   if(InpAutoTrading) {
      CheckAndExecute();
   }

   //--- Dashboard
   if(InpShowDashboard) {
      PrintDashboard();
   }

   //--- Alert
   if(gNewPatternAlert && gAlertMessage != "") {
      Alert(gAlertMessage);
      gNewPatternAlert = false;
      gAlertMessage    = "";
   }
}

//+------------------------------------------------------------------+
//| IS NEW BAR                                                       |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime cur = iTime(Symbol(), PERIOD_CURRENT, 0);
   if(cur != gLastBarTime) {
      gLastBarTime = cur;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| CHECK SPREAD TOO HIGH                                            |
//+------------------------------------------------------------------+
bool CheckSpreadTooHigh()
{
   return (int)SymbolInfoInteger(Symbol(), SYMBOL_SPREAD) > gSpreadFilter;
}

//+------------------------------------------------------------------+
//| CHECK HANDLES                                                    |
//+------------------------------------------------------------------+
bool CheckAllHandles()
{
   return gAtrHandle.Handle()       != INVALID_HANDLE
       && gEmaFastHandle.Handle()    != INVALID_HANDLE
       && gEmaSlowHandle.Handle()    != INVALID_HANDLE
       && gEmaTrendHandle.Handle()   != INVALID_HANDLE
       && gVolMaHandle.Handle()      != INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| SAFE DELETE                                                      |
//+------------------------------------------------------------------+
template<typename T>
void SafeDelete(T &obj)
{
   if(CheckPointer(obj) != POINTER_INVALID) {
      obj.Destroy();
      delete obj;
      obj = NULL;
   }
}

//+------------------------------------------------------------------+
//| GET INDICATOR VALUES                                             |
//+------------------------------------------------------------------+
double GetAtr(int shift=1)         { return gAtrHandle.GetData(shift); }
double GetEmaFast(int shift=1)    { return gEmaFastHandle.GetData(shift); }
double GetEmaSlow(int shift=1)    { return gEmaSlowHandle.GetData(shift); }
double GetEmaTrend(int shift=1)   { return gEmaTrendHandle.GetData(shift); }
double GetVolMa(int shift=1)       { return gVolMaHandle.GetData(shift); }

//+------------------------------------------------------------------+
//| VOLUME FILTER                                                    |
//+------------------------------------------------------------------+
bool IsVolumeConfirmed()
{
   if(!InpUseVolFilter) return true;
   double vol  = (double)Volume(1);
   double volMa = GetVolMa(1);
   return vol > volMa * InpVolMultiplier;
}

//+------------------------------------------------------------------+
//| EMA TREND FILTER                                                 |
//+------------------------------------------------------------------+
bool IsTrendBullish()
{
   if(!InpUseTrendFilter) return true;
   double fast = GetEmaFast(1);
   double slow = GetEmaSlow(1);
   double trend = GetEmaTrend(1);
   return fast > slow && fast > trend;
}

bool IsTrendBearish()
{
   if(!InpUseTrendFilter) return true;
   double fast = GetEmaFast(1);
   double slow = GetEmaSlow(1);
   double trend = GetEmaTrend(1);
   return fast < slow && fast < trend;
}

//+------------------------------------------------------------------+
//| GET TRADE MODE                                                   |
//+------------------------------------------------------------------+
bool IsSwingMode()
{
   double atrVal  = GetAtr(1);
   double close0  = Close(0);
   double volRatio = atrVal / close0 * 100.0;
   return volRatio < 0.3 && InpAllowSwing;
}

bool IsScalpMode()
{
   double atrVal  = GetAtr(1);
   double close0  = Close(0);
   double volRatio = atrVal / close0 * 100.0;
   return volRatio >= 0.3 && InpAllowScalp;
}

string GetTradeModeStr()
{
   if(InpTradeMode == JR_MODE_HYBRID) return "HYBRID";
   if(InpTradeMode == JR_MODE_SWING) return "SWING";
   return "SCALP";
}

//+------------------------------------------------------------------+
//| FIND SWING HIGH/LOW (from current bar going back)                |
//+------------------------------------------------------------------+
SPivotPoint FindSwingHigh(int lookback, int excludeBars = 0)
{
   SPivotPoint pp;
   pp.type    = 1;
   pp.price   = 0;
   pp.barIdx  = -1;
   pp.time    = 0;

   int startBar = 1 + excludeBars;
   int endBar   = lookback + excludeBars;
   if(endBar > iBarShift(Symbol(), PERIOD_CURRENT, iTime(Symbol(), PERIOD_CURRENT, 0)) - 1)
      endBar = (int)iBarShift(Symbol(), PERIOD_CURRENT, iTime(Symbol(), PERIOD_CURRENT, 0)) - 1;

   if(startBar >= endBar) return pp;

   double highest = High(startBar);
   int    bestIdx = startBar;

   for(int i = startBar + 1; i <= endBar; i++) {
      if(High(i) > highest) {
         highest = High(i);
         bestIdx = i;
      }
   }

   // Check it's a real swing high (surrounding bars are lower)
   bool isValid = true;
   if(bestIdx > startBar && High(bestIdx - 1) >= High(bestIdx)) isValid = false;
   if(bestIdx < endBar && High(bestIdx + 1) >= High(bestIdx)) isValid = false;

   if(isValid && highest > 0) {
      pp.price  = highest;
      pp.barIdx = bestIdx;
      pp.time   = iTime(Symbol(), PERIOD_CURRENT, bestIdx);
   }

   return pp;
}

SPivotPoint FindSwingLow(int lookback, int excludeBars = 0)
{
   SPivotPoint pp;
   pp.type    = -1;
   pp.price   = 0;
   pp.barIdx  = -1;
   pp.time    = 0;

   int startBar = 1 + excludeBars;
   int endBar   = lookback + excludeBars;
   if(endBar > iBarShift(Symbol(), PERIOD_CURRENT, iTime(Symbol(), PERIOD_CURRENT, 0)) - 1)
      endBar = (int)iBarShift(Symbol(), PERIOD_CURRENT, iTime(Symbol(), PERIOD_CURRENT, 0)) - 1;

   if(startBar >= endBar) return pp;

   double lowest = Low(startBar);
   int    bestIdx = startBar;

   for(int i = startBar + 1; i <= endBar; i++) {
      if(Low(i) < lowest) {
         lowest = Low(i);
         bestIdx = i;
      }
   }

   bool isValid = true;
   if(bestIdx > startBar && Low(bestIdx - 1) <= Low(bestIdx)) isValid = false;
   if(bestIdx < endBar && Low(bestIdx + 1) <= Low(bestIdx)) isValid = false;

   if(isValid && lowest > 0) {
      pp.price  = lowest;
      pp.barIdx = bestIdx;
      pp.time   = iTime(Symbol(), PERIOD_CURRENT, bestIdx);
   }

   return pp;
}

//+------------------------------------------------------------------+
//| CHECK IF PIVOT IS SIGNIFICANT (size filter)                      |
//+------------------------------------------------------------------+
bool IsPivotSignificant(SPivotPoint &pp, int minPoints)
{
   return pp.price > 0;
}

//+------------------------------------------------------------------+
//| CALCULATE FIBONACCI EXTENSIONS                                   |
//+------------------------------------------------------------------+
SFibLevels CalcFibExtensions(SPivotPoint &p1, SPivotPoint &p2, SPivotPoint &p3)
{
   SFibLevels fib;
   double impulse = MathAbs(p2.price - p1.price);

   if(p2.type == 1) {
      // Bullish: p1=low, p2=high, extension above p2
      fib.level0  = p2.price;
      fib.level127 = p2.price + impulse * 1.27;
      fib.level161 = p2.price + impulse * 1.61;
      fib.level200 = p2.price + impulse * 2.00;
      fib.level261 = p2.price + impulse * 2.61;
   } else {
      // Bearish: p1=high, p2=low, extension below p2
      fib.level0  = p2.price;
      fib.level127 = p2.price - impulse * 1.27;
      fib.level161 = p2.price - impulse * 1.61;
      fib.level200 = p2.price - impulse * 2.00;
      fib.level261 = p2.price - impulse * 2.61;
   }

   return fib;
}

//+------------------------------------------------------------------+
//| CALCULATE FIBONACCI RETRACEMENT                                  |
//+------------------------------------------------------------------+
double GetFibRetracement(SPivotPoint &p1, SPivotPoint &p2, double price)
{
   if(p1.type == -1 && p2.type == 1) {
      // Bullish impulse
      double impulse = p2.price - p1.price;
      if(impulse <= 0) return 0;
      return (price - p1.price) / impulse;
   }
   if(p1.type == 1 && p2.type == -1) {
      // Bearish impulse
      double impulse = p1.price - p2.price;
      if(impulse <= 0) return 0;
      return (p1.price - price) / impulse;
   }
   return 0;
}

//+------------------------------------------------------------------+
//| DETECT 1-2-3 PATTERN                                             |
//+------------------------------------------------------------------+
void DetectPatterns()
{
   int bars = (int)iBarShift(Symbol(), PERIOD_CURRENT, iTime(Symbol(), PERIOD_CURRENT, 0));
   if(bars < InpSwingPeriod * 3 + 5) return;

   double atrVal = GetAtr(1);

   //=== BULLISH 1-2-3 + Ross Hook ===
   // P1: Swing low
   // P2: Swing high (impulse from P1)
   // P3: Swing low (retrace, must be > P1)
   // Hook: Retracement low after P2, entry on hook break

   SPivotPoint p1 = FindSwingLow(InpSwingPeriod);
   if(p1.barIdx < 0) return;

   // P2: Find the swing high AFTER P1
   SPivotPoint p2 = FindSwingHigh(InpSwingPeriod * 2, p1.barIdx);
   if(p2.barIdx < 0) return;
   if(p2.price <= p1.price) return; // P2 must be above P1 for bullish

   // P3: Find the swing low AFTER P2 (retrace)
   SPivotPoint p3 = FindSwingLow(InpSwingPeriod, p2.barIdx);
   if(p3.barIdx < 0) return;

   // Validate: P3 must be ABOVE P1 (pattern valid)
   // Joe Ross: "Bullish pattern is considered irrelevant if point 3 is at the level of or below point 1"
   double p1ToP3Dist = NormalizePrice(p3.price - p1.price);
   double minSize = NormalizePrice(atrVal * 0.5);

   if(p3.price > p1.price && p1ToP3Dist >= minSize) {
      // Bullish 1-2-3 found
      if(gCurrentPattern.pattern != PATTERN_BULL_123 || gCurrentPattern.p3.barIdx != p3.barIdx) {
         gCurrentPattern.pattern      = PATTERN_BULL_123;
         gCurrentPattern.p1           = p1;
         gCurrentPattern.p2           = p2;
         gCurrentPattern.p3          = p3;
         gCurrentPattern.detectionTime = TimeCurrent();
         gCurrentPattern.triggered    = false;
         gCurrentPattern.invalid      = false;
         gCurrentPattern.hookState    = HOOK_FORMING;

         // Calculate Fib extensions for TP
         SFibLevels fib = CalcFibExtensions(p1, p2, p3);
         gCurrentPattern.takeProfit1 = fib.level127;
         gCurrentPattern.takeProfit2 = fib.level161;
         gCurrentPattern.takeProfit3 = fib.level200;

         // Calculate SL (below P3 or below P1)
         gCurrentPattern.stopLoss = MathMin(p3.price - atrVal * InpAtrMultSL * 0.5,
                                            p1.price - atrVal * InpAtrMultSL * 0.3);

         // RR
         double risk = MathAbs(gCurrentPattern.entryPrice - gCurrentPattern.stopLoss);
         double reward = MathAbs(gCurrentPattern.takeProfit1 - gCurrentPattern.entryPrice);
         gCurrentPattern.rrRatio = (risk > 0) ? NormalizeDouble(reward / risk, 2) : 0;

         // Confidence
         int conf = 5;
         if(IsVolumeConfirmed()) conf += 2;
         if(IsTrendBullish()) conf += 2;
         if(p3.price > p1.price * 1.002) conf += 1; // Clear separation
         gCurrentPattern.confidence = MathMin(10, MathMax(1, conf));

         gAlertMessage = "BULLISH 1-2-3 DETECTED! P1:" + DoubleToStr(p1.price, _Digits)
                       + " P2:" + DoubleToStr(p2.price, _Digits)
                       + " P3:" + DoubleToStr(p3.price, _Digits)
                       + " | Waiting for Ross Hook...";
         gNewPatternAlert = true;
         Print("=== BULLISH 1-2-3 DETECTED ===");
         Print("   P1: ", DoubleToStr(p1.price, _Digits), " at ", p1.time);
         Print("   P2: ", DoubleToStr(p2.price, _Digits), " at ", p2.time);
         Print("   P3: ", DoubleToStr(p3.price, _Digits), " at ", p3.time);
         Print("   TP1: ", DoubleToStr(gCurrentPattern.takeProfit1, _Digits));
         Print("   SL: ", DoubleToStr(gCurrentPattern.stopLoss, _Digits));
      }
   }

   //=== BEARISH 1-2-3 + Ross Hook ===
   // P1: Swing high
   // P2: Swing low (impulse from P1)
   // P3: Swing high (retrace, must be < P1)
   // Hook: Retracement high after P2, entry on hook break

   SPivotPoint p1b = FindSwingHigh(InpSwingPeriod);
   if(p1b.barIdx < 0) return;

   SPivotPoint p2b = FindSwingLow(InpSwingPeriod * 2, p1b.barIdx);
   if(p2b.barIdx < 0) return;
   if(p2b.price >= p1b.price) return; // P2 must be below P1 for bearish

   SPivotPoint p3b = FindSwingHigh(InpSwingPeriod, p2b.barIdx);
   if(p3b.barIdx < 0) return;

   if(p3b.price < p1b.price && NormalizePrice(p1b.price - p3b.price) >= minSize) {
      if(gCurrentPattern.pattern != PATTERN_BEAR_123 || gCurrentPattern.p3.barIdx != p3b.barIdx) {
         gCurrentPattern.pattern      = PATTERN_BEAR_123;
         gCurrentPattern.p1           = p1b;
         gCurrentPattern.p2           = p2b;
         gCurrentPattern.p3          = p3b;
         gCurrentPattern.detectionTime = TimeCurrent();
         gCurrentPattern.triggered    = false;
         gCurrentPattern.invalid      = false;
         gCurrentPattern.hookState    = HOOK_FORMING;

         SFibLevels fib = CalcFibExtensions(p1b, p2b, p3b);
         gCurrentPattern.takeProfit1 = fib.level127;
         gCurrentPattern.takeProfit2 = fib.level161;
         gCurrentPattern.takeProfit3 = fib.level200;

         gCurrentPattern.stopLoss = MathMax(p3b.price + atrVal * InpAtrMultSL * 0.5,
                                            p1b.price + atrVal * InpAtrMultSL * 0.3);

         double risk = MathAbs(gCurrentPattern.entryPrice - gCurrentPattern.stopLoss);
         double reward = MathAbs(gCurrentPattern.entryPrice - gCurrentPattern.takeProfit1);
         gCurrentPattern.rrRatio = (risk > 0) ? NormalizeDouble(reward / risk, 2) : 0;

         int conf = 5;
         if(IsVolumeConfirmed()) conf += 2;
         if(IsTrendBearish()) conf += 2;
         if(p3b.price < p1b.price * 0.998) conf += 1;
         gCurrentPattern.confidence = MathMin(10, MathMax(1, conf));

         gAlertMessage = "BEARISH 1-2-3 DETECTED! P1:" + DoubleToStr(p1b.price, _Digits)
                       + " P2:" + DoubleToStr(p2b.price, _Digits)
                       + " P3:" + DoubleToStr(p3b.price, _Digits)
                       + " | Waiting for Ross Hook...";
         gNewPatternAlert = true;
         Print("=== BEARISH 1-2-3 DETECTED ===");
         Print("   P1: ", DoubleToStr(p1b.price, _Digits), " at ", p1b.time);
         Print("   P2: ", DoubleToStr(p2b.price, _Digits), " at ", p2b.time);
         Print("   P3: ", DoubleToStr(p3b.price, _Digits), " at ", p3b.time);
      }
   }

   //=== REVERSAL HOOKS ===
   if(InpAllowReversal) {
      DetectReversalHooks();
   }
}

//+------------------------------------------------------------------+
//| DETECT REVERSAL HOOKS                                            |
//| When P3 breaks P1 level, the pattern invalidates → trade reversal|
//+------------------------------------------------------------------+
void DetectReversalHooks()
{
   double atrVal  = GetAtr(1);
   double close0  = Close(0);
   double minSize = NormalizePrice(atrVal * 0.5);

   //=== BULLISH REVERSAL HOOK ===
   // Scenario: Bearish 1-2-3 formed but P3 breaks BELOW P1
   // → Price reverses UP, breaking above P1 = Bullish Reversal Hook entry

   if(gCurrentPattern.pattern == PATTERN_BEAR_123 && !gCurrentPattern.invalid) {
      // Check if P3 broke below P1
      if(gCurrentPattern.p3.barIdx > 0 && gCurrentPattern.p1.barIdx > 0) {
         if(gCurrentPattern.p3.barIdx > gCurrentPattern.p1.barIdx) {
            // P3 formed AFTER P1 — check if P3 < P1
            if(gCurrentPattern.p3.price < gCurrentPattern.p1.price * 0.999) {
               // Pattern 1-2-3 invalidated — reversal bullish setup
               if(gCurrentPattern.pattern != PATTERN_BULL_REVERSAL) {
                  Print("=== BULLISH REVERSAL HOOK TRIGGERED ===");
                  Print("   Original BEARISH 1-2-3 invalidated (P3 < P1)");
                  Print("   Bullish reversal forming — watch for break above P1");

                  gCurrentPattern.pattern      = PATTERN_BULL_REVERSAL;
                  gCurrentPattern.detectionTime = TimeCurrent();
                  gCurrentPattern.hookState   = HOOK_FORMING;
                  gCurrentPattern.triggered    = false;
                  gCurrentPattern.stopLoss     = gCurrentPattern.p3.price - atrVal * InpAtrMultSL * 0.5;
                  gCurrentPattern.takeProfit1  = gCurrentPattern.p1.price + atrVal * InpAtrMultTP;
                  gCurrentPattern.takeProfit2  = gCurrentPattern.p2.price + atrVal * InpAtrMultTP * 0.5;
                  gCurrentPattern.rrRatio      = 0;
                  gCurrentPattern.confidence   = 4;

                  gAlertMessage = "BULLISH REVERSAL HOOK! P3 broke below P1 — reversal UP incoming";
                  gNewPatternAlert = true;
               }
            }
         }
      }
   }

   //=== BEARISH REVERSAL HOOK ===
   // Scenario: Bullish 1-2-3 formed but P3 breaks ABOVE P1
   // → Price reverses DOWN, breaking below P1 = Bearish Reversal Hook entry

   if(gCurrentPattern.pattern == PATTERN_BULL_123 && !gCurrentPattern.invalid) {
      if(gCurrentPattern.p3.barIdx > 0 && gCurrentPattern.p1.barIdx > 0) {
         if(gCurrentPattern.p3.barIdx > gCurrentPattern.p1.barIdx) {
            if(gCurrentPattern.p3.price > gCurrentPattern.p1.price * 1.001) {
               if(gCurrentPattern.pattern != PATTERN_BEAR_REVERSAL) {
                  Print("=== BEARISH REVERSAL HOOK TRIGGERED ===");
                  Print("   Original BULLISH 1-2-3 invalidated (P3 > P1)");
                  Print("   Bearish reversal forming — watch for break below P1");

                  gCurrentPattern.pattern      = PATTERN_BEAR_REVERSAL;
                  gCurrentPattern.detectionTime = TimeCurrent();
                  gCurrentPattern.hookState   = HOOK_FORMING;
                  gCurrentPattern.triggered    = false;
                  gCurrentPattern.stopLoss     = gCurrentPattern.p3.price + atrVal * InpAtrMultSL * 0.5;
                  gCurrentPattern.takeProfit1  = gCurrentPattern.p1.price - atrVal * InpAtrMultTP;
                  gCurrentPattern.takeProfit2  = gCurrentPattern.p2.price - atrVal * InpAtrMultTP * 0.5;
                  gCurrentPattern.rrRatio      = 0;
                  gCurrentPattern.confidence   = 4;

                  gAlertMessage = "BEARISH REVERSAL HOOK! P3 broke above P1 — reversal DOWN incoming";
                  gNewPatternAlert = true;
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| UPDATE HOOK STATE                                                |
//+------------------------------------------------------------------+
void UpdateHookState()
{
   if(gCurrentPattern.pattern == PATTERN_NONE) return;
   if(gCurrentPattern.triggered || gCurrentPattern.invalid) return;

   double close0  = Close(0);
   double high0   = High(0);
   double low0    = Low(0);
   double atrVal  = GetAtr(1);

   //=== BULLISH 1-2-3 Ross Hook ===
   if(gCurrentPattern.pattern == PATTERN_BULL_123) {
      // Hook: Pullback after P2 break — look for higher low above P3
      // Entry trigger: Price breaks above the hook high

      if(gCurrentPattern.hookState == HOOK_FORMING) {
         // Wait for pullback from P2 high — then look for hook formation
         // Hook forms when price makes a lower high after breaking P2
         // For bullish: we want the first pullback AFTER P2 was broken

         // Simple approach: Check if we're in a pullback from P2
         double p2Price = gCurrentPattern.p2.price;
         double p3Price = gCurrentPattern.p3.price;

         // If price is between P2 and P3, we're in the retracement zone
         if(close0 < p2Price && close0 > p3Price) {
            // Find the swing high of this pullback (potential hook)
            SPivotPoint hookHigh = FindSwingHigh(InpHookLookback);
            if(hookHigh.barIdx > gCurrentPattern.p2.barIdx && hookHigh.barIdx < gCurrentPattern.p3.barIdx + InpHookLookback) {
               // Hook is forming
               gCurrentPattern.hook = hookHigh;
               gCurrentPattern.hookState = HOOK_ACTIVE;
               Print("   Ross Hook ACTIVE at ", DoubleToStr(hookHigh.price, _Digits));
            }
         }

         // Direct breakout entry: price breaks above P2 without pullback
         if(close0 > p2Price) {
            gCurrentPattern.entryPrice = NormalizeDouble(MathMax(close0, p2Price), _Digits);
            gCurrentPattern.hookState = HOOK_BROKEN;
            gCurrentPattern.triggered = true;
            double risk = MathAbs(gCurrentPattern.entryPrice - gCurrentPattern.stopLoss);
            double reward = MathAbs(gCurrentPattern.takeProfit1 - gCurrentPattern.entryPrice);
            gCurrentPattern.rrRatio = (risk > 0) ? NormalizeDouble(reward / risk, 2) : 0;
            Print("   DIRECT ENTRY TRIGGERED at ", DoubleToStr(gCurrentPattern.entryPrice, _Digits),
                  " (price broke P2)");
         }
      }

      if(gCurrentPattern.hookState == HOOK_ACTIVE) {
         double hookHigh = gCurrentPattern.hook.price;
         if(close0 > hookHigh) {
            // Hook broken — ENTRY
            gCurrentPattern.entryPrice = NormalizeDouble(MathMax(close0, hookHigh), _Digits);
            gCurrentPattern.hookState = HOOK_BROKEN;
            gCurrentPattern.triggered = true;
            gCurrentPattern.hookBreakTime = TimeCurrent();
            double risk = MathAbs(gCurrentPattern.entryPrice - gCurrentPattern.stopLoss);
            double reward = MathAbs(gCurrentPattern.takeProfit1 - gCurrentPattern.entryPrice);
            gCurrentPattern.rrRatio = (risk > 0) ? NormalizeDouble(reward / risk, 2) : 0;
            Print("=== HOOK BROKEN — ENTRY TRIGGERED ===");
            Print("   Entry: ", DoubleToStr(gCurrentPattern.entryPrice, _Digits));
            Print("   Hook High: ", DoubleToStr(hookHigh, _Digits));
            gAlertMessage = "Ross Hook BROKEN! BUY ENTRY at " + DoubleToStr(gCurrentPattern.entryPrice, _Digits);
            gNewPatternAlert = true;
         }
      }
   }

   //=== BEARISH 1-2-3 Ross Hook ===
   if(gCurrentPattern.pattern == PATTERN_BEAR_123) {
      if(gCurrentPattern.hookState == HOOK_FORMING) {
         double p2Price = gCurrentPattern.p2.price;
         double p3Price = gCurrentPattern.p3.price;

         if(close0 > p2Price && close0 < p3Price) {
            SPivotPoint hookLow = FindSwingLow(InpHookLookback);
            if(hookLow.barIdx > gCurrentPattern.p2.barIdx) {
               gCurrentPattern.hook = hookLow;
               gCurrentPattern.hookState = HOOK_ACTIVE;
               Print("   Ross Hook ACTIVE at ", DoubleToStr(hookLow.price, _Digits));
            }
         }

         // Direct breakout entry
         if(close0 < p2Price) {
            gCurrentPattern.entryPrice = NormalizeDouble(MathMin(close0, p2Price), _Digits);
            gCurrentPattern.hookState = HOOK_BROKEN;
            gCurrentPattern.triggered = true;
            double risk = MathAbs(gCurrentPattern.stopLoss - gCurrentPattern.entryPrice);
            double reward = MathAbs(gCurrentPattern.entryPrice - gCurrentPattern.takeProfit1);
            gCurrentPattern.rrRatio = (risk > 0) ? NormalizeDouble(reward / risk, 2) : 0;
            Print("   DIRECT ENTRY TRIGGERED at ", DoubleToStr(gCurrentPattern.entryPrice, _Digits));
         }
      }

      if(gCurrentPattern.hookState == HOOK_ACTIVE) {
         double hookLow = gCurrentPattern.hook.price;
         if(close0 < hookLow) {
            gCurrentPattern.entryPrice = NormalizeDouble(MathMin(close0, hookLow), _Digits);
            gCurrentPattern.hookState = HOOK_BROKEN;
            gCurrentPattern.triggered = true;
            gCurrentPattern.hookBreakTime = TimeCurrent();
            double risk = MathAbs(gCurrentPattern.stopLoss - gCurrentPattern.entryPrice);
            double reward = MathAbs(gCurrentPattern.entryPrice - gCurrentPattern.takeProfit1);
            gCurrentPattern.rrRatio = (risk > 0) ? NormalizeDouble(reward / risk, 2) : 0;
            Print("=== HOOK BROKEN — ENTRY TRIGGERED ===");
            Print("   Entry: ", DoubleToStr(gCurrentPattern.entryPrice, _Digits));
            Print("   Hook Low: ", DoubleToStr(hookLow, _Digits));
            gAlertMessage = "Ross Hook BROKEN! SELL ENTRY at " + DoubleToStr(gCurrentPattern.entryPrice, _Digits);
            gNewPatternAlert = true;
         }
      }
   }

   //=== REVERSAL HOOK — ENTRY ===
   if(gCurrentPattern.pattern == PATTERN_BULL_REVERSAL) {
      if(gCurrentPattern.hookState == HOOK_FORMING) {
         double p1Price = gCurrentPattern.p1.price;
         // Entry: Price breaks above P1 (original resistance becomes support)
         if(close0 > p1Price) {
            gCurrentPattern.entryPrice = NormalizeDouble(MathMax(close0, p1Price), _Digits);
            gCurrentPattern.hookState = HOOK_BROKEN;
            gCurrentPattern.triggered = true;
            gCurrentPattern.hookBreakTime = TimeCurrent();
            double risk = MathAbs(gCurrentPattern.entryPrice - gCurrentPattern.stopLoss);
            double reward = MathAbs(gCurrentPattern.takeProfit1 - gCurrentPattern.entryPrice);
            gCurrentPattern.rrRatio = (risk > 0) ? NormalizeDouble(reward / risk, 2) : 0;
            Print("=== BULL REVERSAL HOOK TRIGGERED ===");
            gAlertMessage = "Bullish Reversal Hook ENTRY at " + DoubleToStr(gCurrentPattern.entryPrice, _Digits);
            gNewPatternAlert = true;
         }
      }
   }

   if(gCurrentPattern.pattern == PATTERN_BEAR_REVERSAL) {
      if(gCurrentPattern.hookState == HOOK_FORMING) {
         double p1Price = gCurrentPattern.p1.price;
         // Entry: Price breaks below P1
         if(close0 < p1Price) {
            gCurrentPattern.entryPrice = NormalizeDouble(MathMin(close0, p1Price), _Digits);
            gCurrentPattern.hookState = HOOK_BROKEN;
            gCurrentPattern.triggered = true;
            gCurrentPattern.hookBreakTime = TimeCurrent();
            double risk = MathAbs(gCurrentPattern.stopLoss - gCurrentPattern.entryPrice);
            double reward = MathAbs(gCurrentPattern.entryPrice - gCurrentPattern.takeProfit1);
            gCurrentPattern.rrRatio = (risk > 0) ? NormalizeDouble(reward / risk, 2) : 0;
            Print("=== BEAR REVERSAL HOOK TRIGGERED ===");
            gAlertMessage = "Bearish Reversal Hook ENTRY at " + DoubleToStr(gCurrentPattern.entryPrice, _Digits);
            gNewPatternAlert = true;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| CHECK PATTERN INVALIDATION                                        |
//+------------------------------------------------------------------+
void CheckPatternInvalidation()
{
   if(gCurrentPattern.pattern == PATTERN_NONE) return;
   if(gCurrentPattern.invalid || gCurrentPattern.triggered) return;

   double close0  = Close(0);
   double atrVal  = GetAtr(1);
   double p1Price = gCurrentPattern.p1.price;
   double p2Price = gCurrentPattern.p2.price;
   double p3Price = gCurrentPattern.p3.price;

   //=== Bullish 1-2-3 Invalidation ===
   // Price breaks below P3 = invalid
   if(gCurrentPattern.pattern == PATTERN_BULL_123) {
      if(close0 < p3Price - atrVal * 0.3) {
         gCurrentPattern.invalid = true;
         gCurrentPattern.hookState = HOOK_NONE;
         Print("   BULLISH 1-2-3 INVALIDATED — price closed below P3");
      }
   }

   //=== Bearish 1-2-3 Invalidation ===
   if(gCurrentPattern.pattern == PATTERN_BEAR_123) {
      if(close0 > p3Price + atrVal * 0.3) {
         gCurrentPattern.invalid = true;
         gCurrentPattern.hookState = HOOK_NONE;
         Print("   BEARISH 1-2-3 INVALIDATED — price closed above P3");
      }
   }
}

//+------------------------------------------------------------------+
//| NORMALIZE PRICE                                                  |
//+------------------------------------------------------------------+
double NormalizePrice(double price)
{
   return NormalizeDouble(price, _Digits);
}

//+------------------------------------------------------------------+
//| CHECK AND EXECUTE TRADE                                          |
//+------------------------------------------------------------------+
void CheckAndExecute()
{
   if(!gCurrentPattern.triggered) return;
   if(gCurrentPattern.invalid) return;
   if(gCurrentPattern.pattern == PATTERN_NONE) return;

   //=== Mode filter ===
   if(InpTradeMode == JR_MODE_SWING && !IsSwingMode()) return;
   if(InpTradeMode == JR_MODE_SCALP && !IsScalpMode()) return;

   //=== Trend filter ===
   bool trendOK = false;
   ENUM_JR_PATTERN pat = gCurrentPattern.pattern;

   if(pat == PATTERN_BULL_123 || pat == PATTERN_BULL_REVERSAL) {
      trendOK = IsTrendBullish();
   }
   if(pat == PATTERN_BEAR_123 || pat == PATTERN_BEAR_REVERSAL) {
      trendOK = IsTrendBearish();
   }
   if(InpUseTrendFilter && !trendOK) {
      Print("Trade skipped — trend filter not aligned");
      return;
   }

   //=== Confidence filter ===
   if(gCurrentPattern.confidence < 5) {
      Print("Trade skipped — confidence too low (", gCurrentPattern.confidence, "/10)");
      return;
   }

   //=== Volume filter ===
   if(!IsVolumeConfirmed()) {
      Print("Trade skipped — volume not confirmed");
      return;
   }

   //=== Max positions ===
   if(CountOpenPositions() >= InpMaxPositions) return;

   //=== Cooldown ===
   if(TimeCurrent() - gLastTradeTime < InpTradeCooldown) return;

   //=== Calculate lot ===
   double slDist = MathAbs(gCurrentPattern.entryPrice - gCurrentPattern.stopLoss);
   double lot    = CalculateLotSize(slDist);

   //=== Determine order type ===
   ENUM_ORDER_TYPE orderType = ORDER_TYPE_BUY;
   double entry = gCurrentPattern.entryPrice;
   double sl    = gCurrentPattern.stopLoss;
   double tp1   = gCurrentPattern.takeProfit1;

   if(pat == PATTERN_BEAR_123 || pat == PATTERN_BEAR_REVERSAL) {
      orderType = ORDER_TYPE_SELL;
      sl        = gCurrentPattern.stopLoss;
      tp1       = gCurrentPattern.takeProfit1;
   }

   //=== Validate SL/TP ===
   if(!ValidateSLTP(orderType, entry, sl, tp1)) {
      Print("Trade skipped — invalid SL/TP");
      return;
   }

   //=== Execute ===
   bool result = gTrade.PositionOpen(Symbol(), orderType, lot, entry, sl, tp1,
      StringFormat("Ross123|%s|Conf:%d|RR:%.1f|%s",
         EnumToString(pat), gCurrentPattern.confidence,
         gCurrentPattern.rrRatio, GetTradeModeStr()));

   if(result) {
      gLastTradeTime = TimeCurrent();
      Print("✅ TRADE EXECUTED: ", EnumToString(orderType),
            " Entry:", DoubleToStr(entry, _Digits),
            " SL:", DoubleToStr(sl, _Digits),
            " TP1:", DoubleToStr(tp1, _Digits),
            " Lot:", DoubleToStr(lot, 2),
            " RR:", DoubleToStr(gCurrentPattern.rrRatio, 1));
   } else {
      Print("❌ TRADE FAILED: ", GetLastError(),
            " — ", gTrade.ResultComment());
   }

   // Reset after trade
   gCurrentPattern.triggered = false;
}

//+------------------------------------------------------------------+
//| VALIDATE SL/TP                                                   |
//+------------------------------------------------------------------+
bool ValidateSLTP(ENUM_ORDER_TYPE orderType, double entry, double sl, double tp)
{
   double point  = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double minSL  = point * SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL);

   if(orderType == ORDER_TYPE_BUY) {
      if(sl >= entry || tp <= entry) return false;
      if(entry - sl < minSL) return false;
   }
   else if(orderType == ORDER_TYPE_SELL) {
      if(sl <= entry || tp >= entry) return false;
      if(sl - entry < minSL) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| CALCULATE LOT SIZE                                               |
//+------------------------------------------------------------------+
double CalculateLotSize(double slDistance)
{
   if(slDistance <= 0) return 0.01;

   double accountBal = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBal * InpRiskPercent / 100.0;

   double tickVal  = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   double point    = SymbolInfoDouble(Symbol(), SYMBOL_POINT);

   double slPoints  = slDistance / point;
   double riskPerLot = slPoints * tickVal / tickSize * point;

   double lot = (riskPerLot > 0) ? riskAmount / riskPerLot : 0;

   double minLot  = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double maxLot  = InpMaxLot;
   double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);

   lot = MathMax(minLot, MathMin(maxLot, lot));
   lot = MathFloor(lot / lotStep) * lotStep;

   return NormalizeDouble(MathMax(lot, minLot), 2);
}

//+------------------------------------------------------------------+
//| COUNT OPEN POSITIONS                                             |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(gPosition.SelectByIndex(i)) {
         if(gPosition.Magic() == InpMagicNumber && gPosition.Symbol() == Symbol()) {
            count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| MANAGE OPEN TRADES                                               |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(gPosition.SelectByIndex(i)) {
         if(gPosition.Magic() != InpMagicNumber) continue;
         if(gPosition.Symbol() != Symbol()) continue;

         double openPrice   = gPosition.PriceOpen();
         double currentPrice = gPosition.PriceCurrent();
         double posSL        = gPosition.StopLoss();
         double posTP        = gPosition.TakeProfit();
         double profit      = gPosition.Profit();

         if(gPosition.PositionType() == POSITION_TYPE_BUY) {
            // Move SL to breakeven when 1:1 RR reached
            double pnlPts = (currentPrice - openPrice) / SymbolInfoDouble(Symbol(), SYMBOL_POINT);
            double slDist = (posSL > 0) ? (openPrice - posSL) / SymbolInfoDouble(Symbol(), SYMBOL_POINT) : 0;

            if(pnlPts > slDist * 1.5 && (posSL < openPrice || posSL == 0)) {
               double newSL = NormalizeDouble(openPrice + SymbolInfoDouble(Symbol(), SYMBOL_POINT) * 2, _Digits);
               gTrade.PositionModify(Symbol(), newSL, posTP);
               Print("   SL moved to BREAKEVEN at ", DoubleToStr(newSL, _Digits));
            }

            // Partial close at TP1
            double tpDist = (posTP > 0) ? (posTP - openPrice) / SymbolInfoDouble(Symbol(), SYMBOL_POINT) : 0;
            if(tpDist > 0 && pnlPts >= tpDist * 0.8) {
               // 50% partial close
               double closeQty = gPosition.Volume() * 0.5;
               if(closeQty >= SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN)) {
                  gTrade.PositionClosePartial(Symbol(), closeQty);
                  Print("   Partial close 50% at TP1 zone");
               }
            }
         }
         else if(gPosition.PositionType() == POSITION_TYPE_SELL) {
            double pnlPts = (openPrice - currentPrice) / SymbolInfoDouble(Symbol(), SYMBOL_POINT);
            double slDist = (posSL > 0) ? (posSL - openPrice) / SymbolInfoDouble(Symbol(), SYMBOL_POINT) : 0;

            if(pnlPts > slDist * 1.5 && (posSL > openPrice || posSL == 0)) {
               double newSL = NormalizeDouble(openPrice - SymbolInfoDouble(Symbol(), SYMBOL_POINT) * 2, _Digits);
               gTrade.PositionModify(Symbol(), newSL, posTP);
               Print("   SL moved to BREAKEVEN at ", DoubleToStr(newSL, _Digits));
            }

            double tpDist = (posTP > 0) ? (openPrice - posTP) / SymbolInfoDouble(Symbol(), SYMBOL_POINT) : 0;
            if(tpDist > 0 && pnlPts >= tpDist * 0.8) {
               double closeQty = gPosition.Volume() * 0.5;
               if(closeQty >= SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN)) {
                  gTrade.PositionClosePartial(Symbol(), closeQty);
                  Print("   Partial close 50% at TP1 zone");
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| PRINT DASHBOARD                                                  |
//+------------------------------------------------------------------+
void PrintDashboard()
{
   string patternStr = "NONE";
   string stateStr   = "—";
   string biasStr    = "NEUTRAL";
   string modeStr    = GetTradeModeStr();
   string volStr     = IsVolumeConfirmed() ? "✅" : "❌";
   string trendStr   = "NEUTRAL";

   if(gCurrentPattern.pattern == PATTERN_BULL_123) patternStr = "📈 BULL 1-2-3";
   if(gCurrentPattern.pattern == PATTERN_BEAR_123) patternStr = "📉 BEAR 1-2-3";
   if(gCurrentPattern.pattern == PATTERN_BULL_REVERSAL) patternStr = "📈 BULL REVERSAL";
   if(gCurrentPattern.pattern == PATTERN_BEAR_REVERSAL) patternStr = "📉 BEAR REVERSAL";

   if(gCurrentPattern.hookState == HOOK_FORMING) stateStr = "FORMING ⏳";
   if(gCurrentPattern.hookState == HOOK_ACTIVE)  stateStr = "ACTIVE 🎯";
   if(gCurrentPattern.hookState == HOOK_BROKEN)   stateStr = "BROKEN ✅";
   if(gCurrentPattern.invalid)                    stateStr = "INVALID ❌";
   if(gCurrentPattern.triggered)                  stateStr = "TRIGGERED 🚀";

   if(IsTrendBullish())  { biasStr = "🟢 BULLISH"; trendStr = "BULL"; }
   if(IsTrendBearish())  { biasStr = "🔴 BEARISH"; trendStr = "BEAR"; }

   string confBar = "";
   int conf = gCurrentPattern.confidence;
   for(int i = 0; i < 10; i++) confBar += (i < conf) ? "█" : "░";

   string entryStr = (gCurrentPattern.entryPrice > 0) ? DoubleToStr(gCurrentPattern.entryPrice, _Digits) : "—";
   string slStr    = (gCurrentPattern.stopLoss > 0) ? DoubleToStr(gCurrentPattern.stopLoss, _Digits) : "—";
   string tp1Str   = (gCurrentPattern.takeProfit1 > 0) ? DoubleToStr(gCurrentPattern.takeProfit1, _Digits) : "—";

   string dash = StringFormat(
      "══════════════════════════════════════\n"  +
      "   Joe Ross 1-2-3 + Ross Hooks v1.0\n"  +
      "══════════════════════════════════════\n"  +
      "  Pair     : %s\n"                        +
      "  Price    : %s\n"                        +
      "  Spread   : %d pts\n"                   +
      "──────────────────────────────────────\n"  +
      "  Pattern  : %s\n"                        +
      "  State    : %s\n"                        +
      "  Mode     : %s\n"                        +
      "  Trend    : %s\n"                        +
      "  Vol Conf : %s\n"                        +
      "──────────────────────────────────────\n"  +
      "  P1       : %s\n"                        +
      "  P2       : %s\n"                        +
      "  P3       : %s\n"                        +
      "  Hook     : %s\n"                        +
      "──────────────────────────────────────\n"  +
      "  Entry    : %s\n"                        +
      "  SL       : %s\n"                        +
      "  TP1      : %s\n"                        +
      "  RR       : %s\n"                        +
      "──────────────────────────────────────\n"  +
      "  Confidence: %s [%d/10]\n"               +
      "══════════════════════════════════════\n"  +
      "  ⚠️ Joe Ross Rule:\n"                        +
      "  Wait for the Hook — don't enter\n"    +
      "  until price breaks the Ross Hook!\n"  +
      "══════════════════════════════════════",
      Symbol(),
      DoubleToStr(Close(0), _Digits),
      (int)SymbolInfoInteger(Symbol(), SYMBOL_SPREAD),
      patternStr,
      stateStr,
      modeStr,
      biasStr,
      volStr,
      (gCurrentPattern.p1.price > 0) ? DoubleToStr(gCurrentPattern.p1.price, _Digits) : "—",
      (gCurrentPattern.p2.price > 0) ? DoubleToStr(gCurrentPattern.p2.price, _Digits) : "—",
      (gCurrentPattern.p3.price > 0) ? DoubleToStr(gCurrentPattern.p3.price, _Digits) : "—",
      (gCurrentPattern.hook.price > 0) ? DoubleToStr(gCurrentPattern.hook.price, _Digits) : "—",
      entryStr,
      slStr,
      tp1Str,
      (gCurrentPattern.rrRatio > 0) ? DoubleToStr(gCurrentPattern.rrRatio, 2) : "—",
      confBar, gCurrentPattern.confidence
   );

   Comment(dash);
}

//+------------------------------------------------------------------+
//| EXPERT END                                                        |
//+------------------------------------------------------------------+
