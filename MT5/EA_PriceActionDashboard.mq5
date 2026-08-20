//+------------------------------------------------------------------+
//|                                           PriceActionDashboard.mq5 |
//|                              Dashboard FVG, CHoCH, BOS, S&D, AOI |
//|                                    Breakout Probability Indicator |
//+------------------------------------------------------------------+
#property copyright "Trader Nakal"
#property version   "1.00"
#property description "Price Action Dashboard: FVG, CHoCH, BOS, Supply/Demand, AOI/POI, Breakout Prob"
#property indicator_chart_window

#include <Trade\Trade.mqh>

//--- Input Parameters
input group "=== Dashboard Settings ==="
input bool   ShowFVG        = true;    // Show Fair Value Gaps
input bool   ShowCHoCH      = true;    // Show CHoCH Signals
input bool   ShowBOS        = true;    // Show Break of Structure
input bool   ShowSupplyDemand = true;  // Show Supply & Demand Zones
input bool   ShowAOI        = true;    // Show Area of Interest
input bool   ShowPOI        = true;    // Show Point of Interest
input bool   ShowBreakoutProb = true;  // Show Breakout Probability
input bool   ShowTPSL       = true;    // Show TP/SL Levels

input group "=== Detection Settings ==="
input int    SwingLookback  = 20;      // Swing detection lookback bars
input int    FVGMinBars     = 3;      // Minimum bars for FVG
input int    BOSMinPct      = 0.1;    // Minimum break % for BOS
input double ATRPeriod      = 14;     // ATR period for SL/TP
input double ATRMultiplier  = 2.0;    // ATR multiplier for SL
input double TPMultiplier   = 3.0;    // ATR multiplier for TP
input int    ZoneMaxBars    = 50;     // Max bars for S&D zones
input double ZoneMinSize    = 0.5;    // Min zone size %

input group "=== Breakout Probability ==="
input int    ProbLookback   = 100;    // Bars for probability calculation
input double VolWeight      = 0.3;    // Volume weight in probability
input double RangeWeight    = 0.4;    // Range weight
input double TrendWeight    = 0.3;    // Trend weight

//--- Global Variables
CTrade g_trade;
double g_atr[];
double g_vol[];
int    g_atr_handle;

//--- Object prefix for cleanup
#define OBJ_PREFIX "PAD_"

//+------------------------------------------------------------------+
//| Custom indicator initialization function                          |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize ATR indicator
   g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, (int)ATRPeriod);
   if(g_atr_handle == INVALID_HANDLE)
   {
      Print("Failed to create ATR indicator");
      return(INIT_FAILED);
   }
   
   ArraySetAsSeries(g_atr, true);
   ArraySetAsSeries(g_vol, true);
   
   // Set indicator buffers
   SetIndexBuffer(0, g_atr, INDICATOR_DATA);
   
   Print("Price Action Dashboard initialized");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_atr_handle != INVALID_HANDLE)
      IndicatorRelease(g_atr_handle);
   
   // Clean up all objects
   ObjectsDeleteAll(0, OBJ_PREFIX);
   
   Comment("");
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                               |
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
                const double &spread[])
{
   // Copy ATR data
   if(CopyBuffer(g_atr_handle, 0, 0, rates_total, g_atr) <= 0)
      return(0);
   
   // Copy volume data
   ArrayCopy(g_vol, tick_volume);
   
   // Clean up old objects
   ObjectsDeleteAll(0, OBJ_PREFIX);
   
   // Get current price data
   double current_price = close[0];
   double atr_value = g_atr[0];
   
   // Detect and draw all patterns
   if(ShowFVG) DetectFVG(high, low, close, time);
   if(ShowCHoCH) DetectCHoCH(high, low, close, time);
   if(ShowBOS) DetectBOS(high, low, close, time);
   if(ShowSupplyDemand) DetectSupplyDemand(high, low, close, time);
   if(ShowAOI) DetectAOI(high, low, close, time);
   if(ShowPOI) DetectPOI(high, low, close, time);
   
   // Calculate and display breakout probability
   double breakout_prob = 0;
   if(ShowBreakoutProb)
      breakout_prob = CalculateBreakoutProbability(high, low, close, tick_volume, rates_total);
   
   // Calculate and display TP/SL
   if(ShowTPSL)
      DrawTPSL(current_price, atr_value);
   
   // Draw dashboard panel
   DrawDashboard(current_price, atr_value, breakout_prob, time);
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Detect Fair Value Gaps (FVG)                                      |
//+------------------------------------------------------------------+
void DetectFVG(const double &high[], const double &low[], const double &close[], const datetime &time[])
{
   int drawn = 0;
   for(int i = 2; i < MathMin(SwingLookback * 2, ArraySize(high) - 1); i++)
   {
      // Bullish FVG: gap between candle i-2 high and candle i low
      if(low[i] > high[i-2] && close[i-1] < close[i])
      {
         double fvg_top = high[i-2];
         double fvg_bottom = low[i];
         double fvg_mid = (fvg_top + fvg_bottom) / 2;
         
         // Draw FVG zone
         string name = OBJ_PREFIX + "FVG_B_" + IntegerToString(i);
         if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, time[i-2], fvg_bottom, time[i], fvg_top))
         {
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrLime);
            ObjectSetInteger(0, ObjectFind(0, name), OBJPROP_FILL, true);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
            ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         }
         
         // Draw label
         string label = OBJ_PREFIX + "FVG_B_L" + IntegerToString(i);
         if(ObjectCreate(0, label, OBJ_LABEL, 0, time[i-1], fvg_mid))
         {
            ObjectSetString(0, label, OBJPROP_TEXT, "FVG↑");
            ObjectSetInteger(0, label, OBJPROP_COLOR, clrLime);
            ObjectSetInteger(0, label, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, label, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, label, OBJPROP_ANCHOR, ANCHOR_CENTER);
         }
         drawn++;
      }
      
      // Bearish FVG: gap between candle i-2 low and candle i high
      if(high[i] < low[i-2] && close[i-1] > close[i])
      {
         double fvg_top = high[i];
         double fvg_bottom = low[i-2];
         double fvg_mid = (fvg_top + fvg_bottom) / 2;
         
         string name = OBJ_PREFIX + "FVG_S_" + IntegerToString(i);
         if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, time[i-2], fvg_bottom, time[i], fvg_top))
         {
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, name, OBJPROP_FILL, true);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
            ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         }
         
         string label = OBJ_PREFIX + "FVG_S_L" + IntegerToString(i);
         if(ObjectCreate(0, label, OBJ_LABEL, 0, time[i-1], fvg_mid))
         {
            ObjectSetString(0, label, OBJPROP_TEXT, "FVG↓");
            ObjectSetInteger(0, label, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, label, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, label, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, label, OBJPROP_ANCHOR, ANCHOR_CENTER);
         }
         drawn++;
      }
      
      if(drawn >= 10) break; // Limit drawn zones
   }
}

