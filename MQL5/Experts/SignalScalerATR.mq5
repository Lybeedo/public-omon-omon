//+------------------------------------------------------------------+
//|                                        SignalScalerATR_v1.1.mq5 |
//|                                          Copyright 7NAGA System |
//|                                                   Signal Scaler  |
//|                                                Recovery Mode     |
//+------------------------------------------------------------------+
#property copyright   "7NAGA System"
#property version      "1.01"
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
input double InpVolThreshold = 1.5;     // Volume multiplier vs MA

input group "=== DISTANCE: ATR ==="
input int    InpATRPeriod    = 14;      // ATR Period
input double InpATRMultiplier = 1.5;     // ATR Multiplier (entry distance)
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
//| RECOVERY MODE INPUTS                                             |
//+------------------------------------------------------------------+
input group "=== RECOVERY MODE ==="
input bool   InpRecoveryMode  = true;   // Enable Recovery Mode
input double InpRecoveryThreshold = 50.0;// Floating $ to trigger recovery (50 = $50)
input double InpRecoveryMult    = 2.0;  // Recovery lot multiplier
input double InpProfitTarget   = 20.0;  // Total profit $ to close all ($)

input group "=== TIME FILTER ==="
input int    InpStartHour     = 6;      // Start trading hour (0-23)
input int    InpEndHour       = 20;     // End trading hour (0-23)

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CTrade       trade;
datetime     g_lastBarTime   = 0;
bool         g_recoveryActive = false;
double       g_lotStep       = 0.0;
double       g_tickValue     = 0.0;
int          g_digits        = 0;
double       g_point          = 0.0;
double       g_pip            = 0.0;
datetime     g_lastRecoveryTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   g_digits   = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_pip      = (g_digits == 3 || g_digits == 5) ? g_point * 10 : g_point;
   
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   
   g_lotStep  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   Print("[SignalScalerATR] v1.1 Recovery Mode Initialized");
   Print("  Symbol=", _Symbol, " Digits=", g_digits, " Pip=", g_pip);
   Print("  Recovery Threshold=$", InpRecoveryThreshold, " Profit Target=$", InpProfitTarget);
   
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
   if(!IsNewBar()) return;
   
   // Check time filter
   if(!IsTradingTime()) return;
   
   int posCount = CountMyPositions();
   double totalLots = TotalLots();
   double floatingLoss = GetFloatingLoss();
   double totalProfit = GetTotalProfit();
   
   // Check recovery mode first
   if(InpRecoveryMode && posCount > 0)
   {
      // Recovery: floating loss exceeds threshold, add more positions
      if(floatingLoss <= -InpRecoveryThreshold)
      {
         int last_dir = GetLastTradeDirection();
         
         if(last_dir != 0 && posCount < InpMaxPositions && totalLots < InpMaxLots)
         {
            // Wait for ATR-based distance
            double atr = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod).GetData(0);
            double lastPrice = GetLastPositionPrice();
            
            if(lastPrice > 0)
            {
               double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               double distance = (last_dir == 1) ? (ask - lastPrice) : (lastPrice - bid);
               
               // If distance >= ATR, add position
               if(distance >= atr * InpATRMultiplier)
               {
                  // Check minimum time between recovery entries
                  if(TimeCurrent() - g_lastRecoveryTime >= 300) // 5 min cooldown
                  {
                     OpenRecoveryPosition(last_dir);
                     g_lastRecoveryTime = TimeCurrent();
                  }
               }
            }
         }
      }
      
      // Close all when profit target reached
      if(totalProfit >= InpProfitTarget)
      {
         CloseAllPositions();
         g_recoveryActive = false;
         Print("[SignalScalerATR] Recovery complete! Profit=$", totalProfit);
         return;
      }
      
      // Check stop loss if all in profit
      if(totalProfit > InpProfitTarget * 0.5 && posCount > 0)
      {
         // Move to BE when 50% of target reached
         MoveAllToBreakEven();
      }
   }
   
   // Normal signal mode (only if not in deep recovery)
   if(floatingLoss > -InpRecoveryThreshold)
   {
      if(posCount == 0)
      {
         int signal = GetSignal();
         
         if(signal == 1 && InpAllowBuy)
            OpenPosition(ORDER_TYPE_BUY, signal);
         else if(signal == -1 && InpAllowSell)
            OpenPosition(ORDER_TYPE_SELL, signal);
      }
      else
      {
         int last_dir = GetLastTradeDirection();
         int signal = GetSignal();
         
         if(signal == 1 && last_dir == 1 && posCount < InpMaxPositions && totalLots < InpMaxLots && InpAllowBuy)
            OpenPosition(ORDER_TYPE_BUY, signal);
         else if(signal == -1 && last_dir == -1 && posCount < InpMaxPositions && totalLots < InpMaxLots && InpAllowSell)
            OpenPosition(ORDER_TYPE_SELL, signal);
      }
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
//| Check trading time                                                |
//+------------------------------------------------------------------+
bool IsTradingTime()
{
   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);
   
   if(InpStartHour < InpEndHour)
      return (now.hour >= InpStartHour && now.hour < InpEndHour);
   else
      return (now.hour >= InpStartHour || now.hour < InpEndHour);
}

