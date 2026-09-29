================================================================================
PANDUAN LENGKAP TRADING MANUAL
MENGGUNAKAN INDIKATOR
KNN_Wave_MTF_Dashboard_v2.52.mq5
================================================================================
Versi panduan : 1.00
Indikator     : KNN_Wave_MTF_Dashboard_v2.52.mq5
Author kode   : Timesynctrading.com / public-omon-omon
Tujuan        : Trading manual berbasis probabilitas KNN multi-timeframe
================================================================================

--------------------------------------------------------------------------------
1. APa ITU INDIKATOR INI?
--------------------------------------------------------------------------------
Indikator ini menampilkan dashboard probabilitas arah harga (Bullish/Bearish)
berbasis algoritma K-Nearest Neighbors (KNN) pada 5 timeframe:

   M5 -> M15 -> H1 -> H4 -> D1

Setiap timeframe menghitung:
   - Probabilitas harga akan naik (Bull %) dan turun (Bear %) dalam N bar ke depan.
   - Kecocokan pola sekarang dengan histori (Match %).
   - Signal BUY / SELL / WAIT.
   - Statistik performa sinyal live (Hit % dan Acc %).
   - Hasil walk-forward backtest (Exp / PnL).
   - Rekomendasi Entry, SL, TP, dan rasio Reward:Risk (RR).

Indikator bersifat probabilitas, BUKAN prediksi pasti. Gunakan sebagai
filter arah, bukan sebagai sinyal otomatis.

--------------------------------------------------------------------------------
2. CARA INSTALL
--------------------------------------------------------------------------------
1. Buka MetaTrader 5.
2. Menu File -> Open Data Folder (Buka Folder Data).
3. Masuk ke folder: MQL5\Indicators\
4. Copy file KNN_Wave_MTF_Dashboard_v2.52.mq5 ke folder tersebut.
5. Buka MetaEditor (toolbar atau F4).
6. Di Navigator, klik kanan KNN_Wave_MTF_Dashboard_v2.52.mq5 -> Compile.
7. Kembali ke MT5. Di Navigator -> Indicators -> Custom, drag indikator ke chart.
8. Atur input sesuai kebutuhan (lihat Bagian 4), lalu OK.

Tunggu beberapa detik sampai kolom dashboard berubah dari "LOAD / ..."
menjadi angka/sinyal. Proses warm-up membutuhkan data historis yang cukup.

--------------------------------------------------------------------------------
3. TAMPILAN DASHBOARD
--------------------------------------------------------------------------------
Dashboard menampilkan tabel utama dan blok rekomendasi entry.

3.1 TABEL UTAMA
--------------------------------------------------------------------------------
| TF  | Trend F4 | Bull % | Bear % | Match | Signal | Hit % (n) | Acc % |
--------------------------------------------------------------------------------

Kolom:

   TF        : Timeframe (M5, M15, H1, H4, D1).

   Trend F4  : Arah trend dari fitur F4 (macro wave).
                 UP  -> harga sedang uptrend (nilai positif).
                 DOWN -> harga sedang downtrend (nilai negatif).
                 Angka di belakangnya = kekuatan trend.

   Bull %    : Probabilitas harga naik dalam horizon bar.
   Bear %    : Probabilitas harga turun dalam horizon bar.

   Match %   : Seberapa mirip kondisi sekarang dengan pola historis terdekat.
               Semakin tinggi, semakin confident pola yang ditemukan.
               Warna: hijau (>=50), kuning (20-50), merah (<20).

   Signal    : Output sinyal dari KNN.
               BUY  (hijau)  -> probabilitas Bull >= threshold.
               SELL (merah)  -> probabilitas Bear >= threshold.
               WAIT (abu)    -> belum ada sinyal kuat.

   Hit % (n) : Persentase sinyal live yang berhasil (hit/miss).
               n = jumlah sampel yang sudah terekam.
               Warna hijau jika n>=10 dan Hit > 50%.

   Acc %     : Akurasi semua prediksi (Bull+Bear), bukan hanya yang jadi sinyal.
               n = jumlah sampel.
               Warna hijau jika n>=20 dan Acc > 55%.

3.2 BLOK REKOMENDASI ENTRY
--------------------------------------------------------------------------------
-- REKOMENDASI ENTRY (SELF-LEARNING) --
M5  BUY  (Selaras 67%/12)   Entry 2650.120  SL 2648.340 (1.2A)  TP 2653.210 (2.1A)  RR 1:1.8
M15 SELL (NonSelaras n/a,5) Entry 2649.550  SL 2651.200 (1.5A)  TP 2645.100 (2.0A)  RR 1:1.3
...

