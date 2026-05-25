//+------------------------------------------------------------------+
//|                                                 FiboLevels.mqh   |
//|               Fibonacci Retracement + Extension Engine           |
//+------------------------------------------------------------------+
#property copyright "Murray Math EA"
#property version   "1.00"
#property strict

#ifndef FIBO_LEVELS_MQH
#define FIBO_LEVELS_MQH

#include "Utils.mqh"

//+------------------------------------------------------------------+
//| Fibonacci Level                                                  |
//+------------------------------------------------------------------+
struct FiboLevel {
    double price;
    double ratio;
    string name;
    color  clr;
    bool   isMajor;      // 23.6, 38.2, 50, 61.8, 78.6
    bool   isExtension;
    bool   isHidden;     // works against the trend
};

//+------------------------------------------------------------------+
//| Fibonacci Calculator                                             |
//+------------------------------------------------------------------+
class CFiboCalculator {
public:
    double  mSwingHigh;
    double  mSwingLow;
    int     mDigits;

    // Calculated levels
    FiboLevel mRetraceLevels[5];    // 23.6, 38.2, 50, 61.8, 78.6
    FiboLevel mExtensionLevels[6];   // 127.2, 141.4, 161.8, 200, 261.8, 423.6

    double  mUpDirection;   // 1 = uptrend, -1 = downtrend

    //+----------------------------------------------------------+
    //| Constructor                                               |
    //+----------------------------------------------------------+
    void CFiboCalculator() {
        mSwingHigh = 0; mSwingLow = 0; mDigits = 5; mUpDirection = 1;
    }

    //+----------------------------------------------------------+
    //| Auto-detect swing high/low from N bars                    |
    //+----------------------------------------------------------+
    void DetectSwing(int lookback = 50, int minSwingSizePips = 50) {
        mDigits = GetDigits();

        // Find swing high (highest high in lookback)
        int highBar = 0;
        double high = 0;
        for(int i = 2; i < lookback - 2; i++) {
            double h = iHigh(_Symbol, PERIOD_CURRENT, i);
            if(h > high) { high = h; highBar = i; }
        }
        mSwingHigh = high;

        // Find swing low (lowest low in lookback)
        int lowBar = 0;
        double low = DoubleMax;
        for(int i = 2; i < lookback - 2; i++) {
            double l = iLow(_Symbol, PERIOD_CURRENT, i);
            if(l < low) { low = l; lowBar = i; }
        }
        mSwingLow = low;

        // Ensure high > low
        if(mSwingHigh <= mSwingLow) {
            double avg = (mSwingHigh + mSwingLow) / 2;
            mSwingHigh = avg + GetPoint() * 20;
            mSwingLow  = avg - GetPoint() * 20;
        }

        mUpDirection = (mSwingHigh > mSwingLow) ? 1 : -1;
        ComputeLevels();
    }

    //+----------------------------------------------------------+
    //| Set explicit swing points                                 |
    //+----------------------------------------------------------+
    void SetSwing(double low, double high) {
        mSwingLow  = low;
        mSwingHigh = high;
        mDigits = DetectDigits(high);
        mUpDirection = (high > low) ? 1 : -1;
        ComputeLevels();
    }

private:
    void ComputeLevels() {
        double range = mSwingHigh - mSwingLow;
        if(range <= 0) return;

        // Retracement levels
        double retraces[] = {23.6, 38.2, 50.0, 61.8, 78.6};
        color  rcols[]   = {clrGray, clrSilver, clrWhite, clrGold, clrYellow};

        for(int i = 0; i < 5; i++) {
            mRetraceLevels[i].price     = NormalizePrice(mSwingHigh - retraces[i] / 100.0 * range);
            mRetraceLevels[i].ratio     = retraces[i] / 100.0;
            mRetraceLevels[i].name      = DoubleToString(retraces[i], 1) + "%";
            mRetraceLevels[i].clr       = rcols[i];
            mRetraceLevels[i].isMajor   = (retraces[i] == 61.8 || retraces[i] == 50.0 || retraces[i] == 38.2);
            mRetraceLevels[i].isExtension = false;
            mRetraceLevels[i].isHidden   = false;
        }

        // Extension levels (beyond the move)
        double extensions[] = {127.2, 141.4, 161.8, 200.0, 261.8, 423.6};
        color   ecols[]     = {clrBlue, clrDeepSkyBlue, clrDodgerBlue, clrNavy, clrDarkBlue, clrPurple};

        for(int i = 0; i < 6; i++) {
            mExtensionLevels[i].price     = NormalizePrice(mSwingLow + (100.0 + extensions[i]) / 100.0 * range);
            mExtensionLevels[i].ratio     = (100.0 + extensions[i]) / 100.0;
            mExtensionLevels[i].name      = DoubleToString(extensions[i], 1) + "%";
            mExtensionLevels[i].clr       = ecols[i];
            mExtensionLevels[i].isMajor   = (extensions[i] == 127.2 || extensions[i] == 161.8 || extensions[i] == 261.8);
            mExtensionLevels[i].isExtension = true;
            mExtensionLevels[i].isHidden   = false;
        }
    }

public:
    //+----------------------------------------------------------+
    //| Get retracement level by index (0-4)                     |
    //+----------------------------------------------------------+
    double GetRetrace(int idx) {
        if(idx < 0 || idx >= 5) return 0;
        return mRetraceLevels[idx].price;
    }

    FiboLevel GetRetraceInfo(int idx) {
        if(idx < 0 || idx >= 5) return mRetraceLevels[0];
        return mRetraceLevels[idx];
    }

