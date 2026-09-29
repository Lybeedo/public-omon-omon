//+------------------------------------------------------------------+
//|                                    KNN_Wave_MTF_Dashboard_v2.mq5 |
//|  KNN 8-Dimensi (Micro + Macro Wave + Regime) - Multi TF Dashboard|
//|                                                                  |
//|  Peningkatan v2:                                                 |
//|   1. Kolom Match  : seberapa mirip pola sekarang vs histori      |
//|   2. Voting KNN berbobot jarak (1 / (jarak + eps))               |
//|   3. Hit-rate tracker (live forward) + walk-forward backtest     |
//|   4. Target: arah setelah N bar, gerak minimum x ATR             |
//|   5. Memori & statistik disimpan ke file (MQL5\Files)            |
//|                                                                  |
//|  Peningkatan v2.1:                                               |
//|   6. Notifikasi (Alert/Push/Email/Sound) saat Trend F4 selaras   |
//|      dengan Signal (UP+BUY atau DOWN+SELL) pada tiap timeframe,  |
//|      difilter kualitas Match% & Hit%(n) ("Sinyal Kuat")         |
//|                                                                  |
//|  Peningkatan v2.2 (Optimasi KNN):                                |
//|   7. Bobot fitur (F1..F5) di jarak KNN, dihitung otomatis dari   |
//|      daya pisah pola Bull vs Bear di memori (bukan lagi rata)    |
//|   8. Skor gabungan (Confluence) lintas 5 timeframe berbobot,     |
//|      ditampilkan sebagai baris "ALL" di dashboard + notifikasi   |
//|      terpisah saat Confluence kuat & selaras                    |
//|      >> DIHAPUS di v2.32, lihat catatan di bawah <<              |
//|                                                                  |
//|  Peningkatan v2.3 (Rekomendasi Entry Self-Learning):             |
//|   9. Tiap pola kini merekam besar pergerakan aktual & max        |
//|      adverse excursion (MAE) historisnya, bukan cuma arah        |
//|  10. TP diestimasi dari rata-rata pergerakan aktual K tetangga   |
//|      searah; SL dari rata-rata MAE-nya (+ buffer keamanan)       |
//|  11. Dashboard menampilkan blok "REKOMENDASI ENTRY" per          |
//|      timeframe: Entry, SL, TP, dan rasio Reward:Risk             |
//|      (CATATAN: format file memori berubah - Hit%(n)/Acc% akan   |
//|      reset & memori dibangun ulang otomatis setelah update ini)  |
//|                                                                  |
//|  Peningkatan v2.31:                                              |
//|  12. Blok "REKOMENDASI ENTRY" hanya tampil saat Trend F4 selaras |
//|      dengan Signal (sinyal yang tidak selaras trend tidak lagi   |
//|      dikasih rekomendasi Entry/SL/TP)                            |
//|  13. Notifikasi "[Sinyal Kuat]" kini mengikuti/menempel pada     |
//|      ketersediaan rekomendasi entry tsb (bukan pengecekan        |
//|      keselarasan terpisah) - Match%/Hit%(n) tetap jadi filter    |
//|      kualitas tambahan sebelum notifikasi terkirim               |
//|                                                                  |
//|  Peningkatan v2.32 (Simplifikasi - fokus self-learning per TF):  |
//|  14. Skor gabungan/Confluence (baris "ALL", input InpWeight*,    |
//|      InpAlertConfluence, InpConfluenceMinAlign) DIHAPUS. Fokus   |
//|      dashboard kembali ke 3 hal per timeframe: kualitas Trend    |
//|      F4, kualitas Signal (Match%/Hit%(n)/Acc%/walk-forward),     |
//|      dan Rekomendasi Entry self-learning (bagian 7 README)       |
//|                                                                  |
//|  Peningkatan v2.4 (Fitur Regime & Wave Matematis - F6/F7/F8):    |
//|  15. F6 Efficiency Ratio (Kaufman): rasio perpindahan bersih vs  |
//|      total jarak tempuh - regime trending vs choppy/ranging      |
//|  16. F7 Hurst Exponent (estimasi R/S 2-skala): regime persisten  |
//|      (H>0.5, trending) vs mean-reverting (H<0.5)                 |
//|  17. F8 Wave Leg Ratio: rasio jarak leg fractal terbaru vs       |
//|      leg sebelumnya - hubungan Fibonacci antar-wave dari data,   |
//|      bukan pattern kategorikal/hardcode                          |
//|      (Semua kontinu, dihitung murni dari OHLC, otomatis ikut     |
//|      bobot fitur adaptif & normalisasi yang sudah ada)           |
//|      (CATATAN: dimensi fitur bertambah 5->8, format file memori |
//|      berubah lagi - Hit%(n)/Acc% akan reset & memori dibangun    |
//|      ulang otomatis setelah update ini)                          |
//|                                                                  |
//|  Peningkatan v2.5 (Notifikasi Self-Tuning, 2 Tier Terbukti):     |
//|  18. Trend F4 TIDAK lagi jadi syarat wajib rekomendasi Entry -   |
//|      F4 sudah ikut di 8 dimensi KNN dgn bobot yang dipelajari    |
//|      sendiri; mensyaratkan arahnya cocok lagi bisa membuang      |
//|      sinyal bagus yang F4-nya kebetulan berlawanan               |
//|  19. Tiap sinyal dicatat sbg tier "Selaras" atau "Non-Selaras"   |
//|      (F4 vs Signal), Hit%(n) live keduanya dilacak TERPISAH -    |
//|      dashboard membuktikan sendiri tier mana yang lebih baik     |
//|      untuk simbol/timeframe Anda, bukan diasumsikan di awal      |
//|  20. InpMinMatch, InpNotifMinMatch, InpNotifMinHitN,             |
//|      InpNotifMinHitPct DIHAPUS. Notifikasi kini self-tuning:     |
//|      terkirim saat tier sinyal saat ini SUDAH TERBUKTI (Hit%     |
//|      live > 50%, baseline netral) lebih baik dari tebakan acak;  |
//|      Input notifikasi yang tersisa hanya mengatur KANAL kirim    |
//|      (Popup/Push/Email/Sound), bukan KAPAN dikirim               |
//|      (CATATAN: format file memori berubah lagi - Hit%(n)/Acc%   |
//|      akan reset & memori dibangun ulang otomatis)                |
//+------------------------------------------------------------------+
#property copyright   "KNN Wave MTF Dashboard"
#property version     "2.51"
#property description "Dashboard probabilitas Bullish/Bearish berbasis KNN (M5, M15, H1, H4, D1)"
#property strict
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//--- konstanta
#define FEATURE_COUNT   8
#define FRACTAL_SCAN    80
#define TF_COUNT        5
#define PREFIX          "KNN2_"
#define WEIGHT_EPS      0.05
#define WF_REFRESH_BARS 50
#define STATE_MAGIC     0x4B4E4E57
#define STATE_VERSION   4
#define MIN_MEMORY_FOR_SIGNAL 200 // memori minimum sebelum sinyal diizinkan
#define MIN_TIER_SAMPLES 10 // sampel minimum sebelum tier (Selaras/Non-Selaras) dipercaya statistiknya
#define DIST_DRIFT_WINDOW 200 // window rolling untuk deteksi drift fitur

//--- enum posisi dashboard
enum ENUM_DASH_CORNER
{
    CORNER_RT = 0, // Kanan Atas(Right - Upper)
    CORNER_LT = 1, // Kiri Atas(Left - Upper)
    CORNER_RB = 2, // Kanan Bawah(Right - Lower)
    CORNER_LB = 3 // Kiri Bawah(Left - Lower)
};

//--- input
input ENUM_DASH_CORNER InpDashCorner = CORNER_RT; // Posisi Dashboard di Chart
input int InpLookback = 1500; // Bar historis untuk warm - up
input int InpMaxMemory = 3000; // Kapasitas maksimum memori pola( >= lookback)
input int InpK = 21; // Jumlah tetangga(K)
input int InpHorizon = 3; // Target: arah setelah N bar
input double InpMinMoveATR = 0.5; // Gerak minimum(x ATR) agar dihitung Bull / Bear
input double InpThreshold = 70.0; // Ambang sinyal( % )
input int InpWFSamples = 250; // Jumlah sampel walk - forward backtest
input bool InpPersist = true; // Simpan memori & statistik ke file

//--- filter kualitas sinyal
input double InpMinMatch = 20.0;         // Minimum Match% agar sinyal diizinkan (0=off)
input double InpMaxSpreadPips = 50.0;    // Maksimum spread dalam pip untuk rekomendasi/alerts (0=off)
input double InpMaxAvgDist = 0.0;        // Batas maksimum rata-rata jarak KNN, 0=off

//--- parameter fitur regime (F6/F7)
input int InpERPeriod = 20;              // Periode Efficiency Ratio (F6)
input int InpHurstWindow = 64;           // Window Hurst Exponent (F7)
input bool InpSmoothRegime = true;       // Smooth F6/F7 dengan median 3-bar

//--- input notifikasi - sistem menentukan SENDIRI kapan layak notifikasi (lihat bagian 6 README),
//--- Anda hanya mengatur LEWAT MANA notifikasi dikirim
input bool InpAlertPopup     = true;         // Notifikasi Pop-up (Alert) di terminal
input bool InpAlertPush      = false;        // Notifikasi Push ke MetaTrader Mobile
input bool InpAlertEmail     = false;        // Notifikasi Email
input bool InpAlertSound     = true;         // Notifikasi Suara
input string InpAlertSoundFile = "alert2.wav"; // Nama file suara (folder Sounds terminal)

//--- rekomendasi Entry/SL/TP berbasis self-learning (dari statistik K tetangga KNN)
input double InpSLBufferMult = 1.2; // Pengali buffer keamanan SL di atas MAE historis rata-rata (mis. 1.2 = +20%)
input double InpSLMinATR     = 0.3; // Jarak SL minimum (dalam ATR), agar SL tidak terlalu sempit

//--- struktur memori
struct SPattern
{
    double features[FEATURE_COUNT];
    int target; // 1 = Bull, 0 = Bear
    double move_atr; // besar pergerakan aktual searah target saat horizon selesai (dalam ATR)
    double mae_atr;  // max adverse excursion sebelum bergerak searah target (dalam ATR)
};

struct SDistance
{
    double dist;
    int target;
    double move_atr;
    double mae_atr;
};

struct SPred // prediksi yang menunggu hasilnya
{
    datetime t; // waktu bar fitur
    int pred; // 1 = Bull, 0 = Bear, - 1 = netral
    int sig; // 1 = BUY, - 1 = SELL, 0 = WAIT
    bool aligned; // apakah Trend F4 selaras dengan sig saat prediksi dicatat (tier Selaras/Non-Selaras)
};

//+------------------------------------------------------------------+
//| Helper: nama timeframe                                           |
//+------------------------------------------------------------------+
string TFToString(const ENUM_TIMEFRAMES tf)
{
    switch(tf)
    {
        case PERIOD_M5: return "M5";
        case PERIOD_M15: return "M15";
        case PERIOD_H1: return "H1";
        case PERIOD_H4: return "H4";
        case PERIOD_D1: return "D1";
        default: return EnumToString(tf);
    }
}

//+------------------------------------------------------------------+
//| Helper: kirim notifikasi saat Trend selaras dengan Signal         |
//| (dipanggil sekali per transisi, bukan setiap tick / timer)        |
//+------------------------------------------------------------------+
void FireNotification(const string src, const string msg)
{
    string full = src + " -> " + msg + " [" + TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES) + "]";
    if(InpAlertPopup) Alert(full);
    if(InpAlertPush)  SendNotification(full);
    if(InpAlertEmail) SendMail("KNN Wave MTF Dashboard - Sinyal", full);
    if(InpAlertSound) PlaySound(InpAlertSoundFile);
    Print("[KNN ALERT] ", full);
}

//+------------------------------------------------------------------+
//| Helper: konversi pip ke harga & median 3 nilai                   |
//+------------------------------------------------------------------+
double PipsToPrice(const string symbol, const double pips)
{
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double mult = (digits == 3 || digits == 5) ? 10.0 : 1.0;
    return pips * mult * point;
}

double Median3(const double a, const double b, const double c)
{
    if(a > b) { if(b > c) return b; if(a > c) return c; return a; }
    else      { if(a > c) return a; if(b > c) return c; return b; }
}

