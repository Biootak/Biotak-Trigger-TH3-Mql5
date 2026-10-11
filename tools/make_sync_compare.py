#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Build BOTH `Biotak Sync Compare` twins from TODAY's production entries.

WHY A GENERATOR AND NOT TWO HAND-WRITTEN FILES.

Parity evidence has to come from the two builds doing the same work, so the twin
must be the production indicator plus a dump - never a re-implementation. The
dump body below is therefore ONE string, written into both twins byte for byte:
same file names, same column order, same number formatting, same filter
(`inpObjectPrefix`), same trigger (a new bar, plus the timer). If the two CSVs
disagree, the disagreement is in the indicator, not in the measuring tool.

The dump uses only calls that exist on BOTH compilers (`ObjectsTotal`,
`ObjectName`, `ObjectGetDouble/Integer/String`, `FileOpen/Write/Seek/Size`,
`TimeToString`, `DoubleToString`, `Time[0]/Open[0]/...`). On MT5 the two object
enumerators arrive through the MT5Compat shims, which is what lets this file be
shared verbatim.

WHAT IT WRITES
  * `Biotak Sync Compare.mq5`  - the MT5 twin, at the MT5 repo root (the MT5
    terminal sees that tree through its own `MQL5/Indicators/Biotak-Trigger-TH3`
    junction, so compiling there is enough).
  * `tools/parity/Biotak Sync Compare.mq4` - the MT4 twin, kept here for the
    record, because this repository never writes into the MT4 tree. Use
    `--deploy-mt4` to also copy it into the live MT4 terminal's `Indicators`
    folder (that folder is a runtime artifact, not the MT4 repository).

Run it again after any MT4 change: the twins follow the entries automatically.
"""
import argparse
import io
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MT5_REPO = os.path.dirname(HERE)
MT4_REPO = os.path.join(os.path.dirname(MT5_REPO), "Biotak-Trigger-TH3-mql4")

MT5_ENTRY = os.path.join(MT5_REPO, "Biotak Trigger TH3.mq5")
MT4_ENTRY = os.path.join(MT4_REPO, "Biotak Trigger TH3.mq4")
MT5_TWIN = os.path.join(MT5_REPO, "Biotak Sync Compare.mq5")
MT4_TWIN = os.path.join(HERE, "parity", "Biotak Sync Compare.mq4")

MT4_DEFAULT_TERMINAL = os.path.join(
    os.environ.get("APPDATA", ""),
    "MetaQuotes", "Terminal", "A1660DA4CB596E740BE3B3233E577E1B",
    "MQL4", "Indicators")

HEADER = """//+------------------------------------------------------------------+
//| Biotak Sync Compare                                              |
//|                                                                  |
//| SYNC VERIFICATION TOOL - not a product build.                     |
//|                                                                  |
//| It IS the production indicator (same include chain, same five      |
//| handlers, copied verbatim from `Biotak Trigger TH3` by             |
//| tools/make_sync_compare.py) plus a dump that runs on every new bar |
//| and on the timer:                                                  |
//|                                                                  |
//|   MQL4/Files or MQL5/Files\\biotak_sync_values.csv   core values   |
//|   MQL4/Files or MQL5/Files\\biotak_sync_objects.csv  drawn objects |
//|                                                                  |
//| PROCEDURE                                                          |
//|   1. Attach ONLY this indicator - remove the real one first, or    |
//|      use a NEW chart - same symbol, same timeframe, IDENTICAL      |
//|      settings in MT4 and MT5 (the defaults are identical by        |
//|      construction: one PropertiesAndInputs.mqh).                   |
//|   2. Let it run for a couple of bars (the timer also dumps, so a   |
//|      tick-less chart still lands inside a second).                 |
//|   3. `python tools/parity/parity-diff.py <mt4-csv> <mt5-csv>`.     |
//|                                                                  |
//| The two feeds are different brokers, so absolute prices answer a   |
//| DIFFERENT question - the tool reports the ladder in BASE-RELATIVE  |
//| units for that reason (see tools/parity/parity-diff.py).           |
//+------------------------------------------------------------------+
"""

DUMP = r"""
//+------------------------------------------------------------------+
//| SYNC COMPARE - THE DUMP (byte-identical on MT4 and MT5)           |
//|                                                                  |
//| Every call below exists on BOTH compilers: ObjectsTotal,          |
//| ObjectName, ObjectGetDouble/Integer/String, FileOpen/Write/Seek/  |
//| Size, TimeToString, DoubleToString, Time[0]/Open[0]/High[0]/       |
//| Low[0]/Close[0]. On MT5 the two object enumerators arrive through  |
//| the MT5Compat shims - which is exactly why one file can carry      |
//| both builds and the CSVs stay comparable by construction.          |
//+------------------------------------------------------------------+
datetime g_syncLastDumpedBar = 0;
int      g_syncValuesFile    = INVALID_HANDLE;
int      g_syncObjectsFile   = INVALID_HANDLE;
int      g_syncStateFile     = INVALID_HANDLE;

