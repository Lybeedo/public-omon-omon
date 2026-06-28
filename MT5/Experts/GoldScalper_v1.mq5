//+------------------------------------------------------------------+
//|                                              GoldScalper_v1.mq5 |
//|                                  Copyright 2026, Lead MQL5 Dev   |
//|                                          Developed for Bambang  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Lead MQL5 Dev"
#property link      "https://cuancux.com"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//--- INPUT PARAMETERS
input group "=== SYMBOL SETTINGS ==="
input string InpTargetSymbol   = "XAUUSD";   // Target Symbol (e.g. XAUUSD)

input group "=== RISK MANAGEMENT ==="
input double InpLotSize        = 0.01;       // Fixed Lot Size
input int    InpStopLoss       = 200;        // Stop Loss (Points)
input int    InpTakeProfit     = 400;        // Take Profit (Points)
input int    InpMagicNumber    = 998877;     // Magic Number

input group "=== STRATEGY SETTINGS ==="
input int    InpRSI_Period     = 14;         // RSI Period
input int    InpRSI_Overbought = 70;         // RSI Overbought Level
input int    InpRSI_Oversold   = 30;         // RSI Oversold Level
input int    InpEMA_Period     = 200;        // Trend EMA Period

//--- GLOBAL VARIABLES
int      g_handleRSI;           // RSI Indicator Handle
int      g_handleEMA;           // EMA Indicator Handle
CTrade   g_trade;               // Trading Class instance

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // 1. Symbol Check
   if(_Symbol != InpTargetSymbol)
   {
      Print("GoldScalper: Symbol mismatch! Target: ", InpTargetSymbol, " | Current: ", _Symbol);
      return(INIT_FAILED);
   }

   // 2. Initialize Indicator Handles
   g_handleRSI = iRSI(_Symbol, _Period, InpRSI_Period, PRICE_CLOSE);
   g_handleEMA = iMA(_Symbol, _Period, InpEMA_Period, 0, MODE_EMA, PRICE_CLOSE);

   if(g_handleRSI == INVALID_HANDLE || g_handleEMA == INVALID_HANDLE)
   {
      Print("GoldScalper: Failed to create indicator handles.");
      return(INIT_FAILED);
   }

   // 3. Setup Trade Class
   g_trade.SetExpertMagicNumber(InpMagicNumber);

   Print("GoldScalper v1.0 initialized successfully on ", _Symbol);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(g_handleRSI);
   IndicatorRelease(g_handleEMA);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // We only want to trade on a new candle to avoid multiple entries in one bar
   if(!IsNewBar()) return;

   double rsi_buffer[];
   double ema_buffer[];
   double close_buffer[];
   
   ArraySetAsSeries(rsi_buffer, true);
   ArraySetAsSeries(ema_buffer, true);
   ArraySetAsSeries(close_buffer, true);

   // Copy indicator and price data
   if(CopyBuffer(g_handleRSI, 0, 0, 3, rsi_buffer) < 3) return;
   if(CopyBuffer(g_handleEMA, 0, 0, 3, ema_buffer) < 3) return;
   if(CopyClose(_Symbol, _Period, 0, 3, close_buffer) < 3) return;

   double currentRSI = rsi_buffer[1];
   double prevRSI    = rsi_buffer[2];
   double currentEMA = ema_buffer[1];
   double currentClose = close_buffer[1];

   // Check if we already have an open position with this magic number
   if(PositionSelectByMagic(InpMagicNumber)) return;

   //--- BUY LOGIC
   // 1. Price is above 200 EMA (Uptrend)
   // 2. RSI crosses ABOVE the Oversold level (Momentum returning)
   if(currentClose > currentEMA && prevRSI < InpRSI_Oversold && currentRSI >= InpRSI_Oversold)
   {
      double sl = (InpStopLoss > 0) ? (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - InpStopLoss * _Point) : 0;
      double tp = (InpTakeProfit > 0) ? (SymbolInfoDouble(_Symbol, SYMBOL_ASK) + InpTakeProfit * _Point) : 0;
      
      Print("GoldScalper: BUY signal detected.");
      g_trade.Buy(InpLotSize, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), sl, tp, "GoldScalper Buy");
   }

   //--- SELL LOGIC
   // 1. Price is below 200 EMA (Downtrend)
   // 2. RSI crosses BELOW the Overbought level (Momentum reversing)
   if(currentClose < currentEMA && prevRSI > InpRSI_Overbought && currentRSI <= InpRSI_Overbought)
   {
      double sl = (InpStopLoss > 0) ? (SymbolInfoDouble(_Symbol, SYMBOL_BID) + InpStopLoss * _Point) : 0;
      double tp = (InpTakeProfit > 0) ? (SymbolInfoDouble(_Symbol, SYMBOL_BID) - InpTakeProfit * _Point) : 0;

      Print("GoldScalper: SELL signal detected.");
      g_trade.Sell(InpLotSize, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), sl, tp, "GoldScalper Sell");
   }
}

//+------------------------------------------------------------------+
//| Helper: Check for new candle                                     |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   static datetime last_time = 0;
   datetime current_time = iTime(_Symbol, _Period, 0);
   if(current_time != last_time)
   {
      last_time = current_time;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Helper: Check if position exists by Magic Number                 |
//+------------------------------------------------------------------+
bool PositionSelectByMagic(long magic)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == magic && PositionGetString(POSITION_SYMBOL) == _Symbol)
            return true;
      }
   }
   return false;
}
