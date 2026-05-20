//+------------------------------------------------------------------+
//|     VPA_BDTL_Volume_V10_Enhanced.mq5                              |
//|  Enhanced from: VPA + BDTL + VOLUME v10.0 (Pine Script)           |
//|  Additions based on Anna Coulling's VPA book:                    |
//|  - Effort vs Result classification (Wyckoff's 3rd Law)           |
//|  - Stopping Volume / Topping Out Volume                           |
//|  - Absorption detection                                          |
//|  - Selling Climax / Buying Climax                                |
//|  - Low Volume Test                                               |
//|  - Close Location Analysis                                       |
//|  - Volume Trend validation (multi-candle)                        |
//|  Version: 1.000 Enhanced                                           |
//+------------------------------------------------------------------+
#property copyright "Enhanced: Pine v10.0 + Coulling VPA Book"
#property version   "1.000"
#property indicator_chart_window
#property indicator_buffers 16
#property indicator_plots    8

//+------------------------------------------------------------------+
//| BUFFER IDs                                                        |
//+------------------------------------------------------------------+
#define BUF_RSI             0
#define BUF_EMA            1
#define BUF_DTL            2
#define BUF_TSL            3
#define BUF_BPR            4  // Buying Pressure (wick analysis)
#define BUF_SPR            5  // Selling Pressure (wick analysis)
#define BUF_DTL_BRK        6
#define BUF_VPA_STATUS     7
#define BUF_EFFORT_RESULT  8  // NEW: Wyckoff effort vs result
#define BUF_STOPPING_VOL   9  // NEW: Stopping Volume signal
#define BUF_TOPPING_OUT    10  // NEW: Topping Out signal
#define BUF_ABSORPTION    11  // NEW: Absorption signal
#define BUF_CLIMAX        12  // NEW: Climax signal (+2=sell climax, -2=buy climax)
#define BUF_LOW_VOL_TEST  13  // NEW: Low Volume Test
#define BUF_CLOSE_LOC     14  // NEW: Close location [0..1]
#define BUF_VOL_TREND     15  // NEW: Volume trend direction

//+------------------------------------------------------------------+
//| ENUM: Effort vs Result States                                    |
//+------------------------------------------------------------------+
enum ENUM_EFFORT_RESULT
{
   ER_NONE       = 0,  // Cannot determine
   ER_VALID      = 1,  // Normal: effort = result
   ER_ANOMALY_A  = 2,  // Anomaly: wide spread + low volume = TRAP
   ER_ANOMALY_B  = 3,  // Anomaly: narrow spread + high vol = WEAK
   ER_CLIMAX     = 4   // Climax: max effort = exhaustion
};

//+------------------------------------------------------------------+
//| ENUM: VPA Signal States                                          |
//+------------------------------------------------------------------+
enum ENUM_VPA_SIGNAL
{
   SIG_NONE      = 0,
   SIG_BULL      = 1,  // Bull Valid (up bar + high vol + wide spread)
   SIG_BEAR      = -1, // Bear Valid (down bar + high vol + wide spread)
   SIG_STOPVOL   = 2,  // Stopping Volume (potential reversal up)
   SIG_TOPPING   = -2, // Topping Out (potential reversal down)
   SIG_SQUAT     = 3,  // Squat Anomaly (high vol + narrow spread)
   SIG_ABSORB    = 4,  // Absorption
   SIG_SELLCLIMAX = -3,// Selling Climax
   SIG_BUYCLIMAX  = 3, // Buying Climax
   SIG_LVTEST    = 5   // Low Volume Test
};

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+

// VPA Sniper Settings (original)
input group("VPA Sniper Settings")
input float  InpVolMult        = 1.2;   // Volume Spike Factor (was 1.2)
input float  InpSpreadMult     = 1.1;   // Wide Spread Factor (was 1.1)
input float  InpUltraHighMult  = 2.0;   // NEW: Ultra High Volume multiplier
input float  InpLowVolMult     = 0.5;   // NEW: Low Volume threshold (below SMA x this)
input int    InpVolPeriod      = 20;    // NEW: Volume SMA period
input int    InpBodyMinRatio   = 50;    // NEW: Min body % of spread for valid candle
input int    InpWickDeepRatio  = 60;    // NEW: Min wick % of range for deep wick

// Structural DTL Settings (original)
input group("Structural DTL Settings")
input int    InpPivotLB        = 10;    // DTL Pivot Strength

// Trade Management (original)
input group("Trade Management")
input float  InpTSLMult        = 2.0;   // TSL Sensitivity (ATR Mult)

// Climax Settings (NEW - from Coulling Ch.5)
input group("Climax Detection (Coulling Ch.5)")
input int    InpClimaxPeriod   = 3;     // Number of candles for climax sequence
input float  InpClimaxVolMult = 2.0;   // Volume must be this x above SMA for climax

// Dashboard & Visuals
input group("Dashboard & Visuals")
input string InpDashPos        = "Top Right";

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
double ExtRSIBuffer[];
double ExtEMABuffer[];
double ExtDTLBuffer[];
double ExtTSLBuffer[];
double ExtBPRBuffer[];
double ExtSPRBuffer[];
double ExtDTLBrkBuffer[];
double ExtVPAStatusBuffer[];
double ExtEffortResult[];      // NEW
double ExtStoppingVol[];       // NEW
double ExtToppingOut[];        // NEW
double ExtAbsorption[];        // NEW
double ExtClimax[];            // NEW
double ExtLowVolTest[];        // NEW
double ExtCloseLoc[];          // NEW
double ExtVolTrend[];          // NEW

