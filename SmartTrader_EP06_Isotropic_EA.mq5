//+------------------------------------------------------------------+
//|                     SmartTrader_EP06_Isotropic_EA.mq5             |
//|                                Cuancux Algo Traders / Paulus     |
//|                        Smart Trader Episode 06: Isotropic Trend  |
//+------------------------------------------------------------------+
#property copyright   "Cuancux Algo Traders"
#property version     "1.00"
#property strict

//--- Input: Calculation
input group "=== CALCULATION ==="
input int      Trend_Period       = 13;       // Trend Block Period (5-100)
input int      Trend_Groups      = 5;        // Trend Block Groups (3-5)
input double   Range_Threshold   = 0.5;      // Range Threshold (°, 0.0-45.0)
input int      Sigma_Length      = 20;       // Yang-Zhang Sigma Length (5-100)
input string   Calculation_Bar   = "Live Bar"; // Calculation Bar (Live Bar/Close Bar)

//--- Input: Channel Lines
input group "=== CHANNEL LINES ==="
input color    Up_Color          = clrTeal;   // Up Color
input color    Down_Color        = clrCrimson; // Down Color
input color    Range_Color       = clrGray;   // Range Color
input int      Line_Width        = 2;        // Line Width (1-5)
input string   Line_Style        = "Solid";  // Line Style (Solid/Dashed/Dotted)

//--- Input: Projection Lines
input group "=== PROJECTION LINES ==="
input int      Projection_Offset = 7;        // Projection Offset (1-100)
input int      Projection_Width  = 2;        // Projection Width (1-5)
input string   Projection_Style  = "Dotted"; // Projection Style (Solid/Dashed/Dotted)

//--- Input: Channel Fill
input group "=== CHANNEL FILL ==="
input color    Fill_Up_Color     = clrTeal;   // Fill Up Color
input color    Fill_Down_Color   = clrCrimson; // Fill Down Color
input color    Fill_Range_Color  = clrGray;   // Fill Range Color
input int      Fill_Transparency = 85;       // Fill Transparency (0-100)

//--- Input: Trade Management
input group "=== TRADE MANAGEMENT ==="
input double   FixedLotSize      = 0.1;      // Fixed Lot (0 = risk-based)
input double   RiskPercent       = 2.0;      // Risk % if FixedLot=0
input int      MaxOpenPositions  = 1;        // Max Positions
input int      ExpirationMinutes = 240;      // Pending Order Expiry (0=no expiry)

//--- Input: Session Filter
input group "=== SESSION FILTER ==="
input int      SignalStartHour   = 8;        // Allow entries from this hour
input int      SignalStartMinute = 30;
input int      SignalEndHour     = 19;       // Stop entries after this hour
input int      SignalEndMinute   = 0;

//--- Globals
#define PREFIX "STEP06_"
int    g_anchor = 0; // 0=Live Bar, 1=Close Bar
int    g_trendDir = 0; // 1=Up, -1=Down, 0=Flat
double g_sigma = 0;
double g_chUpper = 0, g_chLower = 0;

//+------------------------------------------------------------------+
//| Yang-Zhang Volatility Estimator                                  |
//+------------------------------------------------------------------+
double YangZhangSigma(int length)
{
   double k = 0.34 / (1.34 + (length + 1) / (length - 1));
   double overnight = 0, intraday = 0, rs = 0;

   for(int i = 1; i <= length; i++)
   {
      double oc = MathLog(iOpen(_Symbol, PERIOD_CURRENT, i) / iClose(_Symbol, PERIOD_CURRENT, i + 1));
      double co = MathLog(iClose(_Symbol, PERIOD_CURRENT, i) / iOpen(_Symbol, PERIOD_CURRENT, i));
      double rs_val = MathLog(iHigh(_Symbol, PERIOD_CURRENT, i) / iClose(_Symbol, PERIOD_CURRENT, i)) *
                     MathLog(iHigh(_Symbol, PERIOD_CURRENT, i) / iOpen(_Symbol, PERIOD_CURRENT, i)) +
                     MathLog(iLow(_Symbol, PERIOD_CURRENT, i) / iClose(_Symbol, PERIOD_CURRENT, i)) *
                     MathLog(iLow(_Symbol, PERIOD_CURRENT, i) / iOpen(_Symbol, PERIOD_CURRENT, i));

      overnight += oc * oc;
      intraday += co * co;
      rs += rs_val;
   }

   overnight = overnight / (length - 1);
   intraday = intraday / length;
   rs = rs / length;

   return MathSqrt(overnight + k * intraday + (1 - k) * rs);
}

