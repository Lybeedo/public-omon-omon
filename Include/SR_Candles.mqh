//+------------------------------------------------------------------+
//|                                                SR_Candles.mqh   |
//|                          Cuancux Algo Traders • Paulus Is        |
//+------------------------------------------------------------------+
#ifndef SR_CANDLES_MQH
#define SR_CANDLES_MQH

#include <Arrays\List.mqh>

//+------------------------------------------------------------------+
//|  Reversal pattern enum                                           |
//+------------------------------------------------------------------+
enum ENUM_REVERSAL_PATTERN
  {
   REVERSAL_NONE           = 0,
   REVERSAL_BULLISH_ENG    = 1,   // bullish engulfing
   REVERSAL_BEARISH_ENG    = 2,   // bearish engulfing
   REVERSAL_HAMMER         = 3,   // hammer / inverted hammer
   REVERSAL_SHOOTING_STAR  = 4,   // shooting star
   REVERSAL_MORNING_STAR   = 5,   // morning star (3-candle)
   REVERSAL_EVENING_STAR   = 6    // evening star  (3-candle)
  };

//+------------------------------------------------------------------+
//|  Signal structure                                                |
//+------------------------------------------------------------------+
struct SCandleSignal
  {
   ENUM_REVERSAL_PATTERN pattern;
   double                reversalHigh;   // high of reversal candle
   double                reversalLow;    // low  of reversal candle
   double                reversalOpen;
   double                reversalClose;
   int                   reversalBar;    // bar shift of reversal candle
   double                confirmationClose;
   double                confirmationHigh;
   double                confirmationLow;
   bool                  isValid;
  };

//+------------------------------------------------------------------+
//|  CSR_Candles — reversal and confirmation detection               |
//+------------------------------------------------------------------+
class CSR_Candles
  {
private:
   // config flags
   bool        m_useBullEng;
   bool        m_useHammer;
   bool        m_useMorningStar;
   bool        m_useBearEng;
   bool        m_useShootingStar;
   bool        m_useEveningStar;
   double      m_minBodyRatio;

public:
                     CSR_Candles(void);
                    ~CSR_Candles(void);

   void              Configure(bool bullEng, bool hammer, bool morning,
                               bool bearEng, bool shooting, bool evening,
                               double minBodyRatio);

   // Main detection
   bool              DetectReversal(int shift, ENUM_REVERSAL_PATTERN &pattern);
   bool              DetectConfirmation(int reversalBar,
                                        ENUM_ZONE_TYPE zoneType,
                                        SCandleSignal &sig);
   ENUM_REVERSAL_PATTERN DetectPattern(int shift, bool preferBullish);

   // Individual pattern checks
   bool              IsBullishEngulfing(int shift);
   bool              IsBearishEngulfing(int shift);
   bool              IsHammer(int shift);
   bool              IsShootingStar(int shift);
   bool              IsMorningStar(int shift);
   bool              IsEveningStar(int shift);

   // Helpers
   double            CandleBodySize(int shift) const;
   double            CandleRange(int shift)    const;
   double            CandleUpperWick(int shift) const;
   double            CandleLowerWick(int shift) const;

   string            PatternToString(ENUM_REVERSAL_PATTERN p);
  };

//+------------------------------------------------------------------+
CSR_Candles::CSR_Candles(void)
  : m_useBullEng(false), m_useHammer(false), m_useMorningStar(false),
    m_useBearEng(false), m_useShootingStar(false), m_useEveningStar(false),
    m_minBodyRatio(0.5)
  {
  }

//+------------------------------------------------------------------+
CSR_Candles::~CSR_Candles(void) {}

//+------------------------------------------------------------------+
void CSR_Candles::Configure(bool bullEng, bool hammer, bool morning,
                            bool bearEng, bool shooting, bool evening,
                            double minBodyRatio)
  {
   m_useBullEng    = bullEng;
   m_useHammer     = hammer;
   m_useMorningStar= morning;
   m_useBearEng    = bearEng;
   m_useShootingStar=shooting;
   m_useEveningStar = evening;
   m_minBodyRatio   = minBodyRatio;
  }

