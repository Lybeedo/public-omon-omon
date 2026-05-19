//+------------------------------------------------------------------+
//|              MTF_Integration_MQL5.mq5                             |
//|     Breakout & Pullback EA with MTF Filter (MQL5 Example)        |
//|                                v1.0                               |
//+------------------------------------------------------------------+
#property copyright "EFI SMART Trading System"
#property version   "1.00"
#property script_show_inputs

//--- Include MTF Filter Module
#include <MTF_Filter.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+

//=== Trading Parameters ===
input double   LotSize          = 0.1;          // Lot Size
input int      StopLoss         = 50;           // SL in points
input int      TakeProfit       = 100;          // TP in points (2R)
input int      BreakEvenLevel   = 20;           // Break Even trigger (points)
input ulong    MagicNumber      = 20250611;     // Magic Number

//=== Breakout Parameters ===
input int      LookbackPeriod   = 20;           // Breakout lookback period
input double   ATRMultiplier    = 0.5;          // ATR multiplier for zone
input int      ATRPeriod        = 14;           // ATR period

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
CMtfFilter g_MTFFilter;           // MTF Filter Instance
datetime   g_LastTradeTime;       // Prevent multiple trades per bar
double     g_ATR;                 // Current ATR value

//+------------------------------------------------------------------+
//| EXPERT INITIALIZATION                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize MTF Filter
   int initResult = g_MTFFilter.Init();
   if(initResult != INIT_SUCCEEDED)
   {
      Print("[ERROR] MTF Filter initialization failed!");
      return INIT_FAILED;
   }
   
   g_LastTradeTime = 0;
   Print("MTF Filter initialized. Filter TFs: D1=", EnumToString(g_MTF_Filter1), 
         " H4=", EnumToString(g_MTF_Filter2));
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| EXPERT DEINIT                                                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_MTFFilter.Deinit();
   Print("EA Deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| EXPERT TICKET                                                    |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Prevent multiple trades per bar
   datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentTime <= g_LastTradeTime) return;
   
   //--- Update MTF Filter
   g_MTFFilter.Refresh();
   
   //--- Get current ATR
   double atrArray[];
   ArraySetAsSeries(atrArray, true);
   CopyBuffer(iATR(_Symbol, PERIOD_CURRENT, ATRPeriod), 0, 0, 1, atrArray);
   g_ATR = atrArray[0];
   
   //--- Check for breakout signal
   CheckBreakoutSignal();
}

//+------------------------------------------------------------------+
//| CHECK BREAKOUT SIGNAL WITH MTF FILTER                            |
//+------------------------------------------------------------------+
void CheckBreakoutSignal()
{
   //--- Get current candle data
   double highArray[], lowArray[], closeArray[];
   ArraySetAsSeries(highArray, true);
   ArraySetAsSeries(lowArray, true);
   ArraySetAsSeries(closeArray, true);
   
   CopyClose(_Symbol, PERIOD_CURRENT, 0, LookbackPeriod + 1, closeArray);
   CopyHigh(_Symbol, PERIOD_CURRENT, 0, LookbackPeriod + 1, highArray);
   CopyLow(_Symbol, PERIOD_CURRENT, 0, LookbackPeriod + 1, lowArray);
   
   //--- Get highest high and lowest low over lookback period
   double highestHigh = highArray[1];
   double lowestLow   = lowArray[1];
   
   for(int i = 2; i <= LookbackPeriod; i++)
   {
      if(highArray[i] > highestHigh) highestHigh = highArray[i];
      if(lowArray[i] < lowestLow)   lowestLow   = lowArray[i];
   }
   
   //--- Get current close price
   double currentClose = closeArray[0];
   double currentHigh  = highArray[0];
   double currentLow   = lowArray[0];
   
   //--- Check for breakout
   bool bullishBreakout  = (currentHigh > highestHigh);
   bool bearishBreakout  = (currentLow  < lowestLow);
   
   //--- APPLY MTF FILTER HERE
   if(bullishBreakout)
   {
      //=== BULLISH BREAKOUT ===
      // Only allow if MTF filter permits LONG
      if(!g_MTFFilter.AllowLong())
      {
         Print("[MTF] BULLISH breakout detected but BLOCKED by MTF filter");
         Print("[MTF] Filter reason: ", g_MTFFilter.GetTrendInfo());
         return;
      }
      
      // Proceed with buy order
      OpenBuyOrder();
   }
   else if(bearishBreakout)
   {
      //=== BEARISH BREAKOUT ===
      // Only allow if MTF filter permits SHORT
      if(!g_MTFFilter.AllowShort())
      {
         Print("[MTF] BEARISH breakout detected but BLOCKED by MTF filter");
         Print("[MTF] Filter reason: ", g_MTFFilter.GetTrendInfo());
         return;
      }
      
      // Proceed with sell order
      OpenSellOrder();
   }
}

