//+------------------------------------------------------------------+
//|                                      TraderNakal_Trend_EA.mq5 |
//|                                Cuancux Algo Traders / Paulus     |
//|                                              Trader Nakal Trend |
//+------------------------------------------------------------------+
#property copyright   "Cuancux Algo Traders"
#property version     "1.00"
#property strict

//--- Input: Rope Smoother
input group "=== Rope Smoother ==="
input int      Rope_ATR_Len       = 14;       // ATR Length
input double  Rope_Multiplier    = 1.5;      // ATR Multiplier
input int      Rope_Source       = PRICE_CLOSE; // Source (0=Close, 1=Open, etc.)

//--- Input: ATR Exit
input group "=== ATR Exit ==="
input int      ATR_Period         = 14;       // ATR Period
input double  ATR_Mult_TP        = 2.0;      // TP Multiplier
input double  ATR_Mult_SL        = 1.5;      // SL Multiplier

//--- Input: ZigZag Breakout
input group "=== ZigZag Breakout ==="
input int      ZigZag_Len         = 9;        // ZigZag Length
input double  Fib_Factor         = 0.33;     // Fib Factor for Breakout

//--- Input: Trade Management
input group "=== Trade Management ==="
input double  FixedLotSize       = 0.1;      // Fixed Lot (0 = risk-based)
input double  RiskPercent        = 2.0;      // Risk % if FixedLot=0
input int      MaxOpenPositions   = 1;        // Max Positions
input int      ExpirationMinutes  = 240;      // Pending Order Expiry (0=no expiry)

//--- Input: Session Filter
input group "=== Session Filter ==="
input int      SignalStartHour    = 8;        // Allow entries from this hour
input int      SignalStartMinute  = 30;
input int      SignalEndHour      = 19;       // Stop entries after this hour
input int      SignalEndMinute    = 0;

//--- Input: Broker Offset
input group "=== Broker Offset ==="
input int      BrokerOffsetMins   = 0;        // Broker offset from UTC (minutes)

//--- Globals
#define PREFIX "TNT_"
double g_atr;
double g_rope, g_upper, g_lower;
int    g_dir = 0; // 1=Up, -1=Down, 0=Flat

//+------------------------------------------------------------------+
//| Rope Smoother Function                                          |
//+------------------------------------------------------------------+
void RopeSmoother(double &rope[], double &upper[], double &lower[], int len, double multi, int srcType)
{
   double src[];
   ArraySetAsSeries(src, true);
   CopyClose(_Symbol, PERIOD_CURRENT, 0, len + 1, src);

   double atr = iATR(_Symbol, PERIOD_CURRENT, len);
   double threshold = atr * multi;

   for(int i = 0; i < ArraySize(src); i++)
   {
      double move = src[i] - rope[i];
      rope[i+1] = rope[i] + MathMax(MathAbs(move) - threshold, 0) * MathSign(move);
      upper[i+1] = rope[i+1] + threshold;
      lower[i+1] = rope[i+1] - threshold;
   }
}

//+------------------------------------------------------------------+
//| Update Rope Direction                                           |
//+------------------------------------------------------------------+
void UpdateDirection()
{
   if(g_rope > iClose(_Symbol, PERIOD_CURRENT, 1))
      g_dir = 1;
   else if(g_rope < iClose(_Symbol, PERIOD_CURRENT, 1))
      g_dir = -1;
   else
      g_dir = g_dir; // No change

   if(Crosses(g_rope, iClose(_Symbol, PERIOD_CURRENT, 0)))
      g_dir = 0;
}

//+------------------------------------------------------------------+
//| Check if two values cross                                        |
//+------------------------------------------------------------------+
bool Crosses(double val1, double val2)
{
   return (val1 > val2 && val1 <= val2 + _Point * 10) || (val1 < val2 && val1 >= val2 - _Point * 10);
}

//+------------------------------------------------------------------+
//| ZigZag Breakout Logic                                            |
//+------------------------------------------------------------------+
bool IsBreakout()
{
   static int trend = 1;
   static double lastHigh = 0, lastLow = 0;
   static int lastHighIdx = 0, lastLowIdx = 0;

   double high = iHigh(_Symbol, PERIOD_CURRENT, 0);
   double low = iLow(_Symbol, PERIOD_CURRENT, 0);

   bool toUp = high >= iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, ZigZag_Len, 1);
   bool toDown = low <= iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, ZigZag_Len, 1);

   if(trend == 1 && toDown)
   {
      trend = -1;
      lastLow = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, ZigZag_Len, 1);
      lastLowIdx = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, ZigZag_Len, 0);
   }
   else if(trend == -1 && toUp)
   {
      trend = 1;
      lastHigh = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, ZigZag_Len, 1);
      lastHighIdx = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, ZigZag_Len, 0);
   }

   if(trend == 1)
   {
      double fibLevel = lastLow + MathAbs(lastHigh - lastLow) * Fib_Factor;
      return (iClose(_Symbol, PERIOD_CURRENT, 0) > fibLevel && iHigh(_Symbol, PERIOD_CURRENT, 0) > fibLevel);
   }
   else if(trend == -1)
   {
      double fibLevel = lastHigh - MathAbs(lastHigh - lastLow) * Fib_Factor;
      return (iClose(_Symbol, PERIOD_CURRENT, 0) < fibLevel && iLow(_Symbol, PERIOD_CURRENT, 0) < fibLevel);
   }

   return false;
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
//| Count pending orders                                             |
//+------------------------------------------------------------------+
int CountPendingOrders()
{
   int cnt = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderGetString(ORDER_SYMBOL) == _Symbol)
         cnt++;
   }
   return cnt;
}

