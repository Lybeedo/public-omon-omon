//+------------------------------------------------------------------+
//|                                                       VWAP.mqh    |
//|               Anchored VWAP Engine (Session / Daily Reset)       |
//+------------------------------------------------------------------+
#property copyright "Murray Math EA"
#property version   "1.00"
#property strict

#ifndef VWAP_MQH
#define VWAP_MQH

#include "Utils.mqh"

//+------------------------------------------------------------------+
//| VWAP Reset Mode                                                  |
//+------------------------------------------------------------------+
enum ENUM_VWAP_RESET {
    VWAP_SESSION_NEWYORK  = 0,  // Reset at NY session open 07:00-08:00 EST
    VWAP_SESSION_LONDON   = 1,  // Reset at London open 03:00 EST
    VWAP_SESSION_ASIA     = 2,  // Reset at Asia open 19:00 EST
    VWAP_DAILY           = 3,  // Reset at daily bar open (00:00 broker)
    VWAP_WEEKLY          = 4,  // Reset Monday 00:00
    VWAP_CUSTOM          = 5,  // Manual anchor point (user sets bar/time)
    VWAP_AUTOMATIC       = 6   // Auto-detect session boundaries
};

//+------------------------------------------------------------------+
//| VWAP State                                                       |
//+------------------------------------------------------------------+
struct VWAPState {
    double  cumulativeTV;    // Sum(TypicalPrice * Volume)
    double  cumulativeV;    // Sum(Volume)
    double  vwapValue;      // current VWAP price
    datetime anchorTime;    // when VWAP was anchored/reset
    double  anchorPrice;    // price at anchor time
    bool    isAnchored;
    int     barCount;       // bars since anchor
    double  upperBand;      // +1 StdDev
    double  lowerBand;      // -1 StdDev
    double  upperBand2;      // +2 StdDev
    double  lowerBand2;      // -2 StdDev
};

//+------------------------------------------------------------------+
//| Anchored VWAP Calculator                                         |
//+------------------------------------------------------------------+
class CAnchoredVWAP {
public:
    ENUM_VWAP_RESET mResetMode;
    VWAPState       mState;

    // StdDev tracking
    double          mCumPVA;    // cumulative price*vol*price for variance
    int             mBarsSinceReset;

    // Session window settings
    int             mSessionHour;     // e.g. 8 for 08:00
    ENUM_TIMEZONE_MODE {
        TZ_EST = 0,
        TZ_UTC = 1,
        TZ_BROKER = 2
    } mTimezone;

    //+----------------------------------------------------------+
    //| Constructor                                               |
    //+----------------------------------------------------------+
    void CAnchoredVWAP() {
        mResetMode = VWAP_DAILY;
        mSessionHour = 0;
        mTimezone = TZ_BROKER;
        Reset();
    }

    void CAnchoredVWAP(ENUM_VWAP_RESET mode, int sessionHour = 8) {
        mResetMode = mode;
        mSessionHour = sessionHour;
        mTimezone = TZ_BROKER;
        Reset();
    }

    //+----------------------------------------------------------+
    //| Reset VWAP state                                          |
    //+----------------------------------------------------------+
    void Reset() {
        mState.cumulativeTV = 0;
        mState.cumulativeV  = 0;
        mState.vwapValue    = 0;
        mState.isAnchored   = false;
        mState.barCount     = 0;
        mState.upperBand    = 0;
        mState.lowerBand    = 0;
        mState.upperBand2   = 0;
        mState.lowerBand2   = 0;
        mCumPVA = 0;
        mBarsSinceReset = 0;
    }

    //+----------------------------------------------------------+
    //| Anchor VWAP at specific time                              |
    //+----------------------------------------------------------+
    void AnchorAt(datetime barTime, double priceAtAnchor) {
        Reset();
        mState.anchorTime  = barTime;
        mState.anchorPrice = priceAtAnchor;
        mState.isAnchored  = true;
    }

