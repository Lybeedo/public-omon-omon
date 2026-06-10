//+------------------------------------------------------------------+
//|                                                 EasyMathEA.mq5    |
//|                                         Cuancux Algo Traders     |
//+------------------------------------------------------------------+
#property copyright   "Cuancux Algo Traders"
#property version      "1.00"
#property strict

//+------------------------------------------------------------------+
//| INPUTS                                                            |
//+------------------------------------------------------------------+
input group "=== ORDER MODE ==="
input bool     InpUsePullback = true;     // true=Limit(Pullback), false=Stop(Trend)

input group "=== TRADE ==="
input ulong    InpMagic       = 202620;   // Magic Number
input double   InpLot         = 0.01;      // Lot Size
input int      InpSLPips      = 500;        // Stop Loss (pips)
input int      InpTPPips      = 500;      // Take Profit (pips)

input group "=== TRAILING STOP ==="
input bool     InpTrailOn     = false;    // Enable Trailing Stop
input int      InpTrailStart  = 120;       // Trailing Start (pips)
input int      InpTrailStep   = 20;       // Trailing Step (pips)

input group "=== FORMULA ==="
input double   InpParam       = 0.12;     // Parameter (sqrt subtractor)

input group "=== SCHEDULE ==="
input string   InpStartTime   = "09:00";  // Active From (HH:MM)
input string   InpStopTime    = "18:00";  // Active Until (HH:MM)
input bool     InpTimeFilter  = false;     // Enable Time Filter

//+------------------------------------------------------------------+
//| GLOBALS                                                           |
//+------------------------------------------------------------------+
double   gPip;
datetime gLastCandle;

//+------------------------------------------------------------------+
//| INIT                                                              |
//+------------------------------------------------------------------+
int OnInit()
{
   if(InpLot < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN) ||
      InpLot > SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX))
   {
      Print("Invalid lot size. Min: ",
            SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN),
            " Max: ", SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX));
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpSLPips <= 0 || InpTPPips <= 0)
   {
      Print("SL and TP must be > 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   long digits = SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   gPip = (digits == 5 || digits == 3)
          ? SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10
          : SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   Print("EA Initialized. Pip=", gPip, " Digits=", digits);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINIT                                                            |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "EMEA_");
}

