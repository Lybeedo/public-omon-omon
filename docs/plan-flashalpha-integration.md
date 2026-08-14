# XAU Options Pipeline — FlashAlpha Integration Plan

> Updated: 2026-08-14
> Status: Planning (Smith insight applied)

---

## Problem Statement

Pipeline mock data (`xau_options_levels.py`) perlu diganti dengan live options analytics.
FlashAlpha adalah kandidat API, namun free tier tidak cukup untuk MT5 live.

---

## FlashAlpha Assessment

| Aspek | FlashAlpha | Status |
|-------|------------|--------|
| GC=F (Gold Futures) | Support via CME Black-76 | ✅ Ada |
| GLD (ETF Proxy) | Support via US equities | ✅ Ada |
| Free tier | 5 req/hari | ❌ Mati untuk MT5 live |
| Basic tier | $79/bln ($63/thn), 250 req/hari | ✅ Cukup |
| Growth tier | $299/bln, 2,500 req/hari | Overkill |
| yfinance GC=F | Geo-blocked (Contabo) | ❌ 0 expirations |
| yfinance GLD | Jalan | ✅ Valid |

---

## Solution: GLD Proxy + Scale ×10

Pattern sudah teruji di engine pandora:
```
real_ticker: GC=F
etf_proxy: GLD
etf_price_scale: 10.0
```

### Logic

```
FlashAlpha API
    │
    ▼
fa.exposure_levels("GLD")
    │
    │  → call_wall, put_wall, gamma_flip, max_pain, vol_trigger
    │  → net_gex, net_dex, gex_ratio
    │
    ▼ Scale × 10 (gold price = GLD price × 10)
    │
    ▼
data/xau_options_levels.csv
    │
    ▼
MT5/Indicators/XAU_OptionsLevels.mq5
```

---

## Technical Plan

### Phase 1: Test Free Tier
```bash
pip install flashalpha
```
```python
from flashalpha import FlashAlpha

fa = FlashAlpha("YOUR_FREE_KEY")

# Test GLD (equity proxy)
levels = fa.exposure_levels("GLD")
print(levels)

# Expected output:
# {
#   "levels": {
#     "call_wall": float,
#     "put_wall": float,
#     "gamma_flip": float,
#     "max_pain": float,
#     "vol_trigger": float
#   },
#   "net_gex": float,
#   "net_dex": float,
#   "gex_ratio": float
# }
```

**Validasi:**
- Apakah GLD return valid exposure levels?
- Apakah harga call_wall/put_wall masuk akal (~350-400 untuk GLD)?

### Phase 2: Upgrade to Basic (jika valid)
- Monthly: $79/bln
- Annual: $63/bln (hemat ~20%)
- 250 req/hari → cukup untuk cron 15 menit = 96 req/hari

### Phase 3: Update Script
**File:** `scripts/xau_options_levels.py`

```python
# === NEW: FlashAlpha Integration ===
from flashalpha import FlashAlpha, TierRestrictedError

def fetch_levels_flashalpha(api_key, symbol="GLD", scale=10.0):
    """Fetch live options levels via FlashAlpha, scale to gold price."""
    fa = FlashAlpha(api_key)
    try:
        data = fa.exposure_levels(symbol)
        levels = data.get("levels", {})
        
        # Scale to gold price
        scaled_levels = {k: v * scale for k, v in levels.items()}
        
        # Also get GEX/DEX
        gex_data = fa.gex(symbol)
        scaled_levels["net_gex"] = gex_data.get("net_gex", 0) * scale
        scaled_levels["net_dex"] = gex_data.get("net_dex", 0) * scale
        scaled_levels["gex_ratio"] = gex_data.get("gex_ratio", 0)
        
        return scaled_levels
    except TierRestrictedError as e:
        print(f"[ERROR] Tier restricted: {e}")
        return None
    except Exception as e:
        print(f"[ERROR] {e}")
        return None
```

### Phase 4: Cron Setup (15-minute reload)
**File:** `cron/xau_options_reload.sh`
**Cron:** Every 15 minutes

```bash
#!/bin/bash
cd /opt/data/public-omon-omon
/usr/bin/python3 scripts/xau_options_levels.py --api-key "$FLASHALPHA_KEY" --mode flashalpha
```

### Phase 5: MT5 Indicator Update
**File:** `MT5/Indicators/XAU_OptionsLevels.mq5`

Tidak perlu ubah — indicator sudah read CSV. Cukup update cron.

---

## Cost Analysis

| Tier | Price | Req/hari | Cukup? |
|------|-------|----------|--------|
| Free | $0 | 5 | ❌ Mati |
| Basic | $79/bln ($63/thn) | 250 | ✅ Cukup |
| Growth | $299/bln | 2,500 | ⚠️ Overkill |

**Recommendation:** Basic annual ($63/thn) = ~$5.25/bln.

---

## Files to Create/Modify

| Action | File | Purpose |
|--------|------|---------|
| Create | `scripts/xau_options_levels.py` | Update with FlashAlpha integration |
| Create | `cron/xau_options_reload.sh` | 15-min cron script |
| Create | `.env.flashalpha` | Store API key (gitignored) |
| Modify | `docs/plan-flashalpha-integration.md` | This file |
| No change | `MT5/Indicators/XAU_OptionsLevels.mq5` | Already reads CSV |

---

## Decision Points

1. **Test free tier first** → validasi GLD data sebelum bayar
2. **Annual vs monthly** → annual hemat 20% ($63 vs $79/bln)
3. **Cron interval** → 15 menit cukup (96 req/hari < 250 limit)
4. **Fallback** → jika FlashAlpha down, pakai mock data lama

---

## Next Steps

- [ ] Daftar FlashAlpha → dapat free key
- [ ] Test `fa.exposure_levels("GLD")` dengan free key
- [ ] Validasi output (call_wall, put_wall, gamma_flip masuk akal)
- [ ] Jika valid → upgrade ke Basic annual
- [ ] Update `xau_options_levels.py` dengan integrasi FlashAlpha
- [ ] Setup cron 15-menit
- [ ] Test MT5 indicator read CSV baru
