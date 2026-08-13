//+------------------------------------------------------------------+
//|                                SimpleML_3Phase_EA.mq5            |
//|              Adaptive ML-Style Entry with CSV Knowledge Base     |
//|                 MA-MTF + Stochastic + Volume + Learning          |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, Paulus / Lybeedo"
#property link        ""
#property version     "1.00"
#property description "3-Phase EA: Entry(ML-style) -> Review(Virt SL/TP) -> Learn(CSV)"
#property strict

//+------------------------------------------------------------------+
//| INPUT PARAMETERS — ALL SEASON-PROOF ADJUSTABLE                   |
//+------------------------------------------------------------------+
input group "=== INDICATOR: MA MTF TREND ==="
input int    InpMABaseTF    = 240;              // MA Base TF Minutes (5,15,30,60,240)
input int    InpMAFast      = 10;               // MA Fast Period
input int    InpMASlow      = 50;               // MA Slow Period
input ENUM_MA_METHOD InpMAMethod  = MODE_EMA;   // MA Method
input int    InpHTFShift    = 0;              // MA HTF Offset Bars (for confirmation delay)

input group "=== INDICATOR: STOCHASTIC TRIGGER ==="
input int    InpStochK      = 14;               // Stoch %K Period
input int    InpStochD      = 3;                // Stoch %D Smoothing
input int    InpStochSlowing= 3;              // Stoch Slowing
input int    InpStochOverSold = 20;            // Overbought Level
input int    InpStochOverBought= 80;          // Oversold Level

input group "=== INDICATOR: VOLUME FILTER ==="
input double InpVolMult     = 1.5;             // Volume Multiplier (vol > SMA*Mult required)
input int    InpVolSMA      = 20;               // Volume SMA Period

input group "=== FEATURE VECTOR (7 FITUR) ==="
input int    InpATRPeriod   = 14;               // ATR Period for regime bucket
input int    InpVolumeSMA   = 20;               // Volume SMA for ratio calculation
input int    InpSessionMask = 0xF;             // 1=Asia,2=London,4=NY,8=Sydney

input group "=== CONFIDENCE / KNOWLEDGE BASE ==="
input double InpMinConf     = 0.55;            // Minimum Confidence (0.0 - 1.0)
input int    InpMinSamples  = 5;               // Minimum samples per regime for validity
input int    InpMaxRegimes  = 64;              // Max regimes tracked (power of 2)
input int    InpWinBucket   = 10;              // Win-rate bucket size (%)
input double InpSamplePenalty= 0.1;           // Confidence penalty per missing sample

input group "=== TRADE MANAGEMENT (VIRTUAL) ==="
input bool   InpVirtualSL   = true;            // Use Virtual SL (no OrderModify)
input int    InpSLPoints    = 300;             // SL in Points
input int    InpTPPoints    = 600;            // TP in Points
input int    InpTrailingStart= 150;           // Trailing activation (points profit)
input int    InpTrailingStep = 50;            // Trailing step (points)
input double InpLotSize     = 0.01;            // Fixed Lot Size
input double InpRiskPct     = 1.0;            // Risk % of Equity (fallback)
input bool   InpUseEqRisk   = true;            // Use % Equity Risk (overrides fixed lot)

input group "=== SYMBOL & MAGIC ==="
input string InpSymbol      = "";             // "" = current symbol
input int    InpMagic       = 20260813;       // Magic Number (unique per EA)
input int    InpMaxPositions= 1;              // Max concurrent positions
input int    InpMaxSpread   = 30;             // Max spread (points) allowed

input group "=== LEARNING / CSV ==="
input string InpKnowledgeFile= "SimpleML_kb.csv"; // Knowledge base filename (FILE_COMMON)
input bool   InpAutoLearn   = true;            // Enable auto-learning on close

//+------------------------------------------------------------------+
//| INCLUDES                                                         |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Arrays\ArrayObj.mqh>
#include <Arrays\ArrayInt.mqh>

//+------------------------------------------------------------------+
//| STRUCTURES                                                       |
//+------------------------------------------------------------------+
struct TRegimeStats {
   int    regime_id;
   int    wins;
   int    losses;
   int    total;
   double win_rate;
   double confidence;
};

struct TPosData {
   ulong  ticket;
   int    direction;   // 1=BUY, -1=SELL
   double open_price;
   double virtual_sl;
   double virtual_tp;
   double virtual_trail;
   datetime open_time;
   bool   trail_active;
   double feature_hash;
};

struct TFeatureVec {
   double fast_gap_pct;
   double htf_slope;
   double stoch_k;
   int    stoch_dir;    // 1=up_cross, -1=down_cross, 0=none
   double vol_ratio;
   double atr_regime;   // current ATR / long ATR avg
   int    session;      // 0=Asia,1=London,2=NY,3=Sydney
};

//+------------------------------------------------------------------+
//| GLOBALS                                                          |
//+------------------------------------------------------------------+
CTrade        g_trade;
CPositionInfo g_pos;
COrderInfo    g_ord;

