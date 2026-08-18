//+------------------------------------------------------------------+
//|                     TraderNakal_Institutional_SMC_EA.mq5        |
//|                                Cuancux Algo Traders / Paulus     |
//|                        Trader Nakal Institutional SMC PRO        |
//+------------------------------------------------------------------+
#property copyright   "Cuancux Algo Traders"
#property version     "1.00"
#property strict

//--- Input: Dynamic Trend Wave
input group "=== DYNAMIC TREND WAVE ==="
input bool     Show_Wave          = true;      // Show Trend Wave Line
input int      Wave_Period        = 21;        // Wave Period (ALMA)
input int      Wave_Width         = 2;         // Wave Line Thickness
input color    Bull_Wave_Color    = clrLime;   // Bullish Wave Color
input color    Bear_Wave_Color    = clrRed;    // Bearish Wave Color
input int      Fill_Opacity       = 90;        // Background Fill Opacity (0-100)

//--- Input: Smart Candle Coloring
input group "=== SMART CANDLE COLORING ==="
input bool     Show_Candles       = true;      // Enable Smart Candle Coloring
input color    Bull_Candle_Color  = clrGreen;   // Bullish Candle Color
input color    Bear_Candle_Color  = clrMaroon;  // Bearish Candle Color
input color    Inside_Candle_Color= clrGray;   // Consolidation Candle Color

//--- Input: Market Structure (BOS & CHoCH)
input group "=== MARKET STRUCTURE (BOS & CHoCH) ==="
input bool     Show_SMC           = true;      // Show BOS & CHoCH Shifts
input int      SMC_Sensitivity    = 7;         // Structure Sensitivity
input color    BOS_Color          = clrDodgerBlue; // BOS Color
input color    CHoCH_Color        = clrPurple;  // CHoCH Color
input string   SMC_Text_Size      = "small";  // Structure Label Size (tiny/small/normal)

//--- Input: Major Swing Signals (BUY/SELL)
input group "=== MAJOR SWING SIGNALS ==="
input bool     Show_Signals       = true;      // Show Confirmed BUY/SELL Badges
input int      Signal_Sensitivity = 10;        // Signal Swing Sensitivity
input color    Buy_Badge_Color    = clrGreen;   // BUY Badge Fill
input color    Buy_Text_Color     = clrWhite;   // BUY Badge Text Color
input color    Sell_Badge_Color   = clrMaroon;  // SELL Badge Fill
input color    Sell_Text_Color    = clrWhite;   // SELL Badge Text Color

//--- Input: Standard Deviation Target
input group "=== STANDARD DEVIATION TARGET ==="
input bool     Show_SD_Target     = true;      // Show -2.5 SD Next Target Line
input int      SD_Period          = 20;        // SD Calculation Period
input color    SD_Line_Color      = clrOrange;  // -2.5 SD Line Color
input string   SD_Line_Style      = "Dashed"; // SD Line Style (Solid/Dashed/Dotted)
input int      SD_Line_Width      = 2;         // SD Line Thickness

//--- Input: Trade Management
input group "=== TRADE MANAGEMENT ==="
input double   FixedLotSize       = 0.1;      // Fixed Lot (0 = risk-based)
input double   RiskPercent        = 2.0;      // Risk % if FixedLot=0
input int      MaxOpenPositions   = 1;        // Max Positions
input int      ExpirationMinutes  = 240;      // Pending Order Expiry (0=no expiry)

//--- Input: Session Filter
input group "=== SESSION FILTER ==="
input int      SignalStartHour    = 8;        // Allow entries from this hour
input int      SignalStartMinute  = 30;
input int      SignalEndHour      = 19;       // Stop entries after this hour
input int      SignalEndMinute    = 0;

//--- Globals
#define PREFIX "TNSMC_"
int    g_trendDir = 0; // 1=Up, -1=Down, 0=Flat
double g_waveValue = 0;
double g_sdTarget = 0;

//+------------------------------------------------------------------+
//| ALMA (Arnaud Legoux Moving Average)                              |
//+------------------------------------------------------------------+
double ALMA(int period, double offset, double sigma)
{
   double alma = 0, sum = 0, weight = 0;
   double m = offset * (period - 1);
   double s = period / sigma;

   for(int i = 0; i < period; i++)
   {
      double w = MathExp(-((i - m) * (i - m)) / (2 * s * s));
      alma += iClose(_Symbol, PERIOD_CURRENT, i) * w;
      sum += w;
   }
   return alma / sum;
}

