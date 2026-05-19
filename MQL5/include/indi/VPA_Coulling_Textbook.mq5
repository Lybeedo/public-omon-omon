//+------------------------------------------------------------------+
//|           VPA_Coulling_Textbook.mq5                               |
//|  Volume Price Analysis - Strict Textbook Implementation           |
//|  Based on "A Complete Guide to Volume Price Analysis" by         |
//|  Anna Coulling. Follows her methodology EXACTLY:                  |
//|  - Wyckoff's 3 Laws: Cause & Effect, Effort vs Result,           |
//|    Supply vs Demand                                               |
//|  - Confirmation vs Anomaly framework                            |
//|  - Stopping Volume, Topping Out, Absorption, Climax, Test         |
//|  Version: 1.000 - Textbook Pure                                    |
//+------------------------------------------------------------------+
#property copyright "VPA Textbook - Anna Coulling"
#property version   "1.000"
#property indicator_chart_window
#property indicator_buffers 18
#property indicator_plots    9

//+------------------------------------------------------------------+
//| BUFFER IDs                                                        |
//| Based on Anna Coulling's 2-state framework:                       |
//|   1. Confirmation = volume + price AGREE                         |
//|   2. Anomaly      = volume + price DO NOT AGREE = warning         |
//|                                                                      |
//| Then 6 sub-signals: VALID_BULL, VALID_BEAR, STOPPING_VOL,          |
//| TOPPING_OUT, ABSORPTION, SQUAT_ANOMALY, SELLING_CLIMAX,            |
//| BUYING_CLIMAX, LOW_VOL_TEST                                        |
//+------------------------------------------------------------------+
#define BUF_CONFIRMATION    0  // Confirmation state
#define BUF_ANOMALY         1  // Anomaly state
#define BUF_EFFORT_RESULT    2  // 0=unknown,1=normal,2=anomaly,3=climax
#define BUF_BULL_VALID       3  // Up bar + high vol + wide spread
#define BUF_BEAR_VALID       4  // Down bar + high vol + wide spread
#define BUF_SQUAT_ANOMALY    5  // High vol + narrow spread
#define BUF_STOPPING_VOL     6  // Stopping Volume (insider buying)
#define BUF_TOPPING_OUT      7  // Topping Out Volume (insider selling)
#define BUF_ABSORPTION       8  // Absorption (accumulation/distribution)
#define BUF_SELLING_CLIMAX   9  // Selling Climax (end of distribution)
#define BUF_BUYING_CLIMAX   10  // Buying Climax (end of accumulation)
#define BUF_LOW_VOL_TEST    11  // Low Volume Test (smart money check)
#define BUF_CLOSE_LOCATION  12  // Where close is within range [0..1]
#define BUF_VOL_TREND       13  // Volume trend: -1=falling, 0=neutral, 1=rising
#define BUF_VOL_SMA20       14  // Volume SMA(20)
#define BUF_VOL_RATIO       15  // Current vol / SMA20
#define BUF_SPREAD_SMA20    16  // Spread SMA(20)
#define BUF_SIGNAL          17  // Master signal: 1=BUY, -1=SELL, 0=WAIT

//+------------------------------------------------------------------+
//| INPUTS - Coulling Style (single source of truth)                   |
//+------------------------------------------------------------------+

// --- Volume Settings ---
input group("Volume Settings (Coulling Ch.2-4)")
input float  InpVolSpikeFactor = 1.5;       // Volume must be this x above SMA20 to be "high"
input int    InpVolPeriod      = 20;        // Period for volume SMA (benchmark)
input float  InpUltraHighVol  = 2.5;       // Multiplier for "ultra high" volume
input float  InpLowVolFactor  = 0.5;       // Below this x SMA20 = "low"

// --- Spread Settings ---
input group("Spread Settings (Effort vs Result)")
input float  InpWideSpread     = 1.2;       // Above this x avg spread = "wide"
input float  InpNarrowSpread  = 0.7;       // Below this x avg spread = "narrow"
input int    InpSpreadPeriod   = 20;        // Period for spread SMA
input int    InpBodyMinRatio  = 50;         // Body must be at least X% of spread

// --- Trend & S/R ---
input group("Trend & Structure (Coulling Ch.5-7)")
input int    InpTrendEMA       = 50;        // EMA for trend direction
input int    InpTrendPeriod   = 5;         // Slope period (for trend strength)
input int    InpPivotLB        = 10;        // Pivot lookback for S/R
input int    InpWickDeepRatio  = 60;         // Wick must be X% of range to be "deep"

// --- Climax Settings (Coulling Ch.5) ---
input group("Climax Detection (Coulling Ch.5)")
input int    InpClimaxCandles  = 3;         // Candles in climax sequence
input float  InpClimaxVolMult = 2.0;       // Volume multiplier for climax

// --- Dashboard ---
input group("Dashboard")
input string InpDashPos        = "Top Right"; // Dashboard position
input color  InpBullColor      = clrLime;    // Bullish color
input color  InpBearColor      = clrRed;     // Bearish color
input color  InpAnomalyColor   = clrOrange;  // Anomaly color
input color  InpNeutralColor   = clrGray;    // Neutral color

//+------------------------------------------------------------------+
//| GLOBAL STATE                                                       |
//+------------------------------------------------------------------+

// Volume buffers
double gVolSMA20[];
double gVolRatio[];
double gVolTrend[];

// Spread buffers
double gSpreadSMA20[];

// Price-based buffers
double gCloseLocation[];  // 0=low, 0.5=mid, 1=high
double gBodyRatio[];      // body/spread ratio
double gLowerWickRatio[]; // lower wick / spread
double gUpperWickRatio[]; // upper wick / spread

// VPA state buffers
double gConfirmation[];
double gAnomaly[];
double gEffortResult[];   // 0=none, 1=normal, 2=anomaly_wide_lowvol, 3=anomaly_narrow_highvol, 4=climax
double gBullValid[];
double gBearValid[];
double gSquatAnomaly[];
double gStoppingVol[];
double gToppingOut[];
double gAbsorption[];
double gSellingClimax[];
double gBuyingClimax[];
double gLowVolTest[];
double gSignal[];

// DTL / S/R state
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
   // Set all buffers as series
   ArraySetAsSeries(gVolSMA20,      true);
   ArraySetAsSeries(gVolRatio,      true);
   ArraySetAsSeries(gVolTrend,      true);
   ArraySetAsSeries(gSpreadSMA20,   true);
   ArraySetAsSeries(gCloseLocation, true);
   ArraySetAsSeries(gBodyRatio,      true);
   ArraySetAsSeries(gLowerWickRatio, true);
   ArraySetAsSeries(gUpperWickRatio, true);
   ArraySetAsSeries(gConfirmation,   true);
   ArraySetAsSeries(gAnomaly,        true);
   ArraySetAsSeries(gEffortResult,   true);
   ArraySetAsSeries(gBullValid,      true);
   ArraySetAsSeries(gBearValid,      true);
   ArraySetAsSeries(gSquatAnomaly,   true);
   ArraySetAsSeries(gStoppingVol,    true);
   ArraySetAsSeries(gToppingOut,     true);
   ArraySetAsSeries(gAbsorption,      true);
   ArraySetAsSeries(gSellingClimax,  true);
   ArraySetAsSeries(gBuyingClimax,   true);
   ArraySetAsSeries(gLowVolTest,     true);
   ArraySetAsSeries(gSignal,         true);

   // Bind buffers
   SetIndexBuffer(BUF_VOL_SMA20,      gVolSMA20,       INDICATOR_DATA);
   SetIndexBuffer(BUF_VOL_RATIO,      gVolRatio,       INDICATOR_CALCULATIONS);
   SetIndexBuffer(BUF_VOL_TREND,       gVolTrend,       INDICATOR_DATA);
   SetIndexBuffer(BUF_SPREAD_SMA20,   gSpreadSMA20,    INDICATOR_DATA);
   SetIndexBuffer(BUF_CLOSE_LOCATION,  gCloseLocation,  INDICATOR_DATA);
   SetIndexBuffer(BUF_CONFIRMATION,   gConfirmation,   INDICATOR_DATA);
   SetIndexBuffer(BUF_ANOMALY,        gAnomaly,        INDICATOR_DATA);
   SetIndexBuffer(BUF_EFFORT_RESULT,  gEffortResult,   INDICATOR_DATA);
   SetIndexBuffer(BUF_BULL_VALID,     gBullValid,      INDICATOR_DATA);
   SetIndexBuffer(BUF_BEAR_VALID,     gBearValid,      INDICATOR_DATA);
   SetIndexBuffer(BUF_SQUAT_ANOMALY,  gSquatAnomaly,   INDICATOR_DATA);
   SetIndexBuffer(BUF_STOPPING_VOL,  gStoppingVol,    INDICATOR_DATA);
   SetIndexBuffer(BUF_TOPPING_OUT,   gToppingOut,     INDICATOR_DATA);
   SetIndexBuffer(BUF_ABSORPTION,    gAbsorption,     INDICATOR_DATA);
   SetIndexBuffer(BUF_SELLING_CLIMAX, gSellingClimax, INDICATOR_DATA);
   SetIndexBuffer(BUF_BUYING_CLIMAX, gBuyingClimax,   INDICATOR_DATA);
   SetIndexBuffer(BUF_LOW_VOL_TEST,  gLowVolTest,    INDICATOR_DATA);
   SetIndexBuffer(BUF_SIGNAL,        gSignal,         INDICATOR_DATA);

   // Plot 1: Confirmation (green line when confirmed)
   PlotIndexSetString(0, PLOT_LABEL, "VPA Confirmation");
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_NONE);

   // Plot 2: Anomaly (orange)
   PlotIndexSetString(1, PLOT_LABEL, "VPA Anomaly");
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);

   // Plot 3: Effort vs Result state (colors)
   PlotIndexSetString(2, PLOT_LABEL, "Effort vs Result");
   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_NONE);

   // Plot 4: Bull Valid
   PlotIndexSetString(3, PLOT_LABEL, "Bull Valid");
   PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_ARROW);
   PlotIndexSetInteger(3, PLOT_ARROW, 233);
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, InpBullColor);

   // Plot 5: Bear Valid
   PlotIndexSetString(4, PLOT_LABEL, "Bear Valid");
   PlotIndexSetInteger(4, PLOT_DRAW_TYPE, DRAW_ARROW);
   PlotIndexSetInteger(4, PLOT_ARROW, 234);
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, InpBearColor);

   // Plot 6: Squat Anomaly
   PlotIndexSetString(5, PLOT_LABEL, "Squat Anomaly");
   PlotIndexSetInteger(5, PLOT_DRAW_TYPE, DRAW_ARROW);
   PlotIndexSetInteger(5, PLOT_ARROW, 159);
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, InpAnomalyColor);

   // Plot 7: Stopping Volume
   PlotIndexSetString(6, PLOT_LABEL, "Stopping Volume");
   PlotIndexSetInteger(6, PLOT_DRAW_TYPE, DRAW_ARROW);
   PlotIndexSetInteger(6, PLOT_ARROW, 233);
   PlotIndexSetInteger(6, PLOT_LINE_COLOR, clrDodgerBlue);

   // Plot 8: Topping Out
   PlotIndexSetString(7, PLOT_LABEL, "Topping Out");
   PlotIndexSetInteger(7, PLOT_DRAW_TYPE, DRAW_ARROW);
   PlotIndexSetInteger(7, PLOT_ARROW, 234);
   PlotIndexSetInteger(7, PLOT_LINE_COLOR, clrDeepSkyBlue);

   // Plot 9: Signal (master)
   PlotIndexSetString(8, PLOT_LABEL, "Signal");
   PlotIndexSetInteger(8, PLOT_DRAW_TYPE, DRAW_NONE);

   // Create indicator handles
   gAtrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
   if(gAtrHandle == INVALID_HANDLE) { Print("[VPA TextBook] ATR handle error!"); return INIT_FAILED; }

   gEmaHandle = iMA(_Symbol, PERIOD_CURRENT, InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
   if(gEmaHandle == INVALID_HANDLE) { Print("[VPA TextBook] EMA handle error!"); return INIT_FAILED; }

   IndicatorSetString(INDICATOR_SHORTNAME, "VPA_Coulling_Textbook v1.0");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(gAtrHandle != INVALID_HANDLE) IndicatorRelease(gAtrHandle);
   if(gEmaHandle != INVALID_HANDLE) IndicatorRelease(gEmaHandle);
   // Delete all drawn objects
   for(int i = 0; i < 100; i++)
   {
      ObjectDelete(0, "VPA_Arrow_" + IntegerToString(i));
      ObjectDelete(0, "VPA_Label_" + IntegerToString(i));
   }
   Comment("");
}

//+------------------------------------------------------------------+
//| HELPER: Calculate Volume Stats                                     |
//+------------------------------------------------------------------+
void CalcVolumeStats(int shift, double& volSMA, double& volRatio, bool& isHigh, bool& isUltraHigh, bool& isLow)
{
   if(shift < InpVolPeriod) { volSMA = 0; volRatio = 0; isHigh = false; isUltraHigh = false; isLow = false; return; }

   double sum = 0;
   for(int i = shift; i < shift + InpVolPeriod; i++) sum += (double)Volume[i];
   volSMA = sum / InpVolPeriod;

   if(volSMA > 0) volRatio = (double)Volume[shift] / volSMA;
   else          volRatio = 0;

   isHigh     = (volRatio >= InpVolSpikeFactor);
   isUltraHigh = (volRatio >= InpUltraHighVol);
   isLow      = (volRatio < InpLowVolFactor);
}

//+------------------------------------------------------------------+
//| HELPER: Calculate Spread Stats                                     |
//+------------------------------------------------------------------+
void CalcSpreadStats(int shift, double& spread, double& spreadSMA, bool& isWide, bool& isNarrow)
{
   if(shift < InpSpreadPeriod) { spread = 0; spreadSMA = 0; isWide = false; isNarrow = false; return; }

   spread = High[shift] - Low[shift];
   double sum = 0;
   for(int i = shift; i < shift + InpSpreadPeriod; i++) sum += (High[i] - Low[i]);
   spreadSMA = sum / InpSpreadPeriod;

   isWide   = (spread > spreadSMA * InpWideSpread);
   isNarrow = (spread < spreadSMA * InpNarrowSpread);
}

//+------------------------------------------------------------------+
//| HELPER: Candle Anatomy (Coulling Ch.3-4)                          |
//+------------------------------------------------------------------+
void CalcCandleAnatomy(int shift, double& bodySize, double& lowerWick, double& upperWick,
                       double& bodyRatio, double& closeLocation,
                       bool& isUpBar, bool& isDownBar)
{
   double openPrice  = Open[shift];
   double closePrice = Close[shift];
   double highPrice  = High[shift];
   double lowPrice   = Low[shift];
   double range      = highPrice - lowPrice;

   bodySize   = MathAbs(closePrice - openPrice);
   lowerWick  = MathMin(openPrice, closePrice) - lowPrice;
   upperWick  = highPrice - MathMax(openPrice, closePrice);
   isUpBar    = (closePrice > openPrice);
   isDownBar  = (closePrice < openPrice);

   if(range > 0) {
      bodyRatio      = bodySize / range * 100.0;
      closeLocation  = (closePrice - lowPrice) / range; // 0=low, 1=high
   } else {
      bodyRatio     = 0;
      closeLocation = 0.5;
   }
}

//+------------------------------------------------------------------+
//| HELPER: Is Deep Wick? (for Stopping/Topping detection)            |
//+------------------------------------------------------------------+
bool IsDeepLowerWick(double lowerWick, double range)
{
   return (range > 0 && lowerWick / range * 100.0 >= InpWickDeepRatio);
}

bool IsDeepUpperWick(double upperWick, double range)
{
   return (range > 0 && upperWick / range * 100.0 >= InpWickDeepRatio);
}

//+------------------------------------------------------------------+
//| HELPER: Trend Direction (Coulling Ch.7)                           |
//+------------------------------------------------------------------+
int GetTrendDirection(int emaHandle, int shift)
{
   double emaCur = 0, emaPrev = 0;
   double buf1[], buf2[];
   ArraySetAsSeries(buf1, true);
   ArraySetAsSeries(buf2, true);

   if(emaHandle != INVALID_HANDLE)
   {
      if(CopyBuffer(emaHandle, 0, shift, 1, buf1) > 0 &&
         CopyBuffer(emaHandle, 0, shift + InpTrendPeriod, 1, buf2) > 0)
      {
         emaCur  = buf1[0];
         emaPrev = buf2[0];
         if(emaPrev != 0)
         {
            double slopePct = (emaCur - emaPrev) / emaPrev * 100.0;
            if(slopePct > 0.05)  return  1;  // Bull trend
            if(slopePct < -0.05) return -1;  // Bear trend
         }
      }
   }
   return 0; // Neutral
}

//+------------------------------------------------------------------+
//| HELPER: Volume Trend (rising or falling over last N bars)         |
//| Coulling Ch.4: Rising prices = rising volume expected            |
//+------------------------------------------------------------------+
int GetVolumeTrend(int shift)
{
   if(shift < InpVolPeriod) return 0;
   double recent = 0, older = 0;
   for(int i = shift;       i < shift + InpVolPeriod / 2; i++) recent += (double)Volume[i];
   for(int i = shift + InpVolPeriod / 2; i < shift + InpVolPeriod; i++) older += (double)Volume[i];
   if(older > 0)
   {
      double ratio = recent / older;
      if(ratio > 1.1) return  1; // Rising volume
      if(ratio < 0.9) return -1; // Falling volume
   }
   return 0; // Neutral
}

//+------------------------------------------------------------------+
//| HELPER: Custom Pivot High (DTL structure - Coulling Ch.7)         |
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
//| HELPER: Update DTL (Coulling Ch.7 - Support/Resistance)           |
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
//| HELPER: Get DTL price at given shift                               |
//+------------------------------------------------------------------+
double GetDTLPrice(int shift)
{
   if(gP1Y == EMPTY_VALUE || gP2Y == EMPTY_VALUE || gP1X == 0) return 0;
   if(gP1Y >= gP2Y) return 0; // Not a valid DTL (slope must be negative)
   return gP1Y + gSlope * (double)(shift - gP1X);
}

//+------------------------------------------------------------------+
//| CORE: Classify Effort vs Result (Wyckoff's 3rd Law)              |
//| Coulling Ch.4 - The most fundamental rule                         |
//+------------------------------------------------------------------+
int ClassifyEffortResult(bool isHighVol, bool isLowVol, bool isWideSpread, bool isNarrowSpread)
{
   // NORMAL: effort = result
   // 1. Wide spread + High volume = VALID (effort matches result)
   // 2. Narrow spread + Low volume = VALID (small effort, small result)
   // ANOMALY: effort != result
   // 3. Wide spread + Low volume = ANOMALY (big result, little effort = trap)
   // 4. Narrow spread + High volume = ANOMALY (big effort, little result = weakness)

   if(isHighVol)
   {
      if(isNarrowSpread) return 3; // Anomaly: high effort, little result
      if(isWideSpread)   return 1; // Normal: high effort, big result
   }
   else if(isLowVol)
   {
      if(isWideSpread)   return 2; // Anomaly: big result from little effort
      if(isNarrowSpread) return 1; // Normal: small effort, small result
   }
   return 0; // Neutral / indeterminate
}

//+------------------------------------------------------------------+
//| CORE: BULL VALID (Coulling Ch.4)                                 |
//| Condition: Up bar + Wide Spread + High Volume + Valid body        |
//| "Volume validates the price action - market is bullish"            |
//+------------------------------------------------------------------+
bool IsBullValid(bool isUpBar, bool isWideSpread, bool isHighVol, double bodyRatio)
{
   return isUpBar && isWideSpread && isHighVol && bodyRatio >= InpBodyMinRatio;
}

//+------------------------------------------------------------------+
//| CORE: BEAR VALID (Coulling Ch.4)                                  |
//| Condition: Down bar + Wide Spread + High Volume + Valid body     |
//| "Volume validates the price action - market is bearish"            |
//+------------------------------------------------------------------+
bool IsBearValid(bool isDownBar, bool isWideSpread, bool isHighVol, double bodyRatio)
{
   return isDownBar && isWideSpread && isHighVol && bodyRatio >= InpBodyMinRatio;
}

//+------------------------------------------------------------------+
//| CORE: SQUAT ANOMALY (Coulling Ch.4, 6, 10)                        |
//| High volume + Narrow spread = ANOMALY                             |
//| This is the ONLY anomaly pattern detected per-candle              |
//| Sub-classified by close location:                                 |
//|   Near low  = potential stopping volume / absorption = bullish    |
//|   Near high = potential topping out / absorption = bearish       |
//|   Mid-range = absorbing (inconclusive, WAIT)                     |
//+------------------------------------------------------------------+
bool IsSquatAnomaly(bool isHighVol, bool isNarrowSpread)
{
   return isHighVol && isNarrowSpread;
}

//+------------------------------------------------------------------+
//| CORE: STOPPING VOLUME (Coulling Ch.6, 10)                        |
//| "Insiders move in to absorb selling pressure"                      |
//| CONDITIONS (ALL must be true):                                    |
//| 1. Down bar (selling in progress)                                 |
//| 2. High or Ultra High volume (insider buying effort)             |
//| 3. Deep lower wick (price recovered, buyers absorbed selling)     |
//| 4. Close in UPPER HALF of candle (recovery strong)              |
//| 5. Occurs in BEAR TREND (before stopping makes sense)            |
//| RESULT: Reversal to upside likely                                 |
//+------------------------------------------------------------------+
bool IsStoppingVolume(bool isDownBar, bool isHighVol, bool isUltraHigh,
                     bool deepLowerWick, double closeLoc, int trendDir)
{
   return isDownBar && (isHighVol || isUltraHigh)
          && deepLowerWick && (closeLoc >= 0.5)
          && (trendDir <= 0); // Bear or neutral trend
}

//+------------------------------------------------------------------+
//| CORE: TOPPING OUT VOLUME (Coulling Ch.6)                         |
//| "Just as stopping volume was stopping the market from falling,     |
//|  so topping out volume is the market topping out after a           |
//|  bullish run higher"                                               |
//| CONDITIONS (ALL must be true):                                    |
//| 1. Up bar (buying in progress)                                   |
//| 2. High or Ultra High volume (insider distribution effort)       |
//| 3. Deep upper wick (insiders selling into strength)              |
//| 4. Close in LOWER HALF (failed to hold highs)                   |
//| 5. Occurs in BULL TREND (before topping makes sense)             |
//| RESULT: Reversal to downside likely                               |
//+------------------------------------------------------------------+
bool IsToppingOut(bool isUpBar, bool isHighVol, bool isUltraHigh,
                  bool deepUpperWick, double closeLoc, int trendDir)
{
   return isUpBar && (isHighVol || isUltraHigh)
          && deepUpperWick && (closeLoc <= 0.5)
          && (trendDir >= 0); // Bull or neutral trend
}

//+------------------------------------------------------------------+
//| CORE: ABSORPTION (Coulling Ch.4, 6)                               |
//| "The specialists absorb the volume, but price doesn't move        |
//|  in the expected direction - the market is being controlled"     |
//| CONDITIONS:                                                       |
//| - High volume candle in direction A, but close barely moved       |
//| - Close location near extreme of opposite direction              |
//| - Body ratio < 40% (very small body despite high volume)         |
//+------------------------------------------------------------------+
bool IsAbsorption(bool isHighVol, double bodyRatio, double closeLoc, bool isUpBar, bool isDownBar)
{
   if(!isHighVol || bodyRatio >= 40.0) return false;
   // Absorption: large effort (high vol), tiny result (small body)
   // If up bar but close near lows = absorption of buying = bearish
   // If down bar but close near highs = absorption of selling = bullish
   if(isUpBar   && closeLoc < 0.35) return true;  // Absorption of up move
   if(isDownBar && closeLoc > 0.65) return true;  // Absorption of down move
   return false;
}

//+------------------------------------------------------------------+
//| CORE: SELLING CLIMAX (Coulling Ch.5)                              |
//| "The last hurrah before insiders take the market lower"           |
//| "Generally 2-3 times on high volume with the market closing        |
//|  back at the open"                                                |
//| CONDITIONS:                                                       |
//| 1. SEQUENCE of 2-3 bars, each with:                               |
//|    - Wide spread (big price swing)                               |
//|    - High or Ultra High volume                                   |
//|    - Close near the open (doji-like, body < 30% of range)        |
//| 2. Occurs at end of BULL TREND (after prolonged rise)            |
//| 3. Volume SPILLING OVER on last candle (climax = maximum effort) |
//| RESULT: End of distribution - sharp move lower coming            |
//+------------------------------------------------------------------+
bool IsSellingClimax(int shift, bool isUltraHigh, int trendDir)
{
   if(trendDir < 0) return false; // Must be in bull trend

   int count = 0;
   bool climaxFormed = false;

   for(int i = shift; i < shift + InpClimaxCandles && i < Bars - 1; i++)
   {
      double range     = High[i] - Low[i];
      double bodySize  = MathAbs(Close[i] - Open[i]);
      double bodyRatio = (range > 0) ? bodySize / range * 100.0 : 0;
      double closeLoc  = (range > 0) ? (Close[i] - Low[i]) / range : 0.5;

      double volRatio = 0;
      double volSum = 0;
      for(int j = i; j < i + InpVolPeriod && j < Bars; j++) volSum += (double)Volume[j];
      double volSMA = volSum / InpVolPeriod;
      if(volSMA > 0) volRatio = (double)Volume[i] / volSMA;

      bool isWideSpread = (range > 0);
      if(volSMA > 0)
      {
         double avgSpread = 0;
         double sprSum = 0;
         for(int j = i; j < i + InpSpreadPeriod && j < Bars; j++) sprSum += (High[j] - Low[j]);
         avgSpread = sprSum / InpSpreadPeriod;
         isWideSpread = (range > avgSpread * InpWideSpread);
      }

      // Each candle in climax: wide range, high vol, doji-like
      bool isWideAndVol = (volRatio >= InpClimaxVolMult) && isWideSpread;
      bool isDoji = (bodyRatio < 30.0);
      bool closeNearOpen = (closeLoc > 0.35 && closeLoc < 0.65);

      if(isWideAndVol && isDoji && closeNearOpen) count++;
   }

   climaxFormed = (count >= 2); // At least 2 climax candles
   return climaxFormed && isUltraHigh;
}

//+------------------------------------------------------------------+
//| CORE: BUYING CLIMAX (Coulling Ch.5)                              |
//| "Opposite of selling climax - end of accumulation phase"           |
//| "Generally 2-3 times on high volume with the market closing        |
//|  back at the open"                                                |
//| Similar logic to selling climax but in opposite direction         |
//| CONDITIONS:                                                       |
//| 1. Sequence of 2-3 bars with:                                     |
//|    - Wide spread + High volume                                   |
//|    - Close near the open (doji-like)                            |
//| 2. Occurs at end of BEAR TREND (after prolonged fall)           |
//| RESULT: End of accumulation - sharp move higher coming            |
//+------------------------------------------------------------------+
bool IsBuyingClimax(int shift, bool isUltraHigh, int trendDir)
{
   if(trendDir > 0) return false; // Must be in bear trend

   int count = 0;
   for(int i = shift; i < shift + InpClimaxCandles && i < Bars - 1; i++)
   {
      double range     = High[i] - Low[i];
      double bodySize  = MathAbs(Close[i] - Open[i]);
      double bodyRatio = (range > 0) ? bodySize / range * 100.0 : 0;
      double closeLoc  = (range > 0) ? (Close[i] - Low[i]) / range : 0.5;

      double volSum = 0;
      for(int j = i; j < i + InpVolPeriod && j < Bars; j++) volSum += (double)Volume[j];
      double volSMA = volSum / InpVolPeriod;
      double volRatio = (volSMA > 0) ? (double)Volume[i] / volSMA : 0;

      bool isWideSpread = (range > 0);
      if(volSMA > 0)
      {
         double sprSum = 0;
         for(int j = i; j < i + InpSpreadPeriod && j < Bars; j++) sprSum += (High[j] - Low[j]);
         double avgSpread = sprSum / InpSpreadPeriod;
         isWideSpread = (range > avgSpread * InpWideSpread);
      }

      bool isWideAndVol = (volRatio >= InpClimaxVolMult) && isWideSpread;
      bool isDoji = (bodyRatio < 30.0);
      bool closeNearOpen = (closeLoc > 0.35 && closeLoc < 0.65);

      if(isWideAndVol && isDoji && closeNearOpen) count++;
   }

   return (count >= 2) && isUltraHigh;
}

//+------------------------------------------------------------------+
//| CORE: LOW VOLUME TEST (Coulling Ch.5, p.47)                      |
//| "The market is marked higher using some news, and if there is     |
//|  no demand, closes back near the open, with very low volume"       |
//| CONDITIONS:                                                       |
//| 1. Low volume (below InpLowVolFactor x SMA)                      |
//| 2. Close near the open (body small, < 40% of range)             |
//| 3. After distribution/accumulation phase                          |
//| RESULT: If at support = SUPER BULLISH (no buyers left)            |
//|         If at resistance = SUPER BEARISH (no sellers left)        |
//+------------------------------------------------------------------+
bool IsLowVolTest(bool isLowVol, double bodyRatio, bool isUpBar, bool isDownBar)
{
   // Low vol + narrow body (test) = smart money checking for remaining demand/supply
   return isLowVol && bodyRatio < 40.0;
}

//+------------------------------------------------------------------+
//| HELPER: Get master signal from all VPA states                     |
//| Following Coulling's priority hierarchy:                          |
//|  1. Selling Climax   = -2 (exit longs, prepare shorts)           |
//|  2. Buying Climax    = +2 (exit shorts, prepare longs)           |
//|  3. Stopping Volume  = +1 (potential long entry)                 |
//|  4. Topping Out      = -1 (potential short entry)                |
//|  5. Bull Valid       = +1 (confirmation, ride the trend)         |
//|  6. Bear Valid       = -1 (confirmation, ride the trend)         |
//|  7. Absorption       =  0 (wait, unclear)                        |
//|  8. Squat Anomaly    =  0 (caution, need context)                |
//|  9. Low Vol Test     = +1/-1 (context dependent)                 |
//|  0. No signal       =  0 (neutral)                              |
//+------------------------------------------------------------------+
int GetMasterSignal(bool bullValid, bool bearValid, bool squat,
                   bool stoppingVol, bool toppingOut, bool absorption,
                   bool sellingClimax, bool buyingClimax, bool lowVolTest,
                   double closeLoc, int trendDir)
{
   // Priority 1: Climax (end of phase)
   if(sellingClimax) return -2;
   if(buyingClimax)  return  2;

   // Priority 2: Stopping Volume (reversal from down)
   if(stoppingVol) return  1;

   // Priority 3: Topping Out (reversal from up)
   if(toppingOut)  return -1;

   // Priority 4: Low Volume Test (context-dependent)
   if(lowVolTest)
   {
      if(trendDir >= 0) return  1; // In bull/flat: low vol test at support = bullish
      if(trendDir < 0) return -1;  // In bear: low vol test = potential bullish reversal
   }

   // Priority 5: Absorption (wait)
   if(absorption) return 0;

   // Priority 6: Squat (wait)
   if(squat) return 0;

   // Priority 7: Trend confirmation
   if(bullValid && trendDir > 0) return  1;
   if(bearValid && trendDir < 0) return -1;

   return 0; // No clear signal
}

//+------------------------------------------------------------------+
//| HELPER: Draw annotation on chart                                  |
//+------------------------------------------------------------------+
void DrawAnnotation(int shift, string text, color clr, bool belowBar)
{
   static int counter = 0;
   string name = "VPA_Arrow_" + IntegerToString(counter);
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);

   double price = belowBar ? Low[shift] - 50*_Point : High[shift] + 50*_Point;
   if(!belowBar) price = High[shift] + 50*_Point;

   if(!ObjectCreate(0, name, OBJ_TEXT, 0, Time[shift], price))
      return;

   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, belowBar ? ANCHOR_BOTTOM : ANCHOR_TOP);
   counter++;
   if(counter > 99) counter = 0;
}

//+------------------------------------------------------------------+
//| HELPER: Update Dashboard (Coulling Dashboard)                     |
//+------------------------------------------------------------------+
void UpdateDashboard(string vpaStatus, string effortResult, string signal,
                    string trend, color trendCol, double rsiVal,
                    double closeLoc, bool highVol, int volTrend,
                    double volRatio, string tf)
{
   // Remove old dashboard
   string dashName = "VPA_Dashboard";
   if(ObjectFind(0, dashName) >= 0) ObjectDelete(0, dashName);

   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int xBase = (InpDashPos == "Top Right" || InpDashPos == "Middle Right" || InpDashPos == "Bottom Right")
               ? chartW - 280 : 10;
   int yBase = 30;

   // Background panel
   ObjectCreate(0, dashName + "_bg", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, dashName + "_bg", OBJPROP_XDISTANCE, xBase);
   ObjectSetInteger(0, dashName + "_bg", OBJPROP_YDISTANCE, yBase);
   ObjectSetInteger(0, dashName + "_bg", OBJPROP_XSIZE, 270);
   ObjectSetInteger(0, dashName + "_bg", OBJPROP_YSIZE, 290);
   ObjectSetInteger(0, dashName + "_bg", OBJPROP_BGCOLOR, C'10,10,20');
   ObjectSetInteger(0, dashName + "_bg", OBJPROP_BORDER_COLOR, clrGray);
   ObjectSetInteger(0, dashName + "_bg", OBJPROP_ZORDER, 0);

   string rows[][2] = {
      {"=== VPA COULLING ===", tf + "M"},
      {"VPA Status",     vpaStatus},
      {"Effort vs Result",effortResult},
      {"Master Signal",  signal},
      {"Trend",           trend},
      {"RSI(14)",         DoubleToString(rsiVal, 2)},
      {"Vol Ratio",       DoubleToString(volRatio, 2) + "x"},
      {"Vol Trend",       volTrend > 0 ? "RISING" : volTrend < 0 ? "FALLING" : "FLAT"},
      {"Close Location",  DoubleToString(closeLoc*100, 0) + "% (high)"},
      {"High Volume?",    highVol ? "YES" : "NO"}
   };

   for(int r = 0; r < ArraySize(rows); r++)
   {
      string lName = dashName + "_L" + IntegerToString(r);
      string vName = dashName + "_V" + IntegerToString(r);

      ObjectCreate(0, lName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, lName, OBJPROP_XDISTANCE, xBase + 5);
      ObjectSetInteger(0, lName, OBJPROP_YDISTANCE, yBase + 5 + r * 24);
      ObjectSetString(0, lName, OBJPROP_TEXT, rows[r][0]);
      ObjectSetInteger(0, lName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, lName, OBJPROP_FONTSIZE, 7);
      ObjectSetInteger(0, lName, OBJPROP_ZORDER, 1);

      ObjectCreate(0, vName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, vName, OBJPROP_XDISTANCE, xBase + 145);
      ObjectSetInteger(0, vName, OBJPROP_YDISTANCE, yBase + 5 + r * 24);
      ObjectSetString(0, vName, OBJPROP_TEXT, rows[r][1]);
      ObjectSetInteger(0, vName, OBJPROP_FONTSIZE, 7);
      ObjectSetInteger(0, vName, OBJPROP_ZORDER, 1);

      // Color coding for value column
      color valClr = clrWhite;
      color valBg  = CLR_NONE;

      if(r == 1) { // VPA Status
         if(StringFind(vpaStatus, "BULL") >= 0)      { valClr = InpBullColor;    valBg = color.new(InpBullColor, 80); }
         if(StringFind(vpaStatus, "BEAR") >= 0)      { valClr = InpBearColor;    valBg = color.new(InpBearColor, 80); }
         if(StringFind(vpaStatus, "ANOMALY") >= 0)   { valClr = InpAnomalyColor; valBg = color.new(InpAnomalyColor, 80); }
         if(StringFind(vpaStatus, "STOPPING") >= 0)  { valClr = clrDodgerBlue;   valBg = color.new(clrDodgerBlue, 80); }
         if(StringFind(vpaStatus, "TOPPING") >= 0)   { valClr = clrDeepSkyBlue;  valBg = color.new(clrDeepSkyBlue, 80); }
         if(StringFind(vpaStatus, "CLIMAX") >= 0)     { valClr = clrMagenta;      valBg = color.new(clrMagenta, 80); }
         if(StringFind(vpaStatus, "TEST") >= 0)      { valClr = clrYellow;       valBg = color.new(clrYellow, 80); }
      }
      if(r == 2) { // Effort vs Result
         if(StringFind(effortResult, "ANOMALY") >= 0)  { valClr = InpAnomalyColor; valBg = color.new(InpAnomalyColor, 80); }
         if(StringFind(effortResult, "CLIMAX") >= 0)   { valClr = clrMagenta;      valBg = color.new(clrMagenta, 80); }
         if(StringFind(effortResult, "NORMAL") >= 0)   { valClr = InpNeutralColor; valBg = color.new(InpNeutralColor, 80); }
      }
      if(r == 3) { // Signal
         if(StringFind(signal, "BUY") >= 0)     { valClr = InpBullColor;    valBg = color.new(InpBullColor, 80); }
         if(StringFind(signal, "SELL") >= 0)    { valClr = InpBearColor;    valBg = color.new(InpBearColor, 80); }
         if(StringFind(signal, "NEUTRAL") >= 0) { valClr = InpNeutralColor; valBg = color.new(InpNeutralColor, 80); }
         if(StringFind(signal, "CLIMAX") >= 0)  { valClr = clrMagenta;      valBg = color.new(clrMagenta, 80); }
      }
      if(r == 4) { trendCol = trendCol; valBg = color.new(trendCol, 70); }
      if(r == 5) { // RSI
         if(rsiVal > 70) valBg = color.new(clrRed, 70);
         if(rsiVal < 30) valBg = color.new(InpBullColor, 70);
      }

      ObjectSetInteger(0, vName, OBJPROP_COLOR, valClr);
      if(valBg != CLR_NONE)
         ObjectSetInteger(0, vName, OBJPROP_BGCOLOR, valBg);
   }
}

//+------------------------------------------------------------------+
//| HELPER: Get VPA Status label                                      |
//+------------------------------------------------------------------+
string GetVPAStatusLabel(bool bullValid, bool bearValid, bool squat,
                         bool stoppingVol, bool toppingOut, bool absorption,
                         bool sellingClimax, bool buyingClimax, bool lowVolTest)
{
   if(sellingClimax) return "SELLING CLIMAX!";
   if(buyingClimax)  return "BUYING CLIMAX!";
   if(stoppingVol)   return "STOPPING VOL";
   if(toppingOut)    return "TOPPING OUT";
   if(bullValid)     return "VALID BULL";
   if(bearValid)     return "VALID BEAR";
   if(absorption)    return "ABSORPTION";
   if(lowVolTest)    return "LOW VOL TEST";
   if(squat)         return "SQUAT ANOMALY";
   return "NEUTRAL";
}

//+------------------------------------------------------------------+
//| HELPER: Get Effort Result label                                   |
//+------------------------------------------------------------------+
string GetEffortResultLabel(int er)
{
   switch(er)
   {
      case 1: return "NORMAL (effort=result)";
      case 2: return "ANOMALY (wide+lowvol=trap)";
      case 3: return "ANOMALY (narrow+highvol=weak)";
      case 4: return "CLIMAX (max effort)";
      default: return "INDETERMINATE";
   }
}

//+------------------------------------------------------------------+
//| HELPER: Get Signal label                                          |
//+------------------------------------------------------------------+
string GetSignalLabel(int sig)
{
   switch(sig)
   {
      case  2: return "=== BUY CLIMAX EXIT ===";
      case  1: return "BUY (confirmation)";
      case -1: return "SELL (confirmation)";
      case -2: return "=== SELL CLIMAX EXIT ===";
      default: return "NEUTRAL (wait)";
   }
}

//+------------------------------------------------------------------+
//| OnCalculate                                                       |
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
   if(rates_total < MathMax(MathMax(InpVolPeriod, InpSpreadPeriod), InpPivotLB) + 5)
      return 0;

   int start = prev_calculated > 0 ? prev_calculated - 1 : MathMax(InpVolPeriod, InpSpreadPeriod);

   // Copy ATR & EMA
   double atrBuf[], emaBuf[];
   ArraySetAsSeries(atrBuf, true);
   ArraySetAsSeries(emaBuf, true);
   CopyBuffer(gAtrHandle, 0, 0, rates_total, atrBuf);
   CopyBuffer(gEmaHandle, 0, 0, rates_total, emaBuf);

   for(int i = start; i < rates_total && !IsStopped(); i++)
   {
      //--- 1. VOLUME STATS
      double volSMA = 0, volRatio = 0;
      bool isHighVol = false, isUltraHigh = false, isLowVol = false;
      CalcVolumeStats(i, volSMA, volRatio, isHighVol, isUltraHigh, isLowVol);
      gVolSMA20[i]    = volSMA;
      gVolRatio[i]    = volRatio;

      int volTrend = GetVolumeTrend(i);
      gVolTrend[i]   = volTrend;

      //--- 2. SPREAD STATS
      double spread_ = 0, spreadSMA = 0;
      bool isWideSpread = false, isNarrowSpread = false;
      CalcSpreadStats(i, spread_, spreadSMA, isWideSpread, isNarrowSpread);
      gSpreadSMA20[i] = spreadSMA;

      //--- 3. CANDLE ANATOMY
      double bodySize = 0, lowerWick = 0, upperWick = 0;
      double bodyRatio = 0, closeLoc = 0;
      bool isUpBar = false, isDownBar = false;
      CalcCandleAnatomy(i, bodySize, lowerWick, upperWick, bodyRatio, closeLoc, isUpBar, isDownBar);
      gCloseLocation[i] = closeLoc;
      gBodyRatio[i]      = bodyRatio;
      gLowerWickRatio[i] = (spread_ > 0) ? lowerWick / spread_ * 100.0 : 0;
      gUpperWickRatio[i] = (spread_ > 0) ? upperWick / spread_ * 100.0 : 0;

      //--- 4. TREND DIRECTION
      int trendDir = GetTrendDirection(gEmaHandle, i);

      //--- 5. DTL UPDATE
      UpdateDTL(i);

      //--- 6. CORE VPA CLASSIFICATIONS (Coulling Ch.4-6)

      // Effort vs Result (Wyckoff's 3rd Law)
      int effortResult = ClassifyEffortResult(isHighVol, isLowVol, isWideSpread, isNarrowSpread);
      gEffortResult[i] = effortResult;

      // Bull Valid
      bool bullValid = IsBullValid(isUpBar, isWideSpread, isHighVol, bodyRatio);
      gBullValid[i] = bullValid ? Low[i] - 20*_Point : EMPTY_VALUE;

      // Bear Valid
      bool bearValid = IsBearValid(isDownBar, isWideSpread, isHighVol, bodyRatio);
      gBearValid[i] = bearValid ? High[i] + 20*_Point : EMPTY_VALUE;

      // Squat Anomaly
      bool squat = IsSquatAnomaly(isHighVol, isNarrowSpread);
      gSquatAnomaly[i] = squat ? (Close[i] + Open[i]) / 2 : EMPTY_VALUE;

      // Stopping Volume
      bool deepLowerWick = IsDeepLowerWick(lowerWick, spread_);
      bool stoppingVol   = IsStoppingVolume(isDownBar, isHighVol, isUltraHigh,
                                             deepLowerWick, closeLoc, trendDir);
      gStoppingVol[i] = stoppingVol ? Low[i] - 40*_Point : EMPTY_VALUE;

      // Topping Out Volume
      bool deepUpperWick = IsDeepUpperWick(upperWick, spread_);
      bool toppingOut    = IsToppingOut(isUpBar, isHighVol, isUltraHigh,
                                        deepUpperWick, closeLoc, trendDir);
      gToppingOut[i] = toppingOut ? High[i] + 40*_Point : EMPTY_VALUE;

      // Absorption
      bool absorption = IsAbsorption(isHighVol, bodyRatio, closeLoc, isUpBar, isDownBar);
      gAbsorption[i] = absorption ? (High[i] + Low[i]) / 2 : EMPTY_VALUE;

      // Selling Climax
      bool sellingClimax = IsSellingClimax(i, isUltraHigh, trendDir);
      gSellingClimax[i] = sellingClimax ? High[i] + 60*_Point : EMPTY_VALUE;

      // Buying Climax
      bool buyingClimax = IsBuyingClimax(i, isUltraHigh, trendDir);
      gBuyingClimax[i] = buyingClimax ? Low[i] - 60*_Point : EMPTY_VALUE;

      // Low Volume Test
      bool lowVolTest = IsLowVolTest(isLowVol, bodyRatio, isUpBar, isDownBar);
      gLowVolTest[i] = lowVolTest ? (High[i] + Low[i]) / 2 : EMPTY_VALUE;

      // Confirmation vs Anomaly state
      if(effortResult == 2 || effortResult == 3) {
         gAnomaly[i]      = 1.0;
         gConfirmation[i] = 0.0;
      } else if(effortResult == 1) {
         gConfirmation[i] = isUpBar ? 1.0 : -1.0;
         gAnomaly[i]      = 0.0;
      } else {
         gAnomaly[i]      = 0.0;
         gConfirmation[i] = 0.0;
      }

      // Master Signal
      int signal = GetMasterSignal(bullValid, bearValid, squat,
                                   stoppingVol, toppingOut, absorption,
                                   sellingClimax, buyingClimax, lowVolTest,
                                   closeLoc, trendDir);
      gSignal[i] = signal;

      //--- 7. ANNOTATIONS (last bar only)
      if(i == rates_total - 1)
      {
         // RSI
         double rsiVal = iRSI(NULL, 0, 14, PRICE_CLOSE, 0);

         // Trend label
         string trendLabel;
         color  trendClr;
         if(trendDir > 0)      { trendLabel = "BULL TREND";   trendClr = InpBullColor; }
         else if(trendDir < 0) { trendLabel = "BEAR TREND";   trendClr = InpBearColor; }
         else                  { trendLabel = "NEUTRAL";       trendClr = InpNeutralColor; }

         string vpaStatus = GetVPAStatusLabel(bullValid, bearValid, squat,
                                               stoppingVol, toppingOut, absorption,
                                               sellingClimax, buyingClimax, lowVolTest);
         string effortLabel = GetEffortResultLabel(effortResult);
         string signalLabel = GetSignalLabel(signal);

         // Draw chart annotations
         if(bullValid)     DrawAnnotation(0, "BULL VALID", InpBullColor,    true);
         if(bearValid)     DrawAnnotation(0, "BEAR VALID", InpBearColor,    false);
         if(squat)         DrawAnnotation(0, "SQUAT!", InpAnomalyColor,    true);
         if(stoppingVol)   DrawAnnotation(0, "STOPPING VOL", clrDodgerBlue,  true);
         if(toppingOut)    DrawAnnotation(0, "TOPPING OUT", clrDeepSkyBlue,   false);
         if(sellingClimax) DrawAnnotation(0, "SELLING CLIMAX!", clrMagenta, false);
         if(buyingClimax)  DrawAnnotation(0, "BUYING CLIMAX!", clrMagenta,  true);
         if(lowVolTest)    DrawAnnotation(0, "LOW VOL TEST", clrYellow,    true);

         // Chart comment with VPA summary
         string comment = StringFormat(
            "VPA=%s | E/R=%s | Signal=%s | Trend=%s | RSI=%.1f | VolRatio=%.2fx | CloseLoc=%.0f%%",
            vpaStatus, effortLabel, signalLabel, trendLabel, rsiVal, volRatio, closeLoc * 100);
         Comment(comment);

         // Update dashboard
         string tf = Period() >= 60 ? IntegerToString(Period()/60) + "H" : IntegerToString(Period());
         UpdateDashboard(vpaStatus, effortLabel, signalLabel,
                        trendLabel, trendClr, rsiVal, closeLoc,
                        isHighVol, volTrend, volRatio, tf);
      }
   }

   return rates_total;
}
//+------------------------------------------------------------------+
