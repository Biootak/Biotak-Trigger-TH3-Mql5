//+------------------------------------------------------------------+
//| ChartTools.mqh — the drawing-tool palette's ENGINE (P-DRAW-49)    |
//| Ported from the published source of MQL5 Trading Tools Part 19 /  |
//| 30 / 31 (Allan Munene Mutiiria): its eight tools and their        |
//| Wingdings/Webdings glyph codes, its one-click vs two-click split  |
//| and its "Active: <tool>" status line — the family APPENDS (53).   |
//|                                                                   |
//| WHAT IS OURS. MQL4's palette FACE is this product's own panel     |
//| language; this file owns which tool is armed, where the anchor    |
//| is, what the user is told, and the ONE place a drawing is made.   |
//| A created drawing is handed to DrawStyleApplyOnCreate — the       |
//| remembered look is the only owner of style (P-DRAW-01).           |
//| Lite-safe: Object*/Chart* only; "is this pixel the UI's?" is the  |
//| ONE claim's question (UIPointerOverSurface), asked by the caller. |
//+------------------------------------------------------------------+
#ifndef CHART_TOOLS_MQH
#define CHART_TOOLS_MQH

//--- the roster, in the ladder's own order (CT_NONE is the empty state).
//--- P-DRAW-58 (2026-09-26): the retired members are GONE — the user's own order
//--- retired them from the preview and the product together, so no cell can arm one.
//--- Each survivor is ONE native MT4 object (the kind table in DrawToolbar names
//--- the two that are answered differently: a circle, and a price tag).
enum EChartTool
{
   CT_NONE = 0,
   CT_CROSSHAIR,
   CT_TRENDLINE,
   CT_HLINE,
   CT_VLINE,
   CT_RECTANGLE,
   CT_FIBO,
   CT_TEXT,
   CT_ARROW,
   CT_FIBO_EXPANSION,
   CT_FIBO_CHANNEL,
   CT_RAY,
   CT_EXTENDED,
   CT_CHANNEL,
   CT_PITCHFORK,
   CT_TRIANGLE,
   CT_ELLIPSE,
   CT_CIRCLE,
   CT_NOTE,
   CT_PRICE_NOTE,
   CT_COMMENT,
   // P-DRAW-60: phase 2 of the parity plan — four tools MT4 draws NATIVELY.
   // APPENDED, never inserted: a star mask is bits of these indices and a drawing
   // carries its index in `[CTn]`, so an insert would renumber both.
   CT_ANGLE_LINE,
   CT_GANN_LINE,
   CT_GANN_FAN,
   CT_GANN_BOX,
   // P-DRAW-61: phase 3's first slice — the three tools that are ONE drawing made
   // of two objects (the group owner is DrawToolbar's). Appended for the same
   // reason as phase 2: an index is a star bit and a `[CTn]` tag.
   CT_CROSS_LINE,
   CT_INFO_LINE,
   CT_CALLOUT,
   // P-DRAW-62: the last four. The pitchforks are three lines each (the group
   // owner's biggest use), the position boxes six objects (its largest).
   CT_SCHIFF,
   CT_MOD_SCHIFF,
   CT_LONG_POS,
   CT_SHORT_POS,
   CT_COUNT
};

// 31 cells: the favourite mask is one uint and holds tools 1..31 EXACTLY - a 32nd
// tool needs a second word, never a second table (P-DRAW-56's own note).
#define CT_TOOL_COUNT 31
#define CT_PTS_MAX     3     // the most anchors one tool takes (channel/pitchfork/triangle)
#define CT_NAME_PREFIX "CT_"  // never inpObjectPrefix: these drawings are the USER's

//--- one row per button: glyph + font + caption + hover tip + click count.
struct SToolDef
{
   EChartTool tool;
   string     glyph;
   string     font;
   string     label;
   string     tip;
   int        clicks;   // 1 = one click places it, 2 = two clicks, 0 = live mode
};

//--- the engine's state. One tool at a time, like the article's active_tool.
//--- P-DRAW-54: the anchors are an ARRAY — channel / pitchfork / triangle take
//--- three points, and this count is what the instruction and the create read.
static EChartTool s_ctArmed      = CT_NONE;
static int        s_ctAnchorN    = 0;     // points held for the armed tool
static datetime   s_ctAnchorT[CT_PTS_MAX];
static double     s_ctAnchorP[CT_PTS_MAX];
static int        s_ctSeq        = 0;     // object-name counter (never reused)
// P-DRAW-56: `s_ctCreated` / `ChartToolsCreatedName` were caller-less in every commit
// since birth (catalogue 23's shape) - deleted, not left as a second answer to
// "which drawing was last" that nothing reads.

//--- P-DRAW-55: MT4 moves a selectable object itself (one OBJECT_DRAG per step)
//--- while the chart stays scrollable, so the pan raced the hand — P-DRAW-19's
//--- report, one gesture later. Shape: the band's own (P-TH3-PB-DRAG-LOCK); acquire
//--- at the claim, assert per step, release at EVERY end, and name it in
//--- ChartLockIntended or the 250 ms reconcile reads the lock as a leak.
static bool       s_ctDragLive   = false;  // a press/drag of OUR drawing is in flight
static bool       s_ctDragMoved  = false;  // it really travelled (the echo's witness)
static bool       s_ctLockHeld   = false;  // the view lock is ours (one acquire per gesture)
static string     s_ctDragName   = "";     // the drawing the hand is on
static uint       s_ctDragActMs  = 0;      // last step seen (the heal's own clock)
static uint       s_ctDraggedMs  = 0;      // the release's echo stamp (P-UI-98d's rule)
// P-DRAW-65: the ARMED tool's own PLACEMENT press (a press that will drop a point,
// with no object yet) — the drag state above cannot hold it, because a placement
// press emits no OBJECT_DRAG and would be released by the drag's enders.
static bool       s_ctPlaceLock  = false;

