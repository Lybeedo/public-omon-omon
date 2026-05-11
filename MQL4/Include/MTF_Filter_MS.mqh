//+------------------------------------------------------------------+
//|                           MTF_Filter_MS.mqh                       |
//|              Multi Timeframe + Market Structure Filter Module      |
//|                                v2.0                               |
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
input double g_MS_BOSThreshold   = 0.0005;          // BOS min breakout (price)

//--- Order Block Settings
input bool   g_OB_Enabled        = true;           // Enable Order Block zones
input int    g_OB_Lookback       = 5;               // Bars to check for OB
input int    g_OB_StrongOB       = 3;               // Strong OB = N+ consecutive same-dir candles

//+------------------------------------------------------------------+
//| ENUMERATIONS                                                      |
//+------------------------------------------------------------------+

enum ENUM_TREND_DIRECTION
{
   TREND_BULLISH = 1,    // Uptrend
   TREND_BEARISH = -1,   // Downtrend
   TREND_NEUTRAL = 0     // No clear trend
};

enum ENUM_STRUCTURE_BREAK
{
   BOS_BULLISH  =  1,    // Break of Structure bullish
   BOS_BEARISH  = -1,    // Break of Structure bearish
   CHOC_BULLISH =  2,    // Change of Character bullish
   CHOC_BEARISH = -2,    // Change of Character bearish
   STRUCTURE_NONE = 0
};

enum ENUM_OB_TYPE
{
   OB_BULLISH   =  1,    // Bullish Order Block (last bearish candle)
   OB_BEARISH   = -1,    // Bearish Order Block (last bullish candle)
   OB_NONE      =  0
};

//+------------------------------------------------------------------+
//| STRUCT: Swing Point                                               |
//+------------------------------------------------------------------+
struct SSwingPoint
{
   int      bar;            // Bar index
   double   price;          // Swing high/low price
   bool     isHigh;         // True = high, False = low
};

//+------------------------------------------------------------------+
//| STRUCT: BOS Level                                                 |
//+------------------------------------------------------------------+
struct SBOSLevel
{
   double   price;          // Level that was broken
   datetime time;           // Time of the level
   bool     broken;         // Is it broken?
   bool     bullish;        // Bullish or bearish BOS
};

//+------------------------------------------------------------------+
//| STRUCT: Order Block                                              |
//+------------------------------------------------------------------+
struct SOrderBlock
{
   double   high;           // OB high
   double   low;            // OB low
   datetime time;           // OB creation time
   int      strength;       // How strong (number of candles)
   ENUM_OB_TYPE obType;     // Bullish or Bearish OB
};

//+------------------------------------------------------------------+
//| CLASS: Market Structure + MTF Filter Engine                       |
//+------------------------------------------------------------------+
class CMSFilter
{
private:
   //=== Trend (MTF) ===
   ENUM_TREND_DIRECTION m_D1Trend;
   ENUM_TREND_DIRECTION m_H4Trend;
   double m_D1_MA_Fast, m_D1_MA_Slow;
   double m_H4_MA_Fast, m_H4_MA_Slow;
   
   //=== Market Structure ===
   SSwingPoint m_Swings[];          // Detected swing points
   int         m_SwingCount;
   SBOSLevel   m_LastBOS;          // Last BOS detected
   ENUM_STRUCTURE_BREAK m_LastStructure;
   
   //=== Order Blocks ===
   SOrderBlock m_BullishOB;        // Latest bullish OB
   SOrderBlock m_BearishOB;        // Latest bearish OB
   
   //=== Helper Methods ===
   double GetMAValue(ENUM_TIMEFRAMES tf, int period, int shift);
   int    DetectSwingPoints();
   bool   CheckBOS();
   bool   CheckCHoCH();
   void   DetectOrderBlocks();
   
   //=== Structure Cache ===
   datetime m_LastStructureCheck;
   bool     m_StructureDirty;
   
public:
   //--- Constructor/Destructor
   CMSFilter();
   ~CMSFilter();
   
   //--- Core Methods
   void Refresh();
   void ForceRefresh() { m_StructureDirty = true; }
   