//+------------------------------------------------------------------+
//| CLASS: CKNN_Engine  (otak algoritma, terisolasi per timeframe)   |
//+------------------------------------------------------------------+
class CKNN_Engine
{
    private:
    ENUM_TIMEFRAMES m_tf;
    string m_symbol;
    int m_lookback;
    int m_eff; // lookback efektif(sesuai ketersediaan bar)
    int m_k_neighbors;
    int m_horizon;
    double m_min_move;
    int m_cap;
    double m_threshold;
    int m_wf_samples;
    bool m_persist;

    SPattern m_memory[]; // database ternormalisasi
    SPattern m_raw[]; // database mentah
    datetime m_raw_t[]; // waktu bar fitur tiap pola
    int m_count;
    double m_min[FEATURE_COUNT];
    double m_max[FEATURE_COUNT];
    double m_feat_weight[FEATURE_COUNT]; // bobot tiap fitur di jarak KNN (dihitung dari daya pisah bull/bear)

    // parameter fitur regime & filter sinyal
    int m_er_period;
    int m_hurst_window;
    double m_min_match;
    double m_max_spread_pips;
    double m_max_avg_dist;

    // v2.51: smoothing buffers for regime features
    double m_smoothER[3];
    double m_smoothHurst[3];
    int    m_smoothIdx;

    // statistik tetangga terakhir & walk-forward
    int m_k_bull_count, m_k_bear_count;
    double m_wf_pnl, m_wf_avg_rr, m_wf_expectancy;
    int m_wf_trade_count;

    SDistance m_best[];

    int h_atr, h_ma, h_macd, h_fractal;
    MqlRates m_rates[];
    double b_atr[], b_ma[], b_macd[], b_fup[], b_flo[];
    int m_bars_loaded;

    datetime m_last_bar;
    bool m_ready;
    double m_prob_bull, m_prob_bear, m_trend_f4, m_avg_dist, m_match;
    int m_signal;
    bool m_aligned; // apakah Trend F4 selaras dengan m_signal saat ini (menentukan tier Selaras/Non-Selaras)
    int m_notif_state; // 0 = belum layak dinotifikasi, 1 = BUY sudah dinotifikasi, -1 = SELL sudah dinotifikasi

    // statistik self-learning dari K tetangga terakhir (diisi QueryKNN), dipakai untuk rekomendasi SL/TP
    double m_avgMoveBull, m_avgMoveBear; // rata-rata besar pergerakan aktual (ATR) tetangga Bull/Bear
    double m_avgMaeBull, m_avgMaeBear;   // rata-rata max adverse excursion (ATR) tetangga Bull/Bear
    bool   m_haveMoveBull, m_haveMoveBear;
    // level trading final untuk Signal saat ini (diisi ComputeCurrent), valid hanya jika m_signal != 0
    double m_tp_atr, m_sl_atr;       // jarak TP/SL dalam kelipatan ATR
    double m_entry_price, m_sl_price, m_tp_price; // level harga aktual
    double m_rr;                      // rasio Reward:Risk (tp_atr / sl_atr)

    SPred m_pend[];
    datetime m_last_pred_t;
    // statistik live per-tier: A = Selaras (trend align dgn signal), B = Non-Selaras - dilacak TERPISAH
    // supaya sistem bisa membuktikan sendiri tier mana yang performanya lebih baik (bukan diasumsikan)
    int m_sigA_n, m_sigA_hit, m_sigB_n, m_sigB_hit;
    int m_all_n, m_all_hit; // statistik live semua prediksi arah (kolom Acc%)

    double m_ref[]; // referensi jarak walk - forward
    int m_wf_all_n, m_wf_all_hit, m_wf_sig_n, m_wf_sig_hit;
    int m_since_wf;

    bool IsValid(const double v)
    {
        return(MathIsValidNumber(v) && v != EMPTY_VALUE && v != 0.0);
    }

    bool LoadBuffers(const int need)
    {
        if(CopyRates(m_symbol, m_tf, 0, need, m_rates) != need) return false;
        if(CopyBuffer(h_atr, 0, 0, need, b_atr) != need) return false;
        if(CopyBuffer(h_ma, 0, 0, need, b_ma) != need) return false;
        if(CopyBuffer(h_macd, 0, 0, need, b_macd) != need) return false;
        if(CopyBuffer(h_fractal, 0, 0, need, b_fup) != need) return false; // UPPER_LINE
        if(CopyBuffer(h_fractal, 1, 0, need, b_flo) != need) return false; // LOWER_LINE
        m_bars_loaded = need;
        return true;
    }

    void CopyPattern(const int dst, const int src)
    {
        for(int j = 0; j < FEATURE_COUNT; j++)
        m_raw[dst].features[j] = m_raw[src].features[j];
        m_raw[dst].target = m_raw[src].target;
        m_raw[dst].move_atr = m_raw[src].move_atr;
        m_raw[dst].mae_atr = m_raw[src].mae_atr;
        m_raw_t[dst] = m_raw_t[src];
    }

    void AppendPattern(const double &f[], const int outc, const datetime ts, const double move_atr, const double mae_atr)
    {
        int n = ArraySize(m_raw);
        ArrayResize(m_raw, n + 1, 256);
        ArrayResize(m_raw_t, n + 1, 256);
        for(int j = 0; j < FEATURE_COUNT; j++)
        m_raw[n].features[j] = f[j];
        m_raw[n].target = outc;
        m_raw[n].move_atr = move_atr;
        m_raw[n].mae_atr = mae_atr;
        m_raw_t[n] = ts;
    }

    void TrimToCap()
    {
        int n = ArraySize(m_raw);
        if(n <= m_cap) return;
        int rem = n - m_cap;
        for(int i = 0; i < m_cap; i++)
        CopyPattern(i, i + rem);
        ArrayResize(m_raw, m_cap);
        ArrayResize(m_raw_t, m_cap);
    }

    void RebuildNormalization()
    {
        m_count = ArraySize(m_raw);
        if(m_count <= 0) return;
        for(int j = 0; j < FEATURE_COUNT; j++)
        {
            m_min[j] = m_raw[0].features[j];
            m_max[j] = m_raw[0].features[j];
        }
        for(int i = 1; i < m_count; i++)
        for(int j = 0; j < FEATURE_COUNT; j++)
        {
            double v = m_raw[i].features[j];
            if(v < m_min[j]) m_min[j] = v;
            if(v > m_max[j]) m_max[j] = v;
        }
        ArrayResize(m_memory, m_count);
        for(int i = 0; i < m_count; i++)
        {
            double f[FEATURE_COUNT];
            for(int j = 0; j < FEATURE_COUNT; j++)
            f[j] = m_raw[i].features[j];
            NormalizeFeatures(f);
            for(int j = 0; j < FEATURE_COUNT; j++)
            m_memory[i].features[j] = f[j];
            m_memory[i].target = m_raw[i].target;
            m_memory[i].move_atr = m_raw[i].move_atr;
            m_memory[i].mae_atr = m_raw[i].mae_atr;
        }
        ComputeFeatureWeights();
        CheckFeatureDrift();
    }

   //--- Hitung bobot tiap fitur (F1..F8) berdasarkan seberapa besar fitur itu memisahkan
   //--- kelas Bull vs Bear di memori (mirip skor pemisahan/Cohen's d sederhana), lalu
   //--- dinormalisasi supaya rata-rata bobot = 1.0 (skala jarak KNN tetap sebanding seperti sebelumnya).
   //--- Fitur yang lebih diskriminatif -> bobot > 1 (lebih berpengaruh di jarak).
   //--- Fitur yang kurang diskriminatif -> bobot < 1 (kurang berpengaruh).
    void ComputeFeatureWeights()
    {
        for(int j = 0; j < FEATURE_COUNT; j++) m_feat_weight[j] = 1.0; // default netral

        if(m_count < 30) return; // sampel terlalu sedikit, jangan ubah bobot dulu

        double sumB[FEATURE_COUNT], sumS[FEATURE_COUNT];
        double sqB[FEATURE_COUNT], sqS[FEATURE_COUNT];
        for(int j = 0; j < FEATURE_COUNT; j++)
        {
            sumB[j] = 0.0; sumS[j] = 0.0; sqB[j] = 0.0; sqS[j] = 0.0;
        }
        int nB = 0, nS = 0;
        for(int i = 0; i < m_count; i++)
        {
            bool bull = (m_memory[i].target == 1);
            if(bull) nB++; else nS++;
            for(int j = 0; j < FEATURE_COUNT; j++)
            {
                double v = m_memory[i].features[j];
                if(bull) { sumB[j] += v; sqB[j] += v * v; }
                else     { sumS[j] += v; sqS[j] += v * v; }
            }
        }
        if(nB < 10 || nS < 10) return; // salah satu kelas terlalu sedikit, biarkan bobot netral

        double raw[FEATURE_COUNT];
        double sumRaw = 0.0;
        for(int j = 0; j < FEATURE_COUNT; j++)
        {
            double meanB = sumB[j] / (double)nB;
            double meanS = sumS[j] / (double)nS;
            double varB = MathMax(sqB[j] / (double)nB - meanB * meanB, 0.0);
            double varS = MathMax(sqS[j] / (double)nS - meanS * meanS, 0.0);
            double pooledStd = MathSqrt((varB + varS) / 2.0);
            raw[j] = MathAbs(meanB - meanS) / (pooledStd + 1e-6);
            sumRaw += raw[j];
        }
        double avgRaw = sumRaw / (double)FEATURE_COUNT;
        for(int j = 0; j < FEATURE_COUNT; j++)
        {
            double w = (avgRaw > 1e-9) ? (raw[j] / avgRaw) : 1.0;
            if(w < 0.2) w = 0.2; // batas bawah: fitur tetap ikut berkontribusi, tidak dimatikan total
            if(w > 3.0) w = 3.0; // batas atas: satu fitur tidak boleh mendominasi jarak sepenuhnya
            m_feat_weight[j] = w;
        }
    }

   //--- Rebuild min/max dan bobot fitur hanya dari data [0..upToIdx] (tidak lookahead)
    void RebuildNormalizationUpTo(const int upToIdx, double &min[], double &max[], double &w[])
    {
        int n = upToIdx + 1;
        if(n <= 0 || ArraySize(m_raw) < n) return;
        for(int j = 0; j < FEATURE_COUNT; j++)
        {
            min[j] = m_raw[0].features[j];
            max[j] = m_raw[0].features[j];
        }
        for(int i = 1; i < n; i++)
        for(int j = 0; j < FEATURE_COUNT; j++)
        {
            double v = m_raw[i].features[j];
            if(v < min[j]) min[j] = v;
            if(v > max[j]) max[j] = v;
        }
        ComputeFeatureWeightsUpTo(upToIdx, min, max, w);
    }

   //--- Bobot fitur dari data [0..upToIdx] dengan normalisasi min/max eksternal
    void ComputeFeatureWeightsUpTo(const int upToIdx, const double &min[], const double &max[], double &w[])
    {
        for(int j = 0; j < FEATURE_COUNT; j++) w[j] = 1.0;

        int n = upToIdx + 1;
        if(n < 30) return;

        double sumB[FEATURE_COUNT], sumS[FEATURE_COUNT];
        double sqB[FEATURE_COUNT], sqS[FEATURE_COUNT];
        for(int j = 0; j < FEATURE_COUNT; j++)
        {
            sumB[j] = 0.0; sumS[j] = 0.0; sqB[j] = 0.0; sqS[j] = 0.0;
        }
        int nB = 0, nS = 0;
        for(int i = 0; i < n; i++)
        {
            bool bull = (m_raw[i].target == 1);
            if(bull) nB++; else nS++;
            for(int j = 0; j < FEATURE_COUNT; j++)
            {
                double range = max[j] - min[j];
                double v = (range <= 1e-12) ? 0.5 : (m_raw[i].features[j] - min[j]) / range;
                if(bull) { sumB[j] += v; sqB[j] += v * v; }
                else     { sumS[j] += v; sqS[j] += v * v; }
            }
        }
        if(nB < 10 || nS < 10) return;

        double raw[FEATURE_COUNT];
        double sumRaw = 0.0;
        for(int j = 0; j < FEATURE_COUNT; j++)
        {
            double meanB = sumB[j] / (double)nB;
            double meanS = sumS[j] / (double)nS;
            double varB = MathMax(sqB[j] / (double)nB - meanB * meanB, 0.0);
            double varS = MathMax(sqS[j] / (double)nS - meanS * meanS, 0.0);
            double pooledStd = MathSqrt((varB + varS) / 2.0);
            raw[j] = MathAbs(meanB - meanS) / (pooledStd + 1e-6);
            sumRaw += raw[j];
        }
        double avgRaw = sumRaw / (double)FEATURE_COUNT;
        for(int j = 0; j < FEATURE_COUNT; j++)
        {
            double ww = (avgRaw > 1e-9) ? (raw[j] / avgRaw) : 1.0;
            if(ww < 0.2) ww = 0.2;
            if(ww > 3.0) ww = 3.0;
            w[j] = ww;
        }
    }

