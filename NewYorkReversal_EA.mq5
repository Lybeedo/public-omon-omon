//+------------------------------------------------------------------+
//|                                         NewYorkReversal_EA.mq5   |
//|                                  Copyright 2026, Agent Hermes    |
//|                                             https://github.com/  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Agent Hermes"
#property link      "https://github.com/"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>

//--- Enums
enum ENUM_LOT_MODE {
   LOT_FIXED = 0,      // Fixed Lot
   LOT_RISK_PERCENT = 1 // Risk % of Balance
};

//--- Input Parameters
input group "--- Timing Settings ---"
input int      InpSignalHour      = 9;         // Signal Candle Hour
input int      InpSignalMinute    = 0;         // Signal Candle Minute
input int      InpPlacementHour   = 9;         // Order Placement Hour
input int      InpPlacementMinute = 30;        // Order Placement Minute
input int      InpExpirationHour  = 10;        // Order Expiration Hour
input int      InpExpirationMinute = 0;        // Order Expiration Minute

input group "--- Entry Settings ---"
input ENUM_LOT_MODE InpLotMode    = LOT_FIXED; // Lot Sizing Mode
input double   InpFixedLot        = 0.1;       // Fixed Lot Size
input double   InpRiskPercent     = 1.0;       // Risk % per Trade
input int      InpStopLoss        = 50;        // Stop Loss (Points)
input int      InpTakeProfit      = 75;        // Take Profit (Points)
input int      InpDojiThreshold   = 10;        // Doji Body Max (Points)
input bool     InpUseDojiFilter   = true;      // Use Doji Filter

input group "--- Trade Management ---"
input bool     InpUseBreakEven    = true;      // Use Break Even
input int      InpBETrigger       = 20;        // BE Trigger (Points)
input int      InpBELock          = 10;        // BE Lock (Points)
input bool     InpUseTrailing     = true;      // Use Trailing Stop
input int      InpTrailingStep    = 10;        // Trailing Step (Points)

input group "--- System Settings ---"
input long     InpMagic           = 123456;    // Magic Number

//--- Global Variables
CTrade         m_trade;
CPositionInfo  m_position;
COrderInfo     m_order;
CHistoryOrderInfo m_history;

int            m_day_trades_count = 0;
bool           m_signal_ready     = false;
double         m_signal_open_price = 0;
int            m_signal_direction = 0; // 1 = Bullish (Sell Stop), -1 = Bearish (Buy Stop)
datetime       m_last_processed_day = 0;
bool           m_reentry_allowed   = true;
bool           m_day_finished      = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   m_trade.SetExpertMagicNumber(InpMagic);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   
   // Reset at start of new day
   datetime today_start = StringToTime(TimeToString(now, TIME_DATE));
   if(today_start > m_last_processed_day) {
      ResetDay(today_start);
   }

   if(m_day_finished) return;

   // 1. Check Signal
   if(!m_signal_ready && !m_day_finished) {
      CheckSignal(dt);
   }

   // 2. Check Placement
   if(m_signal_ready && !HasPendingOrder() && !IsPositionOpen()) {
      CheckPlacement(dt);
   }

   // 3. Check Expiration
   if(HasPendingOrder()) {
      CheckExpiration(dt);
   }

   // 4. Manage Active Positions (BE & Trailing)
   if(IsPositionOpen()) {
      ManageTrade();
   }
}

//+------------------------------------------------------------------+
//| Handle Trade Transactions (for Re-entry Logic)                   |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result) {
   
   if(trans.type == TRADE_TRANSACTION_HISTORY_ADD) {
      // Check if a position was closed
      if(HistorySelectByPosition(trans.position)) {
         ulong ticket = trans.position;
         if(PositionSelectByTicket(ticket)) return; // Still open

         // Position is closed. Check why.
         CheckTradeResult(ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| Reset Daily Variables                                            |
//+------------------------------------------------------------------+
void ResetDay(datetime day_start) {
   m_last_processed_day = day_start;
   m_day_trades_count = 0;
   m_signal_ready = false;
   m_signal_open_price = 0;
   m_signal_direction = 0;
   m_reentry_allowed = true;
   m_day_finished = false;
   Print("New Day Detected. Resetting EA state.");
}

//+------------------------------------------------------------------+
//| Signal Detection Logic                                           |
//+------------------------------------------------------------------+
void CheckSignal(MqlDateTime &dt) {
   if(dt.hour == InpSignalHour && dt.min == InpSignalMinute) {
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      if(CopyRates(_Symbol, _Period, 1, 1, rates) > 0) {
         double body = MathAbs(rates[0].close - rates[0].open);
         double body_points = body / _Point;

         // Doji Filter
         if(InpUseDojiFilter && body_points < InpDojiThreshold) {
            Print("Doji detected. Skipping signal.");
            m_day_finished = true; // Skip for today
            return;
         }

         m_signal_open_price = rates[0].open;
         if(rates[0].close > rates[0].open) {
            m_signal_direction = 1; // Bullish -> Place Sell Stop
         } else if(rates[0].close < rates[0].open) {
            m_signal_direction = -1; // Bearish -> Place Buy Stop
         } else {
            m_day_finished = true; // Doji or Flat
            return;
         }
         
         m_signal_ready = true;
         Print("Signal Detected: ", (m_signal_direction == 1 ? "BULLISH" : "BEARISH"), " at ", m_signal_open_price);
      }
   }
}

//+------------------------------------------------------------------+
//| Order Placement Logic                                            |
//+------------------------------------------------------------------+
void CheckPlacement(MqlDateTime &dt) {
   if(dt.hour == InpPlacementHour && dt.min == InpPlacementMinute) {
      double sl = 0, tp = 0;
      double lot = CalculateLotSize(InpStopLoss);

      if(m_signal_direction == 1) { // Sell Stop
         sl = m_signal_open_price + (InpStopLoss * _Point);
         tp = m_signal_open_price - (InpTakeProfit * _Point);
         if(m_trade.SellStop(lot, m_signal_open_price, _Symbol, sl, tp)) {
            m_day_trades_count++;
            Print("1st Sell Stop Order Placed.");
         }
      } else if(m_signal_direction == -1) { // Buy Stop
         sl = m_signal_open_price - (InpStopLoss * _Point);
         tp = m_signal_open_price + (InpTakeProfit * _Point);
         if(m_trade.BuyStop(lot, m_signal_open_price, _Symbol, sl, tp)) {
            m_day_trades_count++;
            Print("1st Buy Stop Order Placed.");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Expiration Logic                                                 |
//+------------------------------------------------------------------+
void CheckExpiration(MqlDateTime &dt) {
   if(dt.hour == InpExpirationHour && dt.min == InpExpirationMinute) {
      // Check if pending order still exists
      if(HasPendingOrder()) {
         Print("Expiration time reached. Deleting pending orders.");
         DeleteAllPendingOrders();
         m_day_finished = true;
      }
   }
}

//+------------------------------------------------------------------+
//| Re-entry Logic (On SL only)                                      |
//+------------------------------------------------------------------+
void CheckTradeResult(ulong ticket) {
   if(m_day_trades_count >= 2 || !m_reentry_allowed) return;

   if(HistorySelectByPosition(ticket)) {
      double profit = HistoryPositionGetDouble(ticket, POSITION_PROFIT);
      
      if(profit < 0) { // Hit SL
         Print("Trade hit SL. Attempting Re-entry...");
         double sl = 0, tp = 0;
         double lot = CalculateLotSize(InpStopLoss);

         if(m_signal_direction == 1) { // Sell Stop
            sl = m_signal_open_price + (InpStopLoss * _Point);
            tp = m_signal_open_price - (InpTakeProfit * _Point);
            if(m_trade.SellStop(lot, m_signal_open_price, _Symbol, sl, tp)) {
               m_day_trades_count++;
               Print("Re-entry Sell Stop Placed.");
            }
         } else { // Buy Stop
            sl = m_signal_open_price - (InpStopLoss * _Point);
            tp = m_signal_open_price + (InpTakeProfit * _Point);
            if(m_trade.BuyStop(lot, m_signal_open_price, _Symbol, sl, tp)) {
               m_day_trades_count++;
               Print("Re-entry Buy Stop Placed.");
            }
         }
      } else { // TP or BE/Trailing Profit
         Print("Trade closed in profit. Stopping for the day.");
         m_day_finished = true;
         m_reentry_allowed = false;
      }
   }
}

//+------------------------------------------------------------------+
//| Trade Management (BE & Trailing)                                 |
//+------------------------------------------------------------------+
void ManageTrade() {
   if(!m_position.Select(_Symbol)) return;
   if(m_position.Magic() != InpMagic) return;

   double current_profit_pts = 0;
   double open_price = m_position.PriceOpen();
   double cur_price = (m_position.PositionType() == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(m_position.PositionType() == POSITION_TYPE_BUY) {
      current_profit_pts = (cur_price - open_price) / _Point;
      
      // Break Even
      if(InpUseBreakEven && current_profit_pts >= InpBETrigger) {
         double new_sl = open_price + (InpBELock * _Point);
         if(m_position.StopLoss() < new_sl) {
            m_trade.PositionModify(m_position.Ticket(), new_sl, m_position.TakeProfit());
         }
      }
      
      // Trailing Stop
      if(InpUseTrailing && current_profit_pts >= InpBETrigger) {
         double new_sl = cur_price - (InpTrailingStep * _Point);
         if(m_position.StopLoss() < new_sl) {
            m_trade.PositionModify(m_position.Ticket(), new_sl, m_position.TakeProfit());
         }
      }
   } 
   else if(m_position.PositionType() == POSITION_TYPE_SELL) {
      current_profit_pts = (open_price - cur_price) / _Point;

      // Break Even
      if(InpUseBreakEven && current_profit_pts >= InpBETrigger) {
         double new_sl = open_price - (InpBELock * _Point);
         if(m_position.StopLoss() > new_sl || m_position.StopLoss() == 0) {
            m_trade.PositionModify(m_position.Ticket(), new_sl, m_position.TakeProfit());
         }
      }

      // Trailing Stop
      if(InpUseTrailing && current_profit_pts >= InpBETrigger) {
         double new_sl = cur_price + (InpTrailingStep * _Point);
         if(m_position.StopLoss() > new_sl || m_position.StopLoss() == 0) {
            m_trade.PositionModify(m_position.Ticket(), new_sl, m_position.TakeProfit());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Helper Functions                                                 |
//+------------------------------------------------------------------+
double CalculateLotSize(double sl_points) {
   if(InpLotMode == LOT_FIXED) return InpFixedLot;
   
   double risk_amount = AccountInfoDouble(ACCOUNT_BALANCE) * (InpRiskPercent / 100.0);
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(sl_points <= 0 || tick_value <= 0) return InpFixedLot;
   
   double lot = risk_amount / (sl_points * (tick_value / tick_size * _Point / tick_size) * _Point); // Approximation
   // Standard formula: Lot = Risk / (SL_in_points * Value_per_point)
   double value_per_point = tick_value * (_Point / tick_size);
   lot = risk_amount / (sl_points * value_per_point);
   
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lot = MathFloor(lot/step_lot) * step_lot;
   if(lot < min_lot) lot = min_lot;
   if(lot > max_lot) lot = max_lot;
   
   return lot;
}

bool HasPendingOrder() {
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      ulong ticket = OrderGetTicket(i);
      if(OrderSelect(ticket)) {
         if(OrderGetInteger(ORDER_MAGIC) == InpMagic && OrderGetString(ORDER_SYMBOL) == _Symbol) return true;
      }
   }
   return false;
}

bool IsPositionOpen() {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(m_position.SelectByIndex(i)) {
         if(m_position.Magic() == InpMagic && m_position.Symbol() == _Symbol) return true;
      }
   }
   return false;
}

void DeleteAllPendingOrders() {
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      ulong ticket = OrderGetTicket(i);
      if(OrderSelect(ticket)) {
         if(OrderGetInteger(ORDER_MAGIC) == InpMagic && OrderGetString(ORDER_SYMBOL) == _Symbol) {
            m_trade.OrderDelete(ticket);
         }
      }
   }
}