    //+----------------------------------------------------------+
    //| Update on each new bar (call in OnCalculate)              |
    //+----------------------------------------------------------+
    double Update(int shift = 0) {
        datetime barTime = iTime(_Symbol, PERIOD_CURRENT, shift);
        
        // Check if we should reset
        if(ShouldReset(barTime)) {
            double openPrice = iOpen(_Symbol, PERIOD_CURRENT, shift);
            AnchorAt(barTime, openPrice);
        }

        if(!mState.isAnchored) {
            // Auto-anchor at first bar
            double openPrice = iOpen(_Symbol, PERIOD_CURRENT, shift);
            AnchorAt(barTime, openPrice);
        }

        double tp   = iTypical(_Symbol, PERIOD_CURRENT, shift);
        double vol  = iVolume(_Symbol, PERIOD_CURRENT, shift);

        // Tick volume = 0 on some brokers (no volume data)
        if(vol <= 0) vol = 1;

        mState.cumulativeTV += tp * vol;
        mState.cumulativeV  += vol;
        mBarsSinceReset++;

        double sumPVA = mCumPVA;
        // Update variance for std dev bands
        double mean = (mState.cumulativeV > 0) ? mState.cumulativeTV / mState.cumulativeV : tp;
        sumPVA += tp * tp * vol;
        double variance = 0;
        if(mState.cumulativeV > 1) {
            variance = (sumPVA / mState.cumulativeV) - (mean * mean);
            if(variance < 0) variance = 0;
        }
        double stdDev = MathSqrt(variance);

        // 1-sigma and 2-sigma bands
        mState.upperBand  = mState.vwapValue + stdDev;
        mState.lowerBand  = mState.vwapValue - stdDev;
        mState.upperBand2 = mState.vwapValue + 2 * stdDev;
        mState.lowerBand2 = mState.vwapValue - 2 * stdDev;

        mState.vwapValue = (mState.cumulativeV > 0)
            ? mState.cumulativeTV / mState.cumulativeV
            : tp;

        mState.barCount = mBarsSinceReset;

        return mState.vwapValue;
    }

private:
    bool ShouldReset(datetime barTime) {
        MqlDateTime dt;
        TimeToStruct(barTime, dt);

        switch(mResetMode) {
            case VWAP_DAILY:
                // Reset at midnight broker time
                if(dt.hour == 0 && dt.min == 0 && mState.isAnchored) {
                    return true;
                }
                break;

            case VWAP_SESSION_NEWYORK: {
                // NY session opens 07:00 EST (12:00 UTC in winter, 11:00 UTC in summer)
                bool isSummer = (dt.mon >= 4 && dt.mon <= 10);
                int nyOpenUTC = isSummer ? 11 : 12;
                if(dt.hour == nyOpenUTC && dt.min == 0 && mState.isAnchored) {
                    return true;
                }
                break;
            }

            case VWAP_SESSION_LONDON: {
                // London opens 03:00 EST (08:00 UTC winter, 07:00 UTC summer)
                bool isSummer = (dt.mon >= 4 && dt.mon <= 10);
                int lonOpenUTC = isSummer ? 7 : 8;
                if(dt.hour == lonOpenUTC && dt.min == 0 && mState.isAnchored) {
                    return true;
                }
                break;
            }

            case VWAP_WEEKLY:
                // Reset Monday at 00:00
                if(dt.day_of_week == 1 && dt.hour == 0 && dt.min == 0 && mState.isAnchored) {
                    return true;
                }
                break;

            case VWAP_AUTOMATIC: {
                // Auto: reset on first bar of new session (London 03:00, NY 07:00, Asia 19:00)
                bool isSummer = (dt.mon >= 4 && dt.mon <= 10);
                int lonOpen = isSummer ? 7 : 8;
                int nyOpen  = isSummer ? 11 : 12;
                int asiaOpen = 19;
                if((dt.hour == lonOpen || dt.hour == nyOpen || dt.hour == asiaOpen)
                   && dt.min == 0 && mState.isAnchored) {
                    return true;
                }
                break;
            }

            case VWAP_CUSTOM:
                // No auto reset - manual anchor only
                break;
        }

        return false;
    }

public:
    //+----------------------------------------------------------+
    //| Get current VWAP value                                    |
    //+----------------------------------------------------------+
    double GetVWAP() {
        return mState.vwapValue;
    }

    double GetUpperBand(int sigma = 1) {
        return (sigma >= 2) ? mState.upperBand2 : mState.upperBand;
    }

    double GetLowerBand(int sigma = 1) {
        return (sigma >= 2) ? mState.lowerBand2 : mState.lowerBand;
    }

