//+------------------------------------------------------------------+
//|                                                   Art_DV.mq5 |
//|                                Copyright 2024, Trader Nakal™ Team |
//|                          Bollinger Band Reversal / "Divergence" V |
//+------------------------------------------------------------------+
#property copyright "Trader Nakal™ — Omon Agent"
#property version   "1.00"
#include <Trade\Trade.mqh>

input group "=== Bollinger Bands Settings ==="
input int    InpBBPeriod     = 20;         // Periode Moving Average
input double InpBBDeviation  = 2.0;        // Standard Deviations
input int    InpBBShift      = 0;          // Shift

input group "=== Execution Settings ==="
input bool   InpUseStructuralSL = true;    // Gunakan SL/TP Dinamis (Struktur)
input double InpLots            = 0.01;    // Volume Eksekusi (Default 0.01 Cent)

CTrade       trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(998877);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // --- Cek Posisi Terbuka ---
   if(PositionsTotal() > 0) return; // Hanya 1 posisi sekaligus

   // --- Ambil Data Bollinger Bands ---
   double upper[], middle[], lower[];
   ArraySetAsSeries(upper, true);
   ArraySetAsSeries(middle, true);
   ArraySetAsSeries(lower, true);

   // Copy data 3 candle terakhir untuk memastikan tidak ada lag
   if(CopyBuffer(iBands(_Symbol, PERIOD_CURRENT, InpBBPeriod, InpBBShift, InpBBDeviation, PRICE_CLOSE), 1, 0, 3, upper) < 3) return;
   if(CopyBuffer(iBands(_Symbol, PERIOD_CURRENT, InpBBPeriod, InpBBShift, InpBBDeviation, PRICE_CLOSE), 2, 0, 3, middle) < 3) return;
   if(CopyBuffer(iBands(_Symbol, PERIOD_CURRENT, InpBBPeriod, InpBBShift, InpBBDeviation, PRICE_CLOSE), 0, 0, 3, lower) < 3) return;

   // --- Logika BUY ---
   // Syarat: 
   // 1. Candle sebelumnya (Index 1) menyentuh/menembus Lower Band saat Low, tapi CLOSE di atasnya (Rejection Wick).
   // 2. Candle sebelum itu (Index 2) valid (Close > Lower Band).
   double low_1 = iLow(_Symbol, PERIOD_CURRENT, 1);
   double close_1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double close_2 = iClose(_Symbol, PERIOD_CURRENT, 2);
   double curr_lower_1 = lower[1];

   if(low_1 <= curr_lower_1 && close_1 > curr_lower_1 && close_2 > curr_lower_2)
   {
      Print("🟢 SIGNAL BUY: Rejection di Lower Band Terdeteksi!");
      ExecuteOrder(ORDER_TYPE_BUY);
   }

   // --- Logika SELL ---
   // Syarat:
   // 1. Candle sebelumnya (Index 1) menyentuh/menembus Upper Band saat High, tapi CLOSE di bawahnya.
   // 2. Candle sebelum itu (Index 2) valid (Close < Upper Band).
   double high_1 = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double close_sell_1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double close_sell_2 = iClose(_Symbol, PERIOD_CURRENT, 2);
   double curr_upper_1 = upper[1];

   if(high_1 >= curr_upper_1 && close_sell_1 < curr_upper_1 && close_sell_2 < curr_upper_2)
   {
      Print("🔴 SIGNAL SELL: Rejection di Upper Band Terdeteksi!");
      ExecuteOrder(ORDER_TYPE_SELL);
   }
  }

//+------------------------------------------------------------------+
//| Fungsi Eksekusi Order                                            |
//+------------------------------------------------------------------+
void ExecuteOrder(ENUM_ORDER_TYPE type)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = 0, tp = 0;

   // Hitung SL dinamis berdasarkan struktur jika diaktifkan
   if(InpUseStructuralSL)
   {
      if(type == ORDER_TYPE_BUY)
      {
         // Cari swing low terdekat untuk Buy SL
         double min_low = iLow(_Symbol, PERIOD_CURRENT, iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, 10, 1));
         sl = min_low - (min_low * 0.001); // Tambah buffer kecil
      }
      else
      {
         // Cari swing high terdekat untuk Sell SL
         double max_high = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, 10, 1);
         sl = max_high + (max_high * 0.001);
      }
   }

   if(type == ORDER_TYPE_BUY) {
      trade.Buy(InpLots, _Symbol, ask, sl, tp, "Art_BBPA Reversal Buy");
   } else {
      trade.Sell(InpLots, _Symbol, bid, sl, tp, "Art_BBPA Reversal Sell");
   }
}
//+------------------------------------------------------------------+
