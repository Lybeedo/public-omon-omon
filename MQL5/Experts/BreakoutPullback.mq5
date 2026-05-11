//+------------------------------------------------------------------+
//|                              BreakoutPullback.mq5                |
//|                        Breakout & Pullback Trading EA            |
//|                          Gold (XAUUSD) H1                        |
//+------------------------------------------------------------------+
#property copyright "7NAGA System"
#property version   "1.00"
#property script_show_inputs

#include <Trade\Trade.mqh>

//--- Include MTF + Market Structure Filter Module
#include <SMC_Filter.mqh>

//+------------------------------------------------------------------+
//| Digit & Pip Auto-Detect (MANDATORY)                              |
//+------------------------------------------------------------------+
int    GDigits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
double GPoint  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
double GPip    = (GDigits == 3 || GDigits == 5) ? GPoint * 10 : GPoint;

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
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_H1; // Chart timeframe

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
   STATE_COMPLETE
};

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
ESTATE     gState = STATE_IDLE;
datetime   gLastBarTime = 0;
double     gHighestHigh = 0;
double     gLowestLow   = 0;
double     gBreakoutLevel = 0;
double     gRetestLevel = 0;
double     gATRVal = 0;
int        gBreakoutBar = 0;
double     gSLPrice = 0;
double     gTP1Price = 0;
double     gTP2Price = 0;
double     gRiskPoints = 0;
double     gLotSize = 0;
bool       gTp1Hit = false;
CTrade     gTrade;
CSMCFilter  g_SMCFilter;   // MTF + Market Structure Filter Instance

//+------------------------------------------------------------------+
//| ATR Calculation                                                  |
//+------------------------------------------------------------------+
double ATR(int period, ENUM_TIMEFRAMES tf) {
   double sum = 0;
   for (int i = 1; i <= period; i++) {
      double tr = MathMax(High(i, tf, i) - Low(i, tf, i),
            MathMax(MathAbs(High(i, tf, i) - Close(i, tf, i+1)),
                    MathAbs(Low(i, tf, i) - Close(i, tf, i+1))));
      sum += tr;
   }
   return sum / period;
}

double High(int shift, ENUM_TIMEFRAMES tf, int bar) { return iHigh(_Symbol, tf, bar + shift); }
double Low(int shift, ENUM_TIMEFRAMES tf, int bar)  { return iLow(_Symbol, tf, bar + shift); }
double Close(int shift, ENUM_TIMEFRAMES tf, int bar) { return iClose(_Symbol, tf, bar + shift); }
datetime Time(int shift, ENUM_TIMEFRAMES tf, int bar) { return iTime(_Symbol, tf, bar + shift); }

double PointsToPips(double pts) {
   return pts / GPip;
}

double PipsToPoints(double pips) {
   return pips * GPip;
}

//+------------------------------------------------------------------+
//| Calculate Lot Size                                                |
//+------------------------------------------------------------------+
double CalcLot(double slDistancePips) {
   double accountBal = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmt = accountBal * (InpRiskPercent / 100.0);
   
   if (slDistancePips <= 0) slDistancePips = 50;
   
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double lotStep   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   
   double lot = riskAmt / (slDistancePips * GPip * tickValue / tickSize);
   lot = MathFloor(lot / lotStep) * lotStep;
   lot = MathMax(lot, minLot);
   lot = MathMin(lot, maxLot);
   return lot;
}

