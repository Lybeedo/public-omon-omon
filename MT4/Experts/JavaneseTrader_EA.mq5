//+------------------------------------------------------------------+
//|                                    JavaneseTrader_EA.mq5         |
//|                                        Javanese Trading Philosophy|
//|                                             "Tuku when price won't|
//|                                              go down. Dol when    |
//|                                              price won't go up."   |
//+------------------------------------------------------------------+
#property copyright   "Javanese Trading Philosophy"
#property version     "1.00"
#property strict

#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+
input group "=== ENTRY SETTINGS ==="
input int      LookbackPeriod    = 20;          // Lookback period for swing detection
input double   MinSwingSize      = 0.5;         // Minimum swing size in points (%)
input int      WaitCandles       = 3;           // Wait N candles for confirmation
input bool     UseRSIFilter      = true;        // Use RSI filter
input int      RSIPeriod         = 14;          // RSI period
input int      RSIBuyLevel       = 30;          // RSI oversold level (buy)
input int      RSISellLevel       = 70;          // RSI overbought level (sell)

input group "=== RISK MANAGEMENT ==="
input double   RiskPercent       = 2.0;         // Risk per trade (%)
input double   FixedLot          = 0.0;         // Fixed lot (0 = use RiskPercent)
input int      StopLossPoints    = 500;         // Stop Loss in points (0 = dynamic)
input int      TakeProfitPoints  = 1000;        // Take Profit in points (0 = dynamic RR)
input double   TakeProfitRatio   = 2.0;         // TP:SL ratio (if TP=0)
input bool     UseBreakeven      = true;        // Move SL to breakeven after X points
input int      BreakevenOffset   = 100;         // Points in profit before BE trigger

input group "=== TRAILING STOP ==="
input bool     UseTrailing       = true;        // Enable trailing stop
input double   TrailingStart     = 100;         // Points profit to start trailing
input double   TrailingStep      = 50;          // Step size (points)
input double   TrailingDistance  = 50;          // Keep distance from price (points)
input ENUM_TRAILING_MODE TrailingMode = TRAILING_STEP; // TRAILING_STEP or TRAILING_LINEAR

input group "=== TIME FILTER ==="
input bool     UseSessionFilter  = false;       // Enable session filter
input int      StartHour         = 9;           // Trading start hour (broker time)
input int      EndHour           = 17;          // Trading end hour (broker time)

input group "=== MONEY MANAGEMENT ==="
input int      MaxOrders          = 1;          // Max concurrent orders per symbol
input int      MagicNumber        = 20250620;    // EA magic number
input int      Slippage           = 30;          // Slippage in points
input string   Comment           = "JavaneseTrader"; // Order comment

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+
CTrade          trade;
datetime        lastBarTime       = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(Slippage);
   trade.SetTypeFilling(ORDER_FILLING_FOK);

   Print("=== Javanese Trader EA Initialized ===");
   Print("Tuku when price won't go down.");
   Print("Dol when price won't go up.");
   Print("Lookback: ", LookbackPeriod, " | MinSwing: ", MinSwingSize, "%");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("Javanese Trader EA removed: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!IsNewBar()) return;

   // Check existing positions
   if(PositionsTotal > 0)
   {
      ManageTrailingStop();
      ManageBreakeven();
      return;
   }

   // Check max orders
   if(CountOrders() >= MaxOrders) return;

   // Session filter
   if(UseSessionFilter && !IsInSession()) return;

   // Scan for entries
   CheckBuySetup();
   CheckSellSetup();
}