    //+----------------------------------------------------------+
    //| Price vs VWAP position                                   |
    //+----------------------------------------------------------+
    int GetPricePosition(double price) {
        if(price > mState.upperBand2) return  2; // Well above
        if(price > mState.upperBand)  return  1; // Above +1σ
        if(price > mState.vwapValue)  return  0; // Above VWAP but within band
        if(price > mState.lowerBand)  return -1; // Below VWAP but within band
        if(price > mState.lowerBand2) return -2; // Below -1σ
        return -3;                               // Well below -2σ
    }

    //+----------------------------------------------------------+
    //| VWAP trend direction                                     |
    //+----------------------------------------------------------+
    // Returns: 1 = bullish (price consistently above VWAP)
    //         -1 = bearish (price consistently below VWAP)
    //          0 = neutral
    int GetTrend(int lookbackBars = 10) {
        if(mState.barCount < 3) return 0;

        int aboveCount = 0;
        for(int i = 1; i <= lookbackBars && i < mState.barCount; i++) {
            double c = iClose(_Symbol, PERIOD_CURRENT, i);
            if(c > mState.vwapValue) aboveCount++;
        }
        if(aboveCount >= lookbackBars * 0.7) return  1;
        if(aboveCount <= lookbackBars * 0.3) return -1;
        return 0;
    }

    //+----------------------------------------------------------+
    //| Get VWAP slope (pips per bar)                            |
    //+----------------------------------------------------------+
    double GetSlope(int lookbackBars = 10) {
        if(mState.barCount < 2) return 0;
        int bars = MathMin(lookbackBars, mState.barCount);
        double firstVWAP = GetVWAPAtBar(bars - 1);
        double lastVWAP  = GetVWAPAtBar(0);
        return (lastVWAP - firstVWAP) / bars;
    }

    //+----------------------------------------------------------+
    //| Approximate VWAP at bar N                                |
    //+----------------------------------------------------------+
    double GetVWAPAtBar(int barsAgo) {
        double cumulativeTV = 0;
        double cumulativeV  = 0;
        for(int i = barsAgo; i >= 0; i--) {
            if(!IsBarInSession(i)) continue;
            double tp  = iTypical(_Symbol, PERIOD_CURRENT, i);
            double vol = iVolume(_Symbol, PERIOD_CURRENT, i);
            if(vol <= 0) vol = 1;
            cumulativeTV += tp * vol;
            cumulativeV  += vol;
        }
        return (cumulativeV > 0) ? cumulativeTV / cumulativeV : mState.vwapValue;
    }

private:
    bool IsBarInSession(int barsAgo) {
        if(!mState.isAnchored) return true;
        datetime barTime = iTime(_Symbol, PERIOD_CURRENT, barsAgo);
        return (barTime >= mState.anchorTime);
    }

public:
    //+----------------------------------------------------------+
    //| Check if price crossed VWAP (for signal confirmation)     |
    //+----------------------------------------------------------+
    bool CrossedAbove(double price, double prevPrice) {
        return (prevPrice < mState.vwapValue && price >= mState.vwapValue);
    }

    bool CrossedBelow(double price, double prevPrice) {
        return (prevPrice > mState.vwapValue && price <= mState.vwapValue);
    }

    //+----------------------------------------------------------+
    //| Get session info string                                  |
    //+----------------------------------------------------------+
    string GetSessionName() {
        switch(mResetMode) {
            case VWAP_SESSION_NEWYORK: return "New York Session";
            case VWAP_SESSION_LONDON:  return "London Session";
            case VWAP_SESSION_ASIA:    return "Asia Session";
            case VWAP_DAILY:          return "Daily";
            case VWAP_WEEKLY:         return "Weekly";
            case VWAP_CUSTOM:         return "Custom Anchor";
            case VWAP_AUTOMATIC:      return "Auto (Multi-Session)";
            default:                  return "Unknown";
        }
    }

    //+----------------------------------------------------------+
    //| Debug print                                               |
    //+----------------------------------------------------------+
    void PrintState() {
        Print("=== Anchored VWAP ===");
        Print("Session: ", GetSessionName());
        PrintFormat("VWAP: %.5f  (+1σ: %.5f  -1σ: %.5f)",
            mState.vwapValue, mState.upperBand, mState.lowerBand);
        PrintFormat("+2σ: %.5f  -2σ: %.5f", mState.upperBand2, mState.lowerBand2);
        Print("Bars since anchor: ", mState.barCount);
        Print("Trend: ", GetTrend() > 0 ? "BULLISH" : GetTrend() < 0 ? "BEARISH" : "NEUTRAL");
        Print("====================");
    }
};

#endif // VWAP_MQH