//+------------------------------------------------------------------+
//| Delete pending orders                                            |
//+------------------------------------------------------------------+
void DeletePendingOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(OrderGetString(ORDER_SYMBOL) == _Symbol)
         OrderDelete(ticket);
   }
}

//+------------------------------------------------------------------+
//| Draw Rope and Channels                                           |
//+------------------------------------------------------------------+
void DrawRope()
{
   string ropeName = PREFIX + "Rope";
   string upperName = PREFIX + "Upper";
   string lowerName = PREFIX + "Lower";

   ObjectCreate(0, ropeName, OBJ_TREND, 0, iTime(_Symbol, PERIOD_CURRENT, 1), g_rope);
   ObjectSetDouble(0, ropeName, OBJPROP_PRICE, 0, g_rope);
   ObjectSetInteger(0, ropeName, OBJPROP_COLOR, g_dir > 0 ? clrLime : g_dir < 0 ? clrRed : clrBlue);
   ObjectSetInteger(0, ropeName, OBJPROP_WIDTH, 3);

   ObjectCreate(0, upperName, OBJ_TREND, 0, iTime(_Symbol, PERIOD_CURRENT, 1), g_upper);
   ObjectSetDouble(0, upperName, OBJPROP_PRICE, 0, g_upper);
   ObjectSetInteger(0, upperName, OBJPROP_COLOR, clrGray);
   ObjectSetInteger(0, upperName, OBJPROP_WIDTH, 1);

   ObjectCreate(0, lowerName, OBJ_TREND, 0, iTime(_Symbol, PERIOD_CURRENT, 1), g_lower);
   ObjectSetDouble(0, lowerName, OBJPROP_PRICE, 0, g_lower);
   ObjectSetInteger(0, lowerName, OBJPROP_COLOR, clrGray);
   ObjectSetInteger(0, lowerName, OBJPROP_WIDTH, 1);
}

//+------------------------------------------------------------------+
//| Draw Dashboard                                                   |
//+------------------------------------------------------------------+
void DrawDashboard()
{
   string dashName = PREFIX + "Dashboard";
   string trendText = g_dir > 0 ? "UPTREND" : g_dir < 0 ? "DOWNTREND" : "SIDEWAYS";
   color trendColor = g_dir > 0 ? clrLime : g_dir < 0 ? clrRed : clrBlue;

   ObjectCreate(0, dashName, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, dashName, OBJPROP_TEXT,
      "=== Trader Nakal Trend EA ===\n" +
      "Rope: " + DoubleToString(g_rope, _Digits) + "\n" +
      "Trend: " + trendText + "\n" +
      "ATR: " + DoubleToString(g_atr, _Digits) + "\n" +
      "TP: " + DoubleToString(g_rope + g_atr * ATR_Mult_TP, _Digits) + "\n" +
      "SL: " + DoubleToString(g_rope - g_atr * ATR_Mult_SL, _Digits));
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
   CTrade trade;
   trade.SetExpertMagicNumber(2025071702);
   trade.SetDeviationInPoints(3);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr = g_atr;
   double lot;

   if(FixedLotSize > 0)
      lot = NormalizeLot(FixedLotSize);
   else
      lot = CalcRiskLot(atr * ATR_Mult_SL);

   //--- Long Entry
   if(g_dir > 0 && IsBreakout() && IsWithinSignalWindow())
   {
      double sl = bid - atr * ATR_Mult_SL;
      double tp = bid + atr * ATR_Mult_TP;
      if(CountPositions() < MaxOpenPositions && CountPendingOrders() == 0)
         trade.Buy(lot, _Symbol, ask, sl, tp, "TNT Long");
   }

   //--- Short Entry
   else if(g_dir < 0 && IsBreakout() && IsWithinSignalWindow())
   {
      double sl = ask + atr * ATR_Mult_SL;
      double tp = ask - atr * ATR_Mult_TP;
      if(CountPositions() < MaxOpenPositions && CountPendingOrders() == 0)
         trade.Sell(lot, _Symbol, bid, sl, tp, "TNT Short");
   }
}

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   CleanUpObjects();
   Print("=== TraderNakal_Trend_EA initialized ===");
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

   //--- ATR Calculation
   g_atr = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);

   //--- Rope Smoother
   double ropeArr[], upperArr[], lowerArr[];
   ArrayResize(ropeArr, 2);
   ArrayResize(upperArr, 2);
   ArrayResize(lowerArr, 2);
   RopeSmoother(ropeArr, upperArr, lowerArr, Rope_ATR_Len, Rope_Multiplier, Rope_Source);
   g_rope = ropeArr[1];
   g_upper = upperArr[1];
   g_lower = lowerArr[1];

   //--- Update Direction
   UpdateDirection();

   //--- Draw Objects
   DrawRope();
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