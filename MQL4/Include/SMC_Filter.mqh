//+------------------------------------------------------------------+
//|                              SMC_Filter.mqh                        |
//|                  Smart Money Concepts Filter Module               |
//|                        v1.0 — BOS/CHoCH/FVG/Inducement            |
//+------------------------------------------------------------------+
#property copyright "EFI SMART Trading System"
#property strict

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+

//=== FVG (Fair Value Gap) Settings ===
input bool   g_FVG_Enabled     = true;            // Enable FVG Filter
input int    g_FVG_Lookback    = 20;              // Bars to look for FVG

//=== Inducement Detection Settings ===
input bool   g_IND_Enabled     = true;            // Enable Inducement Detection
input int    g_IND_Lookback    = 50;              // Lookback for inducement
input double g_IND_MinMove     = 1.5;             // Min move size for inducement (ATR multiplier)
input int    g_IND_ATRPeriod   = 14;             // ATR period for inducement

//=== CHoCH (Change of Character) Settings ===
input bool   g_CHOCH_Enabled   = true;           // Enable CHoCH Detection

//=== Order Block Settings ===
input bool   g_OB_Enabled      = true;            // Enable Order Block zones
input int    g_OB_Lookback     = 10;              // Bars to check for OB

//=== MTF Trend (optional) ===
input bool   g_MTF_Enabled     = true;           // Enable MTF Trend Filter
input int    g_MTF_SMAPeriod1  = 20;             // Fast SMA
input int    g_MTF_SMAPeriod2  = 50;             // Slow SMA

//=== FILTER MODE ===
input bool   g_StrictMode      = false;          // If true, all filters must pass. If false, any 1 pass = allow

//+------------------------------------------------------------------+
//| ENUMERATIONS                                                      |
//+------------------------------------------------------------------+

enum ENUM_SMC_TREND
{
   SMC_BULL = 1,     // Bullish trend/structure
   SMC_BEAR = -1,    // Bearish trend/structure
   SMC_NEUT = 0      // Neutral
};

enum ENUM_FVG_TYPE
{
   FVG_BULLISH =  1,  // Bullish FVG (below price = buy zone)
   FVG_BEARISH = -1,  // Bearish FVG (above price = sell zone)
   FVG_NONE    =  0
};

enum ENUM_IND_RESULT
{
   IND_BULLISH =  1,  // Bullish inducement (fake dump, reversal up)
   IND_BEARISH = -1,  // Bearish inducement (fake pump, reversal down)
   IND_NONE    =  0   // No inducement pattern
};

//+------------------------------------------------------------------+
//| STRUCTURES                                                        |
//+------------------------------------------------------------------+

struct SFVG
{
   double   upper;          // Upper boundary of the gap
   double   lower;          // Lower boundary of the gap
   double   mid;            // Midpoint of the gap
   datetime time;           // Time when FVG was formed
   ENUM_FVG_TYPE fvgType;   // Bullish or Bearish
   bool     active;         // Is this FVG still valid (not filled)?
};

struct SInducement
{
   double   peak;           // Highest point of the move
   double   base;           // Base area before the spike
   datetime time;           // When the inducement formed
   double   atr;            // ATR at time of formation
   ENUM_IND_RESULT indType; // Bullish or Bearish
   bool     active;         // Still valid?
};

struct SOrderBlock
{
   double   high;
   double   low;
   datetime time;
   ENUM_SMC_TREND obType;  // Bullish or Bearish OB
   bool     active;
};

//+------------------------------------------------------------------+
//| CLASS: SMC Filter Engine                                           |
//+------------------------------------------------------------------+
class CSMCFilter
{
private:
   //=== Trend ===
   ENUM_SMC_TREND m_Trend;
   double m_MTF_MA_Fast;
   double m_MTF_MA_Slow;
   
   //=== FVG ===
   SFVG m_BullFVG;         // Latest bullish FVG (untested)
   SFVG m_BearFVG;         // Latest bearish FVG (untested)
   