//+------------------------------------------------------------------+
//| Check if candle is inside bar                                    |
//+------------------------------------------------------------------+
bool IsInsideBar(int shift)
{
   return (iHigh(_Symbol, PERIOD_CURRENT, shift) <= iHigh(_Symbol, PERIOD_CURRENT, shift + 1) &&
           iLow(_Symbol, PERIOD_CURRENT, shift) >= iLow(_Symbol, PERIOD_CURRENT, shift + 1));
}

//+------------------------------------------------------------------+
//| Pivot High Detection                                             |
//+------------------------------------------------------------------+
double PivotHigh(int sensitivity, int shift)
{
   for(int i = 1; i <= sensitivity; i++)
   {
      if(iHigh(_Symbol, PERIOD_CURRENT, shift) < iHigh(_Symbol, PERIOD_CURRENT, shift + i) ||
         iHigh(_Symbol, PERIOD_CURRENT, shift) < iHigh(_Symbol, PERIOD_CURRENT, shift - i))
         return 0;
   }
   return iHigh(_Symbol, PERIOD_CURRENT, shift);
}

//+------------------------------------------------------------------+
//| Pivot Low Detection                                              |
//+------------------------------------------------------------------+
double PivotLow(int sensitivity, int shift)
{
   for(int i = 1; i <= sensitivity; i++)
   {
      if(iLow(_Symbol, PERIOD_CURRENT, shift) > iLow(_Symbol, PERIOD_CURRENT, shift + i) ||
         iLow(_Symbol, PERIOD_CURRENT, shift) > iLow(_Symbol, PERIOD_CURRENT, shift - i))
         return 0;
   }
   return iLow(_Symbol, PERIOD_CURRENT, shift);
}

