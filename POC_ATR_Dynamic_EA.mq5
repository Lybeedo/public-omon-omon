//+------------------------------------------------------------------+
//|                                          POC_ATR_Dynamic_EA.mq5 |
//|                                Cuancux Algo Traders / Paulus     |
//|                                              POC + ATR Dynamic   |
//+------------------------------------------------------------------+
#property copyright   "Cuancux Algo Traders"
#property version     "1.00"
#property indicator_chart_window
#property strict

//--- Input: POC
input group "=== POC (Point Of Control) ==="
input int      POC_LookbackBars   = 20;      // Lookback bars for POC detection
input int      POC_SessionHour    = 8;       // Session start hour (broker time)
input int      POC_SessionMinute  = 0;       // Session start minute

//--- Input: ATR Dynamic TP/SL
input group "=== ATR Dynamic TP/SL ==="
input int      ATR_Period         = 14;      // ATR period
input double   ATR_Mult_TP        = 2.0;     // TP multiplier (ATR x N)
input double   ATR_Mult_SL        = 1.5;     // SL multiplier (ATR x N)

//--- Input: Trade Management
input group "=== Trade Management ==="
input double   FixedLotSize       = 0.1;     // Fixed lot (0 = risk-based)
input double   RiskPercent        = 2.0;     // Risk % if FixedLot=0
input int      MaxOpenPositions   = 1;       // Max concurrent positions
input int      ExpirationMinutes = 240;      // Pending order expiry (min, 0=no expiry)

//--- Input: Filter & Time
input group "=== Session Filter ==="
input int      SignalStartHour    = 8;       // Allow entries from this hour
input int      SignalStartMinute  = 30;
input int      SignalEndHour      = 19;      // Stop entries after this hour
input int      SignalEndMinute    = 0;

//--- Input: Broker Offset (Season-Proof)
input group "=== Broker Offset ==="
input int      BrokerOffsetMins   = 0;       // Broker offset from UTC (minutes)

//--- Globals
#define PREFIX "POCATR_"
double g_atr;

//+------------------------------------------------------------------+
//| Get current broker time offset in minutes from UTC                |
//+------------------------------------------------------------------+
datetime GetBrokerTime()
{
   MqlDateTime brokerTm;
   TimeToStruct(TimeCurrent(), brokerTm);
   return StringFormat("%04d.%02d.%02d %02d:%02d:%02d",
                       brokerTm.year, brokerTm.mon, brokerTm.day,
                       brokerTm.hour, brokerTm.min, brokerTm.sec);
}

//+------------------------------------------------------------------+
//| Check if current time is within signal window                    |
//+------------------------------------------------------------------+
bool IsWithinSignalWindow()
{
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   int curMin = tm.hour * 60 + tm.min;
   int startMin = SignalStartHour * 60 + SignalStartMinute;
   int endMin   = SignalEndHour   * 60 + SignalEndMinute;

   if(endMin > startMin)
      return (curMin >= startMin && curMin <= endMin);
   else
      return (curMin >= startMin || curMin <= endMin);
}

//+------------------------------------------------------------------+
//| Calculate ATR                                                   |
//+------------------------------------------------------------------+
double GetATR(int period)
{
   return iATR(_Symbol, PERIOD_CURRENT, period);
}

//+------------------------------------------------------------------+
//| Find POC: bar with highest total tick volume in lookback          |
//+------------------------------------------------------------------+
double FindPOC(int lookbackBars)
{
   double maxVol = 0.0;
   double pocPrice = 0.0;

   if(CopyRates(_Symbol, PERIOD_CURRENT, 1, lookbackBars) < lookbackBars)
      return 0.0;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_CURRENT, 0, lookbackBars, rates);
   if(copied <= 0) return 0.0;

   for(int i = 0; i < copied; i++)
   {
      double typical = (rates[i].high + rates[i].low + rates[i].close) / 3.0;
      double vol = rates[i].tick_volume;
      if(vol > maxVol)
      {
         maxVol = vol;
         pocPrice = typical;
      }
   }
   return NormalizeDouble(pocPrice, _Digits);
}

//+------------------------------------------------------------------+
//| Normalize lotsize for broker                                      |
//+------------------------------------------------------------------+
double NormalizeLot(double lot)
{
   double minLot   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double step     = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double maxLot   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double norm     = MathRound(lot / step) * step;
   return MathMax(minLot, MathMin(maxLot, norm));
}