   //--- Trend Direction (MTF)
   ENUM_TREND_DIRECTION GetD1Trend()   { return m_D1Trend; }
   ENUM_TREND_DIRECTION GetH4Trend()   { return m_H4Trend; }
   ENUM_TREND_DIRECTION GetCombinedTrend();
   
   //--- Market Structure
   ENUM_STRUCTURE_BREAK GetLastStructure() { return m_LastStructure; }
   bool   IsBullishStructure();   // HH/HL forming, or BOS bullish
   bool   IsBearishStructure();   // LH/LL forming, or BOS bearish
   
   //--- Order Blocks
   bool   IsPriceInBullishOB(double price);
   bool   IsPriceInBearishOB(double price);
   double GetBullishOBHigh()      { return m_BullishOB.high; }
   double GetBullishOBLow()       { return m_BullishOB.low; }
   double GetBearishOBHigh()       { return m_BearishOB.high; }
   double GetBearishOBLow()       { return m_BearishOB.low; }
   
   //=== TRADING DECISION METHODS ===
   bool   AllowLong();    // Main entry filter for BUY
   bool   AllowShort();  // Main entry filter for SELL
   
   //--- Structure-only filters
   bool   AllowLong_MS(); // Only Market Structure filter for BUY
   bool   AllowShort_MS();// Only Market Structure filter for SELL
   
   //--- Trend-only filters
   bool   AllowLong_MTF(); // Only MTF trend filter for BUY
   bool   AllowShort_MTF();// Only MTF trend filter for SELL
   
   //--- Info & Debug
   string GetTrendInfo();
   string GetStructureInfo();
   string GetFullInfo();   // Complete status string
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
   
   // Init order blocks
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
   datetime currentTime = Time[0];
   
   //--- 1. Update MTF Trend (always)
   UpdateMTFTrend();
   
   //--- 2. Update Market Structure (only on new bar or if dirty)
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
   //=== D1 Trend ===
   double d1Fast = iMA(NULL, g_MTF_Filter1, g_MTF_SMAPeriod1, 0, MODE_EMA, g_MTF_TrendPrice, 0);
   double d1Slow = iMA(NULL, g_MTF_Filter1, g_MTF_SMAPeriod2, 0, MODE_EMA, g_MTF_TrendPrice, 0);
   
   if(d1Fast > d1Slow) m_D1Trend = TREND_BULLISH;
   else if(d1Fast < d1Slow) m_D1Trend = TREND_BEARISH;
   else m_D1Trend = TREND_NEUTRAL;
   
   m_D1_MA_Fast = d1Fast;
   m_D1_MA_Slow = d1Slow;
   
   //=== H4 Trend ===
   double h4Fast = iMA(NULL, g_MTF_Filter2, g_MTF_SMAPeriod1, 0, MODE_EMA, g_MTF_TrendPrice, 0);
   double h4Slow = iMA(NULL, g_MTF_Filter2, g_MTF_SMAPeriod2, 0, MODE_EMA, g_MTF_TrendPrice, 0);
   
   if(h4Fast > h4Slow) m_H4Trend = TREND_BULLISH;
   else if(h4Fast < h4Slow) m_H4Trend = TREND_BEARISH;
   else m_H4Trend = TREND_NEUTRAL;
   
   m_H4_MA_Fast = h4Fast;
   m_H4_MA_Slow = h4Slow;
}

//+------------------------------------------------------------------+
//| Get MA Value                                                      |
//+------------------------------------------------------------------+
double CMSFilter::GetMAValue(ENUM_TIMEFRAMES tf, int period, int shift)
{
   return iMA(NULL, tf, period, 0, MODE_EMA, g_MTF_TrendPrice, shift);
}