//+------------------------------------------------------------------+
//|  Get candle data helper                                          |
//+------------------------------------------------------------------+
double CSR_Candles::CandleBodySize(int shift) const
  {
   double o = iOpen(NULL, 0, shift);
   double c = iClose(NULL, 0, shift);
   return MathAbs(c - o);
  }

double CSR_Candles::CandleRange(int shift) const
  {
   return iHigh(NULL, 0, shift) - iLow(NULL, 0, shift);
  }

double CSR_Candles::CandleUpperWick(int shift) const
  {
   double h = iHigh(NULL, 0, shift);
   double c = iClose(NULL, 0, shift);
   double o = iOpen(NULL, 0, shift);
   double upper = MathMax(c, o);
   return h - upper;
  }

double CSR_Candles::CandleLowerWick(int shift) const
  {
   double l = iLow(NULL, 0, shift);
   double c = iClose(NULL, 0, shift);
   double o = iOpen(NULL, 0, shift);
   double lower = MathMin(c, o);
   return lower - l;
  }

//+------------------------------------------------------------------+
//|  Detect reversal pattern at given bar                            |
//+------------------------------------------------------------------+
bool CSR_Candles::DetectReversal(int shift, ENUM_REVERSAL_PATTERN &pattern)
  {
   // shift 1 = most recent closed bar
   if(shift < 1 || shift > 50) return false;

   // Try bullish patterns first
   if(IsBullishEngulfing(shift))     { pattern = REVERSAL_BULLISH_ENG; return true; }
   if(IsHammer(shift))               { pattern = REVERSAL_HAMMER;      return true; }
   if(IsMorningStar(shift))          { pattern = REVERSAL_MORNING_STAR;return true; }

   // Try bearish patterns
   if(IsBearishEngulfing(shift))     { pattern = REVERSAL_BEARISH_ENG; return true; }
   if(IsShootingStar(shift))         { pattern = REVERSAL_SHOOTING_STAR;return true; }
   if(IsEveningStar(shift))          { pattern = REVERSAL_EVENING_STAR; return true; }

   return false;
  }

//+------------------------------------------------------------------+
//|  Detect confirmation candle after reversal bar                   |
//+|  For BUY (demand): confirmation close > reversal high           |
//|  For SELL (supply): confirmation close < reversal low           |
//+------------------------------------------------------------------+
bool CSR_Candles::DetectConfirmation(int reversalBar,
                                      ENUM_ZONE_TYPE zoneType,
                                      SCandleSignal &sig)
  {
   // confirmation is on bar 0 (current bar, still forming)
   double confOpen  = iOpen(NULL, 0, 0);
   double confHigh = iHigh(NULL, 0, 0);
   double confLow  = iLow(NULL, 0, 0);
   double confClose= iClose(NULL, 0, 0);

   sig.confirmationClose = confClose;
   sig.confirmationHigh  = confHigh;
   sig.confirmationLow   = confLow;

   bool ok = false;
   if(zoneType == ZONE_BUY)
     {
      // BUY confirmation: close above reversal candle high
      ok = (confClose > sig.reversalHigh);
     }
   else if(zoneType == ZONE_SELL)
     {
      // SELL confirmation: close below reversal candle low
      ok = (confClose < sig.reversalLow);
     }

   if(!ok) sig.isValid = false;
   else     sig.isValid = true;

   return ok;
  }