//+------------------------------------------------------------------+
//| Geometric Mean of Block                                          |
//+------------------------------------------------------------------+
double BlockGeometricMean(int start, int period)
{
   double sum = 0;
   for(int i = 0; i < period; i++)
   {
      double high = iHigh(_Symbol, PERIOD_CURRENT, start + i);
      double low = iLow(_Symbol, PERIOD_CURRENT, start + i);
      sum += MathLog((high + low) / 2);
   }
   return MathExp(sum / period);
}

//+------------------------------------------------------------------+
//| Find Longest Monotonic Segment                                   |
//+------------------------------------------------------------------+
void FindMonotonicSegment(int groups, int period, int &dir, int &segEnd)
{
   dir = 0;
   segEnd = 0;
   int maxLen = 0;

   for(int i = 0; i < groups - 1; i++)
   {
      double gm1 = BlockGeometricMean(g_anchor + i * period, period);
      double gm2 = BlockGeometricMean(g_anchor + (i + 1) * period, period);
      int currentDir = (gm2 > gm1) ? 1 : (gm2 < gm1) ? -1 : 0;
      int len = 1;

      for(int j = i + 1; j < groups - 1; j++)
      {
         double gm3 = BlockGeometricMean(g_anchor + (j + 1) * period, period);
         int nextDir = (gm3 > BlockGeometricMean(g_anchor + j * period, period)) ? 1 : (gm3 < BlockGeometricMean(g_anchor + j * period, period)) ? -1 : 0;

         if(nextDir == currentDir && currentDir != 0)
            len++;
         else
            break;
      }

      if(len > maxLen)
      {
         maxLen = len;
         dir = currentDir;
         segEnd = i + len;
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate ICS Angle                                              |
//+------------------------------------------------------------------+
double CalculateICSAngle(int groups, int period, int dir)
{
   if(dir == 0) return 0.0;

   double gmStart = BlockGeometricMean(g_anchor, period);
   double gmEnd = BlockGeometricMean(g_anchor + (groups - 1) * period, period);
   double slope = (MathLog(gmEnd) - MathLog(gmStart)) / ((groups - 1) * period);
   double normalizedSlope = slope / (g_sigma + 1e-10);
   return MathArctan(normalizedSlope) * 180 / M_PI;
}

//+------------------------------------------------------------------+
//| Fit Channel Boundaries                                           |
//+------------------------------------------------------------------+
void FitChannel(int groups, int period, double &upper, double &lower)
{
   double high1 = 0, high2 = 0, low1 = 0, low2 = 0;
   int idx1 = 0, idx2 = 0;

   for(int i = 0; i < groups; i++)
   {
      for(int j = 0; j < period; j++)
      {
         double h = iHigh(_Symbol, PERIOD_CURRENT, g_anchor + i * period + j);
         double l = iLow(_Symbol, PERIOD_CURRENT, g_anchor + i * period + j);

         if(h > high1 || i == 0)
         {
            high2 = high1;
            high1 = h;
            idx2 = idx1;
            idx1 = i * period + j;
         }
         else if(h > high2)
         {
            high2 = h;
            idx2 = i * period + j;
         }

         if(l < low1 || i == 0)
         {
            low2 = low1;
            low1 = l;
            idx2 = idx1;
            idx1 = i * period + j;
         }
         else if(l < low2)
         {
            low2 = l;
            idx2 = i * period + j;
         }
      }
   }

   // Linear interpolation for channel boundaries
   double time1 = iTime(_Symbol, PERIOD_CURRENT, g_anchor + idx1);
   double time2 = iTime(_Symbol, PERIOD_CURRENT, g_anchor + idx2);
   double price1 = (high1 > high2) ? high1 : low1;
   double price2 = (high1 > high2) ? high2 : low2;

   double slope = (price2 - price1) / (time2 - time1);
   upper = price1 + slope * (iTime(_Symbol, PERIOD_CURRENT, 0) - time1);
   lower = (low1 < low2) ? low1 + slope * (iTime(_Symbol, PERIOD_CURRENT, 0) - time1) : high1 + slope * (iTime(_Symbol, PERIOD_CURRENT, 0) - time1);
}

//+------------------------------------------------------------------+
//| Check if within signal window                                    |
//+------------------------------------------------------------------+
bool IsWithinSignalWindow()
{
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   int curMin = tm.hour * 60 + tm.min;
   int startMin = SignalStartHour * 60 + SignalStartMinute;
   int endMin = SignalEndHour * 60 + SignalEndMinute;

   if(endMin > startMin)
      return (curMin >= startMin && curMin <= endMin);
   else
      return (curMin >= startMin || curMin <= endMin);
}

//+------------------------------------------------------------------+
//| Normalize lot size                                               |
//+------------------------------------------------------------------+
double NormalizeLot(double lot)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double norm = MathRound(lot / step) * step;
   return MathMax(minLot, MathMin(maxLot, norm));
}

//+------------------------------------------------------------------+
//| Calculate risk-based lot                                         |
//+------------------------------------------------------------------+
double CalcRiskLot(double slDistance)
{
   if(slDistance <= 0) return NormalizeLot(FixedLotSize > 0 ? FixedLotSize : 0.01);

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk = balance * (RiskPercent / 100.0);
   double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSz = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double slTicks = slDistance / tickSz;

   double lot = risk / (slTicks * tickVal);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(lot < minLot) lot = minLot;

   return NormalizeLot(lot);
}

//+------------------------------------------------------------------+
//| Count open positions                                             |
//+------------------------------------------------------------------+
int CountPositions()
{
   int cnt = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_UNKNOWN)
         cnt++;
   }
   return cnt;
}