//+------------------------------------------------------------------+
//| Detect Swing Points using Simple ZigZag-like method               |
//+------------------------------------------------------------------+
int CMSFilter::DetectSwingPoints()
{
   // Reset swings
   m_SwingCount = 0;
   ArrayResize(m_Swings, 0);
   
   int lookback = MathMin(g_MS_Lookback, 100);
   
   // Find local highs and lows
   for(int i = g_MS_SwingStrength + 1; i < lookback - g_MS_SwingStrength; i++)
   {
      // Check if this is a swing high
      bool isHigh = true;
      for(int j = 1; j <= g_MS_SwingStrength; j++)
      {
         if(High[i + j] >= High[i] || High[i - j] >= High[i])
         {
            isHigh = false;
            break;
         }
      }
      
      // Check if this is a swing low
      bool isLow = true;
      for(int j = 1; j <= g_MS_SwingStrength; j++)
      {
         if(Low[i + j] <= Low[i] || Low[i - j] <= Low[i])
         {
            isLow = false;
            break;
         }
      }
      
      if(isHigh)
      {
         ArrayResize(m_Swings, m_SwingCount + 1);
         m_Swings[m_SwingCount].bar = i;
         m_Swings[m_SwingCount].price = High[i];
         m_Swings[m_SwingCount].isHigh = true;
         m_SwingCount++;
      }
      else if(isLow)
      {
         ArrayResize(m_Swings, m_SwingCount + 1);
         m_Swings[m_SwingCount].bar = i;
         m_Swings[m_SwingCount].price = Low[i];
         m_Swings[m_SwingCount].isHigh = false;
         m_SwingCount++;
      }
   }
   
   return m_SwingCount;
}