//+------------------------------------------------------------------+
//| OPEN BUY ORDER                                                   |
//+------------------------------------------------------------------+
void OpenBuyOrder()
{
   MqlTradeRequest request = {};
   MqlTradeResult  result  = {};
   
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl  = NormalizeDouble(ask - StopLoss * _Point, _Digits);
   double tp  = NormalizeDouble(ask + TakeProfit * _Point, _Digits);
   
   request.action    = TRADE_ACTION_DEAL;
   request.symbol    = _Symbol;
   request.volume    = LotSize;
   request.type      = ORDER_TYPE_BUY;
   request.price     = ask;
   request.sl        = sl;
   request.tp        = tp;
   request.deviation = 3;
   request.magic     = MagicNumber;
   request.comment   = "MTF Breakout BUY";
   
   if(!OrderSend(request, result))
   {
      Print("[BUY] Order failed. Retcode: ", result.retcode, 
            " Comment: ", result.comment);
   }
   else if(result.retcode == TRADE_RETCODE_DONE)
   {
      Print("[BUY] Order opened. Ticket: ", result.order);
      Print("[MTF] Trend: ", g_MTFFilter.GetTrendInfo());
      g_LastTradeTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   }
}

//+------------------------------------------------------------------+
//| OPEN SELL ORDER                                                  |
//+------------------------------------------------------------------+
void OpenSellOrder()
{
   MqlTradeRequest request = {};
   MqlTradeResult  result  = {};
   
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl  = NormalizeDouble(bid + StopLoss * _Point, _Digits);
   double tp  = NormalizeDouble(bid - TakeProfit * _Point, _Digits);
   
   request.action    = TRADE_ACTION_DEAL;
   request.symbol    = _Symbol;
   request.volume    = LotSize;
   request.type      = ORDER_TYPE_SELL;
   request.price     = bid;
   request.sl        = sl;
   request.tp        = tp;
   request.deviation = 3;
   request.magic     = MagicNumber;
   request.comment   = "MTF Breakout SELL";
   
   if(!OrderSend(request, result))
   {
      Print("[SELL] Order failed. Retcode: ", result.retcode,
            " Comment: ", result.comment);
   }
   else if(result.retcode == TRADE_RETCODE_DONE)
   {
      Print("[SELL] Order opened. Ticket: ", result.order);
      Print("[MTF] Trend: ", g_MTFFilter.GetTrendInfo());
      g_LastTradeTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   }
}

//+------------------------------------------------------------------+
//| EXPERT COMMENTARY                                                |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   Comment("\n",
           "=== MTF FILTER STATUS ===\n",
           g_MTFFilter.GetTrendInfo(), "\n",
           "=====================\n",
           "MTF Enabled: ", g_MTF_Enabled ? "YES" : "NO");
}

//+------------------------------------------------------------------+
//| END OF EA                                                        |
//+------------------------------------------------------------------+