   //--- Deteksi drift fitur: peringatan jika mean rolling window berbeda > 2 std dari historis
    void CheckFeatureDrift()
    {
        int n = m_count;
        if(n < 2 * DIST_DRIFT_WINDOW) return;
        int roll = DIST_DRIFT_WINDOW;
        int histN = n - roll;
        double histMean[FEATURE_COUNT], histStd[FEATURE_COUNT], rollMean[FEATURE_COUNT];
        for(int j = 0; j < FEATURE_COUNT; j++)
        {
            histMean[j] = 0.0; histStd[j] = 0.0; rollMean[j] = 0.0;
        }
        for(int i = 0; i < histN; i++)
        for(int j = 0; j < FEATURE_COUNT; j++)
            histMean[j] += m_raw[i].features[j];
        for(int j = 0; j < FEATURE_COUNT; j++) histMean[j] /= (double)histN;
        for(int i = 0; i < histN; i++)
        for(int j = 0; j < FEATURE_COUNT; j++)
        {
            double d = m_raw[i].features[j] - histMean[j];
            histStd[j] += d * d;
        }
        for(int j = 0; j < FEATURE_COUNT; j++) histStd[j] = MathSqrt(histStd[j] / (double)histN);
        for(int i = histN; i < n; i++)
        for(int j = 0; j < FEATURE_COUNT; j++)
            rollMean[j] += m_raw[i].features[j];
        for(int j = 0; j < FEATURE_COUNT; j++) rollMean[j] /= (double)roll;
        for(int j = 0; j < FEATURE_COUNT; j++)
        {
            if(histStd[j] > 1e-12 && MathAbs(rollMean[j] - histMean[j]) > 2.0 * histStd[j])
                PrintFormat("[WARN] KNN %s drift F%d roll=%.4f hist=%.4f std=%.4f",
                            TFToString(m_tf), j + 1, rollMean[j], histMean[j], histStd[j]);
        }
    }

   //--- Hasil untuk bar fitur 's': bandingkan close bar (s - horizon) dengan close bar s
   //--- return 1 = Bull, 0 = Bear, -1 = gerak tidak signifikan / data tidak valid
    int OutcomeAt(const int s)
    {
        int o = s - m_horizon;
        if(o < 1 || s >= m_bars_loaded) return - 1;
        double atr = b_atr[s];
        if(!MathIsValidNumber(atr) || atr == EMPTY_VALUE || atr <= 0.0) return - 1;
        double mv = m_rates[o].close - m_rates[s].close;
        double thr = m_min_move * atr;
        if(mv > 0.0 && mv >= thr) return 1;
        if(mv < 0.0 && - mv >= thr) return 0;
        return - 1;
    }

   //--- Statistik "self-learning" untuk pola di bar 's' dengan hasil 'outc' (1=Bull, 0=Bear):
   //--- move_atr  = besar pergerakan aktual searah outc saat horizon selesai (dalam ATR)
   //--- mae_atr   = max adverse excursion (gerak berlawanan arah terburuk) selama horizon (dalam ATR)
   //--- Dipakai nanti untuk mengestimasi jarak TP (dari move_atr) & SL (dari mae_atr) berbasis histori.
    void ComputeMoveStats(const int s, const int outc, double &move_atr, double &mae_atr)
    {
        move_atr = 0.0; mae_atr = 0.0;
        int o = s - m_horizon;
        double atr = b_atr[s];
        if(atr <= 0.0 || o < 1 || s >= m_bars_loaded) return;

        double mv = m_rates[o].close - m_rates[s].close;
        move_atr = MathAbs(mv) / atr;

        double refClose = m_rates[s].close;
        double worst = 0.0;
        for(int idx = s - 1; idx >= o; idx--)
        {
            double dd;
            if(outc == 1) dd = refClose - m_rates[idx].low;  // Bull -> adverse = turun di bawah refClose
            else          dd = m_rates[idx].high - refClose; // Bear -> adverse = naik di atas refClose
            if(dd > worst) worst = dd;
        }
        mae_atr = worst / atr;
    }

   //--- KNN inti: scan memori index [from..to], Top-K terurut, voting berbobot jarak
    bool QueryKNN(const double &f[], const int from, const int to,
    double &bull_pct, double &avg_dist)
    {
        int K = m_k_neighbors;
        if(to < from || (to - from + 1) < K) return false;
        if(ArraySize(m_best) < K) ArrayResize(m_best, K);

        int filled = 0;
        for(int i = from; i <= to; i++)
        {
            double d = 0.0;
            for(int j = 0; j < FEATURE_COUNT; j++)
            {
                double diff = f[j] - m_memory[i].features[j];
                d += m_feat_weight[j] * diff * diff;
            }
            d = MathSqrt(d);

            int pos = 0;
            if(filled < K)
            {
                pos = filled;
                filled++;
            }
            else if(d < m_best[K - 1].dist)
            pos = K - 1;
            else
            continue;

            while(pos > 0 && m_best[pos - 1].dist > d) // insertion: selalu terurut kecil - > besar
            {
                m_best[pos].dist = m_best[pos - 1].dist;
                m_best[pos].target = m_best[pos - 1].target;
                m_best[pos].move_atr = m_best[pos - 1].move_atr;
                m_best[pos].mae_atr = m_best[pos - 1].mae_atr;
                pos--;
            }
            m_best[pos].dist = d;
            m_best[pos].target = m_memory[i].target;
            m_best[pos].move_atr = m_memory[i].move_atr;
            m_best[pos].mae_atr = m_memory[i].mae_atr;
        }

        if(filled < K) return false;

        double sumD = 0.0;
        for(int i = 0; i < K; i++) sumD += m_best[i].dist;
        avg_dist = sumD / (double)K;
        double sigma = MathMax(avg_dist, WEIGHT_EPS);
        double twoSigma2 = 2.0 * sigma * sigma;

        double wBull = 0.0, wTot = 0.0;
        double wMoveBull = 0.0, wMoveBear = 0.0, wMaeBull = 0.0, wMaeBear = 0.0;
        double wClassBull = 0.0, wClassBear = 0.0;
        int nBull = 0, nBear = 0;
        for(int i = 0; i < K; i++)
        {
            double d = m_best[i].dist;
            double w = (twoSigma2 > 0.0) ? MathExp(-(d * d) / twoSigma2) : 1.0;
            wTot += w;
            if(m_best[i].target == 1)
            {
                wBull += w;
                wClassBull += w;
                wMoveBull += w * m_best[i].move_atr;
                wMaeBull += w * m_best[i].mae_atr;
                nBull++;
            }
            else
            {
                wClassBear += w;
                wMoveBear += w * m_best[i].move_atr;
                wMaeBear += w * m_best[i].mae_atr;
                nBear++;
            }
        }
        if(wTot <= 0.0) return false;
        bull_pct = 100.0 * wBull / wTot;

        m_k_bull_count = nBull;
        m_k_bear_count = nBear;

   //--- simpan statistik self-learning (rata-rata berbobot move/MAE per arah) dari K tetangga ini
        m_avgMoveBull = (wClassBull > 0.0) ? (wMoveBull / wClassBull) : 0.0;
        m_avgMoveBear = (wClassBear > 0.0) ? (wMoveBear / wClassBear) : 0.0;
        m_avgMaeBull  = (wClassBull > 0.0) ? (wMaeBull / wClassBull) : 0.0;
        m_avgMaeBear  = (wClassBear > 0.0) ? (wMaeBear / wClassBear) : 0.0;
        m_haveMoveBull = (wClassBull > 0.0);
        m_haveMoveBear = (wClassBear > 0.0);
        return true;
    }

   //--- KNN dengan normalisasi/bobot beku (walk-forward, tidak lookahead)
    bool QueryKNN(const double &f[], const int from, const int to,
    double &bull_pct, double &avg_dist,
    const double &min[], const double &max[], const double &w[])
    {
        int K = m_k_neighbors;
        if(to < from || (to - from + 1) < K) return false;
        if(ArraySize(m_best) < K) ArrayResize(m_best, K);

        int filled = 0;
        for(int i = from; i <= to; i++)
        {
            double d = 0.0;
            for(int j = 0; j < FEATURE_COUNT; j++)
            {
                double range_i = max[j] - min[j];
                double vi = (range_i <= 1e-12) ? 0.5 : (m_raw[i].features[j] - min[j]) / range_i;
                double diff = f[j] - vi;
                d += w[j] * diff * diff;
            }
            d = MathSqrt(d);

            int pos = 0;
            if(filled < K)
            {
                pos = filled;
                filled++;
            }
            else if(d < m_best[K - 1].dist)
            pos = K - 1;
            else
            continue;

            while(pos > 0 && m_best[pos - 1].dist > d)
            {
                m_best[pos].dist = m_best[pos - 1].dist;
                m_best[pos].target = m_best[pos - 1].target;
                m_best[pos].move_atr = m_best[pos - 1].move_atr;
                m_best[pos].mae_atr = m_best[pos - 1].mae_atr;
                pos--;
            }
            m_best[pos].dist = d;
            m_best[pos].target = m_raw[i].target;
            m_best[pos].move_atr = m_raw[i].move_atr;
            m_best[pos].mae_atr = m_raw[i].mae_atr;
        }

        if(filled < K) return false;

        double sumD = 0.0;
        for(int i = 0; i < K; i++) sumD += m_best[i].dist;
        avg_dist = sumD / (double)K;
        double sigma = MathMax(avg_dist, WEIGHT_EPS);
        double twoSigma2 = 2.0 * sigma * sigma;

        double wBull = 0.0, wTot = 0.0;
        double wMoveBull = 0.0, wMoveBear = 0.0, wMaeBull = 0.0, wMaeBear = 0.0;
        double wClassBull = 0.0, wClassBear = 0.0;
        int nBull = 0, nBear = 0;
        for(int i = 0; i < K; i++)
        {
            double d = m_best[i].dist;
            double ww = (twoSigma2 > 0.0) ? MathExp(-(d * d) / twoSigma2) : 1.0;
            wTot += ww;
            if(m_best[i].target == 1)
            {
                wBull += ww;
                wClassBull += ww;
                wMoveBull += ww * m_best[i].move_atr;
                wMaeBull += ww * m_best[i].mae_atr;
                nBull++;
            }
            else
            {
                wClassBear += ww;
                wMoveBear += ww * m_best[i].move_atr;
                wMaeBear += ww * m_best[i].mae_atr;
                nBear++;
            }
        }
        if(wTot <= 0.0) return false;
        bull_pct = 100.0 * wBull / wTot;

        m_k_bull_count = nBull;
        m_k_bear_count = nBear;

        m_avgMoveBull = (wClassBull > 0.0) ? (wMoveBull / wClassBull) : 0.0;
        m_avgMoveBear = (wClassBear > 0.0) ? (wMoveBear / wClassBear) : 0.0;
        m_avgMaeBull  = (wClassBull > 0.0) ? (wMaeBull / wClassBull) : 0.0;
        m_avgMaeBear  = (wClassBear > 0.0) ? (wMaeBear / wClassBear) : 0.0;
        m_haveMoveBull = (wClassBull > 0.0);
        m_haveMoveBear = (wClassBear > 0.0);
        return true;
    }

   //--- persentase referensi historis yang jaraknya >= ad (100 = sangat mirip, 0 = pola asing)
    double MatchPercent(const double ad)
    {
        int n = ArraySize(m_ref);
        if(n < 20) return - 1.0;
        int c = 0;
        for(int i = 0; i < n; i++)
        if(m_ref[i] >= ad) c++;
        return 100.0 * (double)c / (double)n;
    }

