//+------------------------------------------------------------------+
//|                                                 Omon_Strategy.mq5 |
//|                                Copyright 2024, Trader Nakal™ Team |
//+------------------------------------------------------------------+
#property copyright "Trader Nakal™ — Omon Agent"
#property version   "1.00"
#include <Trade/Trade.mqh>
#include <Arrays\ArrayDouble.mqh>

input group      "=== Bollinger Bands Settings ==="
input int        InpBBPeriod     = 20;         // Periode Moving Average
input double     InpBBDev        = 2.0;        // Standard Deviations
input double     InpMinWidth     = 0.02;       // Lebar pita minimum (%) untuk validasi breakout

input group      "=== Price Action Settings ==="
input int        InpSwingPeriod  = 5;          // Candle sebelum/sesudah untuk cek Pivot

CTrade           trade;

// Enum Status Pasar
enum ENUM_TREND { TREND_BULL, TREND_BEAR, TREND_FLAT };
enum ENUM_BB_MODE { BB_RANGE, BB_UP_BREAK, BB_DOWN_BREAK, BB_WALKING_BAND };
enum ENUM_SIGNAL { SIG_NONE, SIG_BUY, SIG_SELL, SIG_EXIT };

//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(999888);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   static datetime last_bar_time = 0;
   if(iTime(_Symbol, PERIOD_CURRENT, 0) == last_bar_time) return;
   
   ENUM_SIGNAL signal = EvaluateConfluence();
   
   // Output ke Terminal
   switch(signal) {
      case SIG_BUY:
         Print("🟢 SIGNAL BUY DETECTED: Struktur Naik + BB Breaking Up");
         break;
      case SIG_SELL:
         Print("🔴 SIGNAL SELL DETECTED: Struktur Turun + BB Breaking Down");
         break;
      case SIG_NONE:
         break; 
   }
   
   last_bar_time = iTime(_Symbol, PERIOD_CURRENT, 0);
  }

//+------------------------------------------------------------------+
ENUM_SIGNAL EvaluateConfluence()
  {
   // --- 1. Cek Struktur Pasar (PA) ---
   ENUM_TREND trend = GetTrendState(InpSwingPeriod);
   if(trend == TREND_FLAT) return SIG_NONE; // Jangan trade saat flat

   // --- 2. Cek Bollinger Bands ---
   ENUM_BB_MODE bb_mode = GetBBMode();
   double upper[], lower[];
   iBands(_Symbol, PERIOD_CURRENT, InpBBPeriod, 0, InpBBDev, PRICE_CLOSE, upper, lower);

   // --- 3. Logika KONFLUENSI (GABUNGAN) ---
   // BUY ONLY IF: Uptrend AND (Breakout Upper Band OR Walking Band Up)
   if(trend == TREND_BULL) {
      if(bb_mode == BB_UP_BREAK || bb_mode == BB_WALKING_BAND) return SIG_BUY;
      if(bb_mode == BB_RANGE && lower[0] > iClose(_Symbol, PERIOD_CURRENT, 0)) return SIG_NONE; // Still safe inside band
   }
   
   // SELL ONLY IF: Downtrend AND (Breakout Lower Band OR Walking Band Down)
   if(trend == TREND_BEAR) {
      if(bb_mode == BB_DOWN_BREAK || bb_mode == BB_WALKING_BAND) return SIG_SELL;
   }

   return SIG_NONE;
  }

//+------------------------------------------------------------------+
ENUM_BB_MODE GetBBMode()
  {
   double upper[], middle[], lower[];
   iBands(_Symbol, PERIOD_CURRENT, InpBBPeriod, 0, InpBBDev, PRICE_CLOSE, upper, middle, lower);
   
   double currClose = iClose(_Symbol, PERIOD_CURRENT, 0);
   double prevClose = iClose(_Symbol, PERIOD_CURRENT, 1);
   double width = upper[0] - lower[0];
   double percentage_width = (width / middle[0]) * 100;
   
   // Deteksi Walking the Band (Tren Sangat Kuat)
   if(currClose > middle[0] && currClose > upper[0] && percentage_width > InpMinWidth) 
      return BB_WALKING_BAND;
      
   // Deteksi Breakout Biasa
   if(currClose > upper[0] && prevClose <= upper[0]) return BB_UP_BREAK;
   if(currClose < lower[0] && prevClose >= lower[0]) return BB_DOWN_BREAK;
   
   return BB_RANGE;
  }

//+------------------------------------------------------------------+
ENUM_TREND GetTrendState(int period)
  {
   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   CopyHigh(_Symbol, PERIOD_CURRENT, 0, 20, highs);
   CopyLow (_Symbol, PERIOD_CURRENT, 0, 20, lows);
   
   // Cari swing terkini
   int ph = ArrayMaximum(highs, 0, period + 1); 
   int pl = ArrayMinimum(lows,  0, period + 1);
   
   // Pastikan data cukup panjang
   if(ph >= period && pl >= period) {
      bool isBull = (highs[ph] > highs[ph-1] && lows[pl] > lows[pl-1]); // HH + HL
      bool isBear = (lows[pl] < lows[pl-1] && highs[ph] < highs[ph-1]); // LL + LH
      
      if(isBull) return TREND_BULL;
      if(isBear) return TREND_BEAR;
   }
   return TREND_FLAT;
  }
//+------------------------------------------------------------------+