   //=== Inducement ===
   SInducement m_BullInd;  // Latest bullish inducement
   SInducement m_BearInd;  // Latest bearish inducement
   
   //=== CHoCH ===
   ENUM_SMC_TREND m_LastCHoCH;
   
   //=== Order Blocks ===
   SOrderBlock m_BullOB;
   SOrderBlock m_BearOB;
   
   //=== Helper Methods ===
   double GetATR(int period);
   double GetMA(int period, ENUM_APPLIED_PRICE priceType);
   ENUM_SMC_TREND DetectMTFTrend();
   ENUM_FVG_TYPE CheckFVG(int shift);
   ENUM_IND_RESULT DetectInducement(int shift);
   void DetectOrderBlocks(int shift);
   ENUM_SMC_TREND DetectCHoCH();
   bool IsFVGActive(SFVG &fvg);
   
   //=== Cache ===
   datetime m_LastRefresh;
   bool     m_CacheDirty;
   
public:
   //--- Constructor
   CSMCFilter();
   ~CSMCFilter();
   
   //--- Core Methods
   void Refresh();
   void ForceRefresh() { m_CacheDirty = true; }
   
   //--- Main Entry Filters
   bool AllowLong();    // Combined SMC filter for BUY
   bool AllowShort();   // Combined SMC filter for SELL
   
   //--- Individual Filters
   bool AllowLong_BOS();   // Break of Structure only
   bool AllowShort_BOS();  // Break of Structure only
   bool IsInFVG(double price);   // Is price inside any FVG?
   bool IsInducementBullish();   // Was last move a bullish inducement?
   bool IsInducementBearish();   // Was last move a bearish inducement?
   bool IsAtBullOB(double price); // Is price at bullish order block?
   bool IsAtBearOB(double price);  // Is price at bearish order block?
   
   //--- Info Methods
   string GetFilterInfo();       // Quick status
   string GetDetailedInfo();     // Full breakdown
   ENUM_SMC_TREND GetTrend() { return m_Trend; }
};

//+------------------------------------------------------------------+
//| Constructor                                                        |
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
//| Destructor                                                         |
//+------------------------------------------------------------------+
CSMCFilter::~CSMCFilter()
{
}

//+------------------------------------------------------------------+
//| Refresh - Update all SMC data                                     |
//+------------------------------------------------------------------+
void CSMCFilter::Refresh()
{
   datetime curTime = Time[0];
   
   // Only refresh on new bar or if dirty
   if(m_CacheDirty || curTime != m_LastRefresh)
   {
      //--- Update MTF Trend
      if(g_MTF_Enabled)
         m_Trend = DetectMTFTrend();
      
      //--- Check FVG (look back a few bars)
      for(int i = 1; i <= 3; i++)
      {
         ENUM_FVG_TYPE fvg = CheckFVG(i);
         if(fvg == FVG_BULLISH && !m_BullFVG.active)
         {
            m_BullFVG.active = true;
            m_BullFVG.time = Time[i];
         }
         else if(fvg == FVG_BEARISH && !m_BearFVG.active)
         {
            m_BearFVG.active = true;
            m_BearFVG.time = Time[i];
         }
      }
      
      //--- Detect Inducement
      DetectInducement(0);
      
      //--- Detect Order Blocks
      DetectOrderBlocks(1);
      
      //--- Check CHoCH
      if(g_CHOCH_Enabled)
         m_LastCHoCH = DetectCHoCH();
      
      m_CacheDirty = false;
      m_LastRefresh = curTime;
   }
}

//+------------------------------------------------------------------+
//| Get ATR Value                                                      |
//+------------------------------------------------------------------+
double CSMCFilter::GetATR(int period)
{
   double trs[];
   ArrayResize(trs, period);
   double sum = 0;
   
   for(int i = 1; i <= period; i++)
   {
      double tr = High[i] - Low[i];
      tr = MathMax(tr, MathAbs(High[i] - Close[i+1]));
      tr = MathMax(tr, MathAbs(Low[i] - Close[i+1]));
      sum += tr;
   }
   
   return sum / period;
}