//+------------------------------------------------------------------+
//| The button table. Filled once, by hand, because MQL4 has no       |
//| aggregate initialiser to lean on - the glyph codes are the        |
//| article's own and must not drift.                                 |
//+------------------------------------------------------------------+
void ChartToolsDefs(SToolDef &d[])
{
   ArrayResize(d, CT_TOOL_COUNT);
   d[0].tool = CT_CROSSHAIR;    d[0].glyph = CharToString((uchar)'v');   d[0].font = "Wingdings";   d[0].label = "Crosshair"; d[0].tip = "Crosshair / measure tool - two clicks report the move"; d[0].clicks = 2;
   d[1].tool = CT_TRENDLINE;    d[1].glyph = CharToString((uchar)'.');   d[1].font = "Wingdings 3"; d[1].label = "Trendline"; d[1].tip = "Trendline tool - two clicks";                              d[1].clicks = 2;
   d[2].tool = CT_HLINE;        d[2].glyph = CharToString((uchar)'*');   d[2].font = "Wingdings 3"; d[2].label = "H-line";    d[2].tip = "Horizontal line tool - one click";                         d[2].clicks = 1;
   d[3].tool = CT_VLINE;        d[3].glyph = CharToString((uchar)'+');   d[3].font = "Wingdings 3"; d[3].label = "V-line";    d[3].tip = "Vertical line tool - one click";                           d[3].clicks = 1;
   d[4].tool = CT_RECTANGLE;    d[4].glyph = CharToString((uchar)'c');   d[4].font = "Webdings";    d[4].label = "Rectangle"; d[4].tip = "Rectangle tool - two clicks, no fill by default";          d[4].clicks = 2;
   d[5].tool = CT_FIBO;         d[5].glyph = CharToString((uchar)'"');   d[5].font = "Webdings";    d[5].label = "Fibonacci"; d[5].tip = "Fibonacci retracement tool - two clicks";                  d[5].clicks = 2;
   d[6].tool = CT_TEXT;         d[6].glyph = CharToString((uchar)'>');   d[6].font = "Webdings";    d[6].label = "Text";      d[6].tip = "Text tool - one click, then edit it in MT4's properties";  d[6].clicks = 1;
   d[7].tool = CT_ARROW;        d[7].glyph = CharToString((uchar)225);   d[7].font = "Wingdings";   d[7].label = "Arrow";     d[7].tip = "Arrow - two clicks: the tail, then the head";              d[7].clicks = 2;
   // P-DRAW-57: three anchors each - the object's own signature (P1, P2, P3) and the
   // prototype's `pts:3`; with two the third stayed at zero.
   d[8].tool = CT_FIBO_EXPANSION; d[8].glyph = CharToString((uchar)'K'); d[8].font = "Wingdings 3"; d[8].label = "Fib expansion"; d[8].tip = "Fibonacci expansion - three clicks (base, then the projection)"; d[8].clicks = 3;
   d[9].tool = CT_FIBO_CHANNEL; d[9].glyph = CharToString((uchar)'L'); d[9].font = "Wingdings 3"; d[9].label = "Fib channel"; d[9].tip = "Fibonacci channel - three clicks: the base, then its width";     d[9].clicks = 3;
   // The glyphs are THIS repo's pick inside the article's own two fonts (its table
   // stops at eight); the hover chip names every cell, so a glyph is a face, not one.
   d[10].tool = CT_RAY;         d[10].glyph = CharToString((uchar)224);  d[10].font = "Wingdings 3"; d[10].label = "Ray";        d[10].tip = "Ray - two clicks, the line runs on to the right";      d[10].clicks = 2;
   d[11].tool = CT_EXTENDED;    d[11].glyph = CharToString((uchar)225);  d[11].font = "Wingdings 3"; d[11].label = "Extended";   d[11].tip = "Extended line - two clicks, both ends run on";        d[11].clicks = 2;
   d[12].tool = CT_CHANNEL;     d[12].glyph = CharToString((uchar)'2');  d[12].font = "Wingdings 3"; d[12].label = "Channel";    d[12].tip = "Parallel channel - three clicks: the line, then its width"; d[12].clicks = 3;
   d[13].tool = CT_PITCHFORK;   d[13].glyph = CharToString((uchar)'H');  d[13].font = "Wingdings 3"; d[13].label = "Pitchfork";  d[13].tip = "Andrews pitchfork - three clicks";                    d[13].clicks = 3;
   d[14].tool = CT_TRIANGLE;    d[14].glyph = CharToString((uchar)9650); d[14].font = "Wingdings";   d[14].label = "Triangle";   d[14].tip = "Triangle - three clicks";                             d[14].clicks = 3;
   d[15].tool = CT_ELLIPSE;     d[15].glyph = CharToString((uchar)9675); d[15].font = "Wingdings";   d[15].label = "Ellipse";    d[15].tip = "Ellipse - two clicks";                                d[15].clicks = 2;
   d[16].tool = CT_CIRCLE;      d[16].glyph = CharToString((uchar)9679); d[16].font = "Wingdings";   d[16].label = "Circle";     d[16].tip = "Circle - two clicks (a square ellipse)";              d[16].clicks = 2;
   d[17].tool = CT_NOTE;        d[17].glyph = CharToString((uchar)'<');  d[17].font = "Webdings";    d[17].label = "Note";       d[17].tip = "Note - one click, then type in the strip's TEXT tab";  d[17].clicks = 1;
   d[18].tool = CT_PRICE_NOTE;  d[18].glyph = CharToString((uchar)'=');  d[18].font = "Webdings";    d[18].label = "Price note"; d[18].tip = "Price note - one click: the price tag on the scale";   d[18].clicks = 1;
   d[19].tool = CT_COMMENT;     d[19].glyph = CharToString((uchar)'@');  d[19].font = "Webdings";    d[19].label = "Comment";    d[19].tip = "Comment - one click, a one-line caption";              d[19].clicks = 1;
   // P-DRAW-60: the preview's own glyph codes, verbatim (its roster is the spec).
   // `gannline` and `gannfan` share `T` there too — the hover chip names them.
   d[20].tool = CT_ANGLE_LINE;  d[20].glyph = CharToString((uchar)196); d[20].font = "Wingdings 3"; d[20].label = "Angle line"; d[20].tip = "Angle line - two clicks, then drag its end to change the angle"; d[20].clicks = 2;
   d[21].tool = CT_GANN_LINE;   d[21].glyph = CharToString((uchar)'T'); d[21].font = "Wingdings";   d[21].label = "Gann line";  d[21].tip = "Gann line - two clicks, a 1x1 line";                   d[21].clicks = 2;
   d[22].tool = CT_GANN_FAN;    d[22].glyph = CharToString((uchar)'T'); d[22].font = "Wingdings";   d[22].label = "Gann fan";   d[22].tip = "Gann fan - two clicks, the 1x1 fan from one corner";   d[22].clicks = 2;
   d[23].tool = CT_GANN_BOX;    d[23].glyph = CharToString((uchar)'U'); d[23].font = "Wingdings";   d[23].label = "Gann box";   d[23].tip = "Gann box - two clicks, the 1x1 grid between them";     d[23].clicks = 2;
   // P-DRAW-61: the preview's own glyph codes again; each is a two-object drawing.
   d[24].tool = CT_CROSS_LINE;  d[24].glyph = CharToString((uchar)219); d[24].font = "Wingdings 3"; d[24].label = "Cross line"; d[24].tip = "Cross line - two clicks: the line through them, plus the horizontal at its middle"; d[24].clicks = 2;
   d[25].tool = CT_INFO_LINE;   d[25].glyph = CharToString((uchar)236); d[25].font = "Wingdings 3"; d[25].label = "Info line";  d[25].tip = "Info line - two clicks: the line, and the move's numbers beside it"; d[25].clicks = 2;
   d[26].tool = CT_CALLOUT;     d[26].glyph = CharToString((uchar)'?'); d[26].font = "Webdings";    d[26].label = "Callout";    d[26].tip = "Callout - two clicks: the point, then where its caption sits"; d[26].clicks = 2;
   // P-DRAW-62: the last four, glyphs from the preview's own roster.
   d[27].tool = CT_SCHIFF;      d[27].glyph = CharToString((uchar)'I'); d[27].font = "Wingdings 3"; d[27].label = "Schiff";     d[27].tip = "Schiff pitchfork - three clicks: the origin, then the two points its median divides"; d[27].clicks = 3;
   d[28].tool = CT_MOD_SCHIFF;  d[28].glyph = CharToString((uchar)'J'); d[28].font = "Wingdings 3"; d[28].label = "Mod Schiff"; d[28].tip = "Modified Schiff pitchfork - three clicks, the origin shifted on the time axis"; d[28].clicks = 3;
   d[29].tool = CT_LONG_POS;    d[29].glyph = CharToString((uchar)233); d[29].font = "Wingdings";   d[29].label = "Long position";  d[29].tip = "Long position - two clicks: the TARGET level, then the entry (the stop mirrors it)"; d[29].clicks = 2;
   d[30].tool = CT_SHORT_POS;   d[30].glyph = CharToString((uchar)234); d[30].font = "Wingdings";   d[30].label = "Short position"; d[30].tip = "Short position - two clicks: the TARGET level, then the entry (the stop mirrors it)"; d[30].clicks = 2;
}

