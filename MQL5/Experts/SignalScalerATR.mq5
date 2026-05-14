//+------------------------------------------------------------------+
//|                                        SignalScalerATR_v1.0.mq5 |
//|                                          Copyright 7NAGA System |
//|                                                   Signal Scaler  |
//+------------------------------------------------------------------+
#property copyright   "7NAGA System"
#property version      "1.00"
#property strict
#property icon         ""

//+------------------------------------------------------------------+
//| Include Trade Library                                            |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Input Parameters - Signal                                        |
//+------------------------------------------------------------------+
input group "=== SIGNAL: EMA CROSSOVER ==="
input int    InpFastEMA      = 10;      // Fast EMA Period
input int    InpSlowEMA      = 20;      // Slow EMA Period

input group "=== SIGNAL: RSI ==="
input int    InpRSIPeriod    = 14;      // RSI Period
input double InpRSIBuyLevel  = 50.0;    // RSI Buy Level (below = oversold)
input double InpRSISellLevel = 50.0;    // RSI Sell Level (above = overbought)

input group "=== SIGNAL: VOLUME ==="
input double InpVolThreshold = 1.5;     // Volume multiplier vs MA (1.5x = spike)

input group "=== DISTANCE: ATR ==="
input int    InpATRPeriod    = 14;      // ATR Period
input double InpATRMultiplier = 1.5;    // ATR Multiplier (entry distance)
input double InpATRStopMult   = 2.0;    // ATR Multiplier (stop loss)

input group "=== LOT & RISK ==="
input double InpBaseLot      = 0.01;    // Base Lot Size
input double InpLotMultiplier = 1.5;    // Lot multiplier per step
input double InpMaxLots      = 0.16;    // Max total lot
input double InpRiskPercent  = 1.0;     // Risk per trade (%)

input group "=== ORDER MANAGEMENT ==="
input int    InpMaxPositions = 5;       // Max positions (scaling steps)
input int    InpMagicNumber  = 77777;   // Magic Number
input string InpComment      = "SignalScalerATR";

input group "=== FILTER ==="
input bool   InpAllowBuy     = true;    // Allow Buy signals
input bool   InpAllowSell    = true;    // Allow Sell signals
input int    InpSlippage     = 3;       // Slippage (points)

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CTrade       trade;
datetime     g_lastBarTime   = 0;
datetime     g_lastBarTimeH4 = 0;
bool         g_tradeActive   = false;
double       g_lotStep       = 0.0;
double       g_tickValue     = 0.0;
int          g_digits        = 0;
double       g_point          = 0.0;
double       g_pip            = 0.0;

//--- ATR buffers
double       g_atrValue      = 0.0;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // Detect digits & pip
   g_digits   = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_pip      = (g_digits == 3 || g_digits == 5) ? g_point * 10 : g_point;
   
   // Trade setup
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   
   // Lot step
   g_lotStep  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   Print("[SignalScalerATR] Initialized. Symbol=", _Symbol,
         " Digits=", g_digits,
         " Pip=", g_pip,
         " ATR Period=", InpATRPeriod);
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("[SignalScalerATR] Deinitialized. Reason=", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Wait for new bar (M1)
   if(!IsNewBar()) return;
   
   // Update ATR
   g_atrValue = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod).Handle(0);
   if(g_atrValue <= 0)
   {
      g_atrValue = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod).GetData(0);
   }
   
   // Check existing positions
   int posCount = CountMyPositions();
   double totalLots = TotalLots();
   
   // If no position, check entry signal
   if(posCount == 0)
   {
      int signal = GetSignal();
      
      if(signal == 1 && InpAllowBuy)
      {
         OpenPosition(ORDER_TYPE_BUY, signal);
      }
      else if(signal == -1 && InpAllowSell)
      {
         OpenPosition(ORDER_TYPE_SELL, signal);
      }
   }
// If has position, check for add position signal
   else
   {
      int last_dir = GetLastTradeDirection();
      int signal = GetSignal();
      
      if(signal == 1 && last_dir == 1 && posCount < InpMaxPositions && totalLots < InpMaxLots && InpAllowBuy)
         OpenPosition(ORDER_TYPE_BUY, signal);
      else if(signal == -1 && last_dir == -1 && posCount < InpMaxPositions && totalLots < InpMaxLots && InpAllowSell)
         OpenPosition(ORDER_TYPE_SELL, signal);
   }
   
   // Manage SL/TP per position
   ManagePositions();
}

//+------------------------------------------------------------------+
//| Detect new bar                                                    |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime curBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(curBar != g_lastBarTime)
   {
      g_lastBarTime = curBar;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Get composite signal: EMA + RSI + Volume                         |
//| Returns: 1 = Buy, -1 = Sell, 0 = No signal                        |
//+------------------------------------------------------------------+
int GetSignal()
{
   // EMA Crossover
   double emaFast0 = iMA(_Symbol, PERIOD_CURRENT, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE).GetData(0);
   double emaFast1 = iMA(_Symbol, PERIOD_CURRENT, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE).GetData(1);
   double emaSlow0 = iMA(_Symbol, PERIOD_CURRENT, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE).GetData(0);
   double emaSlow1 = iMA(_Symbol, PERIOD_CURRENT, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE).GetData(1);
   
   bool emaBullCross = (emaFast1 < emaSlow1 && emaFast0 > emaSlow0);
   bool emaBearCross = (emaFast1 > emaSlow1 && emaFast0 < emaSlow0);
   
   // RSI
   double rsi0 = iRSI(_Symbol, PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE).GetData(0);
   bool rsiBuy  = (rsi0 < InpRSIBuyLevel);   // below level = potential buy
   bool rsiSell = (rsi0 > InpRSISellLevel);  // above level = potential sell
   
   // Volume spike
   double volMA  = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_SMA, VOLUME_TICK).GetData(0);
   double vol0   = iVolume(_Symbol, PERIOD_CURRENT, 0);
   double vol1   = iVolume(_Symbol, PERIOD_CURRENT, 1);
   double volAvg = (vol0 + vol1) * 0.5;
   bool volSpike = (volAvg > volMA * InpVolThreshold);
   
   // Composite signal
   int signal = 0;
   
   if(emaBullCross && rsiBuy && volSpike)
      signal = 1;  // Strong BUY
   else if(emaBearCross && rsiSell && volSpike)
      signal = -1; // Strong SELL
   
   // If not all 3 confirm, allow partial (2 of 3)
   else if(emaBullCross && (rsiBuy || volSpike))
      signal = 1;
   else if(emaBearCross && (rsiSell || volSpike))
      signal = -1;
   
   return signal;
}

//+------------------------------------------------------------------+
//| Open new position (Buy or Sell)                                   |
//+------------------------------------------------------------------+
void OpenPosition(ENUM_ORDER_TYPE type, int signal)
{
   double price    = 0;
   double slPrice  = 0;
   double tpPrice  = 0;
   double ask      = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid      = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr      = g_atrValue;
   double lots     = CalculateLot(atr);
   
   double slDist   = atr * InpATRStopMult;
   double tpDist   = atr * 2.0;  // TP = 2x ATR minimum
   
   if(type == ORDER_TYPE_BUY)
   {
      price   = ask;
      slPrice = NormalizeDouble(price - slDist, g_digits);
      tpPrice = NormalizeDouble(price + tpDist, g_digits);
   }
   else
   {
      price   = bid;
      slPrice = NormalizeDouble(price + slDist, g_digits);
      tpPrice = NormalizeDouble(price - tpDist, g_digits);
   }
   
   // Set volume step
   lots = NormalizeLot(lots);
   
   // Execute
   bool result = trade.PositionOpen(_Symbol, type, lots, price, slPrice, tpPrice, InpComment);
   
   if(result)
   {
      Print("[SignalScalerATR] Opened ", type==ORDER_TYPE_BUY?"BUY":"SELL",
            " Lot=", lots,
            " Price=", price,
            " SL=", slPrice,
            " TP=", tpPrice,
            " ATR=", atr);
   }
   else
   {
      Print("[SignalScalerATR] FAILED to open position. Error=", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Calculate lot based on risk % and ATR stop                        |
//+------------------------------------------------------------------+
double CalculateLot(double atr)
{
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0;
   
   // ATR distance in price
   double slDistPrice = atr * InpATRStopMult;
   
   // Point value per lot
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double pointValue = tickValue * (g_pip / tickSize);
   
   if(pointValue <= 0) pointValue = 1.0;
   
   double lot = riskMoney / (slDistPrice * pointValue);
   
   // Apply multiplier for scaling (use base lot if first)
   int pos = CountMyPositions();
   if(pos > 0)
   {
      double mult = MathPow(InpLotMultiplier, pos);
      lot *= mult;
   }
   else
   {
      lot *= 1.0; // base
   }
   
   return lot;
}

//+------------------------------------------------------------------+
//| Normalize lot to broker requirements                              |
//+------------------------------------------------------------------+
double NormalizeLot(double lots)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lots = MathMax(minLot, lots);
   lots = MathMin(maxLot, lots);
   lots = MathFloor(lots / stepLot) * stepLot;
   
   return lots;
}

//+------------------------------------------------------------------+
//| Count positions managed by this EA                                |
//+------------------------------------------------------------------+
int CountMyPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Get total lots of our positions                                   |
//+------------------------------------------------------------------+
double TotalLots()
{
   double total = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         total += PositionGetDouble(POSITION_VOLUME);
      }
   }
   return total;
}

//+------------------------------------------------------------------+
//| Get direction of last trade (1=BUY, -1=SELL)                     |
//+------------------------------------------------------------------+
int GetLastTradeDirection()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         return (ptype == POSITION_TYPE_BUY) ? 1 : -1;
      }
   }
   return 0;
}

//+------------------------------------------------------------------+
//| Manage all positions: TP, BE, Trailing                            |
//+------------------------------------------------------------------+
void ManagePositions()
{
   double atr = g_atrValue;
   if(atr <= 0) atr = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod).GetData(0);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      
      ulong ticket    = PositionGetInteger(POSITION_TICKET);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double slPrice   = PositionGetDouble(POSITION_SL);
      double tpPrice   = PositionGetDouble(POSITION_TP);
      double curPrice  = PositionGetDouble(POSITION_PRICE_CURRENT);
      double profit    = PositionGetDouble(POSITION_PROFIT);
      double volume    = PositionGetDouble(POSITION_VOLUME);
      
      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      // Break Even when profit >= 2x risk
      double riskAmount = atr * InpATRStopMult * volume * g_pip;
      if(profit >= riskAmount * 2.0 && slPrice != openPrice)
      {
         double bePrice = openPrice + (ptype == POSITION_TYPE_BUY ? g_pip * 2 : -g_pip * 2);
         if(ptype == POSITION_TYPE_BUY && curPrice > bePrice)
         {
            trade.PositionModify(ticket, NormalizeDouble(bePrice, g_digits), tpPrice);
         }
         else if(ptype == POSITION_TYPE_SELL && curPrice < bePrice)
         {
            trade.PositionModify(ticket, NormalizeDouble(bePrice, g_digits), tpPrice);
         }
      }
      
      // Trailing Stop: move SL when profit > 3x ATR
      double trailDist = atr * 1.5;
      if(profit >= atr * 3.0)
      {
         if(ptype == POSITION_TYPE_BUY)
         {
            double newSL = curPrice - trailDist;
            if(newSL > slPrice)
            {
               trade.PositionModify(ticket, NormalizeDouble(newSL, g_digits), tpPrice);
            }
         }
         else
         {
            double newSL = curPrice + trailDist;
            if(newSL < slPrice || slPrice == 0)
            {
               trade.PositionModify(ticket, NormalizeDouble(newSL, g_digits), tpPrice);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Comment on chart                                                 |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   Comment("");
}

//+------------------------------------------------------------------+
//| Timer (1 second)                                                  |
//+------------------------------------------------------------------+
void OnTimer()
{
}
//+------------------------------------------------------------------+