    //+----------------------------------------------------------+
    //| Get extension level by index (0-5)                        |
    //+----------------------------------------------------------+
    double GetExtension(int idx) {
        if(idx < 0 || idx >= 6) return 0;
        return mExtensionLevels[idx].price;
    }

    FiboLevel GetExtensionInfo(int idx) {
        if(idx < 0 || idx >= 6) return mExtensionLevels[0];
        return mExtensionLevels[idx];
    }

    //+----------------------------------------------------------+
    //| Get key Fibo retracement (Golden Zone 38.2-61.8)         |
    //+----------------------------------------------------------+
    double GetGoldenZoneLow()  { return mRetraceLevels[1].price; }  // 38.2
    double GetGoldenZoneHigh() { return mRetraceLevels[3].price; }  // 61.8

    //+----------------------------------------------------------+
    //| Get major extension levels                                |
    //+----------------------------------------------------------+
    double Get127Level() { return mExtensionLevels[0].price; }
    double Get161Level() { return mExtensionLevels[2].price; }
    double Get261Level() { return mExtensionLevels[4].price; }

    //+----------------------------------------------------------+
    //| Find nearest Fibo level to price                          |
    //+----------------------------------------------------------+
    double GetNearestFibo(double price, double maxDistPips = 30) {
        double nearest = 0;
        double minDist  = DoubleMax;
        int    bestIdx  = -1;

        for(int i = 0; i < 5; i++) {
            double d = MathAbs(price - mRetraceLevels[i].price) / GetPoint();
            if(d < minDist) { minDist = d; nearest = mRetraceLevels[i].price; bestIdx = i; }
        }
        for(int i = 0; i < 6; i++) {
            double d = MathAbs(price - mExtensionLevels[i].price) / GetPoint();
            if(d < minDist) { minDist = d; nearest = mExtensionLevels[i].price; bestIdx = i + 10; }
        }

        if(minDist > maxDistPips) return 0;
        return nearest;
    }

    //+----------------------------------------------------------+
    //| Check if price is in Fibo zone                            |
    //+----------------------------------------------------------+
    int InFiboZone(double price, double tolerance = 0) {
        // Returns: 0 = not in zone, 1 = in golden zone (38.2-61.8), 2 = in deep zone (78.6), 3 = in extension
        if(tolerance == 0) tolerance = 5 * GetPoint();

        for(int i = 0; i < 5; i++) {
            if(MathAbs(price - mRetraceLevels[i].price) <= tolerance) {
                if(i >= 1 && i <= 3) return 1;  // Golden zone
                if(i == 4) return 2;             // 78.6 deep zone
                return 3;                         // other
            }
        }
        for(int i = 0; i < 6; i++) {
            if(MathAbs(price - mExtensionLevels[i].price) <= tolerance) {
                return 4;
            }
        }
        return 0;
    }

    //+----------------------------------------------------------+
    //| Get all Fibo levels sorted by price                      |
    //+----------------------------------------------------------+
    void GetAllLevels(double& arr[]) {
        int total = 5 + 6;
        ArrayResize(arr, total);
        int k = 0;
        for(int i = 0; i < 5; i++) arr[k++] = mRetraceLevels[i].price;
        for(int i = 0; i < 6; i++) arr[k++] = mExtensionLevels[i].price;
        ArraySort(arr);
    }

    //+----------------------------------------------------------+
    //| Detect overlap with Murray Math levels                   |
    //+----------------------------------------------------------+
    bool HasOverlapWith(double& murrayLevels[], double tolerancePips = 5) {
        double tol = tolerancePips * GetPoint();
        for(int i = 0; i < 5; i++) {
            double fr = mRetraceLevels[i].price;
            for(int j = 0; j <= 8; j++) {
                if(MathAbs(fr - murrayLevels[j]) <= tol) return true;
            }
        }
        return false;
    }

    //+----------------------------------------------------------+
    //| Get signal based on price vs Fibo + direction             |
    //+----------------------------------------------------------+
    // Returns: >0 = bullish, <0 = bearish, 0 = neutral
    int GetSignal(double price, double vwapPrice) {
        int zone = InFiboZone(price, 5 * GetPoint());

        bool priceAboveVWAP = (price > vwapPrice);
        bool inGoldenZone   = (zone == 1);

        // Bullish: in golden zone AND price above VWAP
        if(inGoldenZone && priceAboveVWAP && mUpDirection > 0) return 2;
        // Bearish: deep zone OR price below VWAP in downtrend
        if((zone == 2 || zone == 4) && !priceAboveVWAP) return -2;
        if(inGoldenZone && !priceAboveVWAP && mUpDirection < 0) return -1;

        return 0;
    }

    //+----------------------------------------------------------+
    //| Debug print                                               |
    //+----------------------------------------------------------+
    void PrintLevels() {
        Print("=== Fibonacci Levels ===");
        PrintFormat("Swing: Low=%.5f  High=%.5f  Dir=%s",
            mSwingLow, mSwingHigh, mUpDirection > 0 ? "UP" : "DOWN");
        Print("--- Retracements ---");
        for(int i = 0; i < 5; i++) {
            PrintFormat("  %s: %.5f", mRetraceLevels[i].name, mRetraceLevels[i].price);
        }
        Print("--- Extensions ---");
        for(int i = 0; i < 6; i++) {
            PrintFormat("  %s: %.5f", mExtensionLevels[i].name, mExtensionLevels[i].price);
        }
        Print("========================");
    }
};

#endif // FIBO_LEVELS_MQH