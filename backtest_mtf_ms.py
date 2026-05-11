#!/usr/bin/env python3
"""
Breakout & Pullback EA — Backtest Engine v2
Includes MTF + Market Structure filter simulation
Author: Claude (7NAGA System)
"""

import math
import random
from datetime import datetime, timedelta

# ─── CONFIG ────────────────────────────────────────────────────────────
INIT_BAL        = 10_000.0
SYMBOL          = "XAUUSD"
RANGE_BARS      = 20
MIN_RANGE_PIPS  = 30.0   # Relaxed for XAUUSD simulation
RETEST_BARS     = 5
ATR_OFFSET      = 1.5
ATR_PERIOD      = 14
RISK_PCT        = 2.0
MAX_SPREAD      = 30
TP2_R           = 2.0
PIP_VALUE       = 10.0

# ─── MTF + MARKET STRUCTURE SIMULATION ─────────────────────────────────
MTF_ENABLED  = True   # Toggle MTF filter
MS_ENABLED   = True   # Toggle Market Structure filter

# ─── SYNTHETIC DATA GENERATOR ────────────────────────────────────────────
def generate_synthetic(start_date, days=180, volatility=2.5, trend=0):
    """Generate realistic H1 candles for XAUUSD simulation."""
    candles = []
    price = 1900.0
    date = datetime(start_date.year, start_date.month, start_date.day)
    
    for d in range(days):
        for h in range(24):
            change = random.gauss(0, volatility)
            if trend != 0:
                change += trend / 730.0
            
            open_p  = price
            high_p  = open_p + abs(random.gauss(0, volatility * 0.6))
            low_p   = open_p - abs(random.gauss(0, volatility * 0.6))
            close_p = open_p + change
            
            high_p  = max(high_p, open_p, close_p)
            low_p   = min(low_p, open_p, close_p)
            spread  = max(5, int(random.gauss(20, 5)))
            
            candles.append({
                "timestamp": date.strftime("%Y-%m-%d %H:%M"),
                "open":   round(open_p, 2),
                "high":   round(high_p, 2),
                "low":    round(low_p, 2),
                "close":  round(close_p, 2),
                "spread": max(5, spread),
            })
            price = close_p
            date += timedelta(hours=1)
    
    return candles

# ─── UTILS ──────────────────────────────────────────────────────────────
def pts_to_pips(pts):
    return pts * 10.0

def pips_to_pts(pips):
    return pips / 10.0

def calc_lot(balance, sl_pips, risk_pct=2.0):
    risk_amt = balance * (risk_pct / 100.0)
    sl_pips  = max(sl_pips, 10.0)
    lot      = risk_amt / (sl_pips * PIP_VALUE)
    lot      = math.floor(lot * 100) / 100.0
    return max(lot, 0.01)

def calc_atr(highs, lows, closes, period, idx):
    if idx < period + 1:
        return 0.5  # default small ATR
    trs = []
    for i in range(idx - period, idx):
        tr = max(highs[i] - lows[i],
                 abs(highs[i] - closes[i - 1]),
                 abs(lows[i] - closes[i - 1]))
        trs.append(tr)
    return sum(trs) / len(trs) if trs else 0.5

def pnl_from_points(pts, lot):
    return (pts / 0.01) * lot * PIP_VALUE

