//+------------------------------------------------------------------+
//|                                    BreakoutPullback.mq4          |
//|                        Breakout & Pullback Trading EA            |
//|                          Gold (XAUUSD) H1                        |
//+------------------------------------------------------------------+
#property copyright "7NAGA System"
#property strict
#property indicator_chart_window

//+------------------------------------------------------------------+
//| Digit & Pip Auto-Detect (MANDATORY)                              |
//+------------------------------------------------------------------+
#define GDigits ((int)MarketInfo(_Symbol, MODE_DIGITS))
#define GPoint  (MarketInfo(_Symbol, MODE_POINT))
#define GPip    ((GDigits == 3 || GDigits == 5) ? GPoint * 10 : GPoint)

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input int    InpRangeBars    = 20;       // Range detection bars
input double InpMinRange     = 100.0;    // Min range size (pips)
input int    InpRetestBars   = 5;        // Max bars for retest
input double InpATROffset    = 1.5;      // ATR multiplier for SL
input int    InpATRPeriod    = 14;       // ATR period
input double InpRiskPercent  = 2.0;     // Risk per trade (%)
input int    InpMaxSpread    = 30;       // Max spread (pips)
input int    InpMagicNumber  = 99999;    // Magic number
input int    InpMaxTrades    = 1;        // Max open trades
input double InpTrailStart   = 1.0;      // Trailing start (R)
//+------------------------------------------------------------------+
//| State Machine                                                    |
//+------------------------------------------------------------------+
enum ESTATE {
   STATE_IDLE,
   STATE_BREAKOUT_UP,
   STATE_BREAKOUT_DOWN,
   STATE_PULLBACK_LONG,
   STATE_PULLBACK_SHORT,
   STATE_ACTIVE_LONG,
   STATE_ACTIVE_SHORT,
   STATE_TP1_LONG,
   STATE_TP1_SHORT,
   STATE_COMPLETE
};

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
ESTATE gState = STATE_IDLE;
datetime gLastBarTime = 0;
datetime gSetupBarTime = 0;
double gHighestHigh = 0;
double gLowestLow = 0;
double gBreakoutLevel = 0;
double gRetestLevel = 0;
double gATRVal = 0;
int   gBreakoutBar = 0;
double gSLPrice = 0;
double gTP1Price = 0;
double gTP2Price = 0;
double gRiskPoints = 0;
double gLotSize = 0;
bool   gTp1Hit = false;
datetime gLastTradeTime = 0;

//+------------------------------------------------------------------+
//| Utility Functions                                                 |
//+------------------------------------------------------------------+
double ATR(int period) {
   double sum = 0;
   for (int i = 1; i <= period; i++) {
      double tr = MathMax(High[i] - Low[i],
            MathMax(MathAbs(High[i] - Close[i+1]), MathAbs(Low[i] - Close[i+1])));
      sum += tr;
   }
   return sum / period;
}

double PointsToPips(double pts) {
   return pts / GPip;
}

double PipsToPoints(double pips) {
   return pips * GPip;
}

int GetSpread() {
   return (int)MarketInfo(_Symbol, MODE_SPREAD);
}

bool IsTradeAllowed() {
   if (!IsTradeAllowed()) return false;
   if (GetSpread() > InpMaxSpread) return false;
   // Skip high-impact news (manual check recommended)
   return true;
}

//+------------------------------------------------------------------+
//| Calculate Lot Size based on Risk %                                |
//+------------------------------------------------------------------+
double CalcLot(double slDistancePips) {
   double accountBal = AccountBalance();
   double riskAmt = accountBal * (InpRiskPercent / 100.0);
   double tickVal = MarketInfo(_Symbol, MODE_TICKVALUE);
   double tickSize = MarketInfo(_Symbol, MODE_TICKSIZE);
   double lotStep  = MarketInfo(_Symbol, MODE_LOTSTEP);
   
   if (slDistancePips <= 0) slDistancePips = 50;
   
   double lot = riskAmt / (slDistancePips * GPip * tickVal / tickSize);
   lot = MathFloor(lot / lotStep) * lotStep;
   lot = MathMax(lot, MarketInfo(_Symbol, MODE_MINLOT));
   lot = MathMin(lot, MarketInfo(_Symbol, MODE_MAXLOT));
   return lot;
}