//+------------------------------------------------------------------+
//| Draw Trend Wave                                                  |
//+------------------------------------------------------------------+
void DrawTrendWave()
{
   g_waveValue = ALMA(Wave_Period, 0.85, 6);
   bool isUptrend = iClose(_Symbol, PERIOD_CURRENT, 0) >= g_waveValue;
   color waveColor = isUptrend ? Bull_Wave_Color : Bear_Wave_Color;

   string waveName = PREFIX + "Wave";
   ObjectCreate(0, waveName, OBJ_TREND, 0, iTime(_Symbol, PERIOD_CURRENT, Wave_Period), g_waveValue);
   ObjectSetDouble(0, waveName, OBJPROP_PRICE, 0, g_waveValue);
   ObjectSetInteger(0, waveName, OBJPROP_COLOR, waveColor);
   ObjectSetInteger(0, waveName, OBJPROP_WIDTH, Wave_Width);

   // Fill
   string fillName = PREFIX + "WaveFill";
   ObjectCreate(0, fillName, OBJ_RECTANGLE_LABEL, 0, iTime(_Symbol, PERIOD_CURRENT, 0), iHigh(_Symbol, PERIOD_CURRENT, 0));
   ObjectSetInteger(0, fillName, OBJPROP_XDISTANCE, 0);
   ObjectSetInteger(0, fillName, OBJPROP_YDISTANCE, 0);
   ObjectSetInteger(0, fillName, OBJPROP_XSIZE, 200);
   ObjectSetInteger(0, fillName, OBJPROP_YSIZE, 200);
   ObjectSetInteger(0, fillName, OBJPROP_BGCOLOR, ColorToARGB(waveColor, Fill_Opacity));
   ObjectSetInteger(0, fillName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
}

//+------------------------------------------------------------------+
//| Draw Smart Candles                                               |
//+------------------------------------------------------------------+
void DrawSmartCandles()
{
   for(int i = 0; i < 50; i++)
   {
      string candleName = PREFIX + "Candle_" + IntegerToString(i);
      bool isInside = IsInsideBar(i);
      bool wasInside = IsInsideBar(i + 1);
      color candleColor = (isInside || wasInside) ? Inside_Candle_Color :
                        (iClose(_Symbol, PERIOD_CURRENT, i) >= iOpen(_Symbol, PERIOD_CURRENT, i)) ? Bull_Candle_Color : Bear_Candle_Color;

      ObjectCreate(0, candleName, OBJ_RECTANGLE, 0, iTime(_Symbol, PERIOD_CURRENT, i), iOpen(_Symbol, PERIOD_CURRENT, i));
      ObjectSetInteger(0, candleName, OBJPROP_TIME, 1, iTime(_Symbol, PERIOD_CURRENT, i + 1));
      ObjectSetDouble(0, candleName, OBJPROP_PRICE, 0, iClose(_Symbol, PERIOD_CURRENT, i));
      ObjectSetDouble(0, candleName, OBJPROP_PRICE, 1, iClose(_Symbol, PERIOD_CURRENT, i));
      ObjectSetInteger(0, candleName, OBJPROP_COLOR, candleColor);
      ObjectSetInteger(0, candleName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, candleName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, candleName, OBJPROP_FILL, true);
      ObjectSetInteger(0, candleName, OBJPROP_BACK, true);
   }
}

//+------------------------------------------------------------------+
//| Draw Market Structure (BOS & CHoCH)                              |
//+------------------------------------------------------------------+
void DrawMarketStructure()
{
   static double lastPH = 0, lastPL = 0;
   double ph = PivotHigh(SMC_Sensitivity, SMC_Sensitivity);
   double pl = PivotLow(SMC_Sensitivity, SMC_Sensitivity);

   if(ph > 0) lastPH = ph;
   if(pl > 0) lastPL = pl;

   if(Show_SMC && lastPH > 0 && iClose(_Symbol, PERIOD_CURRENT, 0) > lastPH)
   {
      string bosName = PREFIX + "BOS_" + IntegerToString(iBars(_Symbol, PERIOD_CURRENT));
      ObjectCreate(0, bosName, OBJ_TREND, 0, iTime(_Symbol, PERIOD_CURRENT, 5), lastPH);
      ObjectSetDouble(0, bosName, OBJPROP_PRICE, 0, lastPH);
      ObjectSetInteger(0, bosName, OBJPROP_COLOR, g_trendDir == -1 ? CHoCH_Color : BOS_Color);
      ObjectSetInteger(0, bosName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, bosName, OBJPROP_WIDTH, 1);

      string lblName = PREFIX + "BOSLbl_" + IntegerToString(iBars(_Symbol, PERIOD_CURRENT));
      ObjectCreate(0, lblName, OBJ_LABEL, 0, iTime(_Symbol, PERIOD_CURRENT, 0), lastPH);
      ObjectSetString(0, lblName, OBJPROP_TEXT, g_trendDir == -1 ? "CHoCH" : "BOS");
      ObjectSetInteger(0, lblName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, lblName, OBJPROP_BGCOLOR, g_trendDir == -1 ? CHoCH_Color : BOS_Color);
      ObjectSetInteger(0, lblName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      g_trendDir = 1;
      lastPH = 0;
   }

   if(Show_SMC && lastPL > 0 && iClose(_Symbol, PERIOD_CURRENT, 0) < lastPL)
   {
      string bosName = PREFIX + "BOS_" + IntegerToString(iBars(_Symbol, PERIOD_CURRENT));
      ObjectCreate(0, bosName, OBJ_TREND, 0, iTime(_Symbol, PERIOD_CURRENT, 5), lastPL);
      ObjectSetDouble(0, bosName, OBJPROP_PRICE, 0, lastPL);
      ObjectSetInteger(0, bosName, OBJPROP_COLOR, g_trendDir == 1 ? CHoCH_Color : BOS_Color);
      ObjectSetInteger(0, bosName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, bosName, OBJPROP_WIDTH, 1);

      string lblName = PREFIX + "BOSLbl_" + IntegerToString(iBars(_Symbol, PERIOD_CURRENT));
      ObjectCreate(0, lblName, OBJ_LABEL, 0, iTime(_Symbol, PERIOD_CURRENT, 0), lastPL);
      ObjectSetString(0, lblName, OBJPROP_TEXT, g_trendDir == 1 ? "CHoCH" : "BOS");
      ObjectSetInteger(0, lblName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, lblName, OBJPROP_BGCOLOR, g_trendDir == 1 ? CHoCH_Color : BOS_Color);
      ObjectSetInteger(0, lblName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      g_trendDir = -1;
      lastPL = 0;
   }
}

//+------------------------------------------------------------------+
//| Draw Major Swing Signals                                         |
//+------------------------------------------------------------------+
void DrawMajorSignals()
{
   double ph = PivotHigh(Signal_Sensitivity, Signal_Sensitivity);
   double pl = PivotLow(Signal_Sensitivity, Signal_Sensitivity);
   double atr = iATR(_Symbol, PERIOD_CURRENT, 14);

   if(Show_Signals && ph > 0)
   {
      string sellName = PREFIX + "Sell_" + IntegerToString(iBars(_Symbol, PERIOD_CURRENT));
      ObjectCreate(0, sellName, OBJ_LABEL, 0, iTime(_Symbol, PERIOD_CURRENT, Signal_Sensitivity), ph + atr * 0.3);
      ObjectSetString(0, sellName, OBJPROP_TEXT, "SELL");
      ObjectSetInteger(0, sellName, OBJPROP_COLOR, Sell_Text_Color);
      ObjectSetInteger(0, sellName, OBJPROP_BGCOLOR, Sell_Badge_Color);
      ObjectSetInteger(0, sellName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   }

   if(Show_Signals && pl > 0)
   {
      string buyName = PREFIX + "Buy_" + IntegerToString(iBars(_Symbol, PERIOD_CURRENT));
      ObjectCreate(0, buyName, OBJ_LABEL, 0, iTime(_Symbol, PERIOD_CURRENT, Signal_Sensitivity), pl - atr * 0.3);
      ObjectSetString(0, buyName, OBJPROP_TEXT, "BUY");
      ObjectSetInteger(0, buyName, OBJPROP_COLOR, Buy_Text_Color);
      ObjectSetInteger(0, buyName, OBJPROP_BGCOLOR, Buy_Badge_Color);
      ObjectSetInteger(0, buyName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   }
}

//+------------------------------------------------------------------+
//| Draw Standard Deviation Target                                   |
//+------------------------------------------------------------------+
void DrawSDTarget()
{
   double sum = 0, mean = 0, sd = 0;
   for(int i = 0; i < SD_Period; i++)
   {
      sum += iClose(_Symbol, PERIOD_CURRENT, i);
   }
   mean = sum / SD_Period;

   double sumSq = 0;
   for(int i = 0; i < SD_Period; i++)
   {
      sumSq += MathPow(iClose(_Symbol, PERIOD_CURRENT, i) - mean, 2);
   }
   sd = MathSqrt(sumSq / SD_Period);
   g_sdTarget = mean - (sd * 2.5);

   string sdName = PREFIX + "SDTarget";
   ObjectCreate(0, sdName, OBJ_HLINE, 0, 0, g_sdTarget);
   ObjectSetInteger(0, sdName, OBJPROP_COLOR, SD_Line_Color);
   ObjectSetInteger(0, sdName, OBJPROP_STYLE, SD_Line_Style == "Solid" ? STYLE_SOLID : SD_Line_Style == "Dashed" ? STYLE_DASH : STYLE_DOT);
   ObjectSetInteger(0, sdName, OBJPROP_WIDTH, SD_Line_Width);

   string lblName = PREFIX + "SDLabel";
   ObjectCreate(0, lblName, OBJ_LABEL, 0, iTime(_Symbol, PERIOD_CURRENT, 0), g_sdTarget);
   ObjectSetString(0, lblName, OBJPROP_TEXT, "Next -2.5 SD Target");
   ObjectSetInteger(0, lblName, OBJPROP_COLOR, SD_Line_Color);
   ObjectSetInteger(0, lblName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
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
//| Execute trade                                                    |
//+------------------------------------------------------------------+
void ExecuteTrade()
{
   if(!IsWithinSignalWindow()) return;

   double atr = iATR(_Symbol, PERIOD_CURRENT, 14);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double lot = FixedLotSize > 0 ? NormalizeLot(FixedLotSize) : CalcRiskLot(atr * 2);

   //--- BUY Signal (Pivot Low + Trend Up)
   if(Show_Signals && g_trendDir == 1 && PivotLow(Signal_Sensitivity, Signal_Sensitivity) > 0)
   {
      double sl = bid - atr * 2;
      double tp = bid + atr * 3;
      if(CountPositions() < MaxOpenPositions)
         trade.Buy(lot, _Symbol, ask, sl, tp, "SMC BUY");
   }

   //--- SELL Signal (Pivot High + Trend Down)
   if(Show_Signals && g_trendDir == -1 && PivotHigh(Signal_Sensitivity, Signal_Sensitivity) > 0)
   {
      double sl = ask + atr * 2;
      double tp = ask - atr * 3;
      if(CountPositions() < MaxOpenPositions)
         trade.Sell(lot, _Symbol, bid, sl, tp, "SMC SELL");
   }
}

//+------------------------------------------------------------------+
//| Clean up objects                                                 |
//+------------------------------------------------------------------+
void CleanUpObjects()
{
   ObjectsDeleteAll(0, PREFIX);
}

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   CleanUpObjects();
   Print("=== TraderNakal Institutional SMC EA initialized ===");
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

   //--- Check New Candle
   datetime candleTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   bool newCandle = (candleTime != lastCandleTime);
   if(newCandle) lastCandleTime = candleTime;

   //--- Draw Visuals
   if(Show_Wave) DrawTrendWave();
   if(Show_Candles) DrawSmartCandles();
   if(Show_SMC) DrawMarketStructure();
   if(Show_Signals) DrawMajorSignals();
   if(Show_SD_Target) DrawSDTarget();

   //--- Trade on New Candle
   if(newCandle && !alreadyTraded)
   {
      ExecuteTrade();
      alreadyTraded = true;
   }

   //--- Reset Trade Flag Outside Window
   if(!IsWithinSignalWindow())
      alreadyTraded = false;
}
//+------------------------------------------------------------------+