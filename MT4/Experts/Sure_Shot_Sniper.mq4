//+------------------------------------------------------------------+
//|                                         Sure_Shot_Sniper.mq4     |
//|                                  Copyright 2026, Agent Hermes    |
//|                                        https://hermes-agent.com  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026"
#property version   "1.07"
#property strict

//--- ENUMS
enum ENUM_LOT_MODE {
   LOT_MODE_FIXED = 0,    // Fixed Lot
   LOT_MODE_RISK  = 1     // Risk Percentage
};

//--- INPUT PARAMETERS
input group "==== 🕒 SEASON-PROOF TIMING ===="
input int      InpSignalHour     = 9;          // Signal Candle Hour
input int      InpSignalMinute   = 0;          // Signal Candle Minute
input int      InpEntryHour      = 9;          // Entry Placement Hour
input int      InpEntryMinute    = 30;         // Entry Placement Minute
input int      InpExpiryHour     = 10;         // Expiration/Sweep Hour
input int      InpBrokerOffset   = 4;          // Broker Time Offset (Hours)

input group "==== 💰 RISK MANAGEMENT ===="
input ENUM_LOT_MODE InpLotMode  = LOT_MODE_RISK; // Lot Calculation Mode
input double   InpFixedLot      = 0.10;       // Fixed Lot Size
input double   InpRiskPercent   = 1.0;        // Risk % of Balance
input int      InpStopLoss      = 25;         // Stop Loss (Points)
input int      InpTakeProfit    = 75;         // Take Profit (Points)

input group "==== 🛡️ TRADE MANAGEMENT (PRO) ===="
input bool     InpUseManagement = true;       // Enable Break-Even & Trailing
input int      InpBE_Trigger    = 20;         // Break-Even Trigger (Points)
input int      InpBE_Level      = 5;          // Break-Even Security (Points)
input int      InpTS_Start      = 30;         // Trailing Start Trigger (Points)
input int      InpTS_Level      = 20;         // Trailing Lock-in (Points)
input int      InpTS_Step       = 5;          // Trailing Step (Points)

input group "==== 🔍 ADDITIONAL SETTINGS ===="
input int      InpDojiPoints    = 300;        // Doji Definition (Points)
input bool     InpEnableIndexFilter = true;   // Enable Index Symbol Filter
input string   InpIndexKeywords = "US30,NAS,USTEC,DJI,NQ,YM"; // Index Keywords
input int      InpMagicNumber   = 888888;     // Magic Number

//--- GLOBALS
datetime       m_last_trade_day = 0;
bool           m_daily_attempt  = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   if(InpEnableIndexFilter && !IsIndexSymbol(Symbol())) {
      Print("⚠️ [ERROR]: Not an index. EA halted.");
      return(INIT_FAILED);
   }
   Print("🚀 [SUCCESS]: Sure.shot Sniper V1.07 Loaded.");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   MqlDateTime dt;
   datetime now = TimeCurrent();
   TimeToStruct(now, dt);

   // 1. DAILY RESET
   datetime current_day = iTime(Symbol(), PERIOD_D1, 0);
   if(current_day > m_last_trade_day) {
      m_daily_attempt = false;
      m_last_trade_day = current_day;
   }

   // 2. THE HARD SWEEP (Cleanup at Expiry Hour)
   if(dt.hour == InpExpiryHour && dt.min == 0) {
      PerformHardSweep(dt);
   }

   // 3. TRADE MANAGEMENT (BE & Trailing)
   if(InpUseManagement) {
      ManageTrades();
   }

   // 4. ENTRY LOGIC
   if(!m_daily_attempt && dt.hour == InpEntryHour && dt.min == InpEntryMinute) {
      ExecuteStrategy(dt);
   }
}

//+------------------------------------------------------------------+
//| The Hard Sweep: Deletes Pending AND Closes Active Trades         |
//+------------------------------------------------------------------+
void PerformHardSweep(MqlDateTime &dt) {
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == InpMagicNumber) {
               if(OrderType() > 1) { 
                  if(OrderDelete(OrderTicket())) Print("🗑️ [SWEEP]: Pending Deleted.");
               } else { 
                  double cp = (OrderType() == OP_BUY) ? Bid : Ask;
                  if(OrderClose(OrderTicket(), OrderLots(), cp, 3, clrWhite)) Print("🛑 [SWEEP]: Active Closed.");
               }
            }
         }
      }
      m_daily_attempt = true; 
   }
}

