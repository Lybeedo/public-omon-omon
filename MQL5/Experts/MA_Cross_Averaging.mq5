//+------------------------------------------------------------------+
//|                                              MA_Cross_Averaging.mq5 |
//|                                                       7NAGA System   |
//|                                                    MA Cross + TP + Layering     |
//+------------------------------------------------------------------+
#property copyright   "7NAGA System"
#property version     "1.00"
#property indicator   chart_window
#property indicator_chart_line
#property strict

//+------------------------------------------------------------------+
//| INPUT - TRIGGER                                                 |
//+------------------------------------------------------------------+
input group "=== TRIGGER MA ==="
input int    MA_Fast_Period  = 15;            // MA Fast Period
input int    MA_Slow_Period  = 30;            // MA Slow Period
input ENUM_MA_METHOD MA_Method = MODE_EMA;    // MA Method (EMA/SMA)
input int    MA_Price        = PRICE_CLOSE;  // MA Price

input group "=== LOT & RISK ==="
input double BaseLot         = 0.10;          // Base Lot Size
input double LotMultiplier   = 1.5;           // Lot Multiplier (MathPow step)
input double MaxLayers       = 5;             // Max Layer / Averaging

input group "=== MONEY MANAGEMENT ==="
input double TakeProfit_Pips = 50;            // Individual TP per trade (pips)
input double BasketTP        = 20;            // Basket TP when BEP hit ($)
input double PipStep         = 30;            // Distance to open next layer (pips)
input double Slippage        = 10;            // Slippage (points)

input group "=== FILTER ==="
input ulong  MagicNumber     = 20250611;      // Magic Number
input double MaxSpread       = 50;            // Max spread allowed (points)
input bool   CloseOnCrossReverse = true;      // Close all when cross reverse

input group "=== TIMEFRAMES ==="
input ENUM_TIMEFRAMES MA_Timeframe = PERIOD_H1; // MA Timeframe

//+------------------------------------------------------------------+
//| BUFFER & GLOBALS                                                 |
//+------------------------------------------------------------------+
double MA_Fast[];
double MA_Slow[];
int    handle_ma_fast;
int    handle_ma_slow;
datetime lastBarTime = 0;
datetime lastTradeBar = 0;  // track last bar we traded on

//+------------------------------------------------------------------+
//| STATE                                                             |
//+------------------------------------------------------------------+
enum ENUM_TREND { TREND_NONE, TREND_BULL, TREND_BEAR };
ENUM_TREND currentTrend = TREND_NONE;

//+------------------------------------------------------------------+
//| PricePrecision helper                                             |
//+------------------------------------------------------------------+
int DigitsAdjust()
{
   return (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
}

double PipsToPoints(double pips)
{
   if(DigitsAdjust() == 3 || DigitsAdjust() == 5)
      return pips * 10;
   return pips;
}

double PointsToPrice(double points)
{
   double pip = (DigitsAdjust() == 3 || DigitsAdjust() == 5) ? 0.01 : 0.01;
   return points * pip;
}

double PipsToPrice(double pips)
{
   double pip = (DigitsAdjust() == 3 || DigitsAdjust() == 5) ? 0.01 : 0.01;
   return pips * pip;
}

string ErrorDescription(int err)
{
   switch(err)
   {
      case ERR_NO_RESULT:         return "No result";
      case ERR_NO_CONNECTION:     return "No connection";
      case ERR_TOO_FREQUENT_REQUESTS: return "Too frequent";
      case ERR_TRADE_DISABLED:    return "Trade disabled";
      case ERR_PRICE_CHANGED:     return "Price changed";
      case ERR_OFF_QUOTES:        return "Off quotes";
      case ERR_BROKER_BUSY:       return "Broker busy";
      case ERR_REQUOTE:           return "Requote";
      case ERR_MARKET_CLOSED:     return "Market closed";
      default:                    return "Error: " + IntegerToString(err);
   }
}

//+------------------------------------------------------------------+
//| CountOpenPositions                                                |
//+------------------------------------------------------------------+
int CountMyPositions(ENUM_POSITION_TYPE type)
{
   int count = 0;
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         if(type == POSITION_TYPE_ALL || (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == type)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| CountMyPositionsEx (with direction)                              |
//+------------------------------------------------------------------+
int CountLayer(ENUM_POSITION_TYPE type)
{
   int count = 0;
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == type)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| GetLayerLots (with MathPow multiplier)                           |
//+------------------------------------------------------------------+
double GetLayerLot(int layerIndex, ENUM_POSITION_TYPE type)
{
   // layerIndex 0 = first trade (base lot)
   double lot = NormalizeDouble(BaseLot * MathPow(LotMultiplier, layerIndex), 2);
   
   // Cap at reasonable max
   double maxLot = BaseLot * MathPow(LotMultiplier, MaxLayers);
   if(lot > maxLot) lot = maxLot;
   
   //=== MONEY MANAGEMENT: risk per layer based on remaining equity ===
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   // Auto-reduce lot if equity is below 80% of balance (equity drawdown)
   if(equity < balance * 0.80)
      lot *= 0.5;
   if(equity < balance * 0.60)
      lot *= 0.5;
   
   return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
//| Calculate BEP + Basket TP Price                                   |
//+------------------------------------------------------------------+
double CalculateBasketTPPice(ENUM_POSITION_TYPE type)
{
   int total = PositionsTotal();
   double totalLotsBuy = 0, totalLotsSell = 0;
   double totalCostBuy = 0, totalCostSell = 0;
   
   for(int i = total - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double vol = PositionGetDouble(POSITION_VOLUME);
         double openPrice = PositionGetDouble(POSITION_OPEN_PRICE);
         
         if(pt == POSITION_TYPE_BUY)
         {
            totalLotsBuy += vol;
            totalCostBuy += openPrice * vol;
         }
         else if(pt == POSITION_TYPE_SELL)
         {
            totalLotsSell += vol;
            totalCostSell += openPrice * vol;
         }
      }
   }

   if(type == POSITION_TYPE_BUY)
   {
      if(totalLotsBuy <= 0) return 0;
      double bep = totalCostBuy / totalLotsBuy;
      return NormalizeDouble(bep + PipsToPrice(TakeProfit_Pips), DigitsAdjust());
   }
   else if(type == POSITION_TYPE_SELL)
   {
      if(totalLotsSell <= 0) return 0;
      double bep = totalCostSell / totalLotsSell;
      return NormalizeDouble(bep - PipsToPrice(TakeProfit_Pips), DigitsAdjust());
   }
   
   return 0;
}

//+------------------------------------------------------------------+
//| Calculate floating P/L                                           |
//+------------------------------------------------------------------+
double CalculateFloatingPL(ENUM_POSITION_TYPE type)
{
   double pl = 0;
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         if(type == POSITION_TYPE_ALL || pt == type)
            pl += PositionGetDouble(POSITION_PROFIT);
      }
   }
   return pl;
}

//+------------------------------------------------------------------+
//| Distance from current price to last layer entry                  |
//+------------------------------------------------------------------+
double GetLastEntryDistance(ENUM_POSITION_TYPE type)
{
   double lastPrice = 0;
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         if(pt == type)
            lastPrice = PositionGetDouble(POSITION_OPEN_PRICE); // get the latest
      }
   }
   
   if(lastPrice == 0) return 0;
   
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(type == POSITION_TYPE_BUY)
      return (ask - lastPrice) / PipsToPrice(1);
   else
      return (lastPrice - bid) / PipsToPrice(1);
}