//+------------------------------------------------------------------+
//| Detect Change of Character (CHoCH)                                |
//+------------------------------------------------------------------+
void DetectCHoCH(const double &high[], const double &low[], const double &close[], const datetime &time[])
{
   if(ArraySize(high) < SwingLookback + 5) return;
   
   int direction = 0; // 1 = bullish, -1 = bearish
   
   // Find recent swing high and low
   double swing_high = high[SwingLookback];
   int swing_high_idx = SwingLookback;
   double swing_low = low[SwingLookback];
   int swing_low_idx = SwingLookback;
   
   for(int i = SwingLookback; i < 2 * SwingLookback && i < ArraySize(high); i++)
   {
      if(high[i] > swing_high) { swing_high = high[i]; swing_high_idx = i; }
      if(low[i] < swing_low) { swing_low = low[i]; swing_low_idx = i; }
   }
   
   // Detect CHoCH - break of swing structure
   for(int i = swing_high_idx + 2; i < ArraySize(high) - 1; i++)
   {
      // Bullish CHoCH: price breaks above swing high
      if(close[i] > swing_high && direction == -1)
      {
         string name = OBJ_PREFIX + "CHoCH_B" + IntegerToString(i);
         if(ObjectCreate(0, name, OBJ_ARROW, 0, time[i], low[i]))
         {
            ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 233); // Up arrow
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrLime);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);
         }
         
         string label = OBJ_PREFIX + "CHoCH_BL" + IntegerToString(i);
         if(ObjectCreate(0, label, OBJ_LABEL, 0, time[i], low[i] - 50 * _Point))
         {
            ObjectSetString(0, label, OBJPROP_TEXT, "CHoCH↑");
            ObjectSetInteger(0, label, OBJPROP_COLOR, clrLime);
            ObjectSetInteger(0, label, OBJPROP_FONTSIZE, 9);
            ObjectSetInteger(0, label, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         }
         direction = 1;
         break;
      }
      
      // Bearish CHoCH: price breaks below swing low
      if(close[i] < swing_low && direction == 1)
      {
         string name = OBJ_PREFIX + "CHoCH_S" + IntegerToString(i);
         if(ObjectCreate(0, name, OBJ_ARROW, 0, time[i], high[i]))
         {
            ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 234); // Down arrow
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);
         }
         
         string label = OBJ_PREFIX + "CHoCH_SL" + IntegerToString(i);
         if(ObjectCreate(0, label, OBJ_LABEL, 0, time[i], high[i] + 50 * _Point))
         {
            ObjectSetString(0, label, OBJPROP_TEXT, "CHoCH↓");
            ObjectSetInteger(0, label, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, label, OBJPROP_FONTSIZE, 9);
            ObjectSetInteger(0, label, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         }
         direction = -1;
         break;
      }
   }
}

//+------------------------------------------------------------------+
//| Detect Break of Structure (BOS)                                   |
//+------------------------------------------------------------------+
void DetectBOS(const double &high[], const double &low[], const double &close[], const datetime &time[])
{
   if(ArraySize(high) < 10) return;
   
   // Find recent structure points
   int structure_idx = 5;
   double structure_price = close[structure_idx];
   
   // Look for structure breaks
   for(int i = 0; i < 10 && i < ArraySize(close) - 2; i++)
   {
      double check_price = close[i];
      
      // Bullish BOS: breaking above recent high
      if(check_price > structure_price * (1 + BOSMinPct/100))
      {
         string name = OBJ_PREFIX + "BOS_B" + IntegerToString(i);
         if(ObjectCreate(0, name, OBJ_ARROW, 0, time[i], low[i]))
         {
            ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 241); // Right arrow
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrLime);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
         }
         
         string label = OBJ_PREFIX + "BOS_BL" + IntegerToString(i);
         if(ObjectCreate(0, label, OBJ_LABEL, 0, time[i], low[i] - 40 * _Point))
         {
            ObjectSetString(0, label, OBJPROP_TEXT, "BOS↑");
            ObjectSetInteger(0, label, OBJPROP_COLOR, clrLime);
            ObjectSetInteger(0, label, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, label, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         }
         break;
      }
      
      // Bearish BOS: breaking below recent low
      if(check_price < structure_price * (1 - BOSMinPct/100))
      {
         string name = OBJ_PREFIX + "BOS_S" + IntegerToString(i);
         if(ObjectCreate(0, name, OBJ_ARROW, 0, time[i], high[i]))
         {
            ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 242); // Left arrow
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
         }
         
         string label = OBJ_PREFIX + "BOS_SL" + IntegerToString(i);
         if(ObjectCreate(0, label, OBJ_LABEL, 0, time[i], high[i] + 40 * _Point))
         {
            ObjectSetString(0, label, OBJPROP_TEXT, "BOS↓");
            ObjectSetInteger(0, label, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, label, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, label, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         }
         break;
      }
   }
}

//+------------------------------------------------------------------+
//| Detect Supply and Demand Zones                                    |
//+------------------------------------------------------------------+
void DetectSupplyDemand(const double &high[], const double &low[], const double &close[], const datetime &time[])
{
   if(ArraySize(high) < ZoneMaxBars) return;
   
   int zones_found = 0;
   
   // Scan for potential supply/demand zones
   for(int i = ZoneMaxBars; i < ArraySize(high) - 5 && zones_found < 5; i++)
   {
      // Demand Zone: Consolidation followed by strong bullish move
      bool is_demand = true;
      for(int j = i; j < i + 5 && j < ArraySize(high); j++)
      {
         if(close[j] < high[j-1] && j > i) { is_demand = false; break; }
      }
      
      if(is_demand)
      {
         double zone_high = high[i];
         double zone_low = low[i];
         
         // Check zone size
         double zone_size = (zone_high - zone_low) / zone_low * 100;
         if(zone_size < ZoneMinSize) continue;
         
         string name = OBJ_PREFIX + "DEM" + IntegerToString(i);
         if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, time[i], zone_low, time[i+3], zone_high))
         {
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrDeepSkyBlue);
            ObjectSetInteger(0, name, OBJPROP_FILL, true);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
            ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         }
         
         zones_found++;
      }
      
      // Supply Zone: Consolidation followed by strong bearish move
      bool is_supply = true;
      for(int j = i; j < i + 5 && j < ArraySize(high); j++)
      {
         if(close[j] > low[j-1] && j > i) { is_supply = false; break; }
      }
      
      if(is_supply)
      {
         double zone_high = high[i];
         double zone_low = low[i];
         
         double zone_size = (zone_high - zone_low) / zone_low * 100;
         if(zone_size < ZoneMinSize) continue;
         
         string name = OBJ_PREFIX + "SUP" + IntegerToString(i);
         if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, time[i], zone_low, time[i+3], zone_high))
         {
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrOrangeRed);
            ObjectSetInteger(0, name, OBJPROP_FILL, true);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
            ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         }
         
         zones_found++;
      }
   }
}

//+------------------------------------------------------------------+
//| Detect Area of Interest (AOI)                                    |
//+------------------------------------------------------------------+
void DetectAOI(const double &high[], const double &low[], const double &close[], const datetime &time[])
{
   // AOI: Confluence of FVG + Supply/Demand zones
   if(ArraySize(high) < 20) return;
   
   for(int i = 20; i < ArraySize(high) - 5; i++)
   {
      // Check for FVG confluence
      bool has_fvg = false;
      for(int j = i - 3; j <= i + 3 && j < ArraySize(high); j++)
      {
         if(j >= 2 && low[j] > high[j-2] && close[j-1] < close[j]) has_fvg = true;
         if(j >= 2 && high[j] < low[j-2] && close[j-1] > close[j]) has_fvg = true;
      }
      
      if(has_fvg)
      {
         // Find confluence zone
         double zone_high = high[i];
         double zone_low = low[i];
         
         for(int j = i - 5; j <= i + 5; j++)
         {
            if(j >= 0 && j < ArraySize(high))
            {
               zone_high = MathMax(zone_high, high[j]);
               zone_low = MathMin(zone_low, low[j]);
            }
         }
         
         string name = OBJ_PREFIX + "AOI" + IntegerToString(i);
         if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, time[i], zone_low, time[i+2], zone_high))
         {
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrYellow);
            ObjectSetInteger(0, name, OBJPROP_FILL, true);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
            ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         }
         
         string label = OBJ_PREFIX + "AOI_L" + IntegerToString(i);
         if(ObjectCreate(0, label, OBJ_LABEL, 0, time[i], zone_high + 30 * _Point))
         {
            ObjectSetString(0, label, OBJPROP_TEXT, "AOI");
            ObjectSetInteger(0, label, OBJPROP_COLOR, clrYellow);
            ObjectSetInteger(0, label, OBJPROP_FONTSIZE, 9);
            ObjectSetInteger(0, label, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         }
         
         break; // Show only one AOI at a time
      }
   }
}