// P-DRAW-56 — THE STARS. A favourite is the user's own mark on a tool, and the
// roster's ORDER derives from it (starred first, then the table's own order), so
// the face keeps ONE owner of the cell-to-tool mapping. The mask is the engine's
// state; the UI block persists it as one slot. A 33rd tool widens the mask, never
// a second table.
static uint s_ctFavMask = 0;
// P-DRAW-66: the shift is UNSIGNED — the 31st tool is bit 31, and `1 << 31` on a
// signed int is the sign bit, not a favourite.
uint ChartToolsFavBit(const EChartTool t) { return ((uint)1 << (int)t); }
bool ChartToolsFavOf(const EChartTool t)
{
   return (t > CT_NONE && t < CT_COUNT && (s_ctFavMask & ChartToolsFavBit(t)) != 0);
}
uint ChartToolsFavMask() { return s_ctFavMask; }
void ChartToolsFavSet(const uint mask) { s_ctFavMask = mask; }
bool ChartToolsFavToggle(const EChartTool t)
{
   if(t <= CT_NONE || t >= CT_COUNT) return false;
   s_ctFavMask ^= ChartToolsFavBit(t);
   return ChartToolsFavOf(t);
}

//--- P-DRAW-57: the PINNED LIST the toolbar draws — the mask's own order, so the face
//--- never keeps a second list that could disagree with the cells it marks.
int ChartToolsPinnedCount()
{
   int n = 0;
   // P-DRAW-66: the bound is CT_COUNT, not CT_TOOL_COUNT. The defines are a COUNT
   // (31 tools, indices 1..31) while these loops read like a last index, so index 31
   // - CT_SHORT_POS - was walked by NO face: one dead ladder cell and a tool that
   // could never be pinned or armed (the preview shows all 32).
   for(int t = 1; t < CT_COUNT; t++)
      if(ChartToolsFavOf((EChartTool)t)) n++;
   return n;
}
EChartTool ChartToolsPinnedAt(const int i)
{
   if(i < 0) return CT_NONE;
   int seen = 0;
   for(int t = 1; t < CT_COUNT; t++)
   {
      if(!ChartToolsFavOf((EChartTool)t)) continue;
      if(seen++ == i) return (EChartTool)t;
   }
   return CT_NONE;
}

// The FACE's ONE reader of the table's ORDER: palette cell i is the i-th tool of the
// DISPLAY order, and that order is the engine's answer (starred first) — a cell's own
// tool, its light and its click all come from here.
EChartTool ChartToolsToolAt(const int i)
{
   if(i < 0 || i >= CT_TOOL_COUNT) return CT_NONE;
   int seen = 0;
   for(int pass = 0; pass < 2; pass++)          // pass 0 = starred, pass 1 = the rest
      for(int t = 1; t < CT_COUNT; t++)
      {
         if(ChartToolsFavOf((EChartTool)t) != (pass == 0)) continue;
         if(seen++ == i) return (EChartTool)t;
      }
   return CT_NONE;
}

bool ChartToolsDefAt(const int i, SToolDef &out)
{
   return ChartToolsDefOf(ChartToolsToolAt(i), out);
}

//--- the palette's LIGHT: the armed tool, asked as one compare.
bool ChartToolsIsArmedTool(const EChartTool t)
{
   return (t != CT_NONE && s_ctArmed == t);
}

//+------------------------------------------------------------------+
bool ChartToolsDefOf(const EChartTool t, SToolDef &out)
{
   SToolDef d[];
   ChartToolsDefs(d);
   for(int i = 0; i < ArraySize(d); i++)
      if(d[i].tool == t) { out = d[i]; return true; }
   return false;
}

string ChartToolsName(const EChartTool t)
{
   SToolDef d;
   if(!ChartToolsDefOf(t, d)) return "None";
   return d.label;
}

int ChartToolsClickCount(const EChartTool t)
{
   SToolDef d;
   if(!ChartToolsDefOf(t, d)) return 0;
   return d.clicks;
}

//+------------------------------------------------------------------+
//| The arm state - the article's `active_tool` plus its `current_    |
//| instruction`, kept as two questions because the palette paints one|
//| and the status line reads the other.                              |
//+------------------------------------------------------------------+
EChartTool ChartToolsArmed()     { return s_ctArmed; }
bool       ChartToolsArmedOnUi() { return (s_ctArmed != CT_NONE); }

