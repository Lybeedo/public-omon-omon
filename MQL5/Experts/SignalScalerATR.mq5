//+------------------------------------------------------------------+
//|                                        SignalScalerATR_v1.2.mq5 |
//|                                          Copyright 7NAGA System |
//|                                                   Signal Scaler  |
//|                                    Dynamic + Distance + Recovery |
//+------------------------------------------------------------------+
#property copyright   "7NAGA System"
#property version      "1.02"
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
input double InpRSIBuyLevel  = 50.0;    // RSI Buy Level
input double InpRSISellLevel = 50.0;    // RSI Sell Level

input group "=== SIGNAL: VOLUME ==="
input double InpVolThreshold = 1.5;     // Volume multiplier vs MA

input group "=== DISTANCE: ATR ==="
input int    InpATRPeriod    = 14;      // ATR Period
input double InpATREntryMult = 1.5;     // ATR Multiplier (entry distance)
input double InpATRStopMult   = 2.0;    // ATR Multiplier (stop loss)

input group "=== LOT SIZING: DYNAMIC % RISK ==="
input double InpRiskPercent  = 1.0;     // Risk per trade (%)
input double InpBaseLot      = 0.01;    // Minimum base lot
input double InpMaxLots      = 0.20;    // Max total lot
input bool   InpUseDynamicLot = true;   // Use dynamic lot sizing (else fixed base)

input group "=== DISTANCE-BASED LOT ADJUSTMENT ==="
input double InpDistFactor   = 0.5;     // Distance factor (0.5 = reduce lot when far)
input double InpDistMinMult  = 0.3;     // Min lot multiplier for far distance

input group "=== ORDER MANAGEMENT ==="
input int    InpMaxPositions = 5;       // Max positions (scaling steps)
input int    InpMagicNumber  = 77777;   // Magic Number
input string InpComment      = "SignalScalerATR";
input int    InpSlippage     = 3;       // Slippage (points)

input group "=== FILTER ==="
input bool   InpAllowBuy     = true;    // Allow Buy signals
input bool   InpAllowSell    = true;    // Allow Sell signals

//+------------------------------------------------------------------+
//| RECOVERY MODE INPUTS                                             |
//+------------------------------------------------------------------+
input group "=== RECOVERY MODE ==="
input bool   InpRecoveryMode  = true;   // Enable Recovery Mode
input double InpRecoveryThreshold = 30.0;// Floating $ to trigger recovery
input double InpRecoveryMult    = 1.5;  // Recovery lot multiplier
input int    InpRecoveryCoolDown = 300; // Seconds between recovery entries
input double InpProfitTarget   = 20.0;  // Total profit $ to close all