//+------------------------------------------------------------------+
//| Detect "tuku" setup - price refuses to go lower                   |
//+------------------------------------------------------------------+
void CheckBuySetup()
{
   double close[];
   double high[];
   double low[];
   ArrayResize(close, LookbackPeriod);
   ArrayResize(high, LookbackPeriod);
   ArrayResize(low, LookbackPeriod);

   for(int i = 0; i < LookbackPeriod; i++)
   {
      close[i] = iClose(_Symbol, PERIOD_CURRENT, i);
      high[i]  = iHigh(_Symbol, PERIOD_CURRENT, i);
      low[i]   = iLow(_Symbol, PERIOD_CURRENT, i);
   }

   // Find swing low
   int swingLowIdx = FindSwingLow(low);
   if(swingLowIdx < 0) return;

   // Must be recent (within WaitCandles)
   if(swingLowIdx > WaitCandles) return;

   // Price refused to make new lows: higher lows after swing
   bool priceRefusingDown = true;
   for(int i = 1; i <= WaitCandles; i++)
   {
      if(swingLowIdx + i < LookbackPeriod)
      {
         if(low[swingLowIdx + i] < low[swingLowIdx])
         {
            priceRefusingDown = false;
            break;
         }
      }
   }

   if(!priceRefusingDown) return;

   // RSI filter
   if(UseRSIFilter)
   {
      double rsi = iRSI(_Symbol, PERIOD_CURRENT, RSIPeriod, PRICE_CLOSE);
      if(rsi > RSIBuyLevel) return;
   }

   // Entry: price bounced / refused to go down
   double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl = CalculateStopLoss(entryPrice, ORDER_TYPE_BUY);
   double tp = CalculateTakeProfit(entryPrice, ORDER_TYPE_BUY);
   double lot = CalculateLot();

   if(trade.Buy(lot, _Symbol, entryPrice, sl, tp, Comment))
   {
      Print("=== TUKU BUY SIGNAL ===");
      Print("Price refused to go down. Entry: ", entryPrice);
      Print("SL: ", sl, " | TP: ", tp);
   }
   else
   {
      Print("Buy failed: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Detect "dol" setup - price refuses to go higher                    |
//+------------------------------------------------------------------+
void CheckSellSetup()
{
   double close[];
   double high[];
   double low[];
   ArrayResize(close, LookbackPeriod);
   ArrayResize(high, LookbackPeriod);
   ArrayResize(low, LookbackPeriod);

   for(int i = 0; i < LookbackPeriod; i++)
   {
      close[i] = iClose(_Symbol, PERIOD_CURRENT, i);
      high[i]  = iHigh(_Symbol, PERIOD_CURRENT, i);
      low[i]   = iLow(_Symbol, PERIOD_CURRENT, i);
   }

   // Find swing high
   int swingHighIdx = FindSwingHigh(high);
   if(swingHighIdx < 0) return;

   // Must be recent
   if(swingHighIdx > WaitCandles) return;

   // Price refused to make new highs: lower highs after swing
   bool priceRefusingUp = true;
   for(int i = 1; i <= WaitCandles; i++)
   {
      if(swingHighIdx + i < LookbackPeriod)
      {
         if(high[swingHighIdx + i] > high[swingHighIdx])
         {
            priceRefusingUp = false;
            break;
         }
      }
   }

   if(!priceRefusingUp) return;

   // RSI filter
   if(UseRSIFilter)
   {
      double rsi = iRSI(_Symbol, PERIOD_CURRENT, RSIPeriod, PRICE_CLOSE);
      if(rsi < RSISellLevel) return;
   }

   // Entry: price rejected from high / refused to go up
   double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = CalculateStopLoss(entryPrice, ORDER_TYPE_SELL);
   double tp = CalculateTakeProfit(entryPrice, ORDER_TYPE_SELL);
   double lot = CalculateLot();

   if(trade.Sell(lot, _Symbol, entryPrice, sl, tp, Comment))
   {
      Print("=== DOL SELL SIGNAL ===");
      Print("Price refused to go up. Entry: ", entryPrice);
      Print("SL: ", sl, " | TP: ", tp);
   }
   else
   {
      Print("Sell failed: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Find local swing low                                             |
//+------------------------------------------------------------------+
int FindSwingLow(double &arr[])
{
   int idx = -1;
   double minVal = DBL_MAX;

   for(int i = 2; i < ArraySize(arr) - 2; i++)
   {
      if(arr[i] < arr[i-1] && arr[i] < arr[i+1] && arr[i] < minVal)
      {
         minVal = arr[i];
         idx = i;
      }
   }
   return idx;
}

//+------------------------------------------------------------------+
//| Find local swing high                                             |
//+------------------------------------------------------------------+
int FindSwingHigh(double &arr[])
{
   int idx = -1;
   double maxVal = -DBL_MAX;

   for(int i = 2; i < ArraySize(arr) - 2; i++)
   {
      if(arr[i] > arr[i-1] && arr[i] > arr[i+1] && arr[i] > maxVal)
      {
         maxVal = arr[i];
         idx = i;
      }
   }
   return idx;
}

//+------------------------------------------------------------------+
//| Calculate lot size                                                |
//+------------------------------------------------------------------+
double CalculateLot()
{
   if(FixedLot > 0) return FixedLot;

   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (RiskPercent / 100.0);

   double tickValue  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double point      = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   int slPts = (StopLossPoints > 0) ? StopLossPoints : 500;
   double lot = riskAmount / (slPts * tickValue * point);

   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot = MathRound(lot / lotStep) * lotStep;

   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;

   return lot;
}

//+------------------------------------------------------------------+
//| Calculate Stop Loss                                               |
//+------------------------------------------------------------------+
double CalculateStopLoss(double price, ENUM_ORDER_TYPE type)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(StopLossPoints > 0)
   {
      if(type == ORDER_TYPE_BUY)
         return price - StopLossPoints * point;
      else
         return price + StopLossPoints * point;
   }

   // Dynamic: ATR-based
   double atr = iATR(_Symbol, PERIOD_CURRENT, 14);
   double slDist = atr * 1.5;

   if(type == ORDER_TYPE_BUY)
      return price - slDist;
   else
      return price + slDist;
}

//+------------------------------------------------------------------+
//| Calculate Take Profit                                              |
//+------------------------------------------------------------------+
double CalculateTakeProfit(double price, ENUM_ORDER_TYPE type)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(TakeProfitPoints > 0)
   {
      if(type == ORDER_TYPE_BUY)
         return price + TakeProfitPoints * point;
      else
         return price - TakeProfitPoints * point;
   }

   // Dynamic: based on RR ratio
   double sl = CalculateStopLoss(price, type);
   double slDist = MathAbs(price - sl);
   double tpDist = slDist * TakeProfitRatio;

   if(type == ORDER_TYPE_BUY)
      return price + tpDist;
   else
      return price - tpDist;
}

//+------------------------------------------------------------------+
//| Trailing stop manager                                             |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   if(!UseTrailing) return;

   for(int i = PositionsTotal - 1; i >= 0; i--)
   {
      if(!PositionSelect(_Symbol)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

      double posPrice  = PositionGetDouble(POSITION_PRICE_OPEN);
      double posSL     = PositionGetDouble(POSITION_SL);
      double posTP     = PositionGetDouble(POSITION_TP);
      double point     = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      int posType = PositionGetInteger(POSITION_TYPE);
      double currentPrice = (posType == POSITION_TYPE_BUY) ? ask : bid;
      double profitPts = MathAbs(currentPrice - posPrice) / point;

      if(profitPts < TrailingStart) continue;

      double newSL = 0;

      if(TrailingMode == TRAILING_STEP)
      {
         int steps    = (int)((profitPts - TrailingStart) / TrailingStep);
         double delta = steps * TrailingStep * point;

         if(posType == POSITION_TYPE_BUY)
            newSL = posPrice + delta - TrailingDistance * point;
         else
            newSL = posPrice - delta + TrailingDistance * point;
      }
      else // TRAILING_LINEAR
      {
         if(posType == POSITION_TYPE_BUY)
            newSL = bid - TrailingDistance * point;
         else
            newSL = ask + TrailingDistance * point;
      }

      // Only improve SL
      if(posType == POSITION_TYPE_BUY)
      {
         if(newSL > posSL && newSL > posPrice)
            trade.PositionModify(_Symbol, newSL, posTP);
      }
      else
      {
         if(newSL < posSL)
            trade.PositionModify(_Symbol, newSL, posTP);
      }
   }
}

//+------------------------------------------------------------------+
//| Breakeven manager                                                 |
//+------------------------------------------------------------------+
void ManageBreakeven()
{
   if(!UseBreakeven) return;

   for(int i = PositionsTotal - 1; i >= 0; i--)
   {
      if(!PositionSelect(_Symbol)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

      double posPrice  = PositionGetDouble(POSITION_PRICE_OPEN);
      double posSL     = PositionGetDouble(POSITION_SL);
      double posTP     = PositionGetDouble(POSITION_TP);
      double point     = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      int posType      = PositionGetInteger(POSITION_TYPE);

      double currentPrice = (posType == POSITION_TYPE_BUY)
                           ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                           : SymbolInfoDouble(_Symbol, SYMBOL_BID);

      double profitPts = MathAbs(currentPrice - posPrice) / point;
      if(profitPts < BreakevenOffset) continue;

      double spreadPts  = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      double breakEven  = posPrice + spreadPts * point;

      if(posType == POSITION_TYPE_BUY)
      {
         if(posSL < breakEvenPrice || posSL == 0)
            trade.PositionModify(_Symbol, breakEvenPrice, posTP);
      }
      else
      {
         if(posSL > breakEvenPrice || posSL == 0)
            trade.PositionModify(_Symbol, breakEvenPrice, posTP);
      }
   }
}

//+------------------------------------------------------------------+
//| New bar detection                                                 |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Count open positions for this EA                                  |
//+------------------------------------------------------------------+
int CountOrders()
{
   int count = 0;
   for(int i = PositionsTotal - 1; i >= 0; i--)
   {
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Session filter                                                    |
//+------------------------------------------------------------------+
bool IsInSession()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   if(StartHour < EndHour)
      return dt.hour >= StartHour && dt.hour <= EndHour;
   else
      return dt.hour >= StartHour || dt.hour <= EndHour;
}
//+------------------------------------------------------------------+