//+------------------------------------------------------------------+
//|                                               Art_Base_Template.mq5 |
//|                                Copyright 2024, Trader Nakal™ Team   |
//|                    Art Analyst Base Template — Use Only When Asked  |
//+------------------------------------------------------------------+
#property copyright "Trader Nakal™ — Omon Agent"
#property version   "1.01"
#include <Trade\Trade.mqh>

input group "=== Indikator Utama ==="
input int    InpBBPeriod     = 20;         // Periode Bollinger Band
input double InpBBDev        = 2.0;        // Deviasi Standard

input group "=== Manajemen Modal & Risk ==="
input double InpLot          = 0.01;       // Volume Default (Cent)
int      InpMagicNumber      = 8888;     // ID Unik EA — Hoki Primbon

//+=================================================================+
//| VARIABEL GLOBAL ENGINE                                          |
//+=================================================================+
CTrade       g_trade;                    // Objek eksekusi presisi
int          g_h_bands;                  // Handle Indikator
double       g_buf_upper[], g_buf_lower[], g_buf_mid[]; // Buffer Pita
bool         g_hasLong  = false;   // Flag posisi LONG aktif
bool         g_hasShort = false;   // Flag posisi SHORT aktif

//+=================================================================+
//| INITIALIZATION (JALAN SEKALI SAAT MULAI)                        |
//+=================================================================+
int OnInit()
{
   // Setup Object Trade Presisi
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK); // Full Or Kill
   g_trade.SetDeviationInPoints(30);          // Toleransi slipage
   g_trade.SetAsyncMode(false);               // Pastikan blocking untuk debugging
   
   // Deklarasikan Indikator Sekali Saja
   g_h_bands = iBands(_Symbol, _Period, InpBBPeriod, 0, InpBBDev, PRICE_CLOSE);
   
   // Konfigurasi Array biar index 0 itu candle terbaru
   ArraySetAsSeries(g_buf_upper, true);
   ArraySetAsSeries(g_buf_lower, true);
   ArraySetAsSeries(g_buf_mid, true);
   
   Print("✅ [SYSTEM] Genetic Base Loaded | Magic: ", InpMagicNumber);
   return(INIT_SUCCEEDED);
}

void OnDeinit()
{
   if(g_h_bands != INVALID_HANDLE) IndicatorRelease(g_h_bands);
}

//+=================================================================+
//| JANTUNG SISTEM (ON TICK)                                        |
//+=================================================================+
void OnTick()
{
   // Reset flag saat semua posisi tertutup
   if(PositionsTotal() == 0) {
      g_hasLong  = false;
      g_hasShort = false;
   }
   
   // 1. Keamanan: Stop jika ada posisi terbuka milik EA ini
   if(PositionsTotal() > 0) return;
   
   RefreshIndicator();
   CheckSignal();
}

//+=================================================================+
//| AREA EDIT UTAMA — GANTI LOGIKA DI BAWAH INI                     |
//+=================================================================+
void CheckSignal()
{
   // Ambil data dari CANDLE YANG SUDAH CLOSE (bukan yang sedang forming)
   // Index 1 = candle terakhir tertutup, Index 0 = candle yang sedang berjalan
   double low_prev  = iLow(_Symbol, PERIOD_CURRENT, 1);
   double high_prev = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double close_prev= iClose(_Symbol, PERIOD_CURRENT, 1);
   double close_2   = iClose(_Symbol, PERIOD_CURRENT, 2);
   
   // Data BB dari candle terakhir yang sudah close
   double curr_lower= g_buf_lower[1];
   double curr_upper= g_buf_upper[1];
   
   // --- MODULE TINGKAT TINGGI (LOGIC TRADING) ---
   bool short_setup = IsShort();
   bool long_setup  = IsLong();
   
   if(short_setup) {
      double sl = 0, tp = 0;
      CalculateTargets(ORDER_TYPE_SELL, sl, tp);
      ExecutePreciseOrder(ORDER_TYPE_SELL, sl, tp, "Short");
   }
   
   else if(long_setup) {
      double sl = 0, tp = 0;
      CalculateTargets(ORDER_TYPE_BUY, sl, tp);
      ExecutePreciseOrder(ORDER_TYPE_BUY, sl, tp, "Long");
   }
}

//+=================================================================+
//| MODULE SHORT (SELL) — KOSONG                                      |
//+=================================================================+
bool IsShort()
{
   // Masukkan logika sell di sini
   bool signal = false;
   if(signal) g_hasShort = true;
   return(signal);
}

//+=================================================================+
//| MODULE LONG (BUY) — KOSONG                                         |
//+=================================================================+
bool IsLong()
{
   // Masukkan logika buy di sini
   bool signal = false;
   if(signal) g_hasLong = true;
   return(signal);
}

//+=================================================================+
//| REFRESH INDICATOR DATA                                             |
//+=================================================================+
void RefreshIndicator()
{
   // Ambil data terbaru dari indikator
   if(CopyBuffer(g_h_bands, 2, 0, 3, g_buf_upper) < 3) return; 
   if(CopyBuffer(g_h_bands, 0, 0, 3, g_buf_lower) < 3) return; 
   if(CopyBuffer(g_h_bands, 1, 0, 3, g_buf_mid)   < 3) return; 
}

//+=================================================================+
//| FUNGSI PERHITUNGAN TARGET (SL/TP)                               |
//+=================================================================+
void CalculateTargets(ENUM_ORDER_TYPE type, double &sl_out, double &tp_out)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double pt  = _Point;
   
   // Contoh TP Dinamis: 70% lebar pita Bollinger Band
   double bb_width = g_buf_upper[0] - g_buf_lower[0];
   double profit_target = NormalizeDouble(bb_width * 0.7, _Digits);
   
   // Tentukan SL dan TP berdasarkan tipe order
   if(type == ORDER_TYPE_BUY) {
      sl_out = bid - (pt * 50); // Fallback default
      tp_out = bid + profit_target;
   } else {
      sl_out = ask + (pt * 50); // Fallback default
      tp_out = ask - profit_target;
   }
}

//+=================================================================+
//| FUNGSI EKSEKUSI FIX API                                         |
//+=================================================================+
void ExecutePreciseOrder(ENUM_ORDER_TYPE type, double sl, double tp, string comment)
{
   double price = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double pt    = _Point;
   
   // Validasi keamanan jarak SL minimal
   double dist_sl = (type == ORDER_TYPE_BUY) ? NormalizeDouble((price - sl)/pt, 0) : NormalizeDouble((sl - price)/pt, 0);
   if(dist_sl < 20) {
      Print("⚠️ [WARNING] Jarak SL terlalu tipis (<20pt). Entry dibatalkan.");
      return;
   }
   
   // Eksekusi koordinat presisi (Strict/Fix API)
   if(type == ORDER_TYPE_BUY) {
      g_trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, InpLot, price, sl, tp, comment);
   } else {
      g_trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, InpLot, price, sl, tp, comment);
   }
}
//+------------------------------------------------------------------+
