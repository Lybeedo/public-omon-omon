//+------------------------------------------------------------------+
//|                                       CrossTrendMA_Breakout.mq5  |
//|                                    Combo: MA Crossing + Breakout |
//+------------------------------------------------------------------+
#property copyright "Trader Nakal"
#property link      ""
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Generic\StringCompare.mqh>

CTrade trade;

input group="=== MA Settings (Crossover) ==="
input int InpMAPeriodFast = 13;           // Fast MA Period
input int InpMAPeriodSlow = 30;           // Slow MA Period
input ENUM_MA_METHOD InpMAMethod = MODE_EMA; // Moving Average Method

input group="=== Breakout Settings ==="
input int InpBreakoutDepth = 20;          // Lookback Period (Bars)

input group="=== Dynamic SL & Trailing ==="
input int InpATRPeriod = 14;              // ATR Period
input double InpSL_Attribute = 1.5;      // Initial SL (Multiplier x ATR)
input double InpTrailing_Attrib = 1.0;   // Trailing Dist (Multiplier x ATR)

input group="=== Money Management ==="
input double InpLotSize = 0.01;           // Fixed Lot Size

input group="=== Timeframe Toggle ==="
input ENUM_TIMEFRAMES InpChartTF = PERIOD_H1; // Indicator Timeframe

int MagicNum = 789456;
double TickSize, PointVal;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNum);
   trade.SetDeviationInPoints(20);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   PointVal = _Point;
   TickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   
   if(InpChartTF == PERIOD_CURRENT)
      Print("Signal TF: ", StringSubstr(EnumToString(InpChartTF), 7));
   else
      Print("Signal TF: ", StringSubstr(EnumToString(InpChartTF), 7));
      
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. Handle Existing Positions (Trailing SL)
   ManageTrailingStop();
   
   // 2. Skip if position exists (Single position strategy per symbol)
   if(PositionsTotal() > 0) return;

   // 3. Fetch Indicators on Selected Timeframe
   int handleMAFast = iMA(_Symbol, InpChartTF, InpMAPeriodFast, 0, InpMAMethod, PRICE_CLOSE);
   int handleMASlow = iMA(_Symbol, InpChartTF, InpMAPeriodSlow, 0, InpMAMethod, PRICE_CLOSE);
   int handleATR = iATR(_Symbol, InpChartTF, InpATRPeriod);

   double valFast[2], valSlow[2], valATR[2];
   CopyBuffer(handleMAFast, 0, 0, 2, valFast); // Index 0 (Current), 1 (Previous)
   CopyBuffer(handleMASlow, 0, 0, 2, valSlow);
   CopyBuffer(handleATR, 0, 0, 2, valATR);
   
   // Ensure we have valid data
   if(valATR[0] <= 0 || valFast[0] == EMPTY_VALUE || valSlow[0] == EMPTY_VALUE) return;
   
   double currentATR = valATR[0];
   double trailDist = currentATR * InpTrailing_Attrib;
   
   // 4. Determine Breakout Levels (From PREVIOUS closed candles)
   double maxHigh = 0;
   double minLow = 99999999;
   
   // Scan from 1 to Depth (skipping 0 which is current incomplete candle)
   for(int i=1; i<=InpBreakoutDepth; i++) {
      double h = iHigh(_Symbol, InpChartTF, i);
      double l = iLow(_Symbol, InpChartTF, i);
      if(h > maxHigh) maxHigh = h;
      if(l < minLow) minLow = l;
   }

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // 5. Check Trend Direction (Latest Closed Values)
   // Using [1] ensures we react on the OPEN of the new candle after cross completed
   bool trendUp = (valFast[1] > valSlow[1]);
   bool trendDown = (valFast[1] < valSlow[1]);

   // 6. Execute Entries
   if(trendUp) {
      // Buy Trigger: Price breaks highest high of lookback
      if(ask > maxHigh) {
         double sl = (trailDist > 0) ? ask - trailDist : ask - (100 * PointVal); // Fallback SL
         trade.Buy(InpLotSize, _Symbol, ask, sl, 0, "CrossMA Buy");
      }
   } 
   else if(trendDown) {
      // Sell Trigger: Price breaks lowest low of lookback
      if(bid < minLow) {
         double sl = (trailDist > 0) ? bid + trailDist : bid + (100 * PointVal);
         trade.Sell(InpLotSize, _Symbol, bid, sl, 0, "CrossMA Sell");
      }
   }

   // Cleanup handles
   CloseHandle(handleMAFast);
   CloseHandle(handleMASlow);
   CloseHandle(handleATR);
}

//+------------------------------------------------------------------+
//| Dynamic Trailing Stop                                            |
//+------------------------------------------------------------------+
void ManageTrailingStop(void)
{
   if(!PositionSelect(_Symbol)) return;
   
   int handleATR = iATR(_Symbol, InpChartTF, InpATRPeriod);
   double atrVal[1];
   CopyBuffer(handleATR, 0, 0, 1, atrVal);
   double trailDist = atrVal[0] * InpTrailing_Attrib;
   
   ulong ticket = PositionGetTicket(0);
   long posType = PositionGetInteger(POSITION_TYPE);
   double openP = PositionGetDouble(POSITION_PRICE_OPEN);
   double curSL = PositionGetDouble(POSITION_SL);
   double tp = PositionGetDouble(POSITION_TP);
   
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double minSLStep = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * PointVal;
   if(minSLStep < 10 * PointVal) minSLStep = 10 * PointVal; // Safety default

   if(posType == POSITION_TYPE_BUY) {
      // Only trail if profit > 0
      if(bid > openP + minSLStep) {
         double newSL = bid - trailDist;
         if(newSL > curSL + minSLStep) {
            trade.PositionModify(ticket, NormalizeDouble(newSL, Digits()), tp);
         }
      }
   } 
   else if(posType == POSITION_TYPE_SELL) {
      if(ask < openP - minSLStep) {
         double newSL = ask + trailDist;
         if(curSL == 0 || newSL < curSL - minSLStep) {
            trade.PositionModify(ticket, NormalizeDouble(newSL, Digits()), tp);
         }
      }
   }
   
   CloseHandle(handleATR);
}