string        g_sym;
int           g_digits;
double        g_point;
double        g_tick_val;
long          g_magic;
int           g_max_spread_pts;

TRegimeStats  g_regimes[];
int           g_regime_count;
int           g_total_trades;
int           g_total_wins;
int           g_total_losses;

TPosData      g_positions[];
int           g_pos_count;

string        g_kb_path;
int           g_file_handle;
bool          g_kb_loaded;

//+------------------------------------------------------------------+
//| UTILITY FUNCTIONS                                                 |
//+------------------------------------------------------------------+
double Sma(const string sym, ENUM_TIMEFRAMES tf, int period, int applied, int shift) {
   double arr[];
   ArraySetAsSeries(arr, true);
   int h = iMA(sym, tf, period, 0, (ENUM_MA_METHOD)applied, shift);
   if(h == INVALID_HANDLE) return 0;
   if(CopyBuffer(h, 0, 0, 1, arr) <= 0) { DeleteIndicator(h); return 0; }
   DeleteIndicator(h);
   return arr[0];
}

double iSMA(const string sym, ENUM_TIMEFRAMES tf, int period, ENUM_APPLIED_PRICE applied, int shift) {
   return iMA(sym, tf, period, 0, MODE_SMA, applied, shift);
}

double GetMA(const string sym, ENUM_TIMEFRAMES tf, int period, ENUM_MA_METHOD method, int shift) {
   double arr[];
   ArraySetAsSeries(arr, true);
   int h = iMA(sym, tf, period, 0, method, shift);
   if(h == INVALID_HANDLE) return 0;
   if(CopyBuffer(h, 0, 0, 1, arr) <= 0) { DeleteIndicator(h); return 0; }
   DeleteIndicator(h);
   return arr[0];
}

double GetSToch(const string sym, ENUM_TIMEFRAMES tf, int k, int d, int slowing, int shift) {
   double arrK[], arrD[];
   ArraySetAsSeries(arrK, true);
   ArraySetAsSeries(arrD, true);
   int h = iStochastic(sym, tf, k, d, slowing, MODE_SMA, 0);
   if(h == INVALID_HANDLE) return 0;
   if(CopyBuffer(h, 0, 0, 1, arrK) <= 0 || CopyBuffer(h, 1, 0, 1, arrD) <= 0) {
      DeleteIndicator(h); return 0;
   }
   DeleteIndicator(h);
   return arrK[0];
}

double GetVolSMA(const string sym, int period, int shift) {
   double arr[];
   ArraySetAsSeries(arr, true);
   if(CopyTickVolume(sym, PERIOD_CURRENT, shift, 1, arr) <= 0) return 0;
   double vol = arr[0];
   if(period <= 1) return vol;
   for(int i = 1; i < period; i++) {
      if(CopyTickVolume(sym, PERIOD_CURRENT, shift + i, 1, arr) <= 0) break;
      vol += arr[0];
   }
   return vol / period;
}

int GetSession() {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int hr = dt.hour;
   // Simplified session: Asia=0-9, London=8-16, NY=13-22, Sydney=20-4(=20-23,0-4)
   if(hr >= 20 || hr < 4)  return 3; // Sydney
   if(hr >= 0  && hr < 9)  return 0; // Asia
   if(hr >= 8  && hr < 16) return 1; // London
   if(hr >= 13 && hr < 22) return 2; // NY
   return 0;
}

double GetATR(const string sym, int period, int shift) {
   double arr[];
   ArraySetAsSeries(arr, true);
   int h = iATR(sym, PERIOD_CURRENT, period);
   if(h == INVALID_HANDLE) return 0;
   if(CopyBuffer(h, 0, 0, 1, arr) <= 0) { DeleteIndicator(h); return 0; }
   DeleteIndicator(h);
   return arr[0];
}

double NormalizePrice(double price) {
   return NormalizeDouble(price, g_digits);
}

double PointsToPrice(int pts) {
   return pts * g_point;
}

int PriceToPoints(double diff) {
   return (int)(MathAbs(diff) / g_point);
}

long GetLotStep() {
   return (long)SymbolInfoInteger(g_sym, SYMBOL_VOLUME_STEP);
}

double GetMinLot() {
   return SymbolInfoDouble(g_sym, SYMBOL_VOLUME_MIN);
}

double GetMaxLot() {
   return SymbolInfoDouble(g_sym, SYMBOL_VOLUME_MAX);
}

double NormalizeLot(double lot) {
   long step = GetLotStep();
   if(step <= 0) step = 1;
   double min_l = GetMinLot();
   double max_l = GetMaxLot();
   if(min_l <= 0) min_l = 0.01;
   if(max_l <= 0 || max_l < min_l) max_l = min_l * 100;
   lot = MathMax(lot, min_l);
   lot = MathMin(lot, max_l);
   lot = MathFloor(lot * step) / step;
   return lot;
}