// DTL pivot state
double gP1Y = EMPTY_VALUE, gP2Y = EMPTY_VALUE;
int    gP1X = 0, gP2X = 0;
double gSlope = 0.0;
double gLastPH = 0.0;

// ATR handle
int gAtrHandle = INVALID_HANDLE;
double gAtrBuffer[];

// EMA handle
int gEmaHandle = INVALID_HANDLE;
double gEmaBuffer[];

//+------------------------------------------------------------------+
//| OnInit                                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(BUF_RSI,          ExtRSIBuffer,     INDICATOR_DATA);
   SetIndexBuffer(BUF_EMA,          ExtEMABuffer,     INDICATOR_DATA);
   SetIndexBuffer(BUF_DTL,          ExtDTLBuffer,     INDICATOR_DATA);
   SetIndexBuffer(BUF_TSL,          ExtTSLBuffer,     INDICATOR_CALCULATIONS);
   SetIndexBuffer(BUF_BPR,          ExtBPRBuffer,     INDICATOR_DATA);
   SetIndexBuffer(BUF_SPR,          ExtSPRBuffer,     INDICATOR_DATA);
   SetIndexBuffer(BUF_DTL_BRK,      ExtDTLBrkBuffer, INDICATOR_DATA);
   SetIndexBuffer(BUF_VPA_STATUS,   ExtVPAStatusBuffer, INDICATOR_DATA);
   SetIndexBuffer(BUF_EFFORT_RESULT, ExtEffortResult, INDICATOR_DATA);
   SetIndexBuffer(BUF_STOPPING_VOL,  ExtStoppingVol,  INDICATOR_DATA);
   SetIndexBuffer(BUF_TOPPING_OUT,   ExtToppingOut,  INDICATOR_DATA);
   SetIndexBuffer(BUF_ABSORPTION,   ExtAbsorption,   INDICATOR_DATA);
   SetIndexBuffer(BUF_CLIMAX,        ExtClimax,       INDICATOR_DATA);
   SetIndexBuffer(BUF_LOW_VOL_TEST,  ExtLowVolTest,  INDICATOR_DATA);
   SetIndexBuffer(BUF_CLOSE_LOC,     ExtCloseLoc,     INDICATOR_DATA);
   SetIndexBuffer(BUF_VOL_TREND,    ExtVolTrend,     INDICATOR_DATA);

   // Plot settings
   PlotIndexSetString(0, PLOT_LABEL, "RSI(14)");
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, clrDodgerBlue);

   PlotIndexSetString(1, PLOT_LABEL, "EMA(50)");
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, clrLime);

   PlotIndexSetString(2, PLOT_LABEL, "DTL");
   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_SECTION);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, clrRed);
   PlotIndexSetInteger(2, PLOT_LINE_STYLE, STYLE_DASH);

   PlotIndexSetString(3, PLOT_LABEL, "TSL");
   PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, clrRed);

   PlotIndexSetString(4, PLOT_LABEL, "BuyPressure");
   PlotIndexSetInteger(4, PLOT_DRAW_TYPE, DRAW_ARROW);
   PlotIndexSetInteger(4, PLOT_ARROW, 233);
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, clrLime);

   PlotIndexSetString(5, PLOT_LABEL, "SellPressure");
   PlotIndexSetInteger(5, PLOT_DRAW_TYPE, DRAW_ARROW);
   PlotIndexSetInteger(5, PLOT_ARROW, 234);
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, clrRed);

   // NEW plots - all DRAW_NONE (buffers used for state + chart annotations)
   for(int p = 6; p <= 7; p++)
   {
      PlotIndexSetInteger(p, PLOT_DRAW_TYPE, DRAW_NONE);
   }

   // Create handles
   gAtrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
   if(gAtrHandle == INVALID_HANDLE) { Print("[VPA] ATR handle error!"); return INIT_FAILED; }

   gEmaHandle = iMA(_Symbol, PERIOD_CURRENT, 50, 0, MODE_EMA, PRICE_CLOSE);
   if(gEmaHandle == INVALID_HANDLE) { Print("[VPA] EMA handle error!"); return INIT_FAILED; }

   gP1Y = EMPTY_VALUE; gP2Y = EMPTY_VALUE;
   gP1X = 0; gP2X = 0; gSlope = 0.0; gLastPH = 0.0;

   IndicatorSetString(INDICATOR_SHORTNAME, "VPA+BDTL+v10.0_Enhanced");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(gAtrHandle != INVALID_HANDLE) IndicatorRelease(gAtrHandle);
   if(gEmaHandle != INVALID_HANDLE) IndicatorRelease(gEmaHandle);
   for(int i = 0; i < 200; i++)
   {
      ObjectDelete(0, "VPAx_Arrow_" + IntegerToString(i));
      ObjectDelete(0, "VPAx_Label_" + IntegerToString(i));
   }
   ObjectDelete(0, "VPAx_Table");
   Comment("");
}

//+------------------------------------------------------------------+
//| HELPER: Calculate Volume Stats (ENHANCED)                         |
//+------------------------------------------------------------------+
void CalcVolumeStatsEnhanced(int shift, double& volSMA, double& volRatio,
                            bool& isHighVol, bool& isUltraHigh, bool& isLowVol)
{
   if(shift < InpVolPeriod) { volSMA = 0; volRatio = 0; isHighVol = false; isUltraHigh = false; isLowVol = false; return; }

   double sum = 0;
   for(int i = shift; i < shift + InpVolPeriod; i++) sum += (double)Volume[i];
   volSMA = sum / InpVolPeriod;

   if(volSMA > 0) volRatio = (double)Volume[shift] / volSMA;
   else           volRatio = 0;

   isHighVol    = (volRatio >= InpVolMult);
   isUltraHigh  = (volRatio >= InpUltraHighMult);
   isLowVol     = (volRatio < InpLowVolMult);
}

