//+------------------------------------------------------------------+
//| XAUUSD Swing EMA-RSI Strategy (H1)                                |
//| Fixed Lot - RR 1:2                                                |
//| v2.0 - Fixed & Ready for Backtest                                 |
//+------------------------------------------------------------------+
#property strict
#property version   "2.0"
#property icon      ""
#property link      ""
#property copyright "7NAGA Trading System"
#property description "XAUUSD Swing EMA-RSI Strategy on H1 with Fractal SL"

//+------------------------------------------------------------------+
//| INPUTS                                                             |
//+------------------------------------------------------------------+
input double LotSize      = 0.01;
input int    EMA_Fast     = 14;
input int    EMA_Slow     = 50;
input int    RSI_Period   = 14;
input double RSI_Buy      = 55.0;
input double RSI_Sell     = 45.0;
input int    SL_BufferPip = 400;
input double RR_Ratio     = 2.0;
input ulong  MagicNumber  = 20260203;

//+------------------------------------------------------------------+
//| GLOBAL HANDLES                                                    |
//+------------------------------------------------------------------+
int emaFastHandle;
int emaSlowHandle;
int rsiHandle;
int fractalHandle;

datetime lastBarTime = 0;

//+------------------------------------------------------------------+
//| OnInit                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   emaFastHandle = iMA(_Symbol, PERIOD_H1, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowHandle = iMA(_Symbol, PERIOD_H1, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   rsiHandle     = iRSI(_Symbol, PERIOD_H1, RSI_Period, PRICE_CLOSE);
   fractalHandle = iFractals(_Symbol, PERIOD_H1);

   if(emaFastHandle < 0 || emaSlowHandle < 0 || rsiHandle < 0 || fractalHandle < 0)
   {
      Print("[ERROR] Failed to create indicator handles!");
      return(INIT_FAILED);
   }

   Print("[OK] XAUUSD Swing EMA-RSI EA initialized");
   Print("   EMA Fast=", EMA_Fast, " | EMA Slow=", EMA_Slow, " | RSI=", RSI_Period);
   Print("   RSI Buy Threshold=", RSI_Buy, " | RSI Sell Threshold=", RSI_Sell);
   Print("   SL Buffer=", SL_BufferPip, " pip | RR Ratio=", RR_Ratio);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnDeinit                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(emaFastHandle != INVALID_HANDLE && emaFastHandle != 0)
      IndicatorRelease(emaFastHandle);
   if(emaSlowHandle != INVALID_HANDLE && emaSlowHandle != 0)
      IndicatorRelease(emaSlowHandle);
   if(rsiHandle != INVALID_HANDLE && rsiHandle != 0)
      IndicatorRelease(rsiHandle);
   if(fractalHandle != INVALID_HANDLE && fractalHandle != 0)
      IndicatorRelease(fractalHandle);

   Print("[OK] XAUUSD Swing EMA-RSI EA deinitialized. Reason=", reason);
}

//+------------------------------------------------------------------+
//| OnTick                                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- New bar check (H1)
   datetime currentBar = iTime(_Symbol, PERIOD_H1, 0);
   if(currentBar == lastBarTime)
      return;
   lastBarTime = currentBar;

   //--- Only check if no position on THIS symbol
   if(PositionSelect(_Symbol))
      return;

   //--- Get indicator buffers
   double emaFast[3], emaSlow[3], rsi[3];
   double fractalUp[10], fractalDown[10];

   if(CopyBuffer(emaFastHandle, 0, 1, 3, emaFast) <= 0) return;
   if(CopyBuffer(emaSlowHandle, 0, 1, 3, emaSlow) <= 0) return;
   if(CopyBuffer(rsiHandle, 0, 1, 3, rsi) <= 0) return;
   if(CopyBuffer(fractalHandle, 0, 0, 10, fractalUp) <= 0) return;
   if(CopyBuffer(fractalHandle, 1, 0, 10, fractalDown) <= 0) return;

   double closePrice = iClose(_Symbol, PERIOD_H1, 1);

   //--- Swing detection from fractals
   double lastSwingLow = 0, prevSwingLow = 0;
   double lastSwingHigh = 0, prevSwingHigh = 0;

   // Find last 2 swing lows
   for(int i = 2; i < 10; i++)
   {
      if(fractalDown[i] != 0)
      {
         if(lastSwingLow == 0)
            lastSwingLow = fractalDown[i];
         else
         {
            prevSwingLow = fractalDown[i];
            break;
         }
      }
   }

   // Find last 2 swing highs
   for(int i = 2; i < 10; i++)
   {
      if(fractalUp[i] != 0)
      {
         if(lastSwingHigh == 0)
            lastSwingHigh = fractalUp[i];
         else
         {
            prevSwingHigh = fractalUp[i];
            break;
         }
      }
   }

   //--- BUY Signal
   if(closePrice > emaSlow[1] &&
      emaFast[1] > emaSlow[1] &&
      closePrice > emaFast[1] &&
      rsi[1] > RSI_Buy &&
      lastSwingLow > prevSwingLow && lastSwingLow > 0)
   {
      double sl = lastSwingLow - SL_BufferPip * _Point;
      double tp = closePrice + (closePrice - sl) * RR_Ratio;
      OpenTrade(ORDER_TYPE_BUY, sl, tp);
   }

   //--- SELL Signal
   if(closePrice < emaSlow[1] &&
      emaFast[1] < emaSlow[1] &&
      closePrice < emaFast[1] &&
      rsi[1] < RSI_Sell &&
      lastSwingHigh < prevSwingHigh && lastSwingHigh > 0)
   {
      double sl = lastSwingHigh + SL_BufferPip * _Point;
      double tp = closePrice - (sl - closePrice) * RR_Ratio;
      OpenTrade(ORDER_TYPE_SELL, sl, tp);
   }
}

//+------------------------------------------------------------------+
//| OpenTrade                                                          |
//+------------------------------------------------------------------+
bool OpenTrade(ENUM_ORDER_TYPE type, double sl, double tp)
{
   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);

   req.action        = TRADE_ACTION_DEAL;
   req.symbol        = _Symbol;
   req.volume        = LotSize;
   req.type          = type;
   req.price         = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   req.sl            = sl;
   req.tp            = tp;
   req.deviation     = 30;
   req.magic         = MagicNumber;
   req.comment       = "XAU Swing EMA-RSI";

   if(!OrderSend(req, res))
   {
      Print("[ERROR] OrderSend failed! Retcode=", res.retcode, " Comment=", res.comment);
      return false;
   }

   if(res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_PLACED)
   {
      Print("[OK] ", (type == ORDER_TYPE_BUY ? "BUY" : "SELL"),
            " opened | Price=", req.price,
            " | SL=", sl, " | TP=", tp,
            " | Lot=", LotSize);
      return true;
   }
   else
   {
      Print("[WARN] Order placed but retcode=", res.retcode, " Comment=", res.comment);
      return false;
   }
}
//+------------------------------------------------------------------+