//+------------------------------------------------------------------+
//| TICK                                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   datetime currentCandle = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentCandle == gLastCandle)
      return;
   gLastCandle = currentCandle;

   if(InpTimeFilter && !IsTimeActive())
      return;

   ManageTrailingStop();

   if(HasPendingOrder())
      return;

   double high = iHigh(_Symbol, PERIOD_CURRENT, 0);
   double low  = iLow(_Symbol, PERIOD_CURRENT, 0);
   double buyEntry  = MathPow(MathSqrt(high) - InpParam, 2);
   double sellEntry = MathPow(MathSqrt(low)  + InpParam, 2);
   buyEntry  = NormalizeDouble(MathMax(low,  MathMin(high, buyEntry)),  _Digits);
   sellEntry = NormalizeDouble(MathMax(low,  MathMin(high, sellEntry)), _Digits);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   long stopDist = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double stopDistPrice = MathMax(stopDist * point, ask - bid);

   MqlTradeResult result = {};
   MqlTradeRequest request = {};
   ZeroMemory(request);
   ZeroMemory(result);
   request.magic     = InpMagic;
   request.symbol    = _Symbol;
   request.volume    = InpLot;
   request.deviation = 10;
   request.comment   = "EasyMathEA";

   if(InpUsePullback)
   {
      // --- PULLBACK MODE: Buy Limit di bawah, Sell Limit di atas ---
      double buyDist  = bid - buyEntry;    // how far buyEntry is below bid
      double sellDist = sellEntry - ask;   // how far sellEntry is above ask

      if(buyDist > stopDistPrice && buyEntry < bid)
      {
         request.action = TRADE_ACTION_PENDING;
         request.type   = ORDER_TYPE_BUY_LIMIT;
         request.price  = NormalizeDouble(buyEntry, _Digits);
         request.sl     = NormalizeDouble(buyEntry - InpSLPips * gPip, _Digits);
         request.tp     = NormalizeDouble(buyEntry + InpTPPips * gPip, _Digits);
         OrderSend(request, result);
         if(result.retcode != TRADE_RETCODE_DONE && result.retcode != TRADE_RETCODE_PLACED)
            Print("BuyLimit error: ", result.retcode, " ", result.comment);
      }

      if(sellDist > stopDistPrice && sellEntry > ask)
      {
         request.action = TRADE_ACTION_PENDING;
         request.type   = ORDER_TYPE_SELL_LIMIT;
         request.price  = NormalizeDouble(sellEntry, _Digits);
         request.sl     = NormalizeDouble(sellEntry + InpSLPips * gPip, _Digits);
         request.tp     = NormalizeDouble(sellEntry - InpTPPips * gPip, _Digits);
         OrderSend(request, result);
         if(result.retcode != TRADE_RETCODE_DONE && result.retcode != TRADE_RETCODE_PLACED)
            Print("SellLimit error: ", result.retcode, " ", result.comment);
      }
   }
   else
   {
      // --- TREND MODE: Buy Stop di atas, Sell Stop di bawah ---
      double buyDist  = buyEntry  - bid;   // positive = above bid
      double sellDist = ask - sellEntry;   // positive = below ask

      if(buyDist > stopDistPrice && buyEntry > bid)
      {
         request.action = TRADE_ACTION_PENDING;
         request.type   = ORDER_TYPE_BUY_STOP;
         request.price  = NormalizeDouble(buyEntry, _Digits);
         request.sl     = NormalizeDouble(buyEntry - InpSLPips * gPip, _Digits);
         request.tp     = NormalizeDouble(buyEntry + InpTPPips * gPip, _Digits);
         OrderSend(request, result);
         if(result.retcode != TRADE_RETCODE_DONE && result.retcode != TRADE_RETCODE_PLACED)
            Print("BuyStop error: ", result.retcode, " ", result.comment);
      }

      if(sellDist > stopDistPrice && sellEntry < ask)
      {
         request.action = TRADE_ACTION_PENDING;
         request.type   = ORDER_TYPE_SELL_STOP;
         request.price  = NormalizeDouble(sellEntry, _Digits);
         request.sl     = NormalizeDouble(sellEntry + InpSLPips * gPip, _Digits);
         request.tp     = NormalizeDouble(sellEntry - InpTPPips * gPip, _Digits);
         OrderSend(request, result);
         if(result.retcode != TRADE_RETCODE_DONE && result.retcode != TRADE_RETCODE_PLACED)
            Print("SellStop error: ", result.retcode, " ", result.comment);
      }
   }

   DrawInfo(buyEntry, sellEntry, high, low);
}

//+------------------------------------------------------------------+
//| TIME FILTER                                                       |
//+------------------------------------------------------------------+
bool IsTimeActive()
{
   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);
   int nowMin = now.hour * 60 + now.min;

   int sh = 0, sm = 0, sth = 0, stm = 0;
   string parts[];

   if(StringSplit(InpStartTime, ':', parts) == 2)
   {
      sh = (int)StringToInteger(parts[0]);
      sm = (int)StringToInteger(parts[1]);
   }
   if(StringSplit(InpStopTime, ':', parts) == 2)
   {
      sth = (int)StringToInteger(parts[0]);
      stm = (int)StringToInteger(parts[1]);
   }

   int startMin = sh * 60 + sm;
   int stopMin  = sth * 60 + stm;

   return (stopMin > startMin)
          ? (nowMin >= startMin && nowMin <= stopMin)
          : (nowMin >= startMin || nowMin <= stopMin);
}