//+------------------------------------------------------------------+
//| HELPER: Calculate Spread Stats                                    |
//+------------------------------------------------------------------+
void CalcSpreadStats(int shift, double& spread, double& avgSpread,
                    bool& isWideSpread, bool& isNarrowSpread)
{
   if(shift < 20) { spread = 0; avgSpread = 0; isWideSpread = false; isNarrowSpread = false; return; }

   spread = High[shift] - Low[shift];
   double sum = 0;
   for(int i = shift; i < shift + 20; i++) sum += (High[i] - Low[i]);
   avgSpread = sum / 20.0;

   isWideSpread  = (spread > avgSpread * InpSpreadMult);
   isNarrowSpread = (spread < avgSpread * 0.7);
}

//+------------------------------------------------------------------+
//| HELPER: Candle Anatomy (ENHANCED)                                 |
//+------------------------------------------------------------------+
void CalcCandleAnatomyEnhanced(int shift, double& bodySize,
                               double& lowerWick, double& upperWick,
                               double& bodyRatio, double& closeLoc,
                               bool& isUpBar, bool& isDownBar)
{
   double openPrice  = Open[shift];
   double closePrice = Close[shift];
   double highPrice  = High[shift];
   double lowPrice   = Low[shift];
   double range      = highPrice - lowPrice;

   bodySize   = MathAbs(closePrice - openPrice);
   lowerWick = MathMin(openPrice, closePrice) - lowPrice;
   upperWick = highPrice - MathMax(openPrice, closePrice);
   isUpBar   = (closePrice > openPrice);
   isDownBar = (closePrice < openPrice);

   if(range > 0)
   {
      bodyRatio = bodySize / range * 100.0;
      closeLoc  = (closePrice - lowPrice) / range; // 0=low, 1=high
   }
   else
   {
      bodyRatio = 0;
      closeLoc  = 0.5;
   }
}

//+------------------------------------------------------------------+
//| HELPER: Trend Direction (from original)                          |
//+------------------------------------------------------------------+
int GetTrendDir(int emaHandle, int shift)
{
   double emaCur = 0, emaPrev = 0;
   double buf1[], buf2[];
   ArraySetAsSeries(buf1, true);
   ArraySetAsSeries(buf2, true);

   if(emaHandle != INVALID_HANDLE)
   {
      if(CopyBuffer(emaHandle, 0, shift, 1, buf1) > 0 &&
         CopyBuffer(emaHandle, 0, shift + 5, 1, buf2) > 0)
      {
         emaCur = buf1[0]; emaPrev = buf2[0];
         if(emaPrev != 0)
         {
            double slope = (emaCur - emaPrev) / emaPrev * 100.0;
            if(slope > 0.05)  return  1;
            if(slope < -0.05) return -1;
         }
      }
   }
   return 0;
}

//+------------------------------------------------------------------+
//| HELPER: Volume Trend (multi-candle)                              |
//| Coulling Ch.4: Rising prices should have rising volume          |
//+------------------------------------------------------------------+
int GetVolumeTrend(int shift)
{
   if(shift < InpVolPeriod) return 0;
   double recent = 0, older = 0;
   for(int i = shift;           i < shift + InpVolPeriod / 2; i++) recent += (double)Volume[i];
   for(int i = shift + InpVolPeriod / 2; i < shift + InpVolPeriod; i++) older += (double)Volume[i];
   if(older > 0)
   {
      double ratio = recent / older;
      if(ratio > 1.1) return  1; // Rising volume
      if(ratio < 0.9) return -1; // Falling volume
   }
   return 0;
}

//+------------------------------------------------------------------+
//| HELPER: Custom Pivot High                                         |
//+------------------------------------------------------------------+
double iCustomPivotHigh(int shift, int lookback)
{
   if(shift < lookback) return 0;
   double peak = High[shift];
   for(int i = 1; i <= lookback; i++)
   { if(High[shift - i] >= peak) return 0; }
   for(int i = 1; i <= lookback; i++)
   { if(High[shift + i] > peak)  return 0; }
   return peak;
}

//+------------------------------------------------------------------+
//| HELPER: Update DTL                                               |
//+------------------------------------------------------------------+
void UpdateDTL(int shift)
{
   double ph = iCustomPivotHigh(shift, InpPivotLB);
   if(ph > 0 && ph != gLastPH)
   {
      gP2Y = gP1Y; gP2X = gP1X;
      gP1Y = ph;
      gP1X = shift - InpPivotLB;
      gLastPH = ph;
      if(gP2X > 0 && gP1X > 0 && gP2X != gP1X)
         gSlope = (gP1Y - gP2Y) / (double)(gP1X - gP2X);
   }
}

//+------------------------------------------------------------------+
//| HELPER: Get DTL price                                             |
//+------------------------------------------------------------------+
double GetDTLPrice(int shift)
{
   if(gP1Y == EMPTY_VALUE || gP2Y == EMPTY_VALUE || gP1X == 0) return 0;
   if(gP1Y >= gP2Y) return 0;
   return gP1Y + gSlope * (double)(shift - gP1X);
}

//+------------------------------------------------------------------+
//| CORE #1: Classify Effort vs Result (Wyckoff - Coulling Ch.4)      |
//| "For every action there is an equal and opposite reaction"         |
//+------------------------------------------------------------------+
ENUM_EFFORT_RESULT ClassifyEffortResult(bool isHighVol, bool isUltraHigh, bool isLowVol,
                                        bool isWideSpread, bool isNarrowSpread)
{
   // ANOMALY TYPE A: Wide spread + LOW volume
   // "Big result from little effort" = TRAP (Coulling Ch.4, p.30-31)
   if(isWideSpread && isLowVol) return ER_ANOMALY_A;

   // ANOMALY TYPE B: Narrow spread + HIGH volume
   // "Big effort, little result" = WEAKNESS (Coulling Ch.4, p.31-32)
   if(isNarrowSpread && isHighVol) return ER_ANOMALY_B;

   // NORMAL: Wide spread + High volume (effort = result, genuine move)
   if(isWideSpread && isHighVol) return ER_VALID;

   // NORMAL: Narrow spread + Low volume (small effort, small result)
   if(isNarrowSpread && isLowVol) return ER_VALID;

   return ER_NONE;
}

//+------------------------------------------------------------------+
//| CORE #2: STOPPING VOLUME (Coulling Ch.6, p.69)                   |
//| "Insiders move in and absorb selling pressure"                     |
//| Conditions: down bar + high vol + deep lower wick + close upper half |
//+------------------------------------------------------------------+
bool IsStoppingVolume(bool isDownBar, bool isHighVol,
                     double lowerWick, double range, double closeLoc,
                     int trendDir)
{
   if(!isDownBar || !isHighVol) return false;
   if(trendDir > 0) return false; // Should occur in bear/flat market

   double lowerWickRatio = (range > 0) ? lowerWick / range * 100.0 : 0;
   if(lowerWickRatio < InpWickDeepRatio) return false; // Wick not deep enough
   if(closeLoc < 0.50) return false; // Close must be in upper half

   return true;
}

//+------------------------------------------------------------------+
//| CORE #3: TOPPING OUT VOLUME (Coulling Ch.6, p.70)                |
//| "Just as stopping volume stops falling, topping out stops rising"   |
//| Conditions: up bar + high vol + deep upper wick + close lower half |
//+------------------------------------------------------------------+
bool IsToppingOut(bool isUpBar, bool isHighVol,
                  double upperWick, double range, double closeLoc,
                  int trendDir)
{
   if(!isUpBar || !isHighVol) return false;
   if(trendDir < 0) return false; // Should occur in bull/flat market

   double upperWickRatio = (range > 0) ? upperWick / range * 100.0 : 0;
   if(upperWickRatio < InpWickDeepRatio) return false;
   if(closeLoc > 0.50) return false; // Close must be in lower half

   return true;
}

//+------------------------------------------------------------------+
//| CORE #4: ABSORPTION (Coulling Ch.4, p.36-37)                    |
//| "Specialists absorb the volume but price doesn't follow"           |
//| Condition: High vol + body ratio < 40% + close at wrong extreme   |
//+------------------------------------------------------------------+
bool IsAbsorption(bool isHighVol, double bodyRatio,
                  double closeLoc, bool isUpBar, bool isDownBar)
{
   if(!isHighVol || bodyRatio >= 40.0) return false;

   // Absorption of buying: up bar but close near lows
   if(isUpBar   && closeLoc < 0.35) return true;
   // Absorption of selling: down bar but close near highs
   if(isDownBar && closeLoc > 0.65) return true;

   return false;
}

//+------------------------------------------------------------------+
//| CORE #5: SELLING CLIMAX (Coulling Ch.5, p.51)                    |
//| "Last hurrah before insiders take market lower"                     |
//| "2-3 wide spread + high volume candles, closing near the open"    |
//+------------------------------------------------------------------+
bool IsSellingClimax(int shift)
{
   if(shift < InpVolPeriod || shift < InpClimaxPeriod) return false;

   int climaxCount = 0;

   for(int i = shift; i < shift + InpClimaxPeriod && i < Bars - 1; i++)
   {
      double range     = High[i] - Low[i];
      double bodySize  = MathAbs(Close[i] - Open[i]);
      double bodyRatio = (range > 0) ? bodySize / range * 100.0 : 0;
      double closeLoc  = (range > 0) ? (Close[i] - Low[i]) / range : 0.5;

      // Volume check
      double volSum = 0;
      for(int j = i; j < i + InpVolPeriod && j < Bars; j++) volSum += (double)Volume[j];
      double volSMA = volSum / InpVolPeriod;
      double volRatio = (volSMA > 0) ? (double)Volume[i] / volSMA : 0;

      // Spread check
      double sprSum = 0;
      for(int j = i; j < i + 20 && j < Bars; j++) sprSum += (High[j] - Low[j]);
      double avgSpr = sprSum / 20.0;
      bool isWideSpread = (range > avgSpr * InpSpreadMult);

      // Climax candle: wide spread + very high vol + doji-like
      bool isClimaxCandle = (volRatio >= InpClimaxVolMult)
                             && isWideSpread
                             && (bodyRatio < 30.0)
                             && (closeLoc > 0.35 && closeLoc < 0.65);

      if(isClimaxCandle) climaxCount++;
   }

   // At least 2 climax candles required
   return (climaxCount >= 2);
}

