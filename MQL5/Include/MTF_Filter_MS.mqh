//+------------------------------------------------------------------+
//|                          MTF_Filter_MS.mqh                        |
//|           Multi Timeframe + Market Structure Filter Module        |
//|                                v2.0                               |
//|                            MQL5 Version                           |
//+------------------------------------------------------------------+
#property copyright "EFI SMART Trading System"
#property strict

//+------------------------------------------------------------------+
//| INPUT PARAMETERS — TREND DETECTION                                |
//+------------------------------------------------------------------+
input bool   g_MTF_Enabled        = true;           // Enable MTF+MS Filter
input int    g_MTF_TrendPeriod    = 50;             // Trend MA Period
input ENUM_APPLIED_PRICE g_MTF_TrendPrice = PRICE_CLOSE;

//--- Timeframe Filter
input ENUM_TIMEFRAMES g_MTF_Filter1  = PERIOD_D1;  // Higher TF (Trend)
input ENUM_TIMEFRAMES g_MTF_Filter2  = PERIOD_H4;  // Lower TF (Structure)

//--- SMA Crossover for trend
input int    g_MTF_SMAPeriod1    = 20;              // SMA Fast Period
input int    g_MTF_SMAPeriod2    = 50;              // SMA Slow Period

//+------------------------------------------------------------------+
//| INPUT PARAMETERS — MARKET STRUCTURE                               |
//+------------------------------------------------------------------+
input bool   g_MS_Enabled        = true;           // Enable Market Structure
input int    g_MS_Lookback       = 100;             // Lookback for structure
input int    g_MS_SwingStrength  = 5;               // Swing strength (pivots)
input double g_MS_BOSThreshold   = 0.0005;          // BOS min breakout

//--- Order Block Settings
input bool   g_OB_Enabled        = true;           // Enable Order Block zones
input int    g_OB_Lookback       = 5;               // Bars to check for OB

//+------------------------------------------------------------------+
//| ENUMERATIONS                                                      |
//+------------------------------------------------------------------+

enum ENUM_TREND_DIRECTION
{
   TREND_BULLISH = 1,
   TREND_BEARISH = -1,
   TREND_NEUTRAL = 0
};

enum ENUM_STRUCTURE_BREAK
{
   BOS_BULLISH  =  1,
   BOS_BEARISH  = -1,
   CHOC_BULLISH =  2,
   CHOC_BEARISH = -2,
   STRUCTURE_NONE = 0
};

enum ENUM_OB_TYPE
{
   OB_BULLISH   =  1,
   OB_BEARISH   = -1,
   OB_NONE      =  0
};

//+------------------------------------------------------------------+
//| STRUCTS                                                           |
//+------------------------------------------------------------------+
struct SSwingPoint
{
   int      bar;
   double   price;
   bool     isHigh;
};

struct SBOSLevel
{
   double   price;
   datetime time;
   bool     broken;
   bool     bullish;
};

struct SOrderBlock
{
   double   high;
   double   low;
   datetime time;
   int      strength;
   ENUM_OB_TYPE obType;
};

//+------------------------------------------------------------------+
//| CLASS: Market Structure + MTF Filter (MQL5)                       |
//+------------------------------------------------------------------+
class CMSFilter
{
private:
   //=== MTF Trend ===
   ENUM_TREND_DIRECTION m_D1Trend;
   ENUM_TREND_DIRECTION m_H4Trend;
   double m_D1_MA_Fast, m_D1_MA_Slow;
   double m_H4_MA_Fast, m_H4_MA_Slow;
   
   //=== Market Structure ===
   SSwingPoint m_Swings[];
   int         m_SwingCount;
   SBOSLevel   m_LastBOS;
   ENUM_STRUCTURE_BREAK m_LastStructure;
   
   //=== Order Blocks ===
   SOrderBlock m_BullishOB;
   SOrderBlock m_BearishOB;
   
   //=== Helper Methods ===
   int    DetectSwingPoints();
   bool   CheckBOS();
   bool   CheckCHoCH();
   void   DetectOrderBlocks();
   
   datetime m_LastStructureCheck;
   bool     m_StructureDirty;
   
public:
   CMSFilter();
   ~CMSFilter();
   
   //--- Core
   void Refresh();
   void ForceRefresh() { m_StructureDirty = true; }
   
   //--- MTF Trend
   ENUM_TREND_DIRECTION GetD1Trend()   { return m_D1Trend; }
   ENUM_TREND_DIRECTION GetH4Trend()   { return m_H4Trend; }
   ENUM_TREND_DIRECTION GetCombinedTrend();
   
   //--- Market Structure
   ENUM_STRUCTURE_BREAK GetLastStructure() { return m_LastStructure; }
   bool   IsBullishStructure();
   bool   IsBearishStructure();
   
   //--- Order Blocks
   bool   IsPriceInBullishOB(double price);
   bool   IsPriceInBearishOB(double price);
   double GetBullishOBHigh()   { return m_BullishOB.high; }
   double GetBullishOBLow()    { return m_BullishOB.low; }
   double GetBearishOBHigh()   { return m_BearishOB.high; }
   double GetBearishOBLow()    { return m_BearishOB.low; }
   
   //=== MAIN TRADING FILTERS ===
   bool   AllowLong();
   bool   AllowShort();
   
   bool   AllowLong_MS();
   bool   AllowShort_MS();
   
   bool   AllowLong_MTF();
   bool   AllowShort_MTF();
   
