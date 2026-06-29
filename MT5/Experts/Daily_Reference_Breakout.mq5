//+------------------------------------------------------------------+
//|                                     Daily_Reference_Breakout.mq5 |
//|                                  Copyright 2024, Agent Hermes    |
//|                                             https://mql5.com     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Agent Hermes"
#property link      ""
#property version   "1.00"
#property strict

//--- Enums for Price Type (matching your indicator)
enum ENUM_PRICE_TYPE {
   PRICE_OPEN = 0,  // Open
   PRICE_HIGH = 1,  // High
   PRICE_LOW  = 2,  // Low
   PRICE_CLOSE= 3   // Close
};

//--- Input Parameters
input group "--- Reference Settings ---"
input ENUM_TIMEFRAMES InpTimeframe   = PERIOD_H1;     // Reference Timeframe
input int             InpHourOffset  = 2;             // Hour Offset (e.g. 2)
input ENUM_PRICE_TYPE InpPriceSource = PRICE_OPEN;    // Price Source (Dropdown)

input group "--- Trading Settings ---"
input double          InpLotSize     = 0.1;           // Lot Size
input int             InpStopLoss    = 200;           // Stop Loss (Pips)
input int             InpTakeProfit  = 400;           // Take Profit (Pips)
input int             InpMagicNumber = 123456;        // Magic Number

//--- Global Variables
double   prev_price = 0;
double   pip_multiplier = 1.0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // [AUTO-DIGIT DETECTION]
   // Standard: 1 pip = 10 points for 5-digit/3-digit brokers
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5)
      pip_multiplier = 10.0 * _Point;
   else
      pip_multiplier = _Point;

   prev_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   Print("EA Initialized. Digits: ", digits, " | Pip Multiplier: ", pip_multiplier);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. Calculate Reference Price (Mirrors Indicator Logic)
   datetime current_day_start = iTime(_Symbol, PERIOD_D1, 0);
   if(current_day_start == 0) return; 

   datetime target_time = current_day_start + (InpHourOffset * 3600);
   int bar_index = iBarShift(_Symbol, InpTimeframe, target_time, false);
   
   if(bar_index < 0) return;

   double target_price = 0;
   switch(InpPriceSource)
   {
      case PRICE_OPEN:  target_price = iOpen(_Symbol, InpTimeframe, bar_index); break;
      case PRICE_HIGH:  target_price = iHigh(_Symbol, InpTimeframe, bar_index); break;
      case PRICE_LOW:   target_price = iLow(_Symbol, InpTimeframe, bar_index);  break;
      case PRICE_CLOSE: target_price = iClose(_Symbol, InpTimeframe, bar_index);break;
   }

   if(target_price <= 0) return;

   // 2. Get Current Market Prices
   double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   if(prev_price == 0) { prev_price = current_bid; return; }

   // 3. Check for existing position (prevents multiple entries on same breakout)
   if(PositionSelectByMagic(InpMagicNumber)) 
   {
      prev_price = current_bid;
      return; 
   }

   // 4. Detection of Breakout (Price crossing the target line)
   bool buy_signal  = (prev_price < target_price && current_bid > target_price);
   bool sell_signal = (prev_price > target_price && current_bid < target_price);

   if(buy_signal)
   {
      ExecuteTrade(ORDER_TYPE_BUY, current_ask, target_price);
   }
   else if(sell_signal)
   {
      ExecuteTrade(ORDER_TYPE_SELL, current_bid, target_price);
   }

   prev_price = current_bid;
}

//+------------------------------------------------------------------+
//| Trade Execution Helper                                           |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE type, double price, double ref_price)
{
   MqlTradeRequest request = {};
   MqlTradeResult  result  = {};

   double sl = 0, tp = 0;
   
   if(type == ORDER_TYPE_BUY)
   {
      sl = price - (InpStopLoss * pip_multiplier);
      tp = price + (InpTakeProfit * pip_multiplier);
   }
   else
   {
      sl = price + (InpStopLoss * pip_multiplier);
      tp = price - (InpTakeProfit * pip_multiplier);
   }

   request.action       = TRADE_ACTION_DEAL;
   request.symbol       = _Symbol;
   request.volume       = InpLotSize;
   request.type         = type;
   request.price        = price;
   request.sl           = NormalizeDouble(sl, _Digits);
   request.tp           = NormalizeDouble(tp, _Digits);
   request.deviation    = 10;
   request.magic        = InpMagicNumber;
   request.comment      = "Daily Ref Breakout";
   request.type_filling = ORDER_FILLING_IOC; // Standard for most MT5 accounts

   if(!OrderSend(request, result))
      Print("OrderSend error: ", GetLastError(), " | Target Price: ", ref_price);
   else
      Print("Trade Executed! Ticket: ", result.deal, " | Type: ", EnumToString(type));
}

//+------------------------------------------------------------------+
//| Check if a position is already open for this EA                  |
//+------------------------------------------------------------------+
bool PositionSelectByMagic(long magic)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == magic && PositionGetString(POSITION_SYMBOL) == _Symbol)
            return true;
      }
   }
   return false;
}