//+------------------------------------------------------------------+
//| Advanced Trade Management (BE & Step-Trailing)                   |
//+------------------------------------------------------------------+
void ManageTrades() {
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == InpMagicNumber) {
            if(OrderType() > 1) continue; 

            double entry = OrderOpenPrice();
            double sl    = OrderStopLoss();
            double tp    = OrderTakeProfit();
            double cur_p = (OrderType() == OP_BUY) ? Bid : Ask;
            double profit = (OrderType() == OP_BUY) ? (cur_p - entry)/Point : (entry - cur_p)/Point;

            // --- 1. BREAK-EVEN LOGIC ---
            if(profit >= InpBE_Trigger) {
               double target_be = (OrderType() == OP_BUY) ? entry + (InpBE_Level * Point) : entry - (InpBE_Level * Point);
               bool can_move = (OrderType() == OP_BUY) ? (target_be > sl || sl == 0) : (target_be < sl || sl == 0);
               if(can_move) {
                  if(OrderModify(OrderTicket(), entry, target_be, tp, 0, clrGreen)) Print("🛡️ [BE]");
               }
            }

            // --- 2. STEP-TRAILING LOGIC ---
            if(profit >= InpTS_Start) {
               double target_sl = 0;
               int steps = (int)MathFloor((profit - InpTS_Start) / InpTS_Step);
               
               if(OrderType() == OP_BUY) {
                  target_sl = entry + (InpTS_Level * Point) + (steps * InpTS_Step * Point);
                  if(target_sl > sl + (1 * Point)) {
                     if(OrderModify(OrderTicket(), entry, target_sl, tp, 0, clrBlue)) Print("📈 [TRAIL]");
                  }
               } else { 
                  target_sl = entry - (InpTS_Level * Point) - (steps * InpTS_Step * Point);
                  if(target_sl < sl - (1 * Point) || sl == 0) {
                     if(OrderModify(OrderTicket(), entry, target_sl, tp, 0, clrRed)) Print("📉 [TRAIL]");
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Core Strategy Logic                                              |
//+------------------------------------------------------------------+
void ExecuteStrategy(MqlDateTime &dt) {
   string date_str = IntegerToString(dt.year)+"."+IntegerToString(dt.mon)+"."+IntegerToString(dt.day);
   string target_signal_str = IntegerToString(InpSignalHour, 2, '0') + ":" + IntegerToString(InpSignalMinute, 2, '0');
   datetime ny_signal_start = StringToTime(date_str + " " + target_signal_str);
   datetime broker_signal_start = ny_signal_start + (InpBrokerOffset * 3600);

   int signal_index = iBarShift(Symbol(), PERIOD_M30, broker_signal_start);
   if(signal_index < 0) return;

   double open_p  = iOpen(Symbol(), PERIOD_M30, signal_index);
   double close_p = iClose(Symbol(), PERIOD_M30, signal_index);
   double high_p  = iHigh(Symbol(), PERIOD_M30, signal_index);
   double low_p   = iLow(Symbol(), PERIOD_M30, signal_index);
   double body    = MathAbs(open_p - close_p);
   
   // --- DOJI CHECK (Fixed Point Definition) ---
   if(body <= InpDojiPoints * Point) {
      Print("ℹ️ [SKIP]: Signal candle is a Doji (", body/Point, " pts). No trade.");
      m_daily_attempt = true;
      return;
   }

   double sl = 0, tp = 0;
   double lot = CalculateLotSize(); 

   if(close_p > open_p) { // Bullish -> Sell Stop
      sl = open_p + (InpStopLoss * Point);
      tp = open_p - (InpTakeProfit * Point);
      if(OrderSend(Symbol(), OP_SELLSTOP, lot, open_p, 3, sl, tp, "SureShot", InpMagicNumber, 0, clrRed) > 0) {
         Print("🎯 [ENTRY]: Sell Stop placed.");
         m_daily_attempt = true;
      }
   } 
   else if(close_p < open_p) { // Bearish -> Buy Stop
      sl = open_p - (InpStopLoss * Point);
      tp = open_p + (InpTakeProfit * Point);
      if(OrderSend(Symbol(), OP_BUYSTOP, lot, open_p, 3, sl, tp, "SureShot", InpMagicNumber, 0, clrBlue) > 0) {
         Print("🎯 [ENTRY]: Buy Stop placed.");
         m_daily_attempt = true;
      }
   }
}

//+------------------------------------------------------------------+
//| Helper Functions                                                 |
//+------------------------------------------------------------------+
double CalculateLotSize() {
   if(InpLotMode == LOT_MODE_FIXED) return InpFixedLot;
   double risk_amt = AccountBalance() * (InpRiskPercent / 100.0);
   double tick_val = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tick_sz  = MarketInfo(Symbol(), MODE_TICKSIZE);
   if(tick_val == 0 || tick_sz == 0) return InpFixedLot;
   double lot = risk_amt / ((InpStopLoss * Point) * (tick_val / tick_sz));
   return NormalizeDouble(MathMax(MarketInfo(Symbol(), MODE_MINLOT), MathMin(MarketInfo(Symbol(), MODE_MAXLOT), lot)), 2);
}

bool IsIndexSymbol(string symbol) {
   if(!InpEnableIndexFilter) return true;
   string sym = symbol; StringToUpper(sym);
   string keywords[];
   int count = StringSplit(InpIndexKeywords, ',', keywords);
   for(int i=0; i<count; i++) {
      string kw = keywords[i]; StringTrimLeft(kw); StringTrimRight(kw); StringToUpper(kw);
      if(StringFind(sym, kw) >= 0) return true;
   }
   return false;
}
```,path: