//+------------------------------------------------------------------+
//|                              SMC_Filter.mqh                        |
//|                  Smart Money Concepts Filter Module               |
//|                        v1.0 — MQL5 Version                        |
//|                    BOS/CHoCH/FVG/Inducement                       |
//+------------------------------------------------------------------+
#property copyright "EFI SMART Trading System"
#property strict

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+

input bool   g_FVG_Enabled     = true;            // Enable FVG Filter
input int    g_FVG_Lookback    = 20;              // Bars to look for FVG

input bool   g_IND_Enabled     = true;            // Enable Inducement Detection
input int    g_IND_Lookback     = 50;              // Lookback for inducement
input double g_IND_MinMove      = 1.5;             // Min move size (ATR multiplier)
input int    g_IND_ATRPeriod    = 14;              // ATR period

input bool   g_CHOCH_Enabled   = true;           // Enable CHoCH Detection

input bool   g_OB_Enabled      = true;            // Enable Order Block zones
input int    g_OB_Lookback     = 10;              // Bars to check for OB

input bool   g_MTF_Enabled     = true;           // Enable MTF Trend Filter
input int    g_MTF_SMAPeriod1  = 20;             // Fast SMA
input int    g_MTF_SMAPeriod2  = 50;             // Slow SMA

input bool   g_StrictMode      = false;          // All filters must pass vs any

//+------------------------------------------------------------------+
//| ENUMERATIONS                                                      |
//+------------------------------------------------------------------+

enum ENUM_SMC_TREND { SMC_BULL = 1, SMC_BEAR = -1, SMC_NEUT = 0 };
enum ENUM_FVG_TYPE  { FVG_BULLISH =  1, FVG_BEARISH = -1, FVG_NONE = 0 };
enum ENUM_IND_RESULT{ IND_BULLISH =  1, IND_BEARISH = -1, IND_NONE = 0 };

//+------------------------------------------------------------------+
//| STRUCTURES                                                        |
//+------------------------------------------------------------------+

struct SFVG { double upper, lower, mid; datetime time; ENUM_FVG_TYPE fvgType; bool active; };
struct SInducement { double peak, base; datetime time; double atr; ENUM_IND_RESULT indType; bool active; };
struct SOrderBlock { double high, low; datetime time; ENUM_SMC_TREND obType; bool active; };

//+------------------------------------------------------------------+
//| CLASS: SMC Filter Engine (MQL5)                                   |
//+------------------------------------------------------------------+
class CSMCFilter
{
private:
   ENUM_SMC_TREND m_Trend;
   ENUM_SMC_TREND m_LastCHoCH;
   double m_MTF_MA_Fast, m_MTF_MA_Slow;
   
   SFVG m_BullFVG, m_BearFVG;
   SInducement m_BullInd, m_BearInd;
   SOrderBlock m_BullOB, m_BearOB;
   
   // Helper methods
   double GetHigh(int shift, int bar) { return iHigh(_Symbol, PERIOD_CURRENT, bar + shift); }
   double GetLow(int shift, int bar)  { return iLow(_Symbol, PERIOD_CURRENT, bar + shift); }
   double GetClose(int shift, int bar){ return iClose(_Symbol, PERIOD_CURRENT, bar + shift); }
   double GetOpen(int shift, int bar) { return iOpen(_Symbol, PERIOD_CURRENT, bar + shift); }
   datetime GetTime(int shift, int bar){ return iTime(_Symbol, PERIOD_CURRENT, bar + shift); }
   
   double GetATR(int period);
   ENUM_SMC_TREND DetectMTFTrend();
   ENUM_FVG_TYPE CheckFVG(int shift);
   ENUM_IND_RESULT DetectInducement(int shift);
   void DetectOrderBlocks(int shift);
   ENUM_SMC_TREND DetectCHoCH();
   
   datetime m_LastRefresh;
   bool m_CacheDirty;
   
public:
   CSMCFilter();
   ~CSMCFilter();
   
