# SKILL — Auto Digit & Kelipatan 5

## Konsep

Auto-detect digit & pip untuk semua pasangan:
- XAUUSD (2 digit) → Point = MODE_POINT
- EURUSD (5 digit) → Point = MODE_POINT
- USDJPY (3 digit) → Point = MODE_POINT

Rumus pip: `GPip = (Digits == 3 || Digits == 5) ? GPoint * 10 : GPoint`

---

## Script MQL4 (Auto Digit)

```mql4
//+------------------------------------------------------------------+
//| Auto-detect digit & pip (works for all pairs)                    |
//+------------------------------------------------------------------+
#define GDigits ((int)MarketInfo(_Symbol, MODE_DIGITS))
#define GPoint  (MarketInfo(_Symbol, MODE_POINT))
#define GPip    ((GDigits == 3 || GDigits == 5) ? GPoint * 10 : GPoint)
```

---

## KELIPATAN 5 — Rounding Script

### Round UP (HIGH → Buy Stop)

```mql4
//+------------------------------------------------------------------+
//| ROUND UP TO MULTIPLE OF 5 (HIGH / Buy Stop)                      |
//+------------------------------------------------------------------+
double RoundToMultiple5_Up(double price) {
   double scaled = price * 100.0;
   double last2  = MathMod(scaled, 100.0);
   if(last2 <= 5.0) {
      scaled = MathFloor(scaled / 100.0) * 100.0 + 5.0;
   } else {
      scaled = MathFloor(scaled / 100.0) * 100.0 + 10.0;
   }
   return scaled / 100.0;
}
```

**Contoh:**
```
2600.02 -> 2600.05
2600.03 -> 2600.05
2600.04 -> 2600.05
2600.05 -> 2600.05
2600.07 -> 2600.10
2600.08 -> 2600.10
2600.09 -> 2600.10
```

### Round DOWN (LOW → Sell Stop)

```mql4
//+------------------------------------------------------------------+
//| ROUND DOWN TO MULTIPLE OF 5 (LOW / Sell Stop)                     |
//+------------------------------------------------------------------+
double RoundToMultiple5_Down(double price) {
   double scaled = price * 100.0;
   double last2  = MathMod(scaled, 100.0);
   if(last2 < 5.0) {
      scaled = MathFloor(scaled / 100.0) * 100.0;
   } else {
      scaled = MathFloor(scaled / 100.0) * 100.0 + 5.0;
   }
   return scaled / 100.0;
}
```

**Contoh:**
```
2590.03 -> 2590.00
2590.04 -> 2590.00
2590.05 -> 2590.00
2590.07 -> 2590.05
2590.08 -> 2590.05
2590.09 -> 2590.05
```

---

## Penggunaan

```mql4
double high = iHigh(_Symbol, PERIOD_M1, 1);
double low  = iLow(_Symbol, PERIOD_M1, 1);

double roundedHigh = RoundToMultiple5_Up(high);
double roundedLow  = RoundToMultiple5_Down(low);

double buyStop  = NormalizeDouble(roundedHigh + 100 * Point, Digits);
double sellStop = NormalizeDouble(roundedLow  - 25 * Point,  Digits);

// Hitung spread dalam pips
double pipsFactor = (Digits == 5 || Digits == 3) ? 10.0 : 1.0;
double spreadPips  = (buyStop - sellStop) / Point / pipsFactor;

Print("HIGH ", high, " -> Rounded UP: ", roundedHigh);
Print("LOW  ", low,  " -> Rounded DOWN: ", roundedLow);
Print("Buy Stop: ", buyStop, "  Sell Stop: ", sellStop);
Print("Spread: ", spreadPips, " pips");
```

---

## Catatan

- `Point` dan `Digits` adalah built-in MQL4 — tidak perlu declare
- `GPip` macro berguna untuk konversi point ke pips di semua pair
- MathMod(?, 100) untuk ambil 2 digit desimal terakhir dari harga