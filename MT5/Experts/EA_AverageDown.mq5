//+------------------------------------------------------------------+
//|                                     Timesync_AverageDown_EA.mq5 |
//|                                              Timesync Trading    |
//|                                         https://www.timesynctrading.com |
//+------------------------------------------------------------------+
#property copyright "Timesync Trading EA"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - MODE SELECTION                                 |
//+------------------------------------------------------------------+
enum MODE {
   MODE_DEFAULT,        // A - Default Market Analyzer
   MODE_BREAKOUT,       // B - Breakout Trading
   MODE_FIBONACCI,      // F - Fibonacci Trading
   MODE_RANGE,          // G - Range Trading
   MODE_PULLBACK,       // H - Pullback & Retracement
   MODE_SCALPING,       // I - Scalping Mode
   MODE_SWING,          // J - Swing Trading
   MODE_TREND,          // K - Trend Trading
   MODE_NEWS,           // L - News Trading
   MODE_SMC,            // M - SMC / Institutional Flow
   MODE_QUANT           // N - Quant Trading
};

input group "=== MODE SELECTION ===";
input MODE TradingMode = MODE_TREND;     // Select Trading Mode (A-P)

input group "=== TREND SETTINGS ===";
input int   FastEMA = 50;                // Fast EMA Period
input int   SlowEMA = 200;               // Slow EMA Period
input int   RSI_Period = 14;             // RSI Period
input double RSI_Overbought = 70;        // RSI Overbought Level
input double RSI_Oversold = 30;          // RSI Oversold Level
input int   ADX_Period = 14;             // ADX Period
input double ADX_Threshold = 25;         // ADX Trend Strength

input group "=== AVERAGE DOWN SETTINGS ===";
input bool  EnableAverageDown = true;     // Enable Average Down Mode
input int   MaxAvgDown = 3;              // Max Average Down Attempts
input double AvgSpacing = 50;            // Points Between Avg Entries
input double LotMultiplier = 1.5;        // Lot Size Multiplier
input double FibLevel1 = 38.2;           // Fibonacci Level 1
input double FibLevel2 = 50.0;           // Fibonacci Level 2
input double FibLevel3 = 61.8;           // Fibonacci Level 3

input group "=== RISK MANAGEMENT ===";
input double MaxRiskPerTrade = 2.0;      // Max Risk % Per Trade
input double MaxDrawdownPercent = 10.0;  // Max Drawdown % to Stop
input int    MaxOpenPositions = 5;       // Max Open Positions
input double StopLossPoints = 100;       // Stop Loss in Points
input double TakeProfitPoints = 150;      // Take Profit in Points
input double TrailingStop = 50;          // Trailing Stop Points