//+------------------------------------------------------------------+
//| Detect Range & Breakout (bar 0 = current)                        |
//+------------------------------------------------------------------+
bool DetectSetup() {
   if (InpRangeBars < 3) return false;
   
   double highest = High(1, InpTimeframe, 1);
   double lowest  = Low(1, InpTimeframe, 1);
   
   for (int i = 2; i <= InpRangeBars; i++) {
       if (High(1, InpTimeframe, i) > highest) highest = High(1, InpTimeframe, i);
       if (Low(1, InpTimeframe, i)  < lowest)  lowest  = Low(1, InpTimeframe, i);
   }
   
   double rangePips = PointsToPips(highest - lowest);
   
   if (rangePips < InpMinRange) {
      gState = STATE_IDLE;
      return false;
   }
   
   gHighestHigh = highest;
   gLowestLow    = lowest;
   gATRVal       = ATR(InpATRPeriod, InpTimeframe);
   
   double close0 = Close(1, InpTimeframe, 0);
   double open0  = Open(1, InpTimeframe, 0);
   double high0  = High(1, InpTimeframe, 0);
   double low0   = Low(1, InpTimeframe, 0);
   
   // Bullish breakout: close above highest high
   if (close0 > gHighestHigh && open0 <= gHighestHigh) {
      gState         = STATE_BREAKOUT_UP;
      gBreakoutLevel  = gHighestHigh;
      gBreakoutBar    = 0;
      gLastBarTime    = Time(1, InpTimeframe, 0);
      return true;
   }
   
   // Bearish breakout: close below lowest low
   if (close0 < gLowestLow && open0 >= gLowestLow) {
      gState         = STATE_BREAKOUT_DOWN;
      gBreakoutLevel  = gLowestLow;
      gBreakoutBar    = 0;
      gLastBarTime    = Time(1, InpTimeframe, 0);
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Detect Pullback Entry                                            |
//+------------------------------------------------------------------+
bool DetectPullbackEntry(int& dir) {
   if (gState != STATE_BREAKOUT_UP && gState != STATE_BREAKOUT_DOWN)
      return false;
   
   for (int i = 1; i <= InpRetestBars; i++) {
      
      if (gState == STATE_BREAKOUT_UP) {
         double lowI  = Low(1, InpTimeframe, i);
         double closeI = Close(1, InpTimeframe, i);
         double openI  = Open(1, InpTimeframe, i);
         
         if (lowI <= gBreakoutLevel && closeI > openI) {
            gRetestLevel = MathMin(gBreakoutLevel, lowI);
            dir = 1;
            return true;
         }
      }
      
      if (gState == STATE_BREAKOUT_DOWN) {
         double highI  = High(1, InpTimeframe, i);
         double closeI = Close(1, InpTimeframe, i);
         double openI  = Open(1, InpTimeframe, i);
         
         if (highI >= gBreakoutLevel && closeI < openI) {
            gRetestLevel = MathMax(gBreakoutLevel, highI);
            dir = -1;
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Calculate SL & TP                                                 |
//+------------------------------------------------------------------+
void CalculateSLTP(int dir) {
   double atrPips = PointsToPips(gATRVal * InpATROffset);
   double entryPrice = Close(1, InpTimeframe, 0);
   
   if (dir == 1) { // BUY
      gSLPrice   = gRetestLevel - PipsToPoints(atrPips);
      gRiskPoints = PointsToPips(entryPrice - gSLPrice);
   } else { // SELL
      gSLPrice   = gRetestLevel + PipsToPoints(atrPips);
      gRiskPoints = PointsToPips(gSLPrice - entryPrice);
   }
   
   if (gRiskPoints <= 0) gRiskPoints = 50;
   
   // TP1 = 1R, TP2 = 2R
   if (dir == 1) {
      gTP1Price = entryPrice + PipsToPoints(gRiskPoints);
      gTP2Price = entryPrice + PipsToPoints(gRiskPoints * 2);
   } else {
      gTP1Price = entryPrice - PipsToPoints(gRiskPoints);
      gTP2Price = entryPrice - PipsToPoints(gRiskPoints * 2);
   }
   
   gLotSize = CalcLot(gRiskPoints);
}

//+------------------------------------------------------------------+
//| Count Open Trades                                                |
//+------------------------------------------------------------------+
int CountTrades() {
   int cnt = 0;
   for (int i = PositionsTotal() - 1; i >= 0; i--) {
      if (PositionGetSymbol(i) == _Symbol &&
          PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
         cnt++;
      }
   }
   return cnt;
}

//+------------------------------------------------------------------+
//| Send Order                                                       |
//+------------------------------------------------------------------+
bool SendOrder(int dir, double sl, double tp, double lot) {
   gTrade.SetExpertMagicNumber(InpMagicNumber);
   gTrade.SetDeviationInPoints(3);
   
   double price = (dir == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                              : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   color  c = (dir == 1) ? clrLime : clrRed;
   uint   type = (dir == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   
   bool res = gTrade.PositionOpen(_Symbol, type, lot, price, sl, tp);
   
   if (res) {
      Print("Order sent: ", type == ORDER_TYPE_BUY ? "BUY" : "SELL",
            " Price:", price, " SL:", sl, " TP:", tp, " Lot:", lot);
   } else {
      Print("PositionOpen failed: ", GetLastError());
   }
   
   return res;
}

//+------------------------------------------------------------------+
//| Manage Positions — TP1 partial close + trailing                  |
//+------------------------------------------------------------------+
void ManagePositions() {
   for (int i = PositionsTotal() - 1; i >= 0; i--) {
      if (!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if (PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      
      double openPrice = PositionGetDouble(POSITION_OPEN_PRICE);
      double curPrice  = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY
                         ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      ulong ticket = PositionGetInteger(POSITION_TICKET);
      
      // Check TP1
      if (!gTp1Hit) {
         if ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY
             && curPrice >= gTP1Price) {
            double newSL = openPrice; // Move SL to BE
            gTrade.PositionModify(ticket, newSL, gTP2Price);
            gTp1Hit = true;
            Print("TP1 hit - SL moved to BE, TP2 set to ", gTP2Price);
         } else if ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL
                    && curPrice <= gTP1Price) {
            double newSL = openPrice; // Move SL to BE
            gTrade.PositionModify(ticket, newSL, gTP2Price);
            gTp1Hit = true;
            Print("TP1 hit - SL moved to BE, TP2 set to ", gTP2Price);
         }
      }
      
      // Trailing stop after TP1
      if (gTp1Hit && InpTrailStart > 0) {
         double trailPips = gRiskPoints * 0.5;
         if ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
            double newSL = curPrice - PipsToPoints(trailPips);
            if (newSL > sl) gTrade.PositionModify(ticket, newSL, tp);
         } else {
            double newSL = curPrice + PipsToPoints(trailPips);
            if (newSL < sl) gTrade.PositionModify(ticket, newSL, tp);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Main OnTick                                                       |
//+------------------------------------------------------------------+
void OnTick() {
   datetime curBarTime = iTime(_Symbol, InpTimeframe, 0);
   
   // Only process on new bar (or allow continuous for pullback)
   bool newBar = (curBarTime != gLastBarTime);
   gLastBarTime = curBarTime;
   
   // Manage positions every tick
   ManagePositions();
   
   //=== REFRESH SMC FILTER ===
   g_SMCFilter.Refresh();
   
   int openTrades = CountTrades();
   
   // Reset after trade closed
   if (openTrades == 0 && (gState == STATE_ACTIVE_LONG || gState == STATE_ACTIVE_SHORT)) {
      gState = STATE_IDLE;
      Comment("");
      gTp1Hit = false;
   }
   
   if (openTrades >= InpMaxTrades) return;
   
   // State machine
   switch (gState) {
      case STATE_IDLE: {
         int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
         if (spread > InpMaxSpread) return;
         
         if (DetectSetup()) {
            if (gState == STATE_BREAKOUT_UP) {
               Alert("Breakout UP — waiting pullback at ", DoubleToStr(gBreakoutLevel, _Digits));
            } else if (gState == STATE_BREAKOUT_DOWN) {
               Alert("Breakout DOWN — waiting pullback at ", DoubleToStr(gBreakoutLevel, _Digits));
            }
         }
         break;
      }
      
      case STATE_BREAKOUT_UP:
      case STATE_BREAKOUT_DOWN: {
         // Wait for pullback
         int dir = 0;
         if (DetectPullbackEntry(dir)) {
            if (dir == 1 && gState == STATE_BREAKOUT_UP) {
               //=== MTF + MARKET STRUCTURE FILTER CHECK ===
               if(!g_SMCFilter.AllowLong()) {
                  Print("[SMC] BUY signal BLOCKED — D1/H4 trend or structure not aligned");
                  Print("[SMC] Status: ", g_SMCFilter.GetFilterInfo(), " | ", g_SMCFilter.GetDetailedInfo());
                  gState = STATE_IDLE;
                  break;
               }
               //=== END FILTER CHECK ===
               CalculateSLTP(dir);
               if (SendOrder(dir, gSLPrice, gTP2Price, gLotSize)) {
                  gState = STATE_ACTIVE_LONG;
                  gTp1Hit = false;
                  Print("[SMC] Trade opened. Trend: ", g_SMCFilter.GetFilterInfo());
                  Print("[SMC] Structure: ", g_SMCFilter.GetDetailedInfo());
                  Comment("Active LONG | SMC: ", g_SMCFilter.GetFilterInfo(),
                          " | ", g_SMCFilter.GetDetailedInfo(),
                          " | Entry:", DoubleToStr(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits),
                          " SL:", DoubleToStr(gSLPrice, _Digits),
                          " TP1:", DoubleToStr(gTP1Price, _Digits),
                          " TP2:", DoubleToStr(gTP2Price, _Digits));
               }
            } else if (dir == -1 && gState == STATE_BREAKOUT_DOWN) {
               //=== MTF + MARKET STRUCTURE FILTER CHECK ===
               if(!g_SMCFilter.AllowShort()) {
                  Print("[SMC] SELL signal BLOCKED — D1/H4 trend or structure not aligned");
                  Print("[SMC] Status: ", g_SMCFilter.GetFilterInfo(), " | ", g_SMCFilter.GetDetailedInfo());
                  gState = STATE_IDLE;
                  break;
               }
               //=== END FILTER CHECK ===
               CalculateSLTP(dir);
               if (SendOrder(dir, gSLPrice, gTP2Price, gLotSize)) {
                  gState = STATE_ACTIVE_SHORT;
                  gTp1Hit = false;
                  Print("[SMC] Trade opened. Trend: ", g_SMCFilter.GetFilterInfo());
                  Print("[SMC] Structure: ", g_SMCFilter.GetDetailedInfo());
                  Comment("Active SHORT | SMC: ", g_SMCFilter.GetFilterInfo(),
                          " | ", g_SMCFilter.GetDetailedInfo(),
                          " | Entry:", DoubleToStr(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits),
                          " SL:", DoubleToStr(gSLPrice, _Digits),
                          " TP1:", DoubleToStr(gTP1Price, _Digits),
                          " TP2:", DoubleToStr(gTP2Price, _Digits));
               }
            }
         }
         
         // Retest timeout — reset if no pullback after InpRetestBars
         datetime bar0Time = iTime(_Symbol, InpTimeframe, 0);
         if (gLastBarTime > 0 && (bar0Time - gLastBarTime) > InpRetestBars * 3600) {
            gState = STATE_IDLE;
         }
         break;
      }
   }
}

//+------------------------------------------------------------------+
//| Initialization                                                    |
//+------------------------------------------------------------------+
int OnInit() {
   gTrade.SetExpertMagicNumber(InpMagicNumber);
   gTrade.SetDeviationInPoints(3);
   Comment("BreakoutPullback EA | RangeBars:", InpRangeBars,
           " | MinRange:", DoubleToStr(InpMinRange, 1), " pips | Risk:", InpRiskPercent, "%",
           "\n[SMC] FVG:", g_FVG_Enabled ? "ON" : "OFF",
           " | Inducement:", g_IND_Enabled ? "ON" : "OFF",
           " | CHoCH:", g_CHOCH_Enabled ? "ON" : "OFF",
           " | OB:", g_OB_Enabled ? "ON" : "OFF",
           "\n", g_SMCFilter.GetFilterInfo());
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