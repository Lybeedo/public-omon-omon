//+------------------------------------------------------------------+
//|  MTF Trend Confluence                                            |
//|  BUY / SELL arrows when 3+ timeframes agree on trend direction   |
//|  Trend strength shown as stars or percentage                     |
//+------------------------------------------------------------------+
#property copyright   "MTF Trend Confluence"
#property version     "1.00"
#property strict

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_color1  clrLime    // BUY arrow
#property indicator_color2  clrRed     // SELL arrow
#property indicator_width1  3
#property indicator_width2  3
#property indicator_style1  STYLE_SOLID
#property indicator_style2  STYLE_SOLID

//--- Arrow codes
#property indicator_type1   DRAW_ARROW
#property indicator_type2   DRAW_ARROW

// ─────────────────────────────────────────
//  INPUTS
// ─────────────────────────────────────────
input int    FastEMA        = 9;          // Fast EMA Length
input int    SlowEMA        = 21;         // Slow EMA Length
input int    MinTFsRequired = 3;          // Min TFs needed for signal (2-5)

input bool   Use_M5        = true;        // Include M5
input bool   Use_M15       = true;        // Include M15
input bool   Use_H1        = true;        // Include H1
input bool   Use_H4        = true;        // Include H4
input bool   Use_D1        = true;        // Include Daily

input bool   ShowStars     = true;        // true=Stars, false=Percent
input bool   ShowTable     = true;        // Show confluence table
input double ATR_Offset    = 2.0;        // Arrow distance (ATR multiplier)
input int    ATR_Period     = 14;         // ATR period for arrow offset
input color  BuyColor       = clrLime;    // BUY label color
input color  SellColor      = clrRed;     // SELL label color
input int    LabelFontSize  = 9;          // Label font size

// ─────────────────────────────────────────
//  BUFFERS
// ─────────────────────────────────────────
double BuyBuffer[];
double SellBuffer[];

// ─────────────────────────────────────────
//  GLOBALS
// ─────────────────────────────────────────
string IndicatorName = "MTF_TC";
int    totalTFs;

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, BuyBuffer);
   SetIndexBuffer(1, SellBuffer);

   SetIndexArrow(0, 233);   // Up arrow
   SetIndexArrow(1, 234);   // Down arrow

   SetIndexLabel(0, "BUY Signal");
   SetIndexLabel(1, "SELL Signal");

   SetIndexEmptyValue(0, 0.0);
   SetIndexEmptyValue(1, 0.0);

   totalTFs = (Use_M5?1:0) + (Use_M15?1:0) + (Use_H1?1:0) + (Use_H4?1:0) + (Use_D1?1:0);

   IndicatorShortName("MTF Confluence (" + IntegerToString(MinTFsRequired) + "/" + IntegerToString(totalTFs) + ")");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Remove all labels and table objects
   ObjectsDeleteAll(0, IndicatorName);
}

//+------------------------------------------------------------------+
//  HELPER: EMA value from a given timeframe
//+------------------------------------------------------------------+
double GetEMA(int tf, int period, int shift)
{
   return iMA(NULL, tf, period, 0, MODE_EMA, PRICE_CLOSE, shift);
}

//+------------------------------------------------------------------+
//  HELPER: Is the given TF bullish at shift?
//  returns: 1=bullish, -1=bearish
//+------------------------------------------------------------------+
int GetTFDirection(int tf, int shift)
{
   double fast = GetEMA(tf, FastEMA, shift);
   double slow = GetEMA(tf, SlowEMA, shift);
   return (fast > slow) ? 1 : -1;
}

//+------------------------------------------------------------------+
//  HELPER: Count agreements
//+------------------------------------------------------------------+
int CountBullish(int shift)
{
   int count = 0;
   if(Use_M5  && GetTFDirection(PERIOD_M5,  shift) == 1) count++;
   if(Use_M15 && GetTFDirection(PERIOD_M15, shift) == 1) count++;
   if(Use_H1  && GetTFDirection(PERIOD_H1,  shift) == 1) count++;
   if(Use_H4  && GetTFDirection(PERIOD_H4,  shift) == 1) count++;
   if(Use_D1  && GetTFDirection(PERIOD_D1,  shift) == 1) count++;
   return count;
}

//+------------------------------------------------------------------+
//  HELPER: Build strength string
//+------------------------------------------------------------------+
string StrengthText(int count, int total)
{
   if(ShowStars)
   {
      string s = "";
      for(int i=0; i<count; i++)  s += "★";
      for(int i=0; i<total-count; i++) s += "☆";
      return s;
   }
   else
   {
      int pct = (total > 0) ? (int)MathRound((double)count / total * 100) : 0;
      return IntegerToString(pct) + "%";
   }
}

//+------------------------------------------------------------------+
//  HELPER: ATR value at shift
//+------------------------------------------------------------------+
double GetATR(int shift)
{
   return iATR(NULL, 0, ATR_Period, shift);
}

//+------------------------------------------------------------------+
//  Draw or update a label object
//+------------------------------------------------------------------+
void DrawLabel(string name, datetime time, double price, string txt, color clr, int anchor)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, time, price);

   ObjectSetString(0, name, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, LabelFontSize);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//  Draw confluence table in top-right corner
//+------------------------------------------------------------------+
void DrawTable(int bullCount, int bearCount, bool isBuy, bool isSell)
{
   int    dirs[5];
   string names[5] = {"M5","M15","H1","H4","D1"};
   bool   active[5];
   active[0]=Use_M5; active[1]=Use_M15; active[2]=Use_H1; active[3]=Use_H4; active[4]=Use_D1;

   dirs[0] = Use_M5  ? GetTFDirection(PERIOD_M5,  0) : 0;
   dirs[1] = Use_M15 ? GetTFDirection(PERIOD_M15, 0) : 0;
   dirs[2] = Use_H1  ? GetTFDirection(PERIOD_H1,  0) : 0;
   dirs[3] = Use_H4  ? GetTFDirection(PERIOD_H4,  0) : 0;
   dirs[4] = Use_D1  ? GetTFDirection(PERIOD_D1,  0) : 0;

   string prefix = IndicatorName + "_tbl_";

   // Header
   string hdr = "┌─ MTF Confluence ─────────┐";
   string obj_h = prefix + "hdr";
   if(ObjectFind(0, obj_h) < 0)
      ObjectCreate(0, obj_h, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, obj_h, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, obj_h, OBJPROP_XDISTANCE, 180);
   ObjectSetInteger(0, obj_h, OBJPROP_YDISTANCE, 20);
   ObjectSetString(0, obj_h, OBJPROP_TEXT, hdr);
   ObjectSetInteger(0, obj_h, OBJPROP_COLOR, clrGray);
   ObjectSetInteger(0, obj_h, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, obj_h, OBJPROP_FONT, "Courier New");
   ObjectSetInteger(0, obj_h, OBJPROP_SELECTABLE, false);

   // TF rows
   for(int i=0; i<5; i++)
   {
      string mark = !active[i] ? " OFF" : (dirs[i]==1 ? "  ▲  Bullish" : "  ▼  Bearish");
      color  rowcol = !active[i] ? clrGray : (dirs[i]==1 ? clrLime : clrTomato);
      string row = "│  " + names[i] + "   " + mark;

      string obj_r = prefix + "row" + IntegerToString(i);
      if(ObjectFind(0, obj_r) < 0)
         ObjectCreate(0, obj_r, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, obj_r, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, obj_r, OBJPROP_XDISTANCE, 180);
      ObjectSetInteger(0, obj_r, OBJPROP_YDISTANCE, 20 + (i+1)*14);
      ObjectSetString(0, obj_r, OBJPROP_TEXT, row);
      ObjectSetInteger(0, obj_r, OBJPROP_COLOR, rowcol);
      ObjectSetInteger(0, obj_r, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, obj_r, OBJPROP_FONT, "Courier New");
      ObjectSetInteger(0, obj_r, OBJPROP_SELECTABLE, false);
   }

   // Signal summary row
   string sigStr;
   color  sigCol;
   int    agreeing;
   if(isBuy)
   {
      agreeing = bullCount;
      sigStr = "│  ▲ BUY  " + StrengthText(agreeing, totalTFs) + "  (" + IntegerToString(agreeing) + "/" + IntegerToString(totalTFs) + ")";
      sigCol = clrLime;
   }
   else if(isSell)
   {
      agreeing = bearCount;
      sigStr = "│  ▼ SELL " + StrengthText(agreeing, totalTFs) + "  (" + IntegerToString(agreeing) + "/" + IntegerToString(totalTFs) + ")";
      sigCol = clrTomato;
   }
   else
   {
      sigStr = "│  — No Signal";
      sigCol = clrGray;
   }

   string obj_sig = prefix + "sig";
   if(ObjectFind(0, obj_sig) < 0)
      ObjectCreate(0, obj_sig, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, obj_sig, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, obj_sig, OBJPROP_XDISTANCE, 180);
   ObjectSetInteger(0, obj_sig, OBJPROP_YDISTANCE, 20 + 6*14);
   ObjectSetString(0, obj_sig, OBJPROP_TEXT, sigStr);
   ObjectSetInteger(0, obj_sig, OBJPROP_COLOR, sigCol);
   ObjectSetInteger(0, obj_sig, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, obj_sig, OBJPROP_FONT, "Courier New");
   ObjectSetInteger(0, obj_sig, OBJPROP_SELECTABLE, false);

   // Footer
   string ftr = "└──────────────────────────┘";
   string obj_f = prefix + "ftr";
   if(ObjectFind(0, obj_f) < 0)
      ObjectCreate(0, obj_f, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, obj_f, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, obj_f, OBJPROP_XDISTANCE, 180);
   ObjectSetInteger(0, obj_f, OBJPROP_YDISTANCE, 20 + 7*14);
   ObjectSetString(0, obj_f, OBJPROP_TEXT, ftr);
   ObjectSetInteger(0, obj_f, OBJPROP_COLOR, clrGray);
   ObjectSetInteger(0, obj_f, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, obj_f, OBJPROP_FONT, "Courier New");
   ObjectSetInteger(0, obj_f, OBJPROP_SELECTABLE, false);
}

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
   if(rates_total < SlowEMA + 10) return(0);

   int limit = rates_total - prev_calculated;
   if(prev_calculated == 0) limit = rates_total - SlowEMA - 1;

   // Only recalculate recently formed bars to avoid huge lookback on historical
   if(limit > 200) limit = 200;

   bool prevBuy  = false;
   bool prevSell = false;

   for(int i = limit; i >= 0; i--)
   {
      BuyBuffer[i]  = 0.0;
      SellBuffer[i] = 0.0;

      int bullCount = CountBullish(i);
      int bearCount = totalTFs - bullCount;

      bool isBuy  = bullCount >= MinTFsRequired;
      bool isSell = bearCount >= MinTFsRequired;

      double atr = GetATR(i);

      // Fire only on transition (suppress repeat arrows)
      bool fireBuy  = isBuy  && !prevBuy;
      bool fireSell = isSell && !prevSell;

      if(fireBuy)
      {
         BuyBuffer[i] = low[i] - atr * ATR_Offset;

         // Strength label
         string lname = IndicatorName + "_buy_" + IntegerToString(i);
         string ltxt  = "▲ BUY " + StrengthText(bullCount, totalTFs);
         DrawLabel(lname, time[i], low[i] - atr * (ATR_Offset + 0.6), ltxt, BuyColor, ANCHOR_TOP);
      }

      if(fireSell)
      {
         SellBuffer[i] = high[i] + atr * ATR_Offset;

         // Strength label
         string lname = IndicatorName + "_sel_" + IntegerToString(i);
         string ltxt  = "▼ SELL " + StrengthText(bearCount, totalTFs);
         DrawLabel(lname, time[i], high[i] + atr * (ATR_Offset + 0.6), ltxt, SellColor, ANCHOR_BOTTOM);
      }

      prevBuy  = isBuy;
      prevSell = isSell;
   }

   // Draw live table on current bar
   if(ShowTable)
   {
      int bullNow = CountBullish(0);
      int bearNow = totalTFs - bullNow;
      DrawTable(bullNow, bearNow, bullNow >= MinTFsRequired, bearNow >= MinTFsRequired);
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
