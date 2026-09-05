//+------------------------------------------------------------------+
//|                                              Genetic_Base.mq5 |
//|                                Copyright 2024, Trader Nakal™ Team |
//|                     REUSABLE STRATEGY TEMPLATE (GENETIC)          |
//+------------------------------------------------------------------+
#property copyright "Trader Nakal™ — Omon Agent"
#property version   "1.00"

// 1. Hubungkan dengan Otak Utama (Foundation)
#include "Omon_Foundation.mqh" 

//=====================================================================
// INPUT SETTINGS (Bisa diedit sesuai kebutuhan)
//=====================================================================
input group "=== Umum ==="
input int    InpMagicNumber = 123456;      // ID Unik EA
input double InpLots        = 0.01;       // Volume Order

input group "=== Indikator Contoh ==="
input int    InpBB_Period   = 20;         // Periode BB
input double InpBB_Dev      = 2.0;        // Deviasi BB

//=====================================================================
// VARIABEL GLOBAL (Mesin & Buffer)
//=====================================================================
CMarketKernel *Kernel;    // Objek Mesin
int           h_indicator; // Handle Indikator

// Buffer penampung data indikator agar hemat proses
double g_buff_upper[], g_buff_lower[];

//+------------------------------------------------------------------+
//| Initialization Function                                          |
//+------------------------------------------------------------------+
int OnInit()
  {
   // 1. Mulai Mesin/Foundation
   Kernel = new CMarketKernel();
   if(Kernel == NULL) { Print("Gagal buat Mesin!"); return(INIT_FAILED); }
   
   if(!Kernel.Init("Genetic Template", InpMagicNumber)) return(INIT_FAILED);
   
   // 2. Siapkan Indikator (Contoh: Bollinger Bands)
   h_indicator = iBands(_Symbol, _Period, InpBB_Period, 0, InpBB_Dev, PRICE_CLOSE);
   if(h_indicator == INVALID_HANDLE) return(INIT_FAILED);
   
   ArraySetAsSeries(g_buff_upper, true);
   ArraySetAsSeries(g_buff_lower, true);
   
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinitialization Function                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // Bersihkan memory mesin dan indikator
   if(Kernel != NULL) delete Kernel;
   IndicatorRelease(h_indicator);
  }

//+------------------------------------------------------------------+
//| Main Tick Loop                                                   |
//+------------------------------------------------------------------+
void OnTick()
  {
   // 1. Ambil data terbaru dari buffer indikator
   CopyBuffer(h_indicator, 0, 0, 3, g_buff_lower);
   CopyBuffer(h_indicator, 2, 0, 3, g_buff_upper);
   
   // 2. Jalankan Logika Trading
   Kernel->Run(); 
  }

//+------------------------------------------------------------------+
// *** BAGIAN TERPENTING (TEMPAT OM MENULIS LOGIKA) ***
// Override fungsi ini untuk setiap strategi baru!
//+------------------------------------------------------------------+
ENUM_SIGNAL CMarketKernel::GetTradingSignal()
  {
   // --- CONTOH LOGIKA (Bollinger Band Reversal) ---
   // Gunakan variable g_buff_lower[1] dan g_buff_upper[1]
   
   double low_1  = iLow(_Symbol, PERIOD_CURRENT, 1);
   double close_1= iClose(_Symbol, PERIOD_CURRENT, 1);
   double close_2= iClose(_Symbol, PERIOD_CURRENT, 2);
   
   // Logika BUY: Sentuh Lower Band lalu Close masuk kembali
   if(low_1 <= g_buff_lower[1] && close_1 > g_buff_lower[1] && close_2 > g_buff_lower[2])
      return SIG_BUY;
   
   // Logika SELL: Sentuh Upper Band lalu Close masuk kembali
   if(iHigh(_Symbol, PERIOD_CURRENT, 1) >= g_buff_upper[1] && close_1 < g_buff_upper[1] && close_2 < g_buff_upper[2])
      return SIG_SELL;
      
   // Jika tidak ada sinyal apa-apa
   return SIG_NONE; 
  }

//+------------------------------------------------------------------+
