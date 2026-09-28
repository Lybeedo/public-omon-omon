# XAU M15 EMA 9/21 Chart — Reusable Skill

Gambar chart candlestick XAUUSD timeframe M15 dengan indikator EMA 9 dan EMA 21.

## Sumber Data

| Sumber | Endpoint | Data | Auth | Catatan |
|--------|----------|------|------|---------|
| **Spot reference** | `https://api.gold-api.com/price/XAU` | Harga spot XAU/USD real-time | Tidak perlu | Free, rate-limit longgar (cache 30s) |
| **Candle M15** | `https://api.binance.com/api/v3/klines?symbol=XAUTUSDT&interval=15m` | OHLCV 15 menit | Tidak perlu | XAUTUSDT = Tether Gold, proxy spot-like untuk XAUUSD |

> gold-api gratis **tidak menyediakan OHLC intraday**; oleh karena itu candle dan EMA dihitung dari XAUTUSDT, sedangkan harga spot gold-api ditampilkan sebagai referensi/annotasi.

## File Reusable

- `scripts/xau_m15_ema_chart.py` — Python script lengkap: fetch spot, fetch klines, hitung EMA, gambar chart.

## Cara Pakai

```bash
cd public-omon-omon
uv run --with requests,pandas,mplfinance python3 scripts/xau_m15_ema_chart.py --output xau_m15.png
```

Parameter:

| Flag | Default | Keterangan |
|------|---------|------------|
| `--symbol` | `XAUTUSDT` | Simbol Binance (bisa `XAUTUSDT` atau `PAXGUSDT`) |
| `--interval` | `15m` | Interval candle |
| `--bars` | `200` | Jumlah candle |
| `--output` | `xau_m15_ema_chart.png` | Path file output |

## Output Contoh

```text
Gold-API spot: 4301.00 USD @ 2026-09-25T12:41:58Z
Latest close: 4296.51 | EMA9: 4298.65 | EMA21: 4293.53
Saved chart to xau_m15.png
```

## Interpretasi Cepat

- `Close > EMA9 > EMA21` → bullish sequence M15.
- `Close < EMA9 < EMA21` → bearish sequence M15.
- Harga di antara EMA9 dan EMA21 → konsolidasi / pull-back ke zona EMA.

## Integrasi ke Bot / Pipeline

```python
from scripts.xau_m15_ema_chart import fetch_gold_api_spot, fetch_binance_klines

spot = fetch_gold_api_spot()
df = fetch_binance_klines("XAUTUSDT", "15m", 200)
df["EMA9"] = df["Close"].ewm(span=9, adjust=False).mean()
df["EMA21"] = df["Close"].ewm(span=21, adjust=False).mean()
```

## Pitfalls

- XAUTUSDT bisa menyimpang tipis dari quote XAUUSD broker (spread, premium/discount tokenized gold).
- Binance API bisa 451/429 saat rate limit; tambahkan retry/backoff jika di production.
- gold-api spot cocok untuk referensi, bukan untuk eksekusi tick-precise — gunakan harga dari MT5/broker untuk entry.
- Selalu set `User-Agent` saat fetch gold-api untuk menghindari blokir edge.

## Verifikasi

- [ ] Script berjalan tanpa error dan menghasilkan PNG.
- [ ] `Gold-API spot` numeric dan `updatedAt` < 60 detik.
- [ ] EMA9 dan EMA21 muncul sebagai garis di chart.
- [ ] Output PNG bisa dibuka/dikirim ke Telegram.