//+------------------------------------------------------------------+
//| Get MA Value (current bar)                                        |
//+------------------------------------------------------------------+
double CSMCFilter::GetMA(int period, ENUM_APPLIED_PRICE priceType)
{
   return iMA(NULL, 0, period, 0, MODE_EMA, priceType, 0);
}

//+------------------------------------------------------------------+
//| Detect MTF Trend (using H4 as higher TF proxy)                   |
//+------------------------------------------------------------------+
ENUM_SMC_TREND CSMCFilter::DetectMTFTrend()
{
   // Use D1/H4 MA on current chart as proxy
   double fast = iMA(NULL, PERIOD_H4, g_MTF_SMAPeriod1, 0, MODE_EMA, PRICE_CLOSE, 0);
   double slow = iMA(NULL, PERIOD_H4, g_MTF_SMAPeriod2, 0, MODE_EMA, PRICE_CLOSE, 0);
   double fast2 = iMA(NULL, PERIOD_D1, g_MTF_SMAPeriod1, 0, MODE_EMA, PRICE_CLOSE, 0);
   double slow2 = iMA(NULL, PERIOD_D1, g_MTF_SMAPeriod2, 0, MODE_EMA, PRICE_CLOSE, 0);
   
   m_MTF_MA_Fast = (fast + fast2) / 2;
   m_MTF_MA_Slow = (slow + slow2) / 2;
   
   // Bullish: both TF agree
   if(fast > slow && fast2 > slow2) return SMC_BULL;
   // Bearish: both TF agree
   if(fast < slow && fast2 < slow2) return SMC_BEAR;
   // Neutral: conflicting
   return SMC_NEUT;
}

//+------------------------------------------------------------------+
//| Check FVG (Fair Value Gap) at specific bar                        |
//| FVG = when bar[i+1] is 100% inside gap between bar[i] and bar[i+2] |
//+------------------------------------------------------------------+
ENUM_FVG_TYPE CSMCFilter::CheckFVG(int shift)
{
   // FVG formation: 3 consecutive bars
   // Bullish FVG: bar[i] up, bar[i+1] up (opens above bar[i]'s high), bar[i+2] up (closes above bar[i+1]'s high)
   //             The gap = High[i] > Low[i+2] (imbalance area)
   // Bearish FVG: bar[i] down, bar[i+1] down (opens below bar[i]'s low), bar[i+2] down (closes below bar[i+1]'s low)
   //             The gap = Low[i] < High[i+2]
   
   // Check for Bullish FVG: bar i+1 fully above bar i-1's high (gap up)
   // Or check: High[i-1] < Low[i+1] for 3-bar bullish FVG
   if(shift < 2) return FVG_NONE;
   
   // 3-bar FVG pattern
   double high_i   = High[shift];
   double low_i    = Low[shift];
   double open_i   = Open[shift];
   double close_i  = Close[shift];
   
   double high_i1  = High[shift + 1];
   double low_i1   = Low[shift + 1];
   double open_i1  = Open[shift + 1];
   double close_i1 = Close[shift + 1];
   
   double high_i2  = High[shift + 2];
   double low_i2   = Low[shift + 2];
   double open_i2  = Open[shift + 2];
   double close_i2 = Close[shift + 2];
   
   // Bullish FVG: middle candle is bullish and there's a gap between candle 1 and 3
   // Imbalance: Low[shift+1] > High[shift+2]
   bool bullFVG = (close_i1 > open_i1) &&            // middle candle is bullish
                  (Low[shift + 1] > High[shift + 2]); // gap below the middle candle
   
   // Bearish FVG: middle candle is bearish and there's a gap between candle 1 and 3
   bool bearFVG = (close_i1 < open_i1) &&            // middle candle is bearish
                  (High[shift + 1] < Low[shift + 2]); // gap above the middle candle
   
   if(bullFVG)
   {
      // Record FVG details
      m_BullFVG.upper = Low[shift + 1];
      m_BullFVG.lower = High[shift + 2];
      m_BullFVG.mid = (m_BullFVG.upper + m_BullFVG.lower) / 2;
      m_BullFVG.fvgType = FVG_BULLISH;
      m_BullFVG.active = true;
      return FVG_BULLISH;
   }
   
   if(bearFVG)
   {
      m_BearFVG.lower = High[shift + 1];
      m_BearFVG.upper = Low[shift + 2];
      m_BearFVG.mid = (m_BearFVG.upper + m_BearFVG.lower) / 2;
      m_BearFVG.fvgType = FVG_BEARISH;
      m_BearFVG.active = true;
      return FVG_BEARISH;
   }
   
   return FVG_NONE;
}