//+------------------------------------------------------------------+
//| Calculate lot based on risk %                                     |
//+------------------------------------------------------------------+
double CalcRiskLot(double slDistance)
{
   if(slDistance <= 0) return NormalizeLot(FixedLotSize > 0 ? FixedLotSize : 0.01);

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk   = balance * (RiskPercent / 100.0);
   double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSz  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double slTicks = slDistance / tickSz;

   double lot = risk / (slTicks * tickVal);
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(lot < minLot) lot = minLot;

   return NormalizeLot(lot);
}

//+------------------------------------------------------------------+
//| Count open positions on this symbol                               |
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
//| Count pending orders from this EA                                |
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
//| Delete all pending orders from this EA                           |
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
//| Draw POC line + label                                            |
//+------------------------------------------------------------------+
void DrawPOC(double poc)
{
   string lineName = PREFIX + "POC_Line";
   string labelName = PREFIX + "POC_Label";
   datetime now = TimeCurrent();

   // Line
   ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, poc);
   ObjectSetInteger(0, lineName, OBJPROP_COLOR, clrGold);
   ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DASH);

   // Label
   ObjectCreate(0, labelName, OBJ_TEXT, 0, now, poc);
   ObjectSetString(0, labelName, OBJPROP_TEXT, "POC");
   ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrGold);
   ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_RIGHT);
}

//+------------------------------------------------------------------+
//| Draw entry/exit zone rectangles                                   |
//+------------------------------------------------------------------+
void DrawZones(double poc, double tp, double sl, bool isLong)
{
   string rectBuy  = PREFIX + "Zone_Buy";
   string rectSell = PREFIX + "Zone_Sell";
   datetime now = TimeCurrent();
   datetime right = now + 60; // extend to right

   // Remove old zones first
   ObjectDelete(0, rectBuy);
   ObjectDelete(0, rectSell);

   color col = isLong ? ColorToARGB(clrLime, 40) : ColorToARGB(clrRed, 40);

   string rectName = isLong ? rectBuy : rectSell;
   ObjectCreate(0, rectName, OBJ_RECTANGLE, 0, now, poc);
   ObjectSetInteger(0, rectName, OBJPROP_TIME2, right);
   ObjectSetDouble(0, rectName, OBJPROP_PRICE, tp);
   ObjectSetInteger(0, rectName, OBJPROP_COLOR, col);
   ObjectSetInteger(0, rectName, OBJPROP_FILL, true);
   ObjectSetInteger(0, rectName, OBJPROP_BACK, true);
}

//+------------------------------------------------------------------+
//| Clear all EA objects                                             |
//+------------------------------------------------------------------+
void CleanUpObjects()
{
   ObjectsDeleteAll(0, PREFIX);
}

//+------------------------------------------------------------------+
//| Comment dashboard                                                |
//+------------------------------------------------------------------+
void DrawDashboard(double poc, double atr, double tp, double sl)
{
   string comment =
      "=== POC + ATR Dynamic EA ===\n" +
      "POC Price   : " + DoubleToString(poc, _Digits) + "\n" +
      "ATR (" + IntegerToString(ATR_Period) + ")  : " + DoubleToString(atr, _Digits) + "\n" +
      "TP (x" + DoubleToString(ATR_Mult_TP, 1) + "): " + DoubleToString(tp, _Digits) + "\n" +
      "SL (x" + DoubleToString(ATR_Mult_SL, 1) + "): " + DoubleToString(sl, _Digits) + "\n" +
      "Signal Window: " + IntegerToString(SignalStartHour) + ":" + IntegerToString(SignalStartMinute, 2) +
      " - " + IntegerToString(SignalEndHour) + ":" + IntegerToString(SignalEndMinute, 2) + "\n" +
      "Open Positions : " + IntegerToString(CountPositions()) + "\n" +
      "Pending Orders : " + IntegerToString(CountPendingOrders());
   Comment(comment);
}

//+------------------------------------------------------------------+
//| Check for valid signal candle                                     |
//+------------------------------------------------------------------+
bool IsValidSignalCandle()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 3, rates) < 3) return false;

   // Require minimum body size (not a doji)
   double body = MathAbs(rates[1].close - rates[1].open);
   double range = rates[1].high - rates[1].low;
   if(range == 0) return false;
   return (body / range) > 0.3; // body > 30% of range
}

