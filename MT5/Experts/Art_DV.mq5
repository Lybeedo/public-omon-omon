//+------------------------------------------------------------------+
//|                                                   Art_DV.mq5 |
//|                                Copyright 2024, Trader Nakal™ Team |
//|                          Bollinger Band Reversal / "Divergence" V |
//|                      Optimized using CTrade::PositionOpen (Fix)  |
//+------------------------------------------------------------------+
#property copyright "Trader Nakal™ — Omon Agent"
#property version   "1.02"
#include <Trade\Trade.mqh>

input group "=== Bollinger Bands Settings ==="
input int    InpBBPeriod     = 20;         // Periode Moving Average
input double InpBBDeviation  = 2.0;        // Standard Deviations
input int    InpBBShift      = 0;          // Shift

input group "=== Execution & Take Profit ==="
input bool   InpUseStructuralSL = true;    // Gunakan SL/TP Dinamis (Struktur)
input double InpLots            = 0.01;    // Volume Eksekusi (Default 0.01 Cent)
input double InpBbWidthRatio    = 0.7;     // % Lebar Pita untuk Target Profit (TP)

CTrade       trade;

//+------------------------------------------------------------------+
//| Variabel Global untuk Handle Indikator                           |
//+------------------------------------------------------------------+
int    g_bands_handle = INVALID_HANDLE;   // Handle untuk Bollinger Bands
double g_buff_upper[];                    // Buffer Upper Band
double g_buff_lower[];                    // Buffer Lower Band
double g_buff_mid[];                      // Buffer Middle Band
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // 1. Deklarasikan dan Inisialisasi Indikator Sekali Saja
   g_bands_handle = iBands(_Symbol, _Period, InpBBPeriod, InpBBShift, InpBBDeviation, PRICE_CLOSE);
   
   if(g_bands_handle == INVALID_HANDLE)
     {
      PrintFormat("Gagal membuat indikator Bollinger Bands! Error code: %d", GetLastError());
      return(INIT_FAILED);
     }
   
   // Atur properti agar array otomatis menjadi Time Series (candle terbaru di index 0)
   ArraySetAsSeries(g_buff_upper, true);
   ArraySetAsSeries(g_buff_lower, true);
   ArraySetAsSeries(g_buff_mid, true);

   // Setup Trade - Menggunakan Magic Number tetap
   trade.SetExpertMagicNumber(998877);
   trade.SetDeviationInPoints(50);     // Toleransi slipage 50 points (aman utk Cent)
   trade.SetTypeFilling(ORDER_FILLING_FOK); // Fallback ke IOC jika FOK ditolak broker
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // 2. Bebaskan memory saat EA dilepas
   if(g_bands_handle != INVALID_HANDLE)
      IndicatorRelease(g_bands_handle);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // --- Cek Posisi Terbuka ---
   if(PositionsTotal() > 0) return; // Hanya 1 posisi sekaligus

   // --- Ambil Data Indikator yang sudah di-cache di Memory ---
   if(CopyBuffer(g_bands_handle, 2, 0, 3, g_buff_upper) < 3) return; // Index 2 = Upper Band
   if(CopyBuffer(g_bands_handle, 0, 0, 3, g_buff_lower) < 3) return; // Index 0 = Lower Band
   if(CopyBuffer(g_bands_handle, 1, 0, 3, g_buff_mid)   < 3) return; // Index 1 = Middle Band

   // --- Logika BUY ---
   double low_1   = iLow(_Symbol, PERIOD_CURRENT, 1);
   double close_1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double close_2 = iClose(_Symbol, PERIOD_CURRENT, 2);
   double curr_lower_1 = g_buff_lower[1];
   double curr_lower_2 = g_buff_lower[2];

   // Deteksi "Wick Touch" + "Valid Closure"
   if(low_1 <= curr_lower_1 && close_1 > curr_lower_1 && close_2 > curr_lower_2)
     {
      Print("🟢 SIGNAL BUY: Lower Band Rejection Confirmed!");
      ExecuteOrder(ORDER_TYPE_BUY);
     }

   // --- Logika SELL ---
   double high_1      = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double close_sell_1= iClose(_Symbol, PERIOD_CURRENT, 1);
   double close_sell_2= iClose(_Symbol, PERIOD_CURRENT, 2);
   double curr_upper_1= g_buff_upper[1];
   double curr_upper_2= g_buff_upper[2];

   if(high_1 >= curr_upper_1 && close_sell_1 < curr_upper_1 && close_sell_2 < curr_upper_2)
     {
      Print("🔴 SIGNAL SELL: Upper Band Rejection Confirmed!");
      ExecuteOrder(ORDER_TYPE_SELL);
     }
  }

