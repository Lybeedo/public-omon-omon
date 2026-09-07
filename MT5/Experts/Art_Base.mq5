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
input int    InpDeviation    = 15;         // Deviasi Open Posisi (Poin)
input string InpComment      = "ArtBase";   // Comment Order
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
   g_trade.SetDeviationInPoints(InpDeviation);  // Toleransi slipage dari Deviasi Input
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
   // Hemat resource: jalankan hanya di candle baru
   static datetime lastBarTime = 0;
   datetime curBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(curBarTime == lastBarTime) return;  // Candle sama → skip
   lastBarTime = curBarTime;             // Update tracker
   
   RefreshIndicator();
   
   // Verifikasi posisi berdasarkan Magic Number
   VerifyPositions();
   CheckSignal();
}

//+=================================================================+
//| VERIFIKASI POSISI (MAGIC NUMBER)                                  |
//+=================================================================+
void VerifyPositions()
{
   bool foundLong  = false;
   bool foundShort = false;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      if(posType == POSITION_TYPE_BUY)  foundLong  = true;
      if(posType == POSITION_TYPE_SELL) foundShort = true;
   }
   
   g_hasLong  = foundLong;
   g_hasShort = foundShort;
}

//+=================================================================+
//| AREA EDIT UTAMA — GANTI LOGIKA DI BAWAH INI                     |
//+=================================================================+
void CheckSignal()
{
   // Variable SL dan TP
   double sl = 0.0;
   double tp = 0.0;
   
   // Buka posisi LONG jika tidak ada posisi LONG dan IsLong() == true
   if(!g_hasLong && IsLong()) {
      ExecutePosition(ORDER_TYPE_BUY, sl, tp);
   }
   
   // Buka posisi SHORT jika tidak ada posisi SHORT dan IsShort() == true
   if(!g_hasShort && IsShort()) {
      ExecutePosition(ORDER_TYPE_SELL, sl, tp);
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
//| MODULE LONG (BUY) — KOSONG                                          |
//+=================================================================+
bool IsLong()
{
   // Masukkan logika buy di sini
   bool signal = false;
   if(signal) g_hasLong = true;
   return(signal);
}

//+=================================================================+
//| EKSEKUSI POSISI (UNIFIED)                                           |
//+=================================================================+
void ExecutePosition(ENUM_ORDER_TYPE type, double &sl, double &tp)
{
   // Hitung SL dan TP
   CalculateTargets(type, sl, tp);
   
   // Tentukan harga entry berdasarkan tipe order
   double entryPrice = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   string comment    = (type == ORDER_TYPE_BUY) ? "Long" : "Short";
   
   // Eksekusi posisi dengan lot pada parameter
   g_trade.PositionOpen(_Symbol, type, InpLot, entryPrice, sl, tp, comment);
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


//+------------------------------------------------------------------+
