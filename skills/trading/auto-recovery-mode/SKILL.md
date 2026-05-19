---
name: auto-recovery-mode
description: Auto Recovery Mode — strategi recovery posisi trading tanpa cut loss, locking profit pelan-pelan sambil averaging dari level lebih baik
category: trading
---

# Auto Recovery Mode

Strategi auto recovery posisi tanpa cut loss — BUKAN martingale agresif.

## Prinsip Inti

- **BUKAN:** Menambah lot di arah yang sama (martingale agresif)
- **TAPI:** Menambah posisi kecil di arah recovery, locking profit pelan-pelan sambil averaging posisi utama dari level yang lebih baik

## Struktur Auto Recovery

### Phase 1: Loss Detected
- Equity drop 5% dari peak
- → Aktifkan Recovery Mode
- → Set trigger untuk phase berikutnya

### Phase 2: Recovery Trigger
- Tunggu konfirmasi reversal / pullback
- Tambahkan posisi kecil di arah recovery
- Set locking profit bertahap (misal: 5-10 pip per stage)

### Phase 3: Averaging
- Rata-rata posisi utama dari level lebih baik
- Geser stop loss pelan-pelan ke breakeven

### Phase 4: Close Recovery
- Tutup semua posisi recovery
- Biarkan posisi utama jalan dengan SL di breakeven

## Risk Note
> Ini BUKAN "no risk" — tapi "delay risk management" sambil kerja recovery. Equity tetap drawdown sampai recovery selesai.

## Implementation Notes (MQL5)
- Pakai PositionGetDouble(POSITION_PROFIT) untuk cek equity
- Tracking AccountInfoDouble(ACCOUNT_EQUITY) peak
- Recovery订单 pake lot kecil (0.01-0.1 lot) — sesuaikan sama balance
- Simpan state recovery di global variables atau file