//+------------------------------------------------------------------+
//| Set TP on all positions                                          |
//+------------------------------------------------------------------+
void SetBasketTP(ENUM_POSITION_TYPE type)
{
   double tpPrice = CalculateBasketTPPice(type);
   if(tpPrice == 0) return;

   int total = PositionsTotal();
   CTrade trade;
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(Slippage);

   for(int i = total - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         ulong ticket = PositionGetTicket(i);
         if(pt == type)
         {
            double curTP = PositionGetDouble(POSITION_TP);
            if(MathAbs(curTP - tpPrice) > PipsToPrice(1))
            {
               trade.PositionModify(ticket, PositionGetDouble(POSITION_OPEN_PRICE), tpPrice);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Open Position                                                    |
//+------------------------------------------------------------------+
bool OpenPosition(ENUM_POSITION_TYPE type)
{
   // Check spread
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > MaxSpread)
   {
      Print("[SPREAD] Too high: ", spread, " > ", MaxSpread, " - Skip trade.");
      return false;
   }

   // Check max layers
   int currentLayers = CountLayer(type);
   if(currentLayers >= (int)MaxLayers)
   {
      Print("[LAYER] Max layers reached (", MaxLayers, ") - Skip.");
      return false;
   }

   double lot = GetLayerLot(currentLayers, type);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double tp  = PipsToPrice(TakeProfit_Pips);
   
   double price, sl, tp_price;
   
   if(type == POSITION_TYPE_BUY)
   {
      price = ask;
      sl = 0; // no SL - rely on basket TP
      tp_price = NormalizeDouble(price + tp, DigitsAdjust());
   }
   else
   {
      price = bid;
      sl = 0;
      tp_price = NormalizeDouble(price - tp, DigitsAdjust());
   }
   
   CTrade trade;
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(Slippage);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   bool result = false;
   string comment = "MA_Average_L" + IntegerToString(currentLayers + 1);
   
   if(type == POSITION_TYPE_BUY)
      result = trade.Buy(lot, _Symbol, price, 0, tp_price, comment);
   else
      result = trade.Sell(lot, _Symbol, price, 0, tp_price, comment);
   
   if(result)
   {
      Print("✓ OPEN ", EnumToString(type), " | Lot: ", lot, 
            " | Price: ", price, " | TP: ", tp_price,
            " | Layer: ", currentLayers + 1, "/", (int)MaxLayers);
      
      // Update basket TP for all same-direction positions
      SetBasketTP(type);
   }
   else
   {
      Print("✗ OPEN FAILED | Error: ", ErrorDescription(GetLastError()));
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Close all positions of type                                       |
//+------------------------------------------------------------------+
void CloseAll(ENUM_POSITION_TYPE type)
{
   CTrade trade;
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(Slippage);
   
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == type)
            trade.PositionClose(PositionGetTicket(i));
      }
   }
}

//+------------------------------------------------------------------+
//| Check cross signal                                               |
//+------------------------------------------------------------------+
ENUM_TREND CheckCross()
{
   // Use current and previous bar
   // MA fast crosses above MA slow = BULL (buy)
   // MA fast crosses below MA slow = BEAR (sell)
   
   int bars = MA_Fast_Period + 2;
   
   double fast1 = MA_Fast[1];
   double fast2 = MA_Fast[2];
   double slow1 = MA_Slow[1];
   double slow2 = MA_Slow[2];
   
   if(fast2 <= slow2 && fast1 > slow1)
      return TREND_BULL;   // Golden Cross - BUY
   if(fast2 >= slow2 && fast1 < slow1)
      return TREND_BEAR;   // Death Cross - SELL
      
   return TREND_NONE;
}

//+------------------------------------------------------------------+
//| Check if new candle just formed                                  |
//+------------------------------------------------------------------+
bool IsNewCandle()
{
   datetime currentBar = iTime(_Symbol, MA_Timeframe, 0);
   if(currentBar == lastBarTime)
      return false;
   
   lastBarTime = currentBar;
   return true;
}

//+------------------------------------------------------------------+
//| Check PipStep condition                                          |
//+------------------------------------------------------------------+
bool CheckPipStep(ENUM_POSITION_TYPE type)
{
   double distance = GetLastEntryDistance(type);
   
   // If no positions, pipstep is automatically met
   if(distance == 0) return true;
   
   // If floating minus, check if distance >= pipstep
   return (distance >= PipStep);
}

//+------------------------------------------------------------------+
//| Check if signal is fresh (not same bar as last trade)            |
//+------------------------------------------------------------------+
bool IsSignalFresh(ENUM_TREND trend)
{
   datetime currentBar = iTime(_Symbol, MA_Timeframe, 0);
   return (currentBar != lastTradeBar);
}

//+------------------------------------------------------------------+
//| ON INIT                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   // Create MA handles
   handle_ma_fast = iMA(_Symbol, MA_Timeframe, MA_Fast_Period, 0, MA_Method, MA_Price);
   handle_ma_slow = iMA(_Symbol, MA_Timeframe, MA_Slow_Period, 0, MA_Method, MA_Price);
   
   if(handle_ma_fast == INVALID_HANDLE || handle_ma_slow == INVALID_HANDLE)
   {
      Print("❌ Failed to create MA handles!");
      return INIT_FAILED;
   }
   
   ArraySetAsSeries(MA_Fast, true);
   ArraySetAsSeries(MA_Slow, true);
   
   lastBarTime = iTime(_Symbol, MA_Timeframe, 0);
   
   Print("═══════════════════════════════════");
   Print("  7NAGA MA CROSS EA INITIALIZED");
   Print("  Fast MA : Period ", MA_Fast_Period, " ", EnumToString(MA_Method));
   Print("  Slow MA : Period ", MA_Slow_Period, " ", EnumToString(MA_Method));
   Print("  TF      : ", EnumToString(MA_Timeframe));
   Print("  BaseLot : ", BaseLot);
   Print("  Multiplier : ", LotMultiplier);
   Print("  MaxLayers : ", (int)MaxLayers);
   Print("  TP (pips) : ", TakeProfit_Pips);
   Print("  PipStep   : ", PipStep);
   Print("═══════════════════════════════════");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| ON DEINIT                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(handle_ma_fast);
   IndicatorRelease(handle_ma_slow);
   Print("EA Deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| ON TICK                                                           |
//+------------------------------------------------------------------+
void OnTick()
{
   // Only check ONCE per new candle
   if(!IsNewCandle())
      return;
   
   // Copy MA values
   if(CopyBuffer(handle_ma_fast, 0, 0, MA_Fast_Period + 2, MA_Fast) <= 0 ||
      CopyBuffer(handle_ma_slow, 0, 0, MA_Slow_Period + 2, MA_Slow) <= 0)
      return;
   
   ENUM_TREND signal = CheckCross();
   
   if(signal == TREND_NONE)
   {
      // No cross, check if we need to add layer (floating minus + pipstep met)
      // Only if we have existing positions
      
      int buyCount  = CountLayer(POSITION_TYPE_BUY);
      int sellCount = CountLayer(POSITION_TYPE_SELL);
      
      // Check BUY layering
      if(buyCount > 0)
      {
         double buyPL = CalculateFloatingPL(POSITION_TYPE_BUY);
         if(buyPL < 0 && CheckPipStep(POSITION_TYPE_BUY))
         {
            // Check if we have a BUY signal (MA fast above slow)
            double f1 = MA_Fast[1], s1 = MA_Slow[1];
            if(f1 > s1 && IsSignalFresh(signal))
            {
               Print("[LAYER BUY] Floating: ", DoubleToString(buyPL, 2),
                     " | Distance: ", DoubleToString(GetLastEntryDistance(POSITION_TYPE_BUY), 1),
                     " pips | Signal: BUY trending");
               OpenPosition(POSITION_TYPE_BUY);
               lastTradeBar = iTime(_Symbol, MA_Timeframe, 0);
            }
         }
      }
      
      // Check SELL layering
      if(sellCount > 0)
      {
         double sellPL = CalculateFloatingPL(POSITION_TYPE_SELL);
         if(sellPL < 0 && CheckPipStep(POSITION_TYPE_SELL))
         {
            double f1 = MA_Fast[1], s1 = MA_Slow[1];
            if(f1 < s1 && IsSignalFresh(signal))
            {
               Print("[LAYER SELL] Floating: ", DoubleToString(sellPL, 2),
                     " | Distance: ", DoubleToString(GetLastEntryDistance(POSITION_TYPE_SELL), 1),
                     " pips | Signal: SELL trending");
               OpenPosition(POSITION_TYPE_SELL);
               lastTradeBar = iTime(_Symbol, MA_Timeframe, 0);
            }
         }
      }
      
      // Update basket TP for existing positions
      if(buyCount > 0)
         SetBasketTP(POSITION_TYPE_BUY);
      if(sellCount > 0)
         SetBasketTP(POSITION_TYPE_SELL);
      
      return;
   }
   
   // === CROSS DETECTED ===
   
   // Determine direction
   ENUM_POSITION_TYPE dir = (signal == TREND_BULL) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   string dirStr = (signal == TREND_BULL) ? "BUY ⬆" : "SELL ⬇";
   
   Print("═══════════════════════════════════");
   Print("⚡ CROSS DETECTED: ", dirStr);
   Print("  MA Fast: ", MA_Fast[1], " | MA Slow: ", MA_Slow[1]);
   Print("═══════════════════════════════════");
   
   // Check if signal is fresh (not same bar as last trade)
   if(!IsSignalFresh(signal))
   {
      Print("[SKIP] Already traded on this bar.");
      return;
   }
   
   int existingCount = CountLayer(dir);
   int oppositeCount = (dir == POSITION_TYPE_BUY) ? CountLayer(POSITION_TYPE_SELL) : CountLayer(POSITION_TYPE_BUY);
   
   // === CLOSE REVERSE LOGIC ===
   if(CloseOnCrossReverse && oppositeCount > 0)
   {
      ENUM_POSITION_TYPE oppType = (dir == POSITION_TYPE_BUY) ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;
      
      double oppPL = CalculateFloatingPL(oppType);
      
      Print("[CLOSE REVERSE] Closing ", IntegerToString(oppositeCount),
            " opposite positions. P/L: ", DoubleToString(oppPL, 2));
      CloseAll(oppType);
      
      // Small delay to let positions close before opening new ones
      Sleep(500);
   }
   
   // === OPEN NEW POSITION ===
   if(existingCount < (int)MaxLayers)
   {
      Print("[OPEN] Opening ", dirStr, " position. Layer: ", existingCount + 1);
      bool ok = OpenPosition(dir);
      if(ok)
         lastTradeBar = iTime(_Symbol, MA_Timeframe, 0);
   }
   else
   {
      Print("[SKIP] Max layers reached for ", dirStr);
   }
}

//+------------------------------------------------------------------+
//| ON CALCULATE (indicator)                                          |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   return rates_total;
}
//+------------------------------------------------------------------+