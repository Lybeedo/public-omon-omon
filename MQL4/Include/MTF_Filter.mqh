//+------------------------------------------------------------------+
//|                              MTF_Filter.mqh                       |
//|                           Multi Timeframe Filter Module           |
//|                                v1.0                               |
//+------------------------------------------------------------------+
#property copyright "EFI SMART Trading System"
#property strict

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+

// Trend Detection Settings
input bool   g_MTF_Enabled        = true;        // Enable MTF Filter
input int    g_MTF_TrendPeriod    = 50;          // Trend MA Period
input ENUM_APPLIED_PRICE g_MTF_TrendPrice = PRICE_CLOSE; // Trend Price Type

// Timeframe Filter Settings
input ENUM_TIMEFRAMES g_MTF_Filter1  = PERIOD_D1; // Filter Timeframe 1 (Higher)
input ENUM_TIMEFRAMES g_MTF_Filter2  = PERIOD_H4; // Filter Timeframe 2 (Lower)

// Trend Confirmation
input int    g_MTF_SMAPeriod1    = 20;           // SMA Period 1 (Fast)
input int    g_MTF_SMAPeriod2    = 50;           // SMA Period 2 (Slow)

//+------------------------------------------------------------------+
//| ENUMERATIONS                                                     |
//+------------------------------------------------------------------+

enum ENUM_TREND_DIRECTION
{
   TREND_BULLISH = 1,    // Uptrend
   TREND_BEARISH = -1,   // Downtrend
   TREND_NEUTRAL = 0     // No clear trend
};

//+------------------------------------------------------------------+
//| CLASS: MTF Filter Engine                                          |
//+------------------------------------------------------------------+
class CMtfFilter
{
private:
   //--- Trend Detection
   ENUM_TREND_DIRECTION m_D1Trend;      // D1 trend direction
   ENUM_TREND_DIRECTION m_H4Trend;      // H4 trend direction
   
   //--- MA Values
   double m_D1_MA_Fast;                  // D1 Fast MA
   double m_D1_MA_Slow;                  // D1 Slow MA
   double m_H4_MA_Fast;                  // H4 Fast MA
   double m_H4_MA_Slow;                  // H4 Slow MA
   
   //--- Price Structure
   double m_D1_Highs[3];                 // D1 last 3 highs
   double m_D1_Lows[3];                  // D1 last 3 lows
   double m_H4_Highs[3];                 // H4 last 3 highs
   double m_H4_Lows[3];                  // H4 last 3 lows
   
   //--- Helper Methods
   double GetMAValue(ENUM_TIMEFRAMES tf, int period, int shift);
   bool   CheckHHHL(ENUM_TIMEFRAMES tf, double &highs[], double &lows[]);
   ENUM_TREND_DIRECTION CombinedTrendDetection(ENUM_TIMEFRAMES tf);
   
public:
   //--- Constructor/Destructor
   CMtfFilter();
   ~CMtfFilter();
   
   //--- Core Methods
   void Refresh();
   
   //--- Trend Direction (MTF)
   ENUM_TREND_DIRECTION GetD1Trend()   { return m_D1Trend; }
   ENUM_TREND_DIRECTION GetH4Trend()   { return m_H4Trend; }
   
   //--- Combined Trend (D1 + H4)
   ENUM_TREND_DIRECTION GetCombinedTrend();
   
   //--- Check if signal aligns with trend
   bool   IsBullishAligned();   // Returns true if all MAs bullish
   bool   IsBearishAligned();   // Returns true if all MAs bearish
   
   //--- Filter Results
   bool   AllowLong();
   bool   AllowShort();
   
   //--- Info String (for display)
   string GetTrendInfo();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CMtfFilter::CMtfFilter()
{
   m_D1Trend = TREND_NEUTRAL;
   m_H4Trend = TREND_NEUTRAL;
   m_D1_MA_Fast = 0;
   m_D1_MA_Slow = 0;
   m_H4_MA_Fast = 0;
   m_H4_MA_Slow = 0;
   
   ArrayInitialize(m_D1_Highs, 0);
   ArrayInitialize(m_D1_Lows, 0);
   ArrayInitialize(m_H4_Highs, 0);
   ArrayInitialize(m_H4_Lows, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CMtfFilter::~CMtfFilter()
{
}

//+------------------------------------------------------------------+
//| Get MA Value for specific timeframe                              |
//+------------------------------------------------------------------+
double CMtfFilter::GetMAValue(ENUM_TIMEFRAMES tf, int period, int shift)
{
   return iMA(NULL, tf, period, 0, MODE_EMA, g_MTF_TrendPrice, shift);
}

//+------------------------------------------------------------------+
//| Check Higher High / Higher Low pattern                           |
//+------------------------------------------------------------------+
bool CMtfFilter::CheckHHHL(ENUM_TIMEFRAMES tf, double &highs[], double &lows[])
{
   // Get last 3 swing highs and lows
   for(int i = 0; i < 3; i++)
   {
      highs[i] = iHigh(NULL, tf, i);
      lows[i]  = iLow(NULL, tf, i);
   }
   
   // Bullish: Higher Highs AND Higher Lows
   bool bullishPattern = (highs[1] > highs[2] && highs[0] > highs[1]) &&
                         (lows[1] > lows[2] && lows[0] > lows[1]);
   
   // Bearish: Lower Highs AND Lower Lows
   bool bearishPattern = (highs[1] < highs[2] && highs[0] < highs[1]) &&
                        (lows[1] < lows[2] && lows[0] < lows[1]);
   
   return bullishPattern || bearishPattern;
}

//+------------------------------------------------------------------+
//| Combined Trend Detection (HHHL + MA Crossover)                   |
//+------------------------------------------------------------------+
ENUM_TREND_DIRECTION CMtfFilter::CombinedTrendDetection(ENUM_TIMEFRAMES tf)
{
   //--- 1. Price Structure Analysis (HHHL)
   double highs[], lows[];
   ArrayResize(highs, 3);
   ArrayResize(lows, 3);
   bool hasHHHL = CheckHHHL(tf, highs, lows);
   
   //--- 2. MA Crossover Analysis
   double maFast = GetMAValue(tf, g_MTF_SMAPeriod1, 0);
   double maSlow = GetMAValue(tf, g_MTF_SMAPeriod2, 0);
   double maFastPrev = GetMAValue(tf, g_MTF_SMAPeriod1, 1);
   double maSlowPrev = GetMAValue(tf, g_MTF_SMAPeriod2, 1);
   
   bool maBullish = (maFast > maSlow) && (maFastPrev <= maSlowPrev);
   bool maBearish = (maFast < maSlow) && (maFastPrev >= maSlowPrev);
   bool maAlignedBullish = maFast > maSlow;
   bool maAlignedBearish = maFast < maSlow;
   
   //--- 3. Combine Both Methods
   ENUM_TREND_DIRECTION trend = TREND_NEUTRAL;
   
   // Need at least MA alignment + 1 confirmation (HHHL or strong MA signal)
   if(maAlignedBullish && !maAlignedBearish)
   {
      trend = TREND_BULLISH;
   }
   else if(maAlignedBearish && !maAlignedBullish)
   {
      trend = TREND_BEARISH;
   }
   
   return trend;
}

//+------------------------------------------------------------------+
//| Refresh - Update all MTF data                                    |
//+------------------------------------------------------------------+
void CMtfFilter::Refresh()
{
   if(!g_MTF_Enabled) return;
   
   //--- Get D1 Trend
   m_D1Trend = CombinedTrendDetection(g_MTF_Filter1);
   
   //--- Get H4 Trend  
   m_H4Trend = CombinedTrendDetection(g_MTF_Filter2);
   
   //--- Store MA values for display
   m_D1_MA_Fast = GetMAValue(g_MTF_Filter1, g_MTF_SMAPeriod1, 0);
   m_D1_MA_Slow = GetMAValue(g_MTF_Filter1, g_MTF_SMAPeriod2, 0);
   m_H4_MA_Fast = GetMAValue(g_MTF_Filter2, g_MTF_SMAPeriod1, 0);
   m_H4_MA_Slow = GetMAValue(g_MTF_Filter2, g_MTF_SMAPeriod2, 0);
}

//+------------------------------------------------------------------+
//| Get Combined Trend (D1 + H4)                                     |
//+------------------------------------------------------------------+
ENUM_TREND_DIRECTION CMtfFilter::GetCombinedTrend()
{
   if(!g_MTF_Enabled) return TREND_NEUTRAL;
   
   // Both must agree for strong signal
   if(m_D1Trend == m_H4Trend && m_D1Trend != TREND_NEUTRAL)
   {
      return m_D1Trend;  // Strong confirmation
   }
   
   // D1 dominates if H4 is neutral
   if(m_D1Trend != TREND_NEUTRAL && m_H4Trend == TREND_NEUTRAL)
   {
      return m_D1Trend;
   }
   
   // H4 can confirm D1 trend
   if(m_D1Trend == m_H4Trend)
   {
      return m_D1Trend;
   }
   
   return TREND_NEUTRAL;
}

//+------------------------------------------------------------------+
//| Check if all MAs are bullish aligned                            |
//+------------------------------------------------------------------+
bool CMtfFilter::IsBullishAligned()
{
   if(!g_MTF_Enabled) return true;
   
   bool d1Bullish = (m_D1_MA_Fast > m_D1_MA_Slow);
   bool h4Bullish = (m_H4_MA_Fast > m_H4_MA_Slow);
   
   return d1Bullish && h4Bullish;
}

//+------------------------------------------------------------------+
//| Check if all MAs are bearish aligned                             |
//+------------------------------------------------------------------+
bool CMtfFilter::IsBearishAligned()
{
   if(!g_MTF_Enabled) return true;
   
   bool d1Bearish = (m_D1_MA_Fast < m_D1_MA_Slow);
   bool h4Bearish = (m_H4_MA_Fast < m_H4_MA_Slow);
   
   return d1Bearish && h4Bearish;
}

//+------------------------------------------------------------------+
//| Allow Long Position                                               |
//+------------------------------------------------------------------+
bool CMtfFilter::AllowLong()
{
   if(!g_MTF_Enabled) return true;
   
   // Allow LONG if trend is BULLISH or NEUTRAL
   ENUM_TREND_DIRECTION trend = GetCombinedTrend();
   
   return (trend == TREND_BULLISH || trend == TREND_NEUTRAL);
}

//+------------------------------------------------------------------+
//| Allow Short Position                                             |
//+------------------------------------------------------------------+
bool CMtfFilter::AllowShort()
{
   if(!g_MTF_Enabled) return true;
   
   // Allow SHORT if trend is BEARISH or NEUTRAL
   ENUM_TREND_DIRECTION trend = GetCombinedTrend();
   
   return (trend == TREND_BEARISH || trend == TREND_NEUTRAL);
}

//+------------------------------------------------------------------+
//| Get Trend Info String for Display                                 |
//+------------------------------------------------------------------+
string CMtfFilter::GetTrendInfo()
{
   string trendD1, trendH4, combined;
   
   if(m_D1Trend == TREND_BULLISH) trendD1 = "BULL";
   else if(m_D1Trend == TREND_BEARISH) trendD1 = "BEAR";
   else trendD1 = "NEUT";
   
   if(m_H4Trend == TREND_BULLISH) trendH4 = "BULL";
   else if(m_H4Trend == TREND_BEARISH) trendH4 = "BEAR";
   else trendH4 = "NEUT";
   
   ENUM_TREND_DIRECTION comb = GetCombinedTrend();
   if(comb == TREND_BULLISH) combined = "BULL";
   else if(comb == TREND_BEARISH) combined = "BEAR";
   else combined = "NEUT";
   
   return StringFormat("D1:%s | H4:%s | CFX:%s", trendD1, trendH4, combined);
}

//+------------------------------------------------------------------+
//| END OF MTF FILTER MODULE                                         |
//+------------------------------------------------------------------+