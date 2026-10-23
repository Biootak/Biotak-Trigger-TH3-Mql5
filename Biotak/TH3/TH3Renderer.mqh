// ============================================================================
// OWNED MT5 module - forked from the MetaTrader 4 source on 2026-10-12.
//   MT4 source : Biotak/Biotak/TH3/TH3Renderer.mqh
//
// MT4 remains the LOGIC reference and tools/parity/module-report.py flags
// any drift, but nothing regenerates this file: MT5-only changes live here
// directly, marked MT5-ONLY / P-MT5-* / P-PERF-*.
//
// MT5-only changes this file already carries:
//   * the chart-wide orphan sweep runs per frame, not per chart change  (1 substitution)
// ============================================================================
//+------------------------------------------------------------------+
//| TH3/TH3Renderer.mqh                                             |
//| Pure model->objects renderer: takes A/B/C points and draws the  |
//| complete AB=CD pattern (points, labels, lines, targets, zones,  |
//| info label). No state is stored here - chart objects are only   |
//| a projection of TH3Pattern models (TH3PatternStore.mqh).        |
//+------------------------------------------------------------------+
#ifndef TH3_RENDERER_MQH
#define TH3_RENDERER_MQH

// TH3Renderer_A.mqh - TH3Renderer.mqh split 2026-09-29: exact lines 10-968, byte-identical, zero renames.
#ifndef TH3_RENDERER_A_MQH
#define TH3_RENDERER_A_MQH

#property strict

// P-TH3-LOG1 ring (file scope: one slot per recent pattern; a redraw that
// re-derives the same verdict logs nothing, a new verdict logs once).
static string s_th3LogPat[8];
static string s_th3LogKey[8];
static int    s_th3LogPos = 0;

// P-TH3-LOG2 (2026-09-22) -- THE PROJECT LOG FOLDER, WITHOUT COPY-PASTE.
// Every verdict is appended to TH3LOG_<symbol>_<tf>.csv in the terminal's
// MQL4/Files (the MT4 sandbox answers nowhere else); tools/pull-th3log.ps1
// copies them into the repo's th3logs/. Same line shape as the Experts Print,
// so tools/th3_log_collect.py reads both. Runs on verdicts only (rare).
void TH3LogFileAppend(const string line)
{
    string sym = Symbol();
    string safe = "";
    for(int i = 0; i < StringLen(sym); i++)
    {
        ushort ch = StringGetCharacter(sym, i);
        bool okc = ((ch >= '0' && ch <= '9') || (ch >= 'A' && ch <= 'Z') ||
                    (ch >= 'a' && ch <= 'z'));
        safe += (okc ? StringSubstr(sym, i, 1) : "_");
    }
    string fn = StringFormat("TH3LOG_%s_%d.csv", safe, Period());
    int h = FileOpen(fn, FILE_READ | FILE_WRITE | FILE_TXT);
    if(h < 0) return;
    if(FileSize(h) == 0)
        FileWriteString(h, "# pat,chart,st,R,closed,K,rung,owner,q,pb,synth,macro,lock,step,proof,deep\n");
    FileSeek(h, 0, SEEK_END);
    FileWriteString(h, line + "\n");
    FileClose(h);
}

//+------------------------------------------------------------------+
//| Calculate AB=CD Point D (with 9-level validation)               |
//|       D       9                                |
//| Rule: AB distance = CD distance (equal price movement)          |
//+------------------------------------------------------------------+
//|      AB=CD     TH3                                    |
//| User provides A, B, C     System calculates D                      |
//| Targets (Step1/3/5/7) start from C (not D)                       |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| P-TH3-PERF-01 (2026-09-19) — THE AVERAGE CANDLE SIZE IS CACHED   |
//| PER BAR, NOT PER REDRAW.                                         |
//|                                                                   |
//| DrawABCDPattern runs on EVERY drag event and once per pattern in   |
//| UpdateAllTH3Objects, and it used to walk 20 bars (20 iHigh + 20    |
//| iLow terminal reads) each time just to place a label. The answer   |
//| only moves when a new bar opens, so it is computed once per bar    |
//| and reused: a drag that fires N times now costs those 40 reads     |
//| ONCE instead of 40 x N.                                           |
//+------------------------------------------------------------------+
double TH3AvgCandleSize()
{
   static datetime s_avgBar = 0;
   static double   s_avg    = 0.0;
   datetime nowBar = iTime(NULL, 0, 0);
   if(nowBar != s_avgBar || s_avg <= 0.0)
   {
      const int lookback = 20;
      double sum = 0.0;
      for(int k = 0; k < lookback; k++)
         sum += (iHigh(NULL, 0, k) - iLow(NULL, 0, k));
      s_avg    = sum / (double)lookback;
      s_avgBar = nowBar;
   }
   return s_avg;
}

//+------------------------------------------------------------------+
//| P-TH3-INFO-04 (2026-09-20) — THE READOUT PLATE: ONE LANGUAGE.     |
//|                                                                  |
//| The leg meter prints its three lines INSIDE a dark plate with a   |
//| hairline border (P-LM-01). The user's ask is that the AB=CD       |
//| caption read the SAME way — one tool, one visual language: the    |
//| same plate ink, the same padding, the same row grid, the same     |
//| MEASURED (never guessed) size, and the same near-white rows with  |
//| the live number on the accent row. Two surfaces spelling those    |
//| numbers themselves is exactly how a tool ends up with two looks,  |
//| so the plate's INK, its METRICS and its WRITERS have ONE owner    |
//| here and both surfaces ask for them:                              |
//|                                                                  |
//|   * TH3ROPlateW/TH3ROPlateH measure the plate off the very        |
//|     strings it carries (`PnlRawTextW`/`PnlRawLineH`, the          |
//|     chart-label grid — the measurement the BaseKnot note plate    |
//|     uses too), never off a literal;                              |
//|   * TH3ROPlateAt creates the plate ONCE, then ever only writes a  |
//|     value that CHANGED (P-PERF-02);                              |
//|   * TH3RORowAt is the row writer: font size, text, ink and place  |
//|     in one guarded pass;                                          |
//|   * TH3RORowY/TH3ROPlateY decide the block's geometry, because    |
//|     MT4 anchors a corner object's distance on the edge nearest    |
//|     that corner — a readout hangs DOWN from its top Y in an upper |
//|     corner and UP in a lower one, and the plate must agree with   |
//|     its own rows in all four.                                    |
//|                                                                  |
//| The plate is created BEFORE the ink it carries: MT4 ties equal    |
//| ZORDER by CREATION ORDER, so a row older than its plate would be  |
//| painted UNDER it — a plate covering its own text. Any surface     |
//| that finds the plate missing therefore rebuilds its rows (see     |
//| TH3InfoFamilyDraw and LegMeasureUpgradeLegacy).                   |
//|                                                                  |
//| The inks are deliberately NOT run through TH3InkForChart: the     |
//| plate is a FIXED dark ink on every theme, so a theme-flipped row  |
//| would be the one thing a readout cannot be — unreadable. The ink  |
//| TABLE itself lives with the ink owner (`TH3Controller.mqh`, the   |
//| `TH3RO_*` palette + `TH3ReadoutInk`), so both readouts ask one    |
//| table for what a row wears. What lives here is the plate's        |
//| LAYOUT — its padding, its row grid and its writers.               |
//+------------------------------------------------------------------+
#define TH3RO_PAD_X    10                 // px of plate on each side of the ink
#define TH3RO_PAD_Y    5
#define TH3RO_LINE_GAP 5                  // px between two readout rows
#define TH3RO_FONT_PT  9                  // the reference box's own text size

int TH3ROLineH(const int fontPt) { return PnlRawLineH(fontPt); }
int TH3RORowH(const int fontPt)  { return TH3ROLineH(fontPt) + TH3RO_LINE_GAP; }

// The plate's height for `rows` rows of ink, padding included.
int TH3ROPlateH(const int rows, const int fontPt)
{
    if(rows <= 0) return 2 * TH3RO_PAD_Y;
    return rows * TH3ROLineH(fontPt) + (rows - 1) * TH3RO_LINE_GAP + 2 * TH3RO_PAD_Y;
}

// The plate's width is the WIDEST row it carries — measured, not guessed.
int TH3ROPlateW(const string &rows[], const int n, const int fontPt)
{
    int bw = 2 * TH3RO_PAD_X + 8;   // a one-character row still gets a plate
    for(int i = 0; i < n; i++)
    {
        if(StringLen(rows[i]) == 0) continue;
        int w = PnlRawTextW(rows[i], fontPt) + 2 * TH3RO_PAD_X;
        if(w > bw) bw = w;
    }
    return bw;
}

// ── the block's own geometry: ONE owner for rows and plate ──────────
bool TH3ROLowerCorner(const ENUM_BASE_CORNER corner)
{
    return (corner == CORNER_LEFT_LOWER || corner == CORNER_RIGHT_LOWER);
}

// Row `row` of a block whose near edge (its first row, top-down) is at `topY`.
int TH3RORowY(const int topY, const int row, const int fontPt, const ENUM_BASE_CORNER corner)
{
    int rowH = TH3RORowH(fontPt);
    if(TH3ROLowerCorner(corner)) return topY - row * rowH;   // a lower corner's y grows UP
    return topY + row * rowH;
}

// The plate's y: PAD_Y BEYOND the block's near edge, on whichever side that is.
int TH3ROPlateY(const int topY, const int rows, const int fontPt, const ENUM_BASE_CORNER corner)
{
    int nearRow = TH3ROLowerCorner(corner) ? rows - 1 : 0;
    return TH3RORowY(topY, nearRow, fontPt, corner) - TH3RO_PAD_Y;
}

// The plate's x: the same rule on the other axis — a right corner's distance is
// measured from the right edge, so there the plate grows to the RIGHT of the ink.
int TH3ROPlateX(const int nearX, const ENUM_BASE_CORNER corner)
{
    if(corner == CORNER_RIGHT_UPPER || corner == CORNER_RIGHT_LOWER)
        return nearX + TH3RO_PAD_X;
    return nearX - TH3RO_PAD_X;
}

// ── change-guarded writers (P-PERF-02) ─────────────────────────────
void TH3ROSetXy(const string nm, const int x, const int y)
{
    if(ObjectFind(0, nm) < 0) return;
    if((int)ObjectGetInteger(0, nm, OBJPROP_XDISTANCE) != x) ObjectSetInteger(0, nm, OBJPROP_XDISTANCE, x);
    if((int)ObjectGetInteger(0, nm, OBJPROP_YDISTANCE) != y) ObjectSetInteger(0, nm, OBJPROP_YDISTANCE, y);
}

void TH3ROSetWh(const string nm, const int w, const int h)
{
    if(ObjectFind(0, nm) < 0) return;
    if((int)ObjectGetInteger(0, nm, OBJPROP_XSIZE) != w) ObjectSetInteger(0, nm, OBJPROP_XSIZE, w);
    if((int)ObjectGetInteger(0, nm, OBJPROP_YSIZE) != h) ObjectSetInteger(0, nm, OBJPROP_YSIZE, h);
}

// Y only — the reposition pass moves a whole block without re-measuring it.
void TH3ROSetY(const string nm, const int y)
{
    if(ObjectFind(0, nm) < 0) return;
    if((int)ObjectGetInteger(0, nm, OBJPROP_YDISTANCE) != y) ObjectSetInteger(0, nm, OBJPROP_YDISTANCE, y);
}

void TH3ROSetCorner(const string nm, const ENUM_BASE_CORNER corner)
{
    if(ObjectFind(0, nm) < 0) return;
    if((int)ObjectGetInteger(0, nm, OBJPROP_CORNER) != (int)corner)
        ObjectSetInteger(0, nm, OBJPROP_CORNER, corner);
}

// Place — and, on the first call, CREATE — the plate at its own top-left corner.
void TH3ROPlateAt(const string plate, const ENUM_BASE_CORNER corner,
                  const int x, const int y, const int w, const int h,
                  const bool create, const string tooltip)
{
    if(create && ObjectFind(0, plate) < 0)
    {
        if(!ObjectCreate(0, plate, OBJ_RECTANGLE_LABEL, 0, 0, 0)) return;
        ObjectSetInteger(0, plate, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, plate, OBJPROP_STYLE,       STYLE_SOLID);
        ObjectSetInteger(0, plate, OBJPROP_WIDTH,       1);
        ObjectSetInteger(0, plate, OBJPROP_COLOR,       TH3RO_EDGE);
        ObjectSetInteger(0, plate, OBJPROP_BGCOLOR,     TH3RO_FILL);
        ObjectSetInteger(0, plate, OBJPROP_BACK,        false);
        ObjectSetInteger(0, plate, OBJPROP_SELECTABLE,  false);
        ObjectSetInteger(0, plate, OBJPROP_HIDDEN,      true);
        ObjectSetInteger(0, plate, OBJPROP_ZORDER,      Z_TH3_RO_PLATE);
        ObjectSetString( 0, plate, OBJPROP_TOOLTIP,     tooltip);
    }
    if(ObjectFind(0, plate) < 0) return;
    TH3ROSetCorner(plate, corner);
    TH3ROSetXy(plate, x, y);
    TH3ROSetWh(plate, w, h);
    // P-TH3-INFO-09: the same re-owning the rows got — a plate some stale
    // writer left with BACK=true slides under every label on the chart.
    if((bool)ObjectGetInteger(0, plate, OBJPROP_BACK))
        ObjectSetInteger(0, plate, OBJPROP_BACK, false);
}

// One row of ink: created on the first call, then only moved and re-inked.
// WHICH ink it wears is not this writer's question — it asks the palette owner
// (TH3ReadoutInk), so the leg meter's box and the AB=CD caption cannot end up
// with two different ideas of what the live row looks like.
bool TH3RORowAt(const string nm, const string txt, const ENUM_BASE_CORNER corner,
                const int x, const int y, const int fontPt,
                const int row, const int rowCount, const bool create)
{
    if(create && ObjectFind(0, nm) < 0)
    {
        if(!ObjectCreate(0, nm, OBJ_LABEL, 0, 0, 0)) return false;
        ObjectSetString( 0, nm, OBJPROP_FONT,       BioChromeFont());
        ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, nm, OBJPROP_HIDDEN,     true);
        ObjectSetInteger(0, nm, OBJPROP_ZORDER,     Z_TH3_RO_TEXT);
    }
    if(ObjectFind(0, nm) < 0) return false;
    color rowInk = TH3ReadoutInk(row, rowCount);
    TH3ROSetCorner(nm, corner);
    if((int)ObjectGetInteger(0, nm, OBJPROP_FONTSIZE) != fontPt)
        ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, fontPt);
    if(ObjectGetString(0, nm, OBJPROP_TEXT) != txt)
        ObjectSetString(0, nm, OBJPROP_TEXT, txt);
    if((color)ObjectGetInteger(0, nm, OBJPROP_COLOR) != rowInk)
        ObjectSetInteger(0, nm, OBJPROP_COLOR, rowInk);
    // P-TH3-INFO-09: the BACK flag is re-owned here, not just at creation — a
    // row a PRE-INFO-09 build (or any stale writer) left with BACK=true paints
    // BEHIND its own plate: the reported «متن داخل کادر سیاه دیده نمیشه» (the
    // plate renders, the ink is under it). Guarded write, one read per row.
    if((bool)ObjectGetInteger(0, nm, OBJPROP_BACK))
        ObjectSetInteger(0, nm, OBJPROP_BACK, false);
    TH3ROSetXy(nm, x, y);
    return true;
}

//+------------------------------------------------------------------+
//| P-TH3-INFO-01 (2026-09-20) — THE CAPTION IS WRAPPED, NOT CLIPPED.|
//|                                                                  |
//| MT4 truncates an object's text at 63 CHARACTERS. It is not a     |
//| MT4 quirk to be worked around once and forgotten; it is a CLIFF   |
//| that every caption added to walks off silently. The user's report |
//| was exactly that: the EURUSD D1 caption on screen read            |
//|                                                                  |
//|   AB=CD | AB:504.1 | BC:765.0 | Step:267.7 pips [closed K=3.0 rat |
//|                                                                  |
//| — 63 characters, cut mid-word inside "ratio" — while the live     |
//| step 267.7 was produced by the WALK-UP SHIFT, whose own words     |
//| ("-> SHIFT 2xLS(D1)=267.7"), the rung, T3/T5 and the milestone    |
//| were ALL past the cliff. Measured off the chart's own price axis  |
//| the ladder is consistent (Step1 1.1290, Step3 1.0754 — 536 pips = |
//| 2 x 267.7 — projecting from the real D at 1.1558) and the closed  |
//| seed really was 162.7 pips with K=3.0; the arithmetic was right.   |
//| What was missing was the ONE line that explains it, so the reader  |
//| draws the only conclusion left: «گام اشتباه میندازه» — a K=3.0    |
//| caption beside a step no K=3.0 seed can produce.                   |
//|                                                                    |
//| So the caption is a FAMILY, not a label: the SAME honest text,      |
//| wrapped at its own " | " boundaries into as many ≤63-character      |
//| lines as it needs, stacked by the project's own spacing (font + 6,  |
//| the mode-label stack's rule — P-TH3-PERF-01's neighbourhood).      |
//| Nothing about the text changes, so whenever the provenance grows    |
//| again the caption grows with it instead of losing its tail. The     |
//| wrap prefers a " | " boundary, falls back to the last space, and    |
//| only hard-cuts when a single token is longer than the line — and it |
//| NEVER drops text itself: the last slot takes whatever is left, so   |
//| the only clip that can still happen is MT4's own, on the final line |
//| of a caption longer than TH3_INFO_MAX_LINES x 63 characters.        |
//|                                                                    |
//| ONE OWNER for the family's whole lifecycle (name, wrap, draw,       |
//| delete, visibility, position). The active-pattern sweep, the        |
//| reposition pass and the delete path all ask these functions instead |
//| of spelling "_Info" themselves — that is what keeps a five-label    |
//| family from leaking a line into the next pattern's caption.         |
//+------------------------------------------------------------------+
#define TH3_INFO_TEXT_MAX  63   // MT4's own cap on OBJPROP_TEXT
#define TH3_INFO_MAX_LINES 10   // P-TH3-DISC: ten discovery rows, each under the
                                // cap so no row ever wraps (was 6; back with the caption)
#define TH3_INFO_ROWS      3    // P-TH3-INFO-04: the readout's layout is its rows
#define TH3_INFO_SLOT_GAP  8    // RETIRED (P-TH3-INFO-14, 2026-09-25): the px between two
                                // captions' plates in the stack. Kept for a one-line restore
                                // (see the retirement note below), no reader now.

// Line 0 keeps the historical name (`_Info`), so the base-name extraction,
// the prefix wipes and any object already on a chart keep resolving.
string TH3InfoLineName(const string base, const int line)
{
    if(line <= 0) return base + "_Info";
    return base + "_Info" + IntegerToString(line + 1);
}

// The plate that carries the family's ink (P-TH3-INFO-04). It is PART OF the
// family on purpose: a caption that is repositioned, hidden or deleted without
// its plate would leave a dark empty bar on the chart — the half-a-readout the
// BaseKnot note's own plate gate forbids on the other surface (P-BK-86).
string TH3InfoPlateName(const string base) { return base + "_InfoPlate"; }

//+------------------------------------------------------------------+
//| P-TH3-INFO-14 (2026-09-25) — THE SLOT PITCH IS DEAD; THE CAPTION |
//| SITS AT THE BASE OF THE SAFE AREA.                                |
//|                                                                  |
//| P-TH3-INFO-03 gave every pattern its own SLOT so two captions'     |
//| plates could not overlap, and P-TH3-INFO-04 sized that pitch on    |
//| `TH3_INFO_ROWS` (three). Both are now wrong in the same way:      |
//|                                                                  |
//|   * P-TH3-INFO-10 made the plate follow visibility by EXISTENCE —  |
//|     only the ACTIVE family carries a plate, and every inactive      |
//|     family's rows wear OBJ_NO_PERIODS. So a second slot can never  |
//|     be OCCUPIED, and the pitch could only ever push the one plate  |
//|     the user sees down by `patternIndex x (56 + 8) = 64 px` at the |
//|     reference size (pt 9, 96 dpi) — over the empty slot of a        |
//|     caption that is not there; and switching the active pattern     |
//|     made the caption JUMP by that much.                            |
//|   * The pitch was a FIXED three rows while the wrap budget is       |
//|     `TH3_INFO_MAX_LINES` (six): a four-line caption measures        |
//|     TH3ROPlateH(4) = 73 px against a 64 px pitch, and a six-line    |
//|     one 107 px — so the very overlap the slot existed to prevent    |
//|     was 9..43 px of it, and the "two plates never overlap" note at   |
//|     the call site was arithmetic that did not hold.                 |
//|                                                                  |
//| The pitch therefore has no reader that can be true, and the two    |
//| helpers that computed it are gone. The plate is measured from its  |
//| own final lines (`TH3ROPlateH(n)`), which is what makes it fit      |
//| whatever the wrap produced — the height was never the problem, the |
//| PITCH was. Restore a stack by giving `TH3_INFO_SLOT_GAP` a reader:  |
//| `topY = baseY + slot * (TH3ROPlateH(n, fontPt) + TH3_INFO_SLOT_GAP)`|
//| — with `n` the PREVIOUS family's own line count, never a constant.  |
//+------------------------------------------------------------------+