double GetEquityRiskLot(double riskPct, double slPoints) {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0) return InpLotSize;
   double riskUsd = equity * riskPct / 100.0;
   double tick = SymbolInfoDouble(g_sym, SYMBOL_TRADE_TICK_VALUE);
   if(tick <= 0) return InpLotSize;
   double lot = riskUsd / (slPoints * g_point * tick / g_point);
   return NormalizeLot(lot);
}

string GetSessionName(int sess) {
   switch(sess) {
      case 0: return "Asia";
      case 1: return "London";
      case 2: return "NY";
      case 3: return "Sydney";
      default: return "Unknown";
   }
}

string DoubleToStrPct(double v, int digits=2) {
   return DoubleToString(v * 100.0, digits) + "%";
}

//+------------------------------------------------------------------+
//| REGIME BUCKETIZATION                                               |
//+------------------------------------------------------------------+
int BucketizeFeature(int idx, double val, int buckets) {
   return (int)MathMin(MathMax(MathFloor(val * buckets), 0), buckets - 1);
}

long ComputeRegimeID(const TFeatureVec &f) {
   // 7 features, bucketized into IDs that form a unique regime
   // Stoch K: 4 buckets (0-25, 25-50, 50-75, 75-100)
   int b_k    = (int)MathMin(MathFloor(f.stoch_k / 25.0), 3);
   int b_stdir= (f.stoch_dir > 0) ? 1 : (f.stoch_dir < 0) ? 2 : 0; // up/down/neutral
   int b_sess = f.session;
   int b_vol  = (int)MathMin(MathFloor(f.vol_ratio), 3); // 0-1x, 1-1.5x, 1.5-2x, 2x+
   if(b_vol > 3) b_vol = 3;
   int b_atr  = (int)MathMin(MathFloor(f.atr_regime), 3); // low/norm/high/vhigh
   if(b_atr > 3) b_atr = 3;
   // Fast MA gap direction (sign)
   int b_gap  = (f.fast_gap_pct >= 0) ? 1 : 0;
   // HTF slope sign
   int b_slope= (f.htf_slope >= 0) ? 1 : 0;
   // Combine into a single regime ID
   long rid = 0;
   rid += (long)b_k    * 1;
   rid += (long)b_stdir * 4;
   rid += (long)b_sess  * 16;
   rid += (long)b_vol   * 64;
   rid += (long)b_atr   * 256;
   rid += (long)b_gap   * 1024;
   rid += (long)b_slope * 2048;
   return rid;
}

int FindRegime(long rid) {
   for(int i = 0; i < g_regime_count; i++) {
      if(g_regimes[i].regime_id == rid) return i;
   }
   return -1;
}

void AddRegime(long rid) {
   if(g_regime_count >= InpMaxRegimes) return;
   int idx = g_regime_count++;
   g_regimes[idx].regime_id = rid;
   g_regimes[idx].wins = 0;
   g_regimes[idx].losses = 0;
   g_regimes[idx].total = 0;
   g_regimes[idx].win_rate = 0;
   g_regimes[idx].confidence = 0;
}

double GetRegimeConfidence(long rid) {
   int idx = FindRegime(rid);
   if(idx < 0) return 0;
   TRegimeStats &rs = g_regimes[idx];
   if(rs.total < InpMinSamples) {
      // Penalty: confidence is base 0.5 minus penalty for each missing sample
      double penalty = (double)(InpMinSamples - rs.total) * InpSamplePenalty;
      return MathMax(0.5 - penalty, 0.0);
   }
   rs.win_rate = (double)rs.wins / (double)rs.total;
   // Confidence = win_rate, clamped
   rs.confidence = rs.win_rate;
   return rs.confidence;
}

void UpdateRegime(long rid, bool won) {
   int idx = FindRegime(rid);
   if(idx < 0) {
      AddRegime(rid);
      idx = g_regime_count - 1;
   }
   g_total_trades++;
   if(won) {
      g_regimes[idx].wins++;
      g_total_wins++;
   } else {
      g_regimes[idx].losses++;
      g_total_losses++;
   }
   g_regimes[idx].total++;
}

//+------------------------------------------------------------------+
//| KNOWLEDGE BASE (CSV) PERSISTENCE                                 |
//+------------------------------------------------------------------+
void InitKBPath() {
   g_sym    = (InpSymbol == "") ? _Symbol : InpSymbol;
   g_magic  = (long)InpMagic;
   g_digits = (int)SymbolInfoInteger(g_sym, SYMBOL_DIGITS);
   g_point  = SymbolInfoDouble(g_sym, SYMBOL_POINT);
   g_tick_val = SymbolInfoDouble(g_sym, SYMBOL_TRADE_TICK_VALUE);
   g_max_spread_pts = InpMaxSpread;

   // FILE_COMMON path for cross-chart sharing
   string common = TerminalInfoString(TERMINAL_COMMONDIRECTORY);
   g_kb_path = common + "\\Files\\" + InpKnowledgeFile;
}