//+------------------------------------------------------------------+
//| CORE #6: BUYING CLIMAX (Coulling Ch.5)                          |
//| "Opposite of selling climax - end of accumulation"                |
//+------------------------------------------------------------------+
bool IsBuyingClimax(int shift)
{
   if(shift < InpVolPeriod || shift < InpClimaxPeriod) return false;

   int climaxCount = 0;

   for(int i = shift; i < shift + InpClimaxPeriod && i < Bars - 1; i++)
   {
      double range     = High[i] - Low[i];
      double bodySize  = MathAbs(Close[i] - Open[i]);
      double bodyRatio = (range > 0) ? bodySize / range * 100.0 : 0;
      double closeLoc  = (range > 0) ? (Close[i] - Low[i]) / range : 0.5;

      double volSum = 0;
      for(int j = i; j < i + InpVolPeriod && j < Bars; j++) volSum += (double)Volume[j];
      double volSMA = volSum / InpVolPeriod;
      double volRatio = (volSMA > 0) ? (double)Volume[i] / volSMA : 0;

      double sprSum = 0;
      for(int j = i; j < i + 20 && j < Bars; j++) sprSum += (High[j] - Low[j]);
      double avgSpr = sprSum / 20.0;
      bool isWideSpread = (range > avgSpr * InpSpreadMult);

      bool isClimaxCandle = (volRatio >= InpClimaxVolMult)
                             && isWideSpread
                             && (bodyRatio < 30.0)
                             && (closeLoc > 0.35 && closeLoc < 0.65);

      if(isClimaxCandle) climaxCount++;
   }

   return (climaxCount >= 2);
}

//+------------------------------------------------------------------+
//| CORE #7: LOW VOLUME TEST (Coulling Ch.5, p.47)                  |
//| "No demand left at this level - safe to move away"               |
//+------------------------------------------------------------------+
bool IsLowVolTest(bool isLowVol, double bodyRatio)
{
   return isLowVol && bodyRatio < 40.0;
}

//+------------------------------------------------------------------+
//| HELPER: Get master VPA signal (priority hierarchy)                |
//+------------------------------------------------------------------+
ENUM_VPA_SIGNAL GetVPAStatus(bool bullValid, bool bearValid, bool squat,
                             bool stoppingVol, bool toppingOut, bool absorption,
                             bool sellClimax, bool buyClimax, bool lowVolTest,
                             double closeLoc, int trendDir)
{
   // Priority 1: Climax (end of distribution/accumulation)
   if(sellClimax) return SIG_SELLCLIMAX;
   if(buyClimax)  return SIG_BUYCLIMAX;

   // Priority 2: Reversal signals
   if(stoppingVol) return SIG_STOPVOL;
   if(toppingOut)  return SIG_TOPPING;

   // Priority 3: Absorption (wait)
   if(absorption)   return SIG_ABSORB;

   // Priority 4: Low Volume Test
   if(lowVolTest)  return SIG_LVTEST;

   // Priority 5: Squat
   if(squat)       return SIG_SQUAT;

   // Priority 6: Trend confirmation
   if(bullValid)   return SIG_BULL;
   if(bearValid)   return SIG_BEAR;

   return SIG_NONE;
}

//+------------------------------------------------------------------+
//| HELPER: Get EMA slope (original)                                  |
//+------------------------------------------------------------------+
double GetEMASlope(int emaHandle, int shift)
{
   double buf1[], buf2[];
   ArraySetAsSeries(buf1, true);
   ArraySetAsSeries(buf2, true);
   if(emaHandle != INVALID_HANDLE)
   {
      if(CopyBuffer(emaHandle, 0, shift, 1, buf1) > 0 &&
         CopyBuffer(emaHandle, 0, shift + 5, 1, buf2) > 0)
      {
         if(buf2[0] != 0) return (buf1[0] - buf2[0]) / buf2[0] * 100.0;
      }
   }
   return 0.0;
}

//+------------------------------------------------------------------+
//| HELPER: Get trend strength (original)                             |
//+------------------------------------------------------------------+
string GetTrendStrength(double emaSlope)
{
   if(emaSlope > 0.1)  return "STRONG BULL";
   if(emaSlope > 0)    return "WEAK BULL";
   if(emaSlope > -0.1) return "WEAK BEAR";
   return "STRONG BEAR";
}

color GetTrendColor(double emaSlope)
{
   if(emaSlope > 0.1)  return clrLime;
   if(emaSlope > 0)    return clrMediumSeaGreen;
   if(emaSlope > -0.1) return clrOrange;
   return clrRed;
}

//+------------------------------------------------------------------+
//| HELPER: Effort Result label (NEW)                                 |
//+------------------------------------------------------------------+
string GetEffortResultLabel(ENUM_EFFORT_RESULT er)
{
   switch(er)
   {
      case ER_VALID:     return "NORMAL";
      case ER_ANOMALY_A: return "ANOMALY: TRAP";
      case ER_ANOMALY_B: return "ANOMALY: WEAK";
      case ER_CLIMAX:    return "CLIMAX";
      default:           return "---";
   }
}

//+------------------------------------------------------------------+
//| HELPER: VPA Status label (NEW)                                   |
//+------------------------------------------------------------------+
string GetVPALabel(ENUM_VPA_SIGNAL sig)
{
   switch(sig)
   {
      case SIG_BULL:       return "VALID BULL";
      case SIG_BEAR:       return "VALID BEAR";
      case SIG_STOPVOL:    return "STOPPING VOL";
      case SIG_TOPPING:   return "TOPPING OUT";
      case SIG_SQUAT:      return "SQUAT ANOMALY";
      case SIG_ABSORB:     return "ABSORPTION";
      case SIG_SELLCLIMAX: return "SELLING CLIMAX!";
      case SIG_BUYCLIMAX:  return "BUYING CLIMAX!";
      case SIG_LVTEST:     return "LOW VOL TEST";
      default:            return "NEUTRAL";
   }
}

