# XAU Price Feed — Spot & Futures (Reusable Skill)

Sumber harga spot **XAU $4,469.39 (2026-09-04 10:25 UTC)** yang dipakai Omon diambil live dari:

| Sumber | Endpoint | Data yang diambil | Auth | Rate Limit |
|--------|----------|-------------------|------|------------|
| **Primary — Spot** | `https://api.gold-api.com/price/XAU` | `price`, `updatedAt`, `currency` | None (free) | ~1 req/s |
| **Secondary — Futures** | `https://query1.finance.yahoo.com/v8/finance/chart/GC=F?interval=1d&range=1mo` | `regularMarketPrice`, `regularMarketDayHigh/Low`, `fiftyTwoWeekHigh/Low` | None, but needs `User-Agent` | Yahoo throttle |
| **Tertiary fallback** | `https://api.metals.live/v1/spot` atau `https://www.goldapi.io/api/XAU/USD` | Spot | API key (optional) | Paid tier |

> Verifikasi 2026-09-04 10:25 UTC: `gold-api -> 4469.399902`, `Yahoo GC=F -> 4518.4 (-0.47%, 4506.6-4537.8, 52W 3567.8-5586.2)` — lihat curl log di session ini.

## Kapan Pakai Skill Ini
- Butuh harga XAU live untuk analisa trend HTF, filter EMA200/ADX, atau display di EA/dashboard tanpa MT5
- Mau feed yang sama dipakai lintas project (PHP/Laravel, Python backtest, Telegram bot, MQL5)
- Perlu fallback chain agar bot tidak mati saat satu API down

## Cara Pakai — 1-liner (curl)

```bash
# Spot (gold-api) — recommended, tanpa key
curl -s https://api.gold-api.com/price/XAU -H "User-Agent: Mozilla/5.0" | jq .

# Futures (Yahoo) — butuh interval & range
curl -s "https://query1.finance.yahoo.com/v8/finance/chart/GC=F?interval=1d&range=1mo" \
  -H "User-Agent: Mozilla/5.0" | jq '.chart.result[0].meta | {regularMarketPrice, regularMarketDayHigh, regularMarketDayLow, fiftyTwoWeekHigh, fiftyTwoWeekLow}'
```

## Cara Pakai — Python (copas ke project lain)

```python
import requests

def get_xau_price(timeout=10):
    # Returns dict spot/futures/source with fallback chain.
    try:
        r = requests.get("https://api.gold-api.com/price/XAU", headers={"User-Agent":"Mozilla/5.0"}, timeout=timeout)
        r.raise_for_status()
        j = r.json()
        spot = float(j["price"])
        return {"spot": spot, "source": "gold-api", "raw": j}
    except Exception as e:
        print(f"gold-api fail: {e}")
    try:
        r = requests.get("https://query1.finance.yahoo.com/v8/finance/chart/GC=F",
                         params={"interval":"1d","range":"1mo"},
                         headers={"User-Agent":"Mozilla/5.0"}, timeout=timeout)
        r.raise_for_status()
        meta = r.json()["chart"]["result"][0]["meta"]
        return {"spot": float(meta["regularMarketPrice"]), "source": "yahoo GC=F", "raw": meta}
    except Exception as e:
        print(f"yahoo fail: {e}")
        raise RuntimeError("All XAU price sources failed")
```

## Cara Pakai — MQL5 (EA langsung)

```mql5
// WebRequest — tambahkan URL ke Tools > Options > Expert Advisors > Allow WebRequest
string XAU_Spot()
{
  char post[], result[];
  string headers = "User-Agent: Mozilla/5.0\r\n";
  string url = "https://api.gold-api.com/price/XAU";
  if(!WebRequest("GET", url, headers, 5000, post, result)) return "ERR";
  return CharArrayToString(result);
}
```

## Cara Pakai — PHP / Laravel

```php
$spot = Http::withHeaders(['User-Agent'=>'Mozilla/5.0'])
  ->timeout(10)->get('https://api.gold-api.com/price/XAU')->json()['price'];
```

## Fallback Chain (Wajib di Production)

1. `gold-api` -> 2. `Yahoo GC=F` -> 3. cache last price (file/redis 5 menit) -> 4. error ke Telegram
- Jangan hammer API tiap tick M1 — cache 30-60s, cukup untuk H4/D1 bias.

## Verifikasi Setelah Integrasi

- [ ] `curl gold-api` return `price` numeric & `updatedAt` < 60s
- [ ] Yahoo `regularMarketPrice` dalam range 3500-6000 (guard typo)
- [ ] Log source yang terpakai (gold-api vs yahoo vs cache) untuk debug
- [ ] MT5 WebRequest whitelist sudah ditambah, jika pakai MQL5

## Pitfalls

- Yahoo tanpa `User-Agent` sering 429/404 — selalu set header.
- `XAUUSD=X` di Yahoo sering delisted — pakai `GC=F` untuk futures proxy, atau gold-api untuk spot murni.
- Jangan simpan API key goldapi.io di repo — pakai `.env:GOLD_API_KEY`.
- Timezone: `updatedAt` gold-api UTC, Yahoo `regularMarketTime` EDT (gmtoffset -14400) — normalisasi sebelum bandingkan.

## Referensi Session Ini

- Snapshot: `XAU 4469.39 (gold-api) | GC=F 4518.4 -0.47% | 52W 3567.8-5586.2` — 2026-09-04 10:25 UTC
- Repo skill path: `skills/xau-price-feed.md` (file ini)

*Analisa teknikal otomatis, bukan saran investasi. Harga live berubah tiap detik — selalu re-fetch sebelum entry.*
