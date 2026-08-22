# 7H Profile Framework
**Author:** Bob Cuan / @macrocircle  
**Source:** https://www.mql5.com/en/articles/18867  
**PDF Origin:** Canva (Juli 2026)  
**Shared by:** YudTira ⦿ in Cuancux Algo Traders (Thread 777)

---

## Konsep Utama

7H Profile adalah **penyempurnaan trade intraday** dari Daily Profile. Menggunakan struktur PO3 (Power of Three) untuk mengidentifikasi setup harian yang ideal dan logis.

### Candle Timing Reference (WIB)

| Candle | Timeframe | Open (WIB) | Fungsi |
|--------|-----------|------------|--------|
| **c1** | Daily | 23:00 | Buka candle harian — tentukan **bias** awal |
| **c2** | 7H | 08:00 | **London session** — cari *reversal / swing point* |
| **c3** | 7H | 15:00 | **NY session AM** — eksekusi trade (continue) |
| **c4** | 7H | 22:00 | **NY session PM** — close / wrap up |

> **Catatan:** Timeserver broker bisa berbeda. Selalu konfirmasi dengan chart.

---

## Candle Timing Reference (broker offset Exness)

| Candle | Deskripsi | Contoh Timing |
|--------|-----------|---------------|
| **c1** | Daily open | 23:00 WIB |
| **c2** | London 7H range | 08:00 WIB |
| **c3** | NY 7H range open | 15:00 WIB |
| **c4** | NY 7H PM close | 22:00 WIB |

---

## Framework 7H — Buy Scenario

```
c1 (Daily) → c2 (London) → c3 (NY 08:00)
     ↓            ↓              ↓
  18:00        01:00          08:00
(Open)    (Reversal?)    (BUY Continue)
```

### Langkah-langkah:

1. **D1 bias Bullish** → london (c2) membentuk *reversal swing point*
2. Konfirmasi London reversal → **c2 closing bearish** = signal
3. Tunggu **c3 NY 08:00** sebagai kelanjutan (continue) → **BUY**
4. Cari **PDA** (Price Delivery Area) di area sumbu candle 7H
5. H1/M30 confirm di PDA → tunggu swing point formation
6. Entry di **LTF (M3/M2)** dengan konfirmasi **CISD** (Change in State of Delivery)

---

## Framework 7H — Sell Scenario

```
c1 (Daily) → c2 (London) → c3 (NY 08:00)
     ↓            ↓              ↓
  18:00        01:00          08:00
(Open)    (Reversal?)    (SELL Continue)
```

### Langkah-langkah:

1. **D1 bias Bearish** → London (c2) membentuk *bearish reversal*
2. London menutup **bearish ekspansi** → persistence arah harian
3. Tunggu **c3 NY 08:00** → **SELL continuation**
4. Cari **PDA** di sumbu candle 7H
5. Konfirmasi formasi + **CISD** di LTF

---

## Multi-Timeframe Checklist (A=M=AMD)

| TF | Aktivitas |
|----|-----------|
| **D1** | Identifikasi bias harian + daily profile |
| **7H** | Tangkap reversal London (c2) → confirm arah c3 |
| **H1/M30** | Tempatkan di PDA, tunggu swing point |
| **M3/M2** | Konfirmasi CISD untuk entry trigger |

### Siklus A=M=D:

- **A** (Analysis): D1 + 7H analysis
- **M** (Market): H1/M30 di PDA, tunggu formasi
- **D** (Delivery): M3/M2 CISD confirmation → Entry

---

## Konfluensi Wajib

| Komponen | Fungsi |
|----------|--------|
| **SMT / SSMT** | Divergence confirmation antar-TF |
| **EQ 50%** | Equilibrium level dari TF tinggi |
| **CISD** | Trigger entry (Change in State of Delivery) |
| **PO3 (Power of Three)** | Struktur candle: 3 candle sequence → reversal/continue |

### Contoh Konfluensi:

> London didukung formasi lainnya, membentuk swing point dan dukungan **SMT/SSMT** yang selaras dengan **EQ 50%** pada MTF. Ini menyempurnakan bahwa MTF melakukan reversal & manipulasi pada sumbu 7H.

---

## Pattern Types

### Profile Bullish
- London konsolidasi → reversal → ekspansi
- c2 closure → c3 continuation → c2 closure into expansion

### Profile Bearish
- London & NY bearish ekspansi
- Continuation pattern dari London ke NY session

### Special Cases
- **London Reversal**: London manipulasi to reversal
- **NY Manipulation**: NY session yang memanipulasi price ke arah reversal

---

## ⚠️ Golden Rule

> **"Jika tidak ada formasi pembentukan dalam framework tersebut, kita TIDAK memaksakan trade dalam kondisi yang buruk."**

### Implikasi Praktis:
- ❌ Tidak ada setup = **No trade**
- ❌ Setup tidak confluent = **Skip**
- ✅ Formasi ada + konfluensi = **Eksekusi**

---

## Integrasi dengan Tools Lain

### Dengan XAU Options Levels (AthFX):

```
C-WALL        = Resistance area
P-WALL        = Support area
Gamma Flip    = Confirm direction bias
Max Pain      = Balance point
```

Jika price di atas C-WALL + London reversal confirmed → bias BUY kuat.

### Dengan CISD Pattern:

- **CISD** = Change in State of Delivery
- Digunakan sebagai trigger entry di LTF
- Confirm reversal pada TF yang lebih rendah

---

## Checklist Sebelum Entry

- [ ] D1 bias teridentifikasi (Bullish/Bearish)
- [ ] London (c2) membentuk reversal swing point
- [ ] c2 closing sesuai arah bias
- [ ] c3 NY session terbuka sesuai arah
- [ ] PDA teridentifikasi di 7H
- [ ] H1/M30 confirm di PDA
- [ ] SMT/SSMT divergence teridentifikasi
- [ ] EQ 50% confluent dengan level
- [ ] CISD trigger terbentuk di M3/M2
- [ ] R:R minimal 2:1

---

## Workflow per Hari

```
00:00-01:00  → Setup D1, identifikasi bias
01:00-08:00  → Monitor London (c2)
08:00         → c2 closing → evaluate reversal
08:00-15:00  → Monitor NY AM (c3), tunggu PDA
15:00         → c3 closing
15:00-22:00  → Monitor NY PM (c4), wrap up
22:00         → c4 closing, review hari
```

---

## Referensi Tambahan

- [Volume Profile Strategy Guide](/opt/data/cache/documents/doc_764cad839304_volume-profile-strategy-guide.pdf) — document yang sering disharing di group
- [XAU Options Levels](/opt/data/scripts/xau_options_levels.py) — pipeline untuk options levels

---

**Disclaimer:** Framework ini berdasarkan PDF dari @macrocircle (Bob Cuan). Test terlebih dahulu di demo sebelum apply ke live account. Risk management tetap jadi tanggung jawab masing-masing.