//+------------------------------------------------------------------+
//| Check Break of Structure (BOS)                                    |
//-------------------------------------------------------------------+
bool CMSFilter::CheckBOS()
{
   if(m_SwingCount < 4) return false;
   
   // Need at least: previous high, previous low, current high, current low
   // Find most recent swings
   int lastHigh = -1, lastLow = -1, prevHigh = -1, prevLow = -1;
   
   for(int i = 0; i < m_SwingCount; i++)
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
   
   //=== Bullish BOS: Price breaks above previous higher high
   // Last high > Previous high (HH) and price breaks above it
   bool bullishBOS = (m_Swings[lastHigh].price > m_Swings[prevHigh].price) &&
                     (Close[0] > m_Swings[lastHigh].price + g_MS_BOSThreshold);
   
   //=== Bearish BOS: Price breaks below previous lower low
   // Last low < Previous low (LL) and price breaks below it
   bool bearishBOS = (m_Swings[lastLow].price < m_Swings[prevLow].price) &&
                     (Close[0] < m_Swings[lastLow].price - g_MS_BOSThreshold);
   
   if(bullishBOS)
   {
      m_LastStructure = BOS_BULLISH;
      m_LastBOS.price = m_Swings[lastHigh].price;
      m_LastBOS.bullish = true;
      m_LastBOS.broken = true;
      m_LastBOS.time = Time[m_Swings[lastHigh].bar];
      return true;
   }
   else if(bearishBOS)
   {
      m_LastStructure = BOS_BEARISH;
      m_LastBOS.price = m_Swings[lastLow].price;
      m_LastBOS.bullish = false;
      m_LastBOS.broken = true;
      m_LastBOS.time = Time[m_Swings[lastLow].bar];
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check Change of Character (CHoCH)                                  |
//+------------------------------------------------------------------+
bool CMSFilter::CheckCHoCH()
{
   if(m_SwingCount < 6) return false;
   
   // Collect last 4 swing points (2 highs, 2 lows minimum)
   double highs[2], lows[2];
   int hIdx = 0, lIdx = 0;
   
   for(int i = m_SwingCount - 1; i >= 0 && (hIdx < 2 || lIdx < 2); i--)
   {
      if(m_Swings[i].isHigh && hIdx < 2) highs[hIdx++] = m_Swings[i].price;
      else if(!m_Swings[i].isHigh && lIdx < 2) lows[lIdx++] = m_Swings[i].price;
   }
   
   if(hIdx < 2 || lIdx < 2) return false;
   
   //=== Bullish CHoCH: Price breaks above previous low (structure shift)
   // In uptrend we have HH/HL, CHoCH when LL forms after price breaks above a structure low
   bool bullishCHoCH = (highs[0] < highs[1]) &&  // Lower high (LH) formed
                      (Close[0] > highs[0]);     // But price still broke above
   
   //=== Bearish CHoCH: Price breaks below previous high
   bool bearishCHoCH = (lows[0] > lows[1]) &&    // Higher low (HL) formed
                      (Close[0] < lows[0]);      // But price broke below
   
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
   // Look back g_OB_Lookback bars for the last bearish/bullish candle body
   // that could be an order block
   
   double bullishOBHigh = 0, bullishOBLow = 0;
   double bearishOBHigh = 0, bearishOBLow = 0;
   int bullCount = 0, bearCount = 0;
   
   for(int i = 1; i <= g_OB_Lookback; i++)
   {
      double body = MathAbs(Close[i] - Open[i]);
      double range = High[i] - Low[i];
      
      // Bullish OB: Last bearish candle before current bullish move
      if(Close[i] < Open[i]) // Bearish candle
      {
         if(bullishOBLow == 0 || Low[i] < bullishOBLow)
         {
            bullishOBLow = Low[i];
            bullishOBHigh = High[i];
         }
         bullCount++;
      }
      
      // Bearish OB: Last bullish candle before current bearish move
      if(Close[i] > Open[i]) // Bullish candle
      {
         if(bearishOBHigh == 0 || High[i] > bearishOBHigh)
         {
            bearishOBHigh = High[i];
            bearishOBLow = Low[i];
         }
         bearCount++;
      }
   }
   
   // Set bullish OB if found
   if(bullCount > 0)
   {
      m_BullishOB.high = bullishOBHigh;
      m_BullishOB.low = bullishOBLow;
      m_BullishOB.time = Time[1];
      m_BullishOB.strength = bullCount;
      m_BullishOB.obType = OB_BULLISH;
   }
   
   // Set bearish OB if found
   if(bearCount > 0)
   {
      m_BearishOB.high = bearishOBHigh;
      m_BearishOB.low = bearishOBLow;
      m_BearishOB.time = Time[1];
      m_BearishOB.strength = bearCount;
      m_BearishOB.obType = OB_BEARISH;
   }
}

//+------------------------------------------------------------------+
//| Get Combined Trend (D1 + H4)                                      |
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
//| Check Bullish Structure (HH/HL or BOS Bullish)                    |
//+------------------------------------------------------------------+
bool CMSFilter::IsBullishStructure()
{
   if(!g_MS_Enabled) return true;
   
   // Check for bullish structure signals
   if(m_LastStructure == BOS_BULLISH) return true;
   if(m_LastStructure == CHOC_BULLISH) return true;
   
   // Check swing points for HH/HL pattern
   if(m_SwingCount >= 4)
   {
      // Last 2 highs and 2 lows
      double recentHighs[2], recentLows[2];
      int hCount = 0, lCount = 0;
      
      for(int i = m_SwingCount - 1; i >= 0 && (hCount < 2 || lCount < 2); i--)
      {
         if(m_Swings[i].isHigh && hCount < 2) recentHighs[hCount++] = m_Swings[i].price;
         else if(!m_Swings[i].isHigh && lCount < 2) recentLows[lCount++] = m_Swings[i].price;
      }
      
      // Bullish structure: HH and HL
      if(hCount >= 2 && lCount >= 2)
      {
         return (recentHighs[0] > recentHighs[1] && recentLows[0] > recentLows[1]);
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check Bearish Structure (LH/LL or BOS Bearish)                    |
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
      
      // Bearish structure: LH and LL
      if(hCount >= 2 && lCount >= 2)
      {
         return (recentHighs[0] < recentHighs[1] && recentLows[0] < recentLows[1]);
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if price is in Bullish Order Block                          |
//+------------------------------------------------------------------+
bool CMSFilter::IsPriceInBullishOB(double price)
{
   if(!g_MS_Enabled || !g_OB_Enabled) return false;
   if(m_BullishOB.obType != OB_BULLISH) return false;
   
   return (price >= m_BullishOB.low && price <= m_BullishOB.high);
}

//+------------------------------------------------------------------+
//| Check if price is in Bearish Order Block                          |
//+------------------------------------------------------------------+
bool CMSFilter::IsPriceInBearishOB(double price)
{
   if(!g_MS_Enabled || !g_OB_Enabled) return false;
   if(m_BearishOB.obType != OB_BEARISH) return false;
   
   return (price >= m_BearishOB.low && price <= m_BearishOB.high);
}

//+------------------------------------------------------------------+
//| MAIN ENTRY FILTER: Allow Long                                     |
//| Combined MTF + Market Structure + Order Block                     |
//+------------------------------------------------------------------+
bool CMSFilter::AllowLong()
{
   //=== Step 1: MTF Trend Check ===
   if(g_MTF_Enabled)
   {
      ENUM_TREND_DIRECTION trend = GetCombinedTrend();
      if(trend == TREND_BEARISH)
      {
         Print("[MTF+MS] LONG blocked — MTF trend is BEARISH");
         return false;
      }
   }
   
   //=== Step 2: Market Structure Check ===
   if(g_MS_Enabled)
   {
      // Need bullish structure for LONG
      if(!IsBullishStructure())
      {
         Print("[MTF+MS] LONG blocked — Market Structure is not bullish");
         return false;
      }
   }
   
   //=== Step 3: Order Block Confirmation (optional) ===
   // If price is at bullish OB, it's a stronger signal
   // But if NOT at OB, we still allow (OB is bonus filter)
   
   return true;
}

//+------------------------------------------------------------------+
//| MAIN ENTRY FILTER: Allow Short                                    |
//+------------------------------------------------------------------+
bool CMSFilter::AllowShort()
{
   //=== Step 1: MTF Trend Check ===
   if(g_MTF_Enabled)
   {
      ENUM_TREND_DIRECTION trend = GetCombinedTrend();
      if(trend == TREND_BULLISH)
      {
         Print("[MTF+MS] SHORT blocked — MTF trend is BULLISH");
         return false;
      }
   }
   
   //=== Step 2: Market Structure Check ===
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
//| Market Structure Only: Allow Long                                |
//+------------------------------------------------------------------+
bool CMSFilter::AllowLong_MS()
{
   if(!g_MS_Enabled) return true;
   return IsBullishStructure();
}

//+------------------------------------------------------------------+
//| Market Structure Only: Allow Short                                |
//+------------------------------------------------------------------+
bool CMSFilter::AllowShort_MS()
{
   if(!g_MS_Enabled) return true;
   return IsBearishStructure();
}

//+------------------------------------------------------------------+
//| MTF Trend Only: Allow Long                                       |
//+------------------------------------------------------------------+
bool CMSFilter::AllowLong_MTF()
{
   if(!g_MTF_Enabled) return true;
   ENUM_TREND_DIRECTION trend = GetCombinedTrend();
   return (trend != TREND_BEARISH);
}

//+------------------------------------------------------------------+
//| MTF Trend Only: Allow Short                                       |
//+------------------------------------------------------------------+
bool CMSFilter::AllowShort_MTF()
{
   if(!g_MTF_Enabled) return true;
   ENUM_TREND_DIRECTION trend = GetCombinedTrend();
   return (trend != TREND_BULLISH);
}

//+------------------------------------------------------------------+
//| Get Trend Info String                                             |
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
//| Get Structure Info String                                         |
//+------------------------------------------------------------------+
string CMSFilter::GetStructureInfo()
{
   string structStr, bosStr = "";
   
   // Structure type
   if(m_LastStructure == BOS_BULLISH) structStr = "BOS_BULL";
   else if(m_LastStructure == BOS_BEARISH) structStr = "BOS_BEAR";
   else if(m_LastStructure == CHOC_BULLISH) structStr = "CHoCH_BULL";
   else if(m_LastStructure == CHOC_BEARISH) structStr = "CHoCH_BEAR";
   else structStr = "NONE";
   
   // Order blocks
   if(g_MS_Enabled && g_OB_Enabled)
   {
      if(m_BullishOB.obType == OB_BULLISH)
         bosStr = StringFormat(" | BullOB:%.5f-%.5f", m_BullishOB.low, m_BullishOB.high);
      if(m_BearishOB.obType == OB_BEARISH)
         bosStr += StringFormat(" | BearOB:%.5f-%.5f", m_BearishOB.low, m_BearishOB.high);
   }
   
   return StringFormat("[MS:%s]%s", structStr, bosStr);
}

//+------------------------------------------------------------------+
//| Get Full Status Info                                              |
//+------------------------------------------------------------------+
string CMSFilter::GetFullInfo()
{
   return StringFormat("MTF+MS FILTER\n===============\nTrend: %s\nStructure: %s",
                       GetTrendInfo(), GetStructureInfo());
}

//+------------------------------------------------------------------+
//| END OF MODULE                                                     |
//+------------------------------------------------------------------+