bool LoadKB() {
   ResetLastError();
   g_file_handle = FileOpen(g_kb_path, FILE_READ | FILE_TXT | FILE_ANSI);
   if(g_file_handle == INVALID_HANDLE) {
      Print("[SimpleML] KB file not found, will create: ", g_kb_path);
      return false;
   }
   string header = FileReadString(g_file_handle);
   int    line_num = 0;
   while(!FileIsEnding(g_file_handle)) {
      string line = FileReadString(g_file_handle);
      if(StringLen(line) == 0) continue;
      line_num++;
      // Format: timestamp,sym,magic,direction,feature_hash,regime_id,result,p&l_pct
      int comma1 = StringFind(line, ',', 0);
      if(comma1 < 0) continue;
      string ts = StringSubstr(line, 0, comma1);
      int    comma2 = StringFind(line, ',', comma1 + 1);
      if(comma2 < 0) continue;
      string sym = StringSubstr(line, comma1 + 1, comma2 - comma1 - 1);
      int    comma3 = StringFind(line, ',', comma2 + 1);
      if(comma3 < 0) continue;
      string magic_s = StringSubstr(line, comma2 + 1, comma3 - comma2 - 1);
      int    comma4 = StringFind(line, ',', comma3 + 1);
      if(comma4 < 0) continue;
      string dir_s = StringSubstr(line, comma3 + 1, comma4 - comma3 - 1);
      int    comma5 = StringFind(line, ',', comma4 + 1);
      if(comma5 < 0) continue;
      string feat_s = StringSubstr(line, comma4 + 1, comma5 - comma4 - 1);
      int    comma6 = StringFind(line, ',', comma5 + 1);
      if(comma6 < 0) continue;
      string rid_s = StringSubstr(line, comma5 + 1, comma6 - comma5 - 1);
      int    comma7 = StringFind(line, ',', comma6 + 1);
      if(comma7 < 0) continue;
      string result_s = StringSubstr(line, comma6 + 1, comma7 - comma6 - 1);
      // Read the rest as pnl (not needed for regime but good to log)
      
      long magic_l = (long)StringToInteger(magic_s);
      long rid_l   = (long)StringToInteger(rid_s);
      int  dir     = (int)StringToInteger(dir_s);
      string result_str = StringSubstr(line, comma6 + 1, comma7 - comma6 - 1);
      
      if(magic_l == g_magic && sym == g_sym) {
         bool won = (result_str == "1" || result_str == "win" || StringToInteger(result_str) > 0);
         UpdateRegime(rid_l, won);
      }
   }
   FileClose(g_file_handle);
   g_kb_loaded = true;
   Print("[SimpleML] KB loaded: ", g_regime_count, " regimes, ", 
         g_total_wins, "W / ", g_total_losses, "L / ", g_total_trades, " total");
   return true;
}

void AppendKB(const TFeatureVec &f, long rid, int direction, double open_price, 
              double close_price, double pnl_pct, bool won) {
   // Open in append mode
   ResetLastError();
   int handle = FileOpen(g_kb_path, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_READ);
   if(handle == INVALID_HANDLE) {
      // Try create
      handle = FileOpen(g_kb_path, FILE_WRITE | FILE_TXT | FILE_ANSI);
      if(handle == INVALID_HANDLE) {
         Print("[SimpleML] ERROR: Cannot open KB file: ", g_kb_path, " err=", GetLastError());
         return;
      }
      // Write header if new file
      FileWriteString(handle, "timestamp,symbol,magic,direction,feature_hash,regime_id,result,pnl_pct\n");
   } else {
      // Seek to end
      FileSeek(handle, 0, SEEK_END);
      FileClose(handle);
      handle = FileOpen(g_kb_path, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_READ);
      if(handle == INVALID_HANDLE) return;
      FileSeek(handle, 0, SEEK_END);
   }
   
   datetime now = TimeCurrent();
   string ts = TimeToString(now, TIME_DATE | TIME_SECONDS);
   string result = won ? "1" : "0";
   
   FileWriteString(handle, ts + "," + g_sym + "," + (string)g_magic + 
                   "," + (string)direction + "," + 
                   DoubleToString(f.fast_gap_pct, 6) + "," +
                   DoubleToString(f.stoch_k, 4) + "," +
                   (string)f.stoch_dir + "," +
                   (string)f.session + "," +
                   DoubleToString(f.vol_ratio, 4) + "," +
                   DoubleToString(f.atr_regime, 4) + "," +
                   (string)rid + "," + result + "," +
                   DoubleToString(pnl_pct, 4) + "\n");
   FileClose(handle);
}