   //--- Walk-forward: prediksi tiap pola terbaru hanya dengan pola yang lebih lama (tanpa lookahead)
    void RunWalkForward()
    {
        m_since_wf = 0;
        m_wf_all_n = 0; m_wf_all_hit = 0;
        m_wf_sig_n = 0; m_wf_sig_hit = 0;
        m_wf_pnl = 0.0; m_wf_avg_rr = 0.0; m_wf_expectancy = 0.0; m_wf_trade_count = 0;
        ArrayResize(m_ref, 0);

        int K = m_k_neighbors;
        int gapIdx = m_horizon + 1; // jarak index minimum agar hasil tetangga tidak tumpang tindih
        int first = MathMax(m_count - m_wf_samples, K + gapIdx + 50);
        if(first >= m_count) return;

        ArrayResize(m_ref, m_count - first);
        int cnt = 0;
        double sumRR = 0.0;
        double minF[FEATURE_COUNT], maxF[FEATURE_COUNT], wF[FEATURE_COUNT];

        for(int idx = first; idx < m_count; idx++)
        {
            int trainUpTo = idx - gapIdx - 1;
            if(trainUpTo < K) continue;

            RebuildNormalizationUpTo(trainUpTo, minF, maxF, wF);

            double f[FEATURE_COUNT];
            NormalizeFeatures(m_raw[idx].features, minF, maxF, f);

            double bp = 0.0, ad = 0.0;
            if(!QueryKNN(f, 0, idx - gapIdx, bp, ad, minF, maxF, wF)) continue;

            m_ref[cnt] = ad;
            cnt++;

            int pred = (bp > 50.0) ? 1 : ((bp < 50.0) ? 0 : -1);
            int act = m_raw[idx].target;
            if(pred >= 0)
            {
                m_wf_all_n++;
                if(pred == act) m_wf_all_hit++;
            }

            bool isBuy = (bp >= m_threshold);
            bool isSell = ((100.0 - bp) >= m_threshold);

            if(isBuy || isSell)
            {
                int sig = isBuy ? 1 : -1;
                if(sig == 1)
                {
                    m_wf_sig_n++;
                    if(act == 1) m_wf_sig_hit++;
                }
                else
                {
                    m_wf_sig_n++;
                    if(act == 0) m_wf_sig_hit++;
                }

                // simulasi PnL dengan TP/SL self-learning dari tetangga beku
                double moveAtr, maeAtr, tpAtr, slAtr;
                bool haveMove;
                if(sig == 1)
                {
                    moveAtr = m_avgMoveBull; maeAtr = m_avgMaeBull; haveMove = m_haveMoveBull;
                }
                else
                {
                    moveAtr = m_avgMoveBear; maeAtr = m_avgMaeBear; haveMove = m_haveMoveBear;
                }
                tpAtr = haveMove ? moveAtr : MathMax(m_min_move, 0.5);
                double slRaw = haveMove ? maeAtr : InpSLMinATR;
                slAtr = MathMax(slRaw * InpSLBufferMult, InpSLMinATR);
                double rr = (slAtr > 0.0) ? (tpAtr / slAtr) : 0.0;

                double pnl = 0.0;
                if(sig == 1 && act == 1) pnl = tpAtr;
                else if(sig == 1 && act == 0) pnl = -slAtr;
                else if(sig == -1 && act == 0) pnl = tpAtr;
                else if(sig == -1 && act == 1) pnl = -slAtr;

                m_wf_pnl += pnl;
                if(rr > 0.0) { sumRR += rr; m_wf_trade_count++; }
            }
        }
        ArrayResize(m_ref, cnt);
        if(cnt > 1) ArraySort(m_ref);

        m_wf_avg_rr = (m_wf_trade_count > 0) ? sumRR / (double)m_wf_trade_count : 0.0;
        m_wf_expectancy = (m_wf_trade_count > 0) ? m_wf_pnl / (double)m_wf_trade_count : 0.0;

        double acc = (m_wf_all_n > 0) ? 100.0 * (double)m_wf_all_hit / (double)m_wf_all_n : 0.0;
        double sacc = (m_wf_sig_n > 0) ? 100.0 * (double)m_wf_sig_hit / (double)m_wf_sig_n : 0.0;
        PrintFormat("[OK] KNN %s Walk-forward: n=%d acc=%.1f%% | signal n=%d hit=%.1f%% | trades=%d PnL=%.2f exp=%.2f rr=%.2f | mem=%d",
                    TFToString(m_tf), m_wf_all_n, acc, m_wf_sig_n, sacc, m_wf_trade_count, m_wf_pnl, m_wf_expectancy, m_wf_avg_rr, m_count);
        PrintFormat("[OK] KNN %s weights F1..F8: %.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f",
                    TFToString(m_tf), m_feat_weight[0], m_feat_weight[1], m_feat_weight[2], m_feat_weight[3],
                    m_feat_weight[4], m_feat_weight[5], m_feat_weight[6], m_feat_weight[7]);
    }

   //--- Cek keselarasan Trend F4 vs Signal DITAMBAH kualitas Match% & Hit%(n),
   //--- persis kriteria "Skenario A - Sinyal kuat" di README (bukan sekadar Skenario B
   //--- yang selaras tapi Match rendah / sampel Hit%(n) masih sedikit).
   //--- Notifikasi hanya terkirim sekali per transisi menuju kondisi memenuhi syarat.
   //--- Notifikasi self-tuning: tidak ada lagi ambang manual (Match%/Hit% tetap). Sistem
   //--- membandingkan performa LIVE tier saat ini (Selaras/Non-Selaras) terhadap baseline
   //--- netral 50% (patokan matematis utk klasifikasi 2 kelas, bukan angka pilihan) - dan
   //--- hanya notifikasi saat tier tsb SUDAH TERBUKTI (via data live-nya sendiri) lebih baik
   //--- dari tebakan acak. Selama data belum cukup (< MIN_TIER_SAMPLES), tetap notifikasi
   //--- apa adanya supaya statistik sempat terkumpul dulu (fase belajar).
    void CheckAlert()
    {
        if(m_signal == 0 || m_entry_price <= 0.0) { m_notif_state = 0; return; }

        int tierN = m_aligned ? m_sigA_n : m_sigB_n;
        int tierHit = m_aligned ? m_sigA_hit : m_sigB_hit;
        double tierPct = (tierN > 0) ? 100.0 * (double)tierHit / (double)tierN : - 1.0;

        bool notifyOk = (tierN < MIN_TIER_SAMPLES) || (tierPct > 50.0);

        int newState = notifyOk ? m_signal : 0;

        if(newState != 0 && newState != m_notif_state)
        {
            string dir = (newState == 1) ? "BUY" : "SELL";
            string trendTxt = (m_trend_f4 >= 0.0) ? "UP" : "DOWN";
            string tierTxt = m_aligned ? "Selaras" : "Non-Selaras";
            string tierStat = (tierN >= MIN_TIER_SAMPLES) ? (DoubleToString(tierPct, 0) + "%/" + IntegerToString(tierN)) : ("n/a, n=" + IntegerToString(tierN));
            string matchTxt = (m_match >= 0.0) ? (DoubleToString(m_match, 0) + "%") : "n/a";
            int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
            string lvlTxt = StringFormat(" | Entry=%s SL=%s(%.1fATR) TP=%s(%.1fATR) RR=1:%.1f",
            DoubleToString(m_entry_price, digits), DoubleToString(m_sl_price, digits), m_sl_atr,
            DoubleToString(m_tp_price, digits), m_tp_atr, m_rr);
            string msg = StringFormat("[Probabilitas Terbaik] %s %s | Tier %s (Hit %s) | Trend %s Bull=%.1f%% Bear=%.1f%% Match=%s%s",
            dir, TFToString(m_tf), tierTxt, tierStat, trendTxt, m_prob_bull, m_prob_bear, matchTxt, lvlTxt);
            FireNotification(m_symbol + " " + TFToString(m_tf), msg);
        }
        m_notif_state = newState;
    }

   //--- Filter kualitas sinyal: memori cukup, Match%, jarak, dan keseimbangan kelas
    bool SignalQualityOk(const double avg_dist)
    {
        if(m_count < MIN_MEMORY_FOR_SIGNAL) return false;

        if(m_min_match > 0.0 && m_match >= 0.0 && m_match < m_min_match) return false;

        if(m_max_avg_dist > 0.0 && avg_dist > m_max_avg_dist) return false;

        int nB = m_k_bull_count, nS = m_k_bear_count;
        if(nB > 0 && nS > 0)
        {
            double kratio = (double)MathMax(nB, nS) / (double)MathMin(nB, nS);
            if(kratio < 0.2 || kratio > 5.0) return false;
        }

        int memB = 0, memS = 0;
        for(int i = 0; i < m_count; i++)
        {
            if(m_raw[i].target == 1) memB++; else memS++;
        }
        if(memB > 0 && memS > 0)
        {
            double mratio = (double)MathMax(memB, memS) / (double)MathMin(memB, memS);
            if(mratio < 0.2 || mratio > 5.0) return false;
        }
        return true;
    }

    bool ComputeCurrent()
    {
        double b = 0.0, r = 0.0, ad = 0.0;
        if(!CalculateKNN_Probability(b, r, ad)) return false;
        m_prob_bull = b;
        m_prob_bear = r;
        m_avg_dist = ad;
        m_match = MatchPercent(ad);

        m_signal = 0;
        if(b >= m_threshold) m_signal = 1;
        else if(r >= m_threshold) m_signal = - 1;
        if(m_signal != 0 && !SignalQualityOk(ad)) m_signal = 0;
        ComputeTradeLevels();
        CheckAlert();
        return true;
    }

   //--- Hitung rekomendasi Entry/SL/TP dari statistik self-learning (move_atr & mae_atr rata-rata
   //--- berbobot dari K tetangga terdekat searah Signal). Hanya valid saat m_signal != 0.
    void ComputeTradeLevels()
    {
        m_tp_atr = 0.0; m_sl_atr = 0.0; m_entry_price = 0.0; m_sl_price = 0.0; m_tp_price = 0.0; m_rr = 0.0;
        m_aligned = false;
        if(m_signal == 0) return;

   //--- Trend F4 tidak lagi jadi syarat wajib untuk memunculkan rekomendasi (F4 sudah ikut
   //--- serta di jarak KNN dengan bobot yang dipelajari sendiri - mensyaratkan arahnya cocok
   //--- lagi secara terpisah berisiko membuang sinyal bagus yang F4-nya kebetulan berlawanan).
   //--- Sebagai gantinya, keselarasan dicatat sebagai TIER (Selaras/Non-Selaras) dan performa
   //--- live keduanya dilacak terpisah (lihat m_sigA_*/m_sigB_*) - datanya sendiri yang membuktikan
   //--- tier mana yang lebih baik, bukan asumsi di awal.
        bool trendUp = (m_trend_f4 >= 0.0);
        m_aligned = (trendUp && m_signal == 1) || (!trendUp && m_signal == - 1);

        double atrPrice = b_atr[1]; // ATR bar terakhir yang sudah closed, konsisten dengan fitur & trend
        if(!MathIsValidNumber(atrPrice) || atrPrice <= 0.0) return;

        double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
        if(bid <= 0.0 || ask <= 0.0) return;

   //--- filter spread lebar: tidak buat rekomendasi/alerts
        if(m_max_spread_pips > 0.0)
        {
            double spreadPips = (ask - bid) / PipsToPrice(m_symbol, 1.0);
            if(spreadPips > m_max_spread_pips) return;
        }

        double moveAtr, maeAtr;
        bool haveMove;
        if(m_signal == 1) { moveAtr = m_avgMoveBull; maeAtr = m_avgMaeBull; haveMove = m_haveMoveBull; }
        else              { moveAtr = m_avgMoveBear; maeAtr = m_avgMaeBear; haveMove = m_haveMoveBear; }

   //--- TP: rata-rata besar pergerakan aktual tetangga searah (otomatis >= InpMinMoveATR karena hanya
   //--- pola yang lolos ambang itu yang tercatat sebagai Bull/Bear). Fallback bila data belum cukup.
        m_tp_atr = haveMove ? moveAtr : MathMax(m_min_move, 0.5);

   //--- SL: rata-rata max adverse excursion tetangga searah, + buffer keamanan & batas bawah minimum
        double slRaw = haveMove ? maeAtr : InpSLMinATR;
        m_sl_atr = MathMax(slRaw * InpSLBufferMult, InpSLMinATR);

        m_rr = (m_sl_atr > 0.0) ? (m_tp_atr / m_sl_atr) : 0.0;

        if(m_signal == 1)
        {
            m_entry_price = ask;
            m_sl_price = m_entry_price - m_sl_atr * atrPrice;
            m_tp_price = m_entry_price + m_tp_atr * atrPrice;
        }
        else
        {
            m_entry_price = bid;
            m_sl_price = m_entry_price + m_sl_atr * atrPrice;
            m_tp_price = m_entry_price - m_tp_atr * atrPrice;
        }

   //--- validasi jarak SL vs SYMBOL_TRADE_STOPS_LEVEL + buffer
        long stops_level = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
        double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
        double minPriceDist = (stops_level + 5.0) * point;
        double slDist = MathAbs(m_entry_price - m_sl_price);
        if(slDist < minPriceDist)
        {
            m_sl_atr = MathMax(m_sl_atr, minPriceDist / atrPrice);
            if(m_signal == 1)
                m_sl_price = m_entry_price - m_sl_atr * atrPrice;
            else
                m_sl_price = m_entry_price + m_sl_atr * atrPrice;
            m_rr = (m_sl_atr > 0.0) ? (m_tp_atr / m_sl_atr) : 0.0;
        }
    }