# ─── MARKET STRUCTURE SIMULATION ─────────────────────────────────────────
def detect_structure(candles, idx, lookback=50):
    """
    Simulate HH/HL (bullish) or LH/LL (bearish) structure detection.
    Uses rolling highs/lows with threshold to simulate swing detection.
    """
    if idx < lookback:
        return 0, 0, 0  # neutral
    
    # Find rolling highs/lows
    window = candles[max(0, idx - lookback):idx + 1]
    highs  = [c["high"] for c in window]
    lows   = [c["low"]  for c in window]
    
    # Simple approach: compare recent structure
    seg = 10  # segment size for structure
    if len(highs) < seg * 4:
        return 0, 0, 0
    
    # Get average highs/lows in segments
    def avg(lst, start, end):
        return sum(lst[start:end]) / (end - start)
    
    n = len(highs)
    h1 = avg(highs, n - seg,     n - seg * 0)
    h2 = avg(highs, n - seg * 2, n - seg * 1)
    l1 = avg(lows,  n - seg,     n - seg * 0)
    l2 = avg(lows,  n - seg * 2, n - seg * 1)
    
    # Bullish structure: HH + HL
    bullish = (h1 > h2 * 1.0001) and (l1 > l2 * 1.0001)
    # Bearish structure: LH + LL
    bearish = (h1 < h2 * 0.9999) and (l1 < l2 * 0.9999)
    
    if bullish: return 1, h1, l1
    if bearish: return -1, h1, l1
    return 0, h1, l1

# ─── MTF TREND SIMULATION ─────────────────────────────────────────────────
def get_mtf_trend(candles, idx):
    """
    Simulate MTF trend (D1+H4) using longer lookback MAs.
    """
    if idx < 120:
        return 0  # neutral
    
    # Simulate D1 MA (lookback ~24 bars per day = 5 days = 120 H1 bars)
    ma_fast = sum(c["close"] for c in candles[idx - 24:idx + 1]) / 25
    ma_slow = sum(c["close"] for c in candles[idx - 60:idx + 1]) / 61
    
    if ma_fast > ma_slow * 1.0001: return 1   # bullish
    if ma_fast < ma_slow * 0.9999: return -1  # bearish
    return 0  # neutral