//--- P-DRAW-65 — THE ARMED TOOL'S PLACEMENT PRESS OWNS THE VIEW. Reported: «ابزار
//--- انتخاب میکنیم اماده کشیدن هستش صفحه پشتش تکون میخوره نمیشه درست رسمش کرد» —
//--- for every palette tool, while the OLD surfaces were fine (LEVEL 76's own split:
//--- the palette's DRAG claim was walked, its PLACEMENT press never was). MT4 pans on
//--- a left press-drag (CHART_MOUSE_SCROLL), so the aim slid out from under the point;
//--- the terminal's own drawing tools do not pan while drawing. The lock is taken for
//--- the PRESS only: ARMED-but-IDLE stays FREE on purpose (P-TH3-PB-UI), so the mode
//--- can still scroll between two clicks. Named in `ChartLockIntended` (D-04) through
//--- `ChartToolsViewOwned`, so the 250 ms reconcile does not read it as a leak.
void ChartToolsPlaceClaim()
{
   if(s_ctPlaceLock) return;
   s_ctPlaceLock = true;
   ChartViewLockAcquire();     // D-02: the ONE owner holds every property the lock is
}
void ChartToolsPlaceRelease()
{
   if(!s_ctPlaceLock) return;
   s_ctPlaceLock = false;
   ChartViewLockRelease();
}

void ChartToolsDisarm()
{
   s_ctArmed    = CT_NONE;
   s_ctAnchorN  = 0;
   ChartToolsPlaceRelease();   // D-05/D-09: Esc, a right-click and a finished drawing end the press lock too
}

// A tap on a button: arm it, or disarm it if it is the one already armed -
// the article's own toggle, and the reason one tap is never "arm then draw".
bool ChartToolsArm(const EChartTool t)
{
   if(t == CT_NONE) { ChartToolsDisarm(); return false; }
   if(s_ctArmed == t) { ChartToolsDisarm(); return false; }
   s_ctArmed   = t;
   s_ctAnchorN = 0;
   return true;
}

//--- the one-line instruction under the palette (the article's
//--- `current_instruction`, same three states).
string ChartToolsInstruction()
{
   if(s_ctArmed == CT_NONE) return "";
   const string who = ChartToolsName(s_ctArmed);
   const int need = ChartToolsClickCount(s_ctArmed);
   if(need == 1) return who + ": click the chart to place it";
   // P-DRAW-54: a count, not a word — a three-point tool needs no third caption.
   return who + ": click point " + IntegerToString(s_ctAnchorN + 1) + " of " + IntegerToString(need);
}

string ChartToolsStatus()
{
   if(s_ctArmed == CT_NONE) return "Active: None";
   const int need = ChartToolsClickCount(s_ctArmed);
   string tail = "";
   if(need > 1 && s_ctAnchorN > 0)
      tail = "  (" + IntegerToString(s_ctAnchorN) + " of " + IntegerToString(need) + ")";
   return "Active: " + ChartToolsName(s_ctArmed) + tail;
}

//--- P-DRAW-53: the hover chip's ONE line for a palette cell — a glyph cannot say which
//--- tool it is, so the NAME and the armed state are here (C-08).
string ChartToolsCellTip(const EChartTool t)
{
   SToolDef d;
   if(!ChartToolsDefOf(t, d)) return "";
   // P-DRAW-56: the star is part of what the surface must say out loud - the mark on the
   // tile is a glyph, and the chip is where it is spelled (C-08).
   return d.label + " - " + d.tip + (ChartToolsIsArmedTool(t) ? "  |  ARMED" : "") +
          (ChartToolsFavOf(t) ? "  |  favourite" : "");
}

// P-DRAW-54: the three single-anchor readers that stood here (HasAnchor / AnchorTime /
// AnchorPrice) were caller-less since birth (catalogue 23) — deleted, not restated.

//+------------------------------------------------------------------+
//| A drawing the palette made is the USER's: it must never carry      |
//| inpObjectPrefix, or the delete branch would read it as ours and    |
//| flag a level rebuild (P-BK-01's own trap).                        |
//+------------------------------------------------------------------+
// P-DRAW-61: ONE member of a group — created, numbered and dressed by the
// remembered look of ITS OWN kind. A single-anchor type gets one point, not two:
// MT4's one varargs signature would set anchors the type does not own.
bool ChartToolsMemberMake(const EChartTool t, const string master, const int k,
                          const int type, const datetime t1, const double p1,
                          const datetime t2, const double p2, const int n)
{
   const string m = GroupMemberName(master, k);
   if(n < 2 || k < 1) return false;          // a "group" of one is not a group
   if(ObjectFind(0, m) >= 0) return false;
   bool made = false;
   // (ENUM_OBJECT): MQL4 takes the type as a plain int, MQL5 as the enum; the
   // cast is legal on both and keeps this line shared (see AGENTS.md).
   if(type == OBJ_HLINE || type == OBJ_VLINE || type == OBJ_TEXT ||
      type == OBJ_ARROW || type == OBJ_ARROW_RIGHT_PRICE)
      made = ObjectCreate(0, m, (ENUM_OBJECT)type, 0, t1, p1);
   else
      made = ObjectCreate(0, m, (ENUM_OBJECT)type, 0, t1, p1, t2, p2);
   if(!made) return false;
   ObjectSetInteger(0, m, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, m, OBJPROP_SELECTED, false);
   ObjectSetString(0, m, OBJPROP_TOOLTIP, ChartToolsName(t));
   DrawStyleApplyOnCreate(m);
   return true;
}
void ChartToolsGroupSeal(const string master, const int n)
{
   for(int k = 1; k < n; k++)
   {
      const string m = GroupMemberName(master, k);
      if(ObjectFind(0, m) >= 0) GroupStamp(m, master, k, n);
   }
   GroupStamp(master, master, 0, n);
}

string ChartToolsNewName(const EChartTool t, const string kind)
{
   s_ctSeq++;
   string nm = CT_NAME_PREFIX + kind + "_" + IntegerToString(s_ctSeq);
   while(ObjectFind(0, nm) >= 0) { s_ctSeq++; nm = CT_NAME_PREFIX + kind + "_" + IntegerToString(s_ctSeq); }
   return nm;
}

//--- P-DRAW-53: this file used to carry its own copy of "does this pixel belong to a UI
//--- surface?" (the strip's rect only) — a SECOND owner of a question the UI layer
//--- already answers for every surface it owns (`UIPointerOverSurface`, A-08/A-13), which
//--- let an armed tool drop an anchor under the ring. Deleted; the caller asks the owner.

// The measure read-out: the article's Part 32 answers a move with price, bars
// and time; this is the same three numbers, printed where the drawing lands.
string ChartToolsMeasureText(const datetime t1, const double p1, const datetime t2, const double p2)
{
   const double d = p2 - p1;
   const double pct = (p1 != 0.0) ? (d / p1 * 100.0) : 0.0;
   string dir = (d > 0.0) ? "up" : ((d < 0.0) ? "down" : "flat");
   return DoubleToString(d, Digits) + "  (" + dir + ", " + DoubleToString(pct, 2) + "%)  " +
          IntegerToString((int)(MathAbs((double)(t2 - t1)) / (double)PeriodSeconds()) ) + " bars";
}