//+------------------------------------------------------------------+
//| Draw Channel                                                     |
//+------------------------------------------------------------------+
void DrawChannel()
{
   string upperName = PREFIX + "Upper";
   string lowerName = PREFIX + "Lower";
   string fillName = PREFIX + "Fill";
   color chColor = g_trendDir > 0 ? Up_Color : g_trendDir < 0 ? Down_Color : Range_Color;
   color fillColor = g_trendDir > 0 ? Fill_Up_Color : g_trendDir < 0 ? Fill_Down_Color : Fill_Range_Color;

   // Upper Channel Line
   ObjectCreate(0, upperName, OBJ_TREND, 0, iTime(_Symbol, PERIOD_CURRENT, g_anchor), g_chUpper);
   ObjectSetDouble(0, upperName, OBJPROP_PRICE, 0, g_chUpper);
   ObjectSetInteger(0, upperName, OBJPROP_COLOR, chColor);
   ObjectSetInteger(0, upperName, OBJPROP_WIDTH, Line_Width);
   ObjectSetInteger(0, upperName, OBJPROP_STYLE, Line_Style == "Solid" ? STYLE_SOLID : Line_Style == "Dashed" ? STYLE_DASH : STYLE_DOT);

   // Lower Channel Line
   ObjectCreate(0, lowerName, OBJ_TREND, 0, iTime(_Symbol, PERIOD_CURRENT, g_anchor), g_chLower);
   ObjectSetDouble(0, lowerName, OBJPROP_PRICE, 0, g_chLower);
   ObjectSetInteger(0, lowerName, OBJPROP_COLOR, chColor);
   ObjectSetInteger(0, lowerName, OBJPROP_WIDTH, Line_Width);
   ObjectSetInteger(0, lowerName, OBJPROP_STYLE, Line_Style == "Solid" ? STYLE_SOLID : Line_Style == "Dashed" ? STYLE_DASH : STYLE_DOT);

   // Projection Lines
   string projUpperName = PREFIX + "ProjUpper";
   string projLowerName = PREFIX + "ProjLower";
   datetime projTime = iTime(_Symbol, PERIOD_CURRENT, 0) + Projection_Offset * PeriodSeconds() * 60;

   ObjectCreate(0, projUpperName, OBJ_TREND, 0, iTime(_Symbol, PERIOD_CURRENT, 0), g_chUpper);
   ObjectSetDouble(0, projUpperName, OBJPROP_PRICE, 1, g_chUpper);
   ObjectSetInteger(0, projUpperName, OBJPROP_TIME, 1, projTime);
   ObjectSetInteger(0, projUpperName, OBJPROP_COLOR, chColor);
   ObjectSetInteger(0, projUpperName, OBJPROP_WIDTH, Projection_Width);
   ObjectSetInteger(0, projUpperName, OBJPROP_STYLE, Projection_Style == "Solid" ? STYLE_SOLID : Projection_Style == "Dashed" ? STYLE_DASH : STYLE_DOT);

   ObjectCreate(0, projLowerName, OBJ_TREND, 0, iTime(_Symbol, PERIOD_CURRENT, 0), g_chLower);
   ObjectSetDouble(0, projLowerName, OBJPROP_PRICE, 1, g_chLower);
   ObjectSetInteger(0, projLowerName, OBJPROP_TIME, 1, projTime);
   ObjectSetInteger(0, projLowerName, OBJPROP_COLOR, chColor);
   ObjectSetInteger(0, projLowerName, OBJPROP_WIDTH, Projection_Width);
   ObjectSetInteger(0, projLowerName, OBJPROP_STYLE, Projection_Style == "Solid" ? STYLE_SOLID : Projection_Style == "Dashed" ? STYLE_DASH : STYLE_DOT);

   // Channel Fill
   ObjectCreate(0, fillName, OBJ_RECTANGLE, 0, iTime(_Symbol, PERIOD_CURRENT, g_anchor), g_chUpper);
   ObjectSetInteger(0, fillName, OBJPROP_TIME, 1, projTime);
   ObjectSetDouble(0, fillName, OBJPROP_PRICE, 0, g_chUpper);
   ObjectSetDouble(0, fillName, OBJPROP_PRICE, 1, g_chLower);
   ObjectSetInteger(0, fillName, OBJPROP_COLOR, ColorToARGB(fillColor, Fill_Transparency));
   ObjectSetInteger(0, fillName, OBJPROP_FILL, true);
   ObjectSetInteger(0, fillName, OBJPROP_BACK, true);
}