//+------------------------------------------------------------------+
//| PHASE 1: ENTRY — FEATURE VECTOR + CONFIDENCE CHECK               |
//+------------------------------------------------------------------+
bool ComputeFeatures(TFeatureVec &f) {
   ENUM_TIMEFRAMES base_tf = (ENUM_TIMEFRAMES)InpMABaseTF;
   
   // Feature 1: FastMA-SlowMA gap (%)
   double ma_fast = GetMA(g_sym, base_tf, InpMAFast, InpMAMethod, 0);
   double ma_slow = GetMA(g_sym, base_tf, InpMASlow, InpMAMethod, 0);
   if(ma_fast <= 0 || ma_slow <= 0) return false;
   f.fast_gap_pct = (ma_fast - ma_slow) / ma_slow;
   
   // Feature 2: HTF MA slope (difference between two bars)
   double ma_htf_0 = GetMA(g_sym, base_tf, InpMASlow, InpMAMethod, 0);
   double ma_htf_1 = GetMA(g_sym, base_tf, InpMASlow, InpMAMethod, 1);
   if(ma_htf_0 <= 0 || ma_htf_1 <= 0) return false;
   f.htf_slope = (ma_htf_0 - ma_htf_1) / ma_htf_1;
   
   // Feature 3+4: Stochastic %K and direction
   double stoch_k = GetSToch(g_sym, base_tf, InpStochK, InpStochD, InpStochSlowing, 0);
   double stoch_k_prev = GetSToch(g_sym, base_tf, InpStochK, InpStochD, InpStochSlowing, 1);
   f.stoch_k = stoch_k;
   if(stoch_k_prev > 0 && stoch_k > 0) {
      f.stoch_dir = (stoch_k > stoch_k_prev) ? 1 : -1;
   } else {
      f.stoch_dir = 0;
   }
   
   // Feature 5: Volume ratio
   double vol_now = 0, vol_sma = 0;
   double arr[];
   ArraySetAsSeries(arr, true);
   if(CopyTickVolume(g_sym, PERIOD_CURRENT, 0, 1, arr) > 0) vol_now = arr[0];
   for(int i = 0; i < InpVolumeSMA; i++) {
      ArraySetAsSeries(arr, true);
      if(CopyTickVolume(g_sym, PERIOD_CURRENT, i, 1, arr) > 0) vol_sma += arr[0];
   }
   f.vol_ratio = (vol_sma > 0) ? (vol_now / vol_sma) : 1.0;
   
   // Feature 6: ATR regime (current ATR / 100-bar avg ATR)
   double atr_now = GetATR(g_sym, InpATRPeriod, 0);
   double atr_avg = 0;
   for(int i = 0; i < 100; i++) {
      double a = GetATR(g_sym, InpATRPeriod, i);
      if(a > 0) atr_avg += a;
   }
   atr_avg /= 100.0;
   f.atr_regime = (atr_avg > 0) ? (atr_now / atr_avg) : 1.0;
   
   // Feature 7: Session
   f.session = GetSession();
   
   return true;
}

int GetSignalDirection(const TFeatureVec &f) {
   // BUY: MA fast > MA slow (bullish), Stoch oversold zone rising, volume above threshold
   bool bull_trend = f.fast_gap_pct > 0;
   bool stoch_buy  = f.stoch_k < InpStochOverSold && f.stoch_dir > 0;
   bool vol_ok     = f.vol_ratio >= InpVolMult * 0.5; // relaxed for emerging volume
   
   // SELL: MA fast < MA slow (bearish), Stoch overbought zone falling
   bool bear_trend = f.fast_gap_pct < 0;
   bool stoch_sell = f.stoch_k > InpStochOverBought && f.stoch_dir < 0;
   
   if(bull_trend && stoch_buy && vol_ok) return 1;   // BUY
   if(bear_trend && stoch_sell && vol_ok) return -1; // SELL
   return 0;
}

bool CheckSpread() {
   double spread = SymbolInfoInteger(g_sym, SYMBOL_SPREAD);
   return spread <= (long)g_max_spread_pts;
}

//+------------------------------------------------------------------+
//| PHASE 2: REVIEW — VIRTUAL SL/TP + TRAILING (TICKET DESCENDING)   |
//+------------------------------------------------------------------+
int FindPosByTicket(ulong ticket) {
   for(int i = 0; i < g_pos_count; i++) {
      if(g_positions[i].ticket == ticket) return i;
   }
   return -1;
}

void AddPosition(ulong ticket, int dir, double open, double sl, double tp) {
   int idx = g_pos_count++;
   ArrayResize(g_positions, g_pos_count);
   g_positions[idx].ticket = ticket;
   g_positions[idx].direction = dir;
   g_positions[idx].open_price = open;
   g_positions[idx].virtual_sl = sl;
   g_positions[idx].virtual_tp = tp;
   g_positions[idx].virtual_trail = sl;
   g_positions[idx].open_time = TimeCurrent();
   g_positions[idx].trail_active = false;
   g_positions[idx].feature_hash = 0;
}

void RemovePosition(int idx) {
   if(idx < 0 || idx >= g_pos_count) return;
   for(int i = idx; i < g_pos_count - 1; i++) {
      g_positions[i] = g_positions[i + 1];
   }
   g_pos_count--;
   ArrayResize(g_positions, g_pos_count);
}