//+------------------------------------------------------------------+
//| Execute trade                                                    |
//+------------------------------------------------------------------+
void ExecuteTrade(double tp, double sl)
{
   CTrade trade;
   trade.SetExpertMagicNumber(2025071701);
   trade.SetDeviationInPoints(3);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr = g_atr;
   double lot;

   if(FixedLotSize > 0)
      lot = NormalizeLot(FixedLotSize);
   else
      lot = CalcRiskLot(MathMax(MathAbs(ask - sl), MathAbs(bid - sl)));

   //--- Long
   if(atr > 0)
   {
      double entryBuy  = ask;
      double slBuy     = NormalizeDouble(ask - sl, _Digits);
      double tpBuy     = NormalizeDouble(ask + tp, _Digits);

      if(CountPositions() < MaxOpenPositions && CountPendingOrders() == 0)
      {
         if(!trade.BuyStop(lot, entryBuy, _Symbol, slBuy, tpBuy, ORDER_TIME_GTC, ExpirationMinutes))
            Print("[POCATR] BuyStop failed: ", GetLastError());
      }

      //--- Short
      if(CountPositions() < MaxOpenPositions && CountPendingOrders() == 0)
      {
         double entrySell = bid;
         double slSell    = NormalizeDouble(bid + sl, _Digits);
         double tpSell    = NormalizeDouble(bid - tp, _Digits);

         if(!trade.SellStop(lot, entrySell, _Symbol, slSell, tpSell, ORDER_TIME_GTC, ExpirationMinutes))
            Print("[POCATR] SellStop failed: ", GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
//| Remove expired pending orders                                     |
//+------------------------------------------------------------------+
void CleanseExpired()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;

      datetime now = TimeCurrent();
      datetime exp = (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
      if(exp > 0 && exp < now)
         OrderDelete(ticket);
   }
}

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   CleanUpObjects();
   Print("=== POC_ATR_Dynamic EA initialized ===");
   Print("Symbol: ", _Symbol, " | Period: ", EnumToString(_Period));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   CleanUpObjects();
   Comment("");
   Print("=== POC_ATR_Dynamic EA deinitialized: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick                                                       |
//+------------------------------------------------------------------+
void OnTick()
{
   static datetime lastCandleTime = 0;
   static bool     alreadyTraded  = false;
   static double   lastPOC        = 0.0;

   // ATR
   double atrArr[];
   ArraySetAsSeries(atrArr, true);
   if(CopyBuffer(iATR(_Symbol, PERIOD_CURRENT, ATR_Period), 0, 0, 2, atrArr) < 2)
      return;
   g_atr = atrArr[0];
   if(g_atr == 0) return;

   // POC
   double poc = FindPOC(POC_LookbackBars);
   if(poc == 0) return;

   // Track new POC
   if(MathAbs(poc - lastPOC) > _Point * 10)
   {
      DeletePendingOrders();
      alreadyTraded = false;
      lastPOC = poc;
      Print("[POC] New POC detected: ", poc);
   }

   // Dashboard
   double tpDist = g_atr * ATR_Mult_TP;
   double slDist = g_atr * ATR_Mult_SL;
   DrawPOC(poc);
   DrawDashboard(poc, g_atr, poc + tpDist, poc - slDist);

   // Clean expired pending orders
   CleanseExpired();

   // Check new candle (once per candle)
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, rates) < 1) return;
   datetime candleTime = rates[0].time;

   bool newCandle = (candleTime != lastCandleTime);
   if(newCandle) lastCandleTime = candleTime;

   // Signal on new candle within window
   if(newCandle && IsWithinSignalWindow() && !alreadyTraded && IsValidSignalCandle())
   {
      if(CountPositions() < MaxOpenPositions)
      {
         ExecuteTrade(tpDist, slDist);
         alreadyTraded = true;
         Print("[POCATR] Trade executed at POC ", poc, " | ATR=", g_atr);
      }
   }

   // Reset flag when candle closes outside window
   if(!IsWithinSignalWindow())
      alreadyTraded = false;
}
//+------------------------------------------------------------------+