//+------------------------------------------------------------------+
//| Detect Range & Breakout                                           |
//+------------------------------------------------------------------+
bool DetectSetup() {
   if (InpRangeBars < 3) return false;
   
   double highest = High[1];
   double lowest  = Low[1];
   
   for (int i = 2; i <= InpRangeBars; i++) {
       if (High[i] > highest) highest = High[i];
       if (Low[i]  < lowest)  lowest  = Low[i];
   }
   
   double rangePips = PointsToPips(highest - lowest);
   
   if (rangePips < InpMinRange) {
      gState = STATE_IDLE;
      return false;
   }
   
   gHighestHigh = highest;
   gLowestLow   = lowest;
   gATRVal      = ATR(InpATRPeriod);
   
   // Check for breakout on current bar (index 0 = current)
   double close = Close[0];
   double open  = Open[0];
   
   // Bullish breakout: close above highest high
   if (close > gHighestHigh && open <= gHighestHigh) {
      gState        = STATE_BREAKOUT_UP;
      gBreakoutLevel = gHighestHigh;
      gBreakoutBar   = 0;
      gLastBarTime   = Time[0];
      return true;
   }
   
   // Bearish breakout: close below lowest low
   if (close < gLowestLow && open >= gLowestLow) {
      gState        = STATE_BREAKOUT_DOWN;
      gBreakoutLevel = gLowestLow;
      gBreakoutBar   = 0;
      gLastBarTime   = Time[0];
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Detect Pullback Entry                                             |
//+------------------------------------------------------------------+
bool DetectPullbackEntry(int& dir) {
   if (gState != STATE_BREAKOUT_UP && gState != STATE_BREAKOUT_DOWN)
      return false;
   
   // Wait for retest within InpRetestBars bars
   for (int i = 1; i <= InpRetestBars; i++) {
      if (i > Bars - 1) break;
      
      if (gState == STATE_BREAKOUT_UP) {
         // Pullback Buy: price kembali ke level breakout dan naik
         if (Low[i] <= gBreakoutLevel && Close[i] > Open[i]) {
            gRetestLevel = MathMin(gBreakoutLevel, Low[i]);
            dir = 1; // BUY
            return true;
         }
      }
      
      if (gState == STATE_BREAKOUT_DOWN) {
         // Pullback Sell: price kembali ke level breakout dan turun
         if (High[i] >= gBreakoutLevel && Close[i] < Open[i]) {
            gRetestLevel = MathMax(gBreakoutLevel, High[i]);
            dir = -1; // SELL
            return true;
         }
      }
   }
   
   // Timeout: no pullback within retest bars
   if (gState == STATE_BREAKOUT_UP || gState == STATE_BROKEN) {
      gState = STATE_IDLE;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Calculate SL & TP                                                 |
//+------------------------------------------------------------------+
void CalculateSLTP(int dir) {
   double atrPips = PointsToPips(gATRVal * InpATROffset);
   
   if (dir == 1) { // BUY
      gSLPrice  = gRetestLevel - PipsToPoints(atrPips);
      gRiskPoints = PointsToPips(Close[0] - gSLPrice);
   } else { // SELL
      gSLPrice  = gRetestLevel + PipsToPoints(atrPips);
      gRiskPoints = PointsToPips(gSLPrice - Close[0]);
   }
   
   // TP1 = 1R, TP2 = 2R
   if (dir == 1) {
      gTP1Price = Close[0] + PipsToPoints(gRiskPoints);
      gTP2Price = Close[0] + PipsToPoints(gRiskPoints * 2);
   } else {
      gTP1Price = Close[0] - PipsToPoints(gRiskPoints);
      gTP2Price = Close[0] - PipsToPoints(gRiskPoints * 2);
   }
   
   gLotSize = CalcLot(gRiskPoints);
}

//+------------------------------------------------------------------+
//| Send Order with SL & TP                                           |
//+------------------------------------------------------------------+
bool SendOrder(int type, double price, double sl, double tp, double lot, int magic) {
   color c = (type == OP_BUY) ? clrLime : clrRed;
   
   int ticket = OrderSend(_Symbol, type, lot, price, 3, sl, tp, "BP-EA", magic, 0, c);
   
   if (ticket > 0) {
      Print("Order sent: ", type == OP_BUY ? "BUY" : "SELL",
            " Price:", price, " SL:", sl, " TP:", tp, " Lot:", lot);
      return true;
   } else {
      Print("OrderSend failed: ", GetLastError());
      return false;
   }
}

//+------------------------------------------------------------------+
//| Check & Manage Open Positions                                     |
//+------------------------------------------------------------------+
void ManagePositions() {
   for (int i = OrdersTotal() - 1; i >= 0; i--) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderSymbol() != _Symbol || OrderMagicNumber() != InpMagicNumber) continue;
      
      double openPrice = OrderOpenPrice();
      double curPrice  = (OrderType() == OP_BUY) ? Bid : Ask;
      double profitPips = PointsToPips(OrderProfit());
      
      // Check TP1
      if (!gTp1Hit) {
         if (OrderType() == OP_BUY && curPrice >= gTP1Price) {
            if (!OrderModify(OrderTicket(), openPrice, OrderStopLoss(), gTP2Price, 0, clrLime)) {
               Print("Modify TP1 failed: ", GetLastError());
            } else {
               gTp1Hit = true;
               Print("TP1 hit - SL moved to BE, TP2 set to ", gTP2Price);
            }
         } else if (OrderType() == OP_SELL && curPrice <= gTP1Price) {
            if (!OrderModify(OrderTicket(), openPrice, OrderStopLoss(), gTP2Price, 0, clrRed)) {
               Print("Modify TP1 failed: ", GetLastError());
            } else {
               gTp1Hit = true;
               Print("TP1 hit - SL moved to BE, TP2 set to ", gTP2Price);
            }
         }
      }
      
      // Trailing stop after TP1
      if (gTp1Hit && InpTrailStart > 0) {
         double trailDist = gRiskPoints * InpTrailStart;
         if (OrderType() == OP_BUY) {
            double newSL = curPrice - PipsToPoints(gRiskPoints * 0.5);
            if (newSL > OrderStopLoss()) {
               OrderModify(OrderTicket(), openPrice, newSL, OrderTakeProfit(), 0, clrLime);
            }
         } else if (OrderType() == OP_SELL) {
            double newSL = curPrice + PipsToPoints(gRiskPoints * 0.5);
            if (newSL < OrderStopLoss()) {
               OrderModify(OrderTicket(), openPrice, newSL, OrderTakeProfit(), 0, clrRed);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Count Open Trades                                                 |
//+------------------------------------------------------------------+
int CountTrades() {
   int cnt = 0;
   for (int i = OrdersTotal() - 1; i >= 0; i--) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderSymbol() == _Symbol && OrderMagicNumber() == InpMagicNumber) cnt++;
   }
   return cnt;
}

//+------------------------------------------------------------------+
//| Main Execution Loop                                               |
//+------------------------------------------------------------------+
void OnTick() {
   // Only process on new bar
   if (Time[0] == gLastBarTime && gState != STATE_ACTIVE_LONG && gState != STATE_ACTIVE_SHORT) return;
   gLastBarTime = Time[0];
   
   ManagePositions();
   
   int openTrades = CountTrades();
   if (openTrades >= InpMaxTrades) return;
   
   // === STATE MACHINE ===
   switch (gState) {
      case STATE_IDLE: {
         if (!IsTradeAllowed()) return;
         if (DetectSetup()) {
            // Wait for pullback
            if (gState == STATE_BREAKOUT_UP) {
               gState = STATE_PULLBACK_LONG;
               Alert("Breakout UP detected — waiting for pullback at ", DoubleToStr(gBreakoutLevel, _Digits));
            } else if (gState == STATE_BREAKOUT_DOWN) {
               gState = STATE_PULLBACK_SHORT;
               Alert("Breakout DOWN detected — waiting for pullback at ", DoubleToStr(gBreakoutLevel, _Digits));
            }
         }
         break;
      }
      
      case STATE_PULLBACK_LONG: {
         int dir = 0;
         if (DetectPullbackEntry(dir) && dir == 1) {
            CalculateSLTP(dir);
            if (SendOrder(OP_BUY, Ask, gSLPrice, gTP2Price, gLotSize, InpMagicNumber)) {
               gState = STATE_ACTIVE_LONG;
               gLastTradeTime = TimeCurrent();
               gTp1Hit = false;
               Comment("BreakoutPullback EA | State: ACTIVE LONG | Entry: ",
                       DoubleToStr(Ask, _Digits), " | SL: ", DoubleToStr(gSLPrice, _Digits),
                       " | TP1: ", DoubleToStr(gTP1Price, _Digits), " | TP2: ", DoubleToStr(gTP2Price, _Digits));
            }
         }
         // Timeout: clear state after retest window passed
         if (Time[0] - gLastBarTime > InpRetestBars * 3600) {
            gState = STATE_IDLE;
         }
         break;
      }
      
      case STATE_PULLBACK_SHORT: {
         int dir = 0;
         if (DetectPullbackEntry(dir) && dir == -1) {
            CalculateSLTP(dir);
            if (SendOrder(OP_SELL, Bid, gSLPrice, gTP2Price, gLotSize, InpMagicNumber)) {
               gState = STATE_ACTIVE_SHORT;
               gLastTradeTime = TimeCurrent();
               gTp1Hit = false;
               Comment("BreakoutPullback EA | State: ACTIVE SHORT | Entry: ",
                       DoubleToStr(Bid, _Digits), " | SL: ", DoubleToStr(gSLPrice, _Digits),
                       " | TP1: ", DoubleToStr(gTP1Price, _Digits), " | TP2: ", DoubleToStr(gTP2Price, _Digits));
            }
         }
         // Timeout: clear state after retest window passed
         if (Time[0] - gLastBarTime > InpRetestBars * 3600) {
            gState = STATE_IDLE;
         }
         break;
      }
      
      case STATE_ACTIVE_LONG:
      case STATE_ACTIVE_SHORT: {
         // Wait for trade to close, then reset to IDLE
         if (openTrades == 0) {
            gState = STATE_IDLE;
            Comment("");
         }
         break;
      }
   }
}

//+------------------------------------------------------------------+
//| Initialization                                                    |
//+------------------------------------------------------------------+
int OnInit() {
   Comment("BreakoutPullback EA loaded | RangeBars:", InpRangeBars,
           " | MinRange:", DoubleToStr(InpMinRange, 1), " pips | Risk:", InpRiskPercent, "%");
   gState = STATE_IDLE;
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Deinitialization                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   Comment("");
}
//+------------------------------------------------------------------+