   void Refresh();
   void ForceRefresh() { m_CacheDirty = true; }
   
   // Main filters
   bool AllowLong();
   bool AllowShort();
   
   // Individual
   bool IsInFVG(double price);
   bool IsAtBullOB(double price);
   bool IsAtBearOB(double price);
   ENUM_SMC_TREND GetTrend() { return m_Trend; }
   
   string GetFilterInfo();
   string GetDetailedInfo();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CSMCFilter::CSMCFilter()
{
   m_Trend = SMC_NEUT;
   m_LastCHoCH = SMC_NEUT;
   m_MTF_MA_Fast = 0;
   m_MTF_MA_Slow = 0;
   m_CacheDirty = true;
   m_LastRefresh = 0;
   m_BullFVG.active = false;
   m_BearFVG.active = false;
   m_BullInd.active = false;
   m_BearInd.active = false;
   m_BullOB.active = false;
   m_BearOB.active = false;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CSMCFilter::~CSMCFilter() {}

//+------------------------------------------------------------------+
//| Refresh                                                            |
//+------------------------------------------------------------------+
void CSMCFilter::Refresh()
{
   datetime curTime = GetTime(0, 0);
   
   if(m_CacheDirty || curTime != m_LastRefresh)
   {
      if(g_MTF_Enabled) m_Trend = DetectMTFTrend();
      
      for(int i = 1; i <= 3; i++)
      {
         ENUM_FVG_TYPE fvg = CheckFVG(i);
         if(fvg == FVG_BULLISH && !m_BullFVG.active)
         {
            m_BullFVG.active = true;
            m_BullFVG.time = GetTime(0, i);
         }
         else if(fvg == FVG_BEARISH && !m_BearFVG.active)
         {
            m_BearFVG.active = true;
            m_BearFVG.time = GetTime(0, i);
         }
      }
      
      DetectInducement(0);
      DetectOrderBlocks(1);
      if(g_CHOCH_Enabled) m_LastCHoCH = DetectCHoCH();
      
      m_CacheDirty = false;
      m_LastRefresh = curTime;
   }
}

//+------------------------------------------------------------------+
//| Get ATR                                                            |
//+------------------------------------------------------------------+
double CSMCFilter::GetATR(int period)
{
   double sum = 0;
   for(int i = 1; i <= period; i++)
   {
      double tr = GetHigh(0, i) - GetLow(0, i);
      tr = MathMax(tr, MathAbs(GetHigh(0, i) - GetClose(0, i + 1)));
      tr = MathMax(tr, MathAbs(GetLow(0, i) - GetClose(0, i + 1)));
      sum += tr;
   }
   return sum / period;
}

//+------------------------------------------------------------------+
//| MTF Trend Detection                                                |
//+------------------------------------------------------------------+
ENUM_SMC_TREND CSMCFilter::DetectMTFTrend()
{
   double fastH4 = iMA(_Symbol, PERIOD_H4, g_MTF_SMAPeriod1, 0, MODE_EMA, PRICE_CLOSE);
   double slowH4 = iMA(_Symbol, PERIOD_H4, g_MTF_SMAPeriod2, 0, MODE_EMA, PRICE_CLOSE);
   double fastD1 = iMA(_Symbol, PERIOD_D1, g_MTF_SMAPeriod1, 0, MODE_EMA, PRICE_CLOSE);
   double slowD1 = iMA(_Symbol, PERIOD_D1, g_MTF_SMAPeriod2, 0, MODE_EMA, PRICE_CLOSE);
   
   m_MTF_MA_Fast = (fastH4 + fastD1) / 2;
   m_MTF_MA_Slow = (slowH4 + slowD1) / 2;
   
   if(fastH4 > slowH4 && fastD1 > slowD1) return SMC_BULL;
   if(fastH4 < slowH4 && fastD1 < slowD1) return SMC_BEAR;
   return SMC_NEUT;
}

//+------------------------------------------------------------------+
//| Check FVG                                                          |
//+------------------------------------------------------------------+
ENUM_FVG_TYPE CSMCFilter::CheckFVG(int shift)
{
   if(shift < 2) return FVG_NONE;
   
   // Bullish FVG: middle candle bullish, gap between candle 1 and 3
   double open_i1  = GetOpen(0, shift + 1);
   double close_i1 = GetClose(0, shift + 1);
   double low_i1   = GetLow(0, shift + 1);
   double high_i2   = GetHigh(0, shift + 2);
   
   bool bullFVG = (close_i1 > open_i1) && (low_i1 > high_i2);
   
   double open_i1b  = GetOpen(0, shift + 1);
   double close_i1b = GetClose(0, shift + 1);
   double high_i1   = GetHigh(0, shift + 1);
   double low_i2    = GetLow(0, shift + 2);
   
   bool bearFVG = (close_i1b < open_i1b) && (high_i1 < low_i2);
   
   if(bullFVG)
   {
      m_BullFVG.upper = low_i1;
      m_BullFVG.lower = high_i2;
      m_BullFVG.mid = (m_BullFVG.upper + m_BullFVG.lower) / 2;
      m_BullFVG.fvgType = FVG_BULLISH;
      m_BullFVG.active = true;
      return FVG_BULLISH;
   }
   
   if(bearFVG)
   {
      m_BearFVG.lower = high_i1;
      m_BearFVG.upper = low_i2;
      m_BearFVG.mid = (m_BearFVG.upper + m_BearFVG.lower) / 2;
      m_BearFVG.fvgType = FVG_BEARISH;
      m_BearFVG.active = true;
      return FVG_BEARISH;
   }
   
   return FVG_NONE;
}

//+------------------------------------------------------------------+
//| Detect Inducement                                                  |
//+------------------------------------------------------------------+
ENUM_IND_RESULT CSMCFilter::DetectInducement(int shift)
{
   double atr = GetATR(g_IND_ATRPeriod);
   
   for(int i = 1; i <= g_IND_Lookback; i++)
   {
      double range_i = GetHigh(0, i) - GetLow(0, i);
      if(range_i < atr * g_IND_MinMove) continue;
      
      // Bearish inducement: bullish spike + reversal down
      if(GetClose(0, i) > GetOpen(0, i))
      {
         if(i < g_IND_Lookback - 3)
         {
            int bearCount = 0;
            for(int j = 1; j <= 3; j++)
               if(GetClose(0, i + j) < GetOpen(0, i + j)) bearCount++;
            
            if(bearCount >= 2)
            {
               m_BearInd.peak = GetHigh(0, i);
               m_BearInd.base = GetLow(0, i);
               m_BearInd.time = GetTime(0, i);
               m_BearInd.atr = atr;
               m_BearInd.indType = IND_BEARISH;
               m_BearInd.active = true;
               return IND_BEARISH;
            }
         }
      }
      
      // Bullish inducement: bearish spike + reversal up
      if(GetClose(0, i) < GetOpen(0, i))
      {
         if(i < g_IND_Lookback - 3)
         {
            int bullCount = 0;
            for(int j = 1; j <= 3; j++)
               if(GetClose(0, i + j) > GetOpen(0, i + j)) bullCount++;
            
            if(bullCount >= 2)
            {
               m_BullInd.peak = GetLow(0, i);
               m_BullInd.base = GetHigh(0, i);
               m_BullInd.time = GetTime(0, i);
               m_BullInd.atr = atr;
               m_BullInd.indType = IND_BULLISH;
               m_BullInd.active = true;
               return IND_BULLISH;
            }
         }
      }
   }
   
   return IND_NONE;
}

//+------------------------------------------------------------------+
//| Detect Order Blocks                                                |
//+------------------------------------------------------------------+
void CSMCFilter::DetectOrderBlocks(int shift)
{
   for(int i = shift; i <= g_OB_Lookback; i++)
   {
      double body = MathAbs(GetClose(0, i) - GetOpen(0, i));
      
      if(GetClose(0, i) < GetOpen(0, i))
      {
         bool hasMom = false;
         for(int j = 1; j <= 3; j++)
            if(GetClose(0, i + j) > GetOpen(0, i + j)) hasMom = true;
         
         if(hasMom && body > 0)
         {
            m_BullOB.high = GetHigh(0, i);
            m_BullOB.low = GetLow(0, i);
            m_BullOB.time = GetTime(0, i);
            m_BullOB.obType = SMC_BULL;
            m_BullOB.active = true;
         }
      }
      
      if(GetClose(0, i) > GetOpen(0, i))
      {
         bool hasMom = false;
         for(int j = 1; j <= 3; j++)
            if(GetClose(0, i + j) < GetOpen(0, i + j)) hasMom = true;
         
         if(hasMom && body > 0)
         {
            m_BearOB.high = GetHigh(0, i);
            m_BearOB.low = GetLow(0, i);
            m_BearOB.time = GetTime(0, i);
            m_BearOB.obType = SMC_BEAR;
            m_BearOB.active = true;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Detect CHoCH                                                       |
//+------------------------------------------------------------------+
ENUM_SMC_TREND CSMCFilter::DetectCHoCH()
{
   if(g_CHOCH_Enabled && g_FVG_Enabled)
   {
      if(m_BullFVG.active) return SMC_BULL;
      if(m_BearFVG.active) return SMC_BEAR;
   }
   return SMC_NEUT;
}

//+------------------------------------------------------------------+
//| Is In FVG                                                           |
//+------------------------------------------------------------------+
bool CSMCFilter::IsInFVG(double price)
{
   if(m_BullFVG.active && price >= m_BullFVG.lower && price <= m_BullFVG.upper)
      return true;
   if(m_BearFVG.active && price >= m_BearFVG.lower && price <= m_BearFVG.upper)
      return true;
   return false;
}

//+------------------------------------------------------------------+
//| Is At Order Block                                                   |
//+------------------------------------------------------------------+
bool CSMCFilter::IsAtBullOB(double price)
{
   if(!g_OB_Enabled || !m_BullOB.active) return false;
   return (price >= m_BullOB.low * 0.9995 && price <= m_BullOB.high * 1.0005);
}

bool CSMCFilter::IsAtBearOB(double price)
{
   if(!g_OB_Enabled || !m_BearOB.active) return false;
   return (price >= m_BearOB.low * 0.9995 && price <= m_BearOB.high * 1.0005);
}

//+------------------------------------------------------------------+
//| Allow Long                                                         |
//+------------------------------------------------------------------+
bool CSMCFilter::AllowLong()
{
   int passCount = 0, totalFilters = 0;
   
   if(g_MTF_Enabled)
   {
      totalFilters++;
      if(m_Trend != SMC_BEAR) passCount++;
      else { Print("[SMC] LONG blocked — MTF BEARISH"); return false; }
   }
   
   if(g_FVG_Enabled)
   {
      totalFilters++;
      if(m_BullFVG.active || !m_BearFVG.active) passCount++;
      else { Print("[SMC] LONG blocked — No Bull FVG"); return false; }
   }
   
   if(g_IND_Enabled)
   {
      totalFilters++;
      if(!m_BearInd.active) passCount++;
      else
      {
         datetime now = GetTime(0, 0);
         if(now - m_BearInd.time < PeriodSeconds(PERIOD_H1) * 10)
         {
            Print("[SMC] LONG blocked — Bear Inducement fresh");
            return false;
         }
         passCount++;
      }
   }
   
   if(g_CHOCH_Enabled)
   {
      totalFilters++;
      if(m_LastCHoCH == SMC_BULL || m_LastCHoCH == SMC_NEUT) passCount++;
      else { Print("[SMC] LONG blocked — No Bull CHoCH"); return false; }
   }
   
   if(g_StrictMode) return (passCount == totalFilters);
   return (passCount >= (totalFilters + 1) / 2);
}

//+------------------------------------------------------------------+
//| Allow Short                                                        |
//+------------------------------------------------------------------+
bool CSMCFilter::AllowShort()
{
   int passCount = 0, totalFilters = 0;
   
   if(g_MTF_Enabled)
   {
      totalFilters++;
      if(m_Trend != SMC_BULL) passCount++;
      else { Print("[SMC] SHORT blocked — MTF BULLISH"); return false; }
   }
   
   if(g_FVG_Enabled)
   {
      totalFilters++;
      if(m_BearFVG.active || !m_BullFVG.active) passCount++;
      else { Print("[SMC] SHORT blocked — No Bear FVG"); return false; }
   }
   
   if(g_IND_Enabled)
   {
      totalFilters++;
      if(!m_BullInd.active) passCount++;
      else
      {
         datetime now = GetTime(0, 0);
         if(now - m_BullInd.time < PeriodSeconds(PERIOD_H1) * 10)
         {
            Print("[SMC] SHORT blocked — Bull Inducement fresh");
            return false;
         }
         passCount++;
      }
   }
   
   if(g_CHOCH_Enabled)
   {
      totalFilters++;
      if(m_LastCHoCH == SMC_BEAR || m_LastCHoCH == SMC_NEUT) passCount++;
      else { Print("[SMC] SHORT blocked — No Bear CHoCH"); return false; }
   }
   
   if(g_StrictMode) return (passCount == totalFilters);
   return (passCount >= (totalFilters + 1) / 2);
}

//+------------------------------------------------------------------+
//| Get Filter Info                                                    |
//+------------------------------------------------------------------+
string CSMCFilter::GetFilterInfo()
{
   string trendStr = (m_Trend == SMC_BULL) ? "BULL" : (m_Trend == SMC_BEAR) ? "BEAR" : "NEUT";
   string fvgStr = (m_BullFVG.active) ? "BullFVG" : (m_BearFVG.active) ? "BearFVG" : "NONE";
   string indStr = (m_BullInd.active) ? "BullIND" : (m_BearInd.active) ? "BearIND" : "NONE";
   return StringFormat("Trend:%s | FVG:%s | IND:%s", trendStr, fvgStr, indStr);
}

//+------------------------------------------------------------------+
//| Get Detailed Info                                                  |
//+------------------------------------------------------------------+
string CSMCFilter::GetDetailedInfo()
{
   string trendStr, fvgStr, indStr, obStr;
   if(m_Trend == SMC_BULL) trendStr = "BULLISH"; else if(m_Trend == SMC_BEAR) trendStr = "BEARISH"; else trendStr = "NEUTRAL";
   if(m_BullFVG.active) fvgStr = StringFormat("BullFVG: %.5f-%.5f", m_BullFVG.lower, m_BullFVG.upper);
   else if(m_BearFVG.active) fvgStr = StringFormat("BearFVG: %.5f-%.5f", m_BearFVG.lower, m_BearFVG.upper);
   else fvgStr = "No FVG";
   if(m_BullInd.active) indStr = StringFormat("BullIND: %.5f", m_BullInd.peak);
   else if(m_BearInd.active) indStr = StringFormat("BearIND: %.5f", m_BearInd.peak);
   else indStr = "No IND";
   if(m_BullOB.active) obStr = StringFormat("BullOB: %.5f-%.5f", m_BullOB.low, m_BullOB.high);
   else if(m_BearOB.active) obStr = StringFormat("BearOB: %.5f-%.5f", m_BearOB.low, m_BearOB.high);
   else obStr = "No OB";
   return StringFormat("=== SMC ===\nTrend:%s\nFVG:%s\nInducement:%s\nOrderBlock:%s", trendStr, fvgStr, indStr, obStr);
}

//+------------------------------------------------------------------+
//| END OF SMC FILTER MODULE (MQL5)                                    |
//+------------------------------------------------------------------+