// P-DRAW-55 — THE DRAWING'S OWN DRAG: THE VIEW IS THE GESTURE'S (four enders in
// EventHandlers/BiotakPanels/the timer), nothing is written while the button is down
// (P-BK-15), and the tag rides the description (P-DRAW-21) so a release finds it back.
bool ChartToolsOwnsName(const string name)
{
   return (name != "" && StringFind(name, CT_NAME_PREFIX) == 0);
}

//--- the two questions the lock list and the heal ask, one bool each.
bool ChartToolsViewOwned() { return (s_ctLockHeld || s_ctPlaceLock); }
bool ChartToolsDragLive()  { return s_ctDragLive; }
//--- P-DRAW-66: the placement press has NO `OBJECT_DRAG` stream to go stale on, so the
//--- timer's button-up read is its only heal — without it a release that lands outside
//--- the chart leaves the view locked for good (the P-BK-03 class, palette-side). The
//--- button read itself stays in the entry (UILeftButtonUp is the UI half's).
bool ChartToolsPlaceLocked() { return s_ctPlaceLock; }

//--- the tool's tag, riding the DESCRIPTION (P-DRAW-21's channel): visible in MT4's own
//--- list, survives reattach and a TF switch, and is the only way back to its tool.
#define CT_TAG_PREFIX "CT"
string ChartToolsTag(const EChartTool t)
{
   return "[" + CT_TAG_PREFIX + IntegerToString((int)t) + "]";
}

//--- the heal's clock: a live drag keeps producing OBJECT_DRAG steps, so a latch this
//--- idle with the button provably up is a release we never saw (P-BK-03).
#define CT_DRAG_IDLE_MS 1500
bool ChartToolsDragStale()
{
   return (s_ctDragLive && s_ctDragActMs != 0 &&
           (GetTickCount() - s_ctDragActMs) > CT_DRAG_IDLE_MS);
}

//--- the release's own click echo: MT4 reports a click at the END of a native drag, and
//--- with a tool armed it would drop an anchor on the drawing just moved (P-UI-98d).
#define CT_CLICK_ECHO_MS 350
bool ChartToolsClickEcho()
{
   return (s_ctDraggedMs != 0 && (GetTickCount() - s_ctDraggedMs) <= CT_CLICK_ECHO_MS);
}

//--- the press that named one of our drawings claims the view BEFORE MT4 starts its
//--- own drag (the gap P-TH3-BAND-PRESS closed for the band), with the hit test the
//--- caller already paid for.
void ChartToolsPressClaim(const string name)
{
   if(!ChartToolsOwnsName(name)) return;
   if(!s_ctLockHeld) { s_ctLockHeld = true; ChartViewLockAcquire(); }
   s_ctDragLive  = true;
   s_ctDragName  = name;
   s_ctDragActMs = GetTickCount();
}

//--- the OBJECT_DRAG channel: CONTINUOUS while MT4 moves the object, and READS only
//--- (the terminal owns the drawing for the gesture, P-BK-15) - a step pays one
//--- read-guarded lock assert.
void ChartToolsDragStep(const string name)
{
   if(!ChartToolsOwnsName(name)) return;
   if(!s_ctLockHeld) { s_ctLockHeld = true; ChartViewLockAcquire(); }
   else ChartViewLockAssert();
   s_ctDragLive  = true;
   s_ctDragMoved = true;
   s_ctDragName  = name;
   s_ctDragActMs = GetTickCount();
   s_ctDraggedMs = s_ctDragActMs;   // the release's echo stamp, armed per step
   // P-DRAW-61: our drawings are gated by the prefix above, so a member of a group
   // is carried here — the rest of its drawing follows the hand by the same delta.
   GroupDragStep(name);
}

//--- THE ONE ENDER: every path calls it - a button-up move, the quiet click, the
//--- 1.5 s heal. The lock goes back only when WE took it, and the tooltip is
//--- refreshed here and nowhere else - never while the button is down (P-BK-15).
void ChartToolsDragEnd()
{
   const string nm = s_ctDragName;
   const bool held = s_ctLockHeld;
   const bool moved = s_ctDragMoved;
   s_ctDragLive  = false;
   s_ctDragMoved = false;
   s_ctLockHeld  = false;
   s_ctDragName  = "";
   s_ctDragActMs = 0;
   GroupDragReset();                           // P-DRAW-61: the carry ends with the gesture
   if(moved) s_ctDraggedMs = GetTickCount();   // a moveless press is a click, not an echo
   if(held) ChartViewLockRelease();
   if(nm != "") ChartToolsTipRefresh(nm);
}

//+------------------------------------------------------------------+
//| ONE owner of the caption: the measure's line IS its numbers, every|
//| other tool's is its name and its own instruction.                 |
//+------------------------------------------------------------------+
string ChartToolsTipOf(const EChartTool t, const datetime t1, const double p1,
                       const datetime t2, const double p2)
{
   if(t == CT_CROSSHAIR) return ChartToolsMeasureText(t1, p1, t2, p2);
   return ChartToolsName(t) + "  |  " + ChartToolsInstruction();
}

//--- the release's own caption: the measure's numbers move with its anchors, so
//--- the text written at create is stale the moment the hand lets go. ONE
//--- description read decides; only the measure pays the four anchor reads.
void ChartToolsTipRefresh(const string nm)
{
   if(nm == "" || ObjectFind(0, nm) < 0) return;
   // Presence, not equality: the box extras append their own `[BX…]` tags to the
   // same TEXT field (P-DRAW-21), and a second writer must not blind this reader.
   if(StringFind(ObjectGetString(0, nm, OBJPROP_TEXT), ChartToolsTag(CT_CROSSHAIR)) < 0) return;
   const datetime t1 = (datetime)ObjectGetInteger(0, nm, OBJPROP_TIME, 0);
   const double   p1 = ObjectGetDouble(0, nm, OBJPROP_PRICE, 0);
   const datetime t2 = (datetime)ObjectGetInteger(0, nm, OBJPROP_TIME, 1);
   const double   p2 = ObjectGetDouble(0, nm, OBJPROP_PRICE, 1);
   const string tip = ChartToolsMeasureText(t1, p1, t2, p2);
   if(ObjectGetString(0, nm, OBJPROP_TOOLTIP) != tip)
      ObjectSetString(0, nm, OBJPROP_TOOLTIP, tip);
}

