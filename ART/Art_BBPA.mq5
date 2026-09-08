//+------------------------------------------------------------------+
//|                                              Omon_Strategy_V1.mq5 |
//|                                Copyright 2024, Trader Nakal™ Team |
//|                          Unified PA-BB with Structural SL & TP     |
//+------------------------------------------------------------------+
#property copyright "Trader Nakal™ — Omon Agent"
#property version   "2.00"
#include <Trade\Trade.mqh>
#include <Arrays\ArrayDouble.mqh>

input group      "=== Bollinger Bands Settings ==="
input int        InpBBPeriod     = 20;         // Periode Moving Average
input double     InpBBDev        = 2.0;        // Standard Deviations
input double     InpMinWidth     = 0.02;       // Lebar pita minimum (%) untuk validasi breakout

input group      "=== Price Action Settings ==="
input int        InpSwingPeriod  = 5;          // Candle sebelum/sesudah untuk cek Pivot

input group      "=== Structural SL / TP Settings ==="
input bool       InpUseStructuralSL = true;    // Gunakan SL/TP Dinamis Berdasarkan Struktur
input int        InpLookbackPeriod  = 20;      // Jarak pencarian struktur terdekat
input double     InpStructBuffer    = 0.001;   // Buffer ekstra (%) agar aman dari market wick
input int        InpMinSLPoints     = 30;      // Minimal jarak SL (Poin) untuk validasi entry

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
      default:
         break; 
   }
   
   last_bar_time = iTime(_Symbol, PERIOD_CURRENT, 0);
  }

//+------------------------------------------------------------------+
ENUM_SIGNAL EvaluateConfluence()
  {
   // --- 1. Cek Struktur Pasar (PA) ---
   ENUM_TREND trend = GetTrendState(InpSwingPeriod);
   if(trend == TREND_FLAT) return SIG_NONE;

   // --- 2. Cek Bollinger Bands ---
   ENUM_BB_MODE bb_mode = GetBBMode();
   double upper[], lower[];
   iBands(_Symbol, PERIOD_CURRENT, InpBBPeriod, 0, InpBBDev, PRICE_CLOSE, upper, lower);

   // --- 3. Logika KONFLUENSI (GABUNGAN) ---
   // BUY ONLY IF: Uptrend AND (Breakout Upper Band OR Walking Band Up)
   if(trend == TREND_BULL) {
      if(bb_mode == BB_UP_BREAK || bb_mode == BB_WALKING_BAND) {
         if(InpUseStructuralSL) ExecuteStructuralTrade(SIG_BUY, TREND_BULL);
         return SIG_BUY;
      }
      if(bb_mode == BB_RANGE && lower[0] > iClose(_Symbol, PERIOD_CURRENT, 0)) return SIG_NONE;
   }
   
   // SELL ONLY IF: Downtrend AND (Breakout Lower Band OR Walking Band Down)
   if(trend == TREND_BEAR) {
      if(bb_mode == BB_DOWN_BREAK || bb_mode == BB_WALKING_BAND) {
         if(InpUseStructuralSL) ExecuteStructuralTrade(SIG_SELL, TREND_BEAR);
         return SIG_SELL;
      }
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
// Fungsi mencari level struktur terdekat (Swing High/Low)
//+------------------------------------------------------------------+
double GetNearestStructurePrice(ENUM_TREND trend, int lookback = 20)
{
   double highs[], lows[];
   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, lookback, highs) <= 0) return 0;
   if(CopyLow (_Symbol, PERIOD_CURRENT, 0, lookback, lows)  <= 0) return 0;
   
   ArraySetAsSeries(highs, false); // Urut waktu (lama ke baru)
   ArraySetAsSeries(lows, false);
   
   if(trend == TREND_BULL) {
      // Untuk UPTREND: SL diletakkan di bawah Swing Low terakhir
      double avgLow = 0;
      for(int i=0; i<5; i++) avgLow += lows[i]; 
      avgLow /= 5;
      return NormalizeDouble(avgLow - (avgLow * InpStructBuffer), _Digits);
   }
   else if(trend == TREND_BEAR) {
      // Untuk DOWNTREND: SL diletakkan di atas Swing High terakhir
      double avgHigh = 0;
      for(int i=0; i<5; i++) avgHigh += highs[i];
      avgHigh /= 5;
      return NormalizeDouble(avgHigh + (avgHigh * InpStructBuffer), _Digits);
   }
   return 0;
}

//+------------------------------------------------------------------+
// Fungsi menghitung TP Target berdasarkan Resistance/Selanjutnya
//+------------------------------------------------------------------+
double GetStructuralTargetPrice(ENUM_TREND trend, int target_index = 20)
{
   double highs[], lows[];
   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, target_index, highs) <= 0) return 0;
   if(CopyLow (_Symbol, PERIOD_CURRENT, 0, target_index, lows)  <= 0) return 0;
   
   ArraySetAsSeries(highs, false);
   ArraySetAsSeries(lows, false);
   
   if(trend == TREND_BULL) {
      // Target TP adalah resistance tertinggi berikutnya dalam jangkauan
      double maxResistance = highs[target_index - 1]; 
      return NormalizeDouble(maxResistance + (maxResistance * InpStructBuffer), _Digits);
   }
   else if(trend == TREND_BEAR) {
      // Target TP adalah support terdalam berikutnya dalam jangkauan
      double minSupport = lows[target_index - 1];
      return NormalizeDouble(minSupport - (minSupport * InpStructBuffer), _Digits);
   }
   return 0;
}

//+------------------------------------------------------------------+
// Fungsi Eksekusi Entry dengan Parameter Structure-Based SL & TP
//+------------------------------------------------------------------+
bool ExecuteStructuralTrade(ENUM_SIGNAL signal, ENUM_TREND trend)
{
   if(!InpUseStructuralSL) return false;
   
   double ask  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl   = GetNearestStructurePrice(trend, InpLookbackPeriod);
   double tp   = GetStructuralTargetPrice(trend, InpLookbackPeriod);
   string type_str = "";
   
   // Validasi Jarak Minimum (Anti-Slipage & Terlalu Tipis)
   double dist_sl = (signal == SIG_BUY) ? (ask - sl) / Point() : (sl - bid) / Point();
   if(dist_sl < InpMinSLPoints) { 
      Print("⚠️ Struktur terlalu dekat. Skip entry.");
      return false;
   }
   
   // Tentukan Type Order
   if(signal == SIG_BUY) {
      type_str = "BUY";
      return trade.Buy(0.01, _Symbol, ask, sl, tp, "PA-BB Structural Buy");
   }
   else if(signal == SIG_SELL) {
      type_str = "SELL";
      return trade.Sell(0.01, _Symbol, bid, sl, tp, "PA-BB Structural Sell");
   }
   
   return false;
}
//+------------------------------------------------------------------+
