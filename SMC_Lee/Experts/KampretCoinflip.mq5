//+------------------------------------------------------------------+
//| KampretCoinflip.mq5                                              |
//| XAUUSD Scalping - Dar Der Dor Style                              |
//| BUY + SELL SIMULTAN di Current Price                            |
//| No indikator. Coinflip. Gas terus.                               |
//+------------------------------------------------------------------+
#property strict
#property version   "1.0"
#property icon      ""
#property link      ""
#property copyright "7NAGA Trading System"
#property description "XAUUSD Scalping - Dar Der Dor. No indikator. Just gas."

//+------------------------------------------------------------------+
//| INPUTS                                                             |
//+------------------------------------------------------------------+
input double LotSize      = 0.01;   // Lot per posisi
input int    SL_Pip       = 300;    // Stop Loss dalam pip
input int    TP_Pip       = 600;    // Take Profit dalam pip (RR 1:2)
input int    MaxPosisi    = 1;      // Max posisi aktif per arah (1 = 1 BUY + 1 SELL)
input ulong  MagicBuy     = 20260204;
input ulong  MagicSell    = 20260205;
input string commentBuy   = "Kampret BUY";
input string commentSell = "Kampret SELL";
input int    Slippage     = 50;     // Slippage tolerance

//+------------------------------------------------------------------+
//| OnInit                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("==========================================");
   Print("   KAMPRET COINFLIP - Dar Der Dor Mode");
   Print("==========================================");
   Print("   Lot       : ", LotSize);
   Print("   SL        : ", SL_Pip, " pip");
   Print("   TP        : ", TP_Pip, " pip");
   Print("   RR Ratio  : 1:", DoubleToString(TP_Pip/(double)SL_Pip, 1));
   Print("   Max Posisi: ", MaxPosisi, " BUY + ", MaxPosisi, " SELL");
   Print("==========================================");
   Print("   NO INDIKATOR. NO ANALYSIS. JUST GAS!");
   Print("==========================================");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnDeinit                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("[OK] Kampret Coinflip EA stopped. Reason=", reason);
}

//+------------------------------------------------------------------+
//| OnTick                                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Count existing positions per direction
   int countBuy  = CountPositions(MagicBuy);
   int countSell = CountPositions(MagicSell);

   //--- Open BUY if below max
   if(countBuy < MaxPosisi)
   {
      OpenBuy();
   }

   //--- Open SELL if below max
   if(countSell < MaxPosisi)
   {
      OpenSell();
   }
}

//+------------------------------------------------------------------+
//| CountPositions                                                      |
//+------------------------------------------------------------------+
int CountPositions(ulong magic)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == magic)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| OpenBuy                                                             |
//+------------------------------------------------------------------+
bool OpenBuy()
{
   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);

   double ask       = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl        = ask - SL_Pip * _Point;
   double tp        = ask + TP_Pip * _Point;

   req.action        = TRADE_ACTION_DEAL;
   req.symbol        = _Symbol;
   req.volume        = LotSize;
   req.type          = ORDER_TYPE_BUY;
   req.price         = ask;
   req.sl            = sl;
   req.tp            = tp;
   req.deviation     = Slippage;
   req.magic         = MagicBuy;
   req.comment       = commentBuy;

   if(!OrderSend(req, res))
   {
      Print("[ERROR] BUY OrderSend failed! Retcode=", res.retcode);
      return false;
   }

   if(res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_PLACED)
   {
      Print("[BUY] Kampret BUY opened @ ", ask, " | SL=", sl, " | TP=", tp);
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| OpenSell                                                            |
//+------------------------------------------------------------------+
bool OpenSell()
{
   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);

   double bid       = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl        = bid + SL_Pip * _Point;
   double tp        = bid - TP_Pip * _Point;

   req.action        = TRADE_ACTION_DEAL;
   req.symbol        = _Symbol;
   req.volume        = LotSize;
   req.type          = ORDER_TYPE_SELL;
   req.price         = bid;
   req.sl            = sl;
   req.tp            = tp;
   req.deviation     = Slippage;
   req.magic         = MagicSell;
   req.comment       = commentSell;

   if(!OrderSend(req, res))
   {
      Print("[ERROR] SELL OrderSend failed! Retcode=", res.retcode);
      return false;
   }

   if(res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_PLACED)
   {
      Print("[SELL] Kampret SELL opened @ ", bid, " | SL=", sl, " | TP=", tp);
      return true;
   }

   return false;
}
//+------------------------------------------------------------------+