//+------------------------------------------------------------------+
//| Draw Dashboard                                                   |
//+------------------------------------------------------------------+
void DrawDashboard()
{
   string dashName = PREFIX + "Dashboard";
   string trendText = g_trendDir > 0 ? "UP" : g_trendDir < 0 ? "DOWN" : "RANGE";
   color trendColor = g_trendDir > 0 ? Up_Color : g_trendDir < 0 ? Down_Color : Range_Color;

   ObjectCreate(0, dashName, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, dashName, OBJPROP_TEXT,
      "=== Smart Trader EP06 ===\n" +
      "Trend: " + trendText + "\n" +
      "Sigma: " + DoubleToString(g_sigma, 4) + "\n" +
      "Upper: " + DoubleToString(g_chUpper, _Digits) + "\n" +
      "Lower: " + DoubleToString(g_chLower, _Digits));
   ObjectSetInteger(0, dashName, OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, dashName, OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, dashName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, dashName, OBJPROP_BGCOLOR, clrBlack);
}

//+------------------------------------------------------------------+
//| Clean up objects                                                 |
//+------------------------------------------------------------------+
void CleanUpObjects()
{
   ObjectsDeleteAll(0, PREFIX);
}

//+------------------------------------------------------------------+
//| Check for valid signal candle                                     |
//+------------------------------------------------------------------+
bool IsValidSignalCandle()
{
   double body = MathAbs(iClose(_Symbol, PERIOD_CURRENT, 0) - iOpen(_Symbol, PERIOD_CURRENT, 0));
   double range = iHigh(_Symbol, PERIOD_CURRENT, 0) - iLow(_Symbol, PERIOD_CURRENT, 0);
   if(range == 0) return false;
   return (body / range) > 0.3; // Body > 30% of range
}