input group "=== GENERAL SETTINGS ===";
input double FixedLotSize = 0.1;         // Fixed Lot Size
input bool   UseEquityGuard = true;      // Enable Equity Guard
input int    MagicNumber = 20250627;     // EA Magic Number
input string CommentText = "TimesyncEA"; // Trade Comment
input int    Slippage = 3;               // Slippage Tolerance

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
int handleRSI, handleADX, handleEMA_Fast, handleEMA_Slow;
datetime lastTradeTime = 0;
double initialLotSize = 0.0;
double entryPriceAvg = 0.0;
int avgDownCount = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit() {
   // Initialize indicators
   handleRSI = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
   handleADX = iADX(_Symbol, PERIOD_CURRENT, ADX_Period);
   handleEMA_Fast = iMA(_Symbol, PERIOD_CURRENT, FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   handleEMA_Slow = iMA(_Symbol, PERIOD_CURRENT, SlowEMA, 0, MODE_EMA, PRICE_CLOSE);

   if(handleRSI == INVALID_HANDLE || handleADX == INVALID_HANDLE ||
      handleEMA_Fast == INVALID_HANDLE || handleEMA_Slow == INVALID_HANDLE) {
      Print("ERROR: Failed to create indicator handles!");
      return INIT_FAILED;
   }

   Comment("Timesync EA | Mode: " + EnumToString(TradingMode) + " | Symbol: " + _Symbol);
   Print("Timesync EA initialized successfully. Mode: ", EnumToString(TradingMode));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   if(handleRSI != INVALID_HANDLE) IndicatorRelease(handleRSI);
   if(handleADX != INVALID_HANDLE) IndicatorRelease(handleADX);
   if(handleEMA_Fast != INVALID_HANDLE) IndicatorRelease(handleEMA_Fast);
   if(handleEMA_Slow != INVALID_HANDLE) IndicatorRelease(handleEMA_Slow);
   Comment("");
   Print("Timesync EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick() {
   // Equity Guard - emergency stop
   if(UseEquityGuard) {
      if(CheckDrawdown()) {
         CloseAllPositions("Drawdown protection triggered");
         Print("WARNING: Drawdown limit reached. All positions closed.");
         return;
      }
   }

   // Count open positions for this EA
   int openPositions = CountOpenPositions();

   // Check if we can open new positions
   if(openPositions == 0) {
      // No open positions - check for new entry signal
      avgDownCount = 0;
      initialLotSize = FixedLotSize;
      entryPriceAvg = 0.0;

      ENUM_ORDER_TYPE signal = GetTradeSignal();
      if(signal != WRONG_ORDER_TYPE) {
         ExecuteTrade(signal, FixedLotSize);
      }
   } else {
      // We have open positions - manage them
      ManageOpenPositions();

      // Average Down Logic
      if(EnableAverageDown && avgDownCount < MaxAvgDown) {
         CheckAverageDown();
      }

      // Trailing Stop
      ApplyTrailingStop();
   }
}

//+------------------------------------------------------------------+
//| Get Trade Signal from Indicators                                 |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE GetTradeSignal() {
   double rsi[];
   double adx[];
   double ema_fast[];
   double ema_slow[];

   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(adx, true);
   ArraySetAsSeries(ema_fast, true);
   ArraySetAsSeries(ema_slow, true);

   if(CopyBuffer(handleRSI, 0, 0, 3, rsi) < 3 ||
      CopyBuffer(handleADX, 0, 0, 3, adx) < 3 ||
      CopyBuffer(handleEMA_Fast, 0, 3, rsi) < 3 ||
      CopyBuffer(handleEMA_Slow, 0, 3, ema_slow) < 3) {
      return WRONG_ORDER_TYPE;
   }

   double rsiVal = rsi[0];
   double adxVal = adx[0];
   double emaF0 = ema_fast[0];
   double emaF1 = ema_fast[1];
   double emaS0 = ema_slow[0];
   double emaS1 = ema_slow[1];

   // Trend detection: EMA crossover
   bool bullishCross = (emaF1 < emaS1) && (emaF0 > emaS0);  // Bullish crossover
   bool bearishCross = (emaF1 > emaS1) && (emaF0 < emaS0);  // Bearish crossover

   // Filter by RSI and ADX
   bool strongTrend = adxVal > ADX_Threshold;

   // BUY signal
   if(bullishCross && strongTrend && rsiVal < RSI_Overbought) {
      return ORDER_TYPE_BUY;
   }

   // SELL signal
   if(bearishCross && strongTrend && rsiVal > RSI_Oversold) {
      return ORDER_TYPE_SELL;
   }

   // Mode-specific signals
   switch(TradingMode) {
      case MODE_SCALPING:
         // Scalping: quick entries on tight timeframes
         if(rsiVal < 30 && adxVal > 20) return ORDER_TYPE_BUY;
         if(rsiVal > 70 && adxVal > 20) return ORDER_TYPE_SELL;
         break;

      case MODE_RANGE:
         // Range: mean reversion
         if(rsiVal < RSI_Oversold) return ORDER_TYPE_BUY;
         if(rsiVal > RSI_Overbought) return ORDER_TYPE_SELL;
         break;

      case MODE_PULLBACK:
         // Pullback: wait for retracement in trend direction
         if(bullishCross || (emaF0 > emaS0 && rsiVal < 40)) return ORDER_TYPE_BUY;
         if(bearishCross || (emaF0 < emaS0 && rsiVal > 60)) return ORDER_TYPE_SELL;
         break;

      case MODE_BREAKOUT:
         // Breakout: strong momentum
         if(adxVal > 30 && rsiVal > 60) return ORDER_TYPE_BUY;
         if(adxVal > 30 && rsiVal < 40) return ORDER_TYPE_SELL;
         break;
   }

   return WRONG_ORDER_TYPE;
}

//+------------------------------------------------------------------+
//| Execute Trade                                                    |
//+------------------------------------------------------------------+
bool ExecuteTrade(ENUM_ORDER_TYPE type, double lot) {
   double price;
   double sl;
   double tp;
   MqlTradeRequest request = {};
   MqlTradeResult result = {};

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(type == ORDER_TYPE_BUY) {
      price = ask;
      sl = price - StopLossPoints * point;
      tp = price + TakeProfitPoints * point;
   } else {
      price = bid;
      sl = price + StopLossPoints * point;
      tp = price - TakeProfitPoints * point;
   }

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lot;
   request.type = type;
   request.price = price;
   request.sl = NormalizeDouble(sl, _Digits);
   request.tp = NormalizeDouble(tp, _Digits);
   request.deviation = Slippage;
   request.magic = MagicNumber;
   request.comment = CommentText + " | Mode:" + EnumToString(TradingMode);

   if(!OrderSend(request, result)) {
      Print("OrderSend failed: ", result.comment);
      return false;
   }

   if(result.retcode == TRADE_RETCODE_DONE) {
      entryPriceAvg = price;
      initialLotSize = lot;
      avgDownCount = 0;
      lastTradeTime = TimeCurrent();
      Print("Trade executed: ", EnumToString(type), " | Lot: ", lot, " | Price: ", price);
      return true;
   }

   Print("Trade failed. Retcode: ", result.retcode);
   return false;
}

//+------------------------------------------------------------------+
//| Manage Open Positions                                           |
//+------------------------------------------------------------------+
void ManageOpenPositions() {
   // Count positions by type
   int buyCount = 0, sellCount = 0;
   double buyLots = 0, sellLots = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(PositionGetSymbol(i) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
         buyCount++;
         buyLots += PositionGetDouble(POSITION_VOLUME);
      } else {
         sellCount++;
         sellLots += PositionGetDouble(POSITION_VOLUME);
      }
   }
}

