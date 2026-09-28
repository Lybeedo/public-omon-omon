//+------------------------------------------------------------------+
//|                                  H4_SelfLearning_Probability.mq5  |
//|                    Empirical Markov Chain - H4 Self Learning EA  |
//|                            Native MQL5, No DLL, No External Lib  |
//+------------------------------------------------------------------+
#property strict
#property copyright "Trader Nakal ©"
#property version   "1.00"
#property description "H4 Self-Learning Probability EA menggunakan Empirical Markov Chain"
#property description "Semua kalkulasi dilakukan native di memori tanpa pustaka eksternal"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Definisi Parameter Input EA                                      |
//+------------------------------------------------------------------+
input group "=== KONFIGURASI TRAINING ==="
input int    InpLookbackBars   = 3000;      // Jumlah candle historis untuk training
input int    InpMinSamples     = 10;        // Minimum sampel historis untuk validitas statistik
input double InpMinProbThreshold = 65.0;   // Probabilitas minimum untuk entry (%)

input group "=== KONFIGURASI RISK MANAGEMENT ==="
input double InpRiskPercent    = 1.0;       // Risiko per trade (% dari Balance)
input double InpATRPeriod      = 14;        // Periode ATR untuk SL/TP
input double InpSLMultiplier   = 1.5;       // Multiplier SL (ATR)
input double InpTPMultiplier   = 3.0;       // Multiplier TP (ATR, Risk:Reward 1:2)

input group "=== KONFIGURASI TRADE ==="
input double InpLotSize        = 0.01;      // Lot manual (0 = auto calculate)
input int    InpMaxOrders      = 1;         // Max posisi terbuka sekaligus
input bool   InpPrintTraining  = true;      // Cetak log training diExperts tab

//+------------------------------------------------------------------+
//| Struktur Data untuk Database Pola                                 |
//+------------------------------------------------------------------+
struct PatternRecord
  {
   string          pattern_key;      // Kunci pola, contoh: "0-1-3"
   int             total_occurrences; // Total kemunculan pola
   int             next_bullish;     // Jumlah next candle bullish
   int             next_bearish;     // Jumlah next candle bearish
  };

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
PatternRecord g_pattern_db[];       // Database pola Markov Chain
int           g_pattern_count = 0;  // Jumlah pola unik yang ditemukan
bool          g_training_done = false;
datetime      g_last_bar_time = 0;  // Waktu bar terakhir untuk deteksi New Bar

//+------------------------------------------------------------------+
//| Fungsi: Mendapatkan State dari sebuah candle berdasarkan CPL      |
//| Input:  Open, High, Low, Close dari candle                        |
//| Output: State 0-3                                                 |
//+------------------------------------------------------------------+
int GetCandleState(double open, double high, double low, double close)
  {
   // Avoid division by zero
   if(high == low) return 2; // Flat candle, default to Normal Bullish
   
   // CPL (Closing Position Location): (Close - Low) / (High - Low) * 100
   double cpl = ((close - low) / (high - low)) * 100.0;
   
   // Kategorikan ke 4 State
   if(cpl < 25.0)
     return 0;  // Strong Bearish
   else if(cpl < 50.0)
     return 1;  // Normal Bearish
   else if(cpl < 75.0)
     return 2;  // Normal Bullish
   else
     return 3;  // Strong Bullish
  }

//+------------------------------------------------------------------+
//| Fungsi: Mengkalkulasi ATR                                         |
//| Input:  Period ATR                                                |
//| Output: Nilai ATR saat ini                                        |
//+------------------------------------------------------------------+
double CalculateATR(int period)
  {
   double atr[];
   if(CopyBuffer(iATR(_Symbol, PERIOD_CURRENT, period), 0, 0, 3, atr) < 3)
     return 0;
   return atr[1]; // ATR dari bar terakhir yang sudah selesai
  }

//+------------------------------------------------------------------+
//| Fungsi: Mengecek apakah bar baru telah terbentuk                  |
//| Output: true jika bar baru, false jika tidak                      |
//+------------------------------------------------------------------+
bool IsNewBar(void)
  {
   datetime current_bar_time = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(current_bar_time != g_last_bar_time)
     {
      if(g_last_bar_time != 0) // Bar baru benar-benar baru
        return true;
     }
   g_last_bar_time = current_bar_time;
   return false;
  }

