//+------------------------------------------------------------------+
//|                                                MurrayMath.mqh    |
//|               Murray Math 8-Level Calculation Engine            |
//+------------------------------------------------------------------+
#property copyright "Murray Math EA"
#property version   "1.00"
#property strict

#ifndef MURRAY_MATH_MQH
#define MURRAY_MATH_MQH

#include "Utils.mqh"

//+------------------------------------------------------------------+
//| Murray Math Level Struct                                         |
//+------------------------------------------------------------------+
struct MMLevel {
    double price;
    int    octave;       // 0..8
    string name;
    string description;
    color  labelColor;
    bool   isKeyLevel;
    bool   isExtreme;
    bool   isDecisionZone;
    bool   isTPZone;
};

//+------------------------------------------------------------------+
//| Main Murray Math Calculator                                      |
//+------------------------------------------------------------------+
class CMurrayMath {
public:
    double  mBase;        // Bottom of range (0/8)
    double  mTop;         // Top of range (8/8)
    double  mStep;        // 1/8 step
    double  mRange;
    int     mDigits;
    MMLevel mLevels[9];   // 0/8 to 8/8
    double  mExtensionBelow;
    double  mExtensionAbove;

    //+----------------------------------------------------------+
    //| Constructor - auto detect range from N candles           |
    //+----------------------------------------------------------+
    void CMurrayMath() {
        mBase = 0; mTop = 0; mStep = 0; mRange = 0; mDigits = 0;
        mExtensionBelow = 0; mExtensionAbove = 0;
    }

    //+----------------------------------------------------------+
    //| Calculate from swing high/low (N candles back)           |
    //+----------------------------------------------------------+
    void Calculate(int lookbackBars = 100) {
        mDigits = GetDigits();
        mTop    = HighestHigh(0, lookbackBars);
        mBase   = LowestLow(0, lookbackBars);
        BuildLevels();
    }

    //+----------------------------------------------------------+
    //| Calculate from explicit price range                       |
    //+----------------------------------------------------------+
    void CalculateRange(double low, double high) {
        mDigits = DetectDigits(high);
        mTop    = high;
        mBase   = low;
        BuildLevels();
    }

    //+----------------------------------------------------------+
    //| Calculate from Fibonacci-based range (more stable)        |
    //+----------------------------------------------------------+
    void CalculateFibonacciRange(int lookbackBars = 50) {
        mDigits = GetDigits();
        
        double highest = HighestHigh(0, lookbackBars);
        double lowest  = LowestLow(0, lookbackBars);
        
        // Round to nice numbers
        mTop  = MathCeil(highest / GetPoint()) * GetPoint();
        mBase = MathFloor(lowest  / GetPoint()) * GetPoint();
        
        BuildLevels();
    }

private:
    void BuildLevels() {
        mRange = mTop - mBase;
        if(mRange <= 0) return;

        // Detect appropriate octave (power of 10)
        double tempRange = mRange;
        int octaveShift = 0;
        while(tempRange < 0.1) { tempRange *= 10; octaveShift++; }
        while(tempRange > 10)  { tempRange /= 10; octaveShift--; }
        if(tempRange < 1)      { tempRange *= 10; octaveShift--; }

        double step = MathPow(10, -octaveShift);
        double baseRound = MathFloor(mBase / step) * step;
        double topRound  = MathCeil(mTop  / step) * step;
        mStep = (topRound - baseRound) / 8.0;
        if(mStep <= 0) mStep = GetPoint();

        // Build 8 levels
        string names[]  = {"0/8", "1/8", "2/8", "3/8", "4/8", "5/8", "6/8", "7/8", "8/8"};
        string descs[]  = {
            "Lower Extension (Extreme Reversal)",
            "Lower Weak (Reversal Buy Zone)",
            "Buy TP Target",
            "Lower Strong (Decision Zone)",
            "PIVOT / Price Magnet",
            "Upper Strong (Decision Zone)",
            "Sell TP Target",
            "Upper Weak (Reversal Sell Zone)",
            "Upper Extension (Extreme Reversal)"
        };
        color  cols[]   = {clrDarkBlue, clrBlue, clrDodgerBlue, clrLime, clrWhite, clrLime, clrOrange, clrRed, clrDarkRed};
        bool   keys[]   = {false, false, true, true, true, true, true, false, false};
        bool   exts[]   = {true, false, false, false, false, false, false, false, true};
        bool   decs[]   = {false, false, false, true, false, true, false, false, false};
        bool   tps[]    = {false, false, true, false, false, false, true, false, false};

        for(int i = 0; i <= 8; i++) {
            mLevels[i].price         = NormalizePrice(baseRound + mStep * i);
            mLevels[i].octave       = i;
            mLevels[i].name         = names[i];
            mLevels[i].description  = descs[i];
            mLevels[i].labelColor    = cols[i];
            mLevels[i].isKeyLevel    = keys[i];
            mLevels[i].isExtreme     = exts[i];
            mLevels[i].isDecisionZone = decs[i];
            mLevels[i].isTPZone      = tps[i];
        }

        mExtensionBelow = NormalizePrice(mLevels[0].price - mStep);
        mExtensionAbove  = NormalizePrice(mLevels[8].price + mStep);
    }

public:
    //+----------------------------------------------------------+
    //| Get level by index (0-8)                                  |
    //+----------------------------------------------------------+
    double GetLevel(int idx) {
        if(idx < 0 || idx > 8) return 0;
        return mLevels[idx].price;
    }