   //--- catat prediksi bar yang baru close untuk dievaluasi setelah 'horizon' bar
    void RecordPrediction()
    {
        datetime t = m_rates[1].time;
        if(t == m_last_pred_t) return;
        m_last_pred_t = t;
        int n = ArraySize(m_pend);
        ArrayResize(m_pend, n + 1);
        m_pend[n].t = t;
        m_pend[n].pred = (m_prob_bull > 50.0) ? 1 : ((m_prob_bull < 50.0) ? 0 : - 1);
        m_pend[n].sig = m_signal;
        m_pend[n].aligned = m_aligned;
    }

   //--- evaluasi prediksi lama yang hasilnya sudah tersedia
    void EvaluatePending()
    {
        int n = ArraySize(m_pend);
        if(n == 0) return;
        SPred keep[];
        ArrayResize(keep, n);
        int kn = 0;
        for(int i = 0; i < n; i++)
        {
            int s = iBarShift(m_symbol, m_tf, m_pend[i].t, true);
            if(s < 0 || s >= m_bars_loaded) continue; // bar tidak ditemukan / terlalu tua: buang
            if(s - m_horizon < 1) // hasil belum tersedia
            {
                keep[kn] = m_pend[i];
                kn++;
                continue;
            }
            int outc = OutcomeAt(s);
            if(outc < 0) continue; // gerak tidak signifikan: tidak dihitung
            if(m_pend[i].pred >= 0)
            {
                m_all_n++;
                if(m_pend[i].pred == outc) m_all_hit++;
            }
            if(m_pend[i].sig != 0)
            {
                bool hit = (m_pend[i].sig == 1 && outc == 1) || (m_pend[i].sig == - 1 && outc == 0);
                if(m_pend[i].aligned)
                {
                    m_sigA_n++;
                    if(hit) m_sigA_hit++;
                }
                else
                {
                    m_sigB_n++;
                    if(hit) m_sigB_hit++;
                }
            }
        }
        ArrayResize(m_pend, kn);
        for(int i = 0; i < kn; i++)
        m_pend[i] = keep[i];
    }

   //--- persistensi
    string StateFile()
    {
        string s = m_symbol;
        StringReplace(s, " / ", "_");
        StringReplace(s, "\\", "_");
        StringReplace(s, ":", "_");
        StringReplace(s, " * ", "_");
        StringReplace(s, "?", "_");
        StringReplace(s, "\"", "_");
        StringReplace(s, " < ", "_");
        StringReplace(s, " > ", "_");
        StringReplace(s, "|", "_");
        return "KNNW_" + s + "_" + TFToString(m_tf) + ".bin";
    }

    void ClearState()
    {
        ArrayResize(m_raw, 0);
        ArrayResize(m_raw_t, 0);
        ArrayResize(m_pend, 0);
        m_sigA_n = 0; m_sigA_hit = 0; m_sigB_n = 0; m_sigB_hit = 0; m_all_n = 0; m_all_hit = 0;
        m_last_pred_t = 0;
    }

    void SaveState()
    {
        if(!m_persist || !m_ready) return;
        int h = FileOpen(StateFile(), FILE_WRITE | FILE_BIN);
        if(h == INVALID_HANDLE) return;

        FileWriteInteger(h, STATE_MAGIC, INT_VALUE);
        FileWriteInteger(h, STATE_VERSION, INT_VALUE);
        FileWriteInteger(h, m_horizon, INT_VALUE);
        FileWriteDouble(h, m_min_move);

        int n = ArraySize(m_raw);
        FileWriteInteger(h, n, INT_VALUE);
        for(int i = 0; i < n; i++)
        {
            FileWriteLong(h, (long)m_raw_t[i]);
            for(int j = 0; j < FEATURE_COUNT; j++)
            FileWriteDouble(h, m_raw[i].features[j]);
            FileWriteInteger(h, m_raw[i].target, INT_VALUE);
            FileWriteDouble(h, m_raw[i].move_atr);
            FileWriteDouble(h, m_raw[i].mae_atr);
        }

        FileWriteInteger(h, m_sigA_n, INT_VALUE);
        FileWriteInteger(h, m_sigA_hit, INT_VALUE);
        FileWriteInteger(h, m_sigB_n, INT_VALUE);
        FileWriteInteger(h, m_sigB_hit, INT_VALUE);
        FileWriteInteger(h, m_all_n, INT_VALUE);
        FileWriteInteger(h, m_all_hit, INT_VALUE);
        FileWriteLong(h, (long)m_last_pred_t);

        int pn = ArraySize(m_pend);
        FileWriteInteger(h, pn, INT_VALUE);
        for(int i = 0; i < pn; i++)
        {
            FileWriteLong(h, (long)m_pend[i].t);
            FileWriteInteger(h, m_pend[i].pred, INT_VALUE);
            FileWriteInteger(h, m_pend[i].sig, INT_VALUE);
            FileWriteInteger(h, m_pend[i].aligned ? 1 : 0, INT_VALUE);
        }
        FileWriteInteger(h, STATE_MAGIC, INT_VALUE); // penanda akhir file
        FileClose(h);
    }

    bool LoadState()
    {
        if(!m_persist) return false;
        string fn = StateFile();
        if(!FileIsExist(fn)) return false;
        int h = FileOpen(fn, FILE_READ | FILE_BIN);
        if(h == INVALID_HANDLE) return false;

        bool ok = true;
        if(FileReadInteger(h, INT_VALUE) != STATE_MAGIC) ok = false;
        if(ok && FileReadInteger(h, INT_VALUE) != STATE_VERSION) ok = false;

        int hz = 0, n = 0;
        double mm = 0.0;
        if(ok)
        {
            hz = FileReadInteger(h, INT_VALUE);
            mm = FileReadDouble(h);
            n = FileReadInteger(h, INT_VALUE);
            if(hz != m_horizon || MathAbs(mm - m_min_move) > 1e-9 || n < 0 || n > 500000) ok = false;
        }

        if(ok)
        {
            ArrayResize(m_raw, n);
            ArrayResize(m_raw_t, n);
            for(int i = 0; i < n; i++)
            {
                m_raw_t[i] = (datetime)FileReadLong(h);
                for(int j = 0; j < FEATURE_COUNT; j++)
                m_raw[i].features[j] = FileReadDouble(h);
                m_raw[i].target = FileReadInteger(h, INT_VALUE);
                m_raw[i].move_atr = FileReadDouble(h);
                m_raw[i].mae_atr = FileReadDouble(h);
            }
            m_sigA_n = FileReadInteger(h, INT_VALUE);
            m_sigA_hit = FileReadInteger(h, INT_VALUE);
            m_sigB_n = FileReadInteger(h, INT_VALUE);
            m_sigB_hit = FileReadInteger(h, INT_VALUE);
            m_all_n = FileReadInteger(h, INT_VALUE);
            m_all_hit = FileReadInteger(h, INT_VALUE);
            m_last_pred_t = (datetime)FileReadLong(h);

            int pn = FileReadInteger(h, INT_VALUE);
            if(pn < 0 || pn > 10000) ok = false;
            else
            {
                ArrayResize(m_pend, pn);
                for(int i = 0; i < pn; i++)
                {
                    m_pend[i].t = (datetime)FileReadLong(h);
                    m_pend[i].pred = FileReadInteger(h, INT_VALUE);
                    m_pend[i].sig = FileReadInteger(h, INT_VALUE);
                    m_pend[i].aligned = (FileReadInteger(h, INT_VALUE) != 0);
                }
            }
            if(ok && FileReadInteger(h, INT_VALUE) != STATE_MAGIC) ok = false;
        }
        FileClose(h);
        if(!ok) ClearState();
        return ok;
    }

    public:
    CKNN_Engine()
    {
        m_tf = PERIOD_CURRENT; m_symbol = ""; m_lookback = 1500; m_eff = 1500; m_k_neighbors = 21;
        m_horizon = 3; m_min_move = 0.5; m_cap = 3000; m_threshold = 70.0;
        m_wf_samples = 250; m_persist = true;
        m_count = 0; m_bars_loaded = 0; m_last_bar = 0; m_ready = false;
        m_prob_bull = 0.0; m_prob_bear = 0.0; m_trend_f4 = 0.0; m_avg_dist = 0.0; m_match = - 1.0;
        m_signal = 0; m_aligned = false; m_last_pred_t = 0; m_notif_state = 0;
        m_avgMoveBull = 0.0; m_avgMoveBear = 0.0; m_avgMaeBull = 0.0; m_avgMaeBear = 0.0;
        m_haveMoveBull = false; m_haveMoveBear = false;
        m_tp_atr = 0.0; m_sl_atr = 0.0; m_entry_price = 0.0; m_sl_price = 0.0; m_tp_price = 0.0; m_rr = 0.0;
        m_sigA_n = 0; m_sigA_hit = 0; m_sigB_n = 0; m_sigB_hit = 0; m_all_n = 0; m_all_hit = 0;
        m_wf_all_n = 0; m_wf_all_hit = 0; m_wf_sig_n = 0; m_wf_sig_hit = 0; m_since_wf = 0;
        h_atr = INVALID_HANDLE; h_ma = INVALID_HANDLE; h_macd = INVALID_HANDLE; h_fractal = INVALID_HANDLE;
        for(int j = 0; j < FEATURE_COUNT; j++) { m_min[j] = 0.0; m_max[j] = 1.0; m_feat_weight[j] = 1.0; }
        m_er_period = 20; m_hurst_window = 64;
        m_min_match = 20.0; m_max_spread_pips = 50.0; m_max_avg_dist = 0.0;
        m_k_bull_count = 0; m_k_bear_count = 0;
        m_smoothIdx = 0;
        for(int j = 0; j < 3; j++) { m_smoothER[j] = 0.5; m_smoothHurst[j] = 0.5; }
        m_wf_pnl = 0.0; m_wf_avg_rr = 0.0; m_wf_expectancy = 0.0; m_wf_trade_count = 0;
        }
        ~CKNN_Engine() { ReleaseHandles(); }

            bool InitEngine(const string symbol, const ENUM_TIMEFRAMES tf, const int lookback, const int k,
            const int horizon, const double min_move, const int max_memory,
            const double threshold,
            const int wf_samples, const bool persist)
            {
                m_symbol = symbol;
                m_tf = tf;
                m_lookback = lookback;
                m_eff = lookback;
                m_k_neighbors = (k < 1 ? 1 : k);
                m_horizon = (horizon < 1 ? 1 : horizon);
                m_min_move = (min_move < 0.0 ? 0.0 : min_move);
                m_cap = (max_memory < lookback ? lookback : max_memory);
                m_threshold = threshold;
                m_wf_samples = (wf_samples < 50 ? 50 : wf_samples);
                m_persist = persist;

                ArrayResize(m_best, m_k_neighbors);
                ArraySetAsSeries(m_rates, true);
                ArraySetAsSeries(b_atr, true);
                ArraySetAsSeries(b_ma, true);
                ArraySetAsSeries(b_macd, true);
                ArraySetAsSeries(b_fup, true);
                ArraySetAsSeries(b_flo, true);

                h_atr = iATR(m_symbol, m_tf, 14);
                h_ma = iMA(m_symbol, m_tf, 34, 0, MODE_EMA, PRICE_CLOSE);
                h_macd = iMACD(m_symbol, m_tf, 12, 26, 9, PRICE_CLOSE);
                h_fractal = iFractals(m_symbol, m_tf);

                if(h_atr == INVALID_HANDLE || h_ma == INVALID_HANDLE ||
                h_macd == INVALID_HANDLE || h_fractal == INVALID_HANDLE)
                {
                    PrintFormat("CKNN_Engine[ % s]: gagal membuat handle indikator(err % d)", TFToString(m_tf), GetLastError());
                    ReleaseHandles();
                    return false;
                }
                return true;
            }