color GetVPAColor(ENUM_VPA_SIGNAL sig)
{
   switch(sig)
   {
      case SIG_BULL:       return clrLime;
      case SIG_BEAR:       return clrRed;
      case SIG_STOPVOL:    return clrDodgerBlue;
      case SIG_TOPPING:    return clrDeepSkyBlue;
      case SIG_SQUAT:      return clrOrange;
      case SIG_ABSORB:     return clrYellow;
      case SIG_SELLCLIMAX: return clrMagenta;
      case SIG_BUYCLIMAX:  return clrMagenta;
      case SIG_LVTEST:     return clrYellow;
      default:            return clrGray;
   }
}

//+------------------------------------------------------------------+
//| HELPER: Signal label                                              |
//+------------------------------------------------------------------+
string GetSignalLabel(ENUM_VPA_SIGNAL sig)
{
   switch(sig)
   {
      case SIG_BULL:       return "BUY";
      case SIG_BEAR:       return "SELL";
      case SIG_STOPVOL:    return "BUY (STOP VOL)";
      case SIG_TOPPING:    return "SELL (TOP OUT)";
      case SIG_SELLCLIMAX: return "EXIT LONG!";
      case SIG_BUYCLIMAX:  return "EXIT SHORT!";
      case SIG_LVTEST:     return "CAUTION";
      case SIG_SQUAT:      return "WAIT";
      case SIG_ABSORB:     return "WAIT";
      default:            return "WAIT";
   }
}

//+------------------------------------------------------------------+
//| HELPER: Draw annotation (NEW)                                    |
//+------------------------------------------------------------------+
int gArrowCounter = 0;
void DrawVPAArrow(int shift, string text, color clr, bool belowBar)
{
   string name = "VPAx_Arrow_" + IntegerToString(gArrowCounter);
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);

   double price = belowBar ? Low[shift] - 40*_Point : High[shift] + 40*_Point;

   if(!ObjectCreate(0, name, OBJ_TEXT, 0, Time[shift], price))
      return;
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, belowBar ? ANCHOR_BOTTOM : ANCHOR_TOP);
   gArrowCounter++;
   if(gArrowCounter > 199) gArrowCounter = 0;
}

//+------------------------------------------------------------------+
//| HELPER: Update Dashboard (ENHANCED)                              |
//+------------------------------------------------------------------+
void UpdateDashboardEnhanced(ENUM_VPA_SIGNAL vpaSig, ENUM_EFFORT_RESULT er,
                            double rsiVal, double emaSlope, double closeLoc,
                            bool isHighVol, int volTrend, double volRatio,
                            bool bullVPA, bool bearVPA, bool squat,
                            bool stoppingVol, bool toppingOut, bool absorb,
                            bool sellClimax, bool buyClimax, bool lowVolTest,
                            string tf)
{
   string dashName = "VPAx_Dashboard";
   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int xBase = (InpDashPos == "Top Right" || InpDashPos == "Middle Right" || InpDashPos == "Bottom Right")
               ? chartW - 300 : 10;
   int yBase = 25;

   // Background
   ObjectCreate(0, dashName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, dashName, OBJPROP_XDISTANCE, xBase);
   ObjectSetInteger(0, dashName, OBJPROP_YDISTANCE, yBase);
   ObjectSetInteger(0, dashName, OBJPROP_XSIZE, 290);
   ObjectSetInteger(0, dashName, OBJPROP_YSIZE, 340);
   ObjectSetInteger(0, dashName, OBJPROP_BGCOLOR, C'8,8,18');
   ObjectSetInteger(0, dashName, OBJPROP_BORDER_COLOR, clrGray);
   ObjectSetInteger(0, dashName, OBJPROP_ZORDER, 0);

   string labels[12], values[12];
   color  bgs[12],    txts[12];

   string trendStr = GetTrendStrength(emaSlope);
   color  trendCol = GetTrendColor(emaSlope);
   color  rsiBg    = (rsiVal > 70) ? clrRed : (rsiVal < 30) ? clrLime : clrDimGray;

   labels[0]  = "VPA+BDTL v10 ENHANCED";  values[0]  = tf + "M";       bgs[0] = clrDodgerBlue; txts[0] = clrWhite;
   labels[1]  = "VPA Status";              values[1]  = GetVPALabel(vpaSig); bgs[1] = GetVPAColor(vpaSig); txts[1] = clrWhite;
   labels[2]  = "Effort vs Result";        values[2]  = GetEffortResultLabel(er); bgs[2] = (er == ER_ANOMALY_A || er == ER_ANOMALY_B) ? clrOrange : (er == ER_VALID ? clrLime : clrGray); txts[2] = clrWhite;
   labels[3]  = "AI Signal";               values[3]  = GetSignalLabel(vpaSig); bgs[3] = (vpaSig == SIG_BULL || vpaSig == SIG_STOPVOL || vpaSig == SIG_BUYCLIMAX) ? clrLime : (vpaSig == SIG_BEAR || vpaSig == SIG_TOPPING || vpaSig == SIG_SELLCLIMAX) ? clrRed : clrDimGray; txts[3] = clrWhite;
   labels[4]  = "Trend";                    values[4]  = trendStr;    bgs[4] = trendCol;       txts[4] = clrWhite;
   labels[5]  = "RSI (14)";                values[5]  = DoubleToString(rsiVal, 2); bgs[5] = rsiBg;  txts[5] = clrWhite;
   labels[6]  = "Vol Ratio";               values[6]  = DoubleToString(volRatio, 2) + "x"; bgs[6] = isHighVol ? clrOrange : clrDimGray; txts[6] = clrWhite;
   labels[7]  = "Vol Trend";              values[7]  = volTrend > 0 ? "RISING" : volTrend < 0 ? "FALLING" : "FLAT"; bgs[7] = volTrend > 0 ? clrLime : volTrend < 0 ? clrRed : clrGray; txts[7] = clrWhite;
   labels[8]  = "Close Location";         values[8]  = DoubleToString(closeLoc*100, 0) + "% high"; bgs[8] = clrDimGray; txts[8] = clrWhite;
   labels[9]  = "---DETECTIONS---";        values[9]  = "-------------"; bgs[9] = clrBlack; txts[9] = clrSilver;
   labels[10] = "StoppingVol";            values[10] = stoppingVol ? "YES" : "NO"; bgs[10] = stoppingVol ? clrDodgerBlue : clrDimGray; txts[10] = clrWhite;
   labels[11] = "ToppingOut";             values[11] = toppingOut ? "YES" : "NO"; bgs[11] = toppingOut ? clrDeepSkyBlue : clrDimGray; txts[11] = clrWhite;

   for(int r = 0; r < 12; r++)
   {
      string ln = dashName + "_L" + IntegerToString(r);
      string vn = dashName + "_V" + IntegerToString(r);
      if(ObjectFind(0, ln) >= 0) ObjectDelete(0, ln);
      if(ObjectFind(0, vn) >= 0) ObjectDelete(0, vn);

      ObjectCreate(0, ln, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, ln, OBJPROP_XDISTANCE, xBase + 5);
      ObjectSetInteger(0, ln, OBJPROP_YDISTANCE, yBase + 5 + r * 24);
      ObjectSetString(0, ln, OBJPROP_TEXT, labels[r]);
      ObjectSetInteger(0, ln, OBJPROP_COLOR, txts[r]);
      ObjectSetInteger(0, ln, OBJPROP_FONTSIZE, 7);
      ObjectSetInteger(0, ln, OBJPROP_ZORDER, 1);

      ObjectCreate(0, vn, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, vn, OBJPROP_XDISTANCE, xBase + 165);
      ObjectSetInteger(0, vn, OBJPROP_YDISTANCE, yBase + 5 + r * 24);
      ObjectSetString(0, vn, OBJPROP_TEXT, values[r]);
      ObjectSetInteger(0, vn, OBJPROP_COLOR, txts[r]);
      ObjectSetInteger(0, vn, OBJPROP_BGCOLOR, bgs[r]);
      ObjectSetInteger(0, vn, OBJPROP_FONTSIZE, 7);
      ObjectSetInteger(0, vn, OBJPROP_ZORDER, 1);
   }

   // Chart comment
   string comment = StringFormat(
      "VPA=%s | E/R=%s | Signal=%s | CloseLoc=%.0f%% | Vol=%.2fx | Trend=%s",
      GetVPALabel(vpaSig), GetEffortResultLabel(er), GetSignalLabel(vpaSig),
      closeLoc*100, volRatio, trendStr);
   Comment(comment);
}

