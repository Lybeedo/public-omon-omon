//+------------------------------------------------------------------+
//|                                           PriceActionDashboard.mq5 |
//|                              Dashboard FVG, CHoCH, BOS, S&D, AOI |
//|                                    Breakout Probability Expert    |
//+------------------------------------------------------------------+
#property copyright   "Trader Nakal"
#property version     "1.00"
#property description "Price Action Dashboard: FVG, CHoCH, BOS, Supply/Demand, AOI/POI, Breakout Prob"
#property expert

#include <Trade\Trade.mqh>

//--- Input Parameters
input group "=== Dashboard Settings ==="
input bool   ShowFVG          = true;
input bool   ShowCHoCH        = true;
input bool   ShowBOS          = true;
input bool   ShowSupplyDemand = true;
input bool   ShowAOI          = true;
input bool   ShowPOI          = true;
input bool   ShowBreakoutProb = true;
input bool   ShowTPSL         = true;

input group "=== Detection Settings ==="
input int    SwingLookback  = 20;
input int    FVGMinBars     = 3;
input double BOSMinPct      = 0.1;
input int    ATRPeriod      = 14;
input double ATRMultiplier  = 2.0;
input double TPMultiplier   = 3.0;
input int    ZoneMaxBars    = 50;
input double ZoneMinSize    = 0.5;

input group "=== Breakout Probability ==="
input int    ProbLookback   = 100;
input double VolWeight      = 0.3;
input double RangeWeight    = 0.4;
input double TrendWeight    = 0.3;

//--- Global Variables
CTrade g_trade;
double g_atr[];
double g_vol[];
int    g_atr_handle;

#define OBJ_PREFIX "PAD_"

//+------------------------------------------------------------------+
//| Custom indicator initialization function                          |
//+------------------------------------------------------------------+
int OnInit()
{
   g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, (int)ATRPeriod);
   if(g_atr_handle == INVALID_HANDLE)
   {
      Print("Failed to create ATR indicator");
      return(INIT_FAILED);
   }

   ArraySetAsSeries(g_atr, true);
   ArraySetAsSeries(g_vol, true);

   EventSetTimer(1);

   Print("Price Action Dashboard EA initialized");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_atr_handle != INVALID_HANDLE)
      IndicatorRelease(g_atr_handle);

   ObjectsDeleteAll(0, OBJ_PREFIX);
   Comment("");
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                               |
//+------------------------------------------------------------------+
void OnTick()
{
   MqlRates rates[];
   int copied = CopyRates(_Symbol, PERIOD_CURRENT, 0, 200, rates);
   if(copied <= 0) return;

   // Copy to arrays for function calls
   datetime time[];
   double open[];
   double high[];
   double low[];
   double close[];
   long volume[];

   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(volume, true);

   ArrayCopy(time, rates[].time);
   ArrayCopy(open, rates[].open);
   ArrayCopy(high, rates[].high);
   ArrayCopy(low, rates[].low);
   ArrayCopy(close, rates[].close);
   ArrayCopy(volume, rates[].tick_volume);

   if(CopyBuffer(g_atr_handle, 0, 0, 50, g_atr) <= 0)
      return;

   ObjectsDeleteAll(0, OBJ_PREFIX);

   double current_price = close[0];
   double atr_value     = g_atr[0];

   if(ShowFVG)          DetectFVG(high, low, close, time);
   if(ShowCHoCH)        DetectCHoCH(high, low, close, time);
   if(ShowBOS)          DetectBOS(high, low, close, time);
   if(ShowSupplyDemand) DetectSupplyDemand(high, low, close, time);
   if(ShowAOI)          DetectAOI(high, low, close, time);
   if(ShowPOI)          DetectPOI(high, low, close, time);

   double breakout_prob = 0;
   if(ShowBreakoutProb)
      breakout_prob = CalculateBreakoutProbability(high, low, close, volume, 200);

   if(ShowTPSL)
      DrawTPSL(current_price, atr_value);

   DrawDashboard(current_price, atr_value, breakout_prob, time);
}

//+------------------------------------------------------------------+
//| Detect Fair Value Gaps (FVG)                                      |
//+------------------------------------------------------------------+
void DetectFVG(const double &high[], const double &low[], const double &close[], const datetime &time[])
{
   int drawn = 0;
   int max_bars = MathMin(SwingLookback * 2, ArraySize(high) - 3);

   for(int i = 2; i < max_bars && drawn < 10; i++)
   {
      // Bullish FVG
      if(low[i] > high[i-2] && close[i-1] < close[i])
      {
         double fvg_top    = high[i-2];
         double fvg_bottom = low[i];
         double fvg_mid    = (fvg_top + fvg_bottom) / 2;

         string name = OBJ_PREFIX + "FVG_B_" + IntegerToString(i);
         if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, time[i-2], fvg_bottom, time[i], fvg_top))
         {
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrLime);
            ObjectSetInteger(0, name, OBJPROP_FILL,    true);
            ObjectSetInteger(0, name, OBJPROP_BACK,    true);
            ObjectSetInteger(0, name, OBJPROP_STYLE,   STYLE_SOLID);
            ObjectSetInteger(0, name, OBJPROP_WIDTH,   1);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         }

         string label = OBJ_PREFIX + "FVG_B_L" + IntegerToString(i);
         if(ObjectCreate(0, label, OBJ_LABEL, 0, time[i-1], fvg_mid))
         {
            ObjectSetString(0, label, OBJPROP_TEXT,    "FVG\u2191");
            ObjectSetInteger(0, label, OBJPROP_COLOR,  clrLime);
            ObjectSetInteger(0, label, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, label, OBJPROP_CORNER,  CORNER_LEFT_UPPER);
            ObjectSetInteger(0, label, OBJPROP_ANCHOR,  ANCHOR_CENTER);
         }
         drawn++;
      }

      // Bearish FVG
      if(high[i] < low[i-2] && close[i-1] > close[i])
      {
         double fvg_top    = high[i];
         double fvg_bottom = low[i-2];
         double fvg_mid    = (fvg_top + fvg_bottom) / 2;

         string name = OBJ_PREFIX + "FVG_S_" + IntegerToString(i);
         if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, time[i-2], fvg_bottom, time[i], fvg_top))
         {
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, name, OBJPROP_FILL,    true);
            ObjectSetInteger(0, name, OBJPROP_BACK,    true);
            ObjectSetInteger(0, name, OBJPROP_STYLE,   STYLE_SOLID);
            ObjectSetInteger(0, name, OBJPROP_WIDTH,   1);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         }

         string label = OBJ_PREFIX + "FVG_S_L" + IntegerToString(i);
         if(ObjectCreate(0, label, OBJ_LABEL, 0, time[i-1], fvg_mid))
         {
            ObjectSetString(0, label, OBJPROP_TEXT,    "FVG\u2193");
            ObjectSetInteger(0, label, OBJPROP_COLOR,  clrRed);
            ObjectSetInteger(0, label, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, label, OBJPROP_CORNER,  CORNER_LEFT_UPPER);
            ObjectSetInteger(0, label, OBJPROP_ANCHOR,  ANCHOR_CENTER);
         }
         drawn++;
      }
   }
}