# ─── BACKTEST WITH MTF + MS FILTER ────────────────────────────────────────
def run_backtest(candles, mtf_enabled=True, ms_enabled=True, 
                 show_trades=False, label=""):
    balance     = INIT_BAL
    wins        = losses = 0
    total_r     = 0.0
    trades_list = []
    state       = "IDLE"
    breakout_level = 0.0
    breakout_dir   = 0
    breakout_bar   = 0
    open_pos       = None
    blocked_mtf    = blocked_ms = 0
    
    highs  = [c["high"]  for c in candles]
    lows   = [c["low"]   for c in candles]
    closes = [c["close"] for c in candles]
    
    for i in range(len(candles)):
        c       = candles[i]
        close   = c["close"]
        high    = c["high"]
        low     = c["low"]
        spread  = c.get("spread", 20)
        
        if spread > MAX_SPREAD:
            continue
        
        # ── MTF Trend Check ────────────────────────────────────────────────
        mtf_trend = 0
        if mtf_enabled and i >= 120:
            mtf_trend = get_mtf_trend(candles, i)
        
        # ── Market Structure Check ─────────────────────────────────────────
        ms_trend = 0
        if ms_enabled and i >= 50:
            ms_trend, _, _ = detect_structure(candles, i, lookback=50)
        
        # ── Range Detection ───────────────────────────────────────────────
        if i >= RANGE_BARS:
            window = candles[i - RANGE_BARS + 1:i + 1]
            highest_high = max(x["high"] for x in window)
            lowest_low   = min(x["low"]  for x in window)
            range_pips   = pts_to_pips(highest_high - lowest_low)
            
            if range_pips >= MIN_RANGE_PIPS:
                atr_val  = calc_atr(highs, lows, closes, ATR_PERIOD, i)
                atr_pips = pts_to_pips(atr_val * ATR_OFFSET)
                open_c   = candles[i]["open"]
                
                # ── Breakout Detection ─────────────────────────────────────
                if state == "IDLE":
                    if close > highest_high and open_c <= highest_high:
                        # ── APPLY MTF + MS FILTER FOR BUY ───────────────
                        filter_pass = True
                        filter_reason = ""
                        
                        if mtf_enabled and mtf_trend < 0:
                            filter_pass = False
                            filter_reason = "MTF:BEAR"
                            blocked_mtf += 1
                        elif ms_enabled and ms_trend < 0:
                            filter_pass = False
                            filter_reason = "MS:BEAR"
                            blocked_ms += 1
                        
                        if filter_pass:
                            state          = "BREAKOUT_UP"
                            breakout_level = highest_high
                            breakout_dir   = 1
                            breakout_bar   = i
                        else:
                            if show_trades:
                                print(f"  [BLOCKED BUY @ {close:.2f}] {filter_reason}")
                        
                    elif close < lowest_low and open_c >= lowest_low:
                        # ── APPLY MTF + MS FILTER FOR SELL ─────────────
                        filter_pass = True
                        filter_reason = ""
                        
                        if mtf_enabled and mtf_trend > 0:
                            filter_pass = False
                            filter_reason = "MTF:BULL"
                            blocked_mtf += 1
                        elif ms_enabled and ms_trend > 0:
                            filter_pass = False
                            filter_reason = "MS:BULL"
                            blocked_ms += 1
                        
                        if filter_pass:
                            state          = "BREAKOUT_DOWN"
                            breakout_level = lowest_low
                            breakout_dir   = -1
                            breakout_bar   = i
                        else:
                            if show_trades:
                                print(f"  [BLOCKED SELL @ {close:.2f}] {filter_reason}")
                
                # ── Pullback Entry ─────────────────────────────────────────
                elif state in ("BREAKOUT_UP", "BREAKOUT_DOWN"):
                    if open_pos is None:
                        for r in range(1, min(RETEST_BARS + 1, i - breakout_bar)):
                            ri  = i - r
                            if ri < 0: break
                            rc  = candles[ri]
                            ro  = rc["open"]
                            rh  = rc["high"]
                            rl  = rc["low"]
                            rc_c = rc["close"]
                            
                            if state == "BREAKOUT_UP":
                                if rl <= breakout_level and rc_c > ro:
                                    entry    = rc_c
                                    sl       = min(breakout_level, rl) - pips_to_pts(atr_pips)
                                    sl_dist  = pts_to_pips(entry - sl)
                                    tp2      = entry + pips_to_pts(sl_dist * 2)
                                    lot      = calc_lot(balance, sl_dist)
                                    open_pos = {
                                        "type": "BUY", "entry": entry, "sl": sl,
                                        "tp2": tp2, "lot": lot, "r": sl_dist,
                                        "bar": i, "tp1_hit": False,
                                    }
                                    state = "ACTIVE_LONG"
                                    if show_trades:
                                        print(f"  [BUY] Entry {entry:.2f} | SL {sl:.2f} | TP2 {tp2:.2f}")
                                    break
                            
                            elif state == "BREAKOUT_DOWN":
                                if rh >= breakout_level and rc_c < ro:
                                    entry    = rc_c
                                    sl       = max(breakout_level, rh) + pips_to_pts(atr_pips)
                                    sl_dist  = pts_to_pips(sl - entry)
                                    tp2      = entry - pips_to_pts(sl_dist * 2)
                                    lot      = calc_lot(balance, sl_dist)
                                    open_pos = {
                                        "type": "SELL", "entry": entry, "sl": sl,
                                        "tp2": tp2, "lot": lot, "r": sl_dist,
                                        "bar": i, "tp1_hit": False,
                                    }
                                    state = "ACTIVE_SHORT"
                                    if show_trades:
                                        print(f"  [SELL] Entry {entry:.2f} | SL {sl:.2f} | TP2 {tp2:.2f}")
                                    break
                        
                        if open_pos is None and (i - breakout_bar) >= RETEST_BARS:
                            state = "IDLE"
        
        # ── Position Management ───────────────────────────────────────────
        if open_pos:
            cur = close
            tp2 = open_pos["tp2"]
            sl  = open_pos["sl"]
            entry = open_pos["entry"]
            
            if open_pos["type"] == "BUY":
                if cur >= tp2:
                    pnl = pnl_from_points(cur - entry, open_pos["lot"])
                    balance += pnl
                    r = open_pos["r"]
                    total_r += r
                    if r > 0: wins += 1
                    else: losses += 1
                    trades_list.append({
                        "dir": "BUY", "pnl": pnl, "r": r,
                        "entry": entry, "exit": cur, "result": "TP2"
                    })
                    if show_trades:
                        print(f"  >> BUY TP2  | PnL +${pnl:.2f} | {r:.1f}R")
                    open_pos = None
                    state = "IDLE"
                elif cur <= sl:
                    pnl = pnl_from_points(sl - entry, open_pos["lot"])
                    balance += pnl
                    r = open_pos["r"]
                    total_r += r
                    losses += 1
                    trades_list.append({
                        "dir": "BUY", "pnl": pnl, "r": -r,
                        "entry": entry, "exit": sl, "result": "SL"
                    })
                    if show_trades:
                        print(f"  >> BUY SL   | PnL ${pnl:.2f} | {-r:.1f}R")
                    open_pos = None
                    state = "IDLE"
            
            elif open_pos["type"] == "SELL":
                if cur <= tp2:
                    pnl = pnl_from_points(entry - cur, open_pos["lot"])
                    balance += pnl
                    r = open_pos["r"]
                    total_r += r
                    wins += 1
                    trades_list.append({
                        "dir": "SELL", "pnl": pnl, "r": r,
                        "entry": entry, "exit": cur, "result": "TP2"
                    })
                    if show_trades:
                        print(f"  >> SELL TP2 | PnL +${pnl:.2f} | {r:.1f}R")
                    open_pos = None
                    state = "IDLE"
                elif cur >= sl:
                    pnl = pnl_from_points(entry - sl, open_pos["lot"])
                    balance += pnl
                    r = open_pos["r"]
                    total_r += r
                    losses += 1
                    trades_list.append({
                        "dir": "SELL", "pnl": pnl, "r": -r,
                        "entry": entry, "exit": sl, "result": "SL"
                    })
                    if show_trades:
                        print(f"  >> SELL SL  | PnL ${pnl:.2f} | {-r:.1f}R")
                    open_pos = None
                    state = "IDLE"
    
    # ─── SUMMARY ───────────────────────────────────────────────────────────
    total_trades = wins + losses
    win_rate = wins / total_trades * 100 if total_trades > 0 else 0
    
    wins_pnl = sum(t["pnl"] for t in trades_list if t["pnl"] > 0)
    loss_pnl = sum(t["pnl"] for t in trades_list if t["pnl"] < 0)
    pf       = abs(wins_pnl / loss_pnl) if loss_pnl != 0 else 0
    
    # Max DD
    peak_bal = INIT_BAL
    max_dd   = 0.0
    bal_cur  = INIT_BAL
    for t in trades_list:
        bal_cur += t["pnl"]
        if bal_cur > peak_bal: peak_bal = bal_cur
        dd = (peak_bal - bal_cur) / peak_bal * 100
        if dd > max_dd: max_dd = dd
    
    sep = "=" * 70
    print(f"\n{sep}")
    print(f"  BREAKOUT & PULLBACK — BACKTEST RESULTS")
    print(f"  {label}")
    print(sep)
    print(f"  Initial Balance   : ${INIT_BAL:>12,.2f}")
    print(f"  Final Balance     : ${balance:>12,.2f}")
    print(f"  Net Profit        : ${balance - INIT_BAL:>12,.2f} ({((balance/INIT_BAL)-1)*100:+.1f}%)")
    print(f"  Total Trades      : {total_trades}")
    print(f"  Win  / Loss       : {wins} / {losses}")
    print(f"  Win Rate          : {win_rate:.1f}%")
    print(f"  Profit Factor     : {pf:.2f}")
    print(f"  Max Drawdown      : {max_dd:.1f}%")
    print(f"  Avg R per trade   : {total_r / total_trades:.3f}R" if total_trades else "")
    if mtf_enabled or ms_enabled:
        print(f"  Signals Blocked   : MTF={blocked_mtf} | MS={blocked_ms}")
    print(sep)
    
    return {
        "balance": balance,
        "total_trades": total_trades,
        "wins": wins,
        "losses": losses,
        "win_rate": win_rate,
        "profit_factor": pf,
        "max_dd_pct": max_dd,
        "avg_r": total_r / total_trades if total_trades else 0,
        "trades": trades_list,
        "blocked_mtf": blocked_mtf,
        "blocked_ms": blocked_ms,
    }