//+------------------------------------------------------------------+
//| OnCalculate (ENHANCED)                                            |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total < MathMax(60, InpVolPeriod + InpClimaxPeriod + 5))
      return 0;

   int start = prev_calculated > 0 ? prev_calculated - 1 : InpVolPeriod + 5;

   // Copy ATR & EMA
   double atrBuf[], emaBuf[];
   ArraySetAsSeries(atrBuf, true);
   ArraySetAsSeries(emaBuf, true);
   CopyBuffer(gAtrHandle, 0, 0, rates_total, atrBuf);
   CopyBuffer(gEmaHandle, 0, 0, rates_total, emaBuf);

   static double prevTSL = 0;
   static bool   inPos    = false;

   for(int i = start; i < rates_total && !IsStopped(); i++)
   {
      //--- Volume Stats (ENHANCED)
      double volSMA = 0, volRatio = 0;
      bool isHighVol = false, isUltraHigh = false, isLowVol = false;
      CalcVolumeStatsEnhanced(i, volSMA, volRatio, isHighVol, isUltraHigh, isLowVol);

      //--- Spread Stats (original)
      double spread_ = 0, avgSpread = 0;
      bool isWideSpread = false, isNarrowSpread = false;
      CalcSpreadStats(i, spread_, avgSpread, isWideSpread, isNarrowSpread);

      //--- Candle Anatomy (ENHANCED)
      double bodySize = 0, lowerWick = 0, upperWick = 0;
      double bodyRatio = 0, closeLoc = 0;
      bool isUpBar = false, isDownBar = false;
      CalcCandleAnatomyEnhanced(i, bodySize, lowerWick, upperWick, bodyRatio, closeLoc, isUpBar, isDownBar);

      //--- Trend
      int trendDir = GetTrendDir(gEmaHandle, i);
      double emaSlope = GetEMASlope(gEmaHandle, i);

      //--- Volume Trend (NEW)
      int volTrend = GetVolumeTrend(i);
      ExtVolTrend[i] = volTrend;

      //--- Close Location (NEW)
      ExtCloseLoc[i] = closeLoc;

      //--- RSI (original)
      ExtRSIBuffer[i] = iRSI(NULL, 0, 14, PRICE_CLOSE, i);

      //--- EMA (original)
      if(i < ArraySize(emaBuf) && MathIsValidNumber(emaBuf[i]))
         ExtEMABuffer[i] = emaBuf[i];

      //--- DTL (original)
      UpdateDTL(i);
      double dtlPrice = GetDTLPrice(i);
      ExtDTLBuffer[i] = (dtlPrice > 0) ? dtlPrice : EMPTY_VALUE;

      //--- Effort vs Result (NEW - Wyckoff's 3rd Law)
      ENUM_EFFORT_RESULT er = ClassifyEffortResult(isHighVol, isUltraHigh, isLowVol, isWideSpread, isNarrowSpread);
      ExtEffortResult[i] = er;

      //--- Bull Valid (original + body ratio check)
      bool bullVPA = isUpBar && isWideSpread && isHighVol && bodyRatio >= InpBodyMinRatio;
      //--- Bear Valid (original + body ratio check)
      bool bearVPA = isDownBar && isWideSpread && isHighVol && bodyRatio >= InpBodyMinRatio;

      //--- Squat Anomaly (original)
      bool squat = isHighVol && isNarrowSpread;

      //--- Stopping Volume (NEW)
      bool stoppingVol = IsStoppingVolume(isDownBar, isHighVol, lowerWick, spread_, closeLoc, trendDir);
      ExtStoppingVol[i] = stoppingVol ? Low[i] - 40*_Point : EMPTY_VALUE;

      //--- Topping Out (NEW)
      bool toppingOut = IsToppingOut(isUpBar, isHighVol, upperWick, spread_, closeLoc, trendDir);
      ExtToppingOut[i] = toppingOut ? High[i] + 40*_Point : EMPTY_VALUE;

      //--- Absorption (NEW)
      bool absorption = IsAbsorption(isHighVol, bodyRatio, closeLoc, isUpBar, isDownBar);
      ExtAbsorption[i] = absorption ? (High[i] + Low[i]) / 2 : EMPTY_VALUE;

      //--- Selling Climax (NEW)
      bool sellClimax = IsSellingClimax(i);
      //--- Buying Climax (NEW)
      bool buyClimax  = IsBuyingClimax(i);
      ExtClimax[i] = sellClimax ? 2.0 : buyClimax ? -2.0 : 0.0;

      //--- Low Volume Test (NEW)
      bool lowVolTest = IsLowVolTest(isLowVol, bodyRatio);
      ExtLowVolTest[i] = lowVolTest ? (High[i] + Low[i]) / 2 : EMPTY_VALUE;

      //--- VPA Status (combined)
      ENUM_VPA_SIGNAL vpaSig = GetVPAStatus(bullVPA, bearVPA, squat,
                                            stoppingVol, toppingOut, absorption,
                                            sellClimax, buyClimax, lowVolTest,
                                            closeLoc, trendDir);
      ExtVPAStatusBuffer[i] = vpaSig;

      //--- DTL Breakout (original)
      bool dtlBreak = false;
      if(i >= 1 && dtlPrice > 0)
      {
         double prevClose = Close[i-1];
         if(prevClose <= dtlPrice && close[i] > dtlPrice)
            dtlBreak = true;
      }
      ExtDTLBrkBuffer[i] = dtlBreak ? High[i] : EMPTY_VALUE;

      //--- Buying / Selling Pressure (original)
      bool buyPressure  = (lowerWick > bodySize * 2) && isHighVol;
      bool sellPressure = (upperWick > bodySize * 2) && isHighVol;
      ExtBPRBuffer[i] = buyPressure  ? Low[i]  : EMPTY_VALUE;
      ExtSPRBuffer[i] = sellPressure ? High[i] : EMPTY_VALUE;

      //--- Buy Signal (original logic + new conditions)
      bool buySignal = bullVPA && dtlBreak && (emaSlope > -0.05);

      //--- TSL (original)
      double atr = (i < ArraySize(atrBuf)) ? atrBuf[i] : 0;
      double tslCalc = (atr > 0) ? close[i] - atr * InpTSLMult : EMPTY_VALUE;

      if(buySignal) inPos = true;

      if(inPos)
      {
         if(bullVPA || bearVPA)
         {
            double newTSL = (tslCalc > prevTSL) ? tslCalc : prevTSL;
            if(tslCalc > 0 || prevTSL > 0)
            {
               ExtTSLBuffer[i] = newTSL;
               prevTSL = newTSL;
            }
         }
      }
      else
      {
         prevTSL = 0;
         ExtTSLBuffer[i] = EMPTY_VALUE;
      }

      if(inPos && (bullVPA || bearVPA))
         inPos = false;

      //--- Chart Annotations (last bar only)
      if(i == rates_total - 1)
      {
         // Draw arrows for signals
         if(bullVPA)     DrawVPAArrow(0, "BULL", clrLime,       true);
         if(bearVPA)     DrawVPAArrow(0, "BEAR", clrRed,       false);
         if(squat)       DrawVPAArrow(0, "SQUAT", clrOrange,   true);
         if(stoppingVol) DrawVPAArrow(0, "STOP VOL", clrDodgerBlue, true);
         if(toppingOut)  DrawVPAArrow(0, "TOP OUT", clrDeepSkyBlue,  false);
         if(sellClimax)  DrawVPAArrow(0, "SELL CLIMAX!", clrMagenta, false);
         if(buyClimax)   DrawVPAArrow(0, "BUY CLIMAX!", clrMagenta,  true);
         if(lowVolTest)  DrawVPAArrow(0, "LOW VOL TEST", clrYellow,   true);
         if(absorption)  DrawVPAArrow(0, "ABSORB", clrYellow,   true);

         // Dashboard
         string tf = Period() >= 60 ? IntegerToString(Period()/60) + "H" : IntegerToString(Period());
         UpdateDashboardEnhanced(vpaSig, er,
                                ExtRSIBuffer[i], emaSlope, closeLoc,
                                isHighVol, volTrend, volRatio,
                                bullVPA, bearVPA, squat,
                                stoppingVol, toppingOut, absorption,
                                sellClimax, buyClimax, lowVolTest,
                                tf);
      }
   }

   return rates_total;
}
//+------------------------------------------------------------------+