//+------------------------------------------------------------------+
//| Detect Change of Character (CHoCH)                                |
//+------------------------------------------------------------------+
void DetectCHoCH(const double &high[], const double &low[], const double &close[], const datetime &time[])
{
   if(ArraySize(high) < SwingLookback + 5) return;

   int direction = 0;

   double swing_high = high[SwingLookback];
   int    swing_high_idx = SwingLookback;
   double swing_low  = low[SwingLookback];
   int    swing_low_idx = SwingLookback;

   for(int i = SwingLookback; i < 2 * SwingLookback && i < ArraySize(high); i++)
   {
      if(high[i] > swing_high) { swing_high = high[i]; swing_high_idx = i; }
      if(low[i]  < swing_low)  { swing_low  = low[i];  swing_low_idx  = i; }
   }

   for(int i = swing_high_idx + 2; i < ArraySize(high) - 1; i++)
   {
      if(close[i] > swing_high && direction == -1)
      {
         string name = OBJ_PREFIX + "CHoCH_B" + IntegerToString(i);
         if(ObjectCreate(0, name, OBJ_ARROW, 0, time[i], low[i]))
         {
            ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 233);
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrLime);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);
         }

         string label = OBJ_PREFIX + "CHoCH_BL" + IntegerToString(i);
         if(ObjectCreate(0, label, OBJ_LABEL, 0, time[i], low[i] - 50 * _Point))
         {
            ObjectSetString(0, label, OBJPROP_TEXT,    "CHoCH\u2191");
            ObjectSetInteger(0, label, OBJPROP_COLOR,  clrLime);
            ObjectSetInteger(0, label, OBJPROP_FONTSIZE, 9);
            ObjectSetInteger(0, label, OBJPROP_CORNER,  CORNER_LEFT_UPPER);
         }
         direction = 1;
         break;
      }

      if(close[i] < swing_low && direction == 1)
      {
         string name = OBJ_PREFIX + "CHoCH_S" + IntegerToString(i);
         if(ObjectCreate(0, name, OBJ_ARROW, 0, time[i], high[i]))
         {
            ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 234);
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);
         }

         string label = OBJ_PREFIX + "CHoCH_SL" + IntegerToString(i);
         if(ObjectCreate(0, label, OBJ_LABEL, 0, time[i], high[i] + 50 * _Point))
         {
            ObjectSetString(0, label, OBJPROP_TEXT,    "CHoCH\u2193");
            ObjectSetInteger(0, label, OBJPROP_COLOR,  clrRed);
            ObjectSetInteger(0, label, OBJPROP_FONTSIZE, 9);
            ObjectSetInteger(0, label, OBJPROP_CORNER,  CORNER_LEFT_UPPER);
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

   double structure_price = close[5];

   for(int i = 0; i < 10 && i < ArraySize(close) - 2; i++)
   {
      double check_price = close[i];

      if(check_price > structure_price * (1.0 + BOSMinPct / 100.0))
      {
         string name = OBJ_PREFIX + "BOS_B" + IntegerToString(i);
         if(ObjectCreate(0, name, OBJ_ARROW, 0, time[i], low[i]))
         {
            ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 241);
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrLime);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
         }

         string label = OBJ_PREFIX + "BOS_BL" + IntegerToString(i);
         if(ObjectCreate(0, label, OBJ_LABEL, 0, time[i], low[i] - 40 * _Point))
         {
            ObjectSetString(0, label, OBJPROP_TEXT,    "BOS\u2191");
            ObjectSetInteger(0, label, OBJPROP_COLOR,  clrLime);
            ObjectSetInteger(0, label, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, label, OBJPROP_CORNER,  CORNER_LEFT_UPPER);
         }
         break;
      }

      if(check_price < structure_price * (1.0 - BOSMinPct / 100.0))
      {
         string name = OBJ_PREFIX + "BOS_S" + IntegerToString(i);
         if(ObjectCreate(0, name, OBJ_ARROW, 0, time[i], high[i]))
         {
            ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 242);
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
         }

         string label = OBJ_PREFIX + "BOS_SL" + IntegerToString(i);
         if(ObjectCreate(0, label, OBJ_LABEL, 0, time[i], high[i] + 40 * _Point))
         {
            ObjectSetString(0, label, OBJPROP_TEXT,    "BOS\u2193");
            ObjectSetInteger(0, label, OBJPROP_COLOR,  clrRed);
            ObjectSetInteger(0, label, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, label, OBJPROP_CORNER,  CORNER_LEFT_UPPER);
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

   for(int i = ZoneMaxBars; i < ArraySize(high) - 5 && zones_found < 5; i++)
   {
      bool is_demand = true;
      for(int j = i; j < i + 5 && j < ArraySize(high); j++)
      {
         if(j > i && close[j] < high[j-1]) { is_demand = false; break; }
      }

      if(is_demand)
      {
         double zone_high = high[i];
         double zone_low  = low[i];
         double zone_size = (zone_high - zone_low) / zone_low * 100.0;
         if(zone_size < ZoneMinSize) continue;

         string name = OBJ_PREFIX + "DEM" + IntegerToString(i);
         if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, time[i], zone_low, time[i+3], zone_high))
         {
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrDeepSkyBlue);
            ObjectSetInteger(0, name, OBJPROP_FILL,    true);
            ObjectSetInteger(0, name, OBJPROP_BACK,    true);
            ObjectSetInteger(0, name, OBJPROP_STYLE,   STYLE_DOT);
            ObjectSetInteger(0, name, OBJPROP_WIDTH,   1);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         }
         zones_found++;
      }

      bool is_supply = true;
      for(int j = i; j < i + 5 && j < ArraySize(high); j++)
      {
         if(j > i && close[j] > low[j-1]) { is_supply = false; break; }
      }

      if(is_supply)
      {
         double zone_high = high[i];
         double zone_low  = low[i];
         double zone_size = (zone_high - zone_low) / zone_low * 100.0;
         if(zone_size < ZoneMinSize) continue;

         string name = OBJ_PREFIX + "SUP" + IntegerToString(i);
         if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, time[i], zone_low, time[i+3], zone_high))
         {
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrOrangeRed);
            ObjectSetInteger(0, name, OBJPROP_FILL,    true);
            ObjectSetInteger(0, name, OBJPROP_BACK,    true);
            ObjectSetInteger(0, name, OBJPROP_STYLE,   STYLE_DOT);
            ObjectSetInteger(0, name, OBJPROP_WIDTH,   1);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         }
         zones_found++;
      }
   }
}

