//+------------------------------------------------------------------+
//|                                                   Utils.mqh       |
//|                     Murray Math EA - Utility Functions           |
//+------------------------------------------------------------------+
#property copyright "Murray Math EA"
#property version   "1.00"
#property strict

#ifndef UTILS_MQH
#define UTILS_MQH

//+------------------------------------------------------------------+
//| Digit Detection                                                  |
//+------------------------------------------------------------------+
int DetectDigits(double price) {
    if(price >= 1000)   return 2;
    if(price >= 10)     return 3;
    if(price >= 1)      return 4;
    if(price >= 0.01)   return 5;
    if(price >= 0.001)  return 6;
    return 8;
}

int DetectDigitsBySymbol(string symbol) {
    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
    return DetectDigits(bid);
}

int GetDigits() {
    return (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
}

double GetPoint() {
    return Point;
}

double GetSpread() {
    return SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * GetPoint();
}

//+------------------------------------------------------------------+
//| Normalization Helpers                                            |
//+------------------------------------------------------------------+
double NormalizePrice(double price) {
    double p = GetPoint();
    return NormalizeDouble(price, (int)GetDigits());
}

double NormalizeSL(double sl) {
    return NormalizePrice(sl);
}

double NormalizeTP(double tp) {
    return NormalizePrice(tp);
}

double NormalizeLots(double lots) {
    double min   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double step  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double max   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

    double norm = MathMax(min, MathMin(max, lots));
    norm = MathFloor(norm / step) * step;
    return NormalizeDouble(norm, 2);
}

//+------------------------------------------------------------------+
//| Risk & Money Management                                           |
//+------------------------------------------------------------------+
double ComputeLotSize(double slPips, double riskPercent) {
    double acc = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmt = acc * (riskPercent / 100.0);

    double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

    if(tickSize == 0) tickSize = GetPoint();

    double slMoney = slPips * GetPoint() * tickVal / tickSize;
    if(slMoney <= 0) return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

    double lot = riskAmt / slMoney;
    return NormalizeLots(lot);
}

//+------------------------------------------------------------------+
//| Price Utilities                                                  |
//+------------------------------------------------------------------+
double HighestHigh(int startBar, int count) {
    double highest = 0;
    for(int i = startBar; i < startBar + count && i >= 0; i++) {
        double h = iHigh(_Symbol, PERIOD_CURRENT, i);
        if(h > highest) highest = h;
    }
    return highest;
}

double LowestLow(int startBar, int count) {
    double lowest = DoubleMax;
    for(int i = startBar; i < startBar + count && i >= 0; i++) {
        double l = iLow(_Symbol, PERIOD_CURRENT, i);
        if(l < lowest) lowest = l;
    }
    return lowest;
}

double MedianPrice(int bar) {
    return (iHigh(_Symbol, PERIOD_CURRENT, bar) + iLow(_Symbol, PERIOD_CURRENT, bar)) / 2.0;
}

double RangeSize(int startBar, int count) {
    double hi = HighestHigh(startBar, count);
    double lo = LowestLow(startBar, count);
    return hi - lo;
}

//+------------------------------------------------------------------+
//| Time / Session Helpers                                           |
//+------------------------------------------------------------------+
bool IsNewBar() {
    static datetime lastBarTime = 0;
    datetime curr = iTime(_Symbol, PERIOD_CURRENT, 0);
    if(curr != lastBarTime) {
        lastBarTime = curr;
        return true;
    }
    return false;
}

datetime SessionStart(int sessionHour) {
    MqlDateTime dt;
    TimeCurrent(dt);
    dt.hour = sessionHour;
    dt.min  = 0;
    dt.sec  = 0;
    return StringToTime(StringFormat("%04d.%02d.%02d %02d:%02d:00",
        dt.year, dt.mon, dt.day, sessionHour, 0));
}

long GetBarTime(int bar) {
    return iTime(_Symbol, PERIOD_CURRENT, bar);
}

//+------------------------------------------------------------------+
//| String Helpers                                                   |
//+------------------------------------------------------------------+
string DoubleToStr(double val, int digits) {
    return DoubleToString(val, digits);
}

// Symbol() uses built-in _Symbol in MT4

//+------------------------------------------------------------------+
//| Magic Number Helpers                                             |
//+------------------------------------------------------------------+
long GetMagicBuy()  { return 2025001; }
long GetMagicSell() { return 2025002; }
long GetMagic()     { return 2025000; }

bool IsMyOrder(ulong ticket, long magic) {
    if(OrderSelect(ticket)) {
        return OrderGetInteger(ORDER_MAGIC) == magic;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Array Helpers                                                    |
//+------------------------------------------------------------------+
void QS(double& arr[], int size) {
    // Quick sort descending for price levels
    ArrayResize(arr, size);
    for(int i = 0; i < size - 1; i++) {
        for(int j = i + 1; j < size; j++) {
            if(arr[i] < arr[j]) {
                double t = arr[i]; arr[i] = arr[j]; arr[j] = t;
            }
        }
    }
}

#endif // UTILS_MQH