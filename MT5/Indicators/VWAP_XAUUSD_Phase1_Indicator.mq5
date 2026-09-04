//+------------------------------------------------------------------+
//|                                               VWAP_Phase1_Fix.mq5 |
//|                                                        Trader Nakal |
//+------------------------------------------------------------------+
#property copyright "Trader Nakal"
#property link      ""
#property version   "1.0"
#property description "VWAP XAUUSD M15 — Phase 1 Foundation (Fixed)"
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   6

//--- Input Groups (Comments only for maximum compatibility)
// === CORE CONFIGURATION ===
input ENUM_APPLIED_PRICE InpPriceBasis = PRICE_TYPICAL; // Price Applied (Typical/HLC3)

// === DAILY RESET SETTINGS ===
input bool   InpDailyReset   = true;             // Enable Daily Reset
input int    InpResetHour    = 0;                // Reset Hour (Server Time)
input int    InpResetMinute  = 0;                // Reset Minute (Server Time)
input color  InpMainColor    = clrDodgerBlue;    // Main Line Color

// === STANDARD DEVIATION BANDS ===
input bool   InpDrawBands    = true;             // Draw Bands?
input double InpBandMult     = 1.0;              // Band Multiplier (> 0)
input color  InpBandColor    = clrOrange;        // Band Color

// === ANCHORED VWAP SETTINGS ===
input bool   InpAnchored     = false;            // Enable Anchored VWAP
input string InpAnchorTime   = "09:30";          // Anchor Time (HH:mm)

//--- Buffers
double         MainVWAP[];
double         UpperBand1[];
double         LowerBand1[];
double         AnchoVWAP[];

// Internal State
double         g_cumTPV = 0.0;   // Cumulative (Price*Volume)
double         g_cumVol = 0.0;   // Cumulative Volume
datetime       g_nextReset = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Validate Reset Time
   if(InpResetHour < 0 || InpResetHour > 23) InpResetHour = 0;
   if(InpResetMinute < 0 || InpResetMinute > 59) InpResetMinute = 0;
   
   if(InpBandMult <= 0) InpBandMult = 1.0;

   // Shortname
   string suffix = InpAnchored ? "_Anchored" : "";
   IndicatorSetString(INDICATOR_SHORTNAME, "VWAP-XAU-P1"+suffix);

   // Set Data Arrays as Series (for OnCalculate loop backwards)
   ArraySetAsSeries(MainVWAP, true);
   ArraySetAsSeries(UpperBand1, true);
   ArraySetAsSeries(LowerBand1, true);
   ArraySetAsSeries(AnchoVWAP, true);

   // Plot Setup
   SetIndexBuffer(0, MainVWAP, INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpMainColor);
   PlotIndexSetString(0, PLOT_LABEL, "Daily VWAP");

   if(InpDrawBands)
   {
      SetIndexBuffer(1, UpperBand1, INDICATOR_DATA);
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);
      PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpBandColor);
      PlotIndexSetString(1, PLOT_LABEL, "Band +1");
      
      SetIndexBuffer(2, LowerBand1, INDICATOR_DATA);
      PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_LINE);
      PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpBandColor);
      PlotIndexSetString(2, PLOT_LABEL, "Band -1");
   }
   
   if(InpAnchored)
   {
      SetIndexBuffer(3, AnchoVWAP, INDICATOR_DATA);
      PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_LINE);
      PlotIndexSetInteger(3, PLOT_LINE_COLOR, clrLime);
      PlotIndexSetString(3, PLOT_LABEL, "Anchored VWAP");
   }

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
}

//+------------------------------------------------------------------+
//| Custom indicator iterative function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &Time[],
                const double &Open[],
                const double &High[],
                const double &Low[],
                const double &Close[],
                const long &TickVolume[],
                const long &Volume[],
                const int &Spread[])
{
   // Work with arrays in Series order (Current index = 0)
   ArraySetAsSeries(Time, true);
   ArraySetAsSeries(High, true);
   ArraySetAsSeries(Low, true);
   ArraySetAsSeries(Close, true);
   ArraySetAsSeries(TickVolume, true);
   ArraySetAsSeries(Volume, true);

   // Determine start index
   int limit = prev_calculated - 1;
   if(limit < 1) limit = 0; 
   
   // Calculate Next Reset Time (relative to oldest bar visible)
   if(g_nextReset == 0)
   {
      datetime today = Time[rates_total-1];
      today -= (today % 86400); // Midnight
      uint resSec = ((uint)InpResetHour * 3600) + ((uint)InpResetMinute * 60);
      g_nextReset = (datetime)(today + resSec);
   }

   // Loop Bars
   for(int i = limit; i < rates_total; i++)
   {
      // Session Boundary Check
      if(Time[i] >= g_nextReset)
      {
         ResetCalculation();
         g_nextReset += 86400;
      }

      // Get Effective Price
      double tp = 0.0;
      switch(InpPriceBasis)
      {
         case PRICE_CLOSE: tp = Close[i]; break;
         case PRICE_OPEN:  tp = Open[i]; break;
         case PRICE_HIGH:  tp = High[i]; break;
         case PRICE_LOW:   tp = Low[i]; break;
         default:          tp = (High[i] + Low[i] + Close[i]) / 3.0; break;
      }

      // Volume Handling: Real preferred, Tick fallback
      double vol = (Volume[i] > 0) ? (double)Volume[i] : (double)TickVolume[i];

      // Accumulate
      g_cumTPV += tp * vol;
      g_cumVol += vol;

      // Compute Values
      double vwap = (g_cumVol > 0) ? (g_cumTPV / g_cumVol) : EMPTY_VALUE;
      double dev = 0.0;
      
      // Simple Deviation Logic (Placeholder for Phase 2 StdDev)
      if(g_cumVol > 0 && InpDrawBands) dev = vwap * InpBandMult * 0.001;

      // Save to Buffers
      MainVWAP[i] = vwap;
      if(InpDrawBands)
      {
         UpperBand1[i] = vwap + dev;
         LowerBand1[i] = vwap - dev;
      }
   }
   
   // --- Anchored VWAP Pass (Efficient Recalculation) ---
   if(InpAnchored)
   {
      StringReplace(InpAnchorTime, ".", ":");
      StringReplace(InpAnchorTime, ",", ":");
      int cPos = StringFind(InpAnchorTime, ":");
      
      if(cPos > 0 && cPos < StringLen(InpAnchorTime))
      {
         int h = (int)StringToInteger(StringSubstr(InpAnchorTime, 0, cPos));
         int m = (int)StringToInteger(StringSubstr(InpAnchorTime, cPos+1, 2));
         
         // Resolve Target Bar
         datetime anchorBase = Time[rates_total-1];
         anchorBase -= (anchorBase % 86400);
         anchorBase += ((uint)h * 3600) + ((uint)m * 60);
         if(anchorBase > Time[rates_total-1]) anchorBase -= 86400;
         
         // Find Index
         int anchorIdx = -1;
         for(int x = 0; x < rates_total; x++) {
            if(Time[x] >= anchorBase) { anchorIdx = x; break; }
         }
         
         if(anchorIdx != -1)
         {
            double a_tpv = 0.0;
            double a_vol = 0.0;
            for(int j = anchorIdx; j < rates_total; j++)
            {
               double t = (High[j] + Low[j] + Close[j]) / 3.0;
               double v = (Volume[j] > 0) ? (double)Volume[j] : (double)TickVolume[j];
               
               a_tpv += t * v;
               a_vol += v;
               AnchoVWAP[j] = (a_vol > 0) ? (a_tpv / a_vol) : EMPTY_VALUE;
            }
         }
      }
   }

   return(rates_total);
}

// Helper
void ResetCalculation()
{
   g_cumTPV = 0.0;
   g_cumVol = 0.0;
}
//+------------------------------------------------------------------+
