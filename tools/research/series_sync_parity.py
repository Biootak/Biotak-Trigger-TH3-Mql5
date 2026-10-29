#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""MT4/MT5 PARITY — THE EMULATED SERIES STATE MACHINE (MT5-PAR-013 / 014).

Question: when the chart's bar count changes, do MT5's emulated series
(Time[]/Open[]/High[]/Low[]/Close[]/Bars) end up describing the SAME bars MT4's
predefined arrays describe at that instant?

What this replays: `CompatRefreshChartData()` in MT5Compat/MQL5Compat.mqh,
transcribed line for line (BEFORE = the branch that shipped until
this audit, AFTER = P-MT5-SERIES-01/-01b as it now stands in the source), against a simulated terminal whose arrays are always the truth
— which is exactly MT4's position: the terminal maintains those arrays, so they
can never be half-updated.

Every event names what the terminal reports, and the emulator only ever sees
what MQL5 lets it see:

    rates_total          OnCalculate's bar count (== MT4's Bars)
    time[rates_total-1]  the CURRENT bar's open time (== livTime)
    CopyRates(...)       the whole history, as many bars as exist now

Verdicts per event:
    OK       Bars and every Time[i] match the truth
    SHORT    Bars is behind (a count change was not applied) — values aligned
    TORN     index 0 mixes two bars (live H/L/C written over an old Time[0])
    SHIFTED  Time[i] is a DIFFERENT BAR than the truth at that index

What this does NOT model (read the verdicts with these in mind):
    - `CopyRates` never fails and never returns fewer bars than asked, so the
      `copied <= 0` retry path and a short copy (which permanently disables the
      +1 test, because `Bars` then lags the stamp) are untested here.
    - One count source. MQL has two: OnCalculate's `rates_total` and the
      OnInit/OnTimer fallback's `iBars(_Symbol, PERIOD_CURRENT)`.
    - No scenario runs with `liv=False`, i.e. the OnInit/OnTimer callers that
      pass no live values; the `iTime`/`iOpen` fallbacks are therefore unexercised.
    - The grade compares `Bars` and every `Time[i]`. It does not compare
      Open/High/Low/Close, so a mis-shift that left the times aligned and the
      bodies wrong would read OK. (It cannot happen here: all five arrays shift
      in the same loop, which is why time is the witness.)
    - A new bar whose bar COUNT did not change (a rolling series) is not modelled;
      that case is documented and dispositioned in BUGS.md's compat table.

Run:  python tools/research/series_sync_parity.py
"""
import sys

EMPTY = None
THROTTLE_MS = 500          # COMPAT_FULL_SYNC_MIN_MS


class Terminal:
    """The truth. Bars are stored oldest-first internally; series index 0 = newest."""

    def __init__(self, tf_minutes=60):
        self.bars = []          # list of dict(time, open, high, low, close), oldest first
        self.tf = tf_minutes * 60

    def append_history(self, count):
        """Older bars arrive (a history download) — the NEWEST bar does not change."""
        first = self.bars[0]["time"] if self.bars else 1_700_000_000
        for k in range(count, 0, -1):
            t = first - k * self.tf
            self.bars.append(self._bar(t, k))
            self.bars.sort(key=lambda b: b["time"])

    def new_bar(self):
        """A genuine new bar: the old forming bar closes, a fresh one opens."""
        if self.bars:
            self.bars[-1]["close"] = self.bars[-1]["open"] + 0.5
        t = (self.bars[-1]["time"] + self.tf) if self.bars else 1_700_000_000
        self.bars.append(self._bar(t, len(self.bars)))

    def _bar(self, t, seed):
        base = 1.0000 + (seed % 97) * 0.0001
        return {"time": t, "open": base, "high": base + 0.0005,
                "low": base - 0.0005, "close": base + 0.0002}

    # --- what the MQL5 API exposes -------------------------------------
    def rates_total(self):
        return len(self.bars)

    def series(self):
        return list(reversed(self.bars))

    def current(self):
        return self.bars[-1]

    def copy_rates(self, count):
        s = self.series()
        return s[:min(count, len(s))]


class Emulator:
    """CompatRefreshChartData() — the MT5 side. `variant` is 'BEFORE' or 'AFTER'."""

    def __init__(self, term, variant):
        self.t = term
        self.variant = variant
        self.Time, self.Open, self.High, self.Low, self.Close = [], [], [], [], []
        self.Bars = 0
        self.synced = -1
        self.last_ms = None          # None == "no sync has ever completed"
        self.action = ""

    def refresh(self, now_ms, liv=True):
        bars = self.t.rates_total()                       # knownBars from OnCalculate
        cur = self.t.current()
        livC, livH, livL = (cur["close"], cur["high"], cur["low"]) if liv else (EMPTY,) * 3
        livT = cur["time"] if liv else 0
        livO = cur["open"] if liv else EMPTY
        if bars <= 0:
            return

        if bars != self.synced:
            due = (self.last_ms is None) or ((now_ms - self.last_ms) >= THROTTLE_MS)
            shift_ok = (self.Bars > 0 and self.Bars == self.synced and
                        bars == self.synced + 1)
            # The newest bar's open time, however the caller can supply it:
            # OnCalculate passes time[rates_total-1] free; OnInit/OnTimer pay one
            # kernel read (iTime(_Symbol, PERIOD_CURRENT, 0)).
            newest = livT if livT > 0 else self.t.current()["time"]
            if self.variant == "AFTER":
                # (1) a +1 count change is a new bar only if the newest bar MOVED
                shift_ok = shift_ok and (self.Bars == 0 or newest > self.Time[0])
                if shift_ok:
                    self.action = "shift"
                    self._shift(newest, livO, now_ms)      # (2) never throttled
                elif due:
                    self.action = "full-copy"
                    self._full_copy(bars, now_ms)
                else:
                    self.action = "hold (throttle)"
            else:
                if due:
                    if shift_ok:
                        self.action = "shift"
                        self._shift(newest, livO, now_ms)
                    else:
                        self.action = "full-copy"
                        self._full_copy(bars, now_ms)
                else:
                    self.action = "hold (throttle)"
        else:
            self.action = "steady"

        aligned = (bars == self.synced) if self.variant == "AFTER" else True
        if self.Bars > 0 and aligned:
            self.action += "+live[0]"
            if livC is not EMPTY and livH is not EMPTY and livL is not EMPTY:
                self.High[0], self.Low[0], self.Close[0] = livH, livL, livC
            else:
                c = self.t.current()
                self.High[0], self.Low[0], self.Close[0] = c["high"], c["low"], c["close"]

    def _shift(self, newTime, livO, now_ms):
        n = self.Bars
        for a in (self.Time, self.Open, self.High, self.Low, self.Close):
            a.append(0)                          # ArrayResize(n + 1) — grows at the TAIL
        for i in range(n, 0, -1):                # the C loop, i = n .. 1
            self.Time[i] = self.Time[i - 1]
            self.Open[i] = self.Open[i - 1]
            self.High[i] = self.High[i - 1]
            self.Low[i] = self.Low[i - 1]
            self.Close[i] = self.Close[i - 1]
        self.Bars = n + 1
        self.synced = self.t.rates_total()
        # The stamp is the fix's subject, so it is modelled per variant: BEFORE
        # stamped inside the shift branch (that is what made the next append wait
        # out a window); AFTER (-01b) the shift never stamps and the 500 ms floor
        # belongs to the full-history copy alone (source :1020, :1049).
        if self.variant == "BEFORE":
            self.last_ms = now_ms
        self.Time[0] = newTime
        self.Open[0] = livO if livO is not EMPTY else self.t.current()["open"]

    def _full_copy(self, bars, now_ms):
        copied = self.t.copy_rates(bars)
        if not copied:
            return
        self.last_ms = now_ms
        self.Time = [b["time"] for b in copied]
        self.Open = [b["open"] for b in copied]
        self.High = [b["high"] for b in copied]
        self.Low = [b["low"] for b in copied]
        self.Close = [b["close"] for b in copied]
        self.Bars = len(copied)
        self.synced = bars

    _now = 0


def verdicts(emp, term):
    """Compare one emulated snapshot with the truth."""
    truth = term.series()
    if emp.Bars == 0:
        return "EMPTY"
    if emp.Time[0] != truth[0]["time"]:
        # index 0 is not the current bar: either torn or the whole array shifted
        if emp.Close[0] == truth[0]["close"] and emp.Bars >= 1:
            return "TORN"          # live H/L/C on a stale Time[0]
        return "SHIFTED"
    bad = [i for i in range(min(emp.Bars, len(truth)))
           if emp.Time[i] != truth[i]["time"]]
    if bad:
        return "SHIFTED(%d)" % len(bad)
    if emp.Bars != len(truth):
        return "SHORT(%d)" % (len(truth) - emp.Bars)
    return "OK"


def run(name, events):
    out = {}
    for variant in ("BEFORE", "AFTER"):
        term = Terminal()
        emp = Emulator(term, variant)
        rows = []
        for ev, _detail in events(term, emp):
            rows.append((ev, emp.action, verdicts(emp, term)))
        out[variant] = rows
    print("\n=== %s ===" % name)
    print("%-26s %-26s %-26s" % ("event", "BEFORE (pre-fix)", "AFTER (shipped now)"))
    for (ev, a_b, v_b), (_ev, a_a, v_a) in zip(out["BEFORE"], out["AFTER"]):
        flag = "   <== DIVERGES" if v_b.split("(")[0] != v_a.split("(")[0] else ""
        print("%-26s %-26s %-26s%s" % (ev, "%s -> %s" % (a_b, v_b),
                                       "%s -> %s" % (a_a, v_a), flag))
    return out


def scenarios():
    # ---- S1: attach, then a new bar 40 ms later (inside the throttle) ----
    def s1(term, emp):
        term.append_history(50)
        emp.refresh(0)
        yield "attach: full sync", None
        term.new_bar()
        emp.refresh(40)                      # 40 ms < 500 ms throttle
        yield "new bar @40ms", None
        emp.refresh(600)                     # throttle released
        yield "retry @600ms", None
    run("S1  attach, then a new bar 40 ms later", s1)

    # ---- S2: history grows by exactly ONE older bar ----
    def s2(term, emp):
        term.append_history(50)
        emp.refresh(0)
        yield "attach: full sync (complete)", None
        term.append_history(1)
        emp.refresh(1000)                    # a new bar has NOT formed
        yield "history +1 older bar @1000ms", None
        emp.refresh(1600)
        yield "retry @1600ms", None
        term.new_bar()
        emp.refresh(2000)
        yield "the next real new bar", None
    run("S2  the terminal adds one older bar", s2)

    # ---- S3: steady state over 12 bars (regression control) ----
    def s3(term, emp):
        term.append_history(30)
        emp.refresh(0)
        yield "attach", None
        bad = 0
        for k in range(12):
            term.new_bar()
            emp.refresh(1000 + k * 1000)
            if verdicts(emp, term) != "OK":
                bad += 1
        yield "12 consecutive new bars", None
    run("S3  steady state, 12 bars (control)", s3)

    # ---- S4: a download in flight, one bar at a time, then a new bar ----
    def s4(term, emp):
        term.append_history(30)
        emp.refresh(0)
        yield "attach", None
        for k in range(4):
            term.append_history(1)
            emp.refresh(1000 + k * 100)      # 100ms apart: throttled after the 1st
        yield "4 history appends (100ms apart)", None
        emp.refresh(2000)
        yield "throttle released", None
    run("S4  a 1-bar-at-a-time backfill", s4)


def main():
    print("MT4 ground truth: the terminal maintains its own arrays — they are")
    print("always one consistent snapshot. MT5 emulates them; the replay shows")
    print("which count-change events the emulation can mis-apply.")
    scenarios()
    print("""
READING
  TORN     index 0 carries the NEW bar's High/Low/Close and the OLD bar's
           Time/Open.  ZoneFactory/ExtendedDrawing read Time[0] as the zone end
           edge and Close[0] as currentPrice: they get two different bars.
  SHORT    Bars is behind the chart. MT4 reads Bars as a VALUE (BaseKnot's
           total, Time[Bars-1] as the oldest bar), so a short Bars is a
           different answer, not just a late one.
  SHIFTED  Time[i] is the wrong BAR for that index and the error never heals:
           the state machine only re-syncs on the next count change.
""")


if __name__ == "__main__":
    main()
