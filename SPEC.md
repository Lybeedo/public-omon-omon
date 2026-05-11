# SPEC — Strategy & EA List

## Published EAs

### 7NAGA
**File:** `MQL4/Experts/SevenCandleNaga.mq4`, `MQL5/Experts/SevenCandleNaga.mq5`  
**Symbol:** GOLD (XAUUSD) | **Timeframe:** Intraday  
**Method:** Buy Stop + Sell Stop berbasis HIGH/LOW 7 candle M1

**Rules:**
- Analisis: 09:30 WIB | Expiry: 17:00 WIB
- Buy Stop = HIGH (kelipatan 5) + 100 pts
- Sell Stop = LOW (kelipatan 5) - 25 pts
- SL = oneshot (Buy SL = Sell Stop, Sell SL = Buy Stop)
- 6 zona TP: 10/15/30/50/100/200 pips (0.01 lot per zona)
- Filter: Senin, NFP, FOMC, CPI, US Holiday
- Distance: 70-200 pips (outside = skip)

---

### CoinFlipEA
**File:** `MQL5/Experts/CoinFlipEA.mq5`  
**Symbol:** Multi-pair | **Timeframe:** Configurable (M1 default)  
**Method:** Flip trading dengan kapitalisasi

**Rules:**
- Start: $500 → Target: $5000
- RR 1:2 — Risk $50, Reward $100
- Lot sizing otomatis berdasarkan risk per trade
- Flip trigger: new candle / instant
- Filter sesi: Asia, London, New York (opsional)
- Stop on bust atau target reached

---

### 7NAGA Telegram Signal
**File:** `MQL5/Experts/SevenNagaSignal_MQ5.mq5`  
**Symbol:** GOLD (XAUUSD) | **Timeframe:** M30  
**Method:** Indikator + auto-send signal ke Telegram

**Rules:**
- Ambil HIGH/LOW dari N candle terakhir (default: 7)
- Kirim pesan ke Telegram: Buy Stop price, Sell Stop price
- Gambar garis HIGH (merah) dan LOW (hijau) di chart
- Skip Senin jika enabled
- Configurable: WIB offset, hour send, pip offset

---

## Under Development

### mentahan/
Koleksi EA mentah / baseline untuk referensi:
- `MTF_Trend_Confluence.mq4`
- `Murray Expert v6.mq4`
- `Prime_Quantum_AI.mq5`
- `RoyalHegen_EA.mq5`