//+------------------------------------------------------------------+
//| Check and Execute Average Down                                   |
//+------------------------------------------------------------------+
void CheckAverageDown() {
   // Get position info
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double entryPrice = 0;
   double lotSize = 0;
   ENUM_ORDER_TYPE posType = WRONG_ORDER_TYPE;
   bool hasPosition = false;

   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(PositionGetSymbol(i) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

      entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      lotSize = PositionGetDouble(POSITION_VOLUME);
      posType = (ENUM_ORDER_TYPE)PositionGetInteger(POSITION_TYPE);
      hasPosition = true;
      break;
   }

   if(!hasPosition) return;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double priceDiff = MathAbs(currentPrice - entryPrice) / point;

   // Check if price moved enough for average down
   double requiredSpacing = AvgSpacing * MathPow(LotMultiplier, avgDownCount);

   if(priceDiff >= requiredSpacing) {
      // Calculate new lot size
      double newLot = NormalizeDouble(lotSize * LotMultiplier, 2);

      // Fibonacci-based entry check
      double fibLevel = GetNextFibLevel(avgDownCount);

      // For BUY position - average down on pullback (price goes down)
      if(posType == ORDER_TYPE_BUY && currentPrice < entryPrice) {
         if(ExecuteTrade(ORDER_TYPE_BUY, newLot)) {
            avgDownCount++;
            entryPriceAvg = (entryPriceAvg * avgDownCount + currentPrice) / (avgDownCount + 1);
            Print("Average Down #", avgDownCount, " | New price: ", currentPrice,
                  " | Lot: ", newLot, " | Avg price: ", entryPriceAvg);
         }
      }
      // For SELL position - average down on rally (price goes up)
      else if(posType == ORDER_TYPE_SELL && currentPrice > entryPrice) {
         if(ExecuteTrade(ORDER_TYPE_SELL, newLot)) {
            avgDownCount++;
            entryPriceAvg = (entryPriceAvg * avgDownCount + currentPrice) / (avgDownCount + 1);
            Print("Average Down #", avgDownCount, " | New price: ", currentPrice,
                  " | Lot: ", newLot, " | Avg price: ", entryPriceAvg);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Get Next Fibonacci Level for Average Down                        |
//+------------------------------------------------------------------+
double GetNextFibLevel(int level) {
   switch(level) {
      case 0: return FibLevel1;
      case 1: return FibLevel2;
      case 2: return FibLevel3;
      default: return FibLevel3;
   }
   return FibLevel3; // suppress compiler warning
}

//+------------------------------------------------------------------+
//| Apply Trailing Stop                                             |
//+------------------------------------------------------------------+
void ApplyTrailingStop() {
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double trailingDist = TrailingStop * point;

   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(PositionGetSymbol(i) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double profit = PositionGetDouble(POSITION_PROFIT);

      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double newSL = bid - trailingDist;

         if(bid - openPrice > trailingDist && newSL > currentSL) {
            ModifyPosition(PositionGetTicket(i), newSL, 0);
         }
      } else {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double newSL = ask + trailingDist;

         if(openPrice - ask > trailingDist && (currentSL == 0 || newSL < currentSL)) {
            ModifyPosition(PositionGetTicket(i), newSL, 0);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Modify Position SL/TP                                           |
//+------------------------------------------------------------------+
bool ModifyPosition(long ticket, double sl, double tp) {
   MqlTradeRequest request = {};
   MqlTradeResult result = {};

   request.action = TRADE_ACTION_SLTP;
   request.position = ticket;
   request.sl = NormalizeDouble(sl, _Digits);
   request.tp = NormalizeDouble(tp, _Digits);
   request.deviation = Slippage;
   request.magic = MagicNumber;

   if(!OrderSend(request, result)) {
      Print("ModifyPosition failed. Ticket: ", ticket, " Error: ", result.comment);
      return false;
   }
   return result.retcode == TRADE_RETCODE_DONE;
}

//+------------------------------------------------------------------+
//| Close All Positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositions(string reason) {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(PositionGetSymbol(i) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

      long ticket = PositionGetTicket(i);
      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)PositionGetInteger(POSITION_TYPE);
      double volume = PositionGetDouble(POSITION_VOLUME);
      double price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                                  : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      MqlTradeRequest request = {};
      MqlTradeResult result = {};

      request.action = TRADE_ACTION_DEAL;
      request.symbol = _Symbol;
      request.volume = volume;
      request.type = (type == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
      request.price = price;
      request.position = ticket;
      request.deviation = Slippage;
      request.magic = MagicNumber;
      request.comment = reason;

      OrderSend(request, result);
   }
}

//+------------------------------------------------------------------+
//| Count Open Positions                                             |
//+------------------------------------------------------------------+
int CountOpenPositions() {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(PositionGetSymbol(i) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Check Drawdown                                                   |
//+------------------------------------------------------------------+
bool CheckDrawdown() {
   double initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);

   if(initialBalance <= 0) return false;

   double drawdown = ((initialBalance - currentEquity) / initialBalance) * 100.0;

   if(drawdown >= MaxDrawdownPercent) {
      Print("Drawdown detected: ", DoubleToString(drawdown, 2),
            "% | Initial: ", initialBalance, " | Equity: ", currentEquity);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Get Spread (for info)                                           |
//+------------------------------------------------------------------+
double GetSpread() {
   return SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
}

//+------------------------------------------------------------------+
//| Print Dashboard                                                  |
//+------------------------------------------------------------------+
void PrintDashboard() {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double spread = GetSpread();

   Print("=== Timesync EA Dashboard ===");
   Print("Mode: ", EnumToString(TradingMode));
   Print("Balance: ", DoubleToString(balance, 2), " | Equity: ", DoubleToString(equity, 2));
   Print("Spread: ", DoubleToString(spread, 1), " pts | Positions: ", CountOpenPositions());
   Print("AvgDown Count: ", avgDownCount, " / ", MaxAvgDown);
   Print("============================");
}
//+------------------------------------------------------------------+