input group "=== TIME FILTER ==="
input int    InpStartHour     = 6;      // Start trading hour (0-23)
input int    InpEndHour       = 20;    // End trading hour (0-23)

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CTrade       trade;
datetime     g_lastBarTime   = 0;
bool         g_recoveryActive = false;
int          g_digits         = 0;
double       g_point          = 0.0;
double       g_pip            = 0.0;
double       g_baseATR        = 0.0;    // ATR at first entry (for distance calc)
datetime     g_lastRecoveryTime = 0;
datetime     g_lastEntryTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   g_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_pip    = (g_digits == 3 || g_digits == 5) ? g_point * 10 : g_point;
   
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   
   Print("[SignalScalerATR] v1.2 Dynamic+Distance+Recovery Initialized");
   Print("  Symbol=", _Symbol, " Digits=", g_digits, " Pip=", g_pip);
   Print("  Risk%", InpRiskPercent, " BaseLot=", InpBaseLot, " MaxLots=", InpMaxLots);
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
   
   if(!IsTradingTime()) return;
   
   int    posCount    = CountMyPositions();
   double totalLots   = TotalLots();
   double floating    = GetFloatingLoss();
   double totalProfit = GetTotalProfit();
   double atr         = GetATR(0);
   
   // Calculate distance factor
   double distFactor = CalculateDistanceFactor(atr);
   
   //-------------------------------
   // RECOVERY MODE LOGIC
   //-------------------------------
   if(InpRecoveryMode && posCount > 0)
   {
      // Check if should add recovery position
      if(floating <= -InpRecoveryThreshold && posCount < InpMaxPositions)
      {
         int lastDir = GetLastTradeDirection();
         
         if(lastDir != 0 && totalLots < InpMaxLots)
         {
            double lastPrice = GetLastPositionPrice();
            
            if(lastPrice > 0)
            {
               double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               double distance = (lastDir == 1) ? (ask - lastPrice) : (lastPrice - bid);
               
               // Distance check: >= ATR Entry Distance
               if(distance >= atr * InpATREntryMult)
               {
                  if(TimeCurrent() - g_lastRecoveryTime >= InpRecoveryCoolDown)
                  {
                     // Confirm signal before adding
                     int signal = GetSignal();
                     if(signal == lastDir)
                     {
                        OpenRecoveryPosition(lastDir, distFactor);
                        g_lastRecoveryTime = TimeCurrent();
                        Print("[SignalScalerATR] Recovery triggered! Floating=$", DoubleToString(floating, 2));
                     }
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
         g_baseATR = 0;
         Print("[SignalScalerATR] Recovery SUCCESS! Profit=$", DoubleToString(totalProfit, 2));
         return;
      }
      
      // Move to BE when 50% target reached
      if(totalProfit >= InpProfitTarget * 0.5 && posCount > 0)
      {
         MoveAllToBreakEven();
      }
      
      // Emergency close if floating loss > 2x threshold
      if(floating <= -InpRecoveryThreshold * 3.0)
      {
         Print("[SignalScalerATR] WARNING: Large floating loss. Closing all...");
         CloseAllPositions();
         g_recoveryActive = false;
      }
   }
   
   //-------------------------------
   // NORMAL SIGNAL MODE
   //-------------------------------
   if(posCount == 0)
   {
      int signal = GetSignal();
      
      if(signal == 1 && InpAllowBuy)
         OpenPosition(ORDER_TYPE_BUY, signal, distFactor);
      else if(signal == -1 && InpAllowSell)
         OpenPosition(ORDER_TYPE_SELL, signal, distFactor);
   }
   else
   {
      // Check for additional position if signal aligns
      int lastDir = GetLastTradeDirection();
      int signal  = GetSignal();
      
      // Only add if same direction AND minimum distance met
      double lastPrice = GetLastPositionPrice();
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double distance = 0;
      
      if(lastPrice > 0)
      {
         distance = (lastDir == 1) ? (ask - lastPrice) : (lastPrice - bid);
      }
      
      // Check cooldown and distance
      bool canAdd = (TimeCurrent() - g_lastEntryTime >= 120);
      
      if(signal == lastDir && posCount < InpMaxPositions && 
         totalLots < InpMaxLots && canAdd && distance >= atr * InpATREntryMult)
      {
         if(signal == 1 && InpAllowBuy)
            OpenPosition(ORDER_TYPE_BUY, signal, distFactor);
         else if(signal == -1 && InpAllowSell)
            OpenPosition(ORDER_TYPE_SELL, signal, distFactor);
      }
   }
   
   // Manage trailing
   ManagePositions(distFactor);
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
//| Get ATR value (with caching for performance)                    |
//+------------------------------------------------------------------+
double GetATR(int shift)
{
   int handle = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod).Handle(0);
   if(handle != INVALID_HANDLE)
      return iATRGetData(handle, shift);
   return iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod).GetData(shift);
}

double iATRGetData(int handle, int shift)
{
   double buffer[];
   ArraySetAsSeries(buffer, true);
   if(CopyBuffer(handle, 0, shift, 1, buffer) > 0)
      return buffer[0];
   return 0;
}

//+------------------------------------------------------------------+
//| Calculate distance-based lot factor                              |
//| Farther distance = smaller lot (safer)                          |
//+------------------------------------------------------------------+
double CalculateDistanceFactor(double currentATR)
{
   if(g_baseATR <= 0 || currentATR <= 0)
      return 1.0;
   
   // ATR ratio: if current ATR > base ATR, price is volatile
   // Reduce lot when volatile (farther effective distance)
   double ratio = g_baseATR / currentATR;
   
   // Clamp between min and max
   double factor = MathMax(InpDistMinMult, MathMin(1.0, ratio * InpDistFactor + (1 - InpDistFactor)));
   
   return factor;
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
//| Open new position with dynamic lot sizing                        |
//+------------------------------------------------------------------+
void OpenPosition(ENUM_ORDER_TYPE type, int signal, double distFactor)
{
   double ask      = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid      = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr      = GetATR(0);
   double slDist   = atr * InpATRStopMult;
   double tpDist   = atr * 2.0;
   double lots     = CalculateDynamicLot(atr, distFactor, 0);
   
   double price, slPrice, tpPrice;
   
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
      // Store base ATR for distance-based lot calculation
      if(g_baseATR <= 0)
         g_baseATR = atr;
      
      g_recoveryActive = true;
      g_lastEntryTime = TimeCurrent();
      
      Print("[SignalScalerATR] Opened ", type==ORDER_TYPE_BUY?"BUY":"SELL",
            " Lot=", DoubleToString(lots, 3),
            " Price=", price,
            " SL=", slPrice,
            " TP=", tpPrice,
            " ATR=", DoubleToString(atr, 5),
            " DistFactor=", DoubleToString(distFactor, 2));
   }
   else
   {
      Print("[SignalScalerATR] FAILED. Error=", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Open recovery position (dynamic + distance based)                |
//+------------------------------------------------------------------+
void OpenRecoveryPosition(int direction, double distFactor)
{
   double ask      = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid      = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr      = GetATR(0);
   double lastPrice = GetLastPositionPrice();
   double slDist   = atr * InpATRStopMult;
   double tpDist   = atr * 1.5;
   int    step     = CountMyPositions();
   
   // Recovery lot: dynamic × distance factor × recovery multiplier × √step
   double lots = CalculateDynamicLot(atr, distFactor, step);
   lots *= InpRecoveryMult;
   
   // Apply sqrt scaling for safety (not linear or exponential)
   double sqrtFactor = MathSqrt((double)(step + 1));
   lots *= sqrtFactor;
   
   ENUM_ORDER_TYPE type;
   double price, slPrice, tpPrice;
   
   if(direction == 1)
   {
      type    = ORDER_TYPE_BUY;
      price   = ask;
      slPrice = NormalizeDouble(lastPrice - slDist, g_digits);
      tpPrice = NormalizeDouble(price + tpDist * 1.5, g_digits);
   }
   else
   {
      type    = ORDER_TYPE_SELL;
      price   = bid;
      slPrice = NormalizeDouble(lastPrice + slDist, g_digits);
      tpPrice = NormalizeDouble(price - tpDist * 1.5, g_digits);
   }
   
   lots = NormalizeLot(lots);
   
   bool result = trade.PositionOpen(_Symbol, type, lots, price, slPrice, tpPrice, "Recovery");
   
   if(result)
   {
      Print("[SignalScalerATR] RECOVERY #", step, 
            " Lot=", DoubleToString(lots, 3),
            " Direction=", direction,
            " ATR=", DoubleToString(atr, 5),
            " DistFactor=", DoubleToString(distFactor, 2),
            " SqrtFactor=", DoubleToString(sqrtFactor, 2));
   }
}

//+------------------------------------------------------------------+
//| Calculate DYNAMIC lot based on risk %                            |
//| Also applies distance factor and step scaling                     |
//+------------------------------------------------------------------+
double CalculateDynamicLot(double atr, double distFactor, int step)
{
   double equity    = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskMoney = equity * InpRiskPercent / 100.0;
   
   // Calculate stop distance in price
   double slDistPrice = atr * InpATRStopMult;
   
   // Calculate point value per lot
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double pointValue = tickValue * (g_pip / tickSize);
   
   if(pointValue <= 0) pointValue = 1.0;
   
   // Dynamic lot = risk / (stop distance × point value)
   double lot = riskMoney / (slDistPrice * pointValue);
   
   // Apply distance factor (reduce when volatile/far)
   lot *= distFactor;
   
   // Apply step scaling for recovery (sqrt growth, not exponential)
   if(step > 0)
   {
      double sqrtFactor = MathSqrt((double)(step + 1));
      lot *= sqrtFactor;
   }
   
   // Ensure minimum base lot
   lot = MathMax(InpBaseLot, lot);
   
   return lot;
}

//+------------------------------------------------------------------+
//| Normalize lot to broker requirements                              |
//+------------------------------------------------------------------+
double NormalizeLot(double lots)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lots = MathMax(minLot, lots);
   lots = MathMin(InpMaxLots, lots);
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
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      
      ulong ticket     = PositionGetInteger(POSITION_TICKET);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double curPrice  = PositionGetDouble(POSITION_PRICE_CURRENT);
      double slPrice   = PositionGetDouble(POSITION_SL);
      double tpPrice   = PositionGetDouble(POSITION_TP);
      
      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      if(ptype == POSITION_TYPE_BUY)
      {
         double bePrice = openPrice + g_pip * 2;
         if(slPrice < bePrice)
            trade.PositionModify(ticket, NormalizeDouble(bePrice, g_digits), tpPrice);
      }
      else
      {
         double bePrice = openPrice - g_pip * 2;
         if(slPrice > bePrice || slPrice == 0)
            trade.PositionModify(ticket, NormalizeDouble(bePrice, g_digits), tpPrice);
      }
   }
}

//+------------------------------------------------------------------+
//| Manage trailing stop                                             |
//+------------------------------------------------------------------+
void ManagePositions(double distFactor)
{
   double atr      = GetATR(0);
   double totalProfit = GetFloatingLoss();
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      
      ulong ticket   = PositionGetInteger(POSITION_TICKET);
      double slPrice = PositionGetDouble(POSITION_SL);
      double tpPrice = PositionGetDouble(POSITION_TP);
      double curPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      double profit   = PositionGetDouble(POSITION_PROFIT);
      
      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      // Trailing when profit > 3x ATR
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
   double totalProfit = GetFloatingLoss();
   int    posCount    = CountMyPositions();
   double atr         = GetATR(0);
   double distFactor  = CalculateDistanceFactor(atr);
   
   string comment = "=== SignalScalerATR v1.2 ===\n";
   comment += "Symbol: " + _Symbol + "\n";
   comment += "Positions: " + IntegerToString(posCount) + "/" + IntegerToString(InpMaxPositions) + "\n";
   comment += "Total Lots: " + DoubleToString(TotalLots(), 3) + "\n";
   comment += "Equity: $" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + "\n";
   comment += "Floating: $" + DoubleToString(totalProfit, 2) + "\n";
   comment += "\n--- ATR System ---\n";
   comment += "ATR: " + DoubleToString(atr, 5) + "\n";
   comment += "Base ATR: " + DoubleToString(g_baseATR, 5) + "\n";
   comment += "Dist Factor: " + DoubleToString(distFactor, 2) + "\n";
   comment += "\n--- Recovery Mode ---\n";
   comment += "Active: " + (g_recoveryActive ? "YES" : "NO") + "\n";
   comment += "Threshold: $" + DoubleToString(InpRecoveryThreshold, 0) + "\n";
   comment += "Profit Target: $" + DoubleToString(InpProfitTarget, 0);
   
   Comment(comment);
}
//+------------------------------------------------------------------+