    MMLevel GetLevelInfo(int idx) {
        if(idx < 0 || idx > 8) return mLevels[0];
        return mLevels[idx];
    }

    //+----------------------------------------------------------+
    //| Get current price zone (0-8)                             |
    //+----------------------------------------------------------+
    int GetCurrentZone(double price) {
        if(mRange <= 0) return -1;
        double pos = (price - mBase) / mRange;
        return MathMax(0, MathMin(8, (int)MathFloor(pos * 8)));
    }

    //+----------------------------------------------------------+
    //| Get nearest level to current price                       |
    //+----------------------------------------------------------+
    double GetNearestLevel(double price, double maxDistance = 0) {
        double nearest = 0;
        double minDist  = DoubleMax;
        for(int i = 0; i <= 8; i++) {
            double d = MathAbs(price - mLevels[i].price);
            if(d < minDist) {
                minDist = d;
                nearest = mLevels[i].price;
            }
        }
        if(maxDistance > 0 && minDist > maxDistance) return 0;
        return nearest;
    }

    //+----------------------------------------------------------+
    //| Get all levels as array (for drawing)                    |
    //+----------------------------------------------------------+
    void GetAllLevels(double& arr[]) {
        ArrayResize(arr, 9);
        for(int i = 0; i <= 8; i++) arr[i] = mLevels[i].price;
    }

    //+----------------------------------------------------------+
    //| Determine signal based on zone + VWAP position           |
    //+----------------------------------------------------------+
    // zone 0-2 = buy zone, 3-5 = neutral, 6-8 = sell zone
    int GetSignal(double price, double vwapPrice) {
        int zone = GetCurrentZone(price);
        if(zone < 0) return 0;

        bool aboveVWAP = price > vwapPrice;
        bool belowVWAP = price < vwapPrice;

        // BUY signals
        if(zone <= 2 && belowVWAP) return 1;   // Strong buy
        if(zone <= 1)               return 2;   // Buy zone

        // SELL signals
        if(zone >= 6 && aboveVWAP) return -1;   // Strong sell
        if(zone >= 7)              return -2;   // Sell zone

        // Decision zone breakout
        if(zone == 3 && !aboveVWAP) return 1;   // Bullish breakout
        if(zone == 5 && !belowVWAP) return -1;  // Bearish breakout

        return 0;
    }

    //+----------------------------------------------------------+
    //| Print levels to console (debug)                          |
    //+----------------------------------------------------------+
    void PrintLevels() {
        Print("=== Murray Math Levels ===");
        Print("Range: ", DoubleToStr(mBase, mDigits), " -> ", DoubleToStr(mTop, mDigits));
        Print("Step: ", DoubleToStr(mStep, mDigits));
        Print("---");
        for(int i = 0; i <= 8; i++) {
            PrintFormat("%s: %s  %s", mLevels[i].name,
                DoubleToStr(mLevels[i].price, mDigits),
                mLevels[i].description);
        }
        Print("Extensions: Below=", DoubleToStr(mExtensionBelow, mDigits),
              " Above=", DoubleToStr(mExtensionAbove, mDigits));
        Print("========================");
    }
};

#endif // MURRAY_MATH_MQH