//+------------------------------------------------------------------+
//| Execute trade                                                    |
//+------------------------------------------------------------------+
void ExecuteTrade()
{
   if(!IsWithinSignalWindow()) return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double lot = FixedLotSize > 0 ? NormalizeLot(FixedLotSize) : CalcRiskLot(MathAbs(g_chUpper - g_chLower));

   //--- BUY Signal (Breakout above upper channel)
   if(g_trendDir == 1 && ask > g_chUpper)
   {
      double sl = bid - MathAbs(g_chUpper - g_chLower) * 0.5;
      double tp = ask + MathAbs(g_chUpper - g_chLower) * 1.5;
      if(CountPositions() < MaxOpenPositions)
         trade.Buy(lot, _Symbol, ask, sl, tp, "STEP06 BUY");
   }

   //--- SELL Signal (Breakout below lower channel)
   else if(g_trendDir == -1 && bid < g_chLower)
   {
      double sl = ask + MathAbs(g_chUpper - g_chLower) * 0.5;
      double tp = bid - MathAbs(g_chUpper - g_chLower) * 1.5;
      if(CountPositions() < MaxOpenPositions)
         trade.Sell(lot, _Symbol, bid, sl, tp, "STEP06 SELL");
   }
}

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   g_anchor = Calculation_Bar == "Live Bar" ? 0 : 1;
   CleanUpObjects();
   Print("=== SmartTrader EP06 Isotropic EA initialized ===");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   CleanUpObjects();
   Comment("");
}

//+------------------------------------------------------------------+
//| Expert tick                                                       |
//+------------------------------------------------------------------+
void OnTick()
{
   static datetime lastCandleTime = 0;
   static bool alreadyTraded = false;

   //--- Update Sigma
   g_sigma = YangZhangSigma(Sigma_Length);

   //--- Find Trend Direction and Channel
   int dir = 0, segEnd = 0;
   FindMonotonicSegment(Trend_Groups, Trend_Period, dir, segEnd);
   g_trendDir = (MathAbs(CalculateICSAngle(Trend_Groups, Trend_Period, dir)) > Range_Threshold) ? dir : 0;

   FitChannel(Trend_Groups, Trend_Period, g_chUpper, g_chLower);

   //--- Draw Visuals
   DrawChannel();
   DrawDashboard();

   //--- Check New Candle
   datetime candleTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   bool newCandle = (candleTime != lastCandleTime);
   if(newCandle) lastCandleTime = candleTime;

   //--- Trade on New Candle
   if(newCandle && !alreadyTraded && IsValidSignalCandle())
   {
      ExecuteTrade();
      alreadyTraded = true;
   }

   //--- Reset Trade Flag Outside Window
   if(!IsWithinSignalWindow())
      alreadyTraded = false;
}
//+------------------------------------------------------------------+