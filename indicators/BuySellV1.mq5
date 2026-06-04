//+------------------------------------------------------------------+
//|                                               BuySellV1.mq5      |
//|                        Converted from TradingView Pine Script v6   |
//|                          Source: Buy Sell V1 by SimpleForexTools |
//|                    https://t.me/simpleforextools                   |
//+------------------------------------------------------------------+
#property copyright "SimpleForexTools | MQL5 Conversion"
#property link      "https://t.me/simpleforextools"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0
#property strict

// ╔══════════════════════════════════════════════════════════════════╗
// ║  INPUTS                                                          ║
// ╚══════════════════════════════════════════════════════════════════╝
input group "=== signalLib Config (ZigZag Engine) ==="
input int   InpDepth      = 30;           // HIGH LOWER ZONE (Depth)
input int   InpDeviation  = 5;            // CANDLES ZONES (Deviation, points)
input int   InpBackstep   = 5;            // MOVEMENT ZONE (Backstep)

input group "=== Labels ==="
input int   InpLabelsTransp = 0;          // Labels Transparency (0-100)
input int   InpLabelSize    = 3;          // Label size (1=Tiny..5=Huge)

input group "=== Colors ==="
input color InpBuyColor       = C'25,254,0';   // Buy-Color (bg)
input color InpSellColor      = C'254,8,0';    // Sell-Color (bg)
input color InpBuyTextColor   = clrBlack;      // Buy Text Color
input color InpSellTextColor  = clrBlack;      // Sell Text Color

input group "=== Settings ==="
input bool  InpRepaint = true;            // Repaint Mode
input bool  InpExtend  = false;           // Extend Lines (reserved)

// ╔══════════════════════════════════════════════════════════════════╗
// ║  GLOBALS                                                         ║
// ╚══════════════════════════════════════════════════════════════════╝
string g_prefix;                          // Object name prefix
int    g_fontSize;                        // Computed font size
int    g_lastAlertBar = -1;               // Prevent duplicate alerts

//--- Pivot history (circular buffer, size=4 is enough for ZigZag state)
struct SPivot
{
   int      bar;                          // Bar index
   datetime time;                         // Time
   double   price;                       // Pivot price
   int      dir;                         // +1 = High pivot (Sell), -1 = Low pivot (Buy)
};
SPivot g_pivots[];
int    g_pivotCount = 0;
int    g_pivotMax   = 256;               // Max stored pivots

//--- Repaint object tracking
string g_repaintObjName = "";            // Name of label on forming bar

// ╔══════════════════════════════════════════════════════════════════╗
// ║  UTILITIES                                                       ║
// ╚══════════════════════════════════════════════════════════════════╝

//+------------------------------------------------------------------+
//| Compute font size from 1..5 setting                               |
//+------------------------------------------------------------------+
int FontSizeFromSetting(int s)
{
   switch(s)
   {
      case 1: return 7;
      case 2: return 8;
      case 3: return 10;
      case 4: return 12;
      case 5: return 14;
   }
   return 10;
}

//+------------------------------------------------------------------+
//| Convert Pine transparency (0..100) to MQL5 color alpha (0..255)  |
//+------------------------------------------------------------------+
uint ColorWithAlpha(color clr, int transpPercent)
{
   if(transpPercent <= 0) return (uint)clr;
   if(transpPercent >= 100) return 0x00FFFFFF; // fully transparent white
   int alpha = 255 - (int)MathRound(transpPercent * 2.55);
   if(alpha < 0) alpha = 0;
   if(alpha > 255) alpha = 255;
   return (uint)((alpha << 24) | ((uint)clr & 0x00FFFFFF));
}

//+------------------------------------------------------------------+
//| Delete all objects created by this indicator                      |
//+------------------------------------------------------------------+
void DeleteAllObjects()
{
   int total = ObjectsTotal(ChartID(), -1, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(ChartID(), i, -1, -1);
      if(StringFind(name, g_prefix) == 0)
         ObjectDelete(ChartID(), name);
   }
}

//+------------------------------------------------------------------+
//| Delete repaint object if exists                                   |
//+------------------------------------------------------------------+
void DeleteRepaintObj()
{
   if(g_repaintObjName != "")
   {
      if(ObjectFind(ChartID(), g_repaintObjName) >= 0)
         ObjectDelete(ChartID(), g_repaintObjName);
      g_repaintObjName = "";
   }
}