//+------------------------------------------------------------------+
//| Detect Point of Interest (POI)                                   |
//+------------------------------------------------------------------+
void DetectPOI(const double &high[], const double &low[], const double &close[], const datetime &time[])
{
   // POI: Key support/resistance levels
   if(ArraySize(high) < 30) return;
   
   // Find recent key levels
   double res_level = high[5];
   double sup_level = low[5];
   
   for(int i = 5; i < 30 && i < ArraySize(high); i++)
   {
      res_level = MathMax(res_level, high[i]);
      sup_level = MathMin(sup_level, low[i]);
   }
   
   // Draw resistance line
   string res_name = OBJ_PREFIX + "RES";
   if(ObjectCreate(0, res_name, OBJ_HLINE, 0, 0, res_level))
   {
      ObjectSetInteger(0, res_name, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, res_name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, res_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, res_name, OBJPROP_SELECTABLE, false);
      
      string res_label = OBJ_PREFIX + "RES_L";
      if(ObjectCreate(0, res_label, OBJ_LABEL, 0, time[0], res_level))
      {
         ObjectSetString(0, res_label, OBJPROP_TEXT, "RES");
         ObjectSetInteger(0, res_label, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, res_label, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, res_label, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      }
   }
   
   // Draw support line
   string sup_name = OBJ_PREFIX + "SUP";
   if(ObjectCreate(0, sup_name, OBJ_HLINE, 0, 0, sup_level))
   {
      ObjectSetInteger(0, sup_name, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, sup_name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, sup_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, sup_name, OBJPROP_SELECTABLE, false);
      
      string sup_label = OBJ_PREFIX + "SUP_L";
      if(ObjectCreate(0, sup_label, OBJ_LABEL, 0, time[0], sup_level))
      {
         ObjectSetString(0, sup_label, OBJPROP_TEXT, "SUP");
         ObjectSetInteger(0, sup_label, OBJPROP_COLOR, clrLime);
         ObjectSetInteger(0, sup_label, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, sup_label, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate Breakout Probability                                    |
//+------------------------------------------------------------------+
double CalculateBreakoutProbability(const double &high[], const double &low[], 
                                     const double &close[], const long &tick_volume[], 
                                     const int rates_total)
{
   if(rates_total < ProbLookback) return 50;
   
   // Factor 1: Volume profile (higher volume = higher probability)
   double avg_vol = 0;
   for(int i = 1; i <= ProbLookback; i++)
      avg_vol += (double)tick_volume[i];
   avg_vol /= ProbLookback;
   
   double vol_score = MathMin(100, (tick_volume[0] / avg_vol) * 100);
   
   // Factor 2: Range compression (tighter range = higher probability)
   double range_high = high[0];
   double range_low = low[0];
   for(int i = 1; i <= ProbLookback; i++)
   {
      range_high = MathMax(range_high, high[i]);
      range_low = MathMin(range_low, low[i]);
   }
   double current_range = range_high - range_low;
   double avg_range = 0;
   for(int i = 1; i <= ProbLookback; i++)
   {
      avg_range += high[i] - low[i];
   }
   avg_range /= ProbLookback;
   
   double range_score = MathMin(100, (avg_range / current_range) * 50);
   
   // Factor 3: Trend strength (ADX-like calculation)
   double trend_score = 0;
   double ma_fast = 0, ma_slow = 0;
   for(int i = 0; i < 14; i++) ma_fast += close[i];
   for(int i = 0; i < 28; i++) ma_slow += close[i];
   ma_fast /= 14;
   ma_slow /= 28;
   trend_score = MathAbs(ma_fast - ma_slow) / ma_slow * 1000;
   trend_score = MathMin(100, trend_score);
   
   // Weighted probability
   double probability = vol_score * VolWeight + range_score * RangeWeight + trend_score * TrendWeight;
   
   return MathMin(100, MathMax(0, probability));
}

//+------------------------------------------------------------------+
//| Draw TP/SL levels                                                 |
//+------------------------------------------------------------------+
void DrawTPSL(double current_price, double atr_value)
{
   double sl_distance = atr_value * ATRMultiplier;
   double tp_distance = atr_value * TPMultiplier;
   
   // Buy SL/TP
   double buy_sl = current_price - sl_distance;
   double buy_tp = current_price + tp_distance;
   
   // Sell SL/TP
   double sell_sl = current_price + sl_distance;
   double sell_tp = current_price - tp_distance;
   
   // Draw Buy SL line
   string buy_sl_name = OBJ_PREFIX + "BUY_SL";
   if(ObjectCreate(0, buy_sl_name, OBJ_HLINE, 0, 0, buy_sl))
   {
      ObjectSetInteger(0, buy_sl_name, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, buy_sl_name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, buy_sl_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, buy_sl_name, OBJPROP_SELECTABLE, false);
   }
   
   // Draw Buy TP line
   string buy_tp_name = OBJ_PREFIX + "BUY_TP";
   if(ObjectCreate(0, buy_tp_name, OBJ_HLINE, 0, 0, buy_tp))
   {
      ObjectSetInteger(0, buy_tp_name, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, buy_tp_name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, buy_tp_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, buy_tp_name, OBJPROP_SELECTABLE, false);
   }
   
   // Draw Sell SL line
   string sell_sl_name = OBJ_PREFIX + "SELL_SL";
   if(ObjectCreate(0, sell_sl_name, OBJ_HLINE, 0, 0, sell_sl))
   {
      ObjectSetInteger(0, sell_sl_name, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, sell_sl_name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, sell_sl_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, sell_sl_name, OBJPROP_SELECTABLE, false);
   }
   
   // Draw Sell TP line
   string sell_tp_name = OBJ_PREFIX + "SELL_TP";
   if(ObjectCreate(0, sell_tp_name, OBJ_HLINE, 0, 0, sell_tp))
   {
      ObjectSetInteger(0, sell_tp_name, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, sell_tp_name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, sell_tp_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, sell_tp_name, OBJPROP_SELECTABLE, false);
   }
}

//+------------------------------------------------------------------+
//| Draw Dashboard Panel                                              |
//+------------------------------------------------------------------+
void DrawDashboard(double price, double atr, double prob, const datetime &time[])
{
   int corner = CORNER_LEFT_UPPER;
   int x_offset = 10;
   int y_offset = 20;
   int line_height = 18;
   
   // Panel background
   string panel_name = OBJ_PREFIX + "PANEL";
   if(ObjectCreate(0, panel_name, OBJ_RECTANGLE, 0, time[0], price + 100 * _Point, time[0] + 200, price - 250 * _Point))
   {
      ObjectSetInteger(0, panel_name, OBJPROP_COLOR, clrBlack);
      ObjectSetInteger(0, panel_name, OBJPROP_FILL, true);
      ObjectSetInteger(0, panel_name, OBJPROP_BACK, true);
      ObjectSetInteger(0, panel_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, panel_name, OBJPROP_SELECTABLE, false);
   }
   
   // Title
   string title = OBJ_PREFIX + "TITLE";
   if(ObjectCreate(0, title, OBJ_LABEL, 0, time[0], price + 80 * _Point))
   {
      ObjectSetString(0, title, OBJPROP_TEXT, "═══ PRICE ACTION DASHBOARD ═══");
      ObjectSetInteger(0, title, OBJPROP_COLOR, clrGold);
      ObjectSetInteger(0, title, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, title, OBJPROP_CORNER, corner);
      ObjectSetInteger(0, title, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, title, OBJPROP_XDISTANCE, x_offset);
      ObjectSetInteger(0, title, OBJPROP_YDISTANCE, y_offset);
   }
   
   // Price info
   string price_info = OBJ_PREFIX + "PRICE";
   if(ObjectCreate(0, price_info, OBJ_LABEL, 0, time[0], price + 60 * _Point))
   {
      ObjectSetString(0, price_info, OBJPROP_TEXT, StringFormat("Price: %.5f", price));
      ObjectSetInteger(0, price_info, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, price_info, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, price_info, OBJPROP_CORNER, corner);
      ObjectSetInteger(0, price_info, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, price_info, OBJPROP_XDISTANCE, x_offset);
      ObjectSetInteger(0, price_info, OBJPROP_YDISTANCE, y_offset + line_height);
   }
   
   // ATR info
   string atr_info = OBJ_PREFIX + "ATR";
   if(ObjectCreate(0, atr_info, OBJ_LABEL, 0, time[0], price + 40 * _Point))
   {
      ObjectSetString(0, atr_info, OBJPROP_TEXT, StringFormat("ATR: %.5f", atr));
      ObjectSetInteger(0, atr_info, OBJPROP_COLOR, clrSilver);
      ObjectSetInteger(0, atr_info, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, atr_info, OBJPROP_CORNER, corner);
      ObjectSetInteger(0, atr_info, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, atr_info, OBJPROP_XDISTANCE, x_offset);
      ObjectSetInteger(0, atr_info, OBJPROP_YDISTANCE, y_offset + line_height * 2);
   }
   
   // Breakout probability
   string prob_color = prob > 70 ? clrLime : (prob > 40 ? clrYellow : clrRed);
   string prob_info = OBJ_PREFIX + "PROB";
   if(ObjectCreate(0, prob_info, OBJ_LABEL, 0, time[0], price + 20 * _Point))
   {
      ObjectSetString(0, prob_info, OBJPROP_TEXT, StringFormat("Breakout Prob: %.0f%%", prob));
      ObjectSetInteger(0, prob_info, OBJPROP_COLOR, prob_color);
      ObjectSetInteger(0, prob_info, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, prob_info, OBJPROP_CORNER, corner);
      ObjectSetInteger(0, prob_info, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, prob_info, OBJPROP_XDISTANCE, x_offset);
      ObjectSetInteger(0, prob_info, OBJPROP_YDISTANCE, y_offset + line_height * 3);
   }
   
   // TP/SL info
   double sl_dist = atr * ATRMultiplier;
   double tp_dist = atr * TPMultiplier;
   string tpsl_info = OBJ_PREFIX + "TPSL";
   if(ObjectCreate(0, tpsl_info, OBJ_LABEL, 0, time[0], price - 10 * _Point))
   {
      ObjectSetString(0, tpsl_info, OBJPROP_TEXT, StringFormat("SL: %.2f | TP: %.2f", sl_dist, tp_dist));
      ObjectSetInteger(0, tpsl_info, OBJPROP_COLOR, clrSkyBlue);
      ObjectSetInteger(0, tpsl_info, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, tpsl_info, OBJPROP_CORNER, corner);
      ObjectSetInteger(0, tpsl_info, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, tpsl_info, OBJPROP_XDISTANCE, x_offset);
      ObjectSetInteger(0, tpsl_info, OBJPROP_YDISTANCE, y_offset + line_height * 4);
   }
   
   // Pattern indicators
   string patterns = OBJ_PREFIX + "PATTERNS";
   string pattern_text = "PATTERNS: ";
   if(ShowFVG) pattern_text += "FVG ● ";
   if(ShowCHoCH) pattern_text += "CHoCH ● ";
   if(ShowBOS) pattern_text += "BOS ● ";
   if(ShowSupplyDemand) pattern_text += "S/D ● ";
   
   if(ObjectCreate(0, patterns, OBJ_LABEL, 0, time[0], price - 30 * _Point))
   {
      ObjectSetString(0, patterns, OBJPROP_TEXT, pattern_text);
      ObjectSetInteger(0, patterns, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, patterns, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, patterns, OBJPROP_CORNER, corner);
      ObjectSetInteger(0, patterns, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, patterns, OBJPROP_XDISTANCE, x_offset);
      ObjectSetInteger(0, patterns, OBJPROP_YDISTANCE, y_offset + line_height * 5);
   }
   
   // Comment for MetaTrader info bar
   Comment(
      "\n═══════════════════════════════════════════\n" +
      "  PRICE ACTION DASHBOARD v1.0\n" +
      "═══════════════════════════════════════════\n" +
      "  Symbol: ", _Symbol, "\n" +
      "  Price: ", DoubleToString(price, _Digits), "\n" +
      "  ATR: ", DoubleToString(atr, _Digits), "\n" +
      "  Breakout Probability: ", IntegerToString((int)prob), "%\n" +
      "  SL Distance: ", DoubleToString(sl_dist, _Digits), "\n" +
      "  TP Distance: ", DoubleToString(tp_dist, _Digits), "\n" +
      "═══════════════════════════════════════════"
   );
}

//+------------------------------------------------------------------+
//| Timer function for periodic updates                               |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Additional periodic updates can be added here
}

//+------------------------------------------------------------------+
