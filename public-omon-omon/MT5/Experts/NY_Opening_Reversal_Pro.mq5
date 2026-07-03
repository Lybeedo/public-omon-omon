//+------------------------------------------------------------------+
//|                                      NY_Opening_Reversal_Pro.mq5 |
//|                                  Copyright 2026, Agent Hermes    |
//|                                             https://hermes.ai    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Agent Hermes"
#property link      "https://hermes.ai"
#property version   "1.20"
#property strict

//--- ENUMS
enum ENUM_CANDLE_TYPE {
   CANDLE_BULLISH,
   CANDLE_BEARISH,
   CANDLE_DOJI,
   CANDLE_UNKNOWN
};

enum ENUM_RISK_MODE { 
   RISK_FIXED_LOT, 
   RISK_PERCENT_EQUITY 
};

//--- INPUT PARAMETERS
input group "--- TIMING (DIRECT BROKER TIME) ---"
input int      InpSignalHour      = 9;          // Signal Candle Hour
input int      InpSignalMinute    = 0;          // Signal Candle Minute
input int      InpPlacementHour   = 9;          // Placement Hour
input int      InpPlacementMinute = 30;         // Placement Minute
input int      InpExpiryHour      = 10;         // Expiration Hour
input int      InpExpiryMinute    = 0;          // Expiration Minute

input group "--- STRATEGY SETTINGS ---"
input int      InpSLPoints        = 500;        // Stop Loss (Points)
input int      InpTPPoints        = 1000;       // Take Profit (Points)
input double   InpDojiThreshold   = 0.1;        // Doji Threshold (0.1 = 10% body/range)

input group "--- MONEY MANAGEMENT ---"
input ENUM_RISK_MODE InpRiskMode  = RISK_FIXED_LOT; // Risk Mode
input double   InpLotSize         = 0.1;        // Fixed Lot Size
input double   InpRiskPercent     = 1.0;        // % Risk of Equity

input group "--- TRADE MANAGEMENT (BE & TRAILING) ---"
input bool     InpUseRiskMgmt     = true;       // Enable Break-Even & Trailing?
input int      InpBEActivation    = 200;        // Break-Even Activation (Points)
input int      InpBELock          = 100;        // Break-Even Lock (Points)
input int      InpTrailingStep    = 50;         // Trailing Step (Points)

input group "--- SYSTEM ---"
input long     InpMagic           = 123456;     // Magic Number

//--- GLOBAL VARIABLES
datetime last_trade_day = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   MqlDateTime dt;
   datetime now = TimeCurrent(dt);
   
   // 1. Manage existing positions (BE & Trailing) if enabled
   if(InpUseRiskMgmt) {
      ManagePositions();
   }

   // 2. Check for Expiration (Cleanup unfilled orders)
   CheckExpiration(dt);

   // 3. Check for Placement (New Orders)
   if(dt.hour == InpPlacementHour && dt.min == InpPlacementMinute) {
      CheckAndPlaceOrders(dt);
   }
}

//+------------------------------------------------------------------+
//| Calculate Lot Size based on Risk Mode                            |
//+------------------------------------------------------------------+
double CalculateLot(double sl_points) {
   if(InpRiskMode == RISK_FIXED_LOT) return InpLotSize;
   
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double risk_money = equity * (InpRiskPercent / 100.0);
   
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(sl_points <= 0 || tick_value <= 0 || tick_size <= 0) return InpLotSize;
   
   // Value of 1 point per 1 lot = (tick_value / tick_size) * _Point
   double points_value = (tick_value / tick_size) * _Point;
   double lot = risk_money / (sl_points * points_value);
   
   // Normalize to broker step
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot = MathFloor(lot / step) * step;
   
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   
   if(lot < min_lot) lot = min_lot;
   if(lot > max_lot) lot = max_lot;
   
   return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
//| Analyze candle and place pending orders                          |
//+------------------------------------------------------------------+
void CheckAndPlaceOrders(MqlDateTime &dt) {
   datetime today_start = StringToTime(IntegerToString(dt.year)+"."+IntegerToString(dt.mon)+"."+IntegerToString(dt.day));
   if(last_trade_day >= today_start) return;

   datetime signal_time = StringToTime(IntegerToString(dt.year)+"."+IntegerToString(dt.mon)+"."+IntegerToString(dt.day)+" "+
                                       IntegerToString(InpSignalHour)+":"+IntegerToString(InpSignalMinute));
   
   if(signal_time >= TimeCurrent()) return;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, _Period, signal_time, 1, rates);

   if(copied <= 0) return;

   ENUM_CANDLE_TYPE type = GetCandleType(rates[0]);
   if(type == CANDLE_DOJI) {
      Print("Signal candle is a Doji. Skipping trade for today.");
      last_trade_day = today_start; 
      return;
   }

   MqlTradeRequest request;
   MqlTradeResult  result;
   ZeroMemory(request);
   ZeroMemory(result);

   double open_price = rates[0].open;
   double calculated_lot = CalculateLot((double)InpSLPoints);

   request.action       = TRADE_ACTION_PENDING;
   request.symbol       = _Symbol;
   request.volume       = calculated_lot;
   request.price        = NormalizeDouble(open_price, _Digits);
   request.magic        = InpMagic;
   request.type_time    = ORDER_TIME_DAY;

   if(type == CANDLE_BULLISH) {
      request.type         = ORDER_TYPE_SELL_STOP;
      request.sl           = NormalizeDouble(open_price + InpSLPoints * _Point, _Digits);
      request.tp           = NormalizeDouble(open_price - InpTPPoints * _Point, _Digits);
   }
   else if(type == CANDLE_BEARISH) {
      request.type         = ORDER_TYPE_BUY_STOP;
      request.sl           = NormalizeDouble(open_price - InpSLPoints * _Point, _Digits);
      request.tp           = NormalizeDouble(open_price + InpTPPoints * _Point, _Digits);
   }
   else return;

   if(OrderSend(request, result)) {
      Print("Order placed successfully. Ticket: ", result.order, " Lot: ", calculated_lot);
      last_trade_day = today_start;
   } else {
      Print("Order placement failed. Error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Determine candle type                                            |
//+------------------------------------------------------------------+
ENUM_CANDLE_TYPE GetCandleType(MqlRates &rate) {
   double body = MathAbs(rate.open - rate.close);
   double range = rate.high - rate.low;
   if(range == 0) return CANDLE_DOJI;
   if(body / range < InpDojiThreshold) return CANDLE_DOJI;
   if(rate.close > rate.open) return CANDLE_BULLISH;
   if(rate.close < rate.open) return CANDLE_BEARISH;
   return CANDLE_DOJI;
}

//+------------------------------------------------------------------+
//| Manage Positions: BE & Trailing Step                             |
//+------------------------------------------------------------------+
void ManagePositions() {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket)) {
         if(PositionGetInteger(POSITION_MAGIC) != InpMagic || PositionGetString(POSITION_SYMBOL) != _Symbol) 
            continue;

         double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
         double current_sl  = PositionGetDouble(POSITION_SL);
         double current_tp  = PositionGetDouble(POSITION_TP);
         double cur_price   = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         
         double profit_points = 0;
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            profit_points = (cur_price - entry_price) / _Point;
         else
            profit_points = (entry_price - cur_price) / _Point;

         // --- STAGE 1: BREAK-EVEN ---
         if(profit_points >= InpBEActivation) {
            double target_be_sl = 0;
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
               target_be_sl = NormalizeDouble(entry_price + InpBELock * _Point, _Digits);
            else
               target_be_sl = NormalizeDouble(entry_price - InpBELock * _Point, _Digits);

            bool can_move_be = false;
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
               if(current_sl < target_be_sl - _Point) can_move_be = true;
            } else {
               if(current_sl > target_be_sl + _Point || current_sl == 0) can_move_be = true;
            }

            if(can_move_be) {
               ModifySL(ticket, target_be_sl, current_tp);
               continue; 
            }
         }

         // --- STAGE 2: TRAILING STEP ---
         if(profit_points >= InpBEActivation) {
            double next_step_sl = 0;
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
               double be_level = entry_price + InpBELock * _Point;
               int steps = (int)((cur_price - be_level) / (InpTrailingStep * _Point));
               if(steps > 0) {
                  next_step_sl = NormalizeDouble(be_level + (steps * InpTrailingStep) * _Point, _Digits);
                  if(next_step_sl > current_sl + _Point) ModifySL(ticket, next_step_sl, current_tp);
               }
            } else {
               double be_level = entry_price - InpBELock * _Point;
               int steps = (int)((be_level - cur_price) / (InpTrailingStep * _Point));
               if(steps > 0) {
                  next_step_sl = NormalizeDouble(be_level - (steps * InpTrailingStep) * _Point, _Digits);
                  if(current_sl == 0 || next_step_sl < current_sl - _Point) ModifySL(ticket, next_step_sl, current_tp);
               }
            }
         }
      }
   }
}

void ModifySL(ulong ticket, double new_sl, double tp) {
   MqlTradeRequest request; MqlTradeResult result;
   ZeroMemory(request); ZeroMemory(result);
   request.action = TRADE_ACTION_SLTP;
   request.position = ticket;
   request.sl = new_sl;
   request.tp = tp;
   if(!OrderSend(request, result)) Print("SL Modification Error: ", GetLastError());
}

void CheckExpiration(MqlDateTime &dt) {
   if(dt.hour == InpExpiryHour && dt.min == InpExpiryMinute) {
      for(int i = OrdersTotal() - 1; i >= 0; i--) {
         ulong ticket = OrderGetTicket(i);
         if(OrderSelect(ticket)) {
            if(OrderGetInteger(ORDER_MAGIC) == InpMagic && OrderGetString(ORDER_SYMBOL) == _Symbol) {
               MqlTradeRequest request; MqlTradeResult result;
               ZeroMemory(request); ZeroMemory(result);
               request.action = TRADE_ACTION_REMOVE;
               request.order  = ticket;
               OrderSend(request, result);
            }
         }
      }
   }
}