//+------------------------------------------------------------------+
//| Detect Area of Interest (AOI)                                     |
//+------------------------------------------------------------------+
void DetectAOI(const double &high[], const double &low[], const double &close[], const datetime &time[])
{
   if(ArraySize(high) < 20) return;

   for(int i = 20; i < ArraySize(high) - 5; i++)
   {
      bool has_fvg = false;
      for(int j = i - 3; j <= i + 3 && j < ArraySize(high); j++)
      {
         if(j >= 2 && low[j] > high[j-2] && close[j-1] < close[j]) has_fvg = true;
         if(j >= 2 && high[j] < low[j-2] && close[j-1] > close[j]) has_fvg = true;
      }

      if(has_fvg)
      {
         double zone_high = high[i];
         double zone_low  = low[i];

         for(int j = i - 5; j <= i + 5; j++)
         {
            if(j >= 0 && j < ArraySize(high))
            {
               zone_high = MathMax(zone_high, high[j]);
               zone_low  = MathMin(zone_low,  low[j]);
            }
         }

         string name = OBJ_PREFIX + "AOI" + IntegerToString(i);
         if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, time[i], zone_low, time[i+2], zone_high))
         {
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrYellow);
            ObjectSetInteger(0, name, OBJPROP_FILL,    true);
            ObjectSetInteger(0, name, OBJPROP_BACK,    true);
            ObjectSetInteger(0, name, OBJPROP_STYLE,   STYLE_SOLID);
            ObjectSetInteger(0, name, OBJPROP_WIDTH,   2);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         }

         string label = OBJ_PREFIX + "AOI_L" + IntegerToString(i);
         if(ObjectCreate(0, label, OBJ_LABEL, 0, time[i], zone_high + 30 * _Point))
         {
            ObjectSetString(0, label, OBJPROP_TEXT,    "AOI");
            ObjectSetInteger(0, label, OBJPROP_COLOR,  clrYellow);
            ObjectSetInteger(0, label, OBJPROP_FONTSIZE, 9);
            ObjectSetInteger(0, label, OBJPROP_CORNER,  CORNER_LEFT_UPPER);
         }
         break;
      }
   }
}

