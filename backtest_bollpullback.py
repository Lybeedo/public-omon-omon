#!/usr/bin/env python3
"""
Breakout & Pullback EA — Full Backtest Engine
Author: Claude (7NAGA System)
Pair: XAUUSD | Timeframe: H1
Fetches real data via yfinance or uses synthetic data.
"""

import math
import csv
import sys
import random
import argparse
from datetime import datetime, timedelta

# ─── CONFIG ────────────────────────────────────────────────────────────
INIT_BAL        = 10_000.0
SYMBOL          = "XAUUSD"
RANGE_BARS      = 20
MIN_RANGE_PIPS  = 100.0
RETEST_BARS     = 5
ATR_OFFSET      = 1.5
ATR_PERIOD      = 14
RISK_PCT        = 2.0
MAX_SPREAD      = 30
MAGIC           = 99999
TP2_R           = 2.0
PIP_VALUE       = 10.0   # $ per pip per 1.0 lot for XAUUSD

# ─── UTILS ────────────────────────────────────────────────────────────
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

def calc_atr(highs, lows, closes, period):
    trs = []
    for i in range(1, min(period + 1, len(closes))):
        tr = max(highs[i] - lows[i],
                 abs(highs[i] - closes[i - 1]),
                 abs(lows[i] - closes[i - 1]))
        trs.append(tr)
    return sum(trs) / len(trs) if trs else 0

def pnl_from_points(pts, lot):
    return (pts / 0.01) * lot * PIP_VALUE

# ─── BACKTEST CORE ─────────────────────────────────────────────────────
def run_backtest(candles, show_trades=False, summary_only=False):
    balance  = INIT_BAL
    wins = losses = 0
    total_r  = 0.0
    trades_list  = []
    state = "IDLE"
    breakout_level = 0.0
    breakout_dir   = 0
    breakout_bar   = 0
    highest_high   = 0.0
    lowest_low     = 0.0
    open_pos = None

    for i in range(len(candles)):
        c = candles[i]
        close = c["close"]
        high  = c["high"]
        low   = c["low"]
        spread = c.get("spread", 20)
        bar_ts = c.get("timestamp", f"bar_{i}")

        if spread > MAX_SPREAD:
            continue

        # ── Range Detection ──────────────────────────────────────────
        if i >= RANGE_BARS:
            window = candles[i - RANGE_BARS + 1 : i + 1]
            highest_high = max(x["high"] for x in window)
            lowest_low   = min(x["low"]  for x in window)
            range_pips  = pts_to_pips(highest_high - lowest_low)

            if range_pips >= MIN_RANGE_PIPS:
                atr_val    = calc_atr([x["high"] for x in candles],
                                      [x["low"]  for x in candles],
                                      [x["close"]for x in candles], ATR_PERIOD)
                atr_pips   = pts_to_pips(atr_val * ATR_OFFSET)

                # ── Breakout Detection ─────────────────────────────
                open_c  = candles[i]["open"]

                if state == "IDLE":
                    if close > highest_high and open_c <= highest_high:
                        state          = "BREAKOUT_UP"
                        breakout_level = highest_high
                        breakout_dir   = 1
                        breakout_bar   = i
                    elif close < lowest_low and open_c >= lowest_low:
                        state          = "BREAKOUT_DOWN"
                        breakout_level = lowest_low
                        breakout_dir   = -1
                        breakout_bar   = i

                # ── Pullback Entry ───────────────────────────────────
                elif state in ("BREAKOUT_UP", "BREAKOUT_DOWN"):
                    # No open position yet
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
                                    tp1      = entry + pips_to_pts(sl_dist * TP2_R)
                                    tp2      = entry + pips_to_pts(sl_dist * TP2_R * 1.0)
                                    lot      = calc_lot(balance, sl_dist)
                                    open_pos = {
                                        "type": "BUY", "entry": entry, "sl": sl,
                                        "tp1": tp1, "tp2": entry + pips_to_pts(sl_dist * 2),
                                        "lot": lot, "r": sl_dist, "bar": i,
                                        "tp1_hit": False, "open_bar": breakout_bar,
                                    }
                                    state = "ACTIVE_LONG"
                                    if show_trades and not summary_only:
                                        print(f"  [BREAKOUT UP] Entry {entry:.2f} | SL {sl:.2f} | TP2 {open_pos['tp2']:.2f}")
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
                                        "tp1": entry - pips_to_pts(sl_dist),
                                        "tp2": tp2,
                                        "lot": lot, "r": sl_dist, "bar": i,
                                        "tp1_hit": False, "open_bar": breakout_bar,
                                    }
                                    state = "ACTIVE_SHORT"
                                    if show_trades and not summary_only:
                                        print(f"  [BREAKOUT DOWN] Entry {entry:.2f} | SL {sl:.2f} | TP2 {tp2:.2f}")
                                    break

                    # Retest timeout: no pullback within RETEST_BARS
                    if open_pos is None and (i - breakout_bar) >= RETEST_BARS:
                        state = "IDLE"

        # ── Position Management ──────────────────────────────────────
        if open_pos:
            cur = close
            tp2 = open_pos["tp2"]
            tp1 = open_pos["tp1"]
            sl  = open_pos["sl"]
            entry = open_pos["entry"]

            if open_pos["type"] == "BUY":
                # TP1 hit → move SL to BE
                if not open_pos["tp1_hit"] and cur >= tp1:
                    open_pos["tp1_hit"] = True
                    open_pos["sl"] = entry  # BE
                # TP2 hit
                if cur >= tp2:
                    pnl = pnl_from_points(cur - entry, open_pos["lot"])
                    balance += pnl
                    r = open_pos["r"]
                    total_r += r
                    if r > 0: wins += 1
                    else: losses += 1
                    trades_list.append({
                        "dir": "BUY", "pnl": pnl, "r": r, "bars": i - open_pos["bar"],
                        "entry": entry, "exit": cur, "result": "TP2"
                    })
                    if show_trades:
                        print(f"  >> BUY TP2  | PnL +${pnl:.2f} | {r:.1f}R")
                    open_pos = None
                    state = "IDLE"
                # SL hit
                elif cur <= sl:
                    pnl = pnl_from_points(sl - entry, open_pos["lot"])
                    balance += pnl
                    r = open_pos["r"]
                    total_r += r
                    losses += 1
                    trades_list.append({
                        "dir": "BUY", "pnl": pnl, "r": -r, "bars": i - open_pos["bar"],
                        "entry": entry, "exit": sl, "result": "SL"
                    })
                    if show_trades:
                        print(f"  >> BUY SL   | PnL ${pnl:.2f} | {-r:.1f}R")
                    open_pos = None
                    state = "IDLE"

            elif open_pos["type"] == "SELL":
                if not open_pos["tp1_hit"] and cur <= tp1:
                    open_pos["tp1_hit"] = True
                    open_pos["sl"] = entry
                if cur <= tp2:
                    pnl = pnl_from_points(entry - cur, open_pos["lot"])
                    balance += pnl
                    r = open_pos["r"]
                    total_r += r
                    wins += 1
                    trades_list.append({
                        "dir": "SELL", "pnl": pnl, "r": r, "bars": i - open_pos["bar"],
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
                        "dir": "SELL", "pnl": pnl, "r": -r, "bars": i - open_pos["bar"],
                        "entry": entry, "exit": sl, "result": "SL"
                    })
                    if show_trades:
                        print(f"  >> SELL SL  | PnL ${pnl:.2f} | {-r:.1f}R")
                    open_pos = None
                    state = "IDLE"

    # ─── SUMMARY ───────────────────────────────────────────────────────
    total_trades = wins + losses
    win_rate = wins / total_trades * 100 if total_trades > 0 else 0

    wins_pnl  = sum(t["pnl"] for t in trades_list if t["pnl"] > 0)
    loss_pnl  = sum(t["pnl"] for t in trades_list if t["pnl"] < 0)
    pf        = abs(wins_pnl / loss_pnl) if loss_pnl != 0 else 0

    # Max DD
    peak_bal = INIT_BAL
    max_dd    = 0.0
    bal_cur   = INIT_BAL
    for t in trades_list:
        bal_cur += t["pnl"]
        if bal_cur > peak_bal: peak_bal = bal_cur
        dd = (peak_bal - bal_cur) / peak_bal * 100
        if dd > max_dd: max_dd = dd

    # Equity curve
    eq = []
    be = INIT_BAL
    for t in trades_list:
        be += t["pnl"]
        eq.append(be)

    # Print summary
    sep = "=" * 65
    print(f"\n{sep}")
    print(f"  BREAKOUT & PULLBACK — BACKTEST SUMMARY")
    print(f"  Symbol: XAUUSD | TF: H1 | Bars: {len(candles)}")
    print(sep)
    print(f"  Initial Balance   : ${INIT_BAL:>12,.2f}")
    print(f"  Final Balance    : ${balance:>12,.2f}")
    print(f"  Net Profit       : ${balance - INIT_BAL:>12,.2f} ({((balance/INIT_BAL)-1)*100:+.1f}%)")
    print(f"  Total Trades     : {total_trades}")
    print(f"  Win  / Loss      : {wins} / {losses}")
    print(f"  Win Rate         : {win_rate:.1f}%")
    print(f"  Profit Factor    : {pf:.2f}")
    print(f"  Max Drawdown     : {max_dd:.1f}%")
    print(f"  Avg R per trade  : {total_r / total_trades:.3f}R" if total_trades else "")
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
        "equity_curve": eq,
        "trades": trades_list,
    }

# ─── SYNTHETIC CANDLE GENERATOR ────────────────────────────────────────
def generate_synthetic(start_date, days=730, volatility=12, trend=0):
    """
    Generate realistic-ish H1 candles for XAUUSD.
    volatility: std dev of hourly returns in $
    trend: drift per day (0 = random walk)
    """
    import datetime as _dt
    candles = []
    price = 1900.0
    date = _dt.datetime(start_date.year, start_date.month, start_date.day)

    for d in range(days):
        for h in range(24):
            # Base movement
            change = random.gauss(0, volatility)
            if trend != 0:
                change += trend / 730.0

            open_p  = price
            high_p  = open_p + abs(random.gauss(0, volatility * 0.5))
            low_p   = open_p - abs(random.gauss(0, volatility * 0.5))
            close_p = open_p + change

            high_p  = max(high_p, open_p, close_p)
            low_p   = min(low_p,  open_p, close_p)

            spread  = int(random.gauss(20, 5))
            spread  = max(5, min(spread, 50))

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

# ─── PARAMETER SCAN ────────────────────────────────────────────────────
def parameter_scan(candles, param_combos):
    results = []
    for params in param_combos:
        rb, mr, rb2, ao = params
        global RANGE_BARS, MIN_RANGE_PIPS, RETEST_BARS, ATR_OFFSET
        RANGE_BARS     = rb
        MIN_RANGE_PIPS = mr
        RETEST_BARS    = rb2
        ATR_OFFSET     = ao
        r = run_backtest(candles, summary_only=True)
        r["params"] = {
            "range_bars": rb, "min_range": mr,
            "retest_bars": rb2, "atr_offset": ao
        }
        results.append(r)

    results.sort(key=lambda x: x["profit_factor"], reverse=True)

    print("\n\n" + "=" * 70)
    print("  PARAMETER SCAN RESULTS (sorted by Profit Factor)")
    print("=" * 70)
    print(f"  {'RB':>4} {'MR':>5} {'RB2':>4} {'AO':>4} | "
          f"{'Trades':>6} {'Win%':>5} {'PF':>5} {'DD%':>5} {'Bal':>10} {'R/trade':>7}")
    print("-" * 70)
    for r in results:
        p = r["params"]
        pf = r["profit_factor"]
        print(f"  {p['range_bars']:>4} {p['min_range']:>5.0f} {p['retest_bars']:>4} {p['atr_offset']:>4.1f} | "
              f" {r['total_trades']:>6} {r['win_rate']:>5.1f}% {pf:>5.2f} {r['max_dd_pct']:>5.1f}% "
              f"${r['balance']:>10,.2f} {r['avg_r']:>+7.3f}R")

    return results

# ─── MAIN ──────────────────────────────────────────────────────────────
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="BreakoutPullback Backtester")
    parser.add_argument("--csv", help="Load candles from CSV file")
    parser.add_argument("--days", type=int, default=730, help="Synthetic data days (default: 730)")
    parser.add_argument("--scan", action="store_true", help="Run parameter scan")
    parser.add_argument("--show-trades", action="store_true", help="Show individual trades")
    parser.add_argument("--vol", type=float, default=12.0, help="Volatility for synthetic data")
    parser.add_argument("--trend", type=float, default=0.0, help="Trend drift per year ($)")
    args = parser.parse_args()

    if args.csv:
        candles = []
        with open(args.csv) as f:
            reader = csv.DictReader(f)
            for row in reader:
                candles.append({
                    "timestamp": row.get("timestamp", ""),
                    "open": float(row["open"]),
                    "high": float(row["high"]),
                    "low":  float(row["low"]),
                    "close": float(row["close"]),
                    "spread": int(row.get("spread", 20)),
                })
        print(f"Loaded {len(candles)} candles from {args.csv}")
    else:
        print(f"Generating synthetic H1 data for {args.days} days (~{args.days*24:,} bars)...")
        print(f"Volatility: {args.vol} | Trend: {args.trend}/yr")
        candles = generate_synthetic(datetime(2022, 1, 1), days=args.days,
                                      volatility=args.vol, trend=args.trend)
        print(f"Generated {len(candles)} candles")

    if args.scan:
        combos = [
            (15, 80,  3, 1.0), (15, 80,  3, 1.5), (15, 80,  3, 2.0),
            (20, 100, 3, 1.0), (20, 100, 3, 1.5), (20, 100, 3, 2.0),
            (20, 100, 5, 1.0), (20, 100, 5, 1.5), (20, 100, 5, 2.0),
            (20, 120, 3, 1.5), (20, 120, 5, 1.5), (20, 120, 5, 2.0),
            (25, 80,  5, 1.5), (25, 100, 5, 1.5), (25, 120, 5, 1.5),
            (30, 80,  5, 1.5), (30, 100, 5, 1.5), (30, 120, 3, 2.0),
        ]
        parameter_scan(candles, combos)
    else:
        result = run_backtest(candles, show_trades=args.show_trades)
        print(f"\nWin Rate: {result['win_rate']:.1f}%")
        print(f"Profit Factor: {result['profit_factor']:.2f}")
        print(f"Max DD: {result['max_dd_pct']:.1f}%")
        print(f"Total Trades: {result['total_trades']}")