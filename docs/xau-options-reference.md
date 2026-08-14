# XAU Options Market Structure — Reference Guide

> Referensi bacaan level-level struktur pasar opsi XAU.
> Dilengkapi pipeline: `scripts/xau_options_levels.py` → `data/xau_options_levels.csv` → `MT5/Indicators/XAU_OptionsLevels.mq5`

---

## Call Wall (C-Wall)

**Apa:** Strike di atas harga sekarang dengan tumpukan gamma call terbesar → berfungsi sebagai **atap/resistance** dan magnet harga.

### Cara Baca

**C-Wall positif** → dealer long gamma → mereka **JUAL** saat harga naik mendekatinya → resistance kuat, harga cenderung mentok tepat di bawahnya.

**C-Wall negatif** → kalau **tembus ke atas**, dealer terpaksa **BELI** → kenaikan bisa **melejit cepat** (gamma squeeze).

### Pergeseran

| Pergerakan | Sinyal |
|---|---|
| C-Wall **naik terus** | Atap diangkat → **bullish**, ruang naik melebar |
| C-Wall **turun terus** | Resistance mendekati harga → **bearish**, ruang naik menyempit |

### Penggunaan

- **Positive gamma** → area **ambil profit / cari short** (fade), jangan taruh target jauh di atasnya.
- **Negative gamma** → jadikan **level pemicu breakout**: tembus + bertahan = ikut squeeze naik.

---

## Put Wall (P-Wall)

**Apa:** Strike di bawah harga sekarang dengan tumpukan gamma put terbesar → berfungsi sebagai **lantai/support** utama.

### Cara Baca

**P-Wall positif** → dealer **BELI** saat harga turun mendekatinya → support solid, harga cenderung **mantul naik**.

**P-Wall negatif** → kalau **tembus ke bawah**, dealer terpaksa **JUAL** makin banyak → **longsor cepat** (risiko crash).

### Pergeseran

| Pergerakan | Sinyal |
|---|---|
| P-Wall **naik terus** | Lantai terangkat mengikuti harga → **bullish** |
| P-Wall **turun terus** | Lantai menjauh → **bearish**, ruang turun terbuka |

### Penggunaan

- **Positive gamma** → area **cari BUY/bounce** saat mendekati P-Wall.
- **Negative gamma** → level **paling wajib dijaga**. Tembus ke bawah = sinyal bahaya, jangan tangkap pisau jatuh.

---

## Gamma Flip (Garis Regime)

**Apa:** Harga di mana **net gamma dealer berganti tanda** — garis pemisah yang membagi market menjadi dua kondisi (regime).

### Cara Baca

| Posisi Harga | Kondisi | Karakteristik |
|---|---|---|
| **DI ATAS** flip | Positive Gamma | Dealer meredam pergerakan → market tenang, range-bound, volatilitas rendah |
| **DI BAWAH** flip | Negative Gamma | Dealer memperbesar pergerakan → trending, liar, volatilitas tinggi |

### Penggunaan

Ini **saklar strategi** Anda:

- **Di atas flip** → main **pantulan** (mean-reversion).
- **Di bawah flip** → ikut **momentum/trend**.
- **Harga menembus flip** → sinyal **ganti mode**.
- **Harga menempel di flip** → regime rapuh → **kecilkan posisi**, tunggu konfirmasi.

---

## Ringkasan Cepat

| Level | Fungsi | Positive Gamma | Negative Gamma |
|---|---|---|---|
| **C-Wall** | Resistance / atap | Fade / ambil profit | Breakout trigger |
| **P-Wall** | Support / lantai | Buy / bounce zone | Danger line — jaga ketat |
| **Gamma Flip** | Saklar regime | Main mean-reversion | Main trend/momentum |

---

## Output Pipeline

```
scripts/xau_options_levels.py
        │
        ▼
data/xau_options_levels.csv   ← dibaca MT5
data/xau_options_levels.json  ← full analytics
        │
        ▼
MT5/Indicators/XAU_OptionsLevels.mq5
  ├─ 6 HLINE: C-WALL, P-WALL, Gamma Flip, Max Pain, Vol Trigger, Current Price
  ├─ Timer: reload tiap 60 detik
  └─ Label + status bar: GEX/DEX/Ratio/Condition/Confluence
```