# ─── MAIN ─────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("Generating synthetic H1 data for 180 days (~4,320 bars)...")
    print("Volatility: 2.5 | Trend: +$200/yr (bullish bias)")
    random.seed(42)
    candles = generate_synthetic(datetime(2022, 1, 1), days=180,
                                  volatility=2.0, trend=300)
    print(f"Generated {len(candles)} candles\n")
    
    print("\n" + "=" * 70)
    print("  SCENARIO 1: WITHOUT MTF + MARKET STRUCTURE FILTER")
    print("=" * 70)
    r1 = run_backtest(candles, mtf_enabled=False, ms_enabled=False, label="NO FILTERS")
    
    print("\n" + "=" * 70)
    print("  SCENARIO 2: WITH MTF FILTER ONLY (D1+H4 Trend)")
    print("=" * 70)
    r2 = run_backtest(candles, mtf_enabled=True, ms_enabled=False, label="MTF ONLY")
    
    print("\n" + "=" * 70)
    print("  SCENARIO 3: WITH MTF + MARKET STRUCTURE FILTER")
    print("=" * 70)
    r3 = run_backtest(candles, mtf_enabled=True, ms_enabled=True, label="MTF + MS FILTER")
    
    # ─── COMPARISON TABLE ──────────────────────────────────────────────────
    print("\n\n" + "=" * 80)
    print("  COMPARISON TABLE — MTF + MARKET STRUCTURE FILTER IMPACT")
    print("=" * 80)
    print(f"  {'Metric':<20} {'No Filter':>15} {'MTF Only':>15} {'MTF+MS':>15}")
    print("-" * 80)
    print(f"  {'Total Trades':<20} {r1['total_trades']:>15} {r2['total_trades']:>15} {r3['total_trades']:>15}")
    print(f"  {'Win Rate':<20} {r1['win_rate']:>14.1f}% {r2['win_rate']:>14.1f}% {r3['win_rate']:>14.1f}%")
    print(f"  {'Profit Factor':<20} {r1['profit_factor']:>15.2f} {r2['profit_factor']:>15.2f} {r3['profit_factor']:>15.2f}")
    print(f"  {'Max DD %':<20} {r1['max_dd_pct']:>15.1f}% {r2['max_dd_pct']:>15.1f}% {r3['max_dd_pct']:>15.1f}%")
    print(f"  {'Final Balance':<20} ${r1['balance']:>14,.0f} ${r2['balance']:>14,.0f} ${r3['balance']:>14,.0f}")
    print(f"  {'Net Profit %':<20} {((r1['balance']/INIT_BAL)-1)*100:>+14.1f}% {((r2['balance']/INIT_BAL)-1)*100:>+14.1f}% {((r3['balance']/INIT_BAL)-1)*100:>+14.1f}%")
    print(f"  {'Avg R/trade':<20} {r1['avg_r']:>+15.3f} {r2['avg_r']:>+15.3f} {r3['avg_r']:>+15.3f}")
    print("=" * 80)
    print("\nFiltered trades breakdown:")
    print(f"  MTF blocked: {r3['blocked_mtf']} | MS blocked: {r3['blocked_ms']}")
    print(f"  Total filtered: {r3['blocked_mtf'] + r3['blocked_ms']}")