bool CheckVirtualTP(ulong ticket, int dir, double current_price) {
   int idx = FindPosByTicket(ticket);
   if(idx < 0) return false;
   double tp = g_positions[idx].virtual_tp;
   if(dir == 1) {
      // BUY: TP above
      return current_price >= tp;
   } else {
      // SELL: TP below
      return current_price <= tp;
   }
}

bool CheckVirtualSL(ulong ticket, int dir, double current_price) {
   int idx = FindPosByTicket(ticket);
   if(idx < 0) return false;
   double sl = g_positions[idx].virtual_sl;
   if(dir == 1) {
      return current_price <= sl;
   } else {
      return current_price >= sl;
   }
}

void UpdateTrailing(ulong ticket, int dir, double current_price) {
   int idx = FindPosByTicket(ticket);
   if(idx < 0) return;
   
   double profit_pts = 0;
   if(dir == 1) {
      profit_pts = (current_price - g_positions[idx].open_price) / g_point;
      // Move trail up
      double new_sl = current_price - PointsToPrice(InpTrailingStart);
      if(new_sl > g_positions[idx].virtual_trail) {
         g_positions[idx].virtual_trail = NormalizePrice(new_sl);
         g_positions[idx].virtual_sl = g_positions[idx].virtual_trail;
      }
   } else {
      profit_pts = (g_positions[idx].open_price - current_price) / g_point;
      double new_sl = current_price + PointsToPrice(InpTrailingStart);
      if(new_sl < g_positions[idx].virtual_trail || g_positions[idx].virtual_trail == g_positions[idx].virtual_sl) {
         g_positions[idx].virtual_trail = NormalizePrice(new_sl);
         g_positions[idx].virtual_sl = g_positions[idx].virtual_trail;
      }
   }
   
   if(profit_pts >= InpTrailingStart) {
      g_positions[idx].trail_active = true;
   }
}

//+------------------------------------------------------------------+
//| OPEN POSITION (PHASE 1 -> PHASE 2)                                |
//+------------------------------------------------------------------+
bool OpenPosition(int dir, double price, const TFeatureVec &f, long rid) {
   if(g_pos_count >= InpMaxPositions) {
      Print("[SimpleML] Max positions reached: ", g_pos_count);
      return false;
   }
   if(!CheckSpread()) {
      Print("[SimpleML] Spread too wide, skipping");
      return false;
   }
   
   double sl_price, tp_price;
   int sl_pts = InpSLPoints;
   int tp_pts = InpTPPoints;
   
   if(dir == 1) {
      sl_price = NormalizePrice(price - PointsToPrice(sl_pts));
      tp_price = NormalizePrice(price + PointsToPrice(tp_pts));
   } else {
      sl_price = NormalizePrice(price + PointsToPrice(sl_pts));
      tp_price = NormalizePrice(price - PointsToPrice(tp_pts));
   }
   
   double lot = InpLotSize;
   if(InpUseEqRisk && sl_pts > 0) {
      lot = GetEquityRiskLot(InpRiskPct, sl_pts);
   }
   lot = NormalizeLot(lot);
   if(lot < GetMinLot()) {
      Print("[SimpleML] Lot too small after normalization, skipping");
      return false;
   }
   
   ResetLastError();
   if(dir == 1) {
      if(!g_trade.Buy(lot, g_sym, price, 0, 0, "")) {
         Print("[SimpleML] BUY failed: ", GetLastError(), " lot=", lot);
         return false;
      }
   } else {
      if(!g_trade.Sell(lot, g_sym, price, 0, 0, "")) {
         Print("[SimpleML] SELL failed: ", GetLastError(), " lot=", lot);
         return false;
      }
   }
   
   ulong ticket = g_trade.ResultOrder();
   if(ticket == 0) {
      Print("[SimpleML] No ticket returned from order");
      return false;
   }
   
   // Find real open price (may differ from request)
   double open_price = price;
   if(g_pos.PositionSelectByTicket(ticket)) {
      open_price = g_pos.PriceOpen();
   }
   
   AddPosition(ticket, dir, open_price, sl_price, tp_price);
   
   // Store feature hash for learning
   if(g_pos_count > 0) {
      g_positions[g_pos_count - 1].feature_hash = (double)rid;
   }
   
   Print("[SimpleML] ", (dir == 1 ? "BUY" : "SELL"), " opened ticket=", ticket,
         " price=", DoubleToString(open_price, g_digits),
         " SL=", DoubleToString(sl_price, g_digits),
         " TP=", DoubleToString(tp_price, g_digits),
         " lot=", DoubleToString(lot, 2));
   
   return true;
}