//+------------------------------------------------------------------+
//| Detect Point of Interest (POI)                                    |
//+------------------------------------------------------------------+
void DetectPOI(const double &high[], const double &low[], const double &close[], const datetime &time[])
{
   if(ArraySize(high) < 30) return;

   double res_level = high[5];
   double sup_level = low[5];

   for(int i = 5; i < 30 && i < ArraySize(high); i++)
   {
      res_level = MathMax(res_level, high[i]);
      sup_level = MathMin(sup_level, low[i]);
   }

   // Resistance line
   string res_name  = OBJ_PREFIX + "RES";
   string res_label = OBJ_PREFIX + "RES_L";

   if(ObjectCreate(0, res_name, OBJ_HLINE, 0, 0, res_level))
   {
      ObjectSetInteger(0, res_name, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, res_name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, res_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, res_name, OBJPROP_SELECTABLE, false);
   }
   if(ObjectCreate(0, res_label, OBJ_LABEL, 0, time[0], res_level))
   {
      ObjectSetString(0, res_label, OBJPROP_TEXT,    "RES");
      ObjectSetInteger(0, res_label, OBJPROP_COLOR,  clrRed);
      ObjectSetInteger(0, res_label, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, res_label, OBJPROP_CORNER,  CORNER_RIGHT_UPPER);
   }

   // Support line
   string sup_name  = OBJ_PREFIX + "SUP";
   string sup_label = OBJ_PREFIX + "SUP_L";

   if(ObjectCreate(0, sup_name, OBJ_HLINE, 0, 0, sup_level))
   {
      ObjectSetInteger(0, sup_name, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, sup_name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, sup_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, sup_name, OBJPROP_SELECTABLE, false);
   }
   if(ObjectCreate(0, sup_label, OBJ_LABEL, 0, time[0], sup_level))
   {
      ObjectSetString(0, sup_label, OBJPROP_TEXT,    "SUP");
      ObjectSetInteger(0, sup_label, OBJPROP_COLOR,  clrLime);
      ObjectSetInteger(0, sup_label, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, sup_label, OBJPROP_CORNER,  CORNER_RIGHT_LOWER);
   }
}

//+------------------------------------------------------------------+
//| Calculate Breakout Probability                                    |
//+------------------------------------------------------------------+
double CalculateBreakoutProbability(const double &high[], const double &low[],
                                     const double &close[], const long &tick_volume[],
                                     const int rates_total)
{
   if(rates_total < ProbLookback) return 50.0;

   // Factor 1: Volume profile
   double avg_vol = 0.0;
   for(int i = 1; i <= ProbLookback; i++)
      avg_vol += (double)tick_volume[i];
   avg_vol /= ProbLookback;

   double vol_score = MathMin(100.0, (tick_volume[0] / MathMax(avg_vol, 1.0)) * 100.0);

   // Factor 2: Range compression
   double range_high = high[0];
   double range_low  = low[0];
   for(int i = 1; i <= ProbLookback; i++)
   {
      range_high = MathMax(range_high, high[i]);
      range_low  = MathMin(range_low,  low[i]);
   }
   double current_range = range_high - range_low;
   double avg_range = 0.0;
   for(int i = 1; i <= ProbLookback; i++)
      avg_range += high[i] - low[i];
   avg_range /= ProbLookback;

   double range_score = MathMin(100.0, (avg_range / MathMax(current_range, 0.0001)) * 50.0);

   // Factor 3: Trend strength
   double ma_fast = 0.0, ma_slow = 0.0;
   for(int i = 0; i < 14; i++) ma_fast  += close[i];
   for(int i = 0; i < 28; i++) ma_slow  += close[i];
   ma_fast /= 14.0;
   ma_slow /= 28.0;
   double trend_score = MathMin(100.0, MathAbs(ma_fast - ma_slow) / MathMax(ma_slow, 0.0001) * 1000.0);

   return MathMin(100.0, MathMax(0.0,
      vol_score  * VolWeight +
      range_score * RangeWeight +
      trend_score * TrendWeight
   ));
}