//+------------------------------------------------------------------+
//| Create Buy/Sell label on chart                                    |
//+------------------------------------------------------------------+
string CreateLabel(int bar, double price, datetime t, int direction, bool isConfirmed)
{
   string suffix = (string)t + "_" + (string)bar + "_" + (string)g_pivotCount;
   string name   = g_prefix + (direction < 0 ? "Buy_" : "Sell_") + suffix;
   
   // If repaint mode and this is the current forming bar, track for later deletion
   if(InpRepaint && !isConfirmed)
   {
      DeleteRepaintObj();
      g_repaintObjName = name;
   }
   
   // Determine visual properties
   color bgColor    = (direction < 0) ? InpBuyColor  : InpSellColor;
   color textColor  = (direction < 0) ? InpBuyTextColor : InpSellTextColor;
   string text      = (direction < 0) ? "BUY" : "SELL";
   
   // For Sell (high pivot), place above bar; for Buy (low pivot), place below bar
   double offset = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 20 * _Point; // small offset
   double drawPrice = price;
   if(direction > 0)      drawPrice += offset; // Sell above
   else                   drawPrice -= offset; // Buy below
   
   // In MQL5, OBJ_TEXT places text at time/price.
   // We emulate Pine label.new with background by using OBJ_EDIT if we wanted bg,
   // but OBJ_EDIT is screen-pinned. Instead use OBJ_TEXT with visible color.
   if(!ObjectCreate(ChartID(), name, OBJ_TEXT, 0, t, drawPrice))
      return "";
   
   // Apply color with Pine-style transparency
   uint clr = ColorWithAlpha(textColor, InpLabelsTransp);
   ObjectSetInteger(ChartID(), name, OBJPROP_COLOR, clr);
   ObjectSetString(ChartID(),  name, OBJPROP_TEXT, text);
   ObjectSetString(ChartID(),  name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(ChartID(), name, OBJPROP_FONTSIZE, g_fontSize);
   ObjectSetInteger(ChartID(), name, OBJPROP_ANCHOR, (direction > 0) ? ANCHOR_LOWER : ANCHOR_UPPER);
   ObjectSetInteger(ChartID(), name, OBJPROP_BACK, false);
   
   return name;
}

// ╔══════════════════════════════════════════════════════════════════╗
// ║  ZIGZAG LOGIC  (reverse-engineered from signalLib parameters)   ║
// ╚══════════════════════════════════════════════════════════════════╝

//+------------------------------------------------------------------+
//| Add pivot to history buffer                                       |
//+------------------------------------------------------------------+
void AddPivot(int bar, datetime t, double price, int dir)
{
   if(g_pivotCount >= g_pivotMax)
   {
      // Shift left to make room
      for(int i = 0; i < g_pivotMax - 1; i++)
         g_pivots[i] = g_pivots[i + 1];
      g_pivotCount = g_pivotMax - 1;
   }
   
   SPivot p;
   p.bar   = bar;
   p.time  = t;
   p.price = price;
   p.dir   = dir;
   g_pivots[g_pivotCount] = p;
   g_pivotCount++;
}

//+------------------------------------------------------------------+
//| Get last confirmed pivot (excludes forming-bar repaint candidates)|
//+------------------------------------------------------------------+
bool GetLastConfirmedPivot(SPivot &out)
{
   if(g_pivotCount <= 0) return false;
   out = g_pivots[g_pivotCount - 1];
   return true;
}

//+------------------------------------------------------------------+
//| Replace last pivot (for repaint adjustments on current bar)       |
//+------------------------------------------------------------------+
void ReplaceLastPivot(int bar, datetime t, double price, int dir)
{
   if(g_pivotCount <= 0)
   {
      AddPivot(bar, t, price, dir);
      return;
   }
   g_pivots[g_pivotCount - 1].bar   = bar;
   g_pivots[g_pivotCount - 1].time  = t;
   g_pivots[g_pivotCount - 1].price = price;
   g_pivots[g_pivotCount - 1].dir   = dir;
}

//+------------------------------------------------------------------+
//| Standard Event Functions                                        |
//+------------------------------------------------------------------+
int OnInit()
{
   g_prefix  = "BSV1_" + (string)ChartID() + "_";
   g_fontSize= FontSizeFromSetting(InpLabelSize);
   ArrayResize(g_pivots, g_pivotMax);
   g_pivotCount = 0;
   g_lastAlertBar = -1;
   g_repaintObjName = "";
   DeleteAllObjects();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteAllObjects();
}

//+------------------------------------------------------------------+
//| MAIN CALCULATION                                                  |
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
   int start = (prev_calculated == 0) ? InpDepth : prev_calculated - 1;
   if(start < InpDepth) start = InpDepth;
   
   double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pointValue == 0) pointValue = _Point;
   double minDevPrice  = InpDeviation * pointValue * 10; // approximate pip/points scaling
   
   for(int i = start; i < rates_total && !IsStopped(); i++)
   {
      bool isHigh = true;
      bool isLow  = true;
      
      //--- Pivot High check: 'Depth' bars left and right must be lower
      for(int j = 1; j <= InpDepth; j++)
      {
         if(i - j < 0 || i + j >= rates_total)
         { isHigh = false; isLow = false; break; }
         
         if(high[i] <  high[i - j] || high[i] <  high[i + j]) isHigh = false;
         if(low[i]  >  low[i - j]  || low[i]  >  low[i + j])  isLow  = false;
      }
      
      if(!isHigh && !isLow) continue;
      
      int    detectedDir   = isHigh ? +1 : -1;        // +1 = High pivot → Sell zone
      double detectedPrice = isHigh ? high[i] : low[i];
      
      //--- FIRST PIVOT: just store, draw label depends on mode
      if(g_pivotCount == 0)
      {
         AddPivot(i, time[i], detectedPrice, detectedDir);
         
         if(InpRepaint)
            CreateLabel(i, detectedPrice, time[i], detectedDir, false);
         else
            CreateLabel(i, detectedPrice, time[i], detectedDir, true);
         
         // Alert on first confirmed bar only if repaint=false logic
         if(g_lastAlertBar != i)
         {
            g_lastAlertBar = i;
            if(detectedDir > 0) Alert("Sell signal generated!!!");
            else                Alert("Buy signal generated!!!");
         }
         continue;
      }
      
      //--- FETCH LAST PIVOT
      SPivot lastP;
      GetLastConfirmedPivot(lastP);
      
      //--- SAME DIRECTION: update extreme if more extreme (ZigZag "backstep" behavior)
      if(detectedDir == lastP.dir)
      {
         bool moreExtreme = false;
         if(detectedDir > 0 && detectedPrice > lastP.price) moreExtreme = true; // Higher high
         if(detectedDir < 0 && detectedPrice < lastP.price) moreExtreme = true; // Lower low
         
         if(moreExtreme)
         {
            // In repaint mode, update last pivot to more extreme value
            if(InpRepaint)
            {
               ReplaceLastPivot(i, time[i], detectedPrice, detectedDir);
               DeleteRepaintObj();
               CreateLabel(i, detectedPrice, time[i], detectedDir, false);
            }
            else if(i > lastP.bar)
            {
               // Non-repaint: if bar has advanced, this new extreme is confirmed
               ReplaceLastPivot(i, time[i], detectedPrice, detectedDir);
               CreateLabel(i, detectedPrice, time[i], detectedDir, true);
            }
         }
         continue;
      }
      
      //--- OPPOSITE DIRECTION: check deviation and backstep
      double priceMove = MathAbs(detectedPrice - lastP.price);
      if(priceMove < minDevPrice) continue; // Not enough deviation
      
      int barGap = i - lastP.bar;
      if(barGap < InpBackstep) continue;     // Too soon (backstep rule)
      
      //--- DIRECTION CHANGE CONFIRMED
      AddPivot(i, time[i], detectedPrice, detectedDir);
      
      bool isConfirmed = true;
      if(InpRepaint && i == rates_total - 1)
         isConfirmed = false; // forming bar
      
      CreateLabel(i, detectedPrice, time[i], detectedDir, isConfirmed);
      
      //--- Alert once per bar
      if(g_lastAlertBar != i)
      {
         g_lastAlertBar = i;
         if(detectedDir > 0) Alert("Sell signal generated!!!");
         else                Alert("Buy signal generated!!!");
      }
   }
   
   //--- Repaint mode: on the forming bar, ensure only latest label remains
   if(InpRepaint && rates_total > 0)
   {
      int formBar = rates_total - 1;
      // Already handled inside loop via ReplaceLastPivot + DeleteRepaintObj
   }
   
   return(rates_total);
}
//+------------------------------------------------------------------+