//+------------------------------------------------------------------+
//| Create ONE drawing for the armed tool, then hand it to the style   |
//| memory (P-DRAW-01: the user's last look for that kind is the only  |
//| owner of style). Returns the name, "" when nothing was made.       |
//+------------------------------------------------------------------+
// P-DRAW-54: the third anchor is OPTIONAL (defaulted), so every two-point call site
// in this file keeps its shape while channel / pitchfork / triangle pass three.
string ChartToolsCreate(const EChartTool t, const datetime t1, const double p1,
                        const datetime t2, const double p2,
                        const datetime t3 = 0, const double p3 = 0.0)
{
   string nm = "";
   bool made = false;
   int    grpN = 1;   // P-DRAW-61: >1 when this tool's drawing is more than one object
   switch(t)
   {
      case CT_TRENDLINE:
         nm = ChartToolsNewName(t, "TREND");
         made = ObjectCreate(0, nm, OBJ_TREND, 0, t1, p1, t2, p2);
         if(made) ObjectSetInteger(0, nm, OBJPROP_RAY_RIGHT, false);
         break;
      case CT_HLINE:
         nm = ChartToolsNewName(t, "HLINE");
         made = ObjectCreate(0, nm, OBJ_HLINE, 0, 0, p1);
         if(made) ObjectSetDouble(0, nm, OBJPROP_PRICE, 0, p1);
         break;
      case CT_VLINE:
         nm = ChartToolsNewName(t, "VLINE");
         made = ObjectCreate(0, nm, OBJ_VLINE, 0, t1, 0);
         if(made) ObjectSetInteger(0, nm, OBJPROP_TIME, 0, t1);
         break;
      case CT_RECTANGLE:
         nm = ChartToolsNewName(t, "RECT");
         made = ObjectCreate(0, nm, OBJ_RECTANGLE, 0, t1, p1, t2, p2);
         // The user's own order for a fresh box, kept here: no fill.
         if(made) ObjectSetInteger(0, nm, OBJPROP_FILL, false);
         break;
      case CT_FIBO:
         nm = ChartToolsNewName(t, "FIBO");
         made = ObjectCreate(0, nm, OBJ_FIBO, 0, t1, p1, t2, p2);
         break;
      case CT_TEXT:
         nm = ChartToolsNewName(t, "TEXT");
         made = ObjectCreate(0, nm, OBJ_TEXT, 0, t1, p1);
         if(made)
         {
            ObjectSetString(0, nm, OBJPROP_TEXT, "Text");
            ObjectSetString(0, nm, OBJPROP_FONT, "Arial");
         }
         break;
      case CT_ARROW:
         // P-DRAW-61: the preview's arrow is a line WITH a head (pts:2) and no single
         // MT4 object draws both — so the HEAD is the master (its kind keeps the
         // strip's GLYPH slot, which a lone trend line would lose) and the line
         // rides it as member 1.
         nm = ChartToolsNewName(t, "ARROW");
         made = ObjectCreate(0, nm, OBJ_ARROW, 0, t2, p2);
         if(made) { grpN = 2; ChartToolsMemberMake(t, nm, 1, OBJ_TREND, t1, p1, t2, p2, grpN); }
         break;
      // Each is ONE native object and the style memory already speaks its kind
      // (DrawKindOf: DK_FIBOCHAN / DK_EXPANSION / DK_FIBO), so the remembered look
      // applies on create here like every other tool — no new style path.
      // P-DRAW-57: three anchors, like the object's own signature.
      case CT_FIBO_EXPANSION:
         nm = ChartToolsNewName(t, "FIBEXP");
         made = ObjectCreate(0, nm, OBJ_EXPANSION, 0, t1, p1, t2, p2, t3, p3);
         break;
      case CT_FIBO_CHANNEL:
         nm = ChartToolsNewName(t, "FIBCH");
         made = ObjectCreate(0, nm, OBJ_FIBOCHANNEL, 0, t1, p1, t2, p2, t3, p3);
         break;
      //--- P-DRAW-54: the second batch. Each one is ONE native object; the two
      //--- that MT4 does not have (a circle, a note's plate) are answered below.
      case CT_RAY:
         nm = ChartToolsNewName(t, "RAY");
         made = ObjectCreate(0, nm, OBJ_TREND, 0, t1, p1, t2, p2);
         if(made)
         {
            ObjectSetInteger(0, nm, OBJPROP_RAY_RIGHT, true);
            ObjectSetInteger(0, nm, OBJPROP_RAY_LEFT, false);
         }
         break;
      case CT_EXTENDED:
         nm = ChartToolsNewName(t, "EXT");
         made = ObjectCreate(0, nm, OBJ_TREND, 0, t1, p1, t2, p2);
         if(made)
         {
            ObjectSetInteger(0, nm, OBJPROP_RAY_RIGHT, true);
            ObjectSetInteger(0, nm, OBJPROP_RAY_LEFT, true);
         }
         break;
      case CT_CHANNEL:
         nm = ChartToolsNewName(t, "CHAN");
         made = ObjectCreate(0, nm, OBJ_CHANNEL, 0, t1, p1, t2, p2, t3, p3);
         break;
      case CT_PITCHFORK:
         nm = ChartToolsNewName(t, "PITCH");
         made = ObjectCreate(0, nm, OBJ_PITCHFORK, 0, t1, p1, t2, p2, t3, p3);
         break;
      case CT_TRIANGLE:
         nm = ChartToolsNewName(t, "TRI");
         made = ObjectCreate(0, nm, OBJ_TRIANGLE, 0, t1, p1, t2, p2, t3, p3);
         break;
      case CT_ELLIPSE:
         nm = ChartToolsNewName(t, "ELL");
         made = ObjectCreate(0, nm, OBJ_ELLIPSE, 0, t1, p1, t2, p2);
         break;
      case CT_CIRCLE:
      {
         // MT4 has no circle: an ELLIPSE whose on-screen box is SQUARE is one. The
         // squaring is measured at CREATE only (2 projections + 1 back-conversion),
         // never in the mouse stream — G-12's bound is this one call.
         nm = ChartToolsNewName(t, "CIRC");
         datetime ct2 = t2; double cp2 = p2;
         int ax = 0, ay = 0, bx = 0, by = 0;
         if(ChartTimePriceToXY(0, 0, t1, p1, ax, ay) && ChartTimePriceToXY(0, 0, t2, p2, bx, by))
         {
            int dx = bx - ax, dy = by - ay;
            int side = (int)MathMax(MathAbs((double)dx), MathAbs((double)dy));
            int sub = 0; datetime nt = 0; double np = 0.0;
            if(ChartXYToTimePrice(0, ax + ((dx < 0) ? -side : side), ay + ((dy < 0) ? -side : side), sub, nt, np))
            { ct2 = nt; cp2 = np; }
         }
         made = ObjectCreate(0, nm, OBJ_ELLIPSE, 0, t1, p1, ct2, cp2);
         break;
      }
      case CT_NOTE:
      case CT_COMMENT:
         // MT4 gives a note and a comment the SAME native object (OBJ_TEXT — a
         // plate is not a property it has). They differ in the caption they open
         // with, and the strip's TEXT tab types over it.
         nm = ChartToolsNewName(t, (t == CT_NOTE) ? "NOTE" : "CMT");
         made = ObjectCreate(0, nm, OBJ_TEXT, 0, t1, p1);
         if(made)
         {
            ObjectSetString(0, nm, OBJPROP_TEXT, (t == CT_NOTE) ? "Note" : "Comment");
            ObjectSetString(0, nm, OBJPROP_FONT, "Arial");
         }
         break;
      case CT_PRICE_NOTE:
         // OBJ_ARROW_RIGHT_PRICE is MT4's own price tag: one anchor, and the value
         // is drawn on the scale by the platform (its kind carries no GLYPH slot).
         nm = ChartToolsNewName(t, "PTAG");
         made = ObjectCreate(0, nm, OBJ_ARROW_RIGHT_PRICE, 0, t1, p1);
         break;
      // P-DRAW-60: four native objects, one anchor pair each — no maths of ours.
      // OBJ_TRENDBYANGLE is the only kind that reads OBJPROP_ANGLE, and MT4 keeps
      // the angle in step with its own end point, so nothing recalculates it.
      case CT_ANGLE_LINE:
         nm = ChartToolsNewName(t, "ANGLE");
         made = ObjectCreate(0, nm, OBJ_TRENDBYANGLE, 0, t1, p1, t2, p2);
         break;
      case CT_GANN_LINE:
         nm = ChartToolsNewName(t, "GLINE");
         made = ObjectCreate(0, nm, OBJ_GANNLINE, 0, t1, p1, t2, p2);
         break;
      case CT_GANN_FAN:
         nm = ChartToolsNewName(t, "GFAN");
         made = ObjectCreate(0, nm, OBJ_GANNFAN, 0, t1, p1, t2, p2);
         break;
      case CT_GANN_BOX:
         nm = ChartToolsNewName(t, "GBOX");
         made = ObjectCreate(0, nm, OBJ_GANNGRID, 0, t1, p1, t2, p2);
         break;
      case CT_CROSSHAIR:
         // The measure: the article's own answer is a read-out between two
         // points, so this is a trend line carrying the numbers as its label.
         nm = ChartToolsNewName(t, "MEAS");
         made = ObjectCreate(0, nm, OBJ_TREND, 0, t1, p1, t2, p2);
         if(made)
         {
            ObjectSetInteger(0, nm, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(0, nm, OBJPROP_WIDTH, 1);
         }
         break;
      // P-DRAW-61: three group tools. Each is a MASTER (the object the strip
      // serves and the kind it reads) plus ONE member; both are sealed at the tail.
      case CT_CROSS_LINE:
         // THE PREVIEW'S OWN SHAPE (its `crossline` case): the A→B line EXTENDED BOTH
         // WAYS plus the horizontal at its MIDDLE — not an H and a V through a point.
         nm = ChartToolsNewName(t, "CROSS");
         made = ObjectCreate(0, nm, OBJ_TREND, 0, t1, p1, t2, p2);
         if(made)
         {
            ObjectSetInteger(0, nm, OBJPROP_RAY_RIGHT, true);
            ObjectSetInteger(0, nm, OBJPROP_RAY_LEFT, true);
            grpN = 2;
            ChartToolsMemberMake(t, nm, 1, OBJ_HLINE, t1, (p1 + p2) / 2.0, t1, p1, grpN);
         }
         break;
      case CT_INFO_LINE:
         // THE PREVIEW'S OWN SHAPE (its `infoline` case): the segment plus the move's
         // NUMBERS beside it. MT4 draws no floating chip, so the numbers are a TEXT at
         // the middle — and it is the ONE measure text this product already owns.
         nm = ChartToolsNewName(t, "INFO");
         made = ObjectCreate(0, nm, OBJ_TREND, 0, t1, p1, t2, p2);
         if(made)
         {
            grpN = 2;
            const datetime mt = t1 + (t2 - t1) / 2;
            const double   mp = (p1 + p2) / 2.0;
            if(ChartToolsMemberMake(t, nm, 1, OBJ_TEXT, mt, mp, t2, p2, grpN))
            {
               ObjectSetString(0, GroupMemberName(nm, 1), OBJPROP_TEXT, ChartToolsMeasureText(t1, p1, t2, p2));
               ObjectSetString(0, GroupMemberName(nm, 1), OBJPROP_FONT, "Arial");
            }
         }
         break;
      case CT_CALLOUT:
         // THE PREVIEW'S OWN SHAPE (its `callout` case): a caption PLATE with a leader
         // line to its point. MT4 has no rounded plate, so the plate is the TEXT's own
         // frame and the drawing is the caption + the leader; the TEXT is the master (a
         // callout's point is its caption) and the leader is member 1 — which is ALSO
         // where the group tag lives, because a TEXT draws its own description and can
         // carry none (P-DRAW-21).
         nm = ChartToolsNewName(t, "CALL");
         made = ObjectCreate(0, nm, OBJ_TEXT, 0, t2, p2);
         if(made)
         {
            ObjectSetString(0, nm, OBJPROP_TEXT, "Callout");
            ObjectSetString(0, nm, OBJPROP_FONT, "Arial");
            grpN = 2;
            ChartToolsMemberMake(t, nm, 1, OBJ_TREND, t1, p1, t2, p2, grpN);
         }
         break;
      // P-DRAW-62 — THE PITCHFORKS, from the preview's OWN construction: the median
      // runs from the ORIGIN through the MIDPOINT of P2/P3, and the two branches are
      // that median TRANSLATED by (P2-P1) and (P3-P1). Only the origin moves — Schiff
      // takes the midpoint of P1/P2 on BOTH axes, Modified Schiff the midpoint in TIME
      // with P1's own price. Three plain trend lines; the median alone is rayed.
      case CT_SCHIFF:
      case CT_MOD_SCHIFF:
      {
         const bool     wr = (t == CT_SCHIFF);
         const datetime oT = (datetime)((t1 + t2) / 2);
         const double   oP = wr ? (p1 + p2) / 2.0 : p1;
         const datetime mT = (datetime)((t2 + t3) / 2);
         const double   mP = (p2 + p3) / 2.0;
         const long     dBt = (long)(t2 - t1), dCt = (long)(t3 - t1);
         const double   dBp = p2 - p1, dCp = p3 - p1;
         nm = ChartToolsNewName(t, wr ? "SCHIFF" : "MSCHIFF");
         made = ObjectCreate(0, nm, OBJ_TREND, 0, oT, oP, mT, mP);
         if(made)
         {
            ObjectSetInteger(0, nm, OBJPROP_RAY_RIGHT, true);
            grpN = 3;
            ChartToolsMemberMake(t, nm, 1, OBJ_TREND, (datetime)((long)oT + dBt), oP + dBp,
                                 (datetime)((long)mT + dBt), mP + dBp, grpN);
            ChartToolsMemberMake(t, nm, 2, OBJ_TREND, (datetime)((long)oT + dCt), oP + dCp,
                                 (datetime)((long)mT + dCt), mP + dCp, grpN);
         }
         break;
      }
      // P-DRAW-62 — THE POSITION BOXES, also from the preview: the SECOND click is the
      // entry and the FIRST is the far level; the stop MIRRORS the target about the
      // entry and the box spans the two clicks' own time range. Six objects, the group
      // owner's largest. The preview's R:R chip is left out ON PURPOSE: a risk/reward
      // ratio is trade-plan maths and that has ONE owner (R-TRADEPLAN).
      case CT_LONG_POS:
      case CT_SHORT_POS:
      {
         const bool     lp = (t == CT_LONG_POS);
         const double   tp = lp ? p1 : p2 + (p2 - p1);
         const double   sl = lp ? (p2 + (p2 - p1)) : p1;
         const datetime x1 = (t1 < t2) ? t1 : t2;
         const datetime x2 = (t1 < t2) ? t2 : t1;
         nm = ChartToolsNewName(t, lp ? "LONG" : "SHORT");
         made = ObjectCreate(0, nm, OBJ_RECTANGLE, 0, x1, tp, x2, sl);
         if(made)
         {
            ObjectSetInteger(0, nm, OBJPROP_FILL, false);   // a fresh box wears no fill
            grpN = 6;
            ChartToolsMemberMake(t, nm, 1, OBJ_TREND, x1, p2, x2, p2, grpN);   // entry
            ChartToolsMemberMake(t, nm, 2, OBJ_TREND, x1, tp, x2, tp, grpN);   // target
            ChartToolsMemberMake(t, nm, 3, OBJ_TREND, x1, sl, x2, sl, grpN);   // stop
            if(ChartToolsMemberMake(t, nm, 4, OBJ_TEXT, x2, tp, x2, tp, grpN))
            {
               ObjectSetString(0, GroupMemberName(nm, 4), OBJPROP_TEXT, "TP " + DoubleToString(tp, Digits));
               ObjectSetString(0, GroupMemberName(nm, 4), OBJPROP_FONT, "Arial");
            }
            if(ChartToolsMemberMake(t, nm, 5, OBJ_TEXT, x2, sl, x2, sl, grpN))
            {
               ObjectSetString(0, GroupMemberName(nm, 5), OBJPROP_TEXT, "SL " + DoubleToString(sl, Digits));
               ObjectSetString(0, GroupMemberName(nm, 5), OBJPROP_FONT, "Arial");
            }
         }
         break;
      }
      default:
         return "";
   }
   if(!made) return "";
   DrawStyleApplyOnCreate(nm);   // the one owner of the remembered look
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, nm, OBJPROP_SELECTED, false);
   ObjectSetString(0, nm, OBJPROP_TOOLTIP, ChartToolsTipOf(t, t1, p1, t2, p2));
   // P-DRAW-55: the tool's identity rides the object's own DESCRIPTION - MT4's
   // OBJPROP_TEXT field, P-DRAW-21/F-01's channel (what MT4 cannot draw rides the
   // object itself, so it survives reattach, a TF switch and a restart). A TEXT
   // kind's TEXT IS its caption and is left alone, and so is the price tag's own
   // label - the measure, the one kind the release reads back, is a trend line and
   // carries the tag.
   const EDrawKind tagKind = DrawKindOf(nm);
   if(tagKind != DK_TEXT && tagKind != DK_PRICENOTE)
      ObjectSetString(0, nm, OBJPROP_TEXT, ChartToolsTag(t));
   // P-DRAW-61: and the group's own seal LAST, so the tag that resolves the family
   // is never the one the tool's identity would overwrite (a group master carries
   // the group tag; the measure, the only reader of `[CTn]`, is never a group).
   if(grpN > 1) ChartToolsGroupSeal(nm, grpN);
   return nm;
}