   //--- Info
   string GetTrendInfo();
   string GetStructureInfo();
   string GetFullInfo();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CMSFilter::CMSFilter()
{
   m_D1Trend = TREND_NEUTRAL;
   m_H4Trend = TREND_NEUTRAL;
   m_SwingCount = 0;
   m_LastStructure = STRUCTURE_NONE;
   m_StructureDirty = true;
   m_LastStructureCheck = 0;
   
   ArrayResize(m_Swings, 0);
   m_BullishOB.obType = OB_NONE;
   m_BearishOB.obType = OB_NONE;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CMSFilter::~CMSFilter()
{
}

//+------------------------------------------------------------------+
//| Refresh - Update all data                                         |
//+------------------------------------------------------------------+
void CMSFilter::Refresh()
{
   datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   //--- 1. Update MTF Trend
   UpdateMTFTrend();
   
   //--- 2. Update Market Structure (on new bar only)
   if(m_StructureDirty || currentTime != m_LastStructureCheck)
   {
      DetectSwingPoints();
      CheckBOS();
      CheckCHoCH();
      DetectOrderBlocks();
      m_StructureDirty = false;
      m_LastStructureCheck = currentTime;
   }
}

//+------------------------------------------------------------------+
//| Update MTF Trend                                                  |
//+------------------------------------------------------------------+
void CMSFilter::UpdateMTFTrend()
{
   // D1
   double d1Fast = iMA(_Symbol, g_MTF_Filter1, g_MTF_SMAPeriod1, 0, MODE_EMA, g_MTF_TrendPrice);
   double d1Slow = iMA(_Symbol, g_MTF_Filter1, g_MTF_SMAPeriod2, 0, MODE_EMA, g_MTF_TrendPrice);
   
   if(d1Fast > d1Slow) m_D1Trend = TREND_BULLISH;
   else if(d1Fast < d1Slow) m_D1Trend = TREND_BEARISH;
   else m_D1Trend = TREND_NEUTRAL;
   
   m_D1_MA_Fast = d1Fast;
   m_D1_MA_Slow = d1Slow;
   
   // H4
   double h4Fast = iMA(_Symbol, g_MTF_Filter2, g_MTF_SMAPeriod1, 0, MODE_EMA, g_MTF_TrendPrice);
   double h4Slow = iMA(_Symbol, g_MTF_Filter2, g_MTF_SMAPeriod2, 0, MODE_EMA, g_MTF_TrendPrice);
   
   if(h4Fast > h4Slow) m_H4Trend = TREND_BULLISH;
   else if(h4Fast < h4Slow) m_H4Trend = TREND_BEARISH;
   else m_H4Trend = TREND_NEUTRAL;
   
   m_H4_MA_Fast = h4Fast;
   m_H4_MA_Slow = h4Slow;
}

//+------------------------------------------------------------------+
//| Get price data helper (MQL5 array access)                         |
//+------------------------------------------------------------------+
double GetHigh(int shift, int bar)
{
   return iHigh(_Symbol, PERIOD_CURRENT, bar + shift);
}

double GetLow(int shift, int bar)
{
   return iLow(_Symbol, PERIOD_CURRENT, bar + shift);
}

double GetClose(int shift, int bar)
{
   return iClose(_Symbol, PERIOD_CURRENT, bar + shift);
}

datetime GetTime(int shift, int bar)
{
   return iTime(_Symbol, PERIOD_CURRENT, bar + shift);
}

//+------------------------------------------------------------------+
//| Detect Swing Points                                               |
//+------------------------------------------------------------------+
int CMSFilter::DetectSwingPoints()
{
   m_SwingCount = 0;
   ArrayResize(m_Swings, 0);
   
   int lookback = MathMin(g_MS_Lookback, 100);
   
   for(int i = g_MS_SwingStrength + 1; i < lookback - g_MS_SwingStrength; i++)
   {
      // Check swing high
      bool isHigh = true;
      for(int j = 1; j <= g_MS_SwingStrength; j++)
      {
         if(GetHigh(0, i + j) >= GetHigh(0, i) || GetHigh(0, i - j) >= GetHigh(0, i))
         {
            isHigh = false;
            break;
         }
      }
      
      // Check swing low
      bool isLow = true;
      for(int j = 1; j <= g_MS_SwingStrength; j++)
      {
         if(GetLow(0, i + j) <= GetLow(0, i) || GetLow(0, i - j) <= GetLow(0, i))
         {
            isLow = false;
            break;
         }
      }
      
      if(isHigh)
      {
         ArrayResize(m_Swings, m_SwingCount + 1);
         m_Swings[m_SwingCount].bar = i;
         m_Swings[m_SwingCount].price = GetHigh(0, i);
         m_Swings[m_SwingCount].isHigh = true;
         m_SwingCount++;
      }
      else if(isLow)
      {
         ArrayResize(m_Swings, m_SwingCount + 1);
         m_Swings[m_SwingCount].bar = i;
         m_Swings[m_SwingCount].price = GetLow(0, i);
         m_Swings[m_SwingCount].isHigh = false;
         m_SwingCount++;
      }
   }
   
   return m_SwingCount;
}

//+------------------------------------------------------------------+
//| Check Break of Structure                                          |
//+------------------------------------------------------------------+
bool CMSFilter::CheckBOS()
{
   if(m_SwingCount < 4) return false;
   
   int lastHigh = -1, lastLow = -1, prevHigh = -1, prevLow = -1;
   
   for(int i = m_SwingCount - 1; i >= 0; i--)
   {
      if(m_Swings[i].isHigh)
      {
         if(lastHigh < 0) lastHigh = i;
         else if(prevHigh < 0) prevHigh = i;
      }
      else
      {
         if(lastLow < 0) lastLow = i;
         else if(prevLow < 0) prevLow = i;
      }
   }
   
   if(lastHigh < 0 || lastLow < 0 || prevHigh < 0 || prevLow < 0)
      return false;
   
   double currentClose = GetClose(0, 0);
   
   // Bullish BOS: HH and price breaks above it
   bool bullishBOS = (m_Swings[lastHigh].price > m_Swings[prevHigh].price) &&
                     (currentClose > m_Swings[lastHigh].price + g_MS_BOSThreshold);
   
   // Bearish BOS: LL and price breaks below it
   bool bearishBOS = (m_Swings[lastLow].price < m_Swings[prevLow].price) &&
                     (currentClose < m_Swings[lastLow].price - g_MS_BOSThreshold);
   
   if(bullishBOS)
   {
      m_LastStructure = BOS_BULLISH;
      m_LastBOS.price = m_Swings[lastHigh].price;
      m_LastBOS.bullish = true;
      m_LastBOS.broken = true;
      m_LastBOS.time = GetTime(0, m_Swings[lastHigh].bar);
      return true;
   }
   else if(bearishBOS)
   {
      m_LastStructure = BOS_BEARISH;
      m_LastBOS.price = m_Swings[lastLow].price;
      m_LastBOS.bullish = false;
      m_LastBOS.broken = true;
      m_LastBOS.time = GetTime(0, m_Swings[lastLow].bar);
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check Change of Character                                         |
//+------------------------------------------------------------------+
bool CMSFilter::CheckCHoCH()
{
   if(m_SwingCount < 6) return false;
   
   double highs[2], lows[2];
   int hIdx = 0, lIdx = 0;
   
   for(int i = m_SwingCount - 1; i >= 0 && (hIdx < 2 || lIdx < 2); i--)
   {
      if(m_Swings[i].isHigh && hIdx < 2) highs[hIdx++] = m_Swings[i].price;
      else if(!m_Swings[i].isHigh && lIdx < 2) lows[lIdx++] = m_Swings[i].price;
   }
   
   if(hIdx < 2 || lIdx < 2) return false;
   
   double currentClose = GetClose(0, 0);
   
   bool bullishCHoCH = (highs[0] < highs[1]) && (currentClose > highs[0]);
   bool bearishCHoCH = (lows[0] > lows[1]) && (currentClose < lows[0]);
   
   if(bullishCHoCH)
   {
      m_LastStructure = CHOC_BULLISH;
      return true;
   }
   else if(bearishCHoCH)
   {
      m_LastStructure = CHOC_BEARISH;
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Detect Order Blocks                                               |
//+------------------------------------------------------------------+
void CMSFilter::DetectOrderBlocks()
{
   double bullishOBHigh = 0, bullishOBLow = 0;
   double bearishOBHigh = 0, bearishOBLow = 0;
   int bullCount = 0, bearCount = 0;
   
   for(int i = 1; i <= g_OB_Lookback; i++)
   {
      double close1 = GetClose(0, i);
      double open1  = iOpen(_Symbol, PERIOD_CURRENT, i);
      
      if(close1 < open1) // Bearish candle = potential bullish OB
      {
         if(bullishOBLow == 0 || GetLow(0, i) < bullishOBLow)
         {
            bullishOBLow = GetLow(0, i);
            bullishOBHigh = GetHigh(0, i);
         }
         bullCount++;
      }
      
      if(close1 > open1) // Bullish candle = potential bearish OB
      {
         if(bearishOBHigh == 0 || GetHigh(0, i) > bearishOBHigh)
         {
            bearishOBHigh = GetHigh(0, i);
            bearishOBLow = GetLow(0, i);
         }
         bearCount++;
      }
   }
   
   if(bullCount > 0)
   {
      m_BullishOB.high = bullishOBHigh;
      m_BullishOB.low = bullishOBLow;
      m_BullishOB.time = GetTime(0, 1);
      m_BullishOB.strength = bullCount;
      m_BullishOB.obType = OB_BULLISH;
   }
   
   if(bearCount > 0)
   {
      m_BearishOB.high = bearishOBHigh;
      m_BearishOB.low = bearishOBLow;
      m_BearishOB.time = GetTime(0, 1);
      m_BearishOB.strength = bearCount;
      m_BearishOB.obType = OB_BEARISH;
   }
}

//+------------------------------------------------------------------+
//| Get Combined Trend                                                 |
//+------------------------------------------------------------------+
ENUM_TREND_DIRECTION CMSFilter::GetCombinedTrend()
{
   if(!g_MTF_Enabled) return TREND_NEUTRAL;
   
   if(m_D1Trend == m_H4Trend && m_D1Trend != TREND_NEUTRAL)
      return m_D1Trend;
   
   if(m_D1Trend != TREND_NEUTRAL && m_H4Trend == TREND_NEUTRAL)
      return m_D1Trend;
   
   return TREND_NEUTRAL;
}

//+------------------------------------------------------------------+
//| Is Bullish Structure                                              |
//+------------------------------------------------------------------+
bool CMSFilter::IsBullishStructure()
{
   if(!g_MS_Enabled) return true;
   
   if(m_LastStructure == BOS_BULLISH) return true;
   if(m_LastStructure == CHOC_BULLISH) return true;
   
   if(m_SwingCount >= 4)
   {
      double recentHighs[2], recentLows[2];
      int hCount = 0, lCount = 0;
      
      for(int i = m_SwingCount - 1; i >= 0 && (hCount < 2 || lCount < 2); i--)
      {
         if(m_Swings[i].isHigh && hCount < 2) recentHighs[hCount++] = m_Swings[i].price;
         else if(!m_Swings[i].isHigh && lCount < 2) recentLows[lCount++] = m_Swings[i].price;
      }
      
      if(hCount >= 2 && lCount >= 2)
      {
         return (recentHighs[0] > recentHighs[1] && recentLows[0] > recentLows[1]);
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Is Bearish Structure                                              |
//+------------------------------------------------------------------+
bool CMSFilter::IsBearishStructure()
{
   if(!g_MS_Enabled) return true;
   
   if(m_LastStructure == BOS_BEARISH) return true;
   if(m_LastStructure == CHOC_BEARISH) return true;
   
   if(m_SwingCount >= 4)
   {
      double recentHighs[2], recentLows[2];
      int hCount = 0, lCount = 0;
      
      for(int i = m_SwingCount - 1; i >= 0 && (hCount < 2 || lCount < 2); i--)
      {
         if(m_Swings[i].isHigh && hCount < 2) recentHighs[hCount++] = m_Swings[i].price;
         else if(!m_Swings[i].isHigh && lCount < 2) recentLows[lCount++] = m_Swings[i].price;
      }
      
      if(hCount >= 2 && lCount >= 2)
      {
         return (recentHighs[0] < recentHighs[1] && recentLows[0] < recentLows[1]);
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Is Price in Bullish OB                                            |
//+------------------------------------------------------------------+
bool CMSFilter::IsPriceInBullishOB(double price)
{
   if(!g_MS_Enabled || !g_OB_Enabled) return false;
   if(m_BullishOB.obType != OB_BULLISH) return false;
   return (price >= m_BullishOB.low && price <= m_BullishOB.high);
}

//+------------------------------------------------------------------+
//| Is Price in Bearish OB                                            |
//+------------------------------------------------------------------+
bool CMSFilter::IsPriceInBearishOB(double price)
{
   if(!g_MS_Enabled || !g_OB_Enabled) return false;
   if(m_BearishOB.obType != OB_BEARISH) return false;
   return (price >= m_BearishOB.low && price <= m_BearishOB.high);
}

//+------------------------------------------------------------------+
//| MAIN ENTRY FILTER: Allow Long                                     |
//+------------------------------------------------------------------+
bool CMSFilter::AllowLong()
{
   // Step 1: MTF Trend
   if(g_MTF_Enabled)
   {
      ENUM_TREND_DIRECTION trend = GetCombinedTrend();
      if(trend == TREND_BEARISH)
      {
         Print("[MTF+MS] LONG blocked — MTF trend is BEARISH");
         return false;
      }
   }
   
   // Step 2: Market Structure
   if(g_MS_Enabled)
   {
      if(!IsBullishStructure())
      {
         Print("[MTF+MS] LONG blocked — Market Structure is not bullish");
         return false;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| MAIN ENTRY FILTER: Allow Short                                    |
//+------------------------------------------------------------------+
bool CMSFilter::AllowShort()
{
   // Step 1: MTF Trend
   if(g_MTF_Enabled)
   {
      ENUM_TREND_DIRECTION trend = GetCombinedTrend();
      if(trend == TREND_BULLISH)
      {
         Print("[MTF+MS] SHORT blocked — MTF trend is BULLISH");
         return false;
      }
   }
   
   // Step 2: Market Structure
   if(g_MS_Enabled)
   {
      if(!IsBearishStructure())
      {
         Print("[MTF+MS] SHORT blocked — Market Structure is not bearish");
         return false;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| MS Only: Allow Long                                               |
//+------------------------------------------------------------------+
bool CMSFilter::AllowLong_MS()
{
   if(!g_MS_Enabled) return true;
   return IsBullishStructure();
}

//+------------------------------------------------------------------+
//| MS Only: Allow Short                                              |
//+------------------------------------------------------------------+
bool CMSFilter::AllowShort_MS()
{
   if(!g_MS_Enabled) return true;
   return IsBearishStructure();
}

//+------------------------------------------------------------------+
//| MTF Only: Allow Long                                              |
//+------------------------------------------------------------------+
bool CMSFilter::AllowLong_MTF()
{
   if(!g_MTF_Enabled) return true;
   ENUM_TREND_DIRECTION trend = GetCombinedTrend();
   return (trend != TREND_BEARISH);
}

//+------------------------------------------------------------------+
//| MTF Only: Allow Short                                             |
//+------------------------------------------------------------------+
bool CMSFilter::AllowShort_MTF()
{
   if(!g_MTF_Enabled) return true;
   ENUM_TREND_DIRECTION trend = GetCombinedTrend();
   return (trend != TREND_BULLISH);
}

//+------------------------------------------------------------------+
//| Get Trend Info                                                    |
//+------------------------------------------------------------------+
string CMSFilter::GetTrendInfo()
{
   string d1Str, h4Str, combStr;
   
   if(m_D1Trend == TREND_BULLISH) d1Str = "BULL";
   else if(m_D1Trend == TREND_BEARISH) d1Str = "BEAR";
   else d1Str = "NEUT";
   
   if(m_H4Trend == TREND_BULLISH) h4Str = "BULL";
   else if(m_H4Trend == TREND_BEARISH) h4Str = "BEAR";
   else h4Str = "NEUT";
   
   ENUM_TREND_DIRECTION comb = GetCombinedTrend();
   if(comb == TREND_BULLISH) combStr = "BULL";
   else if(comb == TREND_BEARISH) combStr = "BEAR";
   else combStr = "NEUT";
   
   return StringFormat("D1:%s H4:%s CFX:%s", d1Str, h4Str, combStr);
}

//+------------------------------------------------------------------+
//| Get Structure Info                                                |
//+------------------------------------------------------------------+
string CMSFilter::GetStructureInfo()
{
   string structStr, obStr = "";
   
   if(m_LastStructure == BOS_BULLISH) structStr = "BOS_BULL";
   else if(m_LastStructure == BOS_BEARISH) structStr = "BOS_BEAR";
   else if(m_LastStructure == CHOC_BULLISH) structStr = "CHoCH_BULL";
   else if(m_LastStructure == CHOC_BEARISH) structStr = "CHoCH_BEAR";
   else structStr = "NONE";
   
   if(g_MS_Enabled && g_OB_Enabled)
   {
      if(m_BullishOB.obType == OB_BULLISH)
         obStr = StringFormat(" | BullOB:%.5f-%.5f", m_BullishOB.low, m_BullishOB.high);
      if(m_BearishOB.obType == OB_BEARISH)
         obStr += StringFormat(" | BearOB:%.5f-%.5f", m_BearishOB.low, m_BearishOB.high);
   }
   
   return StringFormat("[MS:%s]%s", structStr, obStr);
}

//+------------------------------------------------------------------+
//| Get Full Info                                                     |
//+------------------------------------------------------------------+
string CMSFilter::GetFullInfo()
{
   return StringFormat("MTF+MS FILTER\n===============\nTrend: %s\nStructure: %s",
                       GetTrendInfo(), GetStructureInfo());
}

//+------------------------------------------------------------------+
//| END OF MODULE (MQL5)                                              |
//+------------------------------------------------------------------+