# Prompt Engineering Frameworks

Koleksi kerangka prompt untuk menghasilkan output sesuai ekspektasi. Dua level: **daily use** dan **deep adversarial reasoning**.

---

## 1. RTCFOSSRC

**Gunakan untuk:** tugas sehari-hari, query biasa, output predictable.

| # | Element | Deskripsi |
|---|---------|-----------|
| 1 | **Role** | Peran AI (expert, analyst, coach...) |
| 2 | **Task** | Tugas spesifik yang diharapkan |
| 3 | **Context** | Latar belakang, constraints, audience |
| 4 | **Fokus** | Area重点, apa yang harus di-highlight |
| 5 | **Output** | Format output (JSON, markdown, bullet...) |
| 6 | **Style** | Tone, voice, terminologi |
| 7 | **Stop** | Batasan, apa yang TIDAK boleh |
| 8 | **Reasoning** | Langkah berpikir sebelum answer |
| 9 | **Criteria** | Standar sukses, kondisi pass/fail |

### Contoh: Market Analysis

```
Role: Senior Technical Analyst
Task: Analisa setup BUY untuk EURUSD H1
Context: Trend bull mingguan, ADX 25, ada resistance 1.0900
Fokus: Entry zone, SL, TP, risk/reward
Output: Markdown dengan bullets + level harga
Style: Concise, pakai istilah trading (SL/TP/breaker)
Stop: Jangan kasih sinyal contrário dengan trend
Reasoning: (1) ID trend → (2) check SR → (3) find entry → (4) calc RR
Criteria: RR minimal 2:1, SL不超过 50 pips
```

---

## 2. AETHER-11

**Gunakan untuk:** adu mekanik, problem solving kompleks, reasoning layers.

| # | Element | Deskripsi |
|---|---------|-----------|
| 1 | **Archetype** | Persona dasar — siapa AI ini |
| 2 | **Objective** | Tujuan utama — apa outcome yang mau dicapai |
| 3 | **Horizon** | Timeframe — jangka pendek/medium/long |
| 4 | **Essence** | Inti problema — esensi dari pertanyaan |
| 5 | **Precision** | Presisi yang diharapkan — ketepatan level mana |
| 6 | **Output Architecture** | Struktur output — bagaimana output diorganisir |
| 7 | **Resonance** | Kohesi — output harus nyambung antar layer |
| 8 | **Abyss** | Edge cases — skenario ekstrem, corner cases |
| 9 | **Cognition Protocol** | Proses berpikir — meta-step reasoning |
| 10 | **Excellence Criteria** | Standar excelência — kapan output dianggap *good* |
| 11 | **Evolution Layer** | Loop — output akhir ngirim balik ke Archetype untuk refinement |

### Perbedaan kunci vs RTCFOSSRC

- **Recursive** — Evolution Layer bikin output nggak linear, tapi looping
- **Recursive depth** — Archetype → Output → Archetype review → refined output
- **Abyss** — wajib cover corner cases yang RTCFOSSRC nggak handle
- **Essence extraction** — harus identify esensi problema sebelum mulai reasoning

### Contoh: EA Strategy Design

```
Archetype: MQL5 Expert Advisor Designer — institusi, disiplin
Objective: Design breakout EA dengan drawdown < 15%
Horizon: Medium term — viable untuk forward test
Essence: Entry trigger + MM yang robust di kondisi volatile
Precision: Exact pip levels, ATR multipliers, lot formula
Output Architecture: (1) Concept → (2) Logic flow → (3) Code structure → (4) Edge cases
Resonance: Semua modul harus nyambung — signal, MM, exit
Abyss: Gap up/down, news spike, broker requote, spread widening
Cognition Protocol: (1) Problem decomp → (2) Hypothesis → (3) Test logic → (4) Validate
Excellence Criteria: Kompilasi bersih, bisa backtest langsung, no hardcoded magic numbers
Evolution Layer: Output di-review oleh Archetype lagi → refine jadi final version
```

---

## 3. OMNIA (Coming Soon)

Prompt level terakhir — bikin model *lag* karena context window sangat besar.

> ⚠️ **OMNIA bikin ngelag** — artinya model dipaksa hit limit context window.
> Lebih detail akan di-share nanti.

### Spekulasi dari pattern:

- Kemungkinan besar ini **recursive multi-agent** — output layer A jadi input layer B, dst.
- Atau **chain-of-thought yang sangat panjang** dengan self-reflection loop.
- Atau **context stuffing** — inject memory/knowledge base langsung ke prompt.

### Warning:

Kalau OMNIA beneran bikin lag, berarti:
- Token consumption sangat tinggi
- Cost per query mahal
- Cocok untuk **batch processing**, bukan real-time

---

## Quick Reference

| Situasi | Framework |
|---------|-----------|
| Chat quotidiano | RTCFOSSRC |
| Build EA / Strategy | AETHER-11 |
| System design complex | AETHER-11 (bisa stack 2x) |
| Batch analysis berat | Tunggu OMNIA |
| Real-time signal | RTCFOSSRC + Style: urgent |

---

## Catatan

- RTCFOSSRC dan AETHER-11 bisa digabung — pakai RTCFOSSRC sebagai base, tambahin Evolution Layer dari AETHER-11.
- Stop criteria di RTCFOSSRC itu powerful — tanpa itu, AI cenderung over-explain.
- Evolution Layer bukan untuk semua task — overkill kalau query-nya simple.

**Source:** Paulus Is — Cuancux Algo Traders community