// Is this object part of ANY pattern's caption — a line, or the plate under them?
// (the family test the active-pattern sweep needs, so a line 2 is swept with its
// line 1, and a plate goes dark with the rows it carries)
bool TH3IsInfoPlateName(const string objName)
{
    int n = StringLen(objName);
    return (n > 10 && StringSubstr(objName, n - 10) == "_InfoPlate");
}

bool TH3IsInfoLabelName(const string objName)
{
    if(TH3IsInfoPlateName(objName)) return true;
    int n = StringLen(objName);
    for(int line = 0; line < TH3_INFO_MAX_LINES; line++)
    {
        string suffix = (line == 0) ? "_Info" : "_Info" + IntegerToString(line + 1);
        int s = StringLen(suffix);
        if(n > s && StringSubstr(objName, n - s) == suffix) return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| P-TH3-P6f (2026-09-22) — AT MOST ONE LADDER IS VISIBLE.          |
//| Two patterns in the store drew two Step1/3/5/7 families and the   |
//| chart read as one mixed ladder (XAUUSD M15: Step1 115.4 vs 109.6, |
//| Step3 346.3 vs 328.8 — each pattern owns its closedStep, so each  |
//| owns its q winner and its lock). The ladder is the ACTIVE         |
//| pattern's answer the way the caption already is (P-TH3-P6d) and   |
//| the mother badge already is (one badge per chart): other patterns |
//| keep their ABCD ink and their caption slot, but no targets, no   |
//| proof (P-TH3-DISC: zones stay ON for every pattern — the user's    |
//| order). Chart objects obey TIMEFRAMES (the P-TH3-INFO-10            |
//| exception is screen plates only), so masks hide them; guarded     |
//| writes only (perf law). Suffix-tested like the info test above.   |
//+------------------------------------------------------------------+
bool TH3IsLadderName(const string objName)
{
    // P-TH3-DISC: zones are NOT ladder-masked — they stay on every TF, active
    // or not (the user's order). Lines and mids still follow the caption.
    if(StringFind(objName, "_Target_") >= 0) return true;
    if(StringFind(objName, "_Mid_") >= 0) return true;
    if(StringFind(objName, "_HitLine") >= 0) return true;
    if(StringFind(objName, "_HitLabel") >= 0) return true;
    return false;
}

void TH3LadderMaskOne(const string objName, const int wantTF)
{
    if(ObjectFind(0, objName) < 0) return;
    if(ObjectGetInteger(0, objName, OBJPROP_TIMEFRAMES) != wantTF)
        ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, wantTF);
}

void TH3LadderSetVisible(const string base, const bool visible)
{
    int wantTF = visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
    for(int i = 1; i <= 4; i++)
    {
        string s = IntegerToString(i);
        TH3LadderMaskOne(base + "_Target_" + s, wantTF);
    }
    TH3LadderMaskOne(base + "_Mid_2", wantTF);
    TH3LadderMaskOne(base + "_Mid_4", wantTF);
    TH3LadderMaskOne(base + "_Mid_6", wantTF);
    TH3LadderMaskOne(base + "_HitLine", wantTF);
    TH3LadderMaskOne(base + "_HitLabel", wantTF);
}

//+------------------------------------------------------------------+
//| P-TH3-DEL1 (2026-09-22) -- THE FAMILY BASE, OFF THE NAME.       |
//| Pattern names are `ABCD_Pattern_<digits>` (TH3Tool.mqh: the      |
//| completion stamps GetTickCount()). Any member name — point, line, |
//| target, zone, border, proof, caption row, temp, or the TH3_MP_    |
//| overlay's own prefix — reduces to the same base: the literal      |
//| prefix plus its leading digits. "" when the name is no family    |
//| member at all. Pure string logic: Lite-safe, harness-safe.        |
//+------------------------------------------------------------------+
string TH3FamilyBaseOf(const string objName)
{
    string rest = objName;
    if(StringFind(rest, "TH3_MP_") == 0)
        rest = StringSubstr(rest, 7);
    string pre = TH3_PATTERN_PREFIX;
    if(StringFind(rest, pre) != 0) return "";
    string tail = StringSubstr(rest, StringLen(pre));
    int di = 0;
    int tn = StringLen(tail);
    while(di < tn)
    {
        ushort ch = StringGetCharacter(tail, di);
        if(ch < '0' || ch > '9') break;
        di++;
    }
    if(di <= 0) return "";
    return pre + StringSubstr(tail, 0, di);
}

//+------------------------------------------------------------------+
//| P-TH3-DEL2 (2026-09-22) -- THE ANCHORS DECIDE. A family whose    |
//| A/B/C points and AB/BC leg lines all stand is INTACT: a member   |
//| missing from it is our own maintenance (overlay/proof/zone       |
//| dropped by a draw) and is healed back, never wiped. A family     |
//| missing ANY of them was broken by a hand (or a failed build) and |
//| wipes whole. D/CD are NOT anchors: a rule-D pattern (AB=CD fallback,|
//| P-TH3-D4) carries no D objects, yet is whole -- demanding them   |
//| wiped such patterns on any member delete. Five probes, delete    |
//| path only -- nothing on the steady path.                         |
//+------------------------------------------------------------------+
bool TH3FamilyAnchorsAlive(const string base)
{
    if(ObjectFind(0, base + "_Point_A") < 0) return false;
    if(ObjectFind(0, base + "_Point_B") < 0) return false;
    if(ObjectFind(0, base + "_Point_C") < 0) return false;
#ifdef BIOTAK_RENDER_ENGINE
    // R-RENDER-ENGINE (MT5-ONLY): a canvas pattern carries no leg objects —
    // probing _Line_AB here told the delete path every HEALTHY family was
    // hand-broken, and a stray echo of our own sweep would then wipe points
    // and caption whole. The point arrows exist in both modes and are the
    // anchors; the line probe stays for the object render path (flag off).
    if(RBridgeActive()) return true;
#endif
    if(ObjectFind(0, base + "_Line_AB") < 0) return false;
    if(ObjectFind(0, base + "_Line_BC") < 0) return false;
    return true;
}

// Split a caption into its own rows: a "\n" is a HARD BREAK (P-TH3-INFO-04) —
// that is how a readout hands its rows over: what the pattern is, what its legs
// measure, and the live number.
int TH3InfoSplitRows(const string text, string &rows[])
{
    ArrayResize(rows, 0);
    string rest = text;
    while(true)
    {
        int p = StringFind(rest, "\n");
        int n = ArraySize(rows);
        ArrayResize(rows, n + 1);
        if(p < 0) { rows[n] = rest; break; }
        rows[n] = StringSubstr(rest, 0, p);
        rest = StringSubstr(rest, p + 1);
    }
    return ArraySize(rows);
}

// Wrap ONE row into the accumulator. The row is taken whole when it fits; a row
// past the cap breaks at its own " | " boundary, then at the last space, and only
// hard-cuts when a single token is longer than the line. The caller owns the slot
// budget, so two rows can never spend each other's lines.
void TH3InfoWrapRow(const string row, const int maxLen, string &lines[])
{
    string rest = row;
    int guard = 0;
    while(StringLen(rest) > 0 && guard < 32)
    {
        guard++;
        bool lastSlot = (ArraySize(lines) >= TH3_INFO_MAX_LINES - 1);
        if(StringLen(rest) <= maxLen || lastSlot)
        {
            int n = ArraySize(lines);
            ArrayResize(lines, n + 1);
            lines[n] = rest;
            break;
        }
        int cut = -1;
        int from = 0;
        while(true)                          // the LAST " | " that still fits
        {
            int p = StringFind(rest, " | ", from);
            if(p < 0 || p + 3 > maxLen) break;
            cut = p + 3;
            from = p + 1;
        }
        if(cut > 0 && (maxLen - cut) > maxLen / 5) cut = -1;
        if(cut <= 0)                         // else the last space that fits
        {
            cut = maxLen;
            for(int i = maxLen; i >= 1; i--)
            {
                if(StringGetCharacter(rest, i - 1) == 32) { cut = i; break; }
            }
        }
        int n = ArraySize(lines);
        ArrayResize(lines, n + 1);
        lines[n] = StringSubstr(rest, 0, cut);
        rest = StringSubstr(rest, cut);
        while(StringLen(rest) > 0 && StringGetCharacter(rest, 0) == 32)
            rest = StringSubstr(rest, 1);    // no line starts on the space it broke at
    }
}

// Wrap a whole caption: every "\n" row through the row wrapper, into ONE
// accumulator. Returns the count; the lines array is resized to it. Prefers a
// " | " boundary, then the last space, then a hard cut; the final slot takes the
// remainder, so this never drops text itself.
int TH3InfoWrap(const string text, const int maxLen, string &lines[])
{
    ArrayResize(lines, 0);
    string rows[];
    int rowCount = TH3InfoSplitRows(text, rows);
    for(int r = 0; r < rowCount && ArraySize(lines) < TH3_INFO_MAX_LINES; r++)
        TH3InfoWrapRow(rows[r], maxLen, lines);
    return ArraySize(lines);
}

// Delete every caption line of one pattern (the surplus lines included) AND the
// plate that carried them: half a readout left behind is a dark empty bar.
void TH3InfoFamilyDelete(const string base)
{
    for(int line = 0; line < TH3_INFO_MAX_LINES; line++)
        ObjectDelete(0, TH3InfoLineName(base, line));
    ObjectDelete(0, TH3InfoPlateName(base));
}

//+------------------------------------------------------------------+
//| P-TH3-INFO-10 (2026-09-22) — THE PLATE IS HIDDEN BY ABSENCE,     |
//| NEVER BY A MASK.                                                  |
//|                                                                   |
//| The report was the M15 chart's top-left box: «اول نمایش میده ولی   |
//| بعد دیگه فقط سیاه هستش». The caption's ROWS went dark on the      |
//| first deactivation (an OBJ_LABEL DOES honour OBJPROP_TIMEFRAMES —  |
//| the P-TH3-INFO-06c "hidden while active" state proved that on this |
//| terminal), while the plate behind them stayed: an                  |
//| OBJ_RECTANGLE_LABEL does NOT go away under the same mask (the      |
//| same screen-object fact P-UI-98n found for OBJ_BITMAP_LABEL — the  |
//| ride circles the L key could not hide). Every family path wrote    |
//| the SAME mask onto both halves, so every hide left a dark bar with |
//| no ink: the «جعبهٔ سیاه بالای چارت» this project has now chased    |
//| four times (INFO-06/06b/06c/08) with fixes aimed at the rows.      |
//|                                                                   |
//| So the plate's visibility is EXISTENCE: a family that must be dark |
//| drops its plate (display-only — a redraw recreates whatever it     |
//| needs), a family that must light grows it back from its OWN rows,  |
//| which are the geometry authority (placed on TH3ROPlateAt/          |
//| TH3RORowAt's one grid; they still hold corner, font, anchor Y and  |
//| text). The rows keep their masks — that half of the contract was   |
//| always honoured. Nothing ever writes OBJ_NO_PERIODS on a plate     |
//| again: a plate on the chart IS a visible plate.                    |
//+------------------------------------------------------------------+
void TH3InfoFamilyPlateDrop(const string base)
{
    string plate = TH3InfoPlateName(base);
    if(ObjectFind(0, plate) >= 0) ObjectDelete(0, plate);
}

// Rebuild the plate from the family's contiguous rows. False = nothing to
// carry (no row 0), which is exactly the orphan rule — never a plate alone.
// P-TH3-INFO-12 (2026-09-22): the rows are rebuilt AFTER the plate, always.
// MT4 ties equal ZORDER by CREATION ORDER (the rule TH3RORowAt's own header
// states), so rows that predate the plate they sit on paint UNDER it — the
// reported «وقتی روی خطوط کلیک میکنم سیاه میشه»: the active sweep (drop) plus
// the verify (grow) round-trip left every surviving row OLDER than its fresh
// plate, the plate covered the ink, and only the next full redraw healed it.
// Recreating the rows re-ages them past the plate; every property they need
// (corner, font, text, ink, BACK=false, Z_TH3_RO_TEXT) is re-owned by
// TH3RORowAt on the way in, and their TIMEFRAMES land on OBJ_ALL_PERIODS —
// both grow callers only ever grow a family that must be LIT.
// P-TH3-INFO-13: the visit clock is NOT armed here — every caller that lights
// a family arms it on its own way out (SetVisible's light path), so a hidden
// family regrown for layout never buys a visit.
bool TH3InfoFamilyPlateGrow(const string base)
{
    string r0 = TH3InfoLineName(base, 0);
    if(ObjectFind(0, r0) < 0) return false;
    string rows[];
    ArrayResize(rows, 0);
    for(int line = 0; line < TH3_INFO_MAX_LINES; line++)
    {
        string nm = TH3InfoLineName(base, line);
        if(ObjectFind(0, nm) < 0) break;          // Draw writes rows contiguously
        int cnt = ArraySize(rows);
        ArrayResize(rows, cnt + 1);
        rows[cnt] = ObjectGetString(0, nm, OBJPROP_TEXT);
    }
    int n = ArraySize(rows);
    if(n <= 0) return false;
    int fontPt = (int)ObjectGetInteger(0, r0, OBJPROP_FONTSIZE);
    int crn = (int)ObjectGetInteger(0, r0, OBJPROP_CORNER);
    ENUM_BASE_CORNER corner = (ENUM_BASE_CORNER)crn;
    int topY = (int)ObjectGetInteger(0, r0, OBJPROP_YDISTANCE);  // row 0 IS topY on both corner sides
    int nearX = (int)ObjectGetInteger(0, r0, OBJPROP_XDISTANCE);
    string plate = TH3InfoPlateName(base);
    TH3ROPlateAt(plate, corner,
                 TH3ROPlateX(nearX, corner),
                 TH3ROPlateY(topY, n, fontPt, corner),
                 TH3ROPlateW(rows, n, fontPt),
                 TH3ROPlateH(n, fontPt),
                 true,
                 "AB=CD caption (P-TH3-INFO-04): the pattern, its legs in pips, and the live step");
    // a plate a pre-INFO-10 build left masked heals itself on the way in —
    // the mask is meaningless to it now, but one honest write settles both
    // possible terminal behaviours.
    if((int)ObjectGetInteger(0, plate, OBJPROP_TIMEFRAMES) != OBJ_ALL_PERIODS)
        ObjectSetInteger(0, plate, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
    // P-TH3-INFO-12: the ink goes back on AFTER the plate exists — a row a
    // pre-grow build created is older than this fresh plate and paints under
    // it (the black box with no text). Deleting first makes TH3RORowAt's
    // create path run, which re-owns every property the row wears.
    for(int line = 0; line < n; line++)
    {
        string nm = TH3InfoLineName(base, line);
        ObjectDelete(0, nm);
        TH3RORowAt(nm, rows[line], corner, nearX,
                   TH3RORowY(topY, line, fontPt, corner), fontPt,
                   line, n, true);
        if((int)ObjectGetInteger(0, nm, OBJPROP_TIMEFRAMES) != OBJ_ALL_PERIODS)
            ObjectSetInteger(0, nm, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
    }
    return true;
}

// Show/hide the whole family (the active-pattern rule: at most ONE pattern's
// caption is visible, and "one" means every line of it AND its plate).
void TH3InfoFamilySetVisible(const string base, const bool visible)
{
    // P-TH3-INFO-08: never show a plate with no rows — it paints as a dark
    // empty bar. Showing is display-only: deleting the orphan loses nothing a
    // redraw cannot recreate.
    // P-TH3-INFO-10: the PLATE now follows the intent by EXISTENCE — a mask
    // does not hide an OBJ_RECTANGLE_LABEL (the rows DO obey theirs), so
    // masking the plate is exactly what left «فقط سیاه» on the chart.
    int rows = 0;
    for(int line = 0; line < TH3_INFO_MAX_LINES; line++)
        if(ObjectFind(0, TH3InfoLineName(base, line)) >= 0) rows++;
    if(rows <= 0) { TH3InfoFamilyPlateDrop(base); return; }
    for(int line = 0; line < TH3_INFO_MAX_LINES; line++)
    {
        string nm = TH3InfoLineName(base, line);
        if(ObjectFind(0, nm) < 0) continue;
        // P-TH3-INFO-08: ink above plate — rare path, unconditional is fine.
        ObjectSetInteger(0, nm, OBJPROP_ZORDER, Z_TH3_RO_TEXT);
        ObjectSetInteger(0, nm, OBJPROP_TIMEFRAMES,
                         visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
    }
    if(!visible) { TH3InfoFamilyPlateDrop(base); return; }
    string plate = TH3InfoPlateName(base);
    if(ObjectFind(0, plate) < 0)
    {
        TH3InfoFamilyPlateGrow(base);
        TH3InfoVisitArm();   // P-TH3-INFO-13: a regrown plate still buys a visit
        return;
    }

    ObjectSetInteger(0, plate, OBJPROP_ZORDER, Z_TH3_RO_PLATE);
    if((bool)ObjectGetInteger(0, plate, OBJPROP_BACK))
        ObjectSetInteger(0, plate, OBJPROP_BACK, false);
    if((int)ObjectGetInteger(0, plate, OBJPROP_TIMEFRAMES) != OBJ_ALL_PERIODS)
        ObjectSetInteger(0, plate, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
    TH3InfoVisitArm();   // P-TH3-INFO-13: every light path re-arms the visit
}

// Move the whole block — rows AND plate — down from a top offset, keeping its
// stacking. The rows move on the readout's own grid (TH3RORowY) and the plate on
// the same one, which is what keeps the ink inside the plate after the move.
void TH3InfoFamilyReposition(const string base, const int topY)
{
    int fontPt = inpABCDInfoFontSize;
    int rows = 0;
    for(int line = 0; line < TH3_INFO_MAX_LINES; line++)
        if(ObjectFind(0, TH3InfoLineName(base, line)) >= 0) rows++;
    for(int line = 0; line < TH3_INFO_MAX_LINES; line++)
    {
        string nm = TH3InfoLineName(base, line);
        if(ObjectFind(0, nm) < 0) continue;
        TH3ROSetY(nm, TH3RORowY(topY, line, fontPt, inpABCDInfoCorner));
    }
    string plate = TH3InfoPlateName(base);
    if(ObjectFind(0, plate) < 0) return;
    // P-TH3-INFO-06: a plate with no rows is never a valid state — it paints
    // as a dark empty bar (the user's top-left box). Rows are counted by
    // EXISTENCE above (a hidden row still counts), so this only ever removes a
    // true orphan instead of moving it.
    if(rows <= 0) { ObjectDelete(0, plate); return; }
    TH3ROSetY(plate, TH3ROPlateY(topY, rows, fontPt, inpABCDInfoCorner));
}

// P-TH3-INFO-06b (2026-09-21) — THE CHART-WIDE ORPHAN SWEEP. The reposition
// pass only visits the STORE, but a plate can outlive its rows from a path
// that never touches the store (a skipped restore base, a build mix after a
// remove/re-add): a plate with ZERO surviving family rows is never valid —
// it paints as a dark empty bar (the top-left box). Display-only objects, so
// deleting one destroys nothing a redraw cannot recreate. Rows count by
// EXISTENCE (a hidden row still counts), exactly like the reposition guard.
// Callers: the reposition pass (rare layout moments) and the attach restore.
void TH3InfoOrphanPlateSweep()
{
    // MT4 parity: no total-count gate. A row can die in the same frame that
    // another object is born, leaving the total unchanged; a gate on that
    // number would then never see the orphan. The walk reads every object but
    // only `ABCD_Pattern_*_InfoPlate` names are candidates, and it runs on
    // layout/attach moments rather than every tick.
    for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
    {
        string nm = ObjectName(0, i, -1, -1);
        if(StringFind(nm, "ABCD_Pattern_") != 0) continue;
        int n = StringLen(nm);
        if(n <= 10 || StringSubstr(nm, n - 10) != "_InfoPlate") continue;
        string base = StringSubstr(nm, 0, n - 10);
        bool anyRow = false;
        for(int line = 0; line < TH3_INFO_MAX_LINES; line++)
        {
            if(ObjectFind(0, TH3InfoLineName(base, line)) >= 0) { anyRow = true; break; }
        }
        if(!anyRow) ObjectDelete(0, nm);
    }
}

// P-TH3-INFO-06c (2026-09-21) — VERIFY, THEN MOVE. Reposition used to only
// move families that already agreed with the active rule; a family whose rows
// exist but wear the WRONG visibility (hidden while active, or lit while
// retired) kept disagreeing forever — the caption that «یکبار میاد ولی ...
// دیگه نمیشه». The redraw always rewrites both sides together, so this only
// heals what happened BETWEEN redraws, through the ONE owner (guarded writes,
// no second writer of TIMEFRAMES here). A plate with no rows dies like any
// other orphan (the store-side twin of the chart-wide sweep).
void TH3InfoFamilyVerify(const string base, const bool isActive)
{
    int rows = 0;
    for(int line = 0; line < TH3_INFO_MAX_LINES; line++)
        if(ObjectFind(0, TH3InfoLineName(base, line)) >= 0) rows++;
    string plate = TH3InfoPlateName(base);
    bool hasPlate = (ObjectFind(0, plate) >= 0);
    if(rows <= 0) { TH3InfoFamilyPlateDrop(base); return; }
    int wantTF = isActive ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
    for(int line = 0; line < TH3_INFO_MAX_LINES; line++)
    {
        string nm = TH3InfoLineName(base, line);
        if(ObjectFind(0, nm) < 0) continue;
        // P-TH3-INFO-08: ink above plate, re-asserted UNGUARDED (old charts).
        // P-UI-31: the rung is never read back — a guarded read would be a
        // product question about paint order, and the 8ab-20b seed bans it.
        // The 250 ms net only reaches a family that already exists; seven
        // same-value writes beat a diagnostic read the audit forbids.
        ObjectSetInteger(0, nm, OBJPROP_ZORDER, Z_TH3_RO_TEXT);
        // P-TH3-INFO-09: and the BACK flag healed here — a stale row with
        // BACK=true is invisible behind its own plate between redraws.
        if((bool)ObjectGetInteger(0, nm, OBJPROP_BACK))
            ObjectSetInteger(0, nm, OBJPROP_BACK, false);
        if((int)ObjectGetInteger(0, nm, OBJPROP_TIMEFRAMES) != wantTF)
            ObjectSetInteger(0, nm, OBJPROP_TIMEFRAMES, wantTF);
    }
    // P-TH3-INFO-10: the plate is EXISTENCE, never a mask — a family that
    // must be dark drops its plate; a lit family whose plate went missing
    // grows it back from its own rows. Only the ALL half of wantTF ever
    // touches a plate from here (a masked plate is a plate that stayed
    // visible — the empty dark bar).
    if(!isActive) { TH3InfoFamilyPlateDrop(base); return; }
    if(!hasPlate) { TH3InfoFamilyPlateGrow(base); return; }
    // P-TH3-INFO-11 / P-UI-31: same unguarded re-assert as the rows above —
    // the rung is never read back (see the rows' note).
    ObjectSetInteger(0, plate, OBJPROP_ZORDER, Z_TH3_RO_PLATE);
    if((bool)ObjectGetInteger(0, plate, OBJPROP_BACK))
        ObjectSetInteger(0, plate, OBJPROP_BACK, false);
    if((int)ObjectGetInteger(0, plate, OBJPROP_TIMEFRAMES) != OBJ_ALL_PERIODS)
        ObjectSetInteger(0, plate, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
}

// ── P-TH3-INFO-13 — THE CAPTION IS A TIMED VISITOR ─────────────────
// The user's order (2026-09-22): «لیبل مود ها و لیبل abcd باید بعد چند ثانیه
// حذف بشن هرچی که اطلاعاتی هستش» — every info readout is a guest of a few
// seconds, the leg meter's own contract (P-LM-09). ONE deadline global, armed
// by the light paths (SetVisible's light branch, the verify's grow, and the
// redraw's own active re-arm in DrawABCDPattern), asked
// through the wrap-safe owner (TickDeadlinePending, [tick-wrap]), swept by the
// 250 ms heal net BEFORE its heal half so a heal can never resurrect an
// expired visit. The duration is inpModeLabelDuration — the SAME input the
// mode rows expire on — so one setting owns every info readout's lifetime.
// 0 = permanent (the input's own contract).
uint g_th3InfoVisitUntilMs = 0;

// The active family's visit still has time on it.
bool TH3InfoVisitPending() { return (g_th3InfoVisitUntilMs != 0); }

// Arm/re-arm the active family's visit clock. Called by the light paths
// (SetVisible's light branch; the verify's grow); a redraw re-arms, an expiry
// is a drop.
void TH3InfoVisitArm()
{
    int durSec = inpModeLabelDuration;
    if(durSec <= 0) { g_th3InfoVisitUntilMs = 0; return; }   // 0 = permanent
    if(durSec > 86400) durSec = 86400;
    g_th3InfoVisitUntilMs = GetTickCount() + (uint)durSec * 1000;
}

// The expiry's own verb: the whole ACTIVE family goes dark through its ONE
// owner (rows masked, plate dropped — the P-TH3-INFO-10 shapes), the active
// pattern stays in the store and its ladder stays; only the readout leaves.
void TH3InfoFamilyDropActive()
{
    string base = g_activeABCDPattern;
    if(base == "") return;
    TH3InfoFamilySetVisible(base, false);
}

//+------------------------------------------------------------------+
//| P-TH3-INFO-11 (2026-09-22) -- THE CAPTION HEAL NET. The top-left |
//| dark plate kept recurring (INFO-06/06b/06c/08/10) because every  |
//| fix covered the paths that DRAW, while killer paths only need to |
//| delete or mask ROWS once between redraws (object-list deletes the |
//| terminal allows despite SELECTABLE=false, foreign sweeps, build   |
//| mixes). So the 250 ms timer asks one question of the ACTIVE      |
//| family through its one owner: rows-masked-while-active unmasked, |
//| missing plate regrown, rowless plate dropped. Reads-only while   |
//| healthy (every write below the verify is guarded); an action     |
//| logs one TH3CAP line the user can send back with the screenshot. |
//+------------------------------------------------------------------+
void TH3InfoCaptionHeal()
{
    if(g_activeABCDPattern == "") return;
    if(IsIndicatorHidden()) return;   // P-UI-93: no caption heal under a hidden indicator
    string base = g_activeABCDPattern;
    // P-TH3-INFO-13 (2026-09-22): the caption is a TIMED VISITOR first. The
    // user's order: «لیبل مود ها و لیبل abcd باید بعد چند ثانیه حذف بشن
    // هرچی که اطلاعاتی هستش» — every info readout leaves after a few
    // seconds, exactly the leg meter's 4-second visit (P-LM-09). The sweep
    // runs here (the 250 ms clock, already running) BEFORE the heal, so a
    // heal can never resurrect an expired visit. Duration is the SAME input
    // the mode rows answer (inpModeLabelDuration, 0 = permanent). A redraw
    // (a re-step, a drag, a settings press) re-arms the clock below.
    if(TH3InfoVisitPending() && !TickDeadlinePending(g_th3InfoVisitUntilMs))
    {
        TH3InfoFamilyDropActive();
        g_th3InfoVisitUntilMs = 0;
        ThrottledChartRedraw();
        return;
    }
    int rows = 0;
    bool masked = false;
    for(int line = 0; line < TH3_INFO_MAX_LINES; line++)
    {
        string nm = TH3InfoLineName(base, line);
        if(ObjectFind(0, nm) < 0) continue;
        rows++;
        if((int)ObjectGetInteger(0, nm, OBJPROP_TIMEFRAMES) != OBJ_ALL_PERIODS)
            masked = true;
    }
    bool hasPlate = (ObjectFind(0, TH3InfoPlateName(base)) >= 0);
    if(rows <= 0 && !hasPlate) return;            // nothing to heal
    if(rows > 0 && !masked && hasPlate) return;   // healthy: reads only
    TH3InfoFamilyVerify(base, true);              // (its grow re-arms the visit)
    // P-TIME-01: the line carries its own SERVER stamp (epoch, no spaces) so
    // rows from two machines stay comparable -- Experts prefixes print the
    // Windows clock, which is a second timezone the formula must not see.
    Print("TH3CAP healed ", base, " st=", IntegerToString((long)TimeCurrent()),
          " rows=", rows,
          " masked=", (masked ? 1 : 0), " plate=", (hasPlate ? 1 : 0));
    ThrottledChartRedraw();
}

// ── P-TH3-INFO-04 — THE CAPTION WRITER: text in, a boxed readout out ──
// THE owner of what a caption looks like. The text may carry "\n" ROW BREAKS (the
// readout's layout: what the pattern is, what its legs measure, the live number),
// and every row is wrapped on its own — MT4's 63-character cliff is per OBJECT, so
// a row that needs two lines gets them instead of being cut. The plate is then
// measured off the FINAL lines, so a caption that grows a line grows its plate
// with it. `topY` starts the whole block, so each pattern's plate owns its slot.
int TH3InfoFamilyDraw(const string base, const string text,
                      const bool isActive, const int topY)
{
    string lines[];
    int n = TH3InfoWrap(text, TH3_INFO_TEXT_MAX, lines);
    if(n <= 0)
    {
        TH3InfoFamilyDelete(base);   // nothing to say: no caption AND no empty plate
        return 0;
    }
    int fontPt = inpABCDInfoFontSize;
    int wantTF = isActive ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
    string plate = TH3InfoPlateName(base);

    // A plate that is NOT there yet is created now — and every row that predates
    // it is dropped FIRST (P-TH3-INFO-08 keeps the explicit rungs plate 62 /
    // ink 63 too, so creation order no longer decides). The rows are
    // our own text and every character of it is recomputed right here, so
    // rebuilding them moves nothing the user drew.
    // P-TH3-INFO-10: only the ACTIVE family carries a plate — an inactive
    // one would need a mask to go dark, and a mask does not hide an
    // OBJ_RECTANGLE_LABEL (its rows DO obey theirs — that asymmetry is the
    // empty dark bar: «اول نمایش میده ولی بعد دیگه فقط سیاه هستش»).
    if(isActive)
    {
        if(ObjectFind(0, plate) < 0)
            for(int line = 0; line < TH3_INFO_MAX_LINES; line++)
                ObjectDelete(0, TH3InfoLineName(base, line));

        TH3ROPlateAt(plate, inpABCDInfoCorner,
                     TH3ROPlateX(inpABCDInfoXDistance, inpABCDInfoCorner),
                     TH3ROPlateY(topY, n, fontPt, inpABCDInfoCorner),
                     TH3ROPlateW(lines, n, fontPt), TH3ROPlateH(n, fontPt), true,
                     "AB=CD caption (P-TH3-INFO-04): the pattern, its legs in pips, and the live step");
    }

    for(int line = 0; line < TH3_INFO_MAX_LINES; line++)
    {
        string nm = TH3InfoLineName(base, line);
        if(line >= n)
        {
            if(ObjectFind(0, nm) >= 0) ObjectDelete(0, nm);
            continue;
        }
        TH3RORowAt(nm, lines[line], inpABCDInfoCorner, inpABCDInfoXDistance,
                   TH3RORowY(topY, line, fontPt, inpABCDInfoCorner), fontPt,
                   line, n, true);
        if((int)ObjectGetInteger(0, nm, OBJPROP_TIMEFRAMES) != wantTF)
            ObjectSetInteger(0, nm, OBJPROP_TIMEFRAMES, wantTF);
    }
    // P-TH3-INFO-10: an inactive family drops its plate (existence is its
    // visibility); an active one only ever heals toward ALL — never a mask.
    if(!isActive) { TH3InfoFamilyPlateDrop(base); return n; }
    if(ObjectFind(0, plate) >= 0 &&
       (int)ObjectGetInteger(0, plate, OBJPROP_TIMEFRAMES) != OBJ_ALL_PERIODS)
        ObjectSetInteger(0, plate, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
    return n;
}

#endif // TH3_RENDERER_A_MQH
// TH3Renderer_B.mqh - TH3Renderer.mqh split 2026-09-29: exact lines 969-2355, byte-identical, zero renames.
#ifndef TH3_RENDERER_B_MQH
#define TH3_RENDERER_B_MQH

void DrawABCDPattern(string mainObjName, datetime tA, double pA, datetime tB, double pB,
                     datetime tC, double pC, datetime tD = 0, double pD = 0)
{
    if(IsIndicatorHidden()) return;   // P-UI-93: a hidden indicator paints nothing
    #ifdef ENABLE_DEBUG_LOGS
    Print("==================== DrawABCDPattern called | Name: ", mainObjName);
    Print("   A: ", TimeToString(tA), " @ ", DoubleToString(pA, Digits));
    Print("   B: ", TimeToString(tB), " @ ", DoubleToString(pB, Digits));
    Print("   C: ", TimeToString(tC), " @ ", DoubleToString(pC, Digits));
    Print("   D: ", TimeToString(tD), " @ ", DoubleToString(pD, Digits));
    #endif

    // R-RENDER-ENGINE (phase A, 2026-10-17): the pattern's ink is staged onto
    // the canvas - the skeleton, the fibo legs, targets, mids, zone bands and
    // every label. Only Point_A..D stay objects (the terminal drags objects,
    // not canvas pixels - the magnet reads them) and the caption family stays
    // objects until phase A2. Comment the entry's one flag line for the
    // object-path A/B; this branch turns off with it. Declared before the
    // early-fail path below, which drops the base's canvas rows with its
    // objects.
    // R-MASK-SCOPE (2026-10-23) — THE PATTERN IS A DRAWING, NOT A LADDER.
    // The canvas engine's licence in this fork is the MT5-only mask for the
    // LEVELS ladder and the HTF candles, and nothing else (user rule,
    // 2026-10-23). The TH3/ABCD pattern is an object the user grabs, drags and
    // deletes, so it paints REAL OBJECTS here exactly as MT4 does; the bridge
    // branch below stays compiled for the A/B sweep but is never taken. Define
    // BIOTAK_RENDER_PATTERNS (beside BIOTAK_RENDER_ENGINE) to put the pattern
    // back on the canvas.
    bool rbr = false;
#ifdef BIOTAK_RENDER_ENGINE
    #ifdef BIOTAK_RENDER_PATTERNS
    rbr = RBridgeActive();
    #else
    rbr = false;
    #endif
#endif
    bool isActive = (g_activeABCDPattern == mainObjName);
    
    if(tD <= 0 || pD <= 0) {
        if(!CalculateABCDPointD(tA, pA, tB, pB, tC, pC, tD, pD)) {
            #ifdef ENABLE_DEBUG_LOGS
            Print("==================== CalculateABCDPointD failed - cleaning up temp objects");
            #endif
            
            // Cleanup partial objects
            string pointNames[5] = {"X", "A", "B", "C", "D"};
            for(int i = 0; i < 5; i++) {
                ObjectDelete(0, mainObjName + "_Point_" + pointNames[i]);
                ObjectDelete(0, mainObjName + "_Label_" + pointNames[i]);
            }
            ObjectDelete(0, mainObjName + "_Line_XA");
            ObjectDelete(0, mainObjName + "_Line_AB");
            ObjectDelete(0, mainObjName + "_Line_BC");
            ObjectDelete(0, mainObjName + "_Line_CD");
            ObjectDelete(0, mainObjName + "_Ray_D");
            ObjectDelete(0, mainObjName + "_Ray_C");
            ObjectDelete(0, mainObjName + "_CDLabel");
            ObjectDelete(0, mainObjName + "_MPTick");
            ObjectDelete(0, mainObjName + "_MPTickB");
            for(int _i = 0; _i < TH3_PIVOT_BASE_LEVELS; _i++) {
                ObjectDelete(0, mainObjName + "_PBLine_"  + IntegerToString(_i));
                ObjectDelete(0, mainObjName + "_PBLabel_" + IntegerToString(_i));
            }
            TH3InfoFamilyDelete(mainObjName);   // P-TH3-INFO-01: the whole caption family
#ifdef BIOTAK_RENDER_ENGINE
            if(rbr) RBridgePatternDropBase(mainObjName);   // R-RENDER-ENGINE: the canvas rows leave with the objects
#endif
            return;
        }
    }
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("==================== Point D: ", TimeToString(tD), " @ ", DoubleToString(pD, Digits));
    #endif
    
    double AB_Distance = MathAbs(pB - pA);
    double BC_Distance = MathAbs(pC - pB);
    double CD_Distance = MathAbs(pD - pC);
    bool dirDown = (pD > pC);   // D is a high, reversal runs down; if D is a low (pD < pC), reversal runs up
    bool isBullish = !dirDown;
    double frequency = GetCurrentTH3Frequency();

    // The ABCD pattern completes at Point D (tD, pD).
    // Closed legs: impulse leg CD and prior retracement leg BC.
    double closedStep = 0, closedK = 0, closedRatio = 0;
    bool closedOK = TH3ClosedStepFromLegs(pB, pC, pD, closedStep, closedK, closedRatio);
    int cdBars = TH3ClosedBars(tC, tD);
    int ownerTF = TH3ClosedOwnerTF(cdBars);
    double seedRung = TH3PatternStepRungTF(ownerTF);
    if(seedRung <= 0) seedRung = TH3PatternStepRung();
    double pip0 = GetCachedPipSize();   // local: the seed/lock blocks sit above pipSize's decl
    if(pip0 <= 0) pip0 = Point;

    // P-TH3-STEP-16 (2026-10-05) — THE UNIFIED EQUATION. One formula, no
    // branches: the B-marked mother (mandatory anchor) and the ABCD leg
    // resonate geometrically (CalculateUnifiedMasterStep, TH3Pivots_B.mqh).
    // TH3ClosedK above stays as the lock's diagnostic reference only — the
    // decider ladder is TH3UnifiedK inside the function.
    double motherSize = TH3ManualBaseStep(inpTH3PivotBasePips, pip0);
    double uniRatio = (closedOK ? closedRatio : 0.0);
    if(!closedOK && BC_Distance > 0 && CD_Distance > 0)
        uniRatio = CD_Distance / BC_Distance;
    double uniK = TH3UnifiedK(uniRatio);
    double baseUnit = 0;
    string seedHow = "";
    double uniStep = CalculateUnifiedMasterStep(CD_Distance, uniRatio, motherSize, seedRung);
    if(uniStep > 0) {
        baseUnit = uniStep;
        seedHow = StringFormat("uni K=%.1f pat=%.1f mom=%.1f th=%.1f%s", uniK,
                               CD_Distance / pip0, motherSize / pip0, seedRung / pip0,
                               (ownerTF != Period() ? " up" : ""));
    } else if(seedRung > 0) {
        baseUnit = seedRung;
        seedHow = (ownerTF != Period()
                   ? StringFormat("TH rung up %s", TH3TfName(ownerTF))
                   : "TH rung");
    }
    bool atrBasis = (baseUnit > 0);
    if(!atrBasis) baseUnit = (CD_Distance > 0 ? CD_Distance : AB_Distance) * (frequency / 100.0);

    // P-TH3-PB-MAN (2026-09-21) — PATH 1 IS HAND-TYPED, NOT DRAWN.
    // The user types the pivot base's height in the TH3 TOOL card, in pips
    // (`inpTH3PivotBasePips`); TH3ManualBaseStep turns it into a price and it
    // enters TH3LockedStep as pbStep. 0 = OFF: no Path 1 at all, and the seed
    // below (the pattern TF's own ATR) is the whole answer — which is the
    // "default from the same timeframe's ATRs" the user asked for. The
    // detector's own candidate (TH3NodeStepAt) no longer answers the LOCK: a
    // hand-typed number is an instruction, a scanned one is not, and the two
    // must never be averaged into each other. (The detector still answers the
    // SEED above, as the synthesis' mother factor.)
    // P-TH3-PB-RET8 (2026-09-22) — THE TYPED NUMBER IS A RETRACE: one R wears
    // eight candidate steps (TH3RetraceBestStep, TH3Pivots.mqh). The winner is
    // the candidate nearest the ABCD step (closedStep: pattern momentum, 60%)
    // and the owner TF's rung (seedRung: fractal volatility, 40%) — the TF
    // comparison rides inside those two anchors, so no new bar read is added.
    // The ref is CLOSED step, never the synthesis: synth already blends TH and
    // the mother, so anchoring Path 1 to it and then locking Path 1 against it
    // is a circle that fires LOCKED by construction. ABCD-anchored Path 1 vs
    // synthesis Path 2 lets TH3LockedStep arbitrate two INDEPENDENT answers.
    // The caption words it as `ret <q>`.
    double pbRaw = motherSize;  // same hand thickness the synthesis above consumes
    double pbStep = pbRaw;
    string retHow = "";
    if(pbRaw > 0)
    {
        double retRef = (closedOK && closedStep > 0 ? closedStep : 0.0);
        double bS = 0, bQ = 0; int bI = -1;
        if(TH3RetraceBestStep(pbRaw, retRef, seedRung, bS, bQ, bI) && bS > 0)
        {
            pbStep = bS;
            retHow = StringFormat("ret %s", TH3RetraceQName(bI));
        }
    }

    // P-TH3-STEP-16: the lock is now a SECOND OPINION, never the decider.
    // The unified step above stands; this verdict (does the hand base agree
    // with it?) is logged in TH3LOG and captioned, never applied.
    bool stepLocked = false;   // the verdict is carried by `lockHow`'s own word
    string lockHow = "";
    double lockedUnit = 0.0;
    TH3LockedStep(lockedUnit, lockHow, stepLocked,
                  baseUnit, pbStep, 0.0,
                  ownerTF, Period(), pip0);
    if(lockHow != "") seedHow += " | " + lockHow;
    if(retHow != "") seedHow += " | " + retHow;

    // Reaction proof from Point D — DIAGNOSTIC ONLY (P-TH3-STEP-16). The
    // reaction no longer moves the ladder; the unified step stands. The vote
    // is still measured, printed and logged (TH3LOG proof/deep) so the chart
    // says whether the market confirmed the equation's answer.
    TH3HitProof hitProof;
    bool hitOK = TH3HitPivotMeasure(tD, pD, dirDown, baseUnit,
                                    hitProof, (closedOK ? closedStep : 0.0));
    // P-TH3-STEP-04e: when no reaction has voted, the label says how far the
    // reaction DID reach, against the floor — the difference between "nothing
    // reacted" and "the walk never ran" was invisible before this number.
    string stepHow = StringFormat("%s; reaction %.2f/%.2f rungs",
                                   seedHow, hitProof.deepestRungs, TH3_STEP_MIN_LEG_RUNGS);
    string hitOwnerTF = "";
    // P-TH3-STEP-09 (BUG B): the vote refines the seed only inside ±25% —
    // the measure already enforces this gate; this second lock stands for
    // any future caller that skips the refStep. A refused vote keeps seed.
    if(hitOK && closedOK && closedStep > 0
       && MathAbs(hitProof.step - closedStep) / closedStep > TH3_HIT_MAX_STEP_ERR)
        hitOK = false;
    if(hitOK) {
        // P-TH3-STEP-16: NO overwrite — the unified step stands; the vote below
        // is corroboration (diagnostic), never the decider.
        hitOwnerTF = (hitProof.hasPivot ? TH3TfName(hitProof.pivTF) : "");
        stepHow = hitProof.hasPivot
                ? StringFormat("T3@%s err %.1f%% x%d", hitOwnerTF,
                               hitProof.rungErr * 100.0, hitProof.touches)
                : StringFormat("T3 reaction x%.2f", hitProof.step / hitProof.rung);
        // which grid does the proved step belong to? Walk the fractal chain
        // up and keep the TF whose own rung sits nearest the step — the
        // user's "شاید مال تایم بزرگ‌تر باشه", answered with numbers. When no
        // six-condition pivot sat on the tip, a bigger TF that still CLAIMS it
        // names the grid in the verdict too (the arithmetic stays the tip's).
        string owner = "";
        double bestR = 1e9;
        int tfWalk = Period();
        for(int w = 0; w < 6; w++) {
            // P-TH3-STEP-08: rungs are TH of their own TFs — same ruler as
            // the ladder (last completed bar of each).
            double r = TH3PatternStepRungTF(tfWalk);
            if(tfWalk != Period() && hitOwnerTF == "" && r > 0) {
                double claimed = 0;
                if(TH3SixPivotsHasPivotAt(tfWalk, hitProof.tipTime, hitProof.tipPrice,
                                          0.5 * r, claimed)) {
                    hitOwnerTF = TH3TfName(tfWalk);
                    stepHow = StringFormat("T3 reaction x%.2f <- %s grid",
                                           hitProof.step / hitProof.rung, hitOwnerTF);
                }
            }
            if(r > 0) {
                double ratio = hitProof.step / r;
                if(MathAbs(ratio - 1.0) < bestR) {
                    bestR = MathAbs(ratio - 1.0);
                    owner = StringFormat("%s x%.2f", THRungNameForTFMin(tfWalk), ratio);
                }
            }
            int up = TH3FractalStepTF(tfWalk, 1);
            if(up == tfWalk) break;
            tfWalk = up;
        }
        Print("TH3: step proof - tip ", DoubleToString(hitProof.tipPrice, Digits),
              " (", (hitProof.pivIsHigh ? "HIGH" : "LOW"), "), step=",
              DoubleToString(hitProof.step / GetCachedPipSize(), 1),
              " pips vs rung ", DoubleToString(hitProof.rung / GetCachedPipSize(), 1),
              " pips (x", DoubleToString(hitProof.step / hitProof.rung, 2), ") ",
              (hitProof.hasPivot ? "on a six-condition pivot" : "- no pivot at the tip"),
              (hitProof.hasPivot ? StringFormat(", err %.1f%%, %d touch(es)",
                                                hitProof.rungErr * 100.0, hitProof.touches) : ""),
              ", grid: ", owner);
    }
    else {
        // P-TH3-STEP-04e: the rejection is logged with its own number, so the
        // chart's own log says whether the ladder is on its seed because the
        // market has not reacted or because the walk was never reached.
        Print("TH3: step not proved - deepest reaction ",
              DoubleToString(hitProof.deepestRungs, 2), " rungs of the ",
              DoubleToString(TH3_STEP_MIN_LEG_RUNGS, 2), " the vote needs; seed ",
              seedHow, " ",
              DoubleToString(baseUnit / GetCachedPipSize(), 1),
              " pips stays the step (thin market / young reaction).");
    }

    // P-TH3-LOG1 (2026-09-22) — THE FEEDBACK LOOP, ONE LINE PER VERDICT.
    // The user marks the chart (ABCD + BASE PIPS) and sends screenshots; the
    // formula updates off DATA, so every input and every verdict lands in the
    // Experts log in one parseable shape (tools/th3_log_collect.py reads it
    // back into CSV: q distribution, lock rate, step-vs-closed bias). Ring of
    // 8 verdict keys: drags and ticks re-derive the same answer for free.
    {
        string logQ = (retHow == "" ? "off" : StringSubstr(retHow, 4));
        string logKey = StringFormat("%s|%.1f|%.1f|%.1f|%s|%d|%.1f|%d",
                                     mainObjName, pbRaw / pip0,
                                     (closedOK ? closedStep / pip0 : 0.0),
                                     seedRung / pip0, logQ,
                                     (stepLocked ? 1 : 0), baseUnit / pip0,
                                     (hitOK ? 1 : 0));
        bool logSeen = false;
        int logSlot = -1;
        for(int lq = 0; lq < 8; lq++)
        {
            if(s_th3LogPat[lq] == mainObjName)
            {
                logSlot = lq;
                if(s_th3LogKey[lq] == logKey) logSeen = true;
                break;
            }
        }
        if(!logSeen)
        {
            if(logSlot < 0) { logSlot = s_th3LogPos % 8; s_th3LogPos++; }
            s_th3LogPat[logSlot] = mainObjName;
            s_th3LogKey[logSlot] = logKey;
            string logLine = StringFormat(
                "TH3LOG pat=%s chart=%d st=%d R=%.1f closed=%.1f K=%.2f rung=%.1f owner=%s q=%s pb=%.1f synth=%.1f macro=%d lock=%d step=%.1f proof=%d deep=%.2f",
                mainObjName, Period(), (long)TimeCurrent(), pbRaw / pip0,
                (closedOK ? closedStep / pip0 : 0.0),
                (closedOK ? closedK : 0.0), seedRung / pip0,
                TH3TfName(ownerTF), logQ, pbStep / pip0,
                (baseUnit / pip0),
                0, (stepLocked ? 1 : 0),
                baseUnit / pip0, (hitOK ? 1 : 0), hitProof.deepestRungs);
            Print(logLine);
            TH3LogFileAppend(logLine);
        }
    }
    
    double pipSize = GetCachedPipSize();
    
    // DYNAMIC OFFSET: Calculate based on candle size for better positioning
    // Offset                          
    double labelOffset;
    
    if(inpABCDLabelOffsetPercent > 0) {
        // User-defined offset percentage (P-TH3-PERF-01: cached per bar)
        double avgCandleSize = TH3AvgCandleSize();
        
        // Use user-defined percentage of average candle size
        labelOffset = avgCandleSize * (inpABCDLabelOffsetPercent / 100.0);
        
        // Minimum offset: 3 pips (prevent labels too close)
        double minOffset = 3.0 * pipSize;
        if(labelOffset < minOffset) labelOffset = minOffset;
        
        // Maximum offset: 100 pips (prevent labels too far)
        double maxOffset = 100.0 * pipSize;
        if(labelOffset > maxOffset) labelOffset = maxOffset;
    } else {
        // Auto mode: Use fixed 15 pips (legacy behavior)
        labelOffset = 15.0 * pipSize;
    }

#ifdef BIOTAK_RENDER_ENGINE
    if(rbr)
    {
        // R-RENDER-ENGINE phase A: the family that moved to the canvas leaves
        // its objects behind ONCE. The sweep runs inside this draw, so
        // g_th3OwnDeleteMs (stamped at the tail) and the delete-token shim both
        // cover it - the queued OBJECT_DELETEs die in CompatConsumeObjEvent
        // before any handler could read them as a user delete. The kept names:
        // `_Point_*` (the drag anchors, objects on purpose) and `_Info*` (the
        // caption family, objects until phase A2). Static per instance: after
        // this pass the chart carries no legacy member of any pattern.
        static bool s_rbrPatSwept=false;
        if(!s_rbrPatSwept)
        {
            s_rbrPatSwept=true;
            for(int sk=ObjectsTotal(0,-1,-1)-1; sk>=0; sk--)
            {
                string sn=ObjectName(0,sk,-1,-1);
                if(TH3FamilyBaseOf(sn)=="") continue;
                if(StringFind(sn,"_Point_")>=0) continue;
                if(StringFind(sn,"_Info")>=0) continue;
                ObjectDelete(0,sn);
            }
        }
        RBridgePatternBegin(mainObjName);
    }
#endif
    
    // Cleanup any lingering legacy X objects (retired; guard to avoid no-op API calls)
    // P-PERF-RET1 (2026-10-12): these objects were removed in P-TH3-D4h/P-TH3-DEL1.
    // After one redraw they are gone; subsequent unconditional deletes are silent
    // API round-trips that cost nothing but accumulate to thousands per session.
    if(ObjectFind(0, mainObjName + "_Point_X") >= 0) ObjectDelete(0, mainObjName + "_Point_X");
    if(ObjectFind(0, mainObjName + "_Label_X") >= 0) ObjectDelete(0, mainObjName + "_Label_X");
    if(ObjectFind(0, mainObjName + "_Line_XA") >= 0) ObjectDelete(0, mainObjName + "_Line_XA");

    // Draw points A, B, C, D with smart label positioning
    string pointNames[4];
    pointNames[0] = "A";
    pointNames[1] = "B";
    pointNames[2] = "C";
    pointNames[3] = "D";
    
    datetime pointTimes[4];
    pointTimes[0] = tA;
    pointTimes[1] = tB;
    pointTimes[2] = tC;
    pointTimes[3] = tD;
    
    double pointPrices[4];
    pointPrices[0] = pA;
    pointPrices[1] = pB;
    pointPrices[2] = pC;
    pointPrices[3] = pD;
    
    // Draw visible drag points for A, B, C, D (small circles with smart positioning)
    for(int i = 0; i < 4; i++) {
        string pointName = mainObjName + "_Point_" + pointNames[i];
        
        // SMART POSITIONING: Place point above/below candle based on price level
        //                     /              
        int barIndex = iBarShift(NULL, 0, pointTimes[i]);
        double pointPrice = pointPrices[i];
        
        if(barIndex >= 0) {
            double high = iHigh(NULL, 0, barIndex);
            double low = iLow(NULL, 0, barIndex);
            double mid = (high + low) / 2.0;
            
            // Determine if point is at top or bottom of candle
            //                         
            bool isAtTop = (pointPrice >= mid);
            
            // Offset point slightly outside candle for visibility
            //                           
            double offset = (high - low) * 0.15; // 15% of candle range
            double minOffset = pipSize * 10;  // Minimum 10 pips
            if(offset < minOffset) offset = minOffset; // Minimum offset
            
            if(isAtTop) {
                // Point at top - place above high
                pointPrice = high + offset;
            } else {
                // Point at bottom - place below low
                pointPrice = low - offset;
            }
        }
        
        // OPTIMIZED: Use small circle (ARROWCODE 159) - visible and draggable
        //             -          
        if(ObjectFind(0, pointName) < 0) {
            if(!ObjectCreate(0, pointName, OBJ_ARROW, 0, pointTimes[i], pointPrices[i])) {
                #ifdef ENABLE_DEBUG_LOGS
                Print("==================== Failed to create point ", pointNames[i], " | Error: ", GetLastError());
                #endif
            } else {
                #ifdef ENABLE_DEBUG_LOGS
                Print("==================== Created point ", pointNames[i], " at ", TimeToString(pointTimes[i]), " @ ", DoubleToString(pointPrices[i], Digits));
                #endif
            }
            
            // CRITICAL: Visible circle with smart positioning
            // P-UI-97: every ink in this file goes through TH3InkForChart, so a light
            // chart gets the same hues at a readable lightness (and a dark chart is
            // untouched). A raw input written straight into OBJPROP_COLOR is how a
            // gold/lime pattern ended up unreadable on white paper.
            ObjectSetInteger(0, pointName, OBJPROP_COLOR, TH3InkForChart(inpABCDPointColor));
            ObjectSetInteger(0, pointName, OBJPROP_ARROWCODE, 159); // Small filled circle
            ObjectSetInteger(0, pointName, OBJPROP_WIDTH, 3); // Medium size for easy clicking
            ObjectSetInteger(0, pointName, OBJPROP_SELECTABLE, true);
            ObjectSetInteger(0, pointName, OBJPROP_SELECTED, false);
            ObjectSetInteger(0, pointName, OBJPROP_BACK, false); // Draw on top
            ObjectSetInteger(0, pointName, OBJPROP_ZORDER, Z_CHART_TOOL); // P-UI-31: over the level lines, under every label
            ObjectSetString(0, pointName, OBJPROP_TOOLTIP, "==================== Point " + pointNames[i] + " | Drag to adjust");
        } else {
            // Update existing point position
            ObjectMove(0, pointName, 0, pointTimes[i], pointPrices[i]);
            #ifdef ENABLE_DEBUG_LOGS
            Print("==================== Updated existing point ", pointNames[i]);
            #endif
        }
        // P-DRAW-122 (2026-10-01) — A PAINTED LAYER IS RE-ASSERTED EVERY PASS. This
        // point's rung was written inside its birth block only, while the branch above
        // MOVES an object that already exists: an arrow that survived a reattach (or a
        // pattern redrawn onto objects the terminal still held) kept the rung of the
        // instance that born it, and `Z_CHART_TOOL` is exactly "over the level lines,
        // under every label" — lose it and the point paints under the lines it marks.
        // Same law as the strip's own painters (DrawStrip_GearB/Paint/Skin); compare-
        // guarded, so a still frame writes nothing.
        if((long)ObjectGetInteger(0, pointName, OBJPROP_ZORDER) != Z_CHART_TOOL ||
           (long)ObjectGetInteger(0, pointName, OBJPROP_BACK) != 0)
        {
            ObjectSetInteger(0, pointName, OBJPROP_BACK, false);
            ObjectSetInteger(0, pointName, OBJPROP_ZORDER, Z_CHART_TOOL);
        }
        
        // Smart label positioning relative to candle High/Low
        //                   High/Low    
        // TH3TOOL-ON (2026-09-19): the card's SHOW LABELS row is honored here too
        // (two owners, one gate): the tool's own switch AND the AB=CD input.
        if(inpABCDShowLabels && g_showTH3Labels) {
            string labelName = mainObjName + "_Label_" + pointNames[i];
            double labelPrice = pointPrices[i];
            ENUM_ANCHOR_POINT anchor = ANCHOR_CENTER;
            
            // Get candle High/Low for this point
            int labelBarIndex = iBarShift(NULL, 0, pointTimes[i]);
            double candleHigh = (labelBarIndex >= 0) ? iHigh(NULL, 0, labelBarIndex) : pointPrices[i];
            double candleLow = (labelBarIndex >= 0) ? iLow(NULL, 0, labelBarIndex) : pointPrices[i];
            
            // Position label relative to candle High/Low (not point price)
            //              High/Low     (         
            if(i == 0 || i == 2) { // A or C (swing lows in bullish, swing highs in bearish)
                if(isBullish) {
                    // A/C are lows - place label below candle low
                    labelPrice = candleLow - labelOffset;
                    anchor = ANCHOR_UPPER;
                } else {
                    // A/C are highs - place label above candle high
                    labelPrice = candleHigh + labelOffset;
                    anchor = ANCHOR_LOWER;
                }
            } else { // B or D (swing highs in bullish, swing lows in bearish)
                if(isBullish) {
                    // B/D are highs - place label above candle high
                    labelPrice = candleHigh + labelOffset;
                    anchor = ANCHOR_LOWER;
                } else {
                    // B/D are lows - place label below candle low
                    labelPrice = candleLow - labelOffset;
                    anchor = ANCHOR_UPPER;
                }
            }

#ifdef BIOTAK_RENDER_ENGINE
            if(rbr)
                RBridgePatternText(labelName, (long)pointTimes[i], labelPrice,
                                   pointNames[i], TH3SessionPointInk(), 10,
                                   (int)RBrAnchorCanvas((int)anchor),
                                   RBrFaceFlags(BioChromeFont()), BioChromeFont());
            if(!rbr)
#endif
            if(ObjectFind(0, labelName) < 0) {
                if(!ObjectCreate(0, labelName, OBJ_TEXT, 0, pointTimes[i], labelPrice)) {
                    #ifdef ENABLE_DEBUG_LOGS
                    Print("==================== Failed to create label ", pointNames[i], " | Error: ", GetLastError());
                    #endif
                } else {
                    #ifdef ENABLE_DEBUG_LOGS
                    Print("==================== Created label ", pointNames[i]);
                    #endif
                }
                ObjectSetString(0, labelName, OBJPROP_TEXT, pointNames[i]);
                ObjectSetInteger(0, labelName, OBJPROP_COLOR, TH3SessionPointInk());
                ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
                ObjectSetString(0, labelName, OBJPROP_FONT, BioChromeFont());
                ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, anchor);
                ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
            } else {
                ObjectMove(0, labelName, 0, pointTimes[i], labelPrice);
                ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, anchor);
                #ifdef ENABLE_DEBUG_LOGS
                Print("==================== Updated existing label ", pointNames[i]);
                #endif
            }
        }
    }
    
    // Draw line AB (solid)
    string lineAB = mainObjName + "_Line_AB";
#ifdef BIOTAK_RENDER_ENGINE
    if(rbr)
        RBridgePatternSeg(lineAB, (long)tA, pA, (long)tB, pB,
                          TH3SessionLineInk(), (int)g_th3Style, g_th3Width);
    if(!rbr)
#endif
    if(ObjectFind(0, lineAB) < 0) {
        if(!ObjectCreate(0, lineAB, OBJ_TREND, 0, tA, pA, tB, pB)) {
            #ifdef ENABLE_DEBUG_LOGS
            Print("==================== Failed to create Line AB | Error: ", GetLastError());
            #endif
        } else {
            #ifdef ENABLE_DEBUG_LOGS
            Print("==================== Created Line AB");
            #endif
        }
        // TH3TOOL-ON (2026-09-19): the card's own LOOK rows are honored here —
        // COLOR / WIDTH / STYLE (and PIP COLOR on the info text) were the tool's
        // own settings. Without these readers the three rows could only move
        // their own switch (P-UI-46's shape; probe-budget's live-control caught
        // exactly that). The AB=CD inputs stay the FALLBACK when the tool's own
        // colour is clrNONE (its shipped default).
        ObjectSetInteger(0, lineAB, OBJPROP_COLOR, TH3SessionLineInk());
        ObjectSetInteger(0, lineAB, OBJPROP_WIDTH, g_th3Width);
        ObjectSetInteger(0, lineAB, OBJPROP_STYLE, g_th3Style);
        ObjectSetInteger(0, lineAB, OBJPROP_RAY_RIGHT, false);
        ObjectSetInteger(0, lineAB, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, lineAB, OBJPROP_BACK, false);
    } else {
        ObjectMove(0, lineAB, 0, tA, pA);
        ObjectMove(0, lineAB, 1, tB, pB);
        // P-TH3-PERF-02 (2026-09-19) — a panel LOOK edit lands HERE, without
        // recreating the object — and only when it actually changed. MT4
        // repaints on every ObjectSet*, so the read-then-write guard is what
        // keeps a drag/repaint loop from paying for three writes per frame
        // (the project's perf law: never write a chart property you would not
        // change). Without this the WIDTH/STYLE/COLOR rows had a reader but no
        // re-apply path, so an edit only showed up after the object was gone.
        color wantClr = TH3SessionLineInk();   // P-UI-97: the same resolved ink as the create path
        if((color)ObjectGetInteger(0, lineAB, OBJPROP_COLOR) != wantClr)
            ObjectSetInteger(0, lineAB, OBJPROP_COLOR, wantClr);
        if((int)ObjectGetInteger(0, lineAB, OBJPROP_WIDTH) != g_th3Width)
            ObjectSetInteger(0, lineAB, OBJPROP_WIDTH, g_th3Width);
        if((int)ObjectGetInteger(0, lineAB, OBJPROP_STYLE) != (int)g_th3Style)
            ObjectSetInteger(0, lineAB, OBJPROP_STYLE, g_th3Style);
    }
    
    // Draw line BC (dotted)
    string lineBC = mainObjName + "_Line_BC";
#ifdef BIOTAK_RENDER_ENGINE
    if(rbr)
        RBridgePatternSeg(lineBC, (long)tB, pB, (long)tC, pC,
                          TH3InkForChart(clrGray), (int)STYLE_DOT, 1);
    if(!rbr)
#endif
    if(ObjectFind(0, lineBC) < 0) {
        if(!ObjectCreate(0, lineBC, OBJ_TREND, 0, tB, pB, tC, pC)) {
            #ifdef ENABLE_DEBUG_LOGS
            Print("==================== Failed to create Line BC | Error: ", GetLastError());
            #endif
        } else {
            #ifdef ENABLE_DEBUG_LOGS
            Print("==================== Created Line BC");
            #endif
        }
        ObjectSetInteger(0, lineBC, OBJPROP_COLOR, TH3InkForChart(clrGray));   // P-UI-97: gray 128 is left as it is on either paper
        ObjectSetInteger(0, lineBC, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, lineBC, OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(0, lineBC, OBJPROP_RAY_RIGHT, false);
        ObjectSetInteger(0, lineBC, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, lineBC, OBJPROP_BACK, true);
    } else {
        ObjectMove(0, lineBC, 0, tB, pB);
        ObjectMove(0, lineBC, 1, tC, pC);
    }

    // P-TH3-D4 (2026-09-20) — THE CD LEG DRAWS. Clicks are A/B/C/D, so the
    // C->D leg is user-placed ink like AB (same width/style/ink), not a
    // computed projection. Without it D floated with no leg into it.
    string lineCD = mainObjName + "_Line_CD";
#ifdef BIOTAK_RENDER_ENGINE
    if(rbr)
        RBridgePatternSeg(lineCD, (long)tC, pC, (long)tD, pD,
                          TH3SessionLineInk(), (int)g_th3Style, g_th3Width);
    if(!rbr)
#endif
    if(ObjectFind(0, lineCD) < 0) {
        if(!ObjectCreate(0, lineCD, OBJ_TREND, 0, tC, pC, tD, pD)) {
            #ifdef ENABLE_DEBUG_LOGS
            Print("==================== Failed to create Line CD | Error: ", GetLastError());
            #endif
        } else {
            #ifdef ENABLE_DEBUG_LOGS
            Print("==================== Created Line CD");
            #endif
        }
        ObjectSetInteger(0, lineCD, OBJPROP_COLOR, TH3SessionLineInk());
        ObjectSetInteger(0, lineCD, OBJPROP_WIDTH, g_th3Width);
        ObjectSetInteger(0, lineCD, OBJPROP_STYLE, g_th3Style);
        ObjectSetInteger(0, lineCD, OBJPROP_RAY_RIGHT, false);
        ObjectSetInteger(0, lineCD, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, lineCD, OBJPROP_BACK, false);
    } else {
        ObjectMove(0, lineCD, 0, tC, pC);
        ObjectMove(0, lineCD, 1, tD, pD);
        color wantCD = TH3SessionLineInk();   // P-TH3-PERF-02: read-then-write like Line_AB
        if((color)ObjectGetInteger(0, lineCD, OBJPROP_COLOR) != wantCD)
            ObjectSetInteger(0, lineCD, OBJPROP_COLOR, wantCD);
        if((int)ObjectGetInteger(0, lineCD, OBJPROP_WIDTH) != g_th3Width)
            ObjectSetInteger(0, lineCD, OBJPROP_WIDTH, g_th3Width);
        if((int)ObjectGetInteger(0, lineCD, OBJPROP_STYLE) != (int)g_th3Style)
            ObjectSetInteger(0, lineCD, OBJPROP_STYLE, g_th3Style);
    }

    // P-TH3-D4h (2026-09-21, user: «خط های بنفش که از سر نقاط به عقب کشیده شده
    // رو حذف کن»): the two magenta level lines are RETIRED — _Ray_D (D's price
    // rayed LEFT into the past) and _Ray_C (C's price, B->C). The names survive
    // only as a retired sweep: a pattern drawn by an older build carries them,
    // and its next redraw deletes them. Never create them again.
    // P-PERF-RET2 (2026-10-12): guarded so the API call only happens when the
    // object is actually there (after one cycle they are gone on every live chart).
    if(ObjectFind(0, mainObjName + "_Ray_D") >= 0) ObjectDelete(0, mainObjName + "_Ray_D");
    if(ObjectFind(0, mainObjName + "_Ray_C") >= 0) ObjectDelete(0, mainObjName + "_Ray_C");

    // P-TH3-D4f — CD LEG LABEL. A small text at the midpoint of CD showing
    // only the ownerTF name (e.g. "H1") so the trader reads which timeframe
    // owns the leg without needing the full caption.
    {
        string cdLbl = mainObjName + "_CDLabel";
        datetime tCD_mid = tC + (tD - tC) / 2;
        double   pCD_mid = (pC + pD) / 2.0;
        string   cdLblText = TH3TfName(ownerTF);
#ifdef BIOTAK_RENDER_ENGINE
        if(rbr)
            RBridgePatternText(cdLbl, (long)tCD_mid, pCD_mid, cdLblText,
                               clrMagenta, 9, (int)RBrAnchorCanvas((int)ANCHOR_CENTER),
                               RBrFaceFlags(BioChromeFont()), BioChromeFont());
        if(!rbr)
#endif
        if(ObjectFind(0, cdLbl) < 0) {
            if(ObjectCreate(0, cdLbl, OBJ_TEXT, 0, tCD_mid, pCD_mid)) {
                ObjectSetString( 0, cdLbl, OBJPROP_TEXT,      cdLblText);
                ObjectSetString( 0, cdLbl, OBJPROP_FONT,      BioChromeFont());
                ObjectSetInteger(0, cdLbl, OBJPROP_FONTSIZE,  9);
                ObjectSetInteger(0, cdLbl, OBJPROP_COLOR,     clrMagenta);
                ObjectSetInteger(0, cdLbl, OBJPROP_ANCHOR,    ANCHOR_CENTER);
                ObjectSetInteger(0, cdLbl, OBJPROP_SELECTABLE,false);
                ObjectSetInteger(0, cdLbl, OBJPROP_BACK,      false);
            }
        } else {
            ObjectMove(0, cdLbl, 0, tCD_mid, pCD_mid);
            if(ObjectGetString(0, cdLbl, OBJPROP_TEXT) != cdLblText)
                ObjectSetString(0, cdLbl, OBJPROP_TEXT, cdLblText);
        }
    }

    // P-TH3-D4f — MOTHER LEG MARKER (v12).
    // Two-pass approach (no running-opposite ambiguity):
    //
    // Pass 1 — find the END bar of the mother leg:
    //   The mother leg ends at the local extreme NEAREST to pA in the CD
    //   direction, BEFORE barA, with |extreme - pA| <= 1 ATR.
    //   We take the CLOSEST (smallest distance) such bar.
    //
    // Pass 2 — find the START bar of the mother leg:
    //   From the END bar, walk further back and find the HIGHEST high
    //   (bearish) or LOWEST low (bullish) — that is the mother start.
    //   No distance gate; just the global max/min before the end bar.
    //
        // Size check: mother leg must be >= CD * 0.80. mlMotherSize feeds the
        // caption's 1/3M row, so the measure stays even though its ticks are gone
        // (P-TH3-D4h).
    double mlMotherSize = 0;
    double mlRatio      = 0;
    {
        int    barA      = iBarShift(NULL, 0, tA);
        int    lookback  = MathMin(500, iBars(NULL, 0) - 1);
        double atrWindow = TH3PatternStepRung();
        if(atrWindow <= 0) atrWindow = CD_Distance;

        // --- Pass 1: END bar = bar with extreme closest to pA before barA ---
        int    bestEndBar  = -1;
        double bestEndDist = 1e9;
        for(int k = barA + 1; k <= lookback; k++)
        {
            double ext  = dirDown ? iLow(NULL, 0, k) : iHigh(NULL, 0, k);
            double dist = MathAbs(ext - pA);
            if(dist <= atrWindow && dist < bestEndDist)
            {
                bestEndDist = dist;
                bestEndBar  = k;
            }
        }

        // --- Pass 2: START bar = global opposite extreme before END bar ---
        int    bestStartBar = -1;
        double bestStartVal = dirDown ? -1e9 : 1e9;
        if(bestEndBar >= 0)
        {
            for(int k = bestEndBar + 1; k <= lookback; k++)
            {
                double ext = dirDown ? iHigh(NULL, 0, k) : iLow(NULL, 0, k);
                if(dirDown ? (ext > bestStartVal) : (ext < bestStartVal))
                {
                    bestStartVal = ext;
                    bestStartBar = k;
                }
            }
        }

        // Size check
        if(bestEndBar >= 0 && bestStartBar >= 0)
        {
            double endExt   = dirDown ? iLow (NULL,0,bestEndBar)
                                      : iHigh(NULL,0,bestEndBar);
            mlMotherSize = MathAbs(bestStartVal - endExt);
        }

        // P-TH3-D4h (2026-09-21, user: «تیک های مادر»): the mother-leg ticks are
        // RETIRED — _MPTick (start) and _MPTickB (end), lime/red width-3. The
        // measurement above STAYS (mlMotherSize feeds the caption); only the two
        // objects go, swept here so an older build's ticks die on redraw. Never
        // create them again.
        // P-PERF-RET3 (2026-10-12): guarded; after one redraw these are gone on
        // every live chart and the unconditional delete just wastes an API call.
        if(ObjectFind(0, mainObjName + "_MPTick")  >= 0) ObjectDelete(0, mainObjName + "_MPTick");
        if(ObjectFind(0, mainObjName + "_MPTickB") >= 0) ObjectDelete(0, mainObjName + "_MPTickB");
    }

    // Draw TH3-style targets (Step1, Step3, Step5, Step7) from D (P-TH3-D4)
    string targetNames[4] = {"Step1", "Step3", "Step5", "Step7"};
    // P-TH3-STEP-16 (§3): the ODD rungs carry the spec's own inks — Step 1 plain
    // (dodger blue), Step 3 the primary target in ORANGE, Step 5 the macro
    // milestone in GREEN, Step 7 the exhaustion level in BROWN. Brown replaces
    // the old gold: gold and lime green are both near-invisible on white paper
    // (P-UI-97's reason for TH3InkForChart), so an exhaustion level nobody can
    // see is not a level. Every hue still goes through TH3InkForChart below.
    color targetColors[4] = {clrDodgerBlue, clrOrangeRed, clrLimeGreen, clrBrown};
    double targetLevels[4];
    
    // P-TH3-D4 (2026-09-20) — THE LADDER PROJECTS FROM THE PLACED D.
    // The 4th click IS D (tD,pD): Step1 sits exactly one step past D
    // (pD +/- 1.0*step), Step3/5/7 at 3/5/7 steps. No RealD walk shifts
    // the origin: the 83.1-vs-39.7 gap was that walk moving the base 68
    // bars into the future while the caption still read the seed step.
    if(isBullish) {
        targetLevels[0] = pD + (1.0 * baseUnit);
        targetLevels[1] = pD + (3.0 * baseUnit);
        targetLevels[2] = pD + (5.0 * baseUnit);
        targetLevels[3] = pD + (7.0 * baseUnit);
    } else {
        targetLevels[0] = pD - (1.0 * baseUnit);
        targetLevels[1] = pD - (3.0 * baseUnit);
        targetLevels[2] = pD - (5.0 * baseUnit);
        targetLevels[3] = pD - (7.0 * baseUnit);
    }
    
    double targetPips[4];
    for(int i = 0; i < 4; i++) {
        targetPips[i] = MathAbs(baseUnit * (i*2 + 1)) / pipSize;
    }

    // P-TH3-DISC: the EVEN rungs (2/4/6) ride WITH the ladder, another ink.
    double midLevels[3];
    double midPips[3];
    ArrayInitialize(midLevels, 0.0);
    ArrayInitialize(midPips, 0.0);
    for(int mi = 0; mi < 3; mi++) {
        int mStep = 2 * (mi + 1);
        midLevels[mi] = isBullish ? pD + (mStep * baseUnit) : pD - (mStep * baseUnit);
        midPips[mi] = MathAbs(baseUnit * mStep) / pipSize;
    }
    
    datetime startTime = tD;   // P-TH3-D4: the ladder starts at the placed D
    // P-TH3-ZONE-03 (2026-10-05) — THE BANDS TRADE FORWARD. The boxes ended
    // 100 bars BEHIND D (history side) while the lines ray right into the
    // trade: every zone stood 4/4 in the census yet none painted beside its
    // line. Rectangles cannot ray, so the end anchors 100 bars past the
    // CURRENT bar — the bands now ride under the lines where price goes.
    // (The fibo lines share these times; their RAY_RIGHT makes the end
    // anchor irrelevant to them, so their look does not move.)
    // P-TH3-ZONE-05: the anchor is a CONSTANT, not «now + 100 bars». Sliding
    // it on every tick made each pass rewrite both anchors of every zone for a
    // picture that is visually identical — the band only appears to move when
    // a new bar closes, and 100 bars ahead of D already covers the trade. It
    // is derived from D (which only changes when the user drags a point) so a
    // still chart costs nothing here.
    datetime endTime = tD + (100 * CompatPeriodSeconds());
    // P-TH3-ZONE-04: the style family the zones on the chart were BORN in. A
    // -1 first pass means «nothing on the chart yet», so the first frame builds
    // without a sweep; after that the sweep runs only when the user changes the
    // style, which is the ONLY event that must re-order paint (P-LOG-10: MT4
    // paints in creation order, so a style flip needs a re-birth, a step change
    // does not).
    static int s_zoneStyleFamily = -1;
    
    // GOLD VERSION: Use configurable zone height from input parameter
    // Convert from percentage (1-100) to decimal (0.01-1.0)
    double zoneHeightPercent = inpTH3ZoneHeightPercent / 100.0;
    
    // Validate and clamp
    if(zoneHeightPercent < 0.01) zoneHeightPercent = 0.01;
    if(zoneHeightPercent > 1.0) zoneHeightPercent = 1.0;
    
    // P-TH3-ZONE-01 (2026-09-19) — THE PERCENT IS THE WHOLE BAND, NOT ITS HALF.
    // The line read `baseUnit * zoneHeightPercent`, so a 33% input drew a band of
    // 2 x 33% = 66% of the step while every other zone family in this project
    // reads the SAME input as the FULL height: `UnifiedZoneSystem`/`LevelPipeline`
    // build `zoneHeight = stepSize * heightPercent * 0.5` (their comment: "0.5
    // because height"), i.e. `heightPercent == 1.0` is the boundary case of one
    // whole step. The label below printed the full height in pips, so label and
    // band disagreed by exactly 2x — the user's «بازه رو اشتباه میندازه»: he set
    // 33% and the chart threw a band twice that. Now the drawn band IS the
    // percentage of the step, both halves come from one number, and the label
    // states the height it draws.
    double zoneHalfWidth = baseUnit * zoneHeightPercent * 0.5;
    // P-TH3-ZONE-04: how many zone objects this pass BUILT. The census below
    // prints it, so a report can tell «drawn once» from «rebuilt every tick».
    int zoneBornThisPass = 0;
    
    for(int i = 0; i < 4; i++) {
        string lineName = mainObjName + "_Target_" + IntegerToString(i+1);
        double centerPrice = targetLevels[i];
        double upperZone = centerPrice + zoneHalfWidth;
        double lowerZone = centerPrice - zoneHalfWidth;
        // P-UI-97: the ladder's four hues (dodger blue / orange red / lime green / gold)
        // are a palette, not a promise — gold and lime green are invisible on white, so
        // the ink is resolved BEFORE the transparency blend that mixes it with the paper.
        color zoneColor = TH3InkForChart((inpTH3ZoneColor == clrNONE) ? targetColors[i] : inpTH3ZoneColor);
        color targetInk = TH3InkForChart(targetColors[i]);
        // Apply the zone transparency to the box/border color (blend with background)
        zoneColor = GetZoneRenderColor(zoneColor, inpTH3ZoneTransparency);

        // R-RENDER-ENGINE: the rung as a canvas stroke, its LEVELTEXT as a
        // right-edge label (the object path's text rides the fibo line's right
        // end — RAY_RIGHT makes that the right EDGE, hence the sentinel; a
        // non-rayed line keeps its text at the end time, off-chart like the
        // object's usually is). Masked with the ladder (P-TH3-P6f): `_Target_`
        // is a ladder name, so inactive patterns keep no rung and no rung text.
        // The label font is the terminal default an OBJ_FIBO level text uses
        // (Arial 8 at the reference DPI) - no code ever set a font there.
#ifdef BIOTAK_RENDER_ENGINE
        if(rbr)
        {
            RBridgePatternSeg(lineName, (long)startTime, centerPrice, (long)endTime, centerPrice,
                              targetInk, (int)STYLE_SOLID, 2, inpABCDExtendCD, isActive);
            if(inpTH3LabelPosition != TH3_LABEL_HIDDEN)
            {
                double zonePips = (zoneHalfWidth * 2.0) / pipSize;
                string labelText = StringFormat("%s (%.1f) ========%.1f", targetNames[i], targetPips[i], zonePips);
                if(inpABCDExtendCD)
                    RBridgePatternText(lineName + "_Text", 0, centerPrice, labelText,
                                       targetInk, 8, (int)(TA_RIGHT|TA_VCENTER), 0, "Arial", isActive);
                else
                    RBridgePatternText(lineName + "_Text", (long)endTime, centerPrice, labelText,
                                       targetInk, 8, (int)(TA_RIGHT|TA_VCENTER), 0, "Arial", isActive);
            }
        }
        if(!rbr)
#endif
        if(ObjectFind(0, lineName) < 0) {
            if(ObjectCreate(0, lineName, OBJ_FIBO, 0, startTime, centerPrice, endTime, centerPrice)) {
                ObjectSetInteger(0, lineName, OBJPROP_COLOR, targetInk);
                ObjectSetInteger(0, lineName, OBJPROP_LEVELCOLOR, targetInk);
                ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
                ObjectSetInteger(0, lineName, OBJPROP_LEVELWIDTH, 2);
                ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, inpABCDExtendCD);
                ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
                ObjectSetInteger(0, lineName, OBJPROP_LEVELS, 1);
                ObjectSetDouble(0, lineName, OBJPROP_LEVELVALUE, 0, 0.0);

                if(inpTH3LabelPosition != TH3_LABEL_HIDDEN) {
                    // P-TH3-ZONE-01: the number is the band's FULL height in pips (what
                    // is drawn), and the separator is short enough that it stays INSIDE
                    // the plot — 20 dashes ran the text past the right edge and cut the
                    // height off the chart entirely.
                    double zonePips = (zoneHalfWidth * 2.0) / pipSize;
                    string labelText = StringFormat("%s (%.1f) ========%.1f", targetNames[i], targetPips[i], zonePips);
                    ObjectSetString(0, lineName, OBJPROP_LEVELTEXT, 0, labelText);
                }
            }
        } else {
            // Update position AND label text when frequency/step changes
            ObjectMove(0, lineName, 0, startTime, centerPrice);
            ObjectMove(0, lineName, 1, endTime, centerPrice);
            
            // Update label text with new pip values (P-TH3-ZONE-01: full height)
            // P-PERF-ZB4 (2026-10-12): guard the string write — ObjectSetString*
            // triggers a repaint; the text only changes when targetPips or
            // zoneHalfWidth moves (point drag), not on every tick.
            if(inpTH3LabelPosition != TH3_LABEL_HIDDEN) {
                double zonePips = (zoneHalfWidth * 2.0) / pipSize;
                string labelText = StringFormat("%s (%.1f) ========%.1f", targetNames[i], targetPips[i], zonePips);
                if(ObjectGetString(0, lineName, OBJPROP_LEVELTEXT, 0) != labelText)
                    ObjectSetString(0, lineName, OBJPROP_LEVELTEXT, 0, labelText);
            }
        }
        
        // Zone objects: BOX styles -> rectangle; HIDDEN -> nothing
        string zoneUpperName = mainObjName + "_ZoneUpper_" + IntegerToString(i+1);
        string zoneLowerName = mainObjName + "_ZoneLower_" + IntegerToString(i+1);
        string zoneBoxName = mainObjName + "_Zone_" + IntegerToString(i+1);

        // P-UI-62: the "hidden" style is retired - visibility is the zone master
        // switch's question, and slot 2 of ENUM_ZONE_STYLE is now OUTLINED. (This
        // module is not included by any build - see ARCHITECTURE.md's retired-modules
        // note - so the edit is here only to keep the names honest for a revival.)
        if(inpTH3ZoneStyle == TH3_ZONE_BOX_EMPTY) {
            // EMPTY BOX: hollow outline drawn as border segments. Works on
            // every MT4 build - OBJ_RECTANGLE with FILL=false is unreliable.
            // P-TH3-ZONE-04 (2026-10-05) — CREATE ONCE, THEN ONLY MOVE. The old
            // branch deleted all three borders and rebuilt them on EVERY pass:
            // three deletes + three creates per rung per frame, for a picture
            // that only ever changes when the step moves. That cost is why the
            // zone «رسم میشه ولی بعد حذف میشه» — MT4 paints in CREATION order
            // (P-LOG-10), so a border re-born every frame lands UNDER the line
            // family and the frame that survives is the last one's. The sweep
            // below now runs only on a STYLE CHANGE, which is the one event
            // that must re-order paint.
            string topBorder = zoneBoxName + "_B_Top";
            string bottomBorder = zoneBoxName + "_B_Bottom";
            string leftBorder = zoneBoxName + "_B_Left";

            // P-MT5-PARITY (2026-10-21) - R-RENDER-ENGINE: THE EMPTY OUTLINE'S THREE STROKES ARE OBJECTS IN
            // EVERY BUILD. MT4 draws them as OBJ_TREND with OBJPROP_BACK=true -
            // BEHIND the candles - and the `_B_Left` vertical is the outline's
            // closing edge. The canvas groups the whole pattern family on its
            // FRONT layer (above the candles) and has no slot for one stroke
            // behind them, so these three stay objects: three small objects per
            // pattern, not one per level, and the pattern delete path's prefix
            // sweep already takes them with the family. The FILLED family below
            // keeps its rectangle as an object too - MT4's filled band is ONE
            // rectangle whose fill AND border are both in front of the candles.
            {
            if(s_zoneStyleFamily != (int)inpTH3ZoneStyle) {
                if(ObjectFind(0, zoneUpperName) >= 0) ObjectDelete(0, zoneUpperName);
                if(ObjectFind(0, zoneLowerName) >= 0) ObjectDelete(0, zoneLowerName);
                if(ObjectFind(0, zoneBoxName) >= 0) ObjectDelete(0, zoneBoxName);
                if(ObjectFind(0, topBorder) >= 0) ObjectDelete(0, topBorder);
                if(ObjectFind(0, bottomBorder) >= 0) ObjectDelete(0, bottomBorder);
                if(ObjectFind(0, leftBorder) >= 0) ObjectDelete(0, leftBorder);
            }

            // Top border (extends right, matching the filled box)
            if(ObjectFind(0, topBorder) < 0) {
                if(ObjectCreate(0, topBorder, OBJ_TREND, 0, startTime, upperZone, endTime, upperZone)) {
                    zoneBornThisPass++;
                    ObjectSetInteger(0, topBorder, OBJPROP_COLOR, zoneColor);
                    ObjectSetInteger(0, topBorder, OBJPROP_STYLE, inpTH3ZoneBorderStyle);
                    ObjectSetInteger(0, topBorder, OBJPROP_WIDTH, inpTH3ZoneBorderWidth);
                    ObjectSetInteger(0, topBorder, OBJPROP_RAY_RIGHT, inpABCDExtendCD);
                    ObjectSetInteger(0, topBorder, OBJPROP_SELECTABLE, false);
                    ObjectSetInteger(0, topBorder, OBJPROP_BACK, true);
                }
            } else {
                // P-PERF-ZB1 (2026-10-12): guard all visual-property writes on the
                // update path — MT5/MT4 repaints on every ObjectSet*, so these three
                // unconditional writes per border per rung per frame accumulated to
                // ~18 forced repaints per drag even when nothing changed.
                ObjectMove(0, topBorder, 0, startTime, upperZone);
                ObjectMove(0, topBorder, 1, endTime, upperZone);
                if((color)ObjectGetInteger(0, topBorder, OBJPROP_COLOR) != zoneColor)
                    ObjectSetInteger(0, topBorder, OBJPROP_COLOR, zoneColor);
                if((int)ObjectGetInteger(0, topBorder, OBJPROP_STYLE) != (int)inpTH3ZoneBorderStyle)
                    ObjectSetInteger(0, topBorder, OBJPROP_STYLE, inpTH3ZoneBorderStyle);
                if((int)ObjectGetInteger(0, topBorder, OBJPROP_WIDTH) != inpTH3ZoneBorderWidth)
                    ObjectSetInteger(0, topBorder, OBJPROP_WIDTH, inpTH3ZoneBorderWidth);
            }

            // Bottom border (extends right, matching the filled box)
            if(ObjectFind(0, bottomBorder) < 0) {
                if(ObjectCreate(0, bottomBorder, OBJ_TREND, 0, startTime, lowerZone, endTime, lowerZone)) {
                    zoneBornThisPass++;
                    ObjectSetInteger(0, bottomBorder, OBJPROP_COLOR, zoneColor);
                    ObjectSetInteger(0, bottomBorder, OBJPROP_STYLE, inpTH3ZoneBorderStyle);
                    ObjectSetInteger(0, bottomBorder, OBJPROP_WIDTH, inpTH3ZoneBorderWidth);
                    ObjectSetInteger(0, bottomBorder, OBJPROP_RAY_RIGHT, inpABCDExtendCD);
                    ObjectSetInteger(0, bottomBorder, OBJPROP_SELECTABLE, false);
                    ObjectSetInteger(0, bottomBorder, OBJPROP_BACK, true);
                }
            } else {
                ObjectMove(0, bottomBorder, 0, startTime, lowerZone);
                ObjectMove(0, bottomBorder, 1, endTime, lowerZone);
                if((color)ObjectGetInteger(0, bottomBorder, OBJPROP_COLOR) != zoneColor)
                    ObjectSetInteger(0, bottomBorder, OBJPROP_COLOR, zoneColor);
                if((int)ObjectGetInteger(0, bottomBorder, OBJPROP_STYLE) != (int)inpTH3ZoneBorderStyle)
                    ObjectSetInteger(0, bottomBorder, OBJPROP_STYLE, inpTH3ZoneBorderStyle);
                if((int)ObjectGetInteger(0, bottomBorder, OBJPROP_WIDTH) != inpTH3ZoneBorderWidth)
                    ObjectSetInteger(0, bottomBorder, OBJPROP_WIDTH, inpTH3ZoneBorderWidth);
            }

            // Left border (vertical - closes the outline)
            if(ObjectFind(0, leftBorder) < 0) {
                if(ObjectCreate(0, leftBorder, OBJ_TREND, 0, startTime, lowerZone, startTime, upperZone)) {
                    zoneBornThisPass++;
                    ObjectSetInteger(0, leftBorder, OBJPROP_COLOR, zoneColor);
                    ObjectSetInteger(0, leftBorder, OBJPROP_STYLE, inpTH3ZoneBorderStyle);
                    ObjectSetInteger(0, leftBorder, OBJPROP_WIDTH, inpTH3ZoneBorderWidth);
                    ObjectSetInteger(0, leftBorder, OBJPROP_RAY_RIGHT, false);
                    ObjectSetInteger(0, leftBorder, OBJPROP_SELECTABLE, false);
                    ObjectSetInteger(0, leftBorder, OBJPROP_BACK, true);
                }
            } else {
                ObjectMove(0, leftBorder, 0, startTime, lowerZone);
                ObjectMove(0, leftBorder, 1, startTime, upperZone);
                if((color)ObjectGetInteger(0, leftBorder, OBJPROP_COLOR) != zoneColor)
                    ObjectSetInteger(0, leftBorder, OBJPROP_COLOR, zoneColor);
                if((int)ObjectGetInteger(0, leftBorder, OBJPROP_STYLE) != (int)inpTH3ZoneBorderStyle)
                    ObjectSetInteger(0, leftBorder, OBJPROP_STYLE, inpTH3ZoneBorderStyle);
                if((int)ObjectGetInteger(0, leftBorder, OBJPROP_WIDTH) != inpTH3ZoneBorderWidth)
                    ObjectSetInteger(0, leftBorder, OBJPROP_WIDTH, inpTH3ZoneBorderWidth);
            }
            }   // the outline's object family - every build
        }
        else {
            // BOX_FILLED: single filled rectangle zone
            // P-TH3-ZONE-04: same law as the branch above — the deletes run on a
            // STYLE change only, never per frame.
            string topBorder = zoneBoxName + "_B_Top";
            string bottomBorder = zoneBoxName + "_B_Bottom";
            string leftBorder = zoneBoxName + "_B_Left";

            // R-RENDER-ENGINE: the band is a time-bounded fill (startTime ->
            // endTime, ray = RAY_RIGHT semantics) plus the three border strokes
            // the rectangle's outline drew. The right edge stroke is skipped -
            // the object's own right border sits at endTime, 100 bars out, so
            // the divergence is at most a hairline on an extreme zoom-out.
            // zoneColor is already the opacity-blended ink (GetZoneRenderColor),
            // so the band covers candles exactly as the BACK=false rectangle did.
#ifdef BIOTAK_RENDER_ENGINE
            if(rbr)
            {
                RBridgePatternBand(zoneBoxName, (long)startTime, (long)endTime,
                                   lowerZone, upperZone, zoneColor, inpABCDExtendCD);
                RBridgePatternSeg(topBorder, (long)startTime, upperZone, (long)endTime, upperZone,
                                  zoneColor, (int)inpTH3ZoneBorderStyle, inpTH3ZoneBorderWidth, inpABCDExtendCD);
                RBridgePatternSeg(bottomBorder, (long)startTime, lowerZone, (long)endTime, lowerZone,
                                  zoneColor, (int)inpTH3ZoneBorderStyle, inpTH3ZoneBorderWidth, inpABCDExtendCD);
                RBridgePatternSeg(leftBorder, (long)startTime, lowerZone, (long)startTime, upperZone,
                                  zoneColor, (int)inpTH3ZoneBorderStyle, inpTH3ZoneBorderWidth, false);
            }
            if(!rbr)
#endif
            {
            if(s_zoneStyleFamily != (int)inpTH3ZoneStyle) {
                if(ObjectFind(0, zoneUpperName) >= 0) ObjectDelete(0, zoneUpperName);
                if(ObjectFind(0, zoneLowerName) >= 0) ObjectDelete(0, zoneLowerName);
                if(ObjectFind(0, topBorder) >= 0) ObjectDelete(0, topBorder);
                if(ObjectFind(0, bottomBorder) >= 0) ObjectDelete(0, bottomBorder);
                if(ObjectFind(0, leftBorder) >= 0) ObjectDelete(0, leftBorder);
                // P-TH3-ZONE-06: the band is re-born with the fix so a chart that
                // already carries a BACK=true rectangle picks up the new layer
                // on the very next draw. One delete, once, not a per-frame loop.
                if(ObjectFind(0, zoneBoxName) >= 0) ObjectDelete(0, zoneBoxName);
            }

            if(ObjectFind(0, zoneBoxName) < 0) {
                zoneBornThisPass++;
                if(ObjectCreate(0, zoneBoxName, OBJ_RECTANGLE, 0, startTime, lowerZone, endTime, upperZone)) {
                    ObjectSetInteger(0, zoneBoxName, OBJPROP_COLOR, zoneColor);
                    ObjectSetInteger(0, zoneBoxName, OBJPROP_FILL, true);
                    ObjectSetInteger(0, zoneBoxName, OBJPROP_STYLE, inpTH3ZoneBorderStyle);
                    ObjectSetInteger(0, zoneBoxName, OBJPROP_WIDTH, inpTH3ZoneBorderWidth);
                    ObjectSetInteger(0, zoneBoxName, OBJPROP_RAY_RIGHT, inpABCDExtendCD);
                    ObjectSetInteger(0, zoneBoxName, OBJPROP_SELECTABLE, false);
                    // P-TH3-ZONE-06 (2026-10-05) — THE FILLED BAND MUST BE ON THE
                    // GRAPH. This wrote OBJPROP_BACK=true on a FILLED rectangle,
                    // which in MT4 paints it BEHIND the candles: the object stood
                    // 4/4 in every census and the user saw nothing — the
                    // «انگار رسم نمیشه». A filled band is the one surface here
                    // that must sit IN FRONT of price (the EMPTY family keeps
                    // BACK=true: it is a hairline outline and must not cover
                    // candles). This is a create-time property, so an existing
                    // band is re-born once by the sweep below to pick it up.
                    ObjectSetInteger(0, zoneBoxName, OBJPROP_BACK, false);
                }
            } else {
                // P-PERF-ZB2 (2026-10-12): guard the visual writes — color is a
                // transparency blend that can change per step; fill and back never
                // change once the object is born (they are create-time properties on
                // OBJ_RECTANGLE). Writing them unconditionally costs three repaints
                // per rung per frame on a still chart.
                ObjectMove(0, zoneBoxName, 0, startTime, lowerZone);
                ObjectMove(0, zoneBoxName, 1, endTime, upperZone);
                if((color)ObjectGetInteger(0, zoneBoxName, OBJPROP_COLOR) != zoneColor)
                    ObjectSetInteger(0, zoneBoxName, OBJPROP_COLOR, zoneColor);
            }
#ifdef BIOTAK_RENDER_ENGINE
            }   // if(!rbr): the object family only
#endif
        }
    }
    // P-TH3-ZONE-04: the family is now BORN, so the next pass skips the sweep
    // and pays only the moves. One write per pass, not six.
    s_zoneStyleFamily = (int)inpTH3ZoneStyle;
    
    // P-TH3-DISC: the even rungs' ink — dotted gray, no zones. Same family
    // discipline as the targets (create once, move after; masked with the
    // ladder in TH3LadderSetVisible, matched in TH3IsLadderName).
    for(int mi = 0; mi < 3; mi++) {
        int mStep = 2 * (mi + 1);
        string midName = mainObjName + "_Mid_" + IntegerToString(mStep);
        string midText = StringFormat("Step%d (%.1f)", mStep, midPips[mi]);
        // R-RENDER-ENGINE: the even rungs stage exactly like the targets —
        // gray dotted stroke, right-edge label, ladder-masked (`_Mid_` is a
        // ladder name), label text only when the label position shows.
#ifdef BIOTAK_RENDER_ENGINE
        if(rbr)
        {
            RBridgePatternSeg(midName, (long)startTime, midLevels[mi], (long)endTime, midLevels[mi],
                              TH3InkForChart(clrGray), (int)STYLE_DOT, 1, inpABCDExtendCD, isActive);
            if(inpTH3LabelPosition != TH3_LABEL_HIDDEN)
            {
                if(inpABCDExtendCD)
                    RBridgePatternText(midName + "_Text", 0, midLevels[mi], midText,
                                       TH3InkForChart(clrGray), 8, (int)(TA_RIGHT|TA_VCENTER), 0, "Arial", isActive);
                else
                    RBridgePatternText(midName + "_Text", (long)endTime, midLevels[mi], midText,
                                       TH3InkForChart(clrGray), 8, (int)(TA_RIGHT|TA_VCENTER), 0, "Arial", isActive);
            }
        }
        if(!rbr)
#endif
        if(ObjectFind(0, midName) < 0) {
            if(ObjectCreate(0, midName, OBJ_FIBO, 0, startTime, midLevels[mi], endTime, midLevels[mi])) {
                ObjectSetInteger(0, midName, OBJPROP_COLOR, TH3InkForChart(clrGray));
                ObjectSetInteger(0, midName, OBJPROP_LEVELCOLOR, TH3InkForChart(clrGray));
                ObjectSetInteger(0, midName, OBJPROP_WIDTH, 1);
                ObjectSetInteger(0, midName, OBJPROP_LEVELWIDTH, 1);
                ObjectSetInteger(0, midName, OBJPROP_STYLE, STYLE_DOT);
                ObjectSetInteger(0, midName, OBJPROP_LEVELSTYLE, STYLE_DOT);
                ObjectSetInteger(0, midName, OBJPROP_RAY_RIGHT, inpABCDExtendCD);
                ObjectSetInteger(0, midName, OBJPROP_SELECTABLE, false);
                ObjectSetInteger(0, midName, OBJPROP_LEVELS, 1);
                ObjectSetDouble(0, midName, OBJPROP_LEVELVALUE, 0, 0.0);
                if(inpTH3LabelPosition != TH3_LABEL_HIDDEN)
                    ObjectSetString(0, midName, OBJPROP_LEVELTEXT, 0, midText);
            }
        } else {
            ObjectMove(0, midName, 0, startTime, midLevels[mi]);
            ObjectMove(0, midName, 1, endTime, midLevels[mi]);
            // P-PERF-ZB3 (2026-10-12): guard the label text write — the mid-pip
            // value only changes when baseUnit changes (i.e. on a point drag), not
            // on every chart tick. ObjectSetString* triggers a repaint on MT4/MT5.
            if(inpTH3LabelPosition != TH3_LABEL_HIDDEN &&
               ObjectGetString(0, midName, OBJPROP_LEVELTEXT, 0) != midText)
                ObjectSetString(0, midName, OBJPROP_LEVELTEXT, 0, midText);
        }
    }

    // P-TH3-ZONE-02 (2026-10-05) — ZONE CENSUS, ONE LINE PER DRAW. The lines
    // paint while the bands read missing, and both come from one loop — so the
    // next occurrence must name setting-vs-code itself: how many of the four
    // zone boxes stand, and the three inputs that render them. Draw-paced
    // (never per tick), so the cost is one line per user gesture.
    // P-TH3-ZONE-04: `born` is the new column, and it is the one that settles
    // «drawn then deleted» — a pass that BUILDS reports born=4, a pass that only
    // re-seats them reports born=0 with bornTotal=4. The two are the same
    // picture; only the cost differs, and now the log says which one ran.
    // P-PERF-CEN1 (2026-10-12): the census fired on every draw — every drag event
    // and every UpdateAllTH3Objects frame — doing 8+ ObjectGetInteger reads per
    // zone per call to compose a string it then printed unconditionally. Gate it
    // behind ENABLE_DEBUG_LOGS so production builds skip all of that work.
    #ifdef ENABLE_DEBUG_LOGS
    if(!rbr)   // R-RENDER-ENGINE: on the canvas there are no zone objects to count
    {
        int zoneStand = 0, zoneBorn = 0;
        string zoneSeen = "";
        for(int zi = 1; zi <= 4; zi++)
        {
            string znm = mainObjName + "_Zone_" + IntegerToString(zi);
            if(ObjectFind(0, znm) < 0) continue;
            zoneStand++;
            // existence is not paint: mask, box and ink decide the pixels.
            // P-TH3-ZONE-06: `bk=` carries the LAYER, because «exists but unseen»
            // was exactly the class of bug here — a BACK=true filled rectangle
            // reads 4/4 in every field above and paints behind the candles.
            zoneSeen += StringFormat(" [%d t0=%s t1=%s p0=%s p1=%s tf=%d cl=%d bk=%d]",
                zi, TimeToString((datetime)ObjectGetInteger(0, znm, OBJPROP_TIME, 0)),
                TimeToString((datetime)ObjectGetInteger(0, znm, OBJPROP_TIME, 1)),
                DoubleToString(ObjectGetDouble(0, znm, OBJPROP_PRICE, 0), Digits),
                DoubleToString(ObjectGetDouble(0, znm, OBJPROP_PRICE, 1), Digits),
                (int)ObjectGetInteger(0, znm, OBJPROP_TIMEFRAMES),
                (int)ObjectGetInteger(0, znm, OBJPROP_COLOR),
                (int)ObjectGetInteger(0, znm, OBJPROP_BACK));
        }
        // the borders of the EMPTY family are the same family, counted the same way
        for(int zi = 1; zi <= 4; zi++)
        {
            string znm = mainObjName + "_Zone_" + IntegerToString(zi) + "_B_Top";
            if(ObjectFind(0, znm) < 0) continue;
            zoneStand++;
            zoneBorn++;
        }
        Print("TH3: zones stand=", zoneStand, "/4 borders=", zoneBorn,
              " bornThisPass=", zoneBornThisPass,
              " style=", (int)inpTH3ZoneStyle,
              " sweep=", (s_zoneStyleFamily == (int)inpTH3ZoneStyle ? "no" : "YES"),
              " tr=", inpTH3ZoneTransparency, " h%=", DoubleToString(inpTH3ZoneHeightPercent, 1),
              zoneSeen);
    }
    #endif

    // P-TH3-STEP-03: the proof objects (retired by P-TH3-DISC below — the
    // step lines already say where L3 sits; the measure, logs and TH3LOG stay).
    // P-TH3-D4: the interval starts at the placed D (tD,pD), not C.
    // P-TH3-STEP-06/07 (2026-09-19) — THE VERDICT ONLY SPEAKS WHEN IT HAS ONE.
    // The interval and the verdict describe the step the ladder now wears, so
    // they draw exactly when the market voted (hitOK — P-TH3-STEP-07 made that
    // the only condition, pivot or not). Without it there is no proof to show
    // and the two objects are DELETED, so a stale interval from a previous
    // render cannot stay parked on the chart, and a verdict can never carry the
    // empty timeframe name an unclaimed tip used to print ("T3 <-  grid").
    // P-TH3-DISC: the proof interval and verdict are OFF the chart — the step
    // lines already say where L3 sits. The measure, the log lines and TH3LOG
    // stay (the formula still wears the proved step); only the two objects
    // go. Old charts drop them on next redraw.
    // P-PERF-RET4 (2026-10-12): guarded; after one cycle these are gone on every
    // live chart — the unconditional delete is a silent but accumulating API cost.
    if(ObjectFind(0, mainObjName + "_HitLine")  >= 0) ObjectDelete(0, mainObjName + "_HitLine");
    if(ObjectFind(0, mainObjName + "_HitLabel") >= 0) ObjectDelete(0, mainObjName + "_HitLabel");

    // P-TH3-P6e + P-TH3-D4 — MOTHER PIVOT AT D, ON THE CHART.
    // The matcher (TH3Pivots.mqh) answers which six-condition pivot the
    // placed D hit (tD,pD); this is its ink — ACTIVE pattern only, one badge
    // per chart (the clean-chart rule). Two dotted bounds (extreme +
    // key line, pivot bar -> D, BACK=true so candles stay on top) plus
    // Head/Tail markers at the pivot bar (extreme + keyPrice) plus one
    // compact badge at D: "[ H1 Mother Pivot | 8.7p | FRESH ]".
    // D is the collision point, so wantHigh = dirDown: a bearish D is a
    // high, a bullish D a low. tol = half the live step, the same ruler
    // the tip corroboration uses. Everything wears the TH3_MP_ prefix:
    // pattern delete (TH3Tool.mqh) and the full teardown (EventHandlers.mqh)
    // sweep it bulk, and a render with no match DELETES the five objects,
    // so no stale zone survives a drag.
    // mpState feeds the corner info label (diagnostics): the chart always
    // says WHY no mother zone is drawn — off / none / TF+state — so a
    // missing badge is a readable verdict, never a silent mystery.
    string mpState = "MP:none";
    bool mpActive = (g_activeABCDPattern == mainObjName);
    string mpHi = "TH3_MP_" + mainObjName + "_Hi";
    string mpLo = "TH3_MP_" + mainObjName + "_Lo";
    string mpHead = "TH3_MP_" + mainObjName + "_Head";
    string mpTail = "TH3_MP_" + mainObjName + "_Tail";
    string mpBadge = "TH3_MP_" + mainObjName + "_Badge";
    TH3PivotSix mp;
    // Pillars 1+4 (P-TH3-MP2): the mother must predate the pattern origin
    // A (P-TH3-D4: X retired), and distance is scored in closed-step units.
    // The anchor PRICE (A) is wired for the launch test — the leg whose
    // start sits in the node is the leg the node launched. tol is the
    // tier-1 entry only; the matcher's ladder widens it to reach a far mother.
    datetime mpAnchor = tA;
    double   mpAnchorPrice = pA;
    bool mpShow = (inpShowMotherPivotZone && mpActive && atrBasis
                   && TH3MotherPivotAt(tD, pD, dirDown, 0.5 * baseUnit, mp,
                                       mpAnchor, (closedOK ? closedStep : 0.0), true,
                                       mpAnchorPrice));
    if(mpShow) {
        double mpTop = MathMax(mp.price, mp.keyPrice);
        double mpBot = MathMin(mp.price, mp.keyPrice);
        // bounds: create once, move after (same pattern as _HitLine).
        // P-UI-97: the resolver sits AT the write (no local ink var) —
        // panel-wiring-audit [th3ink] rejects an unresolved ink variable.
        // R-RENDER-ENGINE: five canvas rows replace the five objects. The
        // no-match branch below needs no canvas twin: this pass stages nothing
        // for the base's MP names, and the per-base unseen sweep in
        // RBridgePatternCommit drops their recs exactly as the ObjectDeletes
        // drop the objects - a drag off the pivot clears the ink either way.
#ifdef BIOTAK_RENDER_ENGINE
        if(rbr)
            RBridgePatternSeg(mpHi, (long)mp.time, mpTop, (long)tD, mpTop,
                              TH3InkForChart(inpTH3Color), (int)STYLE_DOT, 1);
        if(!rbr)
#endif
        if(ObjectFind(0, mpHi) < 0) {
            if(ObjectCreate(0, mpHi, OBJ_TREND, 0, mp.time, mpTop, tD, mpTop)) {
                ObjectSetInteger(0, mpHi, OBJPROP_COLOR, TH3InkForChart(inpTH3Color));
                ObjectSetInteger(0, mpHi, OBJPROP_STYLE, STYLE_DOT);
                ObjectSetInteger(0, mpHi, OBJPROP_WIDTH, 1);
                ObjectSetInteger(0, mpHi, OBJPROP_RAY_RIGHT, false);
                ObjectSetInteger(0, mpHi, OBJPROP_SELECTABLE, false);
                ObjectSetInteger(0, mpHi, OBJPROP_BACK, true);
            }
        } else {
            ObjectMove(0, mpHi, 0, mp.time, mpTop);
            ObjectMove(0, mpHi, 1, tD, mpTop);
        }
#ifdef BIOTAK_RENDER_ENGINE
        if(rbr)
            RBridgePatternSeg(mpLo, (long)mp.time, mpBot, (long)tD, mpBot,
                              TH3InkForChart(inpTH3Color), (int)STYLE_DOT, 1);
        if(!rbr)
#endif
        if(ObjectFind(0, mpLo) < 0) {
            if(ObjectCreate(0, mpLo, OBJ_TREND, 0, mp.time, mpBot, tD, mpBot)) {
                ObjectSetInteger(0, mpLo, OBJPROP_COLOR, TH3InkForChart(inpTH3Color));
                ObjectSetInteger(0, mpLo, OBJPROP_STYLE, STYLE_DOT);
                ObjectSetInteger(0, mpLo, OBJPROP_WIDTH, 1);
                ObjectSetInteger(0, mpLo, OBJPROP_RAY_RIGHT, false);
                ObjectSetInteger(0, mpLo, OBJPROP_SELECTABLE, false);
                ObjectSetInteger(0, mpLo, OBJPROP_BACK, true);
            }
        } else {
            ObjectMove(0, mpLo, 0, mp.time, mpBot);
            ObjectMove(0, mpLo, 1, tD, mpBot);
        }
        // P-TH3-D4 — HEAD/TAIL MARKERS. Head = the pivot extreme (mp.price),
        // Tail = the key line (mp.keyPrice): two small circles ON the pivot
        // bar so سر و ته پیوت مادر reads at a glance. Same prefix, same
        // delete discipline as Hi/Lo.
        // R-RENDER-ENGINE: the arrow-159 glyph as a filled dot — width 3 was
        // the big head, width 2 the tail (the same radii the glyph's pixel
        // blob occupied).
#ifdef BIOTAK_RENDER_ENGINE
        if(rbr)
            RBridgePatternDot(mpHead, (long)mp.time, mp.price, 3, TH3InkForChart(inpTH3Color));
        if(!rbr)
#endif
        if(ObjectFind(0, mpHead) < 0) {
            if(ObjectCreate(0, mpHead, OBJ_ARROW, 0, mp.time, mp.price)) {
                ObjectSetInteger(0, mpHead, OBJPROP_ARROWCODE, 159);
                ObjectSetInteger(0, mpHead, OBJPROP_WIDTH, 3);
                ObjectSetInteger(0, mpHead, OBJPROP_COLOR, TH3InkForChart(inpTH3Color));
                ObjectSetInteger(0, mpHead, OBJPROP_SELECTABLE, false);
                ObjectSetInteger(0, mpHead, OBJPROP_BACK, false);
            }
        } else {
            ObjectMove(0, mpHead, 0, mp.time, mp.price);
        }
#ifdef BIOTAK_RENDER_ENGINE
        if(rbr)
            RBridgePatternDot(mpTail, (long)mp.time, mp.keyPrice, 2, TH3InkForChart(inpTH3Color));
        if(!rbr)
#endif
        if(ObjectFind(0, mpTail) < 0) {
            if(ObjectCreate(0, mpTail, OBJ_ARROW, 0, mp.time, mp.keyPrice)) {
                ObjectSetInteger(0, mpTail, OBJPROP_ARROWCODE, 159);
                ObjectSetInteger(0, mpTail, OBJPROP_WIDTH, 2);
                ObjectSetInteger(0, mpTail, OBJPROP_COLOR, TH3InkForChart(inpTH3Color));
                ObjectSetInteger(0, mpTail, OBJPROP_SELECTABLE, false);
                ObjectSetInteger(0, mpTail, OBJPROP_BACK, false);
            }
        } else {
            ObjectMove(0, mpTail, 0, mp.time, mp.keyPrice);
        }
        double mpThickPips = (mpTop - mpBot) / pipSize;
        string mpFlip = ((mp.isHigh != dirDown) ? " | FLIP" : "");
        string mpText = StringFormat("[ %s Mother Pivot | %.1fp | %s%s ]",
                                     TH3TfName(mp.tf), mpThickPips,
                                     (mp.mitigated ? "MITIGATED" : "FRESH"), mpFlip);
        mpState = StringFormat("MP:%s %s%s", TH3TfName(mp.tf),
                               (mp.mitigated ? "MIT" : "FRESH"), mpFlip);
        double mpMid = (mpTop + mpBot) / 2.0;
        // P-UI-97: the badge's ink is resolved where it is computed and then worn,
        // so `inpABCDInfoColor` still paints the one caption-side surface that is
        // drawn ON the paper — the readout plate's rows are its own palette now
        // (TH3ReadoutInk), because a theme-flipped row on a fixed dark plate is
        // unreadable (P-TH3-INFO-04).
        color wantInk = TH3InkForChart(inpABCDInfoColor);
#ifdef BIOTAK_RENDER_ENGINE
        if(rbr)
            RBridgePatternText(mpBadge, (long)tD, mpMid, mpText, wantInk, 8,
                               (int)(TA_LEFT|TA_VCENTER), 0, BIO_FONT_BADGE);
        if(!rbr)
#endif
        if(ObjectFind(0, mpBadge) < 0) {
            if(ObjectCreate(0, mpBadge, OBJ_TEXT, 0, tD, mpMid)) {
                ObjectSetString(0, mpBadge, OBJPROP_TEXT, mpText);
                ObjectSetInteger(0, mpBadge, OBJPROP_COLOR, wantInk);
                ObjectSetInteger(0, mpBadge, OBJPROP_FONTSIZE, 8);
                ObjectSetString(0, mpBadge, OBJPROP_FONT, BIO_FONT_BADGE);
                ObjectSetInteger(0, mpBadge, OBJPROP_ANCHOR, ANCHOR_LEFT);
                ObjectSetInteger(0, mpBadge, OBJPROP_SELECTABLE, false);
            }
        } else {
            ObjectMove(0, mpBadge, 0, tD, mpMid);
            if(ObjectGetString(0, mpBadge, OBJPROP_TEXT) != mpText)
                ObjectSetString(0, mpBadge, OBJPROP_TEXT, mpText);
        }
    } else {
        if(!inpShowMotherPivotZone) mpState = "MP:off";
        else if(!mpActive) mpState = "MP:idle";
        // P-TH3-D4b: a miss on the ACTIVE pattern is logged with its own
        // inputs, so the log says whether D found no pivot or was never
        // allowed to look (off/idle/no-step). Rare path (one draw), not per tick.
        if(inpShowMotherPivotZone && mpActive && atrBasis)
        {
            Print("TH3: no mother at D ", TimeToString(tD), " @ ",
                  DoubleToString(pD, Digits), " dirDown=", (dirDown ? "1" : "0"),
                  " tol=", DoubleToString(0.5 * baseUnit / pipSize, 1), "p",
                  " anchor=", TimeToString(mpAnchor));
            // P-TH3-D4e: scan each TF DIRECTLY (bypassing the read memos) and
            // print (bars, anchor-shift, depth, count) — the memo-vs-scan
            // split pinpoints an empty cache to either "no bars" or a memo bug.
            // Rare path (one miss-draw), never per tick.
            int nTF0 = Period();
            int nTF1 = TH3FractalStepTF(Period(), 1);
            int nTF2 = TH3FractalStepTF(Period(), 2);
            TH3PivotSix nChart[], nStruct[], nMacro[];
            ArrayResize(nChart, TH3_P6_MAX_PIVOTS);
            ArrayResize(nStruct, TH3_P6_MAX_PIVOTS);
            ArrayResize(nMacro, TH3_P6_MAX_PIVOTS);
            int nStf = nTF1, nMtf = nTF2;
            int nNc = TH3SixPivotsScanTF(nTF0, nChart, TH3_P6_MAX_PIVOTS, 400, tD);
            Print("TH3: pivscan tf=", TH3TfName(nTF0), " bars=", iBars(NULL, nTF0),
                  " last=", iBarShift(NULL, nTF0, tD), " found=", nNc);
            int nNs = TH3SixPivotsScanTF(nTF1, nStruct, TH3_P6_MAX_PIVOTS, 400, tD);
            Print("TH3: pivscan tf=", TH3TfName(nTF1), " bars=", iBars(NULL, nTF1),
                  " last=", iBarShift(NULL, nTF1, tD), " found=", nNs);
            int nNm = TH3SixPivotsScanTF(nTF2, nMacro, TH3_P6_MAX_PIVOTS, 400, tD);
            Print("TH3: pivscan tf=", TH3TfName(nTF2), " bars=", iBars(NULL, nTF2),
                  " last=", iBarShift(NULL, nTF2, tD), " found=", nNm);
            bool nFound = false;
            TH3PivotSix nBest;   // initialised below; the compiler cannot see that
            nBest.valid = false; // `nFound` and the assignment are one condition, so
                                 // it warns — an invalid struct is the honest default.
            double nBestD = 1e9;
            for(int nL = 0; nL < 3; nL++)
            {
                int nN = (nL == 0 ? nNc : (nL == 1 ? nNs : nNm));
                for(int nI = 0; nI < nN; nI++)
                {
                    TH3PivotSix nC = (nL == 0 ? nChart[nI] : (nL == 1 ? nStruct[nI] : nMacro[nI]));
                    if(!nC.valid || nC.time > tD) continue;
                    double nD = MathAbs(nC.price - pD);
                    if(nD < nBestD) { nBestD = nD; nBest = nC; nFound = true; }
                }
            }
            if(nFound)
                Print("TH3: nearest pivot to D ",
                      TH3TfName(nBest.tf), (nBest.isHigh ? " H" : " L"),
                      " ", TimeToString(nBest.time), " @ ",
                      DoubleToString(nBest.price, Digits), " (",
                      DoubleToString(nBestD / pipSize, 1), "p away",
                      (nBest.time >= mpAnchor ? ", AFTER anchor" : ", before anchor"),
                      ((nBest.isHigh != dirDown) ? ", FLIP-kind" : ""), ")");
            else
                Print("TH3: nearest pivot to D none (cache nc=", nNc,
                      " ns=", nNs, " nm=", nNm, ")");
        }
        if(ObjectFind(0, mpHi) >= 0) ObjectDelete(0, mpHi);
        if(ObjectFind(0, mpLo) >= 0) ObjectDelete(0, mpLo);
        if(ObjectFind(0, mpHead) >= 0) ObjectDelete(0, mpHead);
        if(ObjectFind(0, mpTail) >= 0) ObjectDelete(0, mpTail);
        if(ObjectFind(0, mpBadge) >= 0) ObjectDelete(0, mpBadge);
    }

    // P-TH3-P6e Tier-2 — ORIGIN, ON THE CHART. Tier-1 answers "which level
    // is D sitting on" (P-TH3-D4) and correctly says nothing when the true
    // base is 300 pips behind: a fixed half-step tol can never reach it.
    // The origin answers "where did the move start": macro layer only,
    // ruler = the pattern's own span |D-A| (a base farther than the pattern
    // is long is another pattern's base). ONE dotted BACK line, origin bar
    // -> D at the origin price, plus an ORG token in the info state —
    // no second badge (the clean-chart rule). Same TH3_MP_ prefix, same
    // delete discipline as the Tier-1 set above.
    string mpOrg = "TH3_MP_" + mainObjName + "_Org";
    TH3PivotSix org;
    double orgSpan = MathAbs(pD - pA);   // P-TH3-D4: span measured to the placed D
    bool orgShow = (inpShowMotherPivotZone && mpActive && atrBasis && orgSpan > 0
                    && TH3OriginPivotAt(tD, pD, dirDown, orgSpan, mpAnchor, org));
    if(orgShow) {
#ifdef BIOTAK_RENDER_ENGINE
        if(rbr)
            RBridgePatternSeg(mpOrg, (long)org.time, org.price, (long)tD, org.price,
                              TH3InkForChart(inpTH3Color), (int)STYLE_DOT, 1);
        if(!rbr)
#endif
        if(ObjectFind(0, mpOrg) < 0) {
            if(ObjectCreate(0, mpOrg, OBJ_TREND, 0, org.time, org.price, tD, org.price)) {
                ObjectSetInteger(0, mpOrg, OBJPROP_COLOR, TH3InkForChart(inpTH3Color));
                ObjectSetInteger(0, mpOrg, OBJPROP_STYLE, STYLE_DOT);
                ObjectSetInteger(0, mpOrg, OBJPROP_WIDTH, 1);
                ObjectSetInteger(0, mpOrg, OBJPROP_RAY_RIGHT, false);
                ObjectSetInteger(0, mpOrg, OBJPROP_SELECTABLE, false);
                ObjectSetInteger(0, mpOrg, OBJPROP_BACK, true);
            }
        } else {
            ObjectMove(0, mpOrg, 0, org.time, org.price);
            ObjectMove(0, mpOrg, 1, tD, org.price);
        }
        mpState += (" ORG:" + TH3TfName(org.tf));
    } else {
        if(ObjectFind(0, mpOrg) >= 0) ObjectDelete(0, mpOrg);
    }

    // P-TH3-DISC: the CD-leg pivot marker is retired with the auto markers —
    // display-only, never in the formula. Old charts drop it on next redraw.
    ObjectDelete(0, mainObjName + "_LegPiv");

    // P-TH3-LOCK — THE STATE MACHINE, ON THE LABEL (the user formula's §4).
    // The gate is measured FROM THE LINES, not from the tip: L3 touched ->
    // >= 1.0-step pullback from the L3 line -> Level5 armed (M1). L5 touched
    // -> >= 2.0-step pullback from the L5 line (M2). Until the gate passes,
    // the chart says WHY the ladder is not yet at Level5 — the red-line rule
    // ("قیمت حق ندارد به صورت شارپ از گام ۳ به گام ۵ برود") made readable.
    string mileState = "";
    {
        double retraceSteps = 0;
        bool ladderUp = !dirDown;   // dirDown: D is a high, the ladder runs DOWN (P-TH3-D4)
        int mile = TH3LadderMilestone(tD, pD, ladderUp, baseUnit, retraceSteps);
        if(mile == 2)      mileState = StringFormat("M2(%.1f)", retraceSteps);
        else if(mile == 1) mileState = StringFormat("M1(%.1f)", retraceSteps);
        else               mileState = StringFormat("M0(%.1f/1.0)", retraceSteps);
    }

    // Info label (corner-based positioning - configurable)
    //     (        -      
    // VISIBILITY: Only shown for active pattern
    //         :                 
    double pips_AB = AB_Distance / pipSize;
    double pips_BC = MathAbs(pC - pB) / pipSize;
    
    // "Step", not "Freq": this number is the movement step — the LIVE one,
    // with its own provenance: which step, from what. The hunter's question
    // ("where do T3 and T5 sit ahead of me?") then answers itself off the
    // ladder lines, because the number that built them is printed here.
    // P-TH3-STEP-04e (2026-09-19) — THE SEED SHOWS BESIDE THE LIVE STEP. The
    // user's demand is that the LADDER ride the movement step, and the movement
    // step is the market's: once a reaction has voted, `Step` is the proved
    // number, not the pattern TF's ATR. Printing the seed too (`rung`) is what
    // makes the two readable against each other on the chart — the earlier twin
    // label did exactly that, and it is how a reader can tell a recalibrated
    // ladder from one still standing on its seed (step == rung, stepHow says
    // so). On XAUUSD H1 2026-09-19 this reads "Step:163.3 pips [T3 reaction
    // x0.90 | rung 175.6] | T3=489.9 T5=816.5" — the ladder the market voted.
    // P-TH3-INFO-04 (2026-09-20) — THE CAPTION IS A READOUT, NOT A LINE.
    // The user's ask: the AB=CD caption must read like the leg meter's box, because
    // it is the same tool — so it is THREE ROWS inside the same dark plate, in the
    // same order and the same ink (the family owner draws it, P-TH3-INFO-01):
    //
    //   AB=CD | H1 | CD 18 bars          <- what this pattern IS
    //   AB 504p | BC 765p | CD 1200p     <- what its legs MEASURE
    //   Step 255.0p | K 3.0 | M0(0.4)    <- the LIVE number, on the accent row
    //   (+ P-TH3-DISC discovery rows: prices, harmonic, mother, calc, lock,
    //   ladder prices — nine rows until the formula locks)
    //
    // The rows are joined with "\n": the family owner wraps WITHIN a row (MT4's
    // 63-character cliff is per object) but never across two of them, so the shape
    // survives a long pattern name. Every number here is one the ladder above has
    // already computed, or division-only off it — the caption adds no reader.
    string cdTfName = TH3TfName(ownerTF);
    double stepPips = baseUnit / pipSize;
    // P-TH3-DISC (2026-10-05) — DISCOVERY ROWS, TEMPORARY. While the master
    // step formula is being found the caption carries every number the
    // synthesis consumes: prices, ratios, mother, rung, calc stages, ladder
    // prices, mid steps, proof state. Ten short rows (each under the 63-char cliff, so
    // no row ever wraps); the plate measures off the rows as-is. Words are
    // spelled out (no cryptic codes) so an outside reader with no project
    // access can still parse the box. When the formula locks this shrinks
    // back and this tag dies with it. Division-only off numbers computed
    // above — no new reader, no new writer.
    string rowIdentity = StringFormat("AB=CD %s CD %d bars %s",
                                      cdTfName, cdBars, (dirDown ? "down" : "up"));
    string rowLegs     = StringFormat("legs AB %.0fp | BC %.0fp | CD %.0fp",
                                      pips_AB, pips_BC, CD_Distance / pipSize);
    string rowPrices    = StringFormat("A %s B %s C %s D %s",
                                      DoubleToString(pA, Digits),
                                      DoubleToString(pB, Digits),
                                      DoubleToString(pC, Digits),
                                      DoubleToString(pD, Digits));
    double bcabRatio = (AB_Distance > 0) ? BC_Distance / AB_Distance : 0.0;
    string rowHarmonic = StringFormat("BC/AB %.2f | CD/BC %.2f | K %.1f | fibdev %.2f",
                                      bcabRatio,
                                      uniRatio,
                                      uniK,
                                      (uniRatio > 0 ? CalculateFibonacciDeviation(uniRatio) : 0.0));
    string rowMother = "Mother: none";
    if(pbRaw > 0)
        rowMother = StringFormat("Mother hand %.1fp", pbRaw / pipSize);
    string rowCalc  = StringFormat("pattern %.1fp rung %.1fp uni %.1fp",
                                   (CD_Distance / uniK) / pipSize,
                                   seedRung / pipSize,
                                   baseUnit / pipSize);
    string rowLock  = StringFormat("base %.1fp %s final %.1fp %s",
                                   pbStep / pipSize,
                                   (stepLocked ? "LOCKED" : "UNLOCKED"),
                                   stepPips,
                                   (hitOK ? "proved" : "seed"));
    string rowLadder = StringFormat("Targets T1 %s T3 %s T5 %s T7 %s",
                                    DoubleToString(targetLevels[0], Digits),
                                    DoubleToString(targetLevels[1], Digits),
                                    DoubleToString(targetLevels[2], Digits),
                                    DoubleToString(targetLevels[3], Digits));
    string rowMid = StringFormat("Mid T2 %s T4 %s T6 %s",
                                 DoubleToString(midLevels[0], Digits),
                                 DoubleToString(midLevels[1], Digits),
                                 DoubleToString(midLevels[2], Digits));
    string rowLive;
    if(atrBasis) {
        rowLive = StringFormat("Step %.1fp", stepPips);
        if(mlMotherSize > 0) {
            mlRatio = baseUnit / mlMotherSize;
            rowLive += StringFormat(" | momleg %.2f", mlRatio);
        }
    } else {
        rowLive = StringFormat("Step %.1f%% | freq", frequency);
    }
    if(StringLen(mileState) > 0) rowLive += " | gate " + mileState;
    rowLive += (hitOK ? " | proved" : " | seed");

    // P-TH3-INFO-14: ONE visible caption, ONE Y — the slot pitch is retired (its
    // note lives in the geometry block above with the arithmetic). Only the active
    // family carries a plate (INFO-10), so `patIdx` buys nothing and costs the
    // user a 64 px empty slot above the caption plus a jump whenever the active
    // pattern changes. The caption sits at the base of the safe area.
    // P-BE-06 (2026-10-22): `isActive` was a second name for `isActive` — the
    // alias bought nothing and read as if the two could differ.
    int rowY    = inpABCDInfoYDistance;
    int infoLines = TH3InfoFamilyDraw(mainObjName,
                                       rowIdentity + "\n" + rowLegs + "\n" + rowPrices + "\n" +
                                       rowHarmonic + "\n" + rowMother + "\n" + rowCalc + "\n" +
                                       rowLock + "\n" + rowLadder + "\n" + rowMid + "\n" + rowLive,
                                       isActive, rowY);
    // P-TH3-INFO-13: a redraw that TOUCHED the active family re-arms its
    // visit — a re-step, a point drag or a settings press restarts the few
    // seconds the caption lives, exactly like re-showing the leg plate.
    if(isActive) TH3InfoVisitArm();

    // P-TH3-P6f (2026-09-22): the ladder follows the caption — drawn for every
    // pattern, worn by the active one only.
    TH3LadderSetVisible(mainObjName, isActive);

    // P-TH3-PB-OFF (2026-09-21) — the pivot-base LEVEL LINES are retired with
    // the drag that placed them (the base is a hand-typed HEIGHT now, with no
    // chart anchor to hang lines on). This block only sweeps the legacy
    // objects, so a chart drawn by the old build cleans itself on the next
    // redraw instead of wearing four dotted lines to a deleted gesture.
    {
        for(int _pb = 0; _pb < TH3_PIVOT_BASE_LEVELS; _pb++) {
            ObjectDelete(0, mainObjName + "_PBLine_"  + IntegerToString(_pb));
            ObjectDelete(0, mainObjName + "_PBLabel_" + IntegerToString(_pb));
        }
    }

    #ifdef ENABLE_DEBUG_LOGS
    Print("==================== DrawABCDPattern completed | Pattern: ", mainObjName);
    Print("   Caption lines: ", infoLines, " x <= ", TH3_INFO_TEXT_MAX, " chars");
    Print("   Objects: Points(3:A,B,C) + Labels(3) + Lines(2) + Targets(4) + Zones(8) + Info(", infoLines, ")");
    Print("   Note: Point D not shown - target levels indicate D zone");
    #endif

    // R-RENDER-ENGINE: the pass is complete — this base's unseen rows leave and
    // the dirty families reach the front slot in ONE repaint (none when nothing
    // compared different). Commit sits before the delete stamp below for the
    // same reason the object path stamps there: this draw's own drops must be
    // covered by it.
#ifdef BIOTAK_RENDER_ENGINE
    if(rbr) RBridgePatternCommit(mainObjName);
#endif

    // P-TH3-DEL2: this draw's own drops queue their OBJECT_DELETEs behind it.
    g_th3OwnDeleteMs = GetTickCount();
    ThrottledChartRedraw();
}

//+------------------------------------------------------------------+
//| P-TH3-P6 (2026-09-19) — THE SIX-CONDITION PIVOTS, ON THE CHART.  |
//|                                                                  |
//| The detector (TH3Pivots.mqh, from the course PDF pp. 6-7) finds  |
//| the pivots; this is their ink. Two layers, one per fractal TF:   |
//|                                                                  |
//|   * the CHART TF's pivots wear a triangle — Wingdings 218 hangs  |
//|     above an H pivot, 217 sits below an L pivot — ~one candle    |
//|     clear of the wick, so the side reads at a glance (P-TH3-P6b);|
//|   * the STRUCTURE TF's (one chain step up, p. 3) wear the same   |
//|     triangles in the structure's own ink, a fatter width — the   |
//|     bigger structure the small one lives in, big-to-small and    |
//|     small-to-big in one picture;                                 |
//|   * a chart pivot that a structure pivot claims (p. 50, the      |
//|     shared rule: the higher TF owns it) wears the structure ink  |
//|     too, so the eye can see which pivots are the structure's.    |
//|                                                                  |
//| PERF: the scan is cached per new bar of its own TF (inside the   |
//| detector); this painter redraws on a new chart bar or every 5 s  |
//| at most, bulk-clears its own namespace first (teardown/show-hide |
//| are bulk operations), and never writes a property it would not   |
//| change. Inks go through TH3InkForChart (P-UI-97).                |
//+------------------------------------------------------------------+
#define TH3_P6_PREFIX      "TH3_P6_"
void TH3PivotMarkersClear()
{
    // P-PERF-104 (2026-10-16) — ONE PREFIX WIPE, NOT A WHOLE-CHART WALK.
    //
    // The loop this replaces asked the terminal for every chart object by
    // INDEX (`ObjectsTotal` + one `ObjectName` per index) to find a namespace
    // that is RETIRED (P-TH3-DISC: nothing recreates `TH3_P6_*`), so on a
    // chart at ~1200 objects it paid ~1200 MQL calls — ~3 ms each on this
    // terminal, the per-call law P-PERF-100/101/103 all measured — to find
    // nothing. It runs twice per timeframe switch (once at teardown, inside
    // `knot=`, and once at attach from TH3PivotMarkersUpdate), and the live
    // ledger charged the teardown side `knot=687ms`.
    //
    // The delete set is IDENTICAL: `StringFind(nm, prefix) == 0` is exactly
    // the prefix match `ObjectsDeleteAll` documents, so the terminal walks
    // the same list inside ONE call — the shape P-PERF-100 gave the strip
    // sweep and P-PERF-101 the gear family.
    ObjectsDeleteAll(0, TH3_P6_PREFIX, -1, -1);
}

#endif // TH3_RENDERER_B_MQH
// TH3Renderer_C.mqh - TH3Renderer.mqh split 2026-09-29: exact lines 2356-2488, byte-identical, zero renames.
#ifndef TH3_RENDERER_C_MQH
#define TH3_RENDERER_C_MQH

void TH3PivotMarkersUpdate()
{
    // P-TH3-DISC: markers OFF — the hand-marked base is the only mother.
    // (inpTH3AutoPivots still owns the click snap in TH3Tool_C.)
    // One shot per attach: the namespace stays empty (nothing recreates it),
    // so the tick path below pays zero — no scan, no clear loop, no redraw.
    // P-ZERO (2026-10-05): this runs on EVERY tick; a still chart must cost
    // reads only (contract §5), never a 5 s teardown of 100+ objects.
    static bool s_p6Retired = false;
    if(s_p6Retired) return;
    s_p6Retired = true;
    { TH3PivotMarkersClear(); return; }

    // throttle: once per new chart bar, or every 5 s at most
    static datetime s_lastBar = 0;
    static uint     s_lastMs  = 0;
    static int      s_lastTF  = -1;
    datetime barTime = iTime(NULL, 0, 0);
    uint nowMs = GetTickCount();
    if(barTime == s_lastBar && s_lastBar != 0 && s_lastTF == Period() &&
       (nowMs - s_lastMs) < 5000 && s_lastMs != 0) return;
    s_lastBar = barTime; s_lastMs = nowMs; s_lastTF = Period();

    TH3PivotSix chartP[], structP[];
    ArrayResize(chartP, TH3_P6_MAX_PIVOTS);
    ArrayResize(structP, TH3_P6_MAX_PIVOTS);
    int nc = 0, ns = 0, stf = 0;
    TH3PivotsRead(chartP, structP, nc, ns, stf);

    TH3PivotMarkersClear();   // bulk teardown of our own namespace, then redraw
    // P-TH3-P6b (2026-09-19): the marker must CLEAR the candle and SAY its side.
    // 0.35 of an average candle sat on the wick - a dot you could lose against
    // the bar's own ink (the user's report). The offset is now ~one candle, and
    // the shape carries the direction: a DOWN triangle hangs above an H pivot,
    // an UP triangle sits below an L pivot - high or low reads at a glance,
    // without consulting the price.
    double offset = TH3AvgCandleSize() * 0.90;
    double minOff = 12 * GetCachedPipSize();
    if(offset < minOff) offset = minOff;

    int drawn = 0;
    for(int i = 0; i < nc && drawn < TH3_P6_MAX_PIVOTS; i++)
    {
        if(!chartP[i].valid || chartP[i].base) continue;
        string nm = TH3_P6_PREFIX + "C" + IntegerToString((long)chartP[i].time);
        double p  = chartP[i].price + (chartP[i].isHigh ? offset : -offset);
        if(ObjectCreate(0, nm, OBJ_ARROW, 0, chartP[i].time, p))
        {
            // shared (p. 50): the structure TF owns this pivot — its ink.
            color wantClr = chartP[i].shared ? TH3InkForChart(clrGold)
                                             : TH3InkForChart(clrAqua);
            ObjectSetInteger(0, nm, OBJPROP_ARROWCODE, chartP[i].isHigh ? 218 : 217);
            ObjectSetInteger(0, nm, OBJPROP_COLOR, wantClr);
            ObjectSetInteger(0, nm, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, nm, OBJPROP_BACK, true);
            ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
            drawn++;
        }
    }
    for(int j = 0; j < ns && drawn < 2 * TH3_P6_MAX_PIVOTS; j++)
    {
        if(!structP[j].valid || structP[j].base) continue;
        string nm = TH3_P6_PREFIX + "S" + IntegerToString((long)structP[j].time);
        double p  = structP[j].price + (structP[j].isHigh ? offset : -offset);
        if(ObjectCreate(0, nm, OBJ_ARROW, 0, structP[j].time, p))
        {
            ObjectSetInteger(0, nm, OBJPROP_ARROWCODE, structP[j].isHigh ? 218 : 217);
            ObjectSetInteger(0, nm, OBJPROP_COLOR, TH3InkForChart(clrOrangeRed));
            ObjectSetInteger(0, nm, OBJPROP_WIDTH, 3);
            ObjectSetInteger(0, nm, OBJPROP_BACK, true);
            ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
            drawn++;
        }
    }
    if(drawn > 0) ThrottledChartRedraw();
}

//+------------------------------------------------------------------+
//| P-TH3-STEP-04 (2026-09-19) — THE FORWARD PASS. The proof in      |
//| DrawABCDPattern can only fire when the reaction has ALREADY run  |
//| (drawn after the fact). A pattern drawn LIVE completes before    |
//| the reaction exists, so its ladder is drawn on the raw rung and  |
//| then goes stale forever: the chart shows the pre-reaction grid   |
//| while the info of a newer completion shows the proved step — the |
//| two numbers on one chart the user reported (Step:285.5 in the    |
//| header, a 36.5 ladder on the paper). This pass closes that gap:  |
//| on every new chart bar (the same throttle the markers ride) the  |
//| ACTIVE pattern's proof is re-measured, and when a proof exists   |
//| that the drawing does not yet carry — the tip moved, or the      |
//| reaction only just became provable — the pattern is re-drawn.    |//| The measure is pure and cached per bar inside the detector; the   |
//| re-draw runs at most once per bar and only for the one active    |
//| pattern. P-TH3-STEP-04e: the ARITHMETIC is the reaction's own     |
//| (step = |C-tip|/3, no pivot required — P-TH3-STEP-07), so a       |
//| proved step re-draws the ladder whether or not a six-condition    |
//| pivot sits on the tip; the pivot match still words the verdict.    |
//| What cannot vote is a DRIFTING forming bar: the tip must be a     |
//| closed local extreme, which the walk's two-bar offset guarantees.  |
//+------------------------------------------------------------------+
// P-TH3-D4: the forward pass measures from the placed D (tD,pD), not C.
// dirDown = D is a high (pD > pC); the closed seed reads B/C/D; the redraw
// carries the full A/B/C/D model.
void TH3HitPivotForward()
{
    // P-UI-160b: the shadow must not advance under the F mute, or the first
    // tick after show reads the proof as already carried and the ladder never
    // comes back on a chart that only moved while hidden.
    if(IsIndicatorHidden()) return;
    if(g_activeABCDPattern == "") return;
    TH3Pattern pat;
    if(!TH3PatternStoreGet(g_activeABCDPattern, pat)) return;
    if(pat.D.time <= 0 || pat.D.price <= 0) return;
    if(pat.C.time <= 0 || pat.C.price <= 0) return;

    static string s_lastPat = "";
    static double s_lastStep = 0;
    static datetime s_lastTip = 0;

    double rung = TH3PatternStepRung();   // P-TH3-STEP-08: the pattern TF's own TH
    if(rung <= 0) return;
    bool dirDown = (pat.D.price > pat.C.price);
    TH3HitProof hp;
    // P-TH3-STEP-09: same closed seed the draw path votes against, so the
    // forward re-measure cannot adopt what the draw would refuse.
    double fwdStep = 0, fwdK = 0, fwdR = 0;
    double fwdRef = (TH3ClosedStepFromLegs(pat.B.price, pat.C.price, pat.D.price,
                                           fwdStep, fwdK, fwdR) ? fwdStep : 0.0);
    if(!TH3HitPivotMeasure(pat.D.time, pat.D.price, dirDown, rung, hp, fwdRef)) return;
    if(pat.name == s_lastPat && hp.tipTime == s_lastTip &&
       MathAbs(hp.step - s_lastStep) <= GetCachedPoint()) return;   // already carries it

    Print("TH3: forward proof - the active pattern's reaction reached its tip at ",
          DoubleToString(hp.tipPrice, Digits), " (",
          DoubleToString(MathAbs(pat.D.price - hp.tipPrice) / rung, 2),
          " rungs); re-drawing the ladder on the proved step of ",
          DoubleToString(hp.step / GetCachedPipSize(), 1), " pips (",
          DoubleToString(hp.step / rung, 2), " x rung)",
          (hp.hasPivot ? " - six-condition pivot at the tip" : " - no pivot at the tip"));
    s_lastPat = pat.name;
    s_lastStep = hp.step;
    s_lastTip = hp.tipTime;
    DrawABCDPattern(pat.name, pat.A.time, pat.A.price, pat.B.time, pat.B.price,
                    pat.C.time, pat.C.price, pat.D.time, pat.D.price);
}

#endif // TH3_RENDERER_C_MQH

#endif // TH3_RENDERER_MQH
