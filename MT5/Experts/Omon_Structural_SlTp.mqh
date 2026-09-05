//+------------------------------------------------------------------+
//|                                     Omon_Structural_SlTp.mqh |
//|                                Copyright 2024, Trader Nakal™ Team |
//|                              Dynamic SL/TP berbasis Struktur Pasar|
//+------------------------------------------------------------------+
#pragma once

#include <Trade\Trade.mqh>
#include <Arrays\ArrayDouble.mqh>

CTrade           trade;

//+------------------------------------------------------------------+
// Fungsi mencari level struktur terdekat (Pivot High/Low Sederhana)
//+------------------------------------------------------------------+
double GetNearestStructurePrice(ENUM_TREND trend, int lookback = 20)
{
   double highs[], lows[];
   
   // Ambil data candle terakhir
   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, lookback, highs) <= 0) return 0;
   if(CopyLow (_Symbol, PERIOD_CURRENT, 0, lookback, lows)  <= 0) return 0;
   
   ArraySetAsSeries(highs, false); // Urut waktu (lama ke baru)
   ArraySetAsSeries(lows, false);
   
   // Logic Dinamis Berbasis Struktur
   if(trend == TREND_BULL) {
      // Untuk UPTREND: SL diletakkan di bawah *Swing Low* terakhir yang valid
      // Kita ambil rata-rata dari beberapa low terdekat agar tidak kena wick
      double avgLow = 0;
      for(int i=0; i<5; i++) avgLow += lows[i]; 
      avgLow /= 5;
      
      // Tambah buffer kecil (0.1% dari harga) agar aman dari market noise
      return NormalizeDouble(avgLow - (avgLow * 0.001), _Digits);
   }
   else if(trend == TREND_BEAR) {
      // Untuk DOWNTREND: SL diletakkan di atas *Swing High* terakhir yang valid
      double avgHigh = 0;
      for(int i=0; i<5; i++) avgHigh += highs[i];
      avgHigh /= 5;
      
      return NormalizeDouble(avgHigh + (avgHigh * 0.001), _Digits);
   }
   
   return 0;
}

//+------------------------------------------------------------------+
// Fungsi menghitung TP Target berdasarkan Resistance Selanjutnya
//+------------------------------------------------------------------+
double GetStructuralTargetPrice(ENUM_TREND trend, int target_index = 15)
{
   double highs[], lows[];
   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, target_index, highs) <= 0) return 0;
   if(CopyLow (_Symbol, PERIOD_CURRENT, 0, target_index, lows)  <= 0) return 0;
   
   ArraySetAsSeries(highs, false);
   ArraySetAsSeries(lows, false);
   
   if(trend == TREND_BULL) {
      // Target TP adalah resistance tertinggi berikutnya dalam jangkauan
      double maxResistance = highs[target_index - 1]; 
      return NormalizeDouble(maxResistance + (maxResistance * 0.001), _Digits);
   }
   else if(trend == TREND_BEAR) {
      // Target TP adalah support terdalam berikutnya dalam jangkauan
      double minSupport = lows[target_index - 1];
      return NormalizeDouble(minSupport - (minSupport * 0.001), _Digits);
   }
   
   return 0;
}

//+------------------------------------------------------------------+
// Fungsi Eksekusi Entry dengan Parameter Struktur
//+------------------------------------------------------------------+
bool ExecuteStructuralTrade(ENUM_SIGNAL signal, ENUM_TREND trend)
{
   double ask  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl   = 0, tp = 0;
   string type_str = "";
   
   // 1. Hitung SL & TP berdasar struktur pasar
   sl  = GetNearestStructurePrice(trend);
   tp  = GetStructuralTargetPrice(trend);
   
   // Validasi Jarak Minimum (Anti-Slipage)
   double dist_sl = (signal == SIG_BUY) ? (ask - sl) / Point() : (sl - bid) / Point();
   if(dist_sl < 30) { // Misal minimal 30 poin
      Print("⚠️ Spread terlalu tipis atau struktur terlalu dekat. Skip entry.");
      return false;
   }
   
   // 2. Tentukan Type Order
   if(signal == SIG_BUY) {
      type_str = "BUY";
      return trade.Buy(0.01, _Symbol, ask, sl, tp, "PA-BB Structural Buy"); // Default lot 0.01
   }
   else if(signal == SIG_SELL) {
      type_str = "SELL";
      return trade.Sell(0.01, _Symbol, bid, sl, tp, "PA-BB Structural Sell");
   }
   
   return false;
}