//+------------------------------------------------------------------+
//| CHECK PENDING                                                     |
//+------------------------------------------------------------------+
bool HasPendingOrder()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(OrderGetTicket(i)))
      {
         if(OrderGetInteger(ORDER_MAGIC) == InpMagic &&
            OrderGetString(ORDER_SYMBOL) == _Symbol)
         {
            ENUM_ORDER_TYPE t = OrderGetInteger(ORDER_TYPE);
            if(t == ORDER_TYPE_BUY_LIMIT  || t == ORDER_TYPE_SELL_LIMIT ||
               t == ORDER_TYPE_BUY_STOP   || t == ORDER_TYPE_SELL_STOP)
               return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| TRAILING STOP                                                     |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   if(!InpTrailOn)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      double vol       = PositionGetDouble(POSITION_VOLUME);
      double ask       = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid       = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      MqlTradeResult result = {};
      MqlTradeRequest request = {};
      ZeroMemory(request);
      ZeroMemory(result);
      request.magic     = InpMagic;
      request.symbol    = _Symbol;
      request.volume    = vol;
      request.deviation = 10;

      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
         double profitPips = (bid - openPrice) / gPip;
         if(profitPips >= InpTrailStart)
         {
            double newSL = openPrice + InpTrailStart * gPip;
            if(newSL > currentSL + InpTrailStep * gPip)
            {
               request.action   = TRADE_ACTION_SLTP;
               request.position = ticket;
               request.sl       = NormalizeDouble(newSL, _Digits);
               request.tp       = NormalizeDouble(currentTP, _Digits);
               OrderSend(request, result);
            }
         }
      }
      else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
      {
         double profitPips = (openPrice - ask) / gPip;
         if(profitPips >= InpTrailStart)
         {
            double newSL = openPrice - InpTrailStart * gPip;
            if(newSL < currentSL - InpTrailStep * gPip)
            {
               request.action   = TRADE_ACTION_SLTP;
               request.position = ticket;
               request.sl       = NormalizeDouble(newSL, _Digits);
               request.tp       = NormalizeDouble(currentTP, _Digits);
               OrderSend(request, result);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| DRAW INFO                                                         |
//+------------------------------------------------------------------+
void DrawInfo(double buyEntry, double sellEntry, double high, double low)
{
   string pref = "EMEA_";
   ObjectDelete(0, pref + "BuyLine");
   ObjectDelete(0, pref + "SellLine");
   ObjectDelete(0, pref + "BuyLbl");
   ObjectDelete(0, pref + "SellLbl");
   ObjectDelete(0, pref + "InfoLbl");

   ObjectCreate(0, pref + "BuyLine", OBJ_HLINE, 0, 0, buyEntry);
   ObjectSetInteger(0, pref + "BuyLine", OBJPROP_COLOR, clrLime);
   ObjectSetInteger(0, pref + "BuyLine", OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, pref + "BuyLine", OBJPROP_STYLE, STYLE_DASH);

   ObjectCreate(0, pref + "SellLine", OBJ_HLINE, 0, 0, sellEntry);
   ObjectSetInteger(0, pref + "SellLine", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, pref + "SellLine", OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, pref + "SellLine", OBJPROP_STYLE, STYLE_DASH);

   string modeStr = InpUsePullback ? "LIMIT" : "STOP";

   ObjectCreate(0, pref + "BuyLbl", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, pref + "BuyLbl", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, pref + "BuyLbl", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, pref + "BuyLbl", OBJPROP_YDISTANCE, 20);
   ObjectSetString(0, pref + "BuyLbl", OBJPROP_TEXT,
      "BUY " + modeStr + ": " + DoubleToString(buyEntry, _Digits) +
      "  SL:" + DoubleToString(buyEntry - InpSLPips * gPip, _Digits) +
      "  TP:" + DoubleToString(buyEntry + InpTPPips * gPip, _Digits));
   ObjectSetInteger(0, pref + "BuyLbl", OBJPROP_COLOR, clrLime);

   ObjectCreate(0, pref + "SellLbl", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, pref + "SellLbl", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, pref + "SellLbl", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, pref + "SellLbl", OBJPROP_YDISTANCE, 40);
   ObjectSetString(0, pref + "SellLbl", OBJPROP_TEXT,
      "SELL " + modeStr + ": " + DoubleToString(sellEntry, _Digits) +
      "  SL:" + DoubleToString(sellEntry + InpSLPips * gPip, _Digits) +
      "  TP:" + DoubleToString(sellEntry - InpTPPips * gPip, _Digits));
   ObjectSetInteger(0, pref + "SellLbl", OBJPROP_COLOR, clrRed);

   ObjectCreate(0, pref + "InfoLbl", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, pref + "InfoLbl", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, pref + "InfoLbl", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, pref + "InfoLbl", OBJPROP_YDISTANCE, 65);
   ObjectSetString(0, pref + "InfoLbl", OBJPROP_TEXT,
      "H:" + DoubleToString(high, _Digits) +
      "  L:" + DoubleToString(low, _Digits) +
      "  Mode:" + (InpUsePullback ? "Pullback" : "Trend"));
   ObjectSetInteger(0, pref + "InfoLbl", OBJPROP_COLOR, clrWhite);
}
//+------------------------------------------------------------------+