//+------------------------------------------------------------------+
//|                                   VWAP_XAUUSD_Phase1_Indicator.mq5 |
//|                                                        Trader Nakal |
//+------------------------------------------------------------------+
#property copyright "Trader Nakal"
#property link      ""
#property version   "1.0.0"
#property description "VWAP Indicator — Phase 1 Foundation"
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   6

#include <Arrays\ArrayObj.mqh>
#include <Math\Stat\Normal.mqh>

//--- Enumerations
enum ENUM_VWAP_VOLUME_MODE
{
   VWAP_VOLUME_AUTO   = 0,  // Use real volume if valid; otherwise tick volume
   VWAP_VOLUME_TICK   = 1,  // Always use tick_volume
   VWAP_VOLUME_REAL   = 2   // Always use volume (requires valid data feed)
};

enum ENUM_PRICE_BASIS
{
   PRICE_TYPICAL = 0, // Default: (High + Low + Close) / 3
};

//--- Inputs
ingroup "Core Configuration";
input ENUM_VWAP_VOLUME_MODE InpVolumeMode   = VWAP_VOLUME_AUTO;   // Volume Source Mode
input ENUM_PRICE_BASIS      InpPriceBasis   = PRICE_TYPICAL;      // Price Calculation Basis

ingroup "Daily Reset Settings";
input bool   InpDailyVWAPEnable = true;             // Enable Daily/Session Reset VWAP
input int    InpResetHour       = 0;                // Reset Hour (Broker Server Time)
input int    InpResetMinute     = 0;                // Reset Minute (Broker Server Time)

ingroup "Standard Deviation Bands";
input double InpBand1Mult       = 1.0;              // Band 1 Multiplier (> 0)
input double InpBand2Mult       = 2.0;              // Band 2 Multiplier (> Band 1)

ingroup "Anchored VWAP Settings";
input bool   InpAnchoredEnable  = false;            // Enable Anchored VWAP
input string InpAnchorTimeStr   = "09:30";          // Anchor Time (HH:mm)
input int    InpAnchorOffset    = 0;                // Anchor Offset Days (-/+ days from today)

//--- Indicator Buffers
double   BufferVWAPMain[];
double   BufferBand1Upper[];
double   BufferBand1Lower[];
double   BufferBand2Upper[];
double   BufferBand2Lower[];
double   BufferVWAPAnchored[];

//--- Internal Working Arrays
datetime TimeArr[];
double     OpenArr[], HighArr[], LowArr[], CloseArr[];
ulong      TickVolArr[], RealVolArr[];
double     CumPV[], CumV[], CumPV2[]; // Cumulative Prefix Sums

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Validate Inputs
   if(InpResetHour < 0 || InpResetHour > 23 || InpResetMinute < 0 || InpResetMinute > 59)
   {
      Print("INVALID INPUT: ResetHour must be [0, 23] and ResetMinute [0, 59].");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   if(InpBand1Mult <= 0.0 || InpBand2Mult <= 0.0)
   {
      Print("INVALID INPUT: Band Multipliers must be > 0.");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(InpBand2Mult <= InpBand1Mult)
   {
      Print("INVALID INPUT: Band2Multiplier must be strictly greater than Band1Multiplier.");
      return(INIT_PARAMETERS_INCORRECT);
   }

   //--- Strip separator from anchor time string
   StringReplace(InpAnchorTimeStr, ".", ":");
   int colonPos = StringFind(InpAnchorTimeStr, ":");
   if(colonPos <= 0 || colonPos >= StringLen(InpAnchorTimeStr) - 1)
   {
      Print("INVALID INPUT: AnchorTime format must be HH:mm");
      return(INIT_PARAMETERS_INCORRECT);
   }

   //--- Assign indicator buffers
   IndicatorSetString(INDICATOR_SHORTNAME, "VWAP-XAUUSD-P1");
   SetIndexBuffer(0, BufferVWAPMain, INDICATOR_CALCULATIONS);
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, clrDodgerBlue);
   PlotIndexSetInteger(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   SetIndexBuffer(1, BufferBand1Upper, INDICATOR_CALCULATIONS);
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, clrOrange);
   PlotIndexSetInteger(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   SetIndexBuffer(2, BufferBand1Lower, INDICATOR_CALCULATIONS);
   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, clrOrange);
   PlotIndexSetInteger(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   SetIndexBuffer(3, BufferBand2Upper, INDICATOR_CALCULATIONS);
   PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, clrGold);
   PlotIndexSetInteger(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   SetIndexBuffer(4, BufferBand2Lower, INDICATOR_CALCULATIONS);
   PlotIndexSetInteger(4, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, clrGold);
   PlotIndexSetInteger(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   SetIndexBuffer(5, BufferVWAPAnchored, INDICATOR_CALCULATIONS);
   PlotIndexSetInteger(5, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, clrLime);
   PlotIndexSetInteger(5, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ArrayFree(CumPV);
   ArrayFree(CumV);
   ArrayFree(CumPV2);
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
   // --- Enforce explicit chronological indexing convention ---
   // Index 0 = Oldest Bar, Index rates_total-1 = Newest Bar
   ArraySetAsSeries(TimeArr,        false);
   ArraySetAsSeries(HighArr,        false);
   ArraySetAsSeries(LowArr,         false);
   ArraySetAsSeries(CloseArr,       false);
   ArraySetAsSeries(TickVolArr,     false);
   ArraySetAsSeries(RealVolArr,     false);
   ArraySetAsSeries(CumPV,          false);
   ArraySetAsSeries(CumV,           false);
   ArraySetAsSeries(CumPV2,         false);
   
   // Copy inputs into local flat arrays for predictable memory access
   ArrayCopy(TimeArr, Time);
   ArrayCopy(HighArr, High);
   ArrayCopy(LowArr,  Low);
   ArrayCopy(CloseArr, Close);
   ArrayCopy(TickVolArr, TickVolume);
   ArrayCopy(RealVolArr, Volume);
   
   // Limit loop bounds for performance on each tick
   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;
   int limit = rates_total - start_index;

   // --- 1. Build Cumulative Prefix Sum Arrays ---
   // Rebuild prefix sums if initializing or if new history was added
   if(prev_calculated == 0 || rates_total > ArraySize(CumPV))
   {
      int size = MathMax(rates_total, ArraySize(CumPV));
      ArrayResize(CumPV, size);
      ArrayResize(CumV, size);
      ArrayResize(CumPV2, size);
      
      double cur_pv = 0.0;
      double cur_v  = 0.0;
      double cur_pv2 = 0.0;
      
      for(int i = 0; i < rates_total; i++)
      {
         double eff_vol = GetEffectiveVolume(i);
         double tp = GetTypicalPrice(i);
         
         // Zero-volume bars contribute nothing to the cumulative sums.
         cur_pv  += tp * eff_vol;
         cur_v   += eff_vol;
         cur_pv2 += tp * tp * eff_vol;
         
         CumPV[i]  = cur_pv;
         CumV[i]   = cur_v;
         CumPV2[i] = cur_pv2;
      }
   }

   // --- 2. Calculate Daily / Session Reset VWAP ---
   double sess_pv = 0.0;
   double sess_v  = 0.0;
   double sess_pv2 = 0.0;
   datetime next_reset_time = CalculateNextResetTime(TimeArr[0]);
   
   for(int i = start_index; i < rates_total; i++)
   {
      // Check for session boundary crossing
      if(TimeArr[i] >= next_reset_time && i > 0)
      {
         // Reset accumulators precisely at the bar crossing the timestamp
         sess_pv = 0.0;
         sess_v  = 0.0;
         sess_pv2 = 0.0;
         next_reset_time = GetSubsequentResetTime(next_reset_time);
      }
      
      double eff_vol = GetEffectiveVolume(i);
      double tp = GetTypicalPrice(i);
      
      sess_pv  += tp * eff_vol;
      sess_v   += eff_vol;
      sess_pv2 += tp * tp * eff_vol;
      
      double vwap_val, std_dev, b1_up, b1_dn, b2_up, b2_dn;
      FormVWAPMetrics(sess_pv, sess_v, sess_pv2, vwap_val, std_dev, b1_up, b1_dn, b2_up, b2_dn);
      
      BufferVWAPMain[i]      = vwap_val;
      BufferBand1Upper[i]    = b1_up;
      BufferBand1Lower[i]    = b1_dn;
      BufferBand2Upper[i]    = b2_up;
      BufferBand2Lower[i]    = b2_dn;
   }

   // --- 3. Calculate Anchored VWAP (if enabled) ---
   if(InpAnchoredEnable)
   {
      // Resolve anchor target datetime
      datetime anchor_target = ParseAnchorTime() + (long)InpAnchorOffset * 86400;
      int anchor_idx = FindContainingBarIndex(anchor_target);
      
      // Anchor cannot be beyond current chart bounds
      if(anchor_idx >= 0 && anchor_idx < rates_total)
      {
         double base_pv = (anchor_idx > 0) ? CumPV[anchor_idx - 1] : 0.0;
         double base_v  = (anchor_idx > 0) ? CumV[anchor_idx - 1]  : 0.0;
         double base_pv2 = (anchor_idx > 0) ? CumPV2[anchor_idx - 1] : 0.0;
         
         // Only update anchored buffer going forward from anchor point
         int anchor_loop_start = MathMax(start_index, anchor_idx);
         for(int i = anchor_loop_start; i < rates_total; i++)
         {
            double w_pv  = CumPV[i] - base_pv;
            double w_v   = CumV[i]  - base_v;
            double w_pv2 = CumPV2[i] - base_pv2;
            
            double vwap_val, std_dev, b1_up, b1_dn, b2_up, b2_dn;
            FormVWAPMetrics(w_pv, w_v, w_pv2, vwap_val, std_dev, b1_up, b1_dn, b2_up, b2_dn);
            
            BufferVWAPAnchored[i] = vwap_val;
         }
      }
   }
   else
   {
      // Clear anchored buffer if disabled
      for(int i = start_index; i < rates_total; i++)
         BufferVWAPAnchored[i] = EMPTY_VALUE;
   }

   // Return rates_total to indicate full processing
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Helper: Determines effective volume based on mode configuration  |
//+------------------------------------------------------------------+
double GetEffectiveVolume(int i)
{
   double eff_vol = 0.0;
   switch(InpVolumeMode)
   {
      case VWAP_VOLUME_TICK:
         eff_vol = (double)TickVolArr[i];
         break;
      case VWAP_VOLUME_REAL:
         eff_vol = (double)RealVolArr[i];
         break;
      case VWAP_VOLUME_AUTO:
         eff_vol = (RealVolArr[i] > 0) ? (double)RealVolArr[i] : (double)TickVolArr[i];
         break;
   }
   return eff_vol;
}

//+------------------------------------------------------------------+
//| Helper: Computes Typical Price ((H+L+C)/3)                       |
//+------------------------------------------------------------------+
double GetTypicalPrice(int i)
{
   return (HighArr[i] + LowArr[i] + CloseArr[i]) / 3.0;
}

//+------------------------------------------------------------------+
//| Helper: Solves VWAP math safely                                  |
//+------------------------------------------------------------------+
void FormVWAPMetrics(double pv, double v, double pv2, 
                     double &vwap, double &stddev, 
                     double &b1u, double &b1l, double &b2u, double &b2l)
{
   vwap = EMPTY_VALUE;
   stddev = 0.0;
   b1u = b1l = b2u = b2l = EMPTY_VALUE;

   if(v <= 0.0)
   {
      // Zero valid volume: Cannot compute statistical mean. 
      // Carry forward previous valid values implicitly by leaving EMPTY_VALUE
      return; 
   }

   double mean_px = pv / v;
   double mean_px2 = pv2 / v;
   double variance = mean_px2 - (mean_px * mean_px);
   
   // Numerical protection against floating point drift yielding negative variance
   stddev = MathSqrt(MathMax(variance, 0.0));
   
   vwap = mean_px;
   b1u  = mean_px + (stddev * InpBand1Mult);
   b1l  = mean_px - (stddev * InpBand1Mult);
   b2u  = mean_px + (stddev * InpBand2Mult);
   b2l  = mean_px - (stddev * InpBand2Mult);
}

//+------------------------------------------------------------------+
//| Helper: Resolves requested anchor datetime to nearest bar index  |
//+------------------------------------------------------------------+
int FindContainingBarIndex(datetime target_time)
{
   // Search backwards from the present for the bar containing the target time
   for(int i = ArraySize(TimeArr) - 1; i >= 0; i--)
   {
      datetime next_bar = (i + 1 < ArraySize(TimeArr)) ? TimeArr[i+1] : INT_MAX;
      if(TimeArr[i] <= target_time && target_time < next_bar)
      {
         return i; // Found the containing candle
      }
   }
   return -1; // Outside chart bounds
}

//+------------------------------------------------------------------+
//| Helper: Parses HH:mm string into UNIX timestamp (relative to Today)|
//+------------------------------------------------------------------+
datetime ParseAnchorTime()
{
   int h = StringToInteger(StringSubstr(InpAnchorTimeStr, 0, 2));
   int m = StringToInteger(StringSubstr(InpAnchorTimeStr, 3, 2));
   datetime t_today = TimeCurrent();
   t_today -= (t_today % 86400); // Strip to midnight today
   return t_today + (h * 3600) + (m * 60);
}

//+------------------------------------------------------------------+
//| Helper: Determines next scheduled daily reset timestamp          |
//+------------------------------------------------------------------+
datetime CalculateNextResetTime(datetime first_bar_time)
{
   datetime today = first_bar_time - (first_bar_time % 86400);
   datetime reset_attempt = today + (InpResetHour * 3600) + (InpResetMinute * 60);
   // If the reset time has already passed today relative to the first bar, schedule for tomorrow
   if(reset_attempt < first_bar_time)
      reset_attempt += 86400;
   return reset_attempt;
}

datetime GetSubsequentResetTime(datetime last_reset)
{
   return last_reset + 86400;
}
//+------------------------------------------------------------------+