//+------------------------------------------------------------------+
//| Draw TP/SL levels                                                 |
//+------------------------------------------------------------------+
void DrawTPSL(double current_price, double atr_value)
{
   double sl_dist = atr_value * ATRMultiplier;
   double tp_dist = atr_value * TPMultiplier;

   // Buy SL/TP
   if(ObjectCreate(0, OBJ_PREFIX + "BUY_SL", OBJ_HLINE, 0, 0, current_price - sl_dist))
   {
      ObjectSetInteger(0, OBJ_PREFIX + "BUY_SL", OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, OBJ_PREFIX + "BUY_SL", OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, OBJ_PREFIX + "BUY_SL", OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, OBJ_PREFIX + "BUY_SL", OBJPROP_SELECTABLE, false);
   }
   if(ObjectCreate(0, OBJ_PREFIX + "BUY_TP", OBJ_HLINE, 0, 0, current_price + tp_dist))
   {
      ObjectSetInteger(0, OBJ_PREFIX + "BUY_TP", OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, OBJ_PREFIX + "BUY_TP", OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, OBJ_PREFIX + "BUY_TP", OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, OBJ_PREFIX + "BUY_TP", OBJPROP_SELECTABLE, false);
   }

   // Sell SL/TP
   if(ObjectCreate(0, OBJ_PREFIX + "SELL_SL", OBJ_HLINE, 0, 0, current_price + sl_dist))
   {
      ObjectSetInteger(0, OBJ_PREFIX + "SELL_SL", OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, OBJ_PREFIX + "SELL_SL", OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, OBJ_PREFIX + "SELL_SL", OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, OBJ_PREFIX + "SELL_SL", OBJPROP_SELECTABLE, false);
   }
   if(ObjectCreate(0, OBJ_PREFIX + "SELL_TP", OBJ_HLINE, 0, 0, current_price - tp_dist))
   {
      ObjectSetInteger(0, OBJ_PREFIX + "SELL_TP", OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, OBJ_PREFIX + "SELL_TP", OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, OBJ_PREFIX + "SELL_TP", OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, OBJ_PREFIX + "SELL_TP", OBJPROP_SELECTABLE, false);
   }
}