//+------------------------------------------------------------------+
//| Get composite signal: EMA + RSI + Volume                         |
//+------------------------------------------------------------------+
int GetSignal()
{
   double emaFast0 = iMA(_Symbol, PERIOD_CURRENT, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE).GetData(0);
   double emaFast1 = iMA(_Symbol, PERIOD_CURRENT, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE).GetData(1);
   double emaSlow0 = iMA(_Symbol, PERIOD_CURRENT, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE).GetData(0);
   double emaSlow1 = iMA(_Symbol, PERIOD_CURRENT, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE).GetData(1);
   
   bool emaBullCross = (emaFast1 < emaSlow1 && emaFast0 > emaSlow0);
   bool emaBearCross = (emaFast1 > emaSlow1 && emaFast0 < emaSlow0);
   
   double rsi0 = iRSI(_Symbol, PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE).GetData(0);
   bool rsiBuy  = (rsi0 < InpRSIBuyLevel);
   bool rsiSell = (rsi0 > InpRSISellLevel);
   
   double volMA  = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_SMA, VOLUME_TICK).GetData(0);
   double vol0   = iVolume(_Symbol, PERIOD_CURRENT, 0);
   double vol1   = iVolume(_Symbol, PERIOD_CURRENT, 1);
   double volAvg = (vol0 + vol1) * 0.5;
   bool volSpike = (volAvg > volMA * InpVolThreshold);
   
   int signal = 0;
   
   if(emaBullCross && rsiBuy && volSpike)
      signal = 1;
   else if(emaBearCross && rsiSell && volSpike)
      signal = -1;
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
   double atr      = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod).GetData(0);
   double lots     = CalculateLot(atr);
   
   double slDist   = atr * InpATRStopMult;
   double tpDist   = atr * 2.0;
   
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
   
   lots = NormalizeLot(lots);
   
   bool result = trade.PositionOpen(_Symbol, type, lots, price, slPrice, tpPrice, InpComment);
   
   if(result)
   {
      Print("[SignalScalerATR] Opened ", type==ORDER_TYPE_BUY?"BUY":"SELL",
            " Lot=", lots, " Price=", price, " ATR=", atr);
      g_recoveryActive = true;
   }
   else
   {
      Print("[SignalScalerATR] FAILED. Error=", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Open recovery position (bigger lot)                              |
//+------------------------------------------------------------------+
void OpenRecoveryPosition(int direction)
{
   double ask      = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid      = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr      = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod).GetData(0);
   double lastPrice = GetLastPositionPrice();
   double slDist   = atr * InpATRStopMult;
   double tpDist   = atr * 2.0;
   
   // Recovery lot: multiply by InpRecoveryMult
   int pos = CountMyPositions();
   double lots = InpBaseLot * MathPow(InpLotMultiplier, pos) * InpRecoveryMult;
   lots = NormalizeLot(lots);
   
   double price, slPrice, tpPrice;
   ENUM_ORDER_TYPE type;
   
   if(direction == 1)
   {
      type = ORDER_TYPE_BUY;
      price = ask;
      slPrice = NormalizeDouble(lastPrice - slDist, g_digits);
      tpPrice = NormalizeDouble(price + tpDist * 1.5, g_digits);
   }
   else
   {
      type = ORDER_TYPE_SELL;
      price = bid;
      slPrice = NormalizeDouble(lastPrice + slDist, g_digits);
      tpPrice = NormalizeDouble(price - tpDist * 1.5, g_digits);
   }
   
   bool result = trade.PositionOpen(_Symbol, type, lots, price, slPrice, tpPrice, "Recovery");
   
   if(result)
   {
      Print("[SignalScalerATR] RECOVERY POSITION ADDED! Lot=", lots, " Direction=", direction);
   }
}

//+------------------------------------------------------------------+
//| Calculate lot based on risk % and ATR stop                        |
//+------------------------------------------------------------------+
double CalculateLot(double atr)
{
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0;
   
   double slDistPrice = atr * InpATRStopMult;
   
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double pointValue = tickValue * (g_pip / tickSize);
   
   if(pointValue <= 0) pointValue = 1.0;
   
   double lot = riskMoney / (slDistPrice * pointValue);
   
   // Recovery mode multiplier
   if(g_recoveryActive)
      lot *= InpRecoveryMult;
   
   int pos = CountMyPositions();
   if(pos > 0)
      lot *= MathPow(InpLotMultiplier, pos);
   
   return lot;
}

//+------------------------------------------------------------------+
//| Normalize lot to broker requirements                              |
//+------------------------------------------------------------------+
double NormalizeLot(double lots)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   
   lots = MathMax(minLot, lots);
   lots = MathMin(InpMaxLots, lots);
   lots = MathFloor(lots / g_lotStep) * g_lotStep;
   
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
//| Get last position open price                                      |
//+------------------------------------------------------------------+
double GetLastPositionPrice()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         return PositionGetDouble(POSITION_PRICE_OPEN);
      }
   }
   return 0;
}