   //--- set filter tambahan & parameter fitur regime (dipanggil setelah InitEngine)
            void SetSignalFilters(const double minMatch, const double maxSpreadPips, const double maxAvgDist)
            {
                m_min_match = minMatch;
                m_max_spread_pips = maxSpreadPips;
                m_max_avg_dist = maxAvgDist;
            }
            void SetERPeriod(const int p) { m_er_period = MathMax(5, p); }
            void SetHurstWindow(const int w) { m_hurst_window = MathMax(8, w); }

   //--- F6: Efficiency Ratio (Kaufman) - rasio perpindahan bersih terhadap total jarak tempuh,
   //--- analog efisiensi mekanik (displacement/path-length). 1.0 = trend efisien/lurus,
   //--- mendekati 0 = choppy/ranging (banyak bolak-balik untuk perpindahan bersih yang kecil).
   //--- v2.51: period and optional 3-bar median smoothing to reduce noise on small TFs.
            double ComputeEfficiencyRatio(const int shift, const int period)
            {
                int p = MathMax(2, MathMin(period, 200));
                if(shift + p >= m_bars_loaded) return 0.5;
                double netChange = MathAbs(m_rates[shift].close - m_rates[shift + p].close);
                double pathSum = 0.0;
                for(int i = shift; i < shift + p; i++)
                pathSum += MathAbs(m_rates[i].close - m_rates[i + 1].close);
                if(pathSum <= 1e-12) return 0.0;
                double er = netChange / pathSum;
                if(er > 1.0) er = 1.0;
                if(er < 0.0) er = 0.0;

                if(!InpSmoothRegime) return er;
                int idx = m_smoothIdx % 3;
                m_smoothER[idx] = er;
                m_smoothIdx++;
                double a = m_smoothER[0], b = m_smoothER[1], c = m_smoothER[2];
                return Median3(a, b, c);
            }

   //--- Rescaled-Range (R/S) untuk window sepanjang 'n' bar mulai dari 'shift' (mundur ke masa lalu).
   //--- Dasar dari estimasi Hurst Exponent (asalnya dari studi Hurst/Mandelbrot soal
   //--- fluktuasi alami - fraktal & Brownian motion di fisika statistik).
            double ComputeRS(const int shift, const int n)
            {
                if(n < 2 || n > m_hurst_window || shift + n >= m_bars_loaded) return 0.0;
                double ret[];
                ArrayResize(ret, n);
                double mean = 0.0;
                for(int i = 0; i < n; i++)
                {
                    ret[i] = m_rates[shift + i].close - m_rates[shift + i + 1].close;
                    mean += ret[i];
                }
                mean /= (double)n;

                double cum = 0.0, maxY = -1.0e18, minY = 1.0e18, sumSq = 0.0;
                for(int i = 0; i < n; i++)
                {
                    double dev = ret[i] - mean;
                    cum += dev;
                    if(cum > maxY) maxY = cum;
                    if(cum < minY) minY = cum;
                    sumSq += dev * dev;
                }
                double R = maxY - minY;
                double S = MathSqrt(sumSq / (double)n);
                if(S <= 1e-12) return 0.0;
                return R / S;
            }

   //--- F7: Hurst Exponent (estimasi ringkas 2-skala) - H > 0.5 = persisten/trending,
   //--- H < 0.5 = anti-persisten/mean-reverting, H mendekati 0.5 = mirip random walk.
            double ComputeHurst(const int shift)
            {
                int W = m_hurst_window;
                int half = W / 2;
                if(half < 2) return 0.5;
                double rsFull = ComputeRS(shift, W);
                double rsH1 = ComputeRS(shift, half);
                double rsH2 = ComputeRS(shift + half, half);
                double rsHalfAvg = 0.0;
                if(rsH1 > 0.0 && rsH2 > 0.0) rsHalfAvg = (rsH1 + rsH2) / 2.0;
                else rsHalfAvg = MathMax(rsH1, rsH2);

                if(rsFull <= 0.0 || rsHalfAvg <= 0.0) return 0.5; // fallback netral (random walk)
                double H = MathLog(rsFull / rsHalfAvg) / MathLog(2.0);
                if(H < 0.0) H = 0.0;
                if(H > 1.0) H = 1.0;
                return H;
            }

   //--- F8: Wave Leg Ratio - rasio jarak leg fractal terbaru terhadap leg fractal sebelumnya
   //--- (3 titik pivot fractal berurutan -> 2 leg). Rasio kontinu ini secara alami menangkap
   //--- hubungan Fibonacci antar-wave (0.382/0.618/1.0/1.618 dst muncul dari data, bukan
   //--- di-hardcode) - pendekatan wajar terhadap struktur wave berjenjang, bukan ZigZag sempurna.
            double ComputeWaveLegRatio(const int shift)
            {
                double pts[3];
                int found = 0;
                for(int j = shift + 2; j < shift + 2 + FRACTAL_SCAN && found < 3; j++)
                {
                    double v = 0.0;
                    if(IsValid(b_fup[j])) v = b_fup[j];
                    else if(IsValid(b_flo[j])) v = b_flo[j];
                    if(v > 0.0)
                    {
                        pts[found] = v;
                        found++;
                    }
                }
                if(found < 3) return 1.0; // data fractal belum cukup -> netral (leg dianggap setara)

                double legOlder = MathAbs(pts[1] - pts[2]); // leg sebelumnya (pivot tengah -> pivot terlama)
                double legRecent = MathAbs(pts[0] - pts[1]); // leg terbaru (pivot terbaru -> pivot tengah)
                if(legOlder <= 1e-12) return 1.0;
                double r = legRecent / legOlder;
                if(r > 5.0) r = 5.0; // clip agar outlier ekstrem tidak merusak skala normalisasi
                return r;
            }

   //--- F1..F8 dari bar 'shift' (bar yang sudah close). shift=1 -> bar t-1 saat ini
            bool ExtractFeatures(const int shift, double &f[])
            {
                if(shift < 1) return false;
                if(shift + 2 + FRACTAL_SCAN >= m_bars_loaded) return false;

                double atr = b_atr[shift];
                if(!MathIsValidNumber(atr) || atr == EMPTY_VALUE || atr <= 0.0) return false;
                if(b_ma[shift] == EMPTY_VALUE || b_macd[shift] == EMPTY_VALUE || b_macd[shift + 2] == EMPTY_VALUE) return false;

      // F1: rata-rata Close Position Location 3 candle terakhir
                double sum = 0.0;
                for(int i = 0; i < 3; i++)
                {
                    double rng = m_rates[shift + i].high - m_rates[shift + i].low;
                    double loc = (rng > 0.0) ? (m_rates[shift + i].close - m_rates[shift + i].low) / rng : 0.5;
                    sum += loc;
                }
                f[0] = sum / 3.0;

      // F2: Volatilitas relatif terhadap ATR
                f[1] = (m_rates[shift].high - m_rates[shift].low) / atr;

      // F3: Wave Retracement (fractal terkonfirmasi terdekat: index >= shift+2, tanpa lookahead)
                double up = 0.0, lo = 0.0;
                for(int j = shift + 2; j < shift + 2 + FRACTAL_SCAN; j++)
                {
                    if(up == 0.0 && IsValid(b_fup[j])) up = b_fup[j];
                    if(lo == 0.0 && IsValid(b_flo[j])) lo = b_flo[j];
                    if(up > 0.0 && lo > 0.0) break;
                }
                double c = m_rates[shift].close;
                if(up > 0.0 && lo > 0.0 && up > lo) f[2] = (c - lo) / (up - lo);
                else f[2] = 0.5;

      // F4: Trend Phase
                f[3] = (c - b_ma[shift]) / atr;

      // F5: Wave Momentum (MACD main t-1 minus t-3)
                f[4] = b_macd[shift] - b_macd[shift + 2];

      // F6: Efficiency Ratio (regime: trending vs choppy/ranging), window m_er_period bar
                f[5] = Median3(ComputeEfficiencyRatio(shift, m_er_period),
                               ComputeEfficiencyRatio(shift + 1, m_er_period),
                               ComputeEfficiencyRatio(shift + 2, m_er_period));

      // F7: Hurst Exponent (regime: persisten/trending vs mean-reverting), window m_hurst_window bar
                f[6] = Median3(ComputeHurst(shift), ComputeHurst(shift + 1), ComputeHurst(shift + 2));

      // F8: Wave Leg Ratio (hubungan Fibonacci antar-leg fractal berurutan)
                f[7] = ComputeWaveLegRatio(shift);

                for(int j = 0; j < FEATURE_COUNT; j++)
                if(!MathIsValidNumber(f[j])) return false;
                return true;
            }

   //--- Min-Max Scaling ke [0,1]
            void NormalizeFeatures(double &f[])
            {
                for(int j = 0; j < FEATURE_COUNT; j++)
                {
                    double range = m_max[j] - m_min[j];
                    double v = (range <= 1e-12) ? 0.5 : (f[j] - m_min[j]) / range;
                    if(v < 0.0) v = 0.0;
                    if(v > 1.0) v = 1.0;
                    f[j] = v;
                }
            }

   //--- Min-Max Scaling ke [0,1] dengan parameter min/max eksternal (untuk walk-forward)
            void NormalizeFeatures(const double &src[], const double &min[], const double &max[], double &dst[])
            {
                for(int j = 0; j < FEATURE_COUNT; j++)
                {
                    double range = max[j] - min[j];
                    double v = (range <= 1e-12) ? 0.5 : (src[j] - min[j]) / range;
                    if(v < 0.0) v = 0.0;
                    if(v > 1.0) v = 1.0;
                    dst[j] = v;
                }
            }

   //--- Isi database: muat file (jika ada), lalu tambahkan pola baru dari histori (loop mundur)
            bool WarmUpDatabase()
            {
                int avail = Bars(m_symbol, m_tf);
                if(avail < 300) return false;
                m_eff = MathMin(m_lookback, avail - 125);
                int need = m_eff + 120;
                if(!LoadBuffers(need)) return false;

                if(ArraySize(m_raw) == 0) LoadState();

                int n0 = ArraySize(m_raw);
                datetime last_t = (n0 > 0) ? m_raw_t[n0 - 1] : (datetime)0;

                for(int s = m_eff + 1; s > m_horizon; s--) // dari bar tertua ke terbaru
                {
                    datetime ts = m_rates[s].time;
                    if(ts <= last_t) continue; // sudah ada di memori(dari file)
                    int outc = OutcomeAt(s);
                    if(outc < 0) continue; // gerak tidak signifikan dilewati
                    double f[FEATURE_COUNT];
                    if(!ExtractFeatures(s, f)) continue;
                    double move_atr = 0.0, mae_atr = 0.0;
                    ComputeMoveStats(s, outc, move_atr, mae_atr);
                    AppendPattern(f, outc, ts, move_atr, mae_atr);
                }
                TrimToCap();

                int n = ArraySize(m_raw);
                if(n < 60 || n < m_k_neighbors * 3) return false;

                RebuildNormalization();
                m_last_bar = m_rates[0].time;
                EvaluatePending();
                RunWalkForward();

                m_ready = ComputeCurrent();
                if(m_ready)
                {
                    RecordPrediction();
                    SaveState();
                }
                return m_ready;
            }

   //--- Euclidean distance ke seluruh memori, Top-K terurut, voting berbobot jarak
            bool CalculateKNN_Probability(double &bull_pct, double &bear_pct, double &avg_dist)
            {
                if(m_count < m_k_neighbors) return false;

                double f[FEATURE_COUNT];
                if(!ExtractFeatures(1, f)) return false;
                m_trend_f4 = f[3]; // simpan F4 mentah untuk kolom Trend
                NormalizeFeatures(f);

                if(!QueryKNN(f, 0, m_count - 1, bull_pct, avg_dist)) return false;
                bear_pct = 100.0 - bull_pct;
                return true;
            }