//+------------------------------------------------------------------+
//| Draw Dashboard Panel                                              |
//+------------------------------------------------------------------+
void DrawDashboard(double price, double atr, double prob, const datetime &time[])
{
   const int corner    = CORNER_LEFT_UPPER;
   const int x_offset  = 10;
   const int y_offset  = 20;
   const int lh        = 18;

   double sl_dist = atr * ATRMultiplier;
   double tp_dist = atr * TPMultiplier;

   // Panel background
   string panel = OBJ_PREFIX + "PANEL";
   if(ObjectCreate(0, panel, OBJ_RECTANGLE, 0, time[0], price + 100 * _Point, time[0] + 200, price - 250 * _Point))
   {
      ObjectSetInteger(0, panel, OBJPROP_COLOR, clrBlack);
      ObjectSetInteger(0, panel, OBJPROP_FILL,    true);
      ObjectSetInteger(0, panel, OBJPROP_BACK,    true);
      ObjectSetInteger(0, panel, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, panel, OBJPROP_SELECTABLE, false);
   }

   string title  = OBJ_PREFIX + "TITLE";
   if(ObjectCreate(0, title, OBJ_LABEL, 0, time[0], price + 80 * _Point))
   {
      ObjectSetString(0, title, OBJPROP_TEXT,    "═══ PRICE ACTION DASHBOARD ═══");
      ObjectSetInteger(0, title, OBJPROP_COLOR,  clrGold);
      ObjectSetInteger(0, title, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, title, OBJPROP_CORNER,  corner);
      ObjectSetInteger(0, title, OBJPROP_ANCHOR,  ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, title, OBJPROP_XDISTANCE, x_offset);
      ObjectSetInteger(0, title, OBJPROP_YDISTANCE, y_offset);
   }

   string info_price = OBJ_PREFIX + "PRICE";
   if(ObjectCreate(0, info_price, OBJ_LABEL, 0, time[0], price + 60 * _Point))
   {
      ObjectSetString(0, info_price, OBJPROP_TEXT, StringFormat("Price: %.5f", price));
      ObjectSetInteger(0, info_price, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, info_price, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, info_price, OBJPROP_CORNER, corner);
      ObjectSetInteger(0, info_price, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, info_price, OBJPROP_XDISTANCE, x_offset);
      ObjectSetInteger(0, info_price, OBJPROP_YDISTANCE, y_offset + lh);
   }

   string info_atr = OBJ_PREFIX + "ATR";
   if(ObjectCreate(0, info_atr, OBJ_LABEL, 0, time[0], price + 40 * _Point))
   {
      ObjectSetString(0, info_atr, OBJPROP_TEXT, StringFormat("ATR: %.5f", atr));
      ObjectSetInteger(0, info_atr, OBJPROP_COLOR, clrSilver);
      ObjectSetInteger(0, info_atr, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, info_atr, OBJPROP_CORNER, corner);
      ObjectSetInteger(0, info_atr, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, info_atr, OBJPROP_XDISTANCE, x_offset);
      ObjectSetInteger(0, info_atr, OBJPROP_YDISTANCE, y_offset + lh * 2);
   }

   color   prob_color = prob > 70.0 ? clrLime : (prob > 40.0 ? clrYellow : clrRed);
   string  info_prob  = OBJ_PREFIX + "PROB";
   if(ObjectCreate(0, info_prob, OBJ_LABEL, 0, time[0], price + 20 * _Point))
   {
      ObjectSetString(0, info_prob, OBJPROP_TEXT, StringFormat("Breakout Prob: %.0f%%", prob));
      ObjectSetInteger(0, info_prob, OBJPROP_COLOR, prob_color);
      ObjectSetInteger(0, info_prob, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, info_prob, OBJPROP_CORNER, corner);
      ObjectSetInteger(0, info_prob, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, info_prob, OBJPROP_XDISTANCE, x_offset);
      ObjectSetInteger(0, info_prob, OBJPROP_YDISTANCE, y_offset + lh * 3);
   }

   string info_tpsl = OBJ_PREFIX + "TPSL";
   if(ObjectCreate(0, info_tpsl, OBJ_LABEL, 0, time[0], price - 10 * _Point))
   {
      ObjectSetString(0, info_tpsl, OBJPROP_TEXT, StringFormat("SL: %.2f | TP: %.2f", sl_dist, tp_dist));
      ObjectSetInteger(0, info_tpsl, OBJPROP_COLOR, clrSkyBlue);
      ObjectSetInteger(0, info_tpsl, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, info_tpsl, OBJPROP_CORNER, corner);
      ObjectSetInteger(0, info_tpsl, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, info_tpsl, OBJPROP_XDISTANCE, x_offset);
      ObjectSetInteger(0, info_tpsl, OBJPROP_YDISTANCE, y_offset + lh * 4);
   }

   string info_pat = OBJ_PREFIX + "PATTERNS";
   string pat_text = "PATTERNS: ";
   if(ShowFVG)          pat_text += "FVG \u25cf ";
   if(ShowCHoCH)        pat_text += "CHoCH \u25cf ";
   if(ShowBOS)          pat_text += "BOS \u25cf ";
   if(ShowSupplyDemand) pat_text += "S/D \u25cf ";

   if(ObjectCreate(0, info_pat, OBJ_LABEL, 0, time[0], price - 30 * _Point))
   {
      ObjectSetString(0, info_pat, OBJPROP_TEXT, pat_text);
      ObjectSetInteger(0, info_pat, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, info_pat, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, info_pat, OBJPROP_CORNER, corner);
      ObjectSetInteger(0, info_pat, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, info_pat, OBJPROP_XDISTANCE, x_offset);
      ObjectSetInteger(0, info_pat, OBJPROP_YDISTANCE, y_offset + lh * 5);
   }

   Comment(
      "\n═══════════════════════════════════════════\n" +
      "  PRICE ACTION DASHBOARD v1.0\n" +
      "═══════════════════════════════════════════\n" +
      "  Symbol: ", _Symbol, "\n" +
      "  Price: ", DoubleToString(price, _Digits), "\n" +
      "  ATR: ", DoubleToString(atr, _Digits), "\n" +
      "  Breakout Prob: ", IntegerToString((int)prob), "%\n" +
      "  SL Distance: ", DoubleToString(sl_dist, _Digits), "\n" +
      "  TP Distance: ", DoubleToString(tp_dist, _Digits), "\n" +
      "═══════════════════════════════════════════"
   );
}

//+------------------------------------------------------------------+