//+------------------------------------------------------------------+
//| Get floating loss (negative = loss)                               |
//+------------------------------------------------------------------+
double GetFloatingLoss()
{
   double loss = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         loss += PositionGetDouble(POSITION_PROFIT);
      }
   }
   return loss;
}

//+------------------------------------------------------------------+
//| Get total profit of all positions                                |
//+------------------------------------------------------------------+
double GetTotalProfit()
{
   return GetFloatingLoss();
}

//+------------------------------------------------------------------+
//| Close all positions                                               |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         ulong ticket = PositionGetInteger(POSITION_TICKET);
         trade.PositionClose(ticket, InpSlippage);
      }
   }
}

//+------------------------------------------------------------------+
//| Move all positions to Break Even                                  |
//+------------------------------------------------------------------+
void MoveAllToBreakEven()
{
   double atr = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod).GetData(0);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      
      ulong ticket     = PositionGetInteger(POSITION_TICKET);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double curPrice  = PositionGetDouble(POSITION_PRICE_CURRENT);
      double slPrice   = PositionGetDouble(POSITION_SL);
      
      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      // Only move if not yet at BE
      if(ptype == POSITION_TYPE_BUY)
      {
         double bePrice = openPrice + g_pip * 2;
         if(slPrice < bePrice)
            trade.PositionModify(ticket, NormalizeDouble(bePrice, g_digits), 0);
      }
      else
      {
         double bePrice = openPrice - g_pip * 2;
         if(slPrice > bePrice || slPrice == 0)
            trade.PositionModify(ticket, NormalizeDouble(bePrice, g_digits), 0);
      }
   }
}

//+------------------------------------------------------------------+
//| Manage all positions: Trailing                                    |
//+------------------------------------------------------------------+
void ManagePositions()
{
   double atr = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod).GetData(0);
   double totalProfit = GetTotalProfit();
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      
      ulong ticket    = PositionGetInteger(POSITION_TICKET);
      double slPrice   = PositionGetDouble(POSITION_SL);
      double tpPrice   = PositionGetDouble(POSITION_TP);
      double curPrice  = PositionGetDouble(POSITION_PRICE_CURRENT);
      double profit    = PositionGetDouble(POSITION_PROFIT);
      
      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      // Trailing Stop: move SL when profit > 3x ATR
      double trailDist = atr * 1.5;
      if(totalProfit >= atr * 3.0)
      {
         if(ptype == POSITION_TYPE_BUY)
         {
            double newSL = curPrice - trailDist;
            if(newSL > slPrice)
               trade.PositionModify(ticket, NormalizeDouble(newSL, g_digits), tpPrice);
         }
         else
         {
            double newSL = curPrice + trailDist;
            if(newSL < slPrice || slPrice == 0)
               trade.PositionModify(ticket, NormalizeDouble(newSL, g_digits), tpPrice);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Comment on chart                                                 |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   double totalProfit = GetTotalProfit();
   int posCount = CountMyPositions();
   
   string comment = "=== SignalScalerATR v1.1 ===\n";
   comment += "Positions: " + IntegerToString(posCount) + "/" + IntegerToString(InpMaxPositions) + "\n";
   comment += "Total Lots: " + DoubleToString(TotalLots(), 2) + "\n";
   comment += "Floating: $" + DoubleToString(totalProfit, 2) + "\n";
   comment += "Recovery Mode: " + (InpRecoveryMode ? "ON" : "OFF") + "\n";
   comment += "Recovery Threshold: $" + DoubleToString(InpRecoveryThreshold, 0) + "\n";
   comment += "Profit Target: $" + DoubleToString(InpProfitTarget, 0);
   
   Comment(comment);
}
//+------------------------------------------------------------------+