//+------------------------------------------------------------------+
//|  BULLISH ENGULFING                                               |
//|  - Current bar is bullish (close > open)                         |
//|  - Previous bar is bearish (close < open)                        |
//|  - Current body engulfs previous body                            |
//+------------------------------------------------------------------+
bool CSR_Candles::IsBullishEngulfing(int shift)
  {
   if(!m_useBullEng) return false;
   if(shift < 1) return false;

   double currOpen = iOpen(NULL, 0, shift);
   double currClose= iClose(NULL, 0, shift);
   double prevOpen = iOpen(NULL, 0, shift+1);
   double prevClose= iClose(NULL, 0, shift+1);

   bool currBull  = (currClose > currOpen);
   bool prevBear  = (prevClose < prevOpen);
   if(!currBull || !prevBear) return false;

   double currBodyTop = MathMax(currOpen, currClose);
   double currBodyBot = MathMin(currOpen, currClose);
   double prevBodyTop = MathMax(prevOpen, prevClose);
   double prevBodyBot = MathMin(prevOpen, prevClose);

   bool engulfed = (currBodyBot <= prevBodyBot && currBodyTop >= prevBodyTop);

   // body ratio check
   double bodySize = CandleBodySize(shift);
   double range    = CandleRange(shift);
   bool ratioOK    = (range > 0 && bodySize / range >= m_minBodyRatio);

   return engulfed && ratioOK;
  }

//+------------------------------------------------------------------+
//|  BEARISH ENGULFING                                               |
//|  - Current bar is bearish (close < open)                         |
//|  - Previous bar is bullish (close > open)                        |
//|  - Current body engulfs previous body                            |
//+------------------------------------------------------------------+
bool CSR_Candles::IsBearishEngulfing(int shift)
  {
   if(!m_useBearEng) return false;
   if(shift < 1) return false;

   double currOpen = iOpen(NULL, 0, shift);
   double currClose= iClose(NULL, 0, shift);
   double prevOpen = iOpen(NULL, 0, shift+1);
   double prevClose= iClose(NULL, 0, shift+1);

   bool currBear  = (currClose < currOpen);
   bool prevBull  = (prevClose > prevOpen);
   if(!currBear || !prevBull) return false;

   double currBodyTop = MathMax(currOpen, currClose);
   double currBodyBot = MathMin(currOpen, currClose);
   double prevBodyTop = MathMax(prevOpen, prevClose);
   double prevBodyBot = MathMin(prevOpen, prevClose);

   bool engulfed = (currBodyBot <= prevBodyBot && currBodyTop >= prevBodyTop);

   double bodySize = CandleBodySize(shift);
   double range    = CandleRange(shift);
   bool ratioOK    = (range > 0 && bodySize / range >= m_minBodyRatio);

   return engulfed && ratioOK;
  }

//+------------------------------------------------------------------+
//|  HAMMER / INVERTED HAMMER                                        |
//|  Hammer: bullish, small body, long lower wick (2x+ body),         |
//|          small upper wick                                       |
//+------------------------------------------------------------------+
bool CSR_Candles::IsHammer(int shift)
  {
   if(!m_useHammer) return false;

   double o = iOpen(NULL, 0, shift);
   double c = iClose(NULL, 0, shift);
   double h = iHigh(NULL, 0, shift);
   double l = iLow(NULL, 0, shift);

   double bodySize    = CandleBodySize(shift);
   double range       = CandleRange(shift);
   double lowerWick   = CandleLowerWick(shift);
   double upperWick   = CandleUpperWick(shift);

   bool bullish = (c > o);
   bool ratioOK = (range > 0 && bodySize / range >= 0.2);  // body at least 20% of range
   bool longLower = (lowerWick >= 2.0 * bodySize);
   bool smallUpper= (upperWick <= bodySize * 0.5);

   return bullish && ratioOK && longLower && smallUpper;
  }