Penjelasan per baris:

   TF          : Timeframe sinyal.
   BUY/SELL    : Arah sinyal (warna hijau/merah).
   Selaras     : Trend F4 searah dengan sinyal.
   NonSelaras  : Trend F4 berlawanan dengan sinyal.
   67%/12      : Hit rate tier saat ini = 67% dari 12 sampel.
   n/a,5       : Sampel belum cukup (kurang dari 10), baru 5 sampel.
   Entry       : Harga entry rekomendasi (Bid/Ask saat ini).
   SL          : Stop Loss dalam harga dan ATR (A = ATR).
   TP          : Take Profit dalam harga dan ATR.
   RR          : Rasio Reward:Risk.

Catatan penting:
   - Rekomendasi entry muncul hanya jika Signal != WAIT.
   - Tier "Selaras" / "Non-Selaras" dipisah; amati Hit% live masing-masing.
     Jika pada pair/TF Anda tier Non-Selaras justru lebih baik, itu data nyata,
     bukan asumsi. Indikator membiarkan bukti statistik berbicara.

3.3 FOOTER
--------------------------------------------------------------------------------
H = 3 bar | gerak min 0.50 ATR | K = 21 | ambang 70 %
Walk-forward acc: M5 58 % | M15 62 % | H1 55 % | H4 - | D1 -
Walk-forward Exp/PnL: M5 0.45(12.3) | M15 0.60(8.1) | H1 - | H4 - | D1 -

   H                : Horizon prediksi (berapa bar ke depan).
   gerak min        : Gerakan minimum agar dianggap Bull/Bear (dalam ATR).
   K                : Jumlah tetangga terdekat yang dipakai KNN.
   ambang           : Threshold probabilitas untuk trigger sinyal.
   Walk-forward acc : Akurasi out-of-sample per TF.
   Exp              : Expectancy rata-rata per trade.
   PnL              : Profit/loss kumulatif walk-forward (dalam ATR).

--------------------------------------------------------------------------------
4. INPUT / PARAMETER
--------------------------------------------------------------------------------
Berikut parameter penting yang bisa diubah saat attach indikator:

   InpDashCorner     : Posisi dashboard (Kanan Atas default).
   InpLookback       : Bar historis untuk warm-up (default 1500).
   InpMaxMemory      : Kapasitas memori pola maksimum (default 3000).
   InpK              : Jumlah tetangga KNN (default 21).
   InpHorizon        : Target prediksi N bar ke depan (default 3).
   InpMinMoveATR     : Gerak minimum agar pola dianggap Bull/Bear (default 0.5 ATR).
   InpThreshold      : Ambang probabilitas sinyal (default 70%).
   InpWFSamples      : Sampel walk-forward (default 250).
   InpPersist        : Simpan memori & statistik ke file (true).

   Notifikasi:
   InpAlertPopup, InpAlertPush, InpAlertEmail, InpAlertSound
   (notifikasi dikirim hanya saat tier sinyal sudah terbukti lebih baik dari
    tebakan acak, bukan setiap perubahan kecil).

   Rekomendasi SL/TP:
   InpSLBufferMult   : Buffer keamanan di atas MAE historis (default 1.2 = +20%).
   InpSLMinATR       : Jarak SL minimum dalam ATR (default 0.3).

--------------------------------------------------------------------------------
5. ATURAN TRADING MANUAL
--------------------------------------------------------------------------------
5.1 FILTER WAJIB SEBELUM ENTRY
--------------------------------------------------------------------------------
JANGAN entry hanya karena muncul signal BUY/SELL. Wajib periksa:

   [1] Signal BUY/SELL sudah muncul.
   [2] Match % >= 50 (ideal). Minimum 20.
   [3] Hit % (n) tersedia dan n >= 10, lebih baik jika > 50%.
   [4] Acc % untuk TF tersebut tersedia dan n >= 20, lebih baik > 55%.
   [5] Walk-forward acc/exp positif untuk TF yang akan dijadikan acuan.
   [6] Spread normal; hindari entry saat spread melebar (news, low liquidity).

5.2 PILIH TIMEFRAME UTAMA (TF ENTRY)
--------------------------------------------------------------------------------
Gunakan konsep top-down:

   - Trend besar : lihat H4 / D1 untuk arah dominan.
   - Konfirmasi  : lihat H1 apakah searah trend besar.
   - Entry       : gunakan M15 / M5 untuk timing entry dan rekomendasi SL/TP.

Prioritas setup (dari terbaik):

   A. H4/H1/D1 menunjukkan arah yang sama, lalu M15/M5 memberi signal searah.
      -> Entry kuat.
   B. Minimal 2 timeframe berurutan (misal H1 dan M15) searah.
      -> Entry standar.
   C. Hanya 1 TF memberi signal, TF lain WAIT.
      -> Entry lemah / tunggu konfirmasi candle berikutnya.
   D. Signal muncul melawan trend H4/H1.
      -> Hindari kecuali tier Non-Selaras pada TF entry menunjukkan Hit% tinggi
         dan Anda trading pullback counter-trend dengan size kecil.

5.3 ENTRY
--------------------------------------------------------------------------------
Setelah filter lolos:

   1. Perhatikan blok REKOMENDASI ENTRY pada TF entry yang dipilih.
   2. Entry bisa dilakukan di harga market saat ini (Bid untuk SELL, Ask untuk BUY).
   3. Atau tunggu pullback ke harga Entry yang ditampilkan jika harga belum
      terlalu jauh.
   4. Pastikan jarak SL sesuai risk tolerance Anda. Jika SL terlalu lebar,
      kurangi lot atau skip trade.

5.4 STOP LOSS & TAKE PROFIT
--------------------------------------------------------------------------------
Gunakan rekomendasi dari dashboard sebagai acuan:

   SL  = sesuai blok rekomendasi (biasanya rata-rata MAE historis + buffer).
   TP  = sesuai blok rekomendasi (rata-rata pergerakan aktual searah).
   RR  = minimal 1:1.5 untuk reward:risk.

Opsional:
   - Jika harga bergerak 50% menuju TP, pindahkan SL ke Breakeven.
   - Bisa partial close 50% di TP1, sisakan runner ke TP2.

5.5 MANAJEMEN RISIKO
--------------------------------------------------------------------------------
   - Risk per trade maksimal 1% - 2% dari equity.
   - Gunakan position size calculator berdasarkan SL dalam pips/dollar.
   - Max open position simultan: 3-5 setup agar tidak overexposure.
   - Daily loss limit: 3% - 5% dari equity -> stop trading hari itu.
   - Jika floating loss kolektif mendekati daily loss limit, CLOSE ALL manual.
   - Hindakan news besar (NFP, FOMC, CPI) 30 menit sebelum & sesudah.

5.6 KAPAN TIDAK TRADING
--------------------------------------------------------------------------------
   - Semua TF menunjukkan WAIT.
   - Match % merah (<20) di semua TF.
   - Spread melebar > 2x normal.
   - Harga dalam kondisi choppy/ranging tanpa arah jelas (Trend F4 mendekati 0).
   - Akun dalam drawdown harian yang sudah mencapai batas.

--------------------------------------------------------------------------------
6. CONTOH WORKFLOW TRADING HARIAN
--------------------------------------------------------------------------------
Langkah-langkah praktis:

   1. Buka chart XAUUSD M15. Attach indikator KNN Wave MTF Dashboard v2.52.
   2. Tunggu dashboard load.
   3. Cek H4: Trend F4 UP -> arah dominan bullish.
   4. Cek H1: Trend F4 UP -> konfirmasi bullish.
   5. Cek M15: muncul Signal BUY, Match 68%, Hit 62%(n=15), Acc 58%(n=25).
   6. Cek blok rekomendasi M15:
        Entry 2650.10, SL 2648.50 (1.2A), TP 2653.20 (2.0A), RR 1:1.8.
   7. Hitung lot size agar risiko = 1% equity jika SL tercapai.
   8. Entry BUY di market atau limit di 2650.10.
   9. Pasang SL 2648.50 dan TP 2653.20.
  10. Monitor. Jika harga naik 50% ke TP, pindahkan SL ke Breakeven.
  11. Jika SL tercapai, catat loss dan evaluasi setup di jurnal trading.

--------------------------------------------------------------------------------
7. TIPS & PITFALLS
--------------------------------------------------------------------------------
   - Jangan "chase" harga yang sudah terlalu jauh dari entry rekomendasi.
   - Jika signal muncul bertepatan dengan tier Non-Selaras, perhatikan Hit% nya.
     Jika Hit% Non-Selaras lebih tinggi dari Selaras di pair tersebut,
     sinyal tersebut tetap bisa dipertimbangkan.
   - Indikator belajar dari data historis; performa di masa lalu tidak
     menjamin performa di masa depan.
   - Walk-forward dengan sample kecil (n < 30) masih kurang reliable.
   - Backtest manual di demo account minimal 1-2 minggu sebelum pakai live.

--------------------------------------------------------------------------------
8. DISCLAIMER
--------------------------------------------------------------------------------
Indikator ini dibuat untuk membantu analisis, BUKAN rekomendasi investasi.
Trading forex/emas/derivatif memiliki risiko tinggi termasuk kehilangan
seluruh modal. Gunakan manajemen risiko yang ketat. Hasil backtest dan
statistik historis tidak menjamin hasil di masa depan.

================================================================================
Selamat trading!
================================================================================