//+------------------------------------------------------------------+
//| THE click. Returns true when a drawing was made, so the caller can |
//| redraw once. One click for the single-click family, two for the     |
//| rest - the article's `IsSingleClickTool` split, in this product's   |
//| terms. The mode ENDS with the drawing it made (P-DRAW-56): the      |
//| palette is a command, not a mode the user has to leave.             |
//+------------------------------------------------------------------+
// P-DRAW-56 (user order 2026-09-26: «وقتی کار تموم شد ابزار بسته بشه»): a finished
// drawing disarms the tool. The left-armed palette was the "dirty state" the user
// named - the mode outlived its work and the next press drew instead of scrolled.
// ONE owner for that exit, asked by both click shapes.
bool ChartToolsClickDone(const bool made)
{
   if(made) ChartToolsDisarm();
   return made;
}

bool ChartToolsClick(const datetime clickTime, const double clickPrice)
{
   if(s_ctArmed == CT_NONE) return false;
   const int need = ChartToolsClickCount(s_ctArmed);
   if(need <= 0 || need > CT_PTS_MAX) return false;
   if(need == 1)
      return ChartToolsClickDone(ChartToolsCreate(s_ctArmed, clickTime, clickPrice, clickTime, clickPrice) != "");

   // P-DRAW-54: two or three points — the anchor list grows, and the LAST click
   // creates (then disarms, P-DRAW-56). An anchor is state, the drawing is the end.
   s_ctAnchorT[s_ctAnchorN] = clickTime;
   s_ctAnchorP[s_ctAnchorN] = clickPrice;
   s_ctAnchorN++;
   if(s_ctAnchorN < need) return false;   // an anchor is state, not a drawing

   const datetime t1 = s_ctAnchorT[0];
   const double   p1 = s_ctAnchorP[0];
   const datetime t2 = s_ctAnchorT[1];
   const double   p2 = s_ctAnchorP[1];
   const datetime t3 = (need > 2) ? s_ctAnchorT[2] : t2;
   const double   p3 = (need > 2) ? s_ctAnchorP[2] : p2;
   const bool done = (ChartToolsCreate(s_ctArmed, t1, p1, t2, p2, t3, p3) != "");
   s_ctAnchorN = 0;
   return ChartToolsClickDone(done);
}

//+------------------------------------------------------------------+
//| Esc / a tap on the armed button. Returns true when it cancelled     |
//| something, so the caller can repaint the palette's own face.        |
//+------------------------------------------------------------------+
bool ChartToolsCancel()
{
   if(s_ctArmed == CT_NONE && s_ctAnchorN == 0) return false;
   ChartToolsDisarm();
   return true;
}

#endif // CHART_TOOLS_MQH