#define SYNC_VALUES_FILE  "biotak_sync_values.csv"
#define SYNC_OBJECTS_FILE "biotak_sync_objects.csv"
#define SYNC_STATE_FILE   "biotak_sync_state.csv"
#define SYNC_MAX_OBJECTS  2000

string SyncDumpStr(const double v)
{
    return DoubleToString(v, 10);
}

void SyncOpenFiles()
{
    if(g_syncValuesFile == INVALID_HANDLE)
        g_syncValuesFile = FileOpen(SYNC_VALUES_FILE, FILE_WRITE|FILE_READ|FILE_CSV, ',');
    if(g_syncObjectsFile == INVALID_HANDLE)
        g_syncObjectsFile = FileOpen(SYNC_OBJECTS_FILE, FILE_WRITE|FILE_READ|FILE_CSV, ',');
    if(g_syncStateFile == INVALID_HANDLE)
        g_syncStateFile = FileOpen(SYNC_STATE_FILE, FILE_WRITE|FILE_READ|FILE_CSV, ',');
}

void SyncWriteHeader(const int fh)
{
    if(fh == INVALID_HANDLE) return;
    if(FileSize(fh) > 0) return;
    if(fh == g_syncValuesFile)
        FileWrite(fh, "barTime","barOpen","barHigh","barLow","barClose",
                  "basePrice","thPct","thStep","adaptedStep","atrStep","comboStep",
                  "structVal","patternVal","triggerVal",
                  "atrStruct","atrPattern","atrTrigger","calcMs");
    else if(fh == g_syncObjectsFile)
        FileWrite(fh, "barTime","name","type","price1","price2","time1","time2",
                  "color","style","width","timeframes","back","fill","ray","zorder","text");
    else
        FileWrite(fh, "barTime","symbol","tfMinutes","digits","point",
                  "barsChart","barsEmul","barsM1","barsD1",
                  "basePrice","histCount","histFirst","histLast","m1Power",
                  "startTypeInput","startTypeLive","customStartPrice",
                  "thPct","thStep","adaptedStep","atrStep","comboStep",
                  "leg1","leg2","leg3","leg4","leg5","leg6","weightedATR");
}

//--- close every handle on deinit (nothing below the call site writes them).
void SyncCloseFiles()
{
    if(g_syncValuesFile != INVALID_HANDLE)  { FileClose(g_syncValuesFile);  g_syncValuesFile = INVALID_HANDLE; }
    if(g_syncObjectsFile != INVALID_HANDLE) { FileClose(g_syncObjectsFile); g_syncObjectsFile = INVALID_HANDLE; }
    if(g_syncStateFile != INVALID_HANDLE)   { FileClose(g_syncStateFile);   g_syncStateFile = INVALID_HANDLE; }
}

void SyncDumpValues()
{
    SyncOpenFiles();
    if(g_syncValuesFile == INVALID_HANDLE) return;
    SyncWriteHeader(g_syncValuesFile);
    FileSeek(g_syncValuesFile, 0, SEEK_END);

    uint t0 = GetTickCount();

    double basePrice   = GetBasePriceForTH();
    double thPct       = GetTimeframeTH();
    double thStep      = CalculateTH(basePrice, Digits, thPct);
    double adaptedStep = GetAdaptedStepSize(thStep);
    double atrStep     = CalculateATRBasedStep();
    double comboStep   = GetComboStepSize(basePrice);

    double structVal = 0.0, patternVal = 0.0, triggerVal = 0.0;
    CalculateFractalValues(adaptedStep, structVal, patternVal, triggerVal);

    double atrStruct = 0.0, atrPattern = 0.0, atrTrigger = 0.0;
    CalculateATRFractalValues(atrStruct, atrPattern, atrTrigger);

    uint t1 = GetTickCount();

    FileWrite(g_syncValuesFile,
              TimeToString(Time[0], TIME_DATE|TIME_MINUTES|TIME_SECONDS),
              SyncDumpStr(Open[0]), SyncDumpStr(High[0]), SyncDumpStr(Low[0]), SyncDumpStr(Close[0]),
              SyncDumpStr(basePrice), SyncDumpStr(thPct), SyncDumpStr(thStep), SyncDumpStr(adaptedStep),
              SyncDumpStr(atrStep), SyncDumpStr(comboStep),
              SyncDumpStr(structVal), SyncDumpStr(patternVal), SyncDumpStr(triggerVal),
              SyncDumpStr(atrStruct), SyncDumpStr(atrPattern), SyncDumpStr(atrTrigger),
              IntegerToString((int)(t1 - t0)));
}

//--- THE CAUSE, NOT THE SYMPTOM: every INPUT the level ladder reads, next to
//--- the values it produced. If two runs disagree on a level, this file says
//--- which input disagreed - the reference price (and whether it came from
//--- today's history file or from the live Bid), the history depth, the six ATR
//--- legs, or a custom TH anchor left over on the chart. Identical on both
//--- compilers: Symbol/Digits/Point, iBars(iBars(sym,tf) with minutes),
//--- the shared base-price state and the shared ATR batch.
void SyncDumpState()
{
    SyncOpenFiles();
    if(g_syncStateFile == INVALID_HANDLE) return;
    SyncWriteHeader(g_syncStateFile);
    FileSeek(g_syncStateFile, 0, SEEK_END);

    double basePrice   = GetBasePriceForTH();
    double thPct       = GetTimeframeTH();
    double thStep      = CalculateTH(basePrice, Digits, thPct);
    double adaptedStep = GetAdaptedStepSize(thStep);
    double atrStep     = CalculateATRBasedStep();
    double comboStep   = GetComboStepSize(basePrice);

    // the six legs the weighted ATR averages - the ladder's volatility ruler
    double legs[];
    ArrayResize(legs, 6);
    ArrayInitialize(legs, 0.0);
    CalculateATRBatchTrex(legs, (ENUM_TIMEFRAMES)CompatTF(Period()), 1);
    double weightedATR = CalculateWeightedATR(PERIOD_CURRENT);

    FileWrite(g_syncStateFile,
              TimeToString(Time[0], TIME_DATE|TIME_MINUTES|TIME_SECONDS),
              Symbol(),
              IntegerToString((int)Period()),
              IntegerToString((int)Digits),
              SyncDumpStr(Point),
              IntegerToString(iBars(_Symbol, 0)),
              // MT5-only emulation of MQL4's `Bars`: on MT4 this is the native
              // series count. If it lags barsChart, the MT5 run is reading a
              // shorter series than MT4 would (history still downloading).
              IntegerToString(Bars),
              IntegerToString(iBars(_Symbol, 1)),
              IntegerToString(iBars(_Symbol, 1440)),
              SyncDumpStr(basePrice),
              IntegerToString(g_historyCount),
              (g_historyCount > 0 ? GetHistoryEntry(0) : ""),
              (g_historyCount > 0 ? GetHistoryEntry(g_historyCount - 1) : ""),
              SyncDumpStr(g_referenceM1Power),
              IntegerToString((int)inpTHStartPointType),
              IntegerToString((int)g_thStartPointType),
              SyncDumpStr(g_customTHStartPrice),
              SyncDumpStr(thPct), SyncDumpStr(thStep), SyncDumpStr(adaptedStep),
              SyncDumpStr(atrStep), SyncDumpStr(comboStep),
              SyncDumpStr(legs[0]), SyncDumpStr(legs[1]), SyncDumpStr(legs[2]),
              SyncDumpStr(legs[3]), SyncDumpStr(legs[4]), SyncDumpStr(legs[5]),
              SyncDumpStr(weightedATR));

    // اگر لنگر سفارشی روی چارت باقی مانده باشد، همین خط در لاگ می‌گوید کدام طرف از قیمت سفارشی استفاده می‌کند.
    if(g_thStartPointType == TH_START_POINT_CUSTOM_PRICE)
        Print("[SYNC] TH anchor is CUSTOM on this chart: ", DoubleToString(g_customTHStartPrice, Digits),
              " (input asked for ", EnumToString(inpTHStartPointType), ")");
}

void SyncDumpObjects()
{
    SyncOpenFiles();
    if(g_syncObjectsFile == INVALID_HANDLE) return;
    SyncWriteHeader(g_syncObjectsFile);
    FileSeek(g_syncObjectsFile, 0, SEEK_END);

    string barTag = TimeToString(Time[0], TIME_DATE|TIME_MINUTES|TIME_SECONDS);
    int total = ObjectsTotal();
    int dumped = 0;
    for(int i = 0; i < total && dumped < SYNC_MAX_OBJECTS; i++)
    {
        string name = ObjectName(i);
        if(StringFind(name, inpObjectPrefix) != 0) continue;

        long type = ObjectGetInteger(0, name, OBJPROP_TYPE);
        double p1 = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);
        double p2 = ObjectGetDouble(0, name, OBJPROP_PRICE, 1);
        long   t1 = ObjectGetInteger(0, name, OBJPROP_TIME, 0);
        long   t2 = ObjectGetInteger(0, name, OBJPROP_TIME, 1);

        FileWrite(g_syncObjectsFile,
                  barTag,
                  name,
                  IntegerToString((int)type),
                  SyncDumpStr(p1), SyncDumpStr(p2),
                  TimeToString((datetime)t1, TIME_DATE|TIME_MINUTES|TIME_SECONDS),
                  TimeToString((datetime)t2, TIME_DATE|TIME_MINUTES|TIME_SECONDS),
                  IntegerToString((int)ObjectGetInteger(0, name, OBJPROP_COLOR)),
                  IntegerToString((int)ObjectGetInteger(0, name, OBJPROP_STYLE)),
                  IntegerToString((int)ObjectGetInteger(0, name, OBJPROP_WIDTH)),
                  IntegerToString((int)ObjectGetInteger(0, name, OBJPROP_TIMEFRAMES)),
                  IntegerToString((int)ObjectGetInteger(0, name, OBJPROP_BACK)),
                  IntegerToString((int)ObjectGetInteger(0, name, OBJPROP_FILL)),
                  IntegerToString((int)ObjectGetInteger(0, name, OBJPROP_RAY_RIGHT)),
                  IntegerToString((int)ObjectGetInteger(0, name, OBJPROP_ZORDER)),
                  ObjectGetString(0, name, OBJPROP_TEXT));
        dumped++;
    }
}

//--- ONE trigger for both dumps: a NEW BAR (and the timer, for a quiet chart).
void SyncCompareTick()
{
    if(Bars <= 0) return;
    if(Time[0] == g_syncLastDumpedBar) return;
    g_syncLastDumpedBar = Time[0];
    SyncDumpValues();
    SyncDumpObjects();
    SyncDumpState();   // the inputs behind those values - see its header
}

"""


def read(path):
    with io.open(path, "r", encoding="utf-8-sig", newline="") as fh:
        return fh.read().replace("\r\n", "\n")


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with io.open(path, "w", encoding="utf-8-sig", newline="") as fh:
        fh.write(text.replace("\n", "\r\n"))
    print("wrote", path, "({} lines)".format(text.count("\n") + 1))


def insert_after(text, anchor, addition, what):
    """Insert `addition` right after the line holding `anchor` (exactly one)."""
    n = text.count(anchor)
    if n != 1:
        sys.exit("anchor for {} appears {} times, expected 1: {!r}".format(what, n, anchor))
    at = text.index(anchor)
    end = text.index("\n", at) + 1
    return text[:end] + addition + text[end:]


def build(kind):
    src = MT5_ENTRY if kind == "mq5" else MT4_ENTRY
    text = read(src)

    # 1. the dump block, immediately before the first handler.
    at = text.index("int OnInit()\n")
    text = text[:at] + DUMP.lstrip("\n") + "\n" + text[at:]

    # 2. the handlers: close on deinit, dump on a new bar, dump on the timer.
    text = insert_after(text, "OnDeinitHandler(reason);\n",
                        "    SyncCloseFiles();   // SYNC COMPARE: the two CSVs close here\n",
                        kind + ": OnDeinit")
    text = insert_after(text, "real_volume, spread);\n",
                        "\n    SyncCompareTick();   // SYNC COMPARE: dump on a new bar\n",
                        kind + ": OnCalculate")
    # SAME anchor on both sides: since the MT5 entry is the MT4 entry + the
    # declared platform blocks, both twins must dump at the SAME point of the
    # timer, after every sweep - otherwise the object dumps could legitimately
    # differ and the comparison would be measuring the tool, not the indicator.
    text = insert_after(text, "    TH3BaseBandDragHeartbeat();\n",
                        "\n    SyncCompareTick();   // SYNC COMPARE: the timer's own dump\n",
                        kind + ": OnTimer")

    # 3. the header: this is a tool, and the tool says how to use it.
    text = HEADER.replace("\n", "\n") + text
    return text


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--deploy-mt4", nargs="?", const=MT4_DEFAULT_TERMINAL,
                    default=None, metavar="INDICATORS_DIR",
                    help="also copy the MT4 twin into the live MT4 terminal's "
                         "Indicators folder (default: %s)" % MT4_DEFAULT_TERMINAL)
    args = ap.parse_args()

    write(MT5_TWIN, build("mq5"))
    write(MT4_TWIN, build("mq4"))

    if args.deploy_mt4:
        dst = os.path.join(args.deploy_mt4, os.path.basename(MT4_TWIN))
        write(dst, build("mq4"))
        print("deployed to", dst)


if __name__ == "__main__":
    main()