   //--- Dipanggil dari OnTimer: continuous learning + hitung ulang saat bar baru
            void Update()
            {
                if(!m_ready) { WarmUpDatabase(); return; }

                    datetime t = iTime(m_symbol, m_tf, 0);
                    if(t == 0 || t == m_last_bar) return; // belum ada bar baru

                    int gap = iBarShift(m_symbol, m_tf, m_last_bar, false);
                    if(gap != 1) // ada bar terlewat - > gabungkan ulang dari histori
                    {
                        m_ready = false;
                        WarmUpDatabase();
                        return;
                    }

                    if(!LoadBuffers(m_eff + 120)) return;

      // pelajari pola baru: fitur di bar (horizon+1), hasilnya kini diketahui di bar 1
                    int s = m_horizon + 1;
                    int outc = OutcomeAt(s);
                    double f[FEATURE_COUNT];
                    if(outc >= 0 && ExtractFeatures(s, f))
                    {
                        datetime ts = m_rates[s].time;
                        int n = ArraySize(m_raw);
                        if(n == 0 || ts > m_raw_t[n - 1])
                        {
                            double move_atr = 0.0, mae_atr = 0.0;
                            ComputeMoveStats(s, outc, move_atr, mae_atr);
                            AppendPattern(f, outc, ts, move_atr, mae_atr);
                            TrimToCap();
                            RebuildNormalization();
                        }
                    }

                    m_last_bar = m_rates[0].time;
                    EvaluatePending();

                    m_since_wf++;
                    if(m_since_wf >= WF_REFRESH_BARS) RunWalkForward();

                    if(ComputeCurrent()) RecordPrediction();
                    SaveState();
                }

                void ReleaseHandles()
                {
                    if(h_atr != INVALID_HANDLE) { IndicatorRelease(h_atr); h_atr = INVALID_HANDLE; }
                        if(h_ma != INVALID_HANDLE) { IndicatorRelease(h_ma); h_ma = INVALID_HANDLE; }
                            if(h_macd != INVALID_HANDLE) { IndicatorRelease(h_macd); h_macd = INVALID_HANDLE; }
                                if(h_fractal != INVALID_HANDLE) { IndicatorRelease(h_fractal); h_fractal = INVALID_HANDLE; }
                                }

                                bool IsReady() { return m_ready; }
                                    double GetBull() { return m_prob_bull; }
                                        double GetBear() { return m_prob_bear; }
                                            double GetTrend() { return m_trend_f4; }
                                                double GetAvgDist() { return m_avg_dist; }
                                                    double GetMatch() { return m_match; }
                                                        int GetSignal() { return m_signal; }
                                                            string GetTFName() { return TFToString(m_tf); }

   //--- rekomendasi Entry/SL/TP self-learning: true hanya jika Signal != 0 & harga berhasil diambil.
   //--- aligned/tierPct/tierN: tier (Selaras/Non-Selaras) sinyal ini & statistik live tier tsb.
                                                                bool GetTradeLevels(double &entry, double &sl, double &tp, double &slAtr, double &tpAtr, double &rr,
                                                                bool &aligned, double &tierPct, int &tierN)
                                                                {
                                                                    entry = m_entry_price; sl = m_sl_price; tp = m_tp_price;
                                                                    slAtr = m_sl_atr; tpAtr = m_tp_atr; rr = m_rr;
                                                                    aligned = m_aligned;
                                                                    tierPct = GetTierStats(m_aligned, tierN);
                                                                    return (m_signal != 0 && m_entry_price > 0.0);
                                                                }

   //--- statistik live (forward) : hit-rate sinyal BUY/SELL dan akurasi semua prediksi
                                                                double GetLiveSigHit(int &n)
                                                                {
                                                                    n = m_sigA_n + m_sigB_n;
                                                                    int hit = m_sigA_hit + m_sigB_hit;
                                                                    return (n > 0) ? 100.0 * (double)hit / (double)n : - 1.0;
                                                                }
   //--- statistik live per-tier (Selaras/Non-Selaras) - dasar keputusan notifikasi self-tuning
                                                                double GetTierStats(const bool aligned, int &n)
                                                                {
                                                                    n = aligned ? m_sigA_n : m_sigB_n;
                                                                    int hit = aligned ? m_sigA_hit : m_sigB_hit;
                                                                    return (n > 0) ? 100.0 * (double)hit / (double)n : - 1.0;
                                                                }
                                                                bool IsAligned() { return m_aligned; }
                                                                    double GetLiveAcc(int &n) { n = m_all_n; return(m_all_n > 0) ? 100.0 * (double)m_all_hit / (double)m_all_n : - 1.0; }
   //--- statistik walk-forward backtest
                                                                        double GetWFAcc(int &n) { n = m_wf_all_n; return(m_wf_all_n > 0) ? 100.0 * (double)m_wf_all_hit / (double)m_wf_all_n : - 1.0; }
                                                                            double GetWFSigHit(int &n) { n = m_wf_sig_n; return(m_wf_sig_n > 0) ? 100.0 * (double)m_wf_sig_hit / (double)m_wf_sig_n : - 1.0; }
                                                                            double GetWFProfit() { return m_wf_pnl; }
                                                                            double GetWFAvgRR() { return m_wf_avg_rr; }
                                                                            double GetWFExpectancy() { return m_wf_expectancy; }
                                                                            int GetWFTradeCount() { return m_wf_trade_count; }
                                                                            };

//+------------------------------------------------------------------+
//| Global                                                           |
//+------------------------------------------------------------------+
                                                                            CKNN_Engine * g_engine[TF_COUNT];
                                                                            ENUM_TIMEFRAMES g_tfs[TF_COUNT] = {PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1};
                                                                                int g_horizon = 3;
                                                                                double g_minMove = 0.5;
                                                                                int g_k = 21;
                                                                                double g_thr = 70.0;
                                                                                ENUM_BASE_CORNER g_corner = CORNER_RIGHT_UPPER;
//+------------------------------------------------------------------+
//| GUI helpers                                                      |
//+------------------------------------------------------------------+
                                                                                void CreateRect(const string name, const int x, const int y, const int w, const int h)
                                                                                {
                                                                                    if(ObjectFind(0, name) < 0)
                                                                                    ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
                                                                                    ObjectSetInteger(0, name, OBJPROP_CORNER, g_corner);
                                                                                    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
                                                                                    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
                                                                                    ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
                                                                                    ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
                                                                                    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'18, 20, 30');
                                                                                    ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
                                                                                    ObjectSetInteger(0, name, OBJPROP_COLOR, clrDimGray);
                                                                                    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
                                                                                    ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
                                                                                    ObjectSetInteger(0, name, OBJPROP_BACK, false);
                                                                                    ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
                                                                                }

                                                                                void SetLabel(const string name, const int x, const int y, const string text,
                                                                                const color clr, const int fsize = 10)
                                                                                {
                                                                                    if(ObjectFind(0, name) < 0)
                                                                                    {
                                                                                        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
                                                                                        ObjectSetInteger(0, name, OBJPROP_CORNER, g_corner);
                                                                                        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
                                                                                        ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
                                                                                        ObjectSetInteger(0, name, OBJPROP_ZORDER, 1);
                                                                                        ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
                                                                                    }
   //--- anchor sesuai corner
                                                                                    ENUM_ANCHOR_POINT anc = ANCHOR_LEFT_UPPER;
                                                                                    if(g_corner == CORNER_RIGHT_UPPER) anc = ANCHOR_LEFT_UPPER;
                                                                                    if(g_corner == CORNER_LEFT_UPPER) anc = ANCHOR_LEFT_UPPER;
                                                                                    if(g_corner == CORNER_RIGHT_LOWER) anc = ANCHOR_LEFT_LOWER;
                                                                                    if(g_corner == CORNER_LEFT_LOWER) anc = ANCHOR_LEFT_LOWER;
                                                                                    ObjectSetInteger(0, name, OBJPROP_ANCHOR, anc);
                                                                                    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
                                                                                    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
                                                                                    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fsize);
                                                                                    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
                                                                                    ObjectSetString(0, name, OBJPROP_TEXT, text);
                                                                                }