//+------------------------------------------------------------------+
//|  SHOOTING STAR                                                   |
//|  Bearish, small body, long upper wick, small lower wick          |
//+------------------------------------------------------------------+
bool CSR_Candles::IsShootingStar(int shift)
  {
   if(!m_useShootingStar) return false;

   double o = iOpen(NULL, 0, shift);
   double c = iClose(NULL, 0, shift);
   double h = iHigh(NULL, 0, shift);
   double l = iLow(NULL, 0, shift);

   double bodySize    = CandleBodySize(shift);
   double range       = CandleRange(shift);
   double upperWick   = CandleUpperWick(shift);
   double lowerWick   = CandleLowerWick(shift);

   bool bearish   = (c < o);
   bool ratioOK   = (range > 0 && bodySize / range >= 0.2);
   bool longUpper = (upperWick >= 2.0 * bodySize);
   bool smallLower= (lowerWick <= bodySize * 0.5);

   return bearish && ratioOK && longUpper && smallLower;
  }

//+------------------------------------------------------------------+
//|  MORNING STAR (3-candle bullish reversal)                        |
//|  Bar 2: small body (star) — gap optional                        |
//|  Bar 1: bearish prior                                           |
//|  Bar 0: bullish current                                         |
//+------------------------------------------------------------------+
bool CSR_Candles::IsMorningStar(int shift)
  {
   if(!m_useMorningStar) return false;
   if(shift < 2) return false;

   // bar 0: current, bar 1: middle star, bar 2: prior
   double o2 = iOpen(NULL, 0, shift+2);
   double c2 = iClose(NULL, 0, shift+2);
   double o1 = iOpen(NULL, 0, shift+1);
   double c1 = iClose(NULL, 0, shift+1);
   double o0 = iOpen(NULL, 0, shift);
   double c0 = iClose(NULL, 0, shift);

   // bar 2: bearish
   bool bar2Bear = (c2 < o2);
   // bar 1: small body (star) — body smaller than prior bar
   double body1 = MathAbs(c1 - o1);
   double body2 = MathAbs(c2 - o2);
   bool starSmall = (body1 < body2 * 0.6);
   // bar 0: bullish engulfing-style close
   bool bar0Bull = (c0 > o0);
   bool gapDown   = (MathMax(o1, c1) < MathMax(o2, c2)); // optional gap

   return bar2Bear && starSmall && bar0Bull;
  }

//+------------------------------------------------------------------+
//|  EVENING STAR (3-candle bearish reversal)                         |
//+------------------------------------------------------------------+
bool CSR_Candles::IsEveningStar(int shift)
  {
   if(!m_useEveningStar) return false;
   if(shift < 2) return false;

   double o2 = iOpen(NULL, 0, shift+2);
   double c2 = iClose(NULL, 0, shift+2);
   double o1 = iOpen(NULL, 0, shift+1);
   double c1 = iClose(NULL, 0, shift+1);
   double o0 = iOpen(NULL, 0, shift);
   double c0 = iClose(NULL, 0, shift);

   // bar 2: bullish
   bool bar2Bull = (c2 > o2);
   // bar 1: small body
   double body1 = MathAbs(c1 - o1);
   double body2 = MathAbs(c2 - o2);
   bool starSmall = (body1 < body2 * 0.6);
   // bar 0: bearish close
   bool bar0Bear = (c0 < o0);

   return bar2Bull && starSmall && bar0Bear;
  }

//+------------------------------------------------------------------+
string CSR_Candles::PatternToString(ENUM_REVERSAL_PATTERN p)
  {
   switch(p)
     {
      case REVERSAL_BULLISH_ENG:   return "BULLISH_ENGULFING";
      case REVERSAL_BEARISH_ENG:   return "BEARISH_ENGULFING";
      case REVERSAL_HAMMER:         return "HAMMER";
      case REVERSAL_SHOOTING_STAR:  return "SHOOTING_STAR";
      case REVERSAL_MORNING_STAR:   return "MORNING_STAR";
      case REVERSAL_EVENING_STAR:   return "EVENING_STAR";
     }
   return "NONE";
  }

#endif
//+------------------------------------------------------------------+