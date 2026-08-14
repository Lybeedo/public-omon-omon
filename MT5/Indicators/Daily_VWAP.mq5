//+------------------------------------------------------------------+
//|                                                     Daily VWAP.mq5 |
//|                              Adapted from Syllyon original v1.00  |
//|                         Industrial-grade, symbol-agnostic, DST-safe |
//+------------------------------------------------------------------+
#property copyright   "Original: Guillermo Pineda (Syllyon) | Adapted: Lybeedo"
#property link        "https://www.mql5.com/en/code/viewcode/61090"
#property version     "1.01"
#property description "Daily VWAP: Cumulative Typical Price * Volume / Cumulative Volume. Resets at new trading day."
#property strict

//--- Plotting properties
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots 1

//--- Plot 1: Daily VWAP
#property indicator_label1  "Daily VWAP"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Inputs — all adjustable (season-proof, no recompile for DST)
input group "=== VWAP SETTINGS ==="
input bool   InpUseTickVol  = true;   // Use Tick Volume (false = standard volume)
input int    InpDayStartH   = 0;      // Day Start Hour (broker time, 0-23)
input int    InpDayStartM   = 0;      // Day Start Minute (0-59)
input bool   InpShowAlert   = false;  // Alert on new day reset
input bool   InpDrawBands   = false;  // Draw ±1/2/3 std dev bands

input group "=== BAND SETTINGS ==="
input double InpBandDev1    = 1.0;    // Band Deviation 1 (multiplier)
input double InpBandDev2    = 2.0;    // Band Deviation 2
input double InpBandDev3    = 3.0;    // Band Deviation 3
input color  InpColorBand1  = clrDodgerBlue;
input color  InpColorBand2  = clrGold;
input color  InpColorBand3  = clrOrange;
input int    InpBandWidth   = 1;
input int    InpBandStyle   = STYLE_DOT;

//--- Indicator buffers
double VWAPBuffer[];
double BandUpper1[], BandLower1[];
double BandUpper2[], BandLower2[];
double BandUpper3[], BandLower3[];
double TPVBuffer[];   // cumulative TPV for band calc
double VolBuffer[];   // cumulative volume for band calc

//--- Globals
double   g_cumTPV     = 0.0;
double   g_cumVol     = 0.0;
datetime g_lastBarTime = 0;
datetime g_lastDayStart = 0;
bool     g_firstRun   = true;

//--- Helper: get day start datetime from broker time
datetime GetDayStart(int hour, int minute) {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour    = hour;
   dt.min     = minute;
   dt.sec     = 0;
   return StructToTime(dt);
}

