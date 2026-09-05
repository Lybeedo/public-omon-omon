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

   // Setup Trade
   trade.SetExpertMagicNumber(998877);
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
   // Kita hanya copy data buffer, tidak memanggil kalkulasi ulang ke CPU berat
   if(CopyBuffer(g_bands_handle, 2, 0, 3, g_buff_upper) < 3) return; // Index 2 = Upper Band
   if(CopyBuffer(g_bands_handle, 0, 0, 3, g_buff_lower) < 3) return; // Index 0 = Lower Band
   if(CopyBuffer(g_bands_handle, 1, 0, 3, g_buff_mid)   < 3) return; // Index 1 = Middle Band

   // --- Logika BUY ---
   // Syarat: 
   // 1. Candle sebelumnya (Index 1) Low menyentuh/menembus Lower Band saat Low.
   // 2. Close candle tersebut kembali di atas Lower Band (Pantulan/Pinbar).
   // 3. Candle sebelum itu (Index 2) valid (Close > Lower Band - Mencegah entry saat break strong trend).
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
   // Syarat:
   // 1. Candle sebelumnya (Index 1) High menyentuh/menembus Upper Band saat High.
   // 2. Close candle tersebut kembali di bawah Upper Band (Pantulan).
   // 3. Candle sebelum itu (Index 2) valid (Close < Upper Band).
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
//| Fungsi Eksekusi Order                                            |
//+------------------------------------------------------------------+
void ExecuteOrder(ENUM_ORDER_TYPE type)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl  = 0, tp = 0;

   // Hitung SL dinamis berdasarkan struktur jika diaktifkan
   if(InpUseStructuralSL)
     {
      if(type == ORDER_TYPE_BUY)
        {
         // Cari swing low terdekat dari 10 candle terakhir
         int idx_low = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, 10, 1);
         sl = iLow(_Symbol, PERIOD_CURRENT, idx_low) - (iHigh(_Symbol, PERIOD_CURRENT, idx_low) * 0.0005); // Buffer tipis
        }
      else
        {
         // Cari swing high terdekat dari 10 candle terakhir
         int idx_high = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, 10, 1);
         sl = iHigh(_Symbol, PERIOD_CURRENT, idx_high) + (iHigh(_Symbol, PERIOD_CURRENT, idx_high) * 0.0005); // Buffer tipis
        }
     }

   if(type == ORDER_TYPE_BUY)
     {
      trade.Buy(InpLots, _Symbol, ask, sl, tp, "Art_BBPA Reversal Buy");
     }
   else
     {
      trade.Sell(InpLots, _Symbol, bid, sl, tp, "Art_BBPA Reversal Sell");
     }
}
//+------------------------------------------------------------------+