//+------------------------------------------------------------------+
//| Dashboard                                                        |
//| TF | Trend F4 | Bull % | Bear % | Match | Signal | Hit% (n) | Acc% |
//+------------------------------------------------------------------+
                                                                                void DrawDashboard()
                                                                                {
   //--- ukuran panel
                                                                                    const int panelW = 545;
                                                                                    const int margin = 10;
                                                                                    const int rowH = 22;
                                                                                    const int y0 = 15;
                                                                                    const int yh = y0 + 30;
                                                                                    const int yRecSep = yh + 22 + TF_COUNT * rowH + 6;   // label pemisah blok rekomendasi entry
                                                                                    const int yRecStart = yRecSep + 14;                      // baris pertama rekomendasi (per TF)
                                                                                    const int recRowH = 16;
                                                                                    const int yf = yRecStart + TF_COUNT * recRowH + 10;      // footer, di bawah blok rekomendasi
                                                                                    const int panelH = (yf + 50) - y0;

   //--- apakah corner kiri atau kanan
                                                                                    bool isLeft = (g_corner == CORNER_LEFT_UPPER || g_corner == CORNER_LEFT_LOWER);
                                                                                    bool isLower = (g_corner == CORNER_RIGHT_LOWER || g_corner == CORNER_LEFT_LOWER);

   //--- posisi kolom (offset dari tepi kiri panel)
   //    kolom: TF, Trend F4, Bull%, Bear%, Match, Signal, Hit%(n), Acc%
                                                                                    int co[8];
                                                                                    co[0] = 10; co[1] = 55; co[2] = 160; co[3] = 220;
                                                                                    co[4] = 280; co[5] = 335; co[6] = 395; co[7] = 490;

   //--- konversi ke koordinat X absolut sesuai corner
   //    Untuk CORNER_RIGHT_*: X = jarak dari tepi kanan = panelW + margin - co[]
   //    Untuk CORNER_LEFT_*:  X = jarak dari tepi kiri  = margin + co[]
                                                                                    int xs[8];
                                                                                    for(int q = 0; q < 8; q++)
                                                                                    {
                                                                                        if(isLeft)
                                                                                        xs[q] = margin + co[q];
                                                                                        else
                                                                                        xs[q] = panelW + margin - co[q];
                                                                                    }

   //--- posisi X untuk title dan footer
                                                                                    int xTitle = isLeft ? (margin + co[0]) : (panelW + margin - co[0]);
                                                                                    int xFooter = xTitle;

   //--- posisi X dan Y untuk background rectangle
                                                                                    int bgX = margin;
                                                                                    int bgY = y0;

                                                                                    string hd[8];
                                                                                    hd[0] = "TF"; hd[1] = "Trend F4"; hd[2] = "Bull % "; hd[3] = "Bear % ";
                                                                                    hd[4] = "Match"; hd[5] = "Signal"; hd[6] = "Hit % (n)"; hd[7] = "Acc % ";

                                                                                    CreateRect(PREFIX + "BG", bgX, bgY, panelW, panelH);
                                                                                    SetLabel(PREFIX + "TITLE", xTitle, y0 + 6, "KNN WAVE MTF DASHBOARD", clrGold, 10);
                                                                                    for(int q = 0; q < 8; q++)
                                                                                    SetLabel(PREFIX + "H" + IntegerToString(q), xs[q], yh, hd[q], clrSilver, 9);

                                                                                    for(int i = 0; i < TF_COUNT; i++)
                                                                                    {
                                                                                        int y = yh + 22 + i * rowH;
                                                                                        string r = PREFIX + "R" + IntegerToString(i) + "_";

                                                                                        if(CheckPointer(g_engine[i]) == POINTER_INVALID || !g_engine[i].IsReady())
                                                                                        {
                                                                                            SetLabel(r + "0", xs[0], y, TFToString(g_tfs[i]), clrWhite, 10);
                                                                                            for(int k = 1; k < 8; k++)
                                                                                            SetLabel(r + IntegerToString(k), xs[k], y, (k == 5 ? "LOAD" : "..."), clrGray, 10);
                                                                                            continue;
                                                                                        }

                                                                                        double bull = g_engine[i].GetBull();
                                                                                        double bear = g_engine[i].GetBear();
                                                                                        double f4 = g_engine[i].GetTrend();
                                                                                        double mt = g_engine[i].GetMatch();
                                                                                        int sg = g_engine[i].GetSignal();

                                                                                        string sig = "WAIT";
                                                                                        color sc = clrGray;
                                                                                        if(sg == 1) { sig = "BUY"; sc = clrLime; }
                                                                                            else if(sg == - 1) { sig = "SELL"; sc = clrRed; }

                                                                                                string trend = ((f4 >= 0.0) ? "UP " : "DOWN ") + DoubleToString(f4, 2);
                                                                                                color tcol = (f4 >= 0.0) ? clrLimeGreen : clrTomato;
                                                                                                color cBull = (bull >= g_thr) ? clrLime : clrLightGray;
                                                                                                color cBear = (bear >= g_thr) ? clrRed : clrLightGray;

                                                                                                string mtTxt = "n / a";
                                                                                                color mtCol = clrGray;
                                                                                                if(mt >= 0.0)
                                                                                                {
                                                                                                    mtTxt = DoubleToString(mt, 0) + " % ";
                                                                                                    mtCol = (mt >= 50.0) ? clrLimeGreen : ((mt >= 20.0) ? clrGold : clrTomato);
                                                                                                }

                                                                                                int nS = 0, nA = 0;
                                                                                                double hS = g_engine[i].GetLiveSigHit(nS);
                                                                                                double hA = g_engine[i].GetLiveAcc(nA);
                                                                                                string hitTxt = (nS > 0) ? (DoubleToString(hS, 0) + " % (" + IntegerToString(nS) + ")") : " - ";
                                                                                                color hitCol = clrGray;
                                                                                                if(nS >= 10) hitCol = (hS >= 55.0) ? clrLime : ((hS < 45.0) ? clrTomato : clrLightGray);
                                                                                                string accTxt = (nA > 0) ? (DoubleToString(hA, 1) + " % ") : " - ";
                                                                                                color accCol = clrGray;
                                                                                                if(nA >= 20) accCol = (hA >= 55.0) ? clrLime : ((hA < 45.0) ? clrTomato : clrLightGray);

                                                                                                SetLabel(r + "0", xs[0], y, g_engine[i].GetTFName(), clrWhite, 10);
                                                                                                SetLabel(r + "1", xs[1], y, trend, tcol, 10);
                                                                                                SetLabel(r + "2", xs[2], y, DoubleToString(bull, 1) + " % ", cBull, 10);
                                                                                                SetLabel(r + "3", xs[3], y, DoubleToString(bear, 1) + " % ", cBear, 10);
                                                                                                SetLabel(r + "4", xs[4], y, mtTxt, mtCol, 10);
                                                                                                SetLabel(r + "5", xs[5], y, sig, sc, 10);
                                                                                                SetLabel(r + "6", xs[6], y, hitTxt, hitCol, 10);
                                                                                                SetLabel(r + "7", xs[7], y, accTxt, accCol, 10);
                                                                                            }

   //--- rekomendasi Entry/SL/TP self-learning (dari statistik move/MAE K tetangga), satu baris per TF.
   //--- Sekarang tetap muncul walau Trend & Signal tidak selaras - tapi diberi label tier
   //--- (Selaras/Non-Selaras) + Hit% live tier tsb, supaya Anda lihat sendiri buktinya.
                                                                                            SetLabel(PREFIX + "RSEP", xTitle, yRecSep, "-- REKOMENDASI ENTRY (SELF-LEARNING) --", clrSilver, 8);
                                                                                            int digitsAll = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
                                                                                            for(int i = 0; i < TF_COUNT; i++)
                                                                                            {
                                                                                                int yr = yRecStart + i * recRowH;
                                                                                                string rl = PREFIX + "REC" + IntegerToString(i);
                                                                                                double entry = 0.0, sl = 0.0, tp = 0.0, slAtr = 0.0, tpAtr = 0.0, rr = 0.0, tierPct = 0.0;
                                                                                                bool aligned = false;
                                                                                                int tierN = 0;
                                                                                                bool haveRec = (CheckPointer(g_engine[i]) != POINTER_INVALID) && g_engine[i].IsReady() &&
                                                                                                g_engine[i].GetTradeLevels(entry, sl, tp, slAtr, tpAtr, rr, aligned, tierPct, tierN);
                                                                                                if(!haveRec)
                                                                                                {
                                                                                                    SetLabel(rl, xTitle, yr, TFToString(g_tfs[i]) + ": - (menunggu sinyal)", clrGray, 8);
                                                                                                    continue;
                                                                                                }
                                                                                                int sgi = g_engine[i].GetSignal();
                                                                                                string dirTxt = (sgi == 1) ? "BUY" : "SELL";
                                                                                                color dirCol = (sgi == 1) ? clrLime : clrRed;
                                                                                                string tierTxt = aligned ? "Selaras" : "NonSelaras";
                                                                                                string tierStat = (tierN >= 10) ? (DoubleToString(tierPct, 0) + "%/" + IntegerToString(tierN)) : ("n/a," + IntegerToString(tierN));
                                                                                                string line = TFToString(g_tfs[i]) + " " + dirTxt + " (" + tierTxt + " " + tierStat + ")" +
                                                                                                "  Entry " + DoubleToString(entry, digitsAll) +
                                                                                                "  SL " + DoubleToString(sl, digitsAll) + " (" + DoubleToString(slAtr, 1) + "A)" +
                                                                                                "  TP " + DoubleToString(tp, digitsAll) + " (" + DoubleToString(tpAtr, 1) + "A)" +
                                                                                                "  RR 1:" + DoubleToString(rr, 1);
                                                                                                SetLabel(rl, xTitle, yr, line, dirCol, 8);
                                                                                            }

                                                                                            string f1 = "H = " + IntegerToString(g_horizon) + " bar | gerak min " + DoubleToString(g_minMove, 2) +
                                                                                            " ATR | K = " + IntegerToString(g_k) + " | ambang " + DoubleToString(g_thr, 0) + " % ";
                                                                                            string f2 = "Walk - forward acc: ";
                                                                                            for(int t = 0; t < TF_COUNT; t++)
                                                                                            {
                                                                                                int nW = 0;
                                                                                                double aW = - 1.0;
                                                                                                if(CheckPointer(g_engine[t]) != POINTER_INVALID) aW = g_engine[t].GetWFAcc(nW);
                                                                                                string part = (nW > 0) ? (DoubleToString(aW, 0) + " % ") : " - ";
                                                                                                f2 += TFToString(g_tfs[t]) + " " + part;
                                                                                                if(t < TF_COUNT - 1) f2 += " | ";
                                                                                            }
                                                                                            SetLabel(PREFIX + "F1", xFooter, yf, f1, clrSilver, 8);
                                                                                            SetLabel(PREFIX + "F2", xFooter, yf + 16, f2, clrSilver, 8);
                                                                                            string f3 = "Walk-forward Exp/PnL: ";
                                                                                            for(int t = 0; t < TF_COUNT; t++)
                                                                                            {
                                                                                                if(CheckPointer(g_engine[t]) != POINTER_INVALID)
                                                                                                {
                                                                                                    double expV = g_engine[t].GetWFExpectancy();
                                                                                                    double pnlV = g_engine[t].GetWFProfit();
                                                                                                    int nT = g_engine[t].GetWFTradeCount();
                                                                                                    f3 += TFToString(g_tfs[t]) + " " + ((nT > 0) ? (DoubleToString(expV, 2) + "(" + DoubleToString(pnlV, 1) + ")") : "-");
                                                                                                }
                                                                                                else f3 += TFToString(g_tfs[t]) + " -";
                                                                                                if(t < TF_COUNT - 1) f3 += " | ";
                                                                                            }
                                                                                            SetLabel(PREFIX + "F3", xFooter, yf + 32, f3, clrSilver, 8);

                                                                                            ChartRedraw(0);
                                                                                        }

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
                                                                                        int OnInit()
                                                                                        {
                                                                                            for(int i = 0; i < TF_COUNT; i++) g_engine[i] = NULL;

   //--- set corner dari input
                                                                                            switch(InpDashCorner)
                                                                                            {
                                                                                                case CORNER_LT: g_corner = CORNER_LEFT_UPPER; break;
                                                                                                case CORNER_RB: g_corner = CORNER_RIGHT_LOWER; break;
                                                                                                case CORNER_LB: g_corner = CORNER_LEFT_LOWER; break;
                                                                                                default: g_corner = CORNER_RIGHT_UPPER; break;
                                                                                            }

                                                                                            g_horizon = MathMax(1, MathMin(InpHorizon, 30));
                                                                                            g_minMove = MathMax(0.0, InpMinMoveATR);
                                                                                            g_k = MathMax(1, InpK);
                                                                                            g_thr = InpThreshold;

                                                                                            int lb = MathMax(300, InpLookback);
                                                                                            int cap = MathMax(lb, InpMaxMemory);

                                                                                            for(int i = 0; i < TF_COUNT; i++)
                                                                                            {
                                                                                                g_engine[i] = new CKNN_Engine();
                                                                                                if(CheckPointer(g_engine[i]) == POINTER_INVALID ||
                                                                                                !g_engine[i].InitEngine(_Symbol, g_tfs[i], lb, g_k, g_horizon, g_minMove, cap,
                                                                                                g_thr, InpWFSamples, InpPersist))
                                                                                                {
                                                                                                    Print("[ERR] KNN_Wave_MTF_Dashboard_v2: inisialisasi engine gagal pada TF ", TFToString(g_tfs[i]));
                                                                                                    for(int j = 0; j < TF_COUNT; j++)
                                                                                                    if(CheckPointer(g_engine[j]) == POINTER_DYNAMIC) { delete g_engine[j]; g_engine[j] = NULL; }
                                                                                                        return INIT_FAILED;
                                                                                                    }

                                                                                                // parameter regime & filter kualitas per engine
                                                                                                g_engine[i].SetSignalFilters(InpMinMatch, InpMaxSpreadPips, InpMaxAvgDist);
                                                                                                int erP = InpERPeriod, hurstW = InpHurstWindow;
                                                                                                switch(g_tfs[i])
                                                                                                {
                                                                                                    case PERIOD_M5:  erP = (int)(InpERPeriod * 0.5);  hurstW = (int)(InpHurstWindow * 0.5);  break;
                                                                                                    case PERIOD_M15: erP = (int)(InpERPeriod * 0.75); hurstW = (int)(InpHurstWindow * 0.75); break;
                                                                                                    case PERIOD_H4:  erP = (int)(InpERPeriod * 1.5);  hurstW = (int)(InpHurstWindow * 1.5);  break;
                                                                                                    case PERIOD_D1:  erP = (int)(InpERPeriod * 2.0);  hurstW = (int)(InpHurstWindow * 2.0);  break;
                                                                                                }
                                                                                                g_engine[i].SetERPeriod(erP);
                                                                                                g_engine[i].SetHurstWindow(hurstW);
                                                                                                }

                                                                                                EventSetTimer(3);
                                                                                                DrawDashboard(); // tampilkan panel(status LOAD) sebelum warm - up selesai
                                                                                                return INIT_SUCCEEDED;
                                                                                            }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
                                                                                            void OnDeinit(const int reason)
                                                                                            {
                                                                                                EventKillTimer();
                                                                                                for(int i = 0; i < TF_COUNT; i++)
                                                                                                if(CheckPointer(g_engine[i]) == POINTER_DYNAMIC)
                                                                                                {
                                                                                                    g_engine[i].ReleaseHandles();
                                                                                                    delete g_engine[i];
                                                                                                    g_engine[i] = NULL;
                                                                                                }
                                                                                                ObjectsDeleteAll(0, PREFIX);
                                                                                                ChartRedraw(0);
                                                                                            }

//+------------------------------------------------------------------+
//| OnCalculate (sengaja kosong)                                     |
//+------------------------------------------------------------------+
                                                                                            int OnCalculate(const int rates_total,
                                                                                            const int prev_calculated,
                                                                                            const datetime &time[],
                                                                                            const double &open[],
                                                                                            const double &high[],
                                                                                            const double &low[],
                                                                                            const double &close[],
                                                                                            const long &tick_volume[],
                                                                                            const long &volume[],
                                                                                            const int &spread[])
                                                                                            {
                                                                                                return rates_total;
                                                                                            }

//+------------------------------------------------------------------+
//| OnTimer: learning + KNN + GUI                                    |
//+------------------------------------------------------------------+
                                                                                            void OnTimer()
                                                                                            {
                                                                                                for(int i = 0; i < TF_COUNT; i++)
                                                                                                if(CheckPointer(g_engine[i]) == POINTER_DYNAMIC)
                                                                                                g_engine[i].Update();
                                                                                                DrawDashboard();
                                                                                            }
//+------------------------------------------------------------------+