//+------------------------------------------------------------------+
//| Fungsi: Training Model - Memindai riwayat harga dan membangun    |
//|         database pola Markov Chain                                |
//+------------------------------------------------------------------+
void TrainModel(void)
  {
   if(InpLookbackBars <= 0)
     {
      Print("[TRAINING] InpLookbackBars harus > 0!");
      return;
     }
   
   // Ambil data OHLC historis
   double open[], high[], low[], close[];
   int copied = CopyRates(_Symbol, PERIOD_CURRENT, 0, InpLookbackBars + 3, NULL);
   if(copied < InpLookbackBars + 3)
     {
      Print("[TRAINING] Gagal mengambil data harga: Error=", GetLastError());
      return;
     }
   
   // Salin data ke array lokal
   if(CopyOpen(_Symbol, PERIOD_CURRENT, 0, InpLookbackBars + 3, open) < InpLookbackBars + 3) return;
   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, InpLookbackBars + 3, high) < InpLookbackBars + 3) return;
   if(CopyLow(_Symbol, PERIOD_CURRENT, 0, InpLookbackBars + 3, low) < InpLookbackBars + 3) return;
   if(CopyClose(_Symbol, PERIOD_CURRENT, 0, InpLookbackBars + 3, close) < InpLookbackBars + 3) return;
   
   // Reset database pola
   ArrayResize(g_pattern_db, 0);
   g_pattern_count = 0;
   
   // Loop melalui riwayat untuk mencari pola 3 candle
   // t-3, t-2, t-1 → t0 (candle berikutnya)
   for(int i = 0; i < InpLookbackBars; i++)
     {
      // Dapatkan state dari 3 candle sebelumnya
      int state_t3 = GetCandleState(open[i], high[i], low[i], close[i]);
      int state_t2 = GetCandleState(open[i+1], high[i+1], low[i+1], close[i+1]);
      int state_t1 = GetCandleState(open[i+2], high[i+2], low[i+2], close[i+2]);
      
      // Buat kunci pola
      string pattern_key = StringFormat("%d-%d-%d", state_t3, state_t2, state_t1);
      
      // Lihat hasil candle berikutnya (t0)
      bool next_is_bullish = (close[i+3] > open[i+3]);
      
      // Cari apakah pola sudah ada di database
      int pattern_index = -1;
      for(int j = 0; j < g_pattern_count; j++)
        {
         if(g_pattern_db[j].pattern_key == pattern_key)
           {
            pattern_index = j;
            break;
           }
        }
      
      // Update atau tambahkan record
      if(pattern_index >= 0)
        {
         g_pattern_db[pattern_index].total_occurrences++;
         if(next_is_bullish)
           g_pattern_db[pattern_index].next_bullish++;
         else
           g_pattern_db[pattern_index].next_bearish++;
        }
      else
        {
         // Tambah pola baru
         int new_size = g_pattern_count + 1;
         ArrayResize(g_pattern_db, new_size);
         g_pattern_db[g_pattern_count].pattern_key = pattern_key;
         g_pattern_db[g_pattern_count].total_occurrences = 1;
         g_pattern_db[g_pattern_count].next_bullish = next_is_bullish ? 1 : 0;
         g_pattern_db[g_pattern_count].next_bearish = next_is_bullish ? 0 : 1;
         g_pattern_count++;
        }
     }
   
   // Sortir database berdasarkan total_occurrences (descending) untuk memudahkan debugging
   for(int i = 0; i < g_pattern_count - 1; i++)
     {
      for(int j = i + 1; j < g_pattern_count; j++)
        {
         if(g_pattern_db[j].total_occurrences > g_pattern_db[i].total_occurrences)
           {
            PatternRecord temp = g_pattern_db[i];
            g_pattern_db[i] = g_pattern_db[j];
            g_pattern_db[j] = temp;
           }
        }
     }
   
   // Cetak hasil training
   if(InpPrintTraining)
     {
      Print("[TRAINING] === HASIL TRAINING MARKOV CHAIN ===");
      Print("[TRAINING] Lookback: ", InpLookbackBars, " candle H4");
      Print("[TRAINING] Total pola unik ditemukan: ", g_pattern_count);
      Print("[TRAINING] Minimum sampel: ", InpMinSamples);
      Print("[TRAINING] Probabilitas minimum: ", InpMinProbThreshold, "%");
      Print("[TRAINING] ----------------------------------------");
      
      // Cetak top 20 pola paling sering muncul
      int print_count = MathMin(20, g_pattern_count);
      for(int i = 0; i < print_count; i++)
        {
         double prob_bull = (g_pattern_db[i].total_occurrences > 0) ?
                            (double)g_pattern_db[i].next_bullish / g_pattern_db[i].total_occurrences * 100.0 : 0.0;
         double prob_bear = (g_pattern_db[i].total_occurrences > 0) ?
                            (double)g_pattern_db[i].next_bearish / g_pattern_db[i].total_occurrences * 100.0 : 0.0;
         
         Print("[TRAINING] Pola '", g_pattern_db[i].pattern_key,
               "' | Sampel: ", g_pattern_db[i].total_occurrences,
               " | Bull: ", DoubleToString(prob_bull, 2), "%",
               " | Bear: ", DoubleToString(prob_bear, 2), "%");
        }
      
      // Cetak pola yang memenuhi syarat entry
      Print("[TRAINING] ----------------------------------------");
      Print("[TRAINING] Pola yang memenuhi syarat entry:");
      int qualifying_count = 0;
      for(int i = 0; i < g_pattern_count; i++)
        {
         if(g_pattern_db[i].total_occurrences >= InpMinSamples)
           {
            double prob_bull = (double)g_pattern_db[i].next_bullish / g_pattern_db[i].total_occurrences * 100.0;
            double prob_bear = (double)g_pattern_db[i].next_bearish / g_pattern_db[i].total_occurrences * 100.0;
            
            if(prob_bull >= InpMinProbThreshold || prob_bear >= InpMinProbThreshold)
              {
               qualifying_count++;
               char signal = (prob_bull >= prob_bear) ? 'B' : 'S';
               double prob = (prob_bull >= prob_bear) ? prob_bull : prob_bear;
               
               Print("[TRAINING]   ", signal, " | Pola '", g_pattern_db[i].pattern_key,
                     "' | Sampel: ", g_pattern_db[i].total_occurrences,
                     " | Prob: ", DoubleToString(prob, 2), "%");
              }
           }
        }
      Print("[TRAINING] Total pola qualifying: ", qualifying_count);
      Print("[TRAINING] ========================================");
     }
   
   g_training_done = true;
   Print("[TRAINING] Training selesai. Database Markov Chain siap digunakan.");
  }