//+------------------------------------------------------------------+
//| Detect Inducement (Liquidity Sweep / False Breakout)              |
//+------------------------------------------------------------------+
ENUM_IND_RESULT CSMCFilter::DetectInducement(int shift)
{
   // Inducement = sharp spike/spike through key level followed by reversal
   // Bullish Inducement: price spikes down (below recent low), then reverses up
   // Bearish Inducement: price spikes up (above recent high), then reverses down
   
   double atr = GetATR(g_IND_ATRPeriod);
   
   // Look for spikes
   for(int i = 1; i <= g_IND_Lookback; i++)
   {
      double range_i   = High[i] - Low[i];
      double range_avg = 0;
      for(int j = 1; j <= 10; j++) range_avg += (High[j+i] - Low[j+i]);
      range_avg /= 10;
      
      // Check if this bar is a spike (much larger than average)
      if(range_i < atr * g_IND_MinMove) continue;
      
      // Bearish Inducement: bar i is bullish spike above local high, followed by reversal down
      if(Close[i] > Open[i]) // Bullish bar
      {
         double localHigh = High[i];
         for(int j = 1; j <= 5; j++) localHigh = MathMax(localHigh, High[i+j]);
         
         // Spike through resistance followed by 2+ bearish candles
         if(i < g_IND_Lookback - 3)
         {
            int bearCount = 0;
            for(int j = 1; j <= 3; j++)
            {
               if(Close[i+j] < Open[i+j]) bearCount++;
            }
            
            if(bearCount >= 2)
            {
               // This looks like a bearish inducement (fake breakout up)
               m_BearInd.peak = localHigh;
               m_BearInd.base = Low[i];
               m_BearInd.time = Time[i];
               m_BearInd.atr = atr;
               m_BearInd.indType = IND_BEARISH;
               m_BearInd.active = true;
               return IND_BEARISH;
            }
         }
      }
      
      // Bullish Inducement: bar i is bearish spike below local low, followed by reversal up
      if(Close[i] < Open[i]) // Bearish bar
      {
         double localLow = Low[i];
         for(int j = 1; j <= 5; j++) localLow = MathMin(localLow, Low[i+j]);
         
         if(i < g_IND_Lookback - 3)
         {
            int bullCount = 0;
            for(int j = 1; j <= 3; j++)
            {
               if(Close[i+j] > Open[i+j]) bullCount++;
            }
            
            if(bullCount >= 2)
            {
               m_BullInd.peak = localLow;
               m_BullInd.base = High[i];
               m_BullInd.time = Time[i];
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
//| Detect Order Blocks                                               |
//+------------------------------------------------------------------+
void CSMCFilter::DetectOrderBlocks(int shift)
{
   // Bullish OB: last bearish candle before current bullish momentum
   // Bearish OB: last bullish candle before current bearish momentum
   
   for(int i = shift; i <= g_OB_Lookback; i++)
   {
      double body = MathAbs(Close[i] - Open[i]);
      
      // Bullish OB: bearish candle
      if(Close[i] < Open[i])
      {
         // Check if next few candles are bullish (momentum shift)
         bool hasMomentum = false;
         for(int j = 1; j <= 3; j++)
         {
            if(Close[i+j] > Open[i+j]) hasMomentum = true;
         }
         
         if(hasMomentum && body > 0)
         {
            m_BullOB.high = High[i];
            m_BullOB.low = Low[i];
            m_BullOB.time = Time[i];
            m_BullOB.obType = SMC_BULL;
            m_BullOB.active = true;
         }
      }
      
      // Bearish OB: bullish candle
      if(Close[i] > Open[i])
      {
         bool hasMomentum = false;
         for(int j = 1; j <= 3; j++)
         {
            if(Close[i+j] < Open[i+j]) hasMomentum = true;
         }
         
         if(hasMomentum && body > 0)
         {
            m_BearOB.high = High[i];
            m_BearOB.low = Low[i];
            m_BearOB.time = Time[i];
            m_BearOB.obType = SMC_BEAR;
            m_BearOB.active = true;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Detect CHoCH (Change of Character)                               |
//+------------------------------------------------------------------+
ENUM_SMC_TREND CSMCFilter::DetectCHoCH()
{
   // CHoCH = lower high + break below previous low (bullish shift)
   //        or higher low + break above previous high (bearish shift)
   
   if(g_CHOCH_Enabled && g_FVG_Enabled)
   {
      // Simple approach: use FVG direction as CHoCH proxy
      if(m_BullFVG.active) return SMC_BULL;
      if(m_BearFVG.active) return SMC_BEAR;
   }
   
   // Check for swing structure shift
   double recentHighs[3];
   double recentLows[3];
   int hCount = 0, lCount = 0;
   
   for(int i = 1; i <= 30 && (hCount < 3 || lCount < 3); i++)
   {
      bool isHigh = true;
      for(int j = 1; j <= 3; j++)
      {
         if(High[i+j] >= High[i] || High[i-j] >= High[i]) { isHigh = false; break; }
      }
      bool isLow = true;
      for(int j = 1; j <= 3; j++)
      {
         if(Low[i+j] <= Low[i] || Low[i-j] <= Low[i]) { isLow = false; break; }
      }
      
      if(isHigh && hCount < 3) recentHighs[hCount++] = High[i];
      if(isLow && lCount < 3) recentLows[lCount++] = Low[i];
   }
   
   if(hCount >= 2 && lCount >= 2)
   {
      // Bullish CHoCH: lower high + break above previous low
      bool lowerHigh = recentHighs[0] < recentHighs[1];
      bool breakAbove = Close[0] > recentLows[0];
      
      // Bearish CHoCH: higher low + break below previous high
      bool higherLow = recentLows[0] > recentLows[1];
      bool breakBelow = Close[0] < recentHighs[0];
      
      if(lowerHigh && breakAbove) return SMC_BULL;
      if(higherLow && breakBelow) return SMC_BEAR;
   }
   
   return SMC_NEUT;
}

//+------------------------------------------------------------------+
//| Is FVG Still Active (not fully filled)?                           |
//+------------------------------------------------------------------+
bool CSMCFilter::IsFVGActive(SFVG &fvg)
{
   if(!fvg.active) return false;
   
   if(fvg.fvgType == FVG_BULLISH)
   {
      // Bullish FVG is active if price hasn't filled the gap below
      // Filled when price goes below the gap
      return (Close[0] > fvg.lower);
   }
   else if(fvg.fvgType == FVG_BEARISH)
   {
      return (Close[0] < fvg.upper);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if price is inside any FVG                                  |
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
//| Is At Bullish Order Block                                         |
//+------------------------------------------------------------------+
bool CSMCFilter::IsAtBullOB(double price)
{
   if(!g_OB_Enabled || !m_BullOB.active) return false;
   double range = (m_BullOB.high - m_BullOB.low) * 0.5; // 50% buffer
   return (price >= m_BullOB.low - range && price <= m_BullOB.high + range);
}

//+------------------------------------------------------------------+
//| Is At Bearish Order Block                                         |
//+------------------------------------------------------------------+
bool CSMCFilter::IsAtBearOB(double price)
{
   if(!g_OB_Enabled || !m_BearOB.active) return false;
   double range = (m_BearOB.high - m_BearOB.low) * 0.5;
   return (price >= m_BearOB.low - range && price <= m_BearOB.high + range);
}

//+------------------------------------------------------------------+
//| MAIN ENTRY FILTER: Allow Long                                     |
//+------------------------------------------------------------------+
bool CSMCFilter::AllowLong()
{
   int passCount = 0;
   int totalFilters = 0;
   
   //=== 1. MTF TREND FILTER ===
   if(g_MTF_Enabled)
   {
      totalFilters++;
      if(m_Trend != SMC_BEAR) // Allow if bullish or neutral
         passCount++;
      else
      {
         Print("[SMC] LONG blocked — MTF trend is BEARISH");
         return false;
      }
   }
   
   //=== 2. FVG FILTER ===
   if(g_FVG_Enabled)
   {
      totalFilters++;
      // For BUY: want price inside or near bullish FVG (retest zone)
      // Or bullish FVG should be present (structural shift)
      if(m_BullFVG.active || !m_BearFVG.active)
         passCount++;
      else
      {
         Print("[SMC] LONG blocked — No bullish FVG/signal");
         return false;
      }
   }
   
   //=== 3. INDUCEMENT FILTER (Anti-Inducement) ===
   if(g_IND_Enabled)
   {
      totalFilters++;
      // Block if recent bearish inducement (fake breakout down) is still fresh
      // Allow if bullish inducement (reversal opportunity)
      if(!m_BearInd.active)
         passCount++;
      else
      {
         // Check if inducement is fresh (within last 10 bars)
         datetime now = Time[0];
         if(now - m_BearInd.time < 10 * PeriodSeconds(PERIOD_H1))
         {
            Print("[SMC] LONG blocked — Recent bearish inducement detected");
            return false;
         }
         passCount++;
      }
   }
   
   //=== 4. CHoCH FILTER ===
   if(g_CHOCH_Enabled)
   {
      totalFilters++;
      if(m_LastCHoCH == SMC_BULL || m_LastCHoCH == SMC_NEUT)
         passCount++;
      else
      {
         Print("[SMC] LONG blocked — No bullish CHoCH");
         return false;
      }
   }
   
   //=== 5. ORDER BLOCK FILTER (Bonus) ===
   // If we are at a bullish OB, that's a stronger signal
   // But if at bearish OB, might want to avoid
   
   //=== DECISION ===
   if(g_StrictMode)
   {
      // All filters must pass
      return (passCount == totalFilters);
   }
   else
   {
      // At least half the filters must pass
      return (passCount >= (totalFilters + 1) / 2);
   }
}

//+------------------------------------------------------------------+
//| MAIN ENTRY FILTER: Allow Short                                    |
//+------------------------------------------------------------------+
bool CSMCFilter::AllowShort()
{
   int passCount = 0;
   int totalFilters = 0;
   
   //=== 1. MTF TREND FILTER ===
   if(g_MTF_Enabled)
   {
      totalFilters++;
      if(m_Trend != SMC_BULL) // Allow if bearish or neutral
         passCount++;
      else
      {
         Print("[SMC] SHORT blocked — MTF trend is BULLISH");
         return false;
      }
   }
   
   //=== 2. FVG FILTER ===
   if(g_FVG_Enabled)
   {
      totalFilters++;
      if(m_BearFVG.active || !m_BullFVG.active)
         passCount++;
      else
      {
         Print("[SMC] SHORT blocked — No bearish FVG/signal");
         return false;
      }
   }
   
   //=== 3. INDUCEMENT FILTER (Anti-Inducement) ===
   if(g_IND_Enabled)
   {
      totalFilters++;
      if(!m_BullInd.active)
         passCount++;
      else
      {
         datetime now = Time[0];
         if(now - m_BullInd.time < 10 * PeriodSeconds(PERIOD_H1))
         {
            Print("[SMC] SHORT blocked — Recent bullish inducement detected");
            return false;
         }
         passCount++;
      }
   }
   
   //=== 4. CHoCH FILTER ===
   if(g_CHOCH_Enabled)
   {
      totalFilters++;
      if(m_LastCHoCH == SMC_BEAR || m_LastCHoCH == SMC_NEUT)
         passCount++;
      else
      {
         Print("[SMC] SHORT blocked — No bearish CHoCH");
         return false;
      }
   }
   
   //=== DECISION ===
   if(g_StrictMode)
      return (passCount == totalFilters);
   else
      return (passCount >= (totalFilters + 1) / 2);
}

//+------------------------------------------------------------------+
//| Quick Filter Status String                                        |
//+------------------------------------------------------------------+
string CSMCFilter::GetFilterInfo()
{
   string trendStr = (m_Trend == SMC_BULL) ? "BULL" : 
                     (m_Trend == SMC_BEAR) ? "BEAR" : "NEUT";
   string fvgStr = (m_BullFVG.active) ? "BullFVG" : 
                   (m_BearFVG.active) ? "BearFVG" : "NONE";
   string indStr = (m_BullInd.active) ? "BullIND" : 
                   (m_BearInd.active) ? "BearIND" : "NONE";
   
   return StringFormat("Trend:%s | FVG:%s | IND:%s", trendStr, fvgStr, indStr);
}

//+------------------------------------------------------------------+
//| Detailed Filter Status                                            |
//+------------------------------------------------------------------+
string CSMCFilter::GetDetailedInfo()
{
   string trendStr, fvgStr, indStr, obStr, chochStr;
   
   // Trend
   if(m_Trend == SMC_BULL) trendStr = "BULLISH (D1+H4 aligned)";
   else if(m_Trend == SMC_BEAR) trendStr = "BEARISH (D1+H4 aligned)";
   else trendStr = "NEUTRAL (conflicting TF)";
   
   // FVG
   if(m_BullFVG.active)
      fvgStr = StringFormat("BULL FVG active: %.5f - %.5f", m_BullFVG.lower, m_BullFVG.upper);
   else if(m_BearFVG.active)
      fvgStr = StringFormat("BEAR FVG active: %.5f - %.5f", m_BearFVG.lower, m_BearFVG.upper);
   else
      fvgStr = "No active FVG";
   
   // Inducement
   if(m_BullInd.active)
      indStr = StringFormat("BULL INDUCEMENT: spike low at %.5f (%.1f ATR)", m_BullInd.peak, m_BullInd.atr);
   else if(m_BearInd.active)
      indStr = StringFormat("BEAR INDUCEMENT: spike high at %.5f (%.1f ATR)", m_BearInd.peak, m_BearInd.atr);
   else
      indStr = "No recent inducement";
   
   // CHoCH
   if(m_LastCHoCH == SMC_BULL) chochStr = "BULLISH CHoCH (structure shifted up)";
   else if(m_LastCHoCH == SMC_BEAR) chochStr = "BEARISH CHoCH (structure shifted down)";
   else chochStr = "No CHoCH detected";
   
   // Order Blocks
   if(m_BullOB.active)
      obStr = StringFormat("Bull OB: %.5f - %.5f", m_BullOB.low, m_BullOB.high);
   else if(m_BearOB.active)
      obStr = StringFormat("Bear OB: %.5f - %.5f", m_BearOB.low, m_BearOB.high);
   else
      obStr = "No active OB";
   
   return StringFormat(
      "=== SMC FILTER STATUS ===\n" +
      "MTF Trend: %s\n" +
      "FVG: %s\n" +
      "Inducement: %s\n" +
      "CHoCH: %s\n" +
      "Order Block: %s",
      trendStr, fvgStr, indStr, chochStr, obStr
   );
}

//+------------------------------------------------------------------+
//| END OF SMC FILTER MODULE                                          |
//+------------------------------------------------------------------+