//+------------------------------------------------------------------+
//| CLOSE POSITIONS AND LOG RESULT (PHASE 3)                          |
//+------------------------------------------------------------------+
void CloseAndLog() {
   // Descending loop to avoid skipping (SOP)
   for(int i = g_pos_count - 1; i >= 0; i--) {
      ulong ticket = g_positions[i].ticket;
      if(!g_pos.PositionSelectByTicket(ticket)) {
         // Already closed externally, remove from tracking
         RemovePosition(i);
         continue;
      }
      
      double close_price = g_pos.PriceClose();
      double open_price  = g_positions[i].open_price;
      int    dir         = g_positions[i].direction;
      long   rid         = (long)g_positions[i].feature_hash;
      
      // Calculate P&L
      double pnl = 0;
      if(dir == 1) {
         pnl = (close_price - open_price) / g_point * g_tick_val * InpLotSize;
      } else {
         pnl = (open_price - close_price) / g_point * g_tick_val * InpLotSize;
      }
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double pnl_pct = (equity > 0) ? (pnl / equity * 100.0) : 0;
      bool   won = pnl >= 0;
      
      // Reconstruct feature vec for KB (we stored rid, which encodes features)
      TFeatureVec f;
      // Decode from rid isn't perfect, but we can log the rid directly
      // and the feature details separately
      f.session = GetSession();
      
      // Close the position
      ResetLastError();
      if(dir == 1) {
         g_trade.Sell(InpLotSize, g_sym, close_price, 0, 0, "SL Close");
      } else {
         g_trade.Buy(InpLotSize, g_sym, close_price, 0, 0, "TP/SL Close");
      }
      
      // Update knowledge base
      if(InpAutoLearn) {
         UpdateRegime(rid, won);
         // Log to CSV
         // Re-derive approximate features for logging
         TFeatureVec log_f;
         log_f.session = f.session;
         log_f.stoch_k = 50; // placeholder — full decode would need stored features
         log_f.stoch_dir = 0;
         log_f.vol_ratio = 1.0;
         log_f.atr_regime = 1.0;
         log_f.fast_gap_pct = 0;
         log_f.htf_slope = 0;
         AppendKB(log_f, rid, dir, open_price, close_price, pnl_pct, won);
      }
      
      Print("[SimpleML] Closed ticket=", ticket, " ", (won ? "WIN" : "LOSS"),
            " P&L=", DoubleToString(pnl, 2), " P&L%=", DoubleToStrPct(pnl_pct));
      
      RemovePosition(i);
   }
}

//+------------------------------------------------------------------+
//| CHECK ALL OPEN POSITIONS (PHASE 2)                                |
//+------------------------------------------------------------------+
void ReviewPositions(double current_price) {
   // Descending loop per SOP — avoids skipping during iteration
   for(int i = g_pos_count - 1; i >= 0; i--) {
      ulong ticket = g_positions[i].ticket;
      
      if(!g_pos.PositionSelectByTicket(ticket)) {
         // Position already closed by broker, remove from tracking
         RemovePosition(i);
         continue;
      }
      
      int    dir     = g_positions[i].direction;
      double sl      = g_positions[i].virtual_sl;
      double tp      = g_positions[i].virtual_tp;
      
      // Check TP
      if(CheckVirtualTP(ticket, dir, current_price)) {
         Print("[SimpleML] Virtual TP hit ticket=", ticket, " price=", 
               DoubleToString(current_price, g_digits));
         RemovePosition(i);
         continue;
      }
      
      // Check SL
      if(CheckVirtualSL(ticket, dir, current_price)) {
         Print("[SimpleML] Virtual SL hit ticket=", ticket, " price=", 
               DoubleToString(current_price, g_digits));
         RemovePosition(i);
         continue;
      }
      
      // Update trailing if activated
      if(g_positions[i].trail_active) {
         UpdateTrailing(ticket, dir, current_price);
      }
   }
}

//+------------------------------------------------------------------+
//| ON INIT                                                           |
//+------------------------------------------------------------------+
int OnInit() {
   InitKBPath();
   
   // Load knowledge base
   LoadKB();
   
   // Verify symbol
   if(InpSymbol != "" && InpSymbol != _Symbol) {
      Print("[SimpleML] WARNING: InpSymbol (", InpSymbol, ") != current symbol (", _Symbol, ")");
   }
   
   Print("[SimpleML] Initialized on ", g_sym, " magic=", g_magic,
         " KB: ", g_regime_count, " regimes | ",
         g_total_wins, "W / ", g_total_losses, "L / ", g_total_trades, " total");
   
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
   EventKillTimer();
   if(g_file_handle != INVALID_HANDLE) {
      FileClose(g_file_handle);
      g_file_handle = INVALID_HANDLE;
   }
   Print("[SimpleML] Deinit reason=", reason, " final: ",
         g_total_wins, "W / ", g_total_losses, "L / ", g_total_trades, " total | ",
         g_pos_count, " open positions tracked");
}

//+------------------------------------------------------------------+
//| ON TICK                                                           |
//+------------------------------------------------------------------+
void OnTick() {
   double current_price = SymbolInfoDouble(g_sym, SYMBOL_BID);
   if(current_price <= 0) return;
   
   // PHASE 2: Review existing positions first (every tick)
   ReviewPositions(current_price);
   
   // Check if we can open new position
   if(g_pos_count >= InpMaxPositions) return;
   
   // Check spread
   long spread = SymbolInfoInteger(g_sym, SYMBOL_SPREAD);
   if(spread > (long)g_max_spread_pts) return;
   
   // PHASE 1: Compute features
   TFeatureVec f;
   if(!ComputeFeatures(f)) return;
   
   // Get signal direction
   int dir = GetSignalDirection(f);
   if(dir == 0) return; // No signal
   
   // Compute regime ID
   long rid = ComputeRegimeID(f);
   
   // Get confidence
   double conf = GetRegimeConfidence(rid);
   
   // Confidence check
   if(conf < InpMinConf) {
      // SKIP — log
      Print("[SimpleML] SKIP: dir=", (dir==1?"BUY":"SELL"), 
            " conf=", DoubleToString(conf, 4), 
            " min=", DoubleToString(InpMinConf, 4),
            " rid=", rid,
            " stoch_k=", DoubleToString(f.stoch_k, 2),
            " vol_r=", DoubleToString(f.vol_ratio, 2),
            " sess=", GetSessionName(f.session));
      return;
   }
   
   Print("[SimpleML] SIGNAL: dir=", (dir==1?"BUY":"SELL"),
         " conf=", DoubleToString(conf, 4),
         " rid=", rid,
         " fast_gap=", DoubleToString(f.fast_gap_pct * 100, 3), "%",
         " stoch_k=", DoubleToString(f.stoch_k, 2),
         " vol_r=", DoubleToString(f.vol_ratio, 2),
         " atr_reg=", DoubleToString(f.atr_regime, 3),
         " sess=", GetSessionName(f.session));
   
   // Open position
   double price = (dir == 1) ? SymbolInfoDouble(g_sym, SYMBOL_ASK) : current_price;
   if(price <= 0) return;
   
   OpenPosition(dir, price, f, rid);
}

//+------------------------------------------------------------------+
//| ON TIMER — check for externally closed positions                 |
//+------------------------------------------------------------------+
void OnTimer() {
   // Check positions not tracked by us (closed by broker manually)
   for(int i = g_pos_count - 1; i >= 0; i--) {
      ulong ticket = g_positions[i].ticket;
      if(!g_pos.PositionSelectByTicket(ticket)) {
         // Externally closed — log outcome
         double open_price = g_positions[i].open_price;
         double close_price = g_pos.PriceClose();
         int    dir = g_positions[i].direction;
         long   rid = (long)g_positions[i].feature_hash;
         
         double pnl = 0;
         if(dir == 1) {
            pnl = (close_price - open_price) / g_point * g_tick_val * InpLotSize;
         } else {
            pnl = (open_price - close_price) / g_point * g_tick_val * InpLotSize;
         }
         double equity = AccountInfoDouble(ACCOUNT_EQUITY);
         double pnl_pct = (equity > 0) ? (pnl / equity * 100.0) : 0;
         bool   won = pnl >= 0;
         
         if(InpAutoLearn) {
            UpdateRegime(rid, won);
            TFeatureVec log_f;
            log_f.session = GetSession();
            log_f.stoch_k = 50;
            log_f.stoch_dir = 0;
            log_f.vol_ratio = 1.0;
            log_f.atr_regime = 1.0;
            log_f.fast_gap_pct = 0;
            log_f.htf_slope = 0;
            AppendKB(log_f, rid, dir, open_price, close_price, pnl_pct, won);
         }
         
         Print("[SimpleML] Ext-closed ticket=", ticket, " ", (won?"WIN":"LOSS"),
               " P&L=", DoubleToString(pnl, 2));
         RemovePosition(i);
      }
   }
   
   // Periodically close all tracked positions (safety — every 30 ticks handled by timer)
   // This is a backup; main close logic is in OnTick via ReviewPositions
}

//+------------------------------------------------------------------+
//| ON TRADE — catch position opens/closes from broker                 |
//+------------------------------------------------------------------+
void OnTrade() {
   // Check if any new positions opened that we didn't track
   int external_count = 0;
   for(int i = 0; i < PositionsTotal(); i++) {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Symbol() != g_sym) continue;
      if(g_pos.Magic() == g_magic) continue; // We track these
      
      // External position — log it
      ulong ticket = g_pos.Ticket();
      bool  found = false;
      for(int j = 0; j < g_pos_count; j++) {
         if(g_positions[j].ticket == ticket) { found = true; break; }
      }
      if(!found) {
         Print("[SimpleML] External pos detected ticket=", ticket, 
               " sym=", g_pos.Symbol(), " magic=", g_pos.Magic(),
               " dir=", (g_pos.PositionType()==POSITION_TYPE_BUY?"BUY":"SELL"),
               " vol=", DoubleToString(g_pos.Volume(), 2));
         external_count++;
      }
   }
}
//+------------------------------------------------------------------+