//+------------------------------------------------------------------+
//| Fungsi: Mendapatkan probabilitas untuk pola saat ini              |
//| Output: prob_bullish / prob_bearish melalui reference parameter   |
//| Return: true jika pola ditemukan di database                      |
//+------------------------------------------------------------------+
bool GetPatternProbability(int &prob_bullish, int &prob_bearish)
  {
   if(!g_training_done || g_pattern_count == 0)
     return false;
   
   // Ambil state dari 3 candle terakhir
   double open[], high[], low[], close[];
   if(CopyOpen(_Symbol, PERIOD_CURRENT, 0, 4, open) < 4) return false;
   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, 4, high) < 4) return false;
   if(CopyLow(_Symbol, PERIOD_CURRENT, 0, 4, low) < 4) return false;
   if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 4, close) < 4) return false;
   
   // Candle yang sudah selesai: index 3, 2, 1 (bukan 0 karena 0 adalah bar berjalan)
   int state_1 = GetCandleState(open[3], high[3], low[3], close[3]);
   int state_2 = GetCandleState(open[2], high[2], low[2], close[2]);
   int state_3 = GetCandleState(open[1], high[1], low[1], close[1]);
   
   string pattern_key = StringFormat("%d-%d-%d", state_1, state_2, state_3);
   
   // Cari di database
   for(int i = 0; i < g_pattern_count; i++)
     {
      if(g_pattern_db[i].pattern_key == pattern_key)
        {
         if(g_pattern_db[i].total_occurrences > 0)
           {
            prob_bullish = (int)((double)g_pattern_db[i].next_bullish / g_pattern_db[i].total_occurrences * 100.0);
            prob_bearish = (int)((double)g_pattern_db[i].next_bearish / g_pattern_db[i].total_occurrences * 100.0);
            return true;
           }
        }
     }
   
   return false; // Pola tidak ditemukan di database
  }

//+------------------------------------------------------------------+
//| Fungsi: Menghitung lot size otomatis berdasarkan risiko 1%       |
//| Input:  entry_price, is_buy (true=buy, false=sell)                |
//| Output: Lot size yang dihitung                                    |
//+------------------------------------------------------------------+
double CalculateLotSize(double entry_price, bool is_buy)
  {
   // Jika lot manual diatur, gunakan nilai tersebut
   if(InpLotSize > 0)
     return InpLotSize;
   
   // Hitung ATR untuk menentukan jarak SL
   double atr = CalculateATR((int)InpATRPeriod);
   if(atr <= 0)
     return InpLotSize > 0 ? InpLotSize : 0.01;
   
   double sl_distance = atr * InpSLMultiplier;
   if(sl_distance <= 0)
     return InpLotSize > 0 ? InpLotSize : 0.01;
   
   // Hitung nilai risiko dalam currency
   double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_amount = account_balance * InpRiskPercent / 100.0;
   
   // Dapatkan nilai per lot point
   double contract_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(tick_size <= 0 || tick_value <= 0)
     return InpLotSize > 0 ? InpLotSize : 0.01;
   
   // Hitung lot: risk_amount / (sl_distance / tick_size * tick_value / contract_size)
   // Simplifikasi: lot = risk_amount / (sl_distance * tick_value / tick_size / contract_size)
   double points_at_risk = sl_distance / tick_size;
   double profit_per_point_per_lot = tick_value / tick_size;
   
   double lot = risk_amount / (points_at_risk * profit_per_point_per_lot / contract_size);
   
   // Normalize sesuai step size broker
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lot_step <= 0) lot_step = 0.01;
   lot = MathFloor(lot / lot_step) * lot_step;
   
   // Batasi lot sesuai minimum/maximum
   double lot_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lot_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(lot_min > 0) lot = MathMax(lot, lot_min);
   if(lot_max > 0) lot = MathMin(lot, lot_max);
   
   return lot;
  }

//+------------------------------------------------------------------+
//| Fungsi: Mengecek jumlah order/posisi yang sedang terbuka          |
//| Output: Jumlah posisi terbuka untuk symbol saat ini               |
//+------------------------------------------------------------------+
int GetOpenPositionsCount(void)
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
        {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol)
           count++;
        }
     }
   return count;
  }

//+------------------------------------------------------------------+
//| Fungsi: Eksekusi Trade BUY                                        |
//+------------------------------------------------------------------+
void ExecuteBuy(double entry_price, double sl, double tp, double lot)
  {
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lot;
   request.type = ORDER_TYPE_BUY;
   request.price = entry_price;
   request.sl = sl;
   request.tp = tp;
   request.deviation = 10;
   request.magic = 123456;
   request.comment = "H4 SelfLearning Prob";
   request.type_time = ORDER_TIME_GTC;
   request.type_filling = ORDER_FILLING_FOK;
   
   if(!OrderSend(request, result))
     {
      // Coba dengan IOC jika FOK gagal
      request.type_filling = ORDER_FILLING_IOC;
      if(!OrderSend(request, result))
        Print("[SELL] Order gagal: ", result.retcode, " - ", result.comment);
      else
        Print("[BUY] Order sukses! Ticket: ", result.order, " Lot: ", lot);
     }
   else
     Print("[BUY] Order sukses! Ticket: ", result.order, " Lot: ", lot);
  }

//+------------------------------------------------------------------+
//| Fungsi: Eksekusi Trade SELL                                       |
//+------------------------------------------------------------------+
void ExecuteSell(double entry_price, double sl, double tp, double lot)
  {
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lot;
   request.type = ORDER_TYPE_SELL;
   request.price = entry_price;
   request.sl = sl;
   request.tp = tp;
   request.deviation = 10;
   request.magic = 123456;
   request.comment = "H4 SelfLearning Prob";
   request.type_time = ORDER_TIME_GTC;
   request.type_filling = ORDER_FILLING_FOK;
   
   if(!OrderSend(request, result))
     {
      // Coba dengan IOC jika FOK gagal
      request.type_filling = ORDER_FILLING_IOC;
      if(!OrderSend(request, result))
        Print("[SELL] Order gagal: ", result.retcode, " - ", result.comment);
      else
        Print("[SELL] Order sukses! Ticket: ", result.order, " Lot: ", lot);
     }
   else
     Print("[SELL] Order sukses! Ticket: ", result.order, " Lot: ", lot);
  }

//+------------------------------------------------------------------+
//| Fungsi: Eksekusi Close All Positions                              |
//+------------------------------------------------------------------+
void CloseAllPositions(void)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
        {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol)
           {
            MqlTradeRequest request;
            MqlTradeResult result;
            ZeroMemory(request);
            ZeroMemory(result);
            
            request.action = TRADE_ACTION_CLOSE_BY;
            request.position = ticket;
            request.symbol = _Symbol;
            
            // Gunakan method sederhana: close market order
            bool is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
            double close_price = is_long ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            
            request.action = TRADE_ACTION_DEAL;
            request.position = ticket;
            request.symbol = _Symbol;
            request.volume = PositionGetDouble(POSITION_VOLUME);
            request.type = is_long ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            request.price = close_price;
            request.deviation = 10;
            
            OrderSend(request, result);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| OnInit - Inisialisasi EA                                          |
//+------------------------------------------------------------------+
int OnInit(void)
  {
   Print("[INIT] H4 SelfLearning_Probability EA dimulai");
   Print("[INIT] Symbol: ", _Symbol, " | Timeframe: H4");
   Print("[INIT] Lookback: ", InpLookbackBars, " bars | Risk: ", InpRiskPercent, "%");
   
   // Jalankan training awal
   TrainModel();
   
   // Setup bar terakhir
   g_last_bar_time = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit - Cleanup saat EA dilepas                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Print("[DEINIT] EA dihentikan. Reason: ", reason);
  }

//+------------------------------------------------------------------+
//| OnTick - Eksekusi setiap tick                                     |
//+------------------------------------------------------------------+
void OnTick(void)
  {
   // Cek apakah ini bar baru
   if(!IsNewBar())
     return;
   
   Print("[TICK] Bar baru terdeteksi pada ", TimeToString(TimeCurrent()));
   
   // Pastikan training sudah dilakukan
   if(!g_training_done)
     TrainModel();
   
   // Cek jumlah posisi terbuka
   int open_positions = GetOpenPositionsCount();
   if(open_positions >= InpMaxOrders)
     {
      Print("[TICK] Sudah ada ", open_positions, " posisi terbuka. Melewati entry.");
      return;
     }
   
   // Dapatkan probabilitas pola saat ini
   int prob_bullish, prob_bearish;
   if(!GetPatternProbability(prob_bullish, prob_bearish))
     {
      Print("[TICK] Pola saat ini tidak ditemukan di database training.");
      return;
     }
   
   // Dapatkan 3 state terakhir untuk logging
   double open[], high[], low[], close[];
   CopyOpen(_Symbol, PERIOD_CURRENT, 0, 4, open);
   CopyHigh(_Symbol, PERIOD_CURRENT, 0, 4, high);
   CopyLow(_Symbol, PERIOD_CURRENT, 0, 4, low);
   CopyClose(_Symbol, PERIOD_CURRENT, 0, 4, close);
   
   int s1 = GetCandleState(open[3], high[3], low[3], close[3]);
   int s2 = GetCandleState(open[2], high[2], low[2], close[2]);
   int s3 = GetCandleState(open[1], high[1], low[1], close[1]);
   string current_pattern = StringFormat("%d-%d-%d", s1, s2, s3);
   
   Print("[TICK] Pola terdeteksi: '", current_pattern, "' | Bull: ", prob_bullish, "% | Bear: ", prob_bearish, "%");
   
   // Hitung SL/TP berbasis ATR
   double atr = CalculateATR((int)InpATRPeriod);
   if(atr <= 0)
     {
      Print("[TICK] ATR tidak valid. Melewati entry.");
      return;
     }
   
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   double sl_buy = ask - (atr * InpSLMultiplier);
   double tp_buy = ask + (atr * InpTPMultiplier);
   double sl_sell = bid + (atr * InpSLMultiplier);
   double tp_sell = bid - (atr * InpTPMultiplier);
   
   // Normalisasi SL/TP ke tick size
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size > 0)
     {
      sl_buy = MathFloor(sl_buy / tick_size) * tick_size;
      tp_buy = MathCeil(tp_buy / tick_size) * tick_size;
      sl_sell = MathCeil(sl_sell / tick_size) * tick_size;
      tp_sell = MathFloor(tp_sell / tick_size) * tick_size;
     }
   
   // Logika Entry berdasarkan probabilitas
   bool should_buy = (prob_bullish >= InpMinProbThreshold);
   bool should_sell = (prob_bearish >= InpMinProbThreshold);
   
   if(should_buy)
     {
      double lot = CalculateLotSize(ask, true);
      if(lot > 0)
        ExecuteBuy(ask, sl_buy, tp_buy, lot);
      else
        Print("[TICK] Lot size invalid untuk BUY");
     }
   else if(should_sell)
     {
      double lot = CalculateLotSize(bid, false);
      if(lot > 0)
        ExecuteSell(bid, sl_sell, tp_sell, lot);
      else
        Print("[TICK] Lot size invalid untuk SELL");
     }
   else
     {
      Print("[TICK] Probabilitas tidak memenuhi threshold. Tidak ada entry.");
     }
  }

//+------------------------------------------------------------------+
//| OnTimer - Bisa digunakan untuk re-training berkala               |
//+------------------------------------------------------------------+
void OnTimer(void)
  {
   // Opsional: re-training setiap jam untuk menyesuaikan database
   // Uncomment baris berikut jika ingin re-training berkala
   // if(InpPrintTraining) TrainModel();
  }
//+------------------------------------------------------------------+