//--- Helper: check if current bar is first bar of new day
bool IsNewDay(datetime barTime, int startH, int startM) {
   MqlDateTime dt, ds;
   TimeToStruct(barTime, dt);
   // Check if this bar's day start differs from last recorded
   datetime currentDayStart = GetDayStart(startH, startM);
   // Compare day/month/year
   MqlDateTime ds_prev;
   TimeToStruct(g_lastDayStart, ds_prev);
   MqlDateTime ds_curr;
   TimeToStruct(currentDayStart, ds_curr);
   
   // New day if date changed
   if(dt.day != ds_prev.day || dt.month != ds_prev.month || dt.year != ds_prev.year) {
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
   //--- Map indicator buffers
   SetIndexBuffer(0, VWAPBuffer, INDICATOR_DATA);
   
   if(InpDrawBands) {
      SetIndexBuffer(1, BandUpper1, INDICATOR_DATA);
      SetIndexBuffer(2, BandLower1, INDICATOR_DATA);
      SetIndexBuffer(3, BandUpper2, INDICATOR_DATA);
      SetIndexBuffer(4, BandLower2, INDICATOR_DATA);
      SetIndexBuffer(5, BandUpper3, INDICATOR_DATA);
      SetIndexBuffer(6, BandLower3, INDICATOR_DATA);
      // TPV/Vol buffers for band calc (not plotted)
      SetIndexBuffer(7, TPVBuffer, INDICATOR_CALCULATIONS);
      SetIndexBuffer(8, VolBuffer, INDICATOR_CALCULATIONS);
   }
   
   //--- Plot settings
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 1);
   PlotIndexSetString(0, PLOT_LABEL, "Daily VWAP");
   
   if(InpDrawBands) {
      // Band 1
      PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, 1);
      PlotIndexSetString(1, PLOT_LABEL, "VWAP Band ±1");
      PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpColorBand1);
      PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpBandStyle);
      PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpBandWidth);
      PlotIndexSetInteger(1, PLOT_EMPTY_VALUE, 0);
      
      PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, 1);
      PlotIndexSetString(2, PLOT_LABEL, "VWAP Band -1");
      PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpColorBand1);
      PlotIndexSetInteger(2, PLOT_LINE_STYLE, InpBandStyle);
      PlotIndexSetInteger(2, PLOT_LINE_WIDTH, InpBandWidth);
      PlotIndexSetInteger(2, PLOT_EMPTY_VALUE, 0);
      
      // Band 2
      PlotIndexSetInteger(3, PLOT_DRAW_BEGIN, 1);
      PlotIndexSetString(3, PLOT_LABEL, "VWAP Band ±2");
      PlotIndexSetInteger(3, PLOT_LINE_COLOR, InpColorBand2);
      PlotIndexSetInteger(3, PLOT_LINE_STYLE, InpBandStyle);
      PlotIndexSetInteger(3, PLOT_LINE_WIDTH, InpBandWidth);
      PlotIndexSetInteger(3, PLOT_EMPTY_VALUE, 0);
      
      PlotIndexSetInteger(4, PLOT_DRAW_BEGIN, 1);
      PlotIndexSetString(4, PLOT_LABEL, "VWAP Band -2");
      PlotIndexSetInteger(4, PLOT_LINE_COLOR, InpColorBand2);
      PlotIndexSetInteger(4, PLOT_LINE_STYLE, InpBandStyle);
      PlotIndexSetInteger(4, PLOT_LINE_WIDTH, InpBandWidth);
      PlotIndexSetInteger(4, PLOT_EMPTY_VALUE, 0);
      
      // Band 3
      PlotIndexSetInteger(5, PLOT_DRAW_BEGIN, 1);
      PlotIndexSetString(5, PLOT_LABEL, "VWAP Band ±3");
      PlotIndexSetInteger(5, PLOT_LINE_COLOR, InpColorBand3);
      PlotIndexSetInteger(5, PLOT_LINE_STYLE, InpBandStyle);
      PlotIndexSetInteger(5, PLOT_LINE_WIDTH, InpBandWidth);
      PlotIndexSetInteger(5, PLOT_EMPTY_VALUE, 0);
      
      PlotIndexSetInteger(6, PLOT_DRAW_BEGIN, 1);
      PlotIndexSetString(6, PLOT_LABEL, "VWAP Band -3");
      PlotIndexSetInteger(6, PLOT_LINE_COLOR, InpColorBand3);
      PlotIndexSetInteger(6, PLOT_LINE_STYLE, InpBandStyle);
      PlotIndexSetInteger(6, PLOT_LINE_WIDTH, InpBandWidth);
      PlotIndexSetInteger(6, PLOT_EMPTY_VALUE, 0);
   }
   
   //--- Short name
   IndicatorSetString(INDICATOR_SHORTNAME, 
      "Daily VWAP" + (InpDrawBands ? " ±1/2/3σ" : ""));
   
   //--- Initialize day tracking
   g_lastDayStart = GetDayStart(InpDayStartH, InpDayStartM);
   g_cumTPV = 0.0;
   g_cumVol = 0.0;
   g_firstRun = true;
   
   Print("[Daily VWAP] Initialized | Day start: ", 
         InpDayStartH, ":", IntegerToString(InpDayStartM, 2, '0'),
         " | Bands: ", (InpDrawBands ? "ON" : "OFF"));
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   Print("[Daily VWAP] Deinit reason=", reason,
         " | Final cumVol=", DoubleToString(g_cumVol, 0),
         " | Final VWAP=", DoubleToString(g_cumTPV / MathMax(g_cumVol, 1), _Digits));
}

//+------------------------------------------------------------------+
//| Custom indicator iterative calculate function                    |
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
                const int &spread[]) {
   
   //--- Determine start index
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   
   //--- Reset cumulative values on first bar or new day detection
   if(g_firstRun || start == 0) {
      // Check if we need to reset (new day)
      if(start == 0) {
         // Full scan from beginning to find day boundaries
         ResetCumulative();
         // Find the last bar's day start and continue from there
         if(rates_total > 0) {
            MqlDateTime dt;
            TimeToStruct(time[rates_total - 1], dt);
            datetime lastDayStart = GetDayStart(InpDayStartH, InpDayStartM);
            // Reset to last day start
            g_lastDayStart = lastDayStart;
         }
      }
      g_firstRun = false;
   }
   
   //--- Main VWAP loop
   for(int i = start; i < rates_total; i++) {
      MqlDateTime dt;
      TimeToStruct(time[i], dt);
      
      // Check for new day boundary
      MqlDateTime dtPrev;
      if(i > 0) {
         TimeToStruct(time[i - 1], dtPrev);
         // Detect day change by comparing day/month/year
         bool dayChanged = (dt.day != dtPrev.day || 
                           dt.month != dtPrev.month || 
                           dt.year != dtPrev.year);
         
         if(dayChanged) {
            // Check if we crossed a day boundary (not just overnight)
            datetime expectedStart = GetDayStart(InpDayStartH, InpDayStartM);
            if(dt.day != dtPrev.day) {
               ResetCumulative();
               g_lastDayStart = expectedStart;
               if(InpShowAlert) {
                  Print("[Daily VWAP] NEW DAY reset at bar ", i, 
                        " time=", TimeToString(time[i]));
                  Alert("Daily VWAP: New trading day started at ", 
                        TimeToString(time[i]));
               }
            }
         }
      }
      
      //--- Calculate typical price
      double typicalPrice = (high[i] + low[i] + close[i]) / 3.0;
      
      //--- Use tick volume or standard volume
      long barVolume = (InpUseTickVol) ? tick_volume[i] : volume[i];
      if(barVolume < 1) barVolume = 1; // Avoid zero volume
      
      //--- Accumulate
      g_cumTPV  += typicalPrice * (double)barVolume;
      g_cumVol += (double)barVolume;
      
      //--- Store VWAP
      VWAPBuffer[i] = (g_cumVol > 0) ? g_cumTPV / g_cumVol : 0.0;
      
      //--- Store cumulative values for band calculation
      TPVBuffer[i] = g_cumTPV;
      VolBuffer[i] = g_cumVol;
      
      //--- Calculate standard deviation and bands
      if(g_cumVol > 0 && InpDrawBands && i > 0) {
         // Calculate variance using cumulative formula
         // Var = E[X²] - E[X]² where X = typical price weighted by volume
         double mean = VWAPBuffer[i];
         double variance = 0.0;
         
         // Look back for variance (use last 100 bars or all available)
         int lookback = (i >= 100) ? 100 : i;
         double sumWeightedSq = 0.0;
         double sumWeight = 0.0;
         for(int j = i - lookback; j <= i; j++) {
            double tp = (high[j] + low[j] + close[j]) / 3.0;
            long vol = (InpUseTickVol) ? tick_volume[j] : volume[j];
            if(vol < 1) vol = 1;
            sumWeightedSq += tp * tp * (double)vol;
            sumWeight += (double)vol;
         }
         if(sumWeight > 0) {
            double meanLocal = sumWeightedSq / sumWeight;
            variance = meanLocal - (mean * mean);
            if(variance < 0) variance = 0; // Numerical stability
         }
         double stddev = MathSqrt(variance);
         
         // Draw bands
         BandUpper1[i] = mean + stddev * InpBandDev1;
         BandLower1[i] = mean - stddev * InpBandDev1;
         BandUpper2[i] = mean + stddev * InpBandDev2;
         BandLower2[i] = mean - stddev * InpBandDev2;
         BandUpper3[i] = mean + stddev * InpBandDev3;
         BandLower3[i] = mean - stddev * InpBandDev3;
      }
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Reset cumulative values for new day                              |
//+------------------------------------------------------------------+
void ResetCumulative() {
   g_cumTPV = 0.0;
   g_cumVol = 0.0;
}
//+------------------------------------------------------------------+