//+------------------------------------------------------------------+
//| Fungsi Eksekusi Order (Fix API - PositionOpen)                   |
//+------------------------------------------------------------------+
void ExecuteOrder(ENUM_ORDER_TYPE type)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl  = 0, tp = 0;

   // Hitung Jarak TP Berbasis Lebar Pita (BB Width)
   double bb_width = g_buff_upper[0] - g_buff_lower[0];
   double profit_distance = NormalizeDouble(bb_width * InpBbWidthRatio, _Digits);

   // --- Hitung SL Dinamis berdasarkan Struktur ---
   if(InpUseStructuralSL)
     {
      if(type == ORDER_TYPE_BUY)
        {
         // Cari swing low terdekat dari 10 candle terakhir
         int idx_low = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, 10, 1);
         sl = NormalizeDouble(iLow(_Symbol, PERIOD_CURRENT, idx_low) - (iHigh(_Symbol, PERIOD_CURRENT, idx_low) * 0.0005), _Digits);
        
         // Validasi keamanan jarak SL
         double dist_sl = (sl - bid) / Point();
         if(dist_sl < 20) {
            Print("⚠️ SL Structural terlalu tipis (<20pt). Pakai fixed fallback.");
            sl = bid - (Point() * 50); 
         }
        }
      else
        {
         // Cari swing high terdekat dari 10 candle terakhir
         int idx_high = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, 10, 1);
         sl = NormalizeDouble(iHigh(_Symbol, PERIOD_CURRENT, idx_high) + (iHigh(_Symbol, PERIOD_CURRENT, idx_high) * 0.0005), _Digits);
         
         double dist_sl = (ask - sl) / Point();
         if(dist_sl < 20) {
            Print("⚠️ SL Structural terlalu tipis (<20pt). Pakai fixed fallback.");
            sl = ask + (Point() * 50);
         }
        }
     }
   else {
      // Default SL jika fitur struktural dinonaktifkan
      sl = (type == ORDER_TYPE_BUY) ? bid - (Point() * 50) : ask + (Point() * 50);
   }

   // --- Kalkulasi Koordinat TP Final ---
   if(type == ORDER_TYPE_BUY)
     {
      tp = NormalizeDouble(bid + profit_distance, _Digits);
      
      // EKSEKUSI MEMAKAI FIX API (PositionOpen)
      // Parameter: Symbol, Type, Volume, Price, SL, TP, Comment, Magic
      trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, InpLots, ask, sl, tp, "Art_BBPA Buy", 998877);
     }
   else
     {
      tp = NormalizeDouble(ask - profit_distance, _Digits);
      
      // EKSEKUSI MEMAKAI FIX API (PositionOpen)
      trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, InpLots, bid, sl, tp, "Art_BBPA Sell", 998877);
     }
     
   // Cek hasil eksekusi
   if(!trade.ResultOrder()) {
      Print("❌ Gagal Entry! Retcode: ", trade.ResultRetcode(), " Descript: ", trade.ResultRetcodeDescription());
   }
}
//+------------------------------------------------------------------+
