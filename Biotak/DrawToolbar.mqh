// ============================================================================
// OWNED MT5 module - forked from the MetaTrader 4 source on 2026-10-12.
//   MT4 source : Biotak/Biotak/DrawToolbar.mqh
//
// MT4 remains the LOGIC reference and tools/parity/module-report.py flags
// any drift, but nothing regenerates this file: MT5-only changes live here
// directly, marked MT5-ONLY / P-MT5-* / P-PERF-*.
//
// MT5-only changes this file already carries:
//   * MQL5 ObjectCreate needs an explicit ENUM_OBJECT cast  (1 substitution)
//   * the diag channel prints nothing unless DSTRIP_DIAG is set  (1 substitution)
// ============================================================================
  //+------------------------------------------------------------------+
//|                                              DrawToolbar.mqh      |
//|   P-DRAW-01 (2026-09-22) — THE USER'S OWN DRAWINGS, ONE OWNER.     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Biotak Project"
#property strict

#ifndef DRAW_TOOLBAR_MQH
#define DRAW_TOOLBAR_MQH

// Toolbar_A.mqh - DrawToolbar.mqh split 2026-09-29: exact lines 10-1199, byte-identical, zero renames.
#ifndef TOOLBAR_A_MQH
#define TOOLBAR_A_MQH


// ══════════════════════════════════════════════════════════════════════════
// P-DRAW-01 — A MINI TOOLBAR FOR EVERY DRAWING THE USER MAKES (fibos, trendlines,
// horizontals, rays, lines, boxes) — explicitly NOT for the indicator's own objects,
// which already have their own toolbars.
// WHY THIS SHAPE. MT4 gives every drawing tool its own type and a property surface
// that is only MOSTLY common, so a per-type toolbar would be thirty copies of the same
// five controls. The whole feature is ONE classifier plus ONE table: `DrawKindOf`
// answers an EDrawKind, `DrawKindCaps` is the bitmask of slots that kind carries (a
// slot the kind lacks is not drawn, never greyed), and `DrawSlotRead/Write` is one pair
// per slot — so adding a drawing tool is one row in two switches, never a new control.
// THE HIT TEST IS MEASURED IN PIXELS: every anchor is projected with
// `ChartTimePriceToXY` and the cursor compared against the object's DRAWN shape within
// one px (MT4 itself has no "object under the cursor" call), with the terminal's own
// selection as a second opinion (`DrawSelectedObjectAt`).
// THE STYLE MEMORY IS THE "LAST CHANGE SAVED": every edit goes onto the object AND
// into that KIND's memory, and a freshly drawn object of the kind is given it on
// create (`DrawStyleApplyOnCreate`), per drawing TOOL, not globally.
// ══════════════════════════════════════════════════════════════════════════

//--- THE KINDS. One per drawing BEHAVIOUR the toolbar must speak, not one per
//--- MT4 type: a fan and a plain fibo share their level machinery, so they share
//--- the kind and differ in geometry only.
enum EDrawKind
{
   DK_NONE = 0,     // not a drawing of ours (the indicator's own, a panel, …)
   DK_LINE,         // OBJ_TREND (MT4 has no OBJ_ARROWED_LINE — the arrowed line IS a trend)
   DK_HLINE,        // OBJ_HLINE
   DK_VLINE,        // OBJ_VLINE
   DK_CHANNEL,      // OBJ_CHANNEL / OBJ_STDDEVCHANNEL / OBJ_REGRESSION
   DK_FIBO,         // OBJ_FIBO / OBJ_FIBOTIMES (horizontal level lines)
   DK_FIBOFAN,      // OBJ_FIBOFAN / OBJ_FIBOARC (levels slanted from the first anchor)
   DK_FIBOCHAN,     // OBJ_FIBOCHANNEL
   DK_EXPANSION,    // OBJ_EXPANSION
   DK_GANN,         // OBJ_GANNLINE / OBJ_GANNFAN / OBJ_GANNGRID
   DK_PITCHFORK,    // OBJ_PITCHFORK
   DK_RECT,         // OBJ_RECTANGLE
   DK_TRIANGLE,     // OBJ_TRIANGLE
   DK_ELLIPSE,      // OBJ_ELLIPSE
   DK_ARROW,        // OBJ_ARROW (one anchor, a glyph)
   DK_TEXT,         // OBJ_TEXT (one anchor, a caption)
   //--- P-UNIFY-2 (2026-10-19): THE TWO KINDS THE TOOLBAR OFFERS AND THE STRIP NEVER
   //--- SPOKE. `OBJ_TRENDBYANGLE` and `OBJ_CYCLES` had no kind at all, so a pick on
   //--- either answered DK_NONE - the strip opened on NOTHING (0 cells, 0 rows) and the
   //--- hand that clicked its own drawing got no answer. Appended at the END so every
   //--- index a build before this one wrote (template rows, remembered looks, the
   //--- per-kind array seat) keeps its number: this is an ADD, never a renumber.
   DK_TANGLE,       // OBJ_TRENDBYANGLE (two anchors, a line at a fixed angle)
   DK_CYCLES,       // OBJ_CYCLES (two anchors, a fan of verticals by that period)
   DK_COUNT
};

//--- P-UNIFY-4 (2026-10-19): THE LOOK IDS. Frozen like the `FF_` addresses: an id is
//--- written on the object as `[LKn]` and in a template's style word, so a renumber is
//--- a rename of every drawing a previous build saved. `_3D` (4) is retired and must
//--- never be reused (P-LOOK-3D).
#define DRAW_LOOK_NEON   1
#define DRAW_LOOK_CAPS   2
#define DRAW_LOOK_WASH   3
#define DRAW_LOOK_COUNT  3
#define DRAW_LOOK_TAG    "[LK"
#define DRAW_LOOK_BIT_NEON 0x01
#define DRAW_LOOK_BIT_CAPS 0x02
#define DRAW_LOOK_BIT_WASH 0x04
#define DRAW_LOOK_ALL      (DRAW_LOOK_BIT_NEON | DRAW_LOOK_BIT_CAPS | DRAW_LOOK_BIT_WASH)

//--- THE GEOMETRY FAMILIES. A level family seats N rows between its anchors; a
//--- line has one seat per row; a shape has an outline; a point has one anchor.
#define DKG_NONE    0
#define DKG_LEVEL   1
#define DKG_LINE    2
#define DKG_SHAPE   3
#define DKG_POINT   4

//--- THE PEN FAMILIES. The level pen states per-level lines (`FibPen`); the
//--- object pen copies the whole drawing (line/shape, `PenStack`).
#define DKPEN_NONE   0
#define DKPEN_LEVEL  1
#define DKPEN_OBJECT 2

struct DrawKindProfile
{
   int geom;
   int pen;
   int lookMask;
};

//--- THE SLOTS the strip can show, in the order it shows them. The index is the
//--- contract between this module and the strip; a kind simply does not carry
//--- the ones it has no meaning for.
#define DRAW_SLOT_COLOR   0   // the object's colour (a fibo: the level family's)
#define DRAW_SLOT_WIDTH   1   // 1..5 px
#define DRAW_SLOT_STYLE   2   // solid / dash / dot / …
#define DRAW_SLOT_FILL    3   // rectangle, triangle, ellipse, fibo channel
#define DRAW_SLOT_RAY     4   // a line's own RAY_RIGHT / RAY_LEFT
#define DRAW_SLOT_LOCK    5   // SELECTABLE = false: it cannot be grabbed or moved
#define DRAW_SLOT_MORE    6   // the terminal's own properties (a hint, see the strip)
//--- P-DRAW-09a (2026-09-23) — THE PROPERTIES MT4 ONLY REACHES THROUGH ITS
//--- 9-CHECKBOX DIALOG. User order: «هر چیزی که متاتریدر پشتیبانی نمیکنه [رو
//--- پوشش بده] … ولی پر امکانات باشه». Three controls MT4 HAS and buries, each
//--- one property write and each one tap here — APPENDED, so no existing slot
//--- index moved (the strip speaks these numbers).
//---   * FONT  — OBJ_TEXT's caption size: MT4's own properties dialog, one
//---             object at a time, and the size the user keeps re-setting by hand;
//---   * GLYPH — OBJ_ARROW's Wingdings code: MT4 makes the user hunt a code
//---             number; here the mark is a cycle with the number always shown;
//---   * BACK  — "draw as background": the Common tab's checkbox, which is where
//---             a trader's zones belong and is otherwise four clicks deep.
#define DRAW_SLOT_FONT    7
#define DRAW_SLOT_GLYPH   8
#define DRAW_SLOT_BACK    9
//--- P-DRAW-64a (2026-09-27) — THE BOX'S OWN TWO EXTRAS. User order: «یک ایکون
//--- برای 50 درصد طول باکس بزار ... و یک ایکون دیگه برای اکستند به راست بزار ...
//--- مهمه توی نوار استریپ باشه دم دست», then «۵۰ درصد باکس فقط میخوام، fill بهکارم
//--- نمیاد» (50 % OF THE BOX, not a half-filled interior) and then, after the length
//--- cut shipped: «خود باکس رو از وسط طول نصف میکنه که نباید باشه ... فقط 50 درصد مثل
//--- فیبو که 50 درصد مشخص میشه» — the 50 % is a LEVEL, the length is the hand's.
//--- Both marks already existed in the more-popover (P-DRAW-21/22, `[BX…]`); here they
//--- are SLOTS, one tap each:
//---   * BOXHALF — the 50 % line: `[BX50]`, a level at the box's own mid price, drawn by
//                `BoxMidSync` as the `<box>_BX50` child, the fib's own idiom;
//---   * EXTEND  — the box's later edge travels with the newest bar.
//--- APPENDED, so no existing slot index moved (the strip speaks these numbers).
#define DRAW_SLOT_BOXHALF 11
#define DRAW_SLOT_EXTEND  12
//--- P-DRAW-64 (2026-09-27) — THE SECOND COLOUR, ONE PER ROLE. User order: «رنگ
//--- بوردر بشه جدا تنظیم کرد ... و fill همه جدا. یک بخش براش اضافه کن». MT4 gives
//--- a drawing ONE colour (the docs' own `RectangleCreate` fills with `InpColor`;
//--- `OBJPROP_BGCOLOR` is the screen objects' — see docs/contract.md §2), so the split
//--- is: the LINE/BORDER stays `DRAW_SLOT_COLOR` and the INTERIOR is this slot.
//---   * the LEVEL family has a REAL second colour — `OBJPROP_LEVELCOLOR`;
//---   * the five FILLER kinds have none, so the interior is a CHILD object
//---     (`<drawing>_FL`, the `_BX50` pattern) wearing the interior's own colour.
//--- APPENDED, so no existing slot index moved (the strip speaks these numbers).
#define DRAW_SLOT_FILLCLR 10

//--- P-DRAW-BODY (2026-10-04) — THE BODY IS A LINE OF ITS OWN. «این خط هم جدا باشه
//--- تنظیمات و رنگ و استایل و غیره در تنظیمات و تداخل نداشته باشه باهم». A level drawing
//--- is TWO pictures: the line MT4 draws between the anchors (the BODY) and the LEVEL
//--- family the pen styles — and the strip's own colour/width/style cells were writing
//--- BOTH halves at once, so restyling a level restyled the body and vice versa. These
//--- three seats are the body's: they write `OBJPROP_COLOR/WIDTH/STYLE` and NOTHING else
//--- — no `DrawLevelsSet*`, no look tag, no kind memory (the levels' memory is theirs).
//--- The three cells above them are, for a level kind, the LEVELS' alone.
//--- APPENDED, so no existing slot index moved (the strip speaks these numbers).
#define DRAW_SLOT_BODYCOLOR 13
#define DRAW_SLOT_BODYWIDTH 14
#define DRAW_SLOT_BODYSTYLE 15
#define DRAW_SLOT_N          16

//--- THE CAPABILITIES, one bit per slot. A kind's mask IS its toolbar.
#define DRAW_CAP_COLOR   (1 << DRAW_SLOT_COLOR)
#define DRAW_CAP_WIDTH   (1 << DRAW_SLOT_WIDTH)
#define DRAW_CAP_STYLE   (1 << DRAW_SLOT_STYLE)
#define DRAW_CAP_FILL    (1 << DRAW_SLOT_FILL)
#define DRAW_CAP_RAY     (1 << DRAW_SLOT_RAY)
#define DRAW_CAP_LOCK    (1 << DRAW_SLOT_LOCK)
#define DRAW_CAP_MORE    (1 << DRAW_SLOT_MORE)
#define DRAW_CAP_FONT    (1 << DRAW_SLOT_FONT)
#define DRAW_CAP_GLYPH   (1 << DRAW_SLOT_GLYPH)
#define DRAW_CAP_BACK    (1 << DRAW_SLOT_BACK)
#define DRAW_CAP_FILLCLR (1 << DRAW_SLOT_FILLCLR)   // P-DRAW-64: the interior's colour
#define DRAW_CAP_BOXHALF  (1 << DRAW_SLOT_BOXHALF)  // P-DRAW-64a: the box at 50% of its length
#define DRAW_CAP_EXTEND   (1 << DRAW_SLOT_EXTEND)   // P-DRAW-64a: the far edge travels
#define DRAW_CAP_BODYCOLOR (1 << DRAW_SLOT_BODYCOLOR) // P-DRAW-BODY: the line between the anchors
#define DRAW_CAP_BODYWIDTH (1 << DRAW_SLOT_BODYWIDTH)
#define DRAW_CAP_BODYSTYLE (1 << DRAW_SLOT_BODYSTYLE)
#define DRAW_CAP_BODY      (DRAW_CAP_BODYCOLOR | DRAW_CAP_BODYWIDTH | DRAW_CAP_BODYSTYLE)
//--- every drawing tool the user has: the four common controls + the two that
//--- every MT4 object really carries (LOCK, BACK) + the terminal's own dialog
//--- hint. Kinds add FILL / RAY / FONT / GLYPH on top (see the table).
#define DRAW_CAP_COMMON  (DRAW_CAP_COLOR | DRAW_CAP_WIDTH | DRAW_CAP_STYLE | DRAW_CAP_LOCK | DRAW_CAP_BACK | DRAW_CAP_MORE)

//--- the pick tolerance, in PIXELS: the same "a few pixels around what is
//--- drawn" the terminal itself uses (the custom price line's own lesson,
//--- P-UI-49c: a hit test expressed in price drifts with the zoom).
#define DRAW_HIT_PX      6
#define DRAW_SELECTED_HANDLE_PX 8
//--- the style memory's bounds, mirrored from the panel's own rows.
#define DRAW_WIDTH_MIN   1
#define DRAW_WIDTH_MAX   5
//--- P-LOOK: the fibo's own looks ride the STYLE slot as 5/6/7 — one vocabulary
//--- for the slot's readers (here), its writer (Toolbar_B) and its painter
//--- (FibPen paints them from the [LKn] tag, ids 1..3, its own defines).
//--- P-LOOK-3D retired (2026-10-18): seat 8 («3D») is gone — never renumber, never reuse.
//--- P-DRAW-09a: the two bounded properties the new slots cycle. FONT is the
//--- caption's own point size (MT4 draws OBJ_TEXT at it unchanged), GLYPH the
//--- Wingdings code of a mark.
#define DRAW_FONT_MIN    6
#define DRAW_FONT_MAX   30
#define DRAW_FONT_DEF   10
#define DRAW_GLYPH_MIN   0
#define DRAW_GLYPH_MAX 255

// ══════════════════════════════════════════════════════════════════════════
// IS THIS OBJECT OURS? The indicator's own drawings (levels, zones, the ABCD
// pattern and its harmonics, the BaseKnot boxes, the panels, the leg meter)
// all carry `inpObjectPrefix`; the user's own drawings never do. ONE test,
// asked by every entry point of this module — the user's order was explicit
// that the harmonics and the rest of the indicator's objects are NOT in scope.
//
// P-DRAW-87 (2026-09-30) — ONE FAMILY WAS NOT UNDER THAT PREFIX, AND THIS TEST
// WAS THE WHOLE BUG. «شادو رسم میشه بعد چند ثانیه نیست» (the HTF candle's shadow box
// is drawn and then gone) was NOT a look, a slider or a mask: the overlay's boxes
// are born `BiotakHTF_<chartid>_*` (HTFCandles' own namespace — `inpObjectPrefix`
// is "THLevels"), so every entry point below read them as the USER's drawings.
// The one that shows is the 2 s `BoxExtrasPump` (DrawStrip_Pick): it saw a filled
// rectangle that was not ours, ran the interior split on it, cleared the master's
// FILL and created `<name>_FL` filled with `BlendColorTowardsBG(..., background)`
// — the chart background itself, byte-identical, because a foreign object carries
// no opacity slot (100 - 0 = 100). The hollow BODIES survived untouched, which is
// why the report is about the shadow alone: `OBJPROP_FILL` is already 0 on them,
// so the pump's own `Fill != 0 || child exists` probe never fires.
//
// The name cannot be re-declared here (P-UI-68: HTFCandles is the ONE writer of an
// HTF name), and HTFCandles is included AFTER this file, so the overlay PUBLISHES
// its root — `g_OverlayNameRoot` (GlobalVariables) — and this is one head-on test
// of it. The level prefix is tested FIRST because it owns the walk's majority: a
// name it answers returns without paying for the second compare.
// ══════════════════════════════════════════════════════════════════════════
bool DrawIsHTFObject(const string name)
{
   if(name == "") return false;
   int o = StringLen(g_OverlayNameRoot);
   if(o > 0 && StringFind(name, g_OverlayNameRoot) == 0) return true;
   return (StringFind(name, "BiotakHTF_") == 0);
}

bool DrawIsIndicatorObject(const string name)
{
   if(name == "") return true;                      // no name, no drawing
   int n = StringLen(name);
   if(n == 0) return false;
   int p = StringLen(inpObjectPrefix);
   if(p > 0 && n >= p && StringSubstr(name, 0, p) == inpObjectPrefix) return true;
   //--- P-DRAW-87: the overlay's published namespace. "" until the HTF module
   //--- publishes it (one write, at its init), and then this answers false for
   //--- every name exactly as it did before the test existed.
   int o = StringLen(g_OverlayNameRoot);
   if(o > 0 && n >= o && StringSubstr(name, 0, o) == g_OverlayNameRoot) return true;
   if(DrawIsHTFObject(name)) return true;
   return false;
}
// P-HR-04 (2026-09-28) — THE RAY IS A DRAWING TOO. A Horizontal Ray carries
// the indicator prefix (so create/delete routing ignores it) but the STRIP
// serves it like a user trendline: hold-to-open, color/width/style/delete.
// The `_H` dot is nobody's drawing (handled by HRayTool, never hit, never
// served) — one suffix, one test, asked by every entry point below.
// P-HR-06: the marker is prefix-anchored — a USER drawing that merely
// mentions "_HRAY_" must never inherit ray behaviour.
bool DrawIsHRay(const string name)
{
   if(StringLen(inpObjectPrefix) == 0) return false;
   if(StringFind(name, inpObjectPrefix + "_HRAY_") != 0) return false;
   int l = StringLen(name);
   return !(l > 2 && StringSubstr(name, l - 2) == "_H");
}
// P-UI-136: THE PATH IS A DRAWING TOO — the strip serves a path segment exactly
// as it serves a ray (colour/width/style, hold-to-open, bin delete). The test is
// the path's OWN id parser (`PathIdOfName`), so a handle (`_H<n>`, whose tail is
// not digits) is never served and a user line that merely mentions "_PATH_" is
// never mistaken for one.
bool DrawIsPathSeg(const string name)
{
   if(StringLen(inpObjectPrefix) == 0) return false;
   if(StringFind(name, inpObjectPrefix + PATH_TAG) != 0) return false;
   string id;
   return PathIdOfName(name, id);
}

//--- the object's MT4 type, or -1 when it is not on the chart.
int DrawObjectType(const string name)
{
   if(name == "") return -1;
   if(ObjectFind(0, name) < 0) return -1;
   return (int)ObjectGetInteger(0, name, OBJPROP_TYPE);
}

// P-DRAW-74b — THE FIBO'S OWN STACKED PEN lives in Biotak/FibPen.mqh (split
// 2026-10-03: this file stood at 1498 of the 1500-line ceiling).
// P-WARN-46 (2026-10-04): the six prototypes that stood here went with the build's
// last 6 `warning 46: no #import declaration` lines. They were written for a
// top-down rule MQL4 does not enforce for FUNCTIONS: `UIPointerOverSurface` has
// been called from EventHandlers_Router with its only body in the later-included
// BiotakPanels_Hit.mqh since P-UI-92c, with no prototype anywhere, and the build
// has been green throughout. A prototype is still owed for #import-ed libraries -
// which is exactly the warning this file no longer earns.
// ══════════════════════════════════════════════════════════════════════════
// P-DRAW-21 — THE BOX'S OWN CHILDREN. A box 50% line is a helper the terminal
// cannot draw (OBJ_RECTANGLE has no mid line), so it lives as a separate
// OBJ_TREND named `<box>_BX50`. It is nobody's drawing: the classifier below
// answers DK_NONE for it, so the strip never serves it, the hit test never
// lands on it, and no preset/style memory learns from it. One suffix, one
// test, asked by every entry point that meets an object name.
// ══════════════════════════════════════════════════════════════════════════
#define BOXCHILD_SUFFIX "_BX50"
bool BoxIsMidChild(const string name)
{
   int n = StringLen(name), s = StringLen(BOXCHILD_SUFFIX);
   if(n <= s) return false;
   return (StringSubstr(name, n - s, s) == BOXCHILD_SUFFIX);
}
string BoxMidName(const string box) { return box + BOXCHILD_SUFFIX; }
string BoxMidParent(const string child)
{
   if(!BoxIsMidChild(child)) return "";
   return StringSubstr(child, 0, StringLen(child) - StringLen(BOXCHILD_SUFFIX));
}
//--- P-DRAW-64 (2026-09-27) — THE INTERIOR'S OWN CHILD, the same one-suffix / one-
//--- test the mid line took: MT4 gives a filler kind ONE colour, so a second colour
//--- for the interior is a child object (`<drawing>_FL`) wearing it. `DrawKindOf`
//--- answers DK_NONE for it, so the strip never serves it, the hit test never lands
//--- on it and no preset learns from it.
#define FILLCHILD_SUFFIX "_FL"
bool FillIsChild(const string name)
{
   int n = StringLen(name), s = StringLen(FILLCHILD_SUFFIX);
   if(n <= s) return false;
   return (StringSubstr(name, n - s, s) == FILLCHILD_SUFFIX);
}
string FillChildName(const string obj) { return obj + FILLCHILD_SUFFIX; }
string FillChildParent(const string child)
{
   if(!FillIsChild(child)) return "";
   return StringSubstr(child, 0, StringLen(child) - StringLen(FILLCHILD_SUFFIX));
}
//--- the five kinds whose interior MT4 can only draw in the LINE's colour (so the
//--- interior is a child); the level family's second colour is its LEVELCOLOR.
bool DrawKindHasFillBody(const EDrawKind k)
{
   return (k == DK_RECT || k == DK_TRIANGLE || k == DK_ELLIPSE ||
           k == DK_CHANNEL || k == DK_FIBOCHAN);
}
//--- ...and of those, the MT4 TYPES whose fill is a REAL fill of the type's own
//--- area (so a child of that type can carry the second colour). `DK_CHANNEL`
//--- covers three types and only one of them fills: a regression or a standard
//--- deviation channel has no fill property, so for those two the FILL slot keeps
//--- writing the MASTER's own property (exactly what it did before the split)
//--- instead of stacking a second outline on top of the first.
bool DrawTypeHasFillChild(const int type)
{
   return (type == OBJ_RECTANGLE || type == OBJ_TRIANGLE || type == OBJ_ELLIPSE ||
           type == OBJ_CHANNEL   || type == OBJ_FIBOCHANNEL);
}

// ══════════════════════════════════════════════════════════════════════════
// THE CLASSIFIER. MT4's type answers the kind, with ONE refinement: a trend
// line that carries a ray is a different ANIMAL on the chart (it runs to the
// edge and back), so the kind is decided by the flags, not by the type alone —
// that is also what makes the RAY slot meaningful for those objects only.
// ══════════════════════════════════════════════════════════════════════════
//--- P-UNIFY-4: the TYPE map is its own function, so the profile's pen/look
//--- queries ask the same switch the classifier does - one owner, never a second list.
EDrawKind DrawKindOfType(const int t)
{
   switch(t)
   {
      case OBJ_TREND:          return DK_LINE;
      case OBJ_HLINE:          return DK_HLINE;
      case OBJ_VLINE:          return DK_VLINE;
      case OBJ_CHANNEL:
      case OBJ_STDDEVCHANNEL:
      case OBJ_REGRESSION:     return DK_CHANNEL;
      case OBJ_FIBO:
      case OBJ_FIBOTIMES:      return DK_FIBO;
      case OBJ_FIBOFAN:
      case OBJ_FIBOARC:        return DK_FIBOFAN;
      case OBJ_FIBOCHANNEL:    return DK_FIBOCHAN;
      case OBJ_EXPANSION:      return DK_EXPANSION;
      case OBJ_GANNLINE:
      case OBJ_GANNFAN:
      case OBJ_GANNGRID:       return DK_GANN;
      case OBJ_PITCHFORK:      return DK_PITCHFORK;
      case OBJ_RECTANGLE:      return DK_RECT;
      case OBJ_TRIANGLE:       return DK_TRIANGLE;
      case OBJ_ELLIPSE:        return DK_ELLIPSE;
      case OBJ_ARROW:          return DK_ARROW;
      case OBJ_TEXT:           return DK_TEXT;
      case OBJ_TRENDBYANGLE:   return DK_TANGLE;   // P-UNIFY-2
      case OBJ_CYCLES:         return DK_CYCLES;   // P-UNIFY-2
      default:                 return DK_NONE;
   }
}
EDrawKind DrawKindOf(const string name)
{
   if(DrawIsHTFObject(name)) return DK_NONE;  // HTF candles are indicator overlays, never user drawings
   if(BoxIsMidChild(name)) return DK_NONE;    // P-DRAW-21: a box helper is served never
   if(FillIsChild(name))   return DK_NONE;    // P-DRAW-64: nor an interior's child
   if(FibPenIsChild(name)) return DK_NONE;    // P-DRAW-74b: nor the fibo's stacked pen
   if(FibPenFamIsChild(name)) return DK_NONE;   // P-LOOK: nor a look's caps or wash
   if(PenStackIsChild(name)) return DK_NONE;   // P-DRAW-74c: nor the line pen's rows - served, hit and learned never
   int t = DrawObjectType(name);
   if(t < 0) return DK_NONE;
   return DrawKindOfType(t);
}

// THE TABLE. A kind's mask is its whole toolbar — the strip reads nothing else.
int DrawKindCaps(const EDrawKind k)
{
   switch(k)
   {
      case DK_LINE:      return DRAW_CAP_COMMON | DRAW_CAP_RAY;
      case DK_HLINE:
      case DK_VLINE:     return DRAW_CAP_COMMON;
      // P-DRAW-64: the five FILLER kinds carry the interior too (FILL shows it,
      // FILLCLR is its colour), and the six LEVEL kinds' second colour IS their
      // levels (`OBJPROP_LEVELCOLOR`) — so every kind in the tool set that really
      // has a second colour shows the cell, and no other kind grows a control that
      // would only repeat the colour cell (C-04).
      //--- P-DRAW-64a: BOTH BOX EXTRAS ARE THE RECTANGLE'S ALONE. The 50 % is a line at
      //--- the box's own mid PRICE and the travelling edge is its far anchor, and both
      //--- are written for OBJ_RECTANGLE — a channel's third anchor and an ellipse's are
      //--- not that price, so a control there would be a promise nothing keeps (C-04:
      //--- no control where nothing would happen).
      case DK_CHANNEL:   return DRAW_CAP_COMMON | DRAW_CAP_FILL | DRAW_CAP_FILLCLR;
      //--- P-DRAW-BODY: the six kinds that draw a body AND a level family now carry the
      //--- body's own three seats beside the levels' three — two pictures, two sets.
      case DK_FIBO:
      case DK_FIBOFAN:   return DRAW_CAP_COMMON | DRAW_CAP_FILLCLR | DRAW_CAP_BODY;
      case DK_FIBOCHAN:  return DRAW_CAP_COMMON | DRAW_CAP_FILL | DRAW_CAP_FILLCLR | DRAW_CAP_BODY;
      case DK_EXPANSION: return DRAW_CAP_COMMON | DRAW_CAP_FILLCLR | DRAW_CAP_BODY;
      case DK_GANN:      return DRAW_CAP_COMMON;
      case DK_PITCHFORK: return DRAW_CAP_COMMON | DRAW_CAP_FILLCLR | DRAW_CAP_BODY;
      case DK_RECT:      return DRAW_CAP_COMMON | DRAW_CAP_FILL | DRAW_CAP_FILLCLR |
                                DRAW_CAP_BOXHALF | DRAW_CAP_EXTEND;
      case DK_TRIANGLE:
      case DK_ELLIPSE:   return DRAW_CAP_COMMON | DRAW_CAP_FILL | DRAW_CAP_FILLCLR;
      // P-DRAW-09a: the two kinds whose OWN dialogs are the worst of the family —
      // a text's size and an arrow's code number — get their control in the strip.
      case DK_ARROW:     return (DRAW_CAP_COMMON & ~DRAW_CAP_STYLE) | DRAW_CAP_GLYPH;
      case DK_TEXT:      return (DRAW_CAP_COMMON & ~(DRAW_CAP_WIDTH | DRAW_CAP_STYLE)) | DRAW_CAP_FONT;
      //--- P-UNIFY-2: the two kinds that had NO kind. Both are plain objects, so the six
      //--- common cells answer; no RAY seat until a write is proven to draw (C-04).
      case DK_TANGLE:
      case DK_CYCLES:    return DRAW_CAP_COMMON;
      default:           return 0;
   }
}

bool DrawSlotAvailable(const EDrawKind k, const int slot)
{
   if(slot < 0 || slot >= DRAW_SLOT_N) return false;
   return ((DrawKindCaps(k) & (1 << slot)) != 0);
}

//--- the level family: every kind whose object really CARRIES line-levels, so its look
//--- lives on per-LEVEL colours. P-DRAW-145: the three Gann objects are NOT on this list
//--- (OBJPROP_LEVELS is 0, so every level write was a loop over zero rows).
bool DrawKindHasLevels(const EDrawKind k)
{
   return (k == DK_FIBO || k == DK_FIBOFAN || k == DK_FIBOCHAN ||
           k == DK_EXPANSION || k == DK_PITCHFORK);
}

//--- P-UNIFY-4: THE PROFILE. Every kind has one row: how its points become seats,
//--- which pen owns its width, and which looks the STYLE slot may offer.
void DrawKindProfileGet(const EDrawKind k, DrawKindProfile &p)
{
   p.geom = DKG_NONE;
   p.pen = DKPEN_NONE;
   p.lookMask = 0;
   if(DrawKindHasLevels(k)) p.geom = DKG_LEVEL;
   switch(k)
   {
      case DK_LINE:
      case DK_TANGLE:
      case DK_HLINE:
      case DK_VLINE:
         p.geom = DKG_LINE;
         p.pen = DKPEN_OBJECT;
         break;
      case DK_CHANNEL:
      case DK_GANN:
      case DK_RECT:
      case DK_TRIANGLE:
      case DK_ELLIPSE:
      case DK_CYCLES:
         p.geom = DKG_SHAPE;
         p.pen = DKPEN_OBJECT;
         break;
      case DK_FIBO:
      case DK_FIBOFAN:
      case DK_FIBOCHAN:
      case DK_EXPANSION:
         p.pen = DKPEN_LEVEL;
         p.lookMask = DRAW_LOOK_ALL;
         break;
      case DK_PITCHFORK:
         //--- P-UNIFY-3: its rails ARE its level family; a whole-object copy would
         //--- carry a copy of the levels, so it keeps the native fold and no look.
         break;
      case DK_ARROW:
      case DK_TEXT:
         p.geom = DKG_POINT;
         break;
      default:
         break;
   }
}

int DrawKindGeom(const EDrawKind k)
{
   DrawKindProfile p;
   DrawKindProfileGet(k, p);
   return p.geom;
}
int DrawKindPenFamily(const EDrawKind k)
{
   DrawKindProfile p;
   DrawKindProfileGet(k, p);
   return p.pen;
}
int DrawKindLookMask(const EDrawKind k)
{
   DrawKindProfile p;
   DrawKindProfileGet(k, p);
   return p.lookMask;
}

//--- THE FOUR OBJECT-LEVEL REFUSALS. The kind says "the level pen can state this
//--- drawing"; the TYPE says whether the terminal really draws the lines the pen would
//--- state. A time-zones fibo's levels are vertical, an arc's are a circle, and a
//--- regression / standard-deviation channel has no fill body the object pen could copy.
int DrawTypePenFamily(const int t)
{
   if(t == OBJ_FIBOTIMES || t == OBJ_FIBOARC) return DKPEN_NONE;
   if(t == OBJ_STDDEVCHANNEL || t == OBJ_REGRESSION) return DKPEN_NONE;
   return DrawKindPenFamily(DrawKindOfType(t));
}
int DrawTypeLookMask(const int t)
{
   if(DrawTypePenFamily(t) != DKPEN_LEVEL) return 0;
   return DrawKindLookMask(DrawKindOfType(t));
}

//--- P-UNIFY-4: the look vocabulary's ONE translator. Slot 5.. are looks; the three
//--- native-style consumers below no longer know the offset.
int DrawLookCount()
{
   return DRAW_LOOK_COUNT;
}
bool DrawLookValid(const int lk)
{
   return (lk >= DRAW_LOOK_NEON && lk <= DRAW_LOOK_WASH);
}
int DrawLookFromSlot(const int st)
{
   if(st <= (int)STYLE_DASHDOTDOT) return 0;
   int lk = st - (int)STYLE_DASHDOTDOT;
   return (DrawLookValid(lk) ? lk : 0);
}
int DrawLookToSlot(const int lk)
{
   return (DrawLookValid(lk) ? (int)STYLE_DASHDOTDOT + lk : -1);
}
int DrawLookNative(const int lk)
{
   if(lk == DRAW_LOOK_NEON) return (int)STYLE_DASH;
   if(DrawLookValid(lk))    return (int)STYLE_SOLID;
   return -1;
}
string DrawLookName(const int lk)
{
   if(lk == DRAW_LOOK_NEON) return "Neon";
   if(lk == DRAW_LOOK_CAPS) return "Caps";
   if(lk == DRAW_LOOK_WASH) return "Wash";
   return "";
}

// ══════════════════════════════════════════════════════════════════════════
// THE HIT TEST, IN PIXELS.
//
// Every anchor is projected with `ChartTimePriceToXY` (the conversion this
// codebase already proved works — P-UI-50) and the cursor is compared against
// the object's DRAWN shape. The shapes are the ones a trader actually aims at:
//   * a horizontal line   → its row,
//   * a vertical line     → its column,
//   * a segment           → the distance to the segment, extended by the ray
//                           flags (a ray has no far end, so the projection is
//                           clamped on the side that exists),
//   * a rectangle family  → its border (and its inside when FILL is on, because
//                           then the inside IS drawn),
//   * the fibo family     → every LEVEL line the object draws,
//   * an arrow or a text  → a small box around its one anchor.
// ══════════════════════════════════════════════════════════════════════════
bool DrawAnchorXY(const string name, const int idx, int &x, int &y)
{
   datetime t = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, idx);
   double   p = ObjectGetDouble(0, name, OBJPROP_PRICE, idx);
   if(t <= 0 || !(p > 0.0)) return false;
   if(!ChartTimePriceToXY(0, 0, t, p, x, y)) return false;
   return true;
}

//--- the distance from (px,py) to the segment (x1,y1)-(x2,y2), with the ends
//--- CLAMPED or OPEN per the ray flags. `openA` = the first end runs on for
//--- ever (RAY_LEFT), `openB` = the second (RAY_RIGHT).
double DrawSegDist(const int px, const int py,
                   const int x1, const int y1, const int x2, const int y2,
                   const bool openA, const bool openB)
{
   double dx = (double)(x2 - x1), dy = (double)(y2 - y1);
   double len2 = dx * dx + dy * dy;
   if(len2 <= 0.0) return MathSqrt((double)((px - x1) * (px - x1) + (py - y1) * (py - y1)));
   double u = ((double)(px - x1) * dx + (double)(py - y1) * dy) / len2;
   if(!openA && u < 0.0) u = 0.0;          // the first end stops here
   if(!openB && u > 1.0) u = 1.0;          // the second end stops here
   double cx = x1 + u * dx, cy = y1 + u * dy;
   return MathSqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
}

//--- the level prices of a level family, straight off the object — the TERMINAL's own
//--- law (P-LOOK-ANCHOR, measured 2026-10-18, label-verified to 1 px): level k is drawn
//--- at `p2 + (p1 - p2) * value_k`, 0 % at the SECOND anchor. Counted through
//--- OBJPROP_LEVELS so a fibo with a trimmed level set is measured as it is DRAWN.
int DrawLevelCount(const string name)
{
   int n = (int)ObjectGetInteger(0, name, OBJPROP_LEVELS);
   if(n < 0) n = 0;
   if(n > 64) n = 64;
   return n;
}
double DrawLevelValue(const string name, const int k)
{
   return ObjectGetDouble(0, name, OBJPROP_LEVELVALUE, k);
}

//--- P-UNIFY-3 (2026-10-19) - THE LEVEL FAMILY'S GEOMETRY IS THE KIND'S, NOT THE FIBO'S.
//--- A plain Fibo draws HORIZONTAL rows between its two anchors (P-LOOK-ANCHOR), a Fibo
//--- Fan draws RAYS from the first anchor to the second's own vertical, a Fibo Channel's
//--- levels are PARALLELS of the base through the first pair at `v` times the third
//--- anchor's channel width, and an Expansion projects HORIZONTAL levels from the THIRD
//--- anchor plus `v` waves of the first pair. One law, asked by the pen and both hit tests.
double DrawLevelPriceAt(const EDrawKind k, const double v,
                        const datetime ta, const double pa,
                        const datetime tb, const double pb,
                        const datetime t3, const double p3,
                        const datetime at)
{
   if(k == DK_FIBOFAN)
   {
      double pe = pb + (pa - pb) * v;
      if(tb == ta) return pa;
      return pa + (pe - pa) * ((double)((long)at - (long)ta) / (double)((long)tb - (long)ta));
   }
   if(k == DK_FIBOCHAN)
   {
      if(tb == ta || t3 <= 0 || !(p3 > 0.0)) return pa + v * (p3 - pa);
      double span = (double)((long)tb - (long)ta);
      double f  = (double)((long)at - (long)ta) / span;
      double f3 = (double)((long)t3 - (long)ta) / span;
      double w  = p3 - (pa + (pb - pa) * f3);
      return (pa + (pb - pa) * f) + v * w;
   }
   if(k == DK_EXPANSION)
      return p3 + (pb - pa) * v;   //--- the third anchor plus the first wave
   return pb + (pa - pb) * v;      //--- DK_FIBO/FIBOTIMES and the families this law already served
}

//--- THE LEVEL FAMILY'S LOOK IS PER LEVEL in MT4: each level carries its own
//--- colour, style and width, so "the whole family" is a LOOP, never one call —
//--- and a level the loop skips is a line the user sees unchanged.
void DrawLevelsSetColor(const string name, const color c)
{
   int n = DrawLevelCount(name);
   for(int k = 0; k < n; k++) ObjectSetInteger(0, name, OBJPROP_LEVELCOLOR, k, c);
   FibPenSync(name, false);   // P-DRAW-74b: children wear the level's ink
}
void DrawLevelsSetWidth(const string name, const int w)
{
   int n = DrawLevelCount(name);
   for(int k = 0; k < n; k++) ObjectSetInteger(0, name, OBJPROP_LEVELWIDTH, k, w);
   FibPenTagDrop(name);   // P-DRAW-74b: truth is explicit again — a remembered width would lie
   FibPenSync(name, false);   // P-DRAW-74b: the pen the terminal cannot draw steps down here
}
void DrawLevelsSetStyle(const string name, const int st)
{
   int n = DrawLevelCount(name);
   for(int k = 0; k < n; k++) ObjectSetInteger(0, name, OBJPROP_LEVELSTYLE, k, st);
   FibPenSync(name, false);   // P-DRAW-74b
}

bool DrawHitLevels(const string name, const int px, const int py)
{
   int n = DrawLevelCount(name);
   if(n <= 0) return false;
   datetime t1 = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 0);
   datetime t2 = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 1);
   double   p1 = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);
   double   p2 = ObjectGetDouble(0, name, OBJPROP_PRICE, 1);
   if(t1 <= 0 || !(p1 > 0.0) || !(p2 > 0.0)) return false;
   //--- P-UNIFY-3: the level's TWO ends are the kind's own geometry. The three-anchor
   //--- kinds (channel, expansion) read the third anchor here; every other family
   //--- answers the horizontal law it always did.
   EDrawKind k = DrawKindOf(name);
   bool three = (k == DK_FIBOCHAN || k == DK_EXPANSION);
   datetime t3 = three ? (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 2) : 0;
   double   p3 = three ? ObjectGetDouble(0, name, OBJPROP_PRICE, 2) : 0.0;
   if(three && (t3 <= 0 || !(p3 > 0.0))) return false;
   int xa = 0, ya = 0, xb = 0, yb = 0;
   for(int k1 = 0; k1 < n; k1++)
   {
      double v = DrawLevelValue(name, k1);
      if(!MathIsValidNumber(v)) continue;
      double la = DrawLevelPriceAt(k, v, t1, p1, t2, p2, t3, p3, t1);
      double lb = DrawLevelPriceAt(k, v, t1, p1, t2, p2, t3, p3, t2);
      if(!(la > 0.0) || !(lb > 0.0)) continue;
      if(!ChartTimePriceToXY(0, 0, t1, la, xa, ya)) continue;
      if(!ChartTimePriceToXY(0, 0, t2, lb, xb, yb)) continue;
      if(DrawSegDist(px, py, xa, ya, xb, yb, false, false) <= (double)DRAW_HIT_PX)
         return true;
   }
   return false;
}

bool DrawHitObject(const string name, const int px, const int py)
{
   EDrawKind k = DrawKindOf(name);
   if(k == DK_NONE) return false;
   int x1 = 0, y1 = 0, x2 = 0, y2 = 0;
   int tol = DRAW_HIT_PX;

   switch(k)
   {
      case DK_HLINE:
      {
         if(!DrawAnchorXY(name, 0, x1, y1)) return false;
         return (MathAbs(py - y1) <= tol);
      }
      case DK_VLINE:
      {
         if(!DrawAnchorXY(name, 0, x1, y1)) return false;
         return (MathAbs(px - x1) <= tol);
      }
      case DK_ARROW:
      case DK_TEXT:
      {
         if(!DrawAnchorXY(name, 0, x1, y1)) return false;
         // the glyph's own box: 10 px around the anchor reads as "on it"
         return (MathAbs(px - x1) <= 10 && MathAbs(py - y1) <= 10);
      }
      case DK_LINE:
      case DK_TANGLE:   // P-UNIFY-2: the same drawn shape as a trend - one segment
      {
         if(!DrawAnchorXY(name, 0, x1, y1)) return false;
         if(!DrawAnchorXY(name, 1, x2, y2)) return false;
         bool oA = ((int)ObjectGetInteger(0, name, OBJPROP_RAY_LEFT) != 0);
         bool oB = ((int)ObjectGetInteger(0, name, OBJPROP_RAY_RIGHT) != 0);
         return (DrawSegDist(px, py, x1, y1, x2, y2, oA, oB) <= (double)tol);
      }
      //--- P-UNIFY-2: a cycles object draws a fan of VERTICALS at t1 + k*P, P = |t2-t1|.
      //--- The pick asks the terminal where the cursor's own period stands and probes it
      //--- and its two neighbours - three time->x conversions, never a chart-wide sweep,
      //--- and the answer is the drawn position in PIXELS (weekend gaps included, which
      //--- a pixel-modulo would get wrong).
      case DK_CYCLES:
      {
         datetime ta = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 0);
         datetime tb = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 1);
         double pa = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);
         if(ta <= 0 || tb <= 0 || !(pa > 0.0)) return false;
         if(!DrawAnchorXY(name, 0, x1, y1)) return false;
         long per = (long)tb - (long)ta;
         if(per == 0) return (MathAbs(px - x1) <= tol);
         if(per < 0) per = -per;
         int sub = 0; datetime tc = 0; double pc = 0.0;
         if(!ChartXYToTimePrice(0, px, py, sub, tc, pc)) return false;
         long d = ((long)tc - (long)ta) / per;
         for(int ci = -1; ci <= 1; ci++)
         {
            int vx = 0, vy = 0;
            if(!ChartTimePriceToXY(0, 0, (datetime)((long)ta + (d + ci) * per), pa, vx, vy)) continue;
            if(MathAbs(px - vx) <= tol) return true;
         }
         return false;
      }
      case DK_CHANNEL:
      case DK_FIBOCHAN:
      case DK_GANN:
      case DK_PITCHFORK:
      {
         // the multi-line families: the FIRST two anchors name the span, and the
         // rails are the LEVELS (channels, fibo channels, gann fans, pitchforks
         // all draw them that way). Both are measured, so such an object is
         // grabbed by any line it draws — the way it is drawn.
         if(DrawAnchorXY(name, 0, x1, y1) && DrawAnchorXY(name, 1, x2, y2) &&
            DrawSegDist(px, py, x1, y1, x2, y2, false, false) <= (double)tol)
            return true;
         return DrawHitLevels(name, px, py);
      }
      case DK_RECT:
      case DK_TRIANGLE:
      case DK_ELLIPSE:
      {
         if(!DrawAnchorXY(name, 0, x1, y1)) return false;
         if(!DrawAnchorXY(name, 1, x2, y2)) return false;
         int xa = MathMin(x1, x2), xb = MathMax(x1, x2);
         int ya = MathMin(y1, y2), yb = MathMax(y1, y2);
         bool filled = ((int)ObjectGetInteger(0, name, OBJPROP_FILL) != 0);
         if(filled && px >= xa - tol && px <= xb + tol && py >= ya - tol && py <= yb + tol)
            return true;
         // P-DRAW-08g (the user's own report): A BOX IS HELD FROM THE INSIDE.
         // The border-only test below is MT4's own pick, and it is why «نگه میدارم
         // چیزی بالا نمیاد» — a hollow rectangle, triangle or ellipse is grabbed
         // in the middle by every trader alive, and the hold found nothing there.
         // The inside is therefore part of the shape this module serves, and the
         // border test stays for the drawing that is only an outline on screen
         // (the fill flag decides which is honest).
         if(px >= xa && px <= xb && py >= ya && py <= yb) return true;
         // the BORDER: the four edges, each a segment
         if(DrawSegDist(px, py, xa, ya, xb, ya, false, false) <= (double)tol) return true;
         if(DrawSegDist(px, py, xb, ya, xb, yb, false, false) <= (double)tol) return true;
         if(DrawSegDist(px, py, xb, yb, xa, yb, false, false) <= (double)tol) return true;
         if(DrawSegDist(px, py, xa, yb, xa, ya, false, false) <= (double)tol) return true;
         return false;
      }
      case DK_FIBO:
      case DK_FIBOFAN:
      case DK_EXPANSION:
         return DrawHitLevels(name, px, py);
      default:
         return false;
   }
}

//--- P-UI-113h (2026-09-24): THE TERMINAL'S SELECTED HANDLES BELONG TO THE DRAWING.
//--- MT4 paints a rectangle/ellipse with nine controls when selected - four corners,
//--- four side midpoints and the centre - while OBJPROP_TIME/PRICE expose only the
//--- two diagonal construction anchors. Testing only 0..1 therefore recognises two
//--- of the visible controls and misses the very points the hand is on. The
//--- multi-point families have a third construction anchor; one-point families do
//--- not. This is a click-TARGET fact, never a drag: it is read only after
//--- DrawHitObject says the cursor is not already on the drawn shape.
bool DrawHitSelectedHandle(const string name, const int px, const int py)
{
   EDrawKind k = DrawKindOf(name);
   if(k == DK_RECT || k == DK_ELLIPSE)
   {
      int x1 = 0, y1 = 0, x2 = 0, y2 = 0;
      if(!DrawAnchorXY(name, 0, x1, y1) || !DrawAnchorXY(name, 1, x2, y2)) return false;
      int xa = MathMin(x1, x2), xb = MathMax(x1, x2);
      int ya = MathMin(y1, y2), yb = MathMax(y1, y2);
      int mx = (xa + xb) / 2, my = (ya + yb) / 2;
      int hx[9], hy[9];
      hx[0] = xa;  hy[0] = ya;   // corners
      hx[1] = xb;  hy[1] = ya;
      hx[2] = xb;  hy[2] = yb;
      hx[3] = xa;  hy[3] = yb;
      hx[4] = mx;  hy[4] = ya;   // side midpoints
      hx[5] = mx;  hy[5] = yb;
      hx[6] = xa;  hy[6] = my;
      hx[7] = xb;  hy[7] = my;
      hx[8] = mx;  hy[8] = my;   // centre control
      for(int i = 0; i < 9; i++)
         if(MathAbs(px - hx[i]) <= DRAW_SELECTED_HANDLE_PX &&
            MathAbs(py - hy[i]) <= DRAW_SELECTED_HANDLE_PX) return true;
      return false;
   }

   int count = 3;   // channel / pitchfork and the other three-anchor families
   if(k == DK_HLINE || k == DK_VLINE || k == DK_ARROW || k == DK_TEXT) count = 1;
   for(int i = 0; i < count; i++)
   {
      int x = 0, y = 0;
      if(!DrawAnchorXY(name, i, x, y)) continue;
      if(MathAbs(px - x) <= DRAW_SELECTED_HANDLE_PX &&
         MathAbs(py - y) <= DRAW_SELECTED_HANDLE_PX) return true;
   }
   return false;
}

// ══════════════════════════════════════════════════════════════════════════
// THE TWO ANSWERS TO "WHICH DRAWING IS UNDER THE CURSOR?".
//
// `DrawSelectedObjectAt` is the terminal's OWN answer: MT4 selects the object
// it grabs on the press. It is asked first, but only after the cursor is proven
// to be on that selected object's drawn shape or one of its visible controls -
// selection alone is not a cursor hit.
//
// `DrawObjectAt` is the measured answer, for the builds and the moments the
// terminal's selection does not arrive (P-UI-49c's own lesson: the pick-up is
// not something to depend on alone). It walks the chart from the NEWEST object
// backwards — the last created is the one on top of the pile in practice — and
// returns the first shape the cursor is really on.
//
// Both refuse the indicator's own objects: the harmonics, the levels, the
// boxes and the panels have their own owners (the user's order).
// ══════════════════════════════════════════════════════════════════════════
string DrawSelectedObjectAt(const int px, const int py)
{
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string nm = ObjectName(0, i, -1, -1);
      if(nm == "" || DrawIsIndicatorObject(nm)) continue;
      if(DrawKindOf(nm) == DK_NONE) continue;
      if(!(bool)ObjectGetInteger(0, nm, OBJPROP_SELECTED)) continue;
      if(DrawHitObject(nm, px, py) || DrawHitSelectedHandle(nm, px, py)) return nm;
   }
   return "";
}

string DrawObjectAt(const int px, const int py)
{
   string sel = DrawSelectedObjectAt(px, py);
   if(sel != "") return sel;
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string nm = ObjectName(0, i, -1, -1);
      if(nm == "" || (DrawIsIndicatorObject(nm) && !DrawIsHRay(nm) && !DrawIsPathSeg(nm))) continue;   // P-HR-04/P-UI-136: rays and paths are served
      if(DrawKindOf(nm) == DK_NONE) continue;
      if(DrawHitObject(nm, px, py)) return nm;
   }
   return "";
}

// ══════════════════════════════════════════════════════════════════════════
// THE STYLE MEMORY — «آخرین تغییرات ذخیره بشه».
//
// ONE memory per KIND (not per object, not globally): the second fibo must look
// like the first one the user styled, and a fibo must not inherit a rectangle's
// fill. Five numbers cover every kind — colour, width, style, fill, ray — and
// `s_dkValid[k]` is what tells "the user has styled this kind once" from "this
// is still the factory look", so a kind the user never touched is left exactly
// as the terminal would have drawn it.
// ══════════════════════════════════════════════════════════════════════════
static bool  s_dkValid[DK_COUNT];
static color s_dkColor[DK_COUNT];
static color s_dkFillClr[DK_COUNT];  // P-DRAW-64: the interior's colour this kind last wore
static int   s_dkWidth[DK_COUNT];
static int   s_dkStyle[DK_COUNT];
static bool  s_dkFill[DK_COUNT];
static int   s_dkRay[DK_COUNT];      // 0 none · 1 right · 2 left · 3 both
//--- P-DRAW-09a: the three new slots are LOOKS like the five above, so they are
//--- learned the same way — a caption size and a mark the user chose are theirs
//--- for the next one too, not a per-object whim.
static int   s_dkFont[DK_COUNT];     // OBJ_TEXT caption size (points)
static int   s_dkGlyph[DK_COUNT];    // OBJ_ARROW Wingdings code
static bool  s_dkBack[DK_COUNT];     // draw as background
//--- P-DRAW-INK (2026-10-04) — THE ONE INK EVERY KIND SHARES. The nine slots above
//--- answer "what did THIS kind last wear"; this one answers the question the hand's
//--- own report asks («چرا رنگش پیش‌فرض که میکشم سفید هستش؟ آخرین تغییرات آبی بود») —
//--- which colour did the LAST pick paint, whichever kind it painted. A kind that
//--- has no colour of its own takes it at birth (a first-ever fibo wears the blue
//--- the last trendline was), and the same file carries it across an attach. It is a
//--- FALLBACK, never a write over a kind's own colour: the memory of P-DRAW-48/75
//--- is asked first, this answers only when that memory is empty.
static color s_dkAnyClr = clrNONE;

void DrawStyleInit()
{
   for(int k = 0; k < DK_COUNT; k++)
   {
      s_dkValid[k] = false;
      s_dkColor[k] = clrNONE;
      //--- P-DRAW-64: `clrNONE` is the "no color of its own yet" of the interior —
      //--- a zero-initialised `color` is BLACK, which would be a colour the user
      //--- never chose (the P-DRAW-48 lesson, one slot over).
      s_dkFillClr[k] = clrNONE;
      s_dkWidth[k] = 1;
      s_dkStyle[k] = (int)STYLE_SOLID;
      s_dkFill[k]  = false;
      s_dkRay[k]   = 0;
      s_dkFont[k]  = DRAW_FONT_DEF;
      s_dkGlyph[k] = 0;
      s_dkBack[k]  = false;
   }
   //--- P-DRAW-INK: an empty memory has no last ink either — the file's own row puts
   //--- it back (DrawTplLoad via DrawTplBoot), so the reset must not leave yesterday's
   //--- blue behind.
   s_dkAnyClr = clrNONE;
}

//--- "#RRGGBB" of a colour, and back. Moved DOWN from DrawStrip by P-DRAW-48
//--- because the description tags below are the slot owner's and need both — a
//--- second parser would be a second answer to one question (A-12).
string DrawStripColorHex(const color c)
{
   int v = (int)c;
   if(v < 0) v = 0;
   return StringFormat("#%02X%02X%02X", v % 256, (v / 256) % 256, v / 65536);
}
//--- P-DRAW-48 (2026-09-27) — THE TAG FORM IS SIX DIGITS, AND THE READER OWNS THE
//--- '#'. `DrawStripColorHex` is the DISPLAY form (`#RRGGBB`); writing that into
//--- `[CL…]` and then prepending a second '#' in the reader made every tag
//--- unparseable, so `DrawSlotColorPure` answered false and every read fell back
//--- to the ALREADY blended `OBJPROP_COLOR` — the opacity bar re-blended its own
//--- last blend on every frame (see the note on `DrawSlotOpacitySet`). One owner
//--- for the written form, so writer and reader cannot drift apart again.
string DrawDescColorHex(const color c) { return StringSubstr(DrawStripColorHex(c), 1); }
bool DrawStripHexToColor(const string s, color &c)
{
   string t = s;
   StringTrimLeft(t); StringTrimRight(t);
   if(StringLen(t) != 7 || StringGetCharacter(t, 0) != '#') return false;
   int v = 0;
   for(int i = 1; i < 7; i++)
   {
      int ch = StringGetCharacter(t, i);
      int d = -1;
      if(ch >= '0' && ch <= '9') d = ch - '0';
      else if(ch >= 'A' && ch <= 'F') d = ch - 'A' + 10;
      else if(ch >= 'a' && ch <= 'f') d = ch - 'a' + 10;
      if(d < 0) return false;
      v = v * 16 + d;
   }
   int r = (v >> 16) & 0xFF, g = (v >> 8) & 0xFF, b = v & 0xFF;
   c = (color)(r + g * 256 + b * 65536);
   return true;
}

//--- P-DRAW-48 (2026-09-26) — THE DRAWING'S OPACITY, AND WHY IT RIDES THE DESC.
//--- MT4 gives a drawing ONE colour and no alpha, so opacity is emulated the way
//--- every level in this product already emulates it: the object WEARS the colour
//--- blended towards the chart's own background (`BlendColorTowardsBG`, the one
//--- owner of that blend). The colour the user PICKED must not be lost inside that
//--- write, so it is stored beside the opacity on the object's own DESCRIPTION —
//--- `[OP70] [CLFFC247]` — the P-DRAW-21/22 channel: it survives reattach, a TF
//--- switch and a restart, and the user's own text rides along verbatim. Reads
//--- answer the PURE colour, so the picker's ring and the HEX field show what the
//--- user chose, never the blend. A TEXT object's description IS its content, so
//--- those kinds keep the pure colour and carry no tag (their row says so).
#define DRAW_OP_DEF 100
#define DRAW_OP_MIN   1     // 0 would be the chart's own background: invisible is a lie
//--- set/replace ONE `[TAGvalue]`, keeping every other byte. The tag LEADS, so
//--- `BoxMarkWrite`'s `pre` (everything before ` [BX`) keeps it and the extras of
//--- P-DRAW-21/22 survive a colour write.
string DrawDescTag(const string d, const string tag, const string val)
{
   string out = d;
   int at = StringFind(out, tag);
   if(at >= 0)
   {
      int e = StringFind(out, "]", at + StringLen(tag));
      if(e > at) out = StringSubstr(out, 0, at) + StringSubstr(out, e + 1);
   }
   if(StringLen(out) > 0 && StringGetCharacter(out, 0) == ' ') out = StringSubstr(out, 1);
   string want = tag + val + "]";
   return (out == "") ? want : (want + " " + out);
}
//--- ONE value reader and ONE colour reader for every tag (`[OP…]`, `[FT…]`, `[CL…]`,
//--- `[FL…]`), so a tag can never be parsed two ways (A-12). A colour tag's '#' is
//--- OPTIONAL: a build that wrote the display form heals on the next read (P-DRAW-48).
int DrawDescTagValue(const string d, const string tag, const int def)
{
   int at = StringFind(d, tag);
   if(at < 0) return def;
   int e = StringFind(d, "]", at + StringLen(tag));
   if(e <= at) return def;
   int n = e - at - StringLen(tag);
   if(n <= 0) return def;
   return (int)StringToInteger(StringSubstr(d, at + StringLen(tag), n));
}
bool DrawDescTagColor(const string d, const string tag, color &c)
{
   int at = StringFind(d, tag);
   if(at < 0) return false;
   int e = StringFind(d, "]", at + StringLen(tag));
   if(e <= at) return false;
   string t = StringSubstr(d, at + StringLen(tag), e - at - StringLen(tag));
   StringTrimLeft(t); StringTrimRight(t);
   if(t == "") return false;
   if(StringGetCharacter(t, 0) != '#') t = "#" + t;
   return DrawStripHexToColor(t, c);
}
//--- the LINE/BORDER's own alpha (`[OP…]`).
int DrawSlotOpacityGet(const string name)
{
   if(name == "" || ObjectFind(0, name) < 0) return DRAW_OP_DEF;
   if(DrawKindOf(name) == DK_TEXT) return DRAW_OP_DEF;
   //--- P-UI-137: a path keeps its alpha in its OWN store, never in a `[OP…]` tag
   //--- (MT4 paints a desc along a trend line), so the read asks the path first.
   if(DrawIsPathSeg(name))
   {
      string pid = "";
      if(PathIdOfName(name, pid)) return PathInkOpacityGet(pid);
   }
   int v = DrawDescTagValue(ObjectGetString(0, name, OBJPROP_TEXT), "[OP", DRAW_OP_DEF);
   if(v < DRAW_OP_MIN) v = DRAW_OP_MIN;
   if(v > 100) v = 100;
   return v;
}
//--- P-DRAW-64: the INTERIOR's own alpha, as `[FT…]`. Its DEFAULT is the border's
//--- value, so a drawing made before the split wears exactly the pixels it wore (the
//--- interior was that colour at that alpha) and the user's own tone takes over the
//--- moment the tag exists. 100 is FULL and 0 is the chart's background — the same
//--- direction as `[OP…]`, through the one blend owner.
int DrawSlotFillOpacityGet(const string name)
{
   if(name == "" || ObjectFind(0, name) < 0) return DRAW_OP_DEF;
   if(DrawKindOf(name) == DK_TEXT) return DRAW_OP_DEF;
   string d = ObjectGetString(0, name, OBJPROP_TEXT);
   if(StringFind(d, "[FT") < 0) return DrawSlotOpacityGet(name);
   int v = DrawDescTagValue(d, "[FT", 0);
   if(v < 0) v = 0;
   if(v > 100) v = 100;
   return v;
}
//--- "the alpha of THIS color slot" — the bar the user drags and the render the
//--- chart wears both ask it, so the two cannot drift.
int DrawSlotAlphaGet(const string name, const int slot)
{
   return (slot == DRAW_SLOT_FILLCLR) ? DrawSlotFillOpacityGet(name)
                                      : DrawSlotOpacityGet(name);
}
//--- the LINE/BORDER's pure colour (`[CL…]`), or false when it has none yet.
bool DrawSlotColorPure(const string name, color &c)
{
   if(name == "" || ObjectFind(0, name) < 0) return false;
   if(DrawKindOf(name) == DK_TEXT) return false;
   return DrawDescTagColor(ObjectGetString(0, name, OBJPROP_TEXT), "[CL", c);
}
//--- P-DRAW-64: the INTERIOR's pure colour (`[FL…]`), or false when it has none yet.
bool DrawSlotFillPure(const string name, color &c)
{
   if(name == "" || ObjectFind(0, name) < 0) return false;
   if(DrawKindOf(name) == DK_TEXT) return false;
   return DrawDescTagColor(ObjectGetString(0, name, OBJPROP_TEXT), "[FL", c);
}
//--- the RENDER colour: what the chart must wear for this pure colour at the
//--- object's own opacity.
color DrawSlotRenderColor(const string name, const color pure)
{
   return BlendColorTowardsBG(pure, 100 - DrawSlotOpacityGet(name),
                              GetCachedChartBgColor());
}
//--- P-DRAW-64: the same question for the INTERIOR, at the INTERIOR's own tone.
//--- The one place the interior's pixels are computed, so the child, the level
//--- family and the strip's own swatch can never disagree about the tone.
color DrawSlotRenderFillColor(const string name, const color pure)
{
   return BlendColorTowardsBG(pure, 100 - DrawSlotFillOpacityGet(name),
                              GetCachedChartBgColor());
}
//--- the colour write's tag half: the PURE goes on the description, the object
//--- wears the blend. Returns what the chart must wear.
color DrawSlotColorStore(const string name, const color pure)
{
   if(name == "" || ObjectFind(0, name) < 0) return pure;
   if(DrawKindOf(name) == DK_TEXT) return pure;
   string d = ObjectGetString(0, name, OBJPROP_TEXT);
   d = DrawDescTag(d, "[CL", DrawDescColorHex(pure));
   ObjectSetString(0, name, OBJPROP_TEXT, d);
   return DrawSlotRenderColor(name, pure);
}
// ══════════════════════════════════════════════════════════════════════════
// P-DRAW-64a (2026-09-27) — THE BOX'S MARK GROUP, MOVED DOWN TO THE SLOTS.
// `[BX…]` (the 50% mid line and the far-edge behaviour, P-DRAW-21/22) lived in
// DrawStrip.mqh. The two extras are SLOTS now — the user wants them one tap away
// in the strip's own row — and a slot is read and written HERE, where MQL4's
// define-before-use rule puts the group's one reader and one writer. The GEOMETRY
// the marks drive (the mid child, the extend step, the pump) stays in DrawStrip.
// One group, one writer: `[BX50]`, `[BXE1]`/`[BXE2]`/`[BXE3:N]`.
// ══════════════════════════════════════════════════════════════════════════
#define BOXEXT_OFF   0
#define BOXEXT_TOUCH 1
#define BOXEXT_END   2
#define BOXEXT_NBARS 3
//--- P-DRAW-64a, THIRD cut (2026-09-27) — THE 50 % IS THE LEVEL, NOT THE LENGTH.
//--- User order: «خود باکس رو از وسط طول نصف میکنه که نباید باشه … فقط 50 درصد مثل
//--- فیبو که 50 درصد مشخص میشه». So the cell is the `[BX50]` MARK and nothing else: the
//--- mid line the more-popover already drew, at the box's own mid PRICE, drawn by
//--- `BoxMidSync` (DrawStrip) and owned there. NO anchor of the drawing is touched —
//--- the box keeps the length the hand gave it, and the interior is not a party to it
//--- either. That kills the whole `[BXH:<seconds>]` payload with it: a remembered
//--- length existed only to put back what the cell had cut, and the third cut cuts
//--- nothing, so `DrawBoxHalfSpan/Read/Write` and `BoxHalfRecheck` are GONE rather than
//--- left as a second way to say "half".
//--- P-UI-134 (2026-10-02) — THE MARKS ARE A KEY, NOT A SUBSTRING. The `[BX…]`
//--- design put two owners' state INSIDE a string that FOUR other owners rewrite
//--- (`[CL…]`, `[OP…]`, `[FL…]`, `[FT…]`), so every mark write had to re-serialise a
//--- string it does not own and then cut its own block out of it. Three attempts failed
//--- in a row: P-UI-133 fixed the cut point (`" [BX"` matched the space in front of the
//--- SECOND tag, so `pre` kept `[BX50]`), and the live box then refused BOTH marks to
//--- clear — `slot=11 … -> 0 read=1` AND `slot=12 … -> 0 read=1` («الان هیچکدوم درست
//--- کار نمیکنه»). A shared mutable string with four writers is not a serialisation; it
//--- is a parser racing three other parsers. **The architecture**: one keyed value per
//--- box in the TERMINAL'S OWN store — the same store `BaseKnotGV` already uses for
//--- per-box state (Biotak/BaseKnot_Base.mqh:802), so this is the project's existing
//--- pattern, not a new idea. Nothing is parsed, no block is cut, the mark owner never
//--- writes `OBJPROP_TEXT` again, and the legacy tags are READ ONCE (migration) and
//--- then left in place, inert.
//--- THE VALUE: an MQL4 global carries a double, so the three fields ride ONE integer
//--- (`fp << 22 | n << 12 | ext << 2 | mid`, exact well past 2^40). `fp` is a 20-bit
//--- fingerprint of the box's own NAME, so a key belonging to another box can never be
//--- believed, and a dead key heals to «no marks» instead of wearing someone else's.
#define BOXMARK_FP_MOD 1048576          // 2^20 — the fingerprint's space
string BoxMarkKey(const string name)
{
   long h = 5381;                      // djb2, truncated: stable across runs
   for(int i = 0; i < StringLen(name); i++)
      h = ((h * 33) + (long)StringGetCharacter(name, i)) % BOXMARK_FP_MOD;
   return "Biotak_BXM_" + IntegerToString((int)h) + "_" + GetCachedChartIdStr();
}
int BoxMarkFingerprint(const string name)
{
   long h = 5381;
   for(int i = 0; i < StringLen(name); i++)
      h = ((h * 33) + (long)StringGetCharacter(name, i)) % BOXMARK_FP_MOD;
   return (int)h;
}
//--- the legacy `[BX…]` format, parsed ONCE and never written again. PARSING a format
//--- you do not write is safe; WRITING it inside somebody else's string was the hazard.
void BoxMarkLegacyRead(const string d, bool &mid, int &ext, int &extN)
{
   mid = false; ext = BOXEXT_OFF; extN = 0;
   if(StringFind(d, "[BX50]") >= 0) mid = true;
   int at = StringFind(d, "[BXE");
   if(at < 0) return;
   string tail = StringSubstr(d, at + 4);
   if(StringLen(tail) < 1) return;
   string m = StringSubstr(tail, 0, 1);
   if(m == "1") ext = BOXEXT_TOUCH;
   else if(m == "2") ext = BOXEXT_END;
   else if(m == "3")
   {
      ext = BOXEXT_NBARS;
      int c = StringFind(tail, ":"), e = StringFind(tail, "]");
      if(c > 0 && e > c) extN = (int)StringToInteger(StringSubstr(tail, c + 1, e - c - 1));
      if(extN <= 0) ext = BOXEXT_OFF;
   }
}
void BoxMarkRead(const string name, bool &mid, int &ext, int &extN)
{
   mid = false; ext = BOXEXT_OFF; extN = 0;
   if(name == "" || ObjectFind(0, name) < 0) return;
   string key = BoxMarkKey(name);
   //--- the store is the census. One check per read; a present key costs one get, and
   //--- the fingerprint is verified BEFORE anything is believed (a 20-bit collision, or
   //--- a key left by an object that no longer exists, both fall through to migration).
   if(GlobalVariableCheck(key))
   {
      long v = (long)GlobalVariableGet(key);
      int md = (int)(v % 2); v /= 2;
      int ex = (int)(v % 4); v /= 4;
      int nn = (int)(v % 4096); v /= 4096;
      if((int)v == BoxMarkFingerprint(name))
      {
         mid = (md != 0);
         ext = ex;
         extN = (ex == BOXEXT_NBARS) ? nn : 0;
         return;
      }
   }
   //--- MIGRATION, once per box and only while the store is empty: adopt the legacy tags
   //--- and LEAVE THEM in the description. Cutting them would be one more edit of a
   //--- string four owners share — and inert text costs nothing.
   string d = ObjectGetString(0, name, OBJPROP_TEXT);
   if(StringFind(d, "[BX") < 0) return;
   bool lmid = false; int lext = BOXEXT_OFF, ln = 0;
   BoxMarkLegacyRead(d, lmid, lext, ln);
   if(lmid || lext != BOXEXT_OFF) BoxMarkWrite(name, lmid, lext, ln);
}
void BoxMarkWrite(const string name, const bool mid, const int ext, const int extN)
{
   if(name == "" || ObjectFind(0, name) < 0) return;
   string key = BoxMarkKey(name);
   //--- no marks = NO KEY. A box with nothing to remember owns nothing, so a plain
   //--- rectangle leaves no trace in the terminal's global list.
   if(!mid && ext == BOXEXT_OFF)
   {
      if(GlobalVariableCheck(key)) GlobalVariableDel(key);
      return;
   }
   int ex = (ext == BOXEXT_TOUCH) ? 1 : (ext == BOXEXT_END) ? 2 : (ext == BOXEXT_NBARS) ? 3 : 0;
   int nn = (ex == 3 && extN > 0 && extN < 4096) ? extN : 0;
   long v = BoxMarkFingerprint(name);
   v = v * 4096 + nn;
   v = v * 4 + ex;
   v = v * 2 + (mid ? 1 : 0);
   GlobalVariableSet(key, (double)v);
}
//--- the one place a box's key is DESTROYED: every delete path already calls
//--- `BoxMidDrop`/`FillChildDrop`, and this is their third sibling. MT4 reuses object
//--- names across sessions («Rectangle 17282» again), so a key that outlived its box
//--- would hand a fresh box a dead box's marks — the fingerprint cannot catch that
//--- (same name, same hash), only the delete can.
void BoxMarkDrop(const string name)
{
   if(name == "") return;
   string key = BoxMarkKey(name);
   if(GlobalVariableCheck(key)) GlobalVariableDel(key);
}

//--- read ONE slot off an object. `slot` is the strip's own index.
double DrawSlotRead(const string name, const int slot)
{
   if(name == "" || ObjectFind(0, name) < 0) return 0.0;
   EDrawKind k = DrawKindOf(name);
   bool lvl = (DrawKindHasLevels(k) && DrawLevelCount(name) > 0);
   switch(slot)
   {
      case DRAW_SLOT_COLOR:
      {
         // P-DRAW-48: what the user CHOSE is the description's `[CL…]`; the
         // object's own colour is that colour blended at its opacity.
         // P-UI-137: a path has no description — its PURE lives in the path's own
         // store, so the HEX field and the readout show the colour the user picked,
         // not the blend the chart wears.
         if(DrawIsPathSeg(name))
         {
            string pid = "";
            color pp = clrNONE; int pv = 100;
            if(PathIdOfName(name, pid) && PathInkGet(pid, pp, pv)) return (double)(int)pp;
         }
         color pure;
         if(DrawSlotColorPure(name, pure)) return (double)(int)pure;
         if(lvl) return (double)(int)ObjectGetInteger(0, name, OBJPROP_LEVELCOLOR, 0);
         return (double)(int)ObjectGetInteger(0, name, OBJPROP_COLOR);
      }
      case DRAW_SLOT_WIDTH:
         // P-DRAW-74b: a demoted level reads 1 — the LOGICAL width is the tag's.
         if(lvl) return (double)FibPenLogicalWidth(name, 0);
         // P-DRAW-74c: and a demoted LINE master reads 1 too — its children ARE the
         // memory. The child-0 probe alone decides (children exist only for this pen),
         // so a plain drawing pays one find and one read, never the whole classifier.
         {
            int pw = (int)ObjectGetInteger(0, name, OBJPROP_WIDTH);
            if(pw <= DRAW_WIDTH_MIN && ObjectFind(0, PenStackName(name, 0)) >= 0)
               return (double)PenStackLogicalWidth(name);
            return (double)pw;
         }
      case DRAW_SLOT_STYLE:
         // P-LOOK: a look answers 5/6/7/8; the terminal holds its native 0-4.
         // FibPenLookGet answers 0 outside 1..4, so a positive answer IS the look.
         if(lvl)
         {
            int lk = FibPenLookGet(name);
            if(lk > 0) return (double)DrawLookToSlot(lk);
            return (double)(int)ObjectGetInteger(0, name, OBJPROP_LEVELSTYLE, 0);
         }
         return (double)(int)ObjectGetInteger(0, name, OBJPROP_STYLE);
      case DRAW_SLOT_FILL:
      {
         // P-DRAW-64: for a FILLER kind the interior is the CHILD, so the flag means
         // "the interior is on the chart" — the child's existence, or the master's own
         // fill a build before the split left behind (adopted on the next sync, which
         // then clears it so two colours can coexist).
         if(DrawTypeHasFillChild(DrawObjectType(name)))
            return (((ObjectFind(0, FillChildName(name)) >= 0) ||
                     (int)ObjectGetInteger(0, name, OBJPROP_FILL) != 0) ? 1.0 : 0.0);
         return ((int)ObjectGetInteger(0, name, OBJPROP_FILL) != 0) ? 1.0 : 0.0;
      }
      case DRAW_SLOT_FILLCLR:
      {
         // P-DRAW-64: the user's own interior colour, else what the interior already
         // wears — the level family's level colour, or the LINE's own pure, so a
         // drawing made before the split answers the colour it is filled with.
         color ipure;
         if(DrawSlotFillPure(name, ipure)) return (double)(int)ipure;
         if(lvl) return (double)(int)ObjectGetInteger(0, name, OBJPROP_LEVELCOLOR, 0);
         return DrawSlotRead(name, DRAW_SLOT_COLOR);
      }
      //--- P-DRAW-64a: the box's own 50 % LEVEL, read off its mark group.
      case DRAW_SLOT_BOXHALF:
      {
         // P-UI-139: a path answers this cell from its OWN switch (the midpoint
         // markers); the rectangle answers it from the box's keyed marks store.
         if(DrawIsPathSeg(name))
         {
            string pid = "";
            if(PathIdOfName(name, pid)) return PathMidGet(pid) ? 1.0 : 0.0;
         }
         bool mid = false; int ext = BOXEXT_OFF, exn = 0;
         BoxMarkRead(name, mid, ext, exn);
         return (mid ? 1.0 : 0.0);
      }
      case DRAW_SLOT_EXTEND:
      {
         bool mid = false; int ext = BOXEXT_OFF, exn = 0;
         BoxMarkRead(name, mid, ext, exn);
         return ((ext != BOXEXT_OFF) ? 1.0 : 0.0);
      }
      case DRAW_SLOT_RAY:
      {
         int r = 0;
         if((int)ObjectGetInteger(0, name, OBJPROP_RAY_RIGHT) != 0) r |= 1;
         if((int)ObjectGetInteger(0, name, OBJPROP_RAY_LEFT) != 0)  r |= 2;
         return (double)r;
      }
      case DRAW_SLOT_LOCK:
         if(DrawIsHRay(name)) return 0.0;   // P-HR-04: the ray's lock is N/A (the dot carry replaces it)
      // P-UI-138: a PATH's lock is its OWN flag (Toolbar_B's write arms it, the press
      // branch asks it) — the read must answer the same owner or the cell could never
      // show the state the writer just set.
      if(DrawIsPathSeg(name))
      {
         string pid = "";
         if(PathIdOfName(name, pid)) return PathLockGet(pid) ? 1.0 : 0.0;
      }
         return ((bool)ObjectGetInteger(0, name, OBJPROP_SELECTABLE)) ? 0.0 : 1.0;
      //--- P-DRAW-09a: the three appended slots, read straight off the object.
      case DRAW_SLOT_FONT:
      {
         int fs = (int)ObjectGetInteger(0, name, OBJPROP_FONTSIZE);
         if(fs < DRAW_FONT_MIN || fs > DRAW_FONT_MAX) fs = DRAW_FONT_DEF;
         return (double)fs;
      }
      case DRAW_SLOT_GLYPH: return (double)(int)ObjectGetInteger(0, name, OBJPROP_ARROWCODE);
      case DRAW_SLOT_BACK:  return ((int)ObjectGetInteger(0, name, OBJPROP_BACK) != 0) ? 1.0 : 0.0;
      //--- P-DRAW-BODY: the body reads the object's OWN pair — the same three lines the
      //--- body's three seats write, so the cell can never show the levels' value.
      case DRAW_SLOT_BODYCOLOR: return (double)(color)(int)ObjectGetInteger(0, name, OBJPROP_COLOR);
      case DRAW_SLOT_BODYWIDTH:
      {
         int bw = (int)ObjectGetInteger(0, name, OBJPROP_WIDTH);
         if(bw < DRAW_WIDTH_MIN) bw = DRAW_WIDTH_MIN;
         if(bw > DRAW_WIDTH_MAX) bw = DRAW_WIDTH_MAX;
         return (double)bw;
      }
      case DRAW_SLOT_BODYSTYLE:
      {
         int bs = (int)ObjectGetInteger(0, name, OBJPROP_STYLE);
         if(bs < 0) bs = 0;
         if(bs > (int)STYLE_DASHDOTDOT) bs = (int)STYLE_DASHDOTDOT;
         return (double)bs;
      }
      default: return 0.0;
   }
}

//--- P-DRAW-64 — THE INTERIOR'S OWN CHILD (`<drawing>_FL`). ONE owner for "does this
//--- drawing show an interior, and of which colour": created while the FILL slot is
//--- on, the master's own MT4 shape and anchors, filled, in the BACKGROUND (a fill is
//--- a behind-the-bars layer — the product's own box fill has lived there since
//--- P-BK-58) and non-selectable, so the terminal's drag can only ever grab the
//--- master. Idempotent and guarded: a steady state costs reads, not writes.
//--- DROP first, then the maker and the state follower: MQL4 has no forward
//--- declarations, so every callee stands above its callers.
bool FillChildDrop(const string obj)
{
   if(obj == "") return false;
   string ch = FillChildName(obj);
   if(ObjectFind(0, ch) < 0) return false;
   return ObjectDelete(0, ch);
}
bool FillChildEnsure(const string obj)
{
   if(obj == "" || FillIsChild(obj)) return false;
   if(DrawIsIndicatorObject(obj)) return false;   // P-DRAW-64: the strip's scope, not the tool's
   if(ObjectFind(0, obj) < 0) return false;
   EDrawKind k = DrawKindOf(obj);
   if(!DrawKindHasFillBody(k)) return FillChildDrop(obj);
   int type = DrawObjectType(obj);
   if(!DrawTypeHasFillChild(type)) return FillChildDrop(obj);
   string ch = FillChildName(obj);
   // The master keeps ONLY its outline from now on: the interior is the child's
   // pixel, and the child's colour is the interior's own (it may differ).
   if((int)ObjectGetInteger(0, obj, OBJPROP_FILL) != 0)
      ObjectSetInteger(0, obj, OBJPROP_FILL, false);
   if(ObjectFind(0, ch) < 0)
   {
      datetime t1 = (datetime)ObjectGetInteger(0, obj, OBJPROP_TIME, 0);
      double   p1 = ObjectGetDouble(0, obj, OBJPROP_PRICE, 0);
      datetime t2 = (datetime)ObjectGetInteger(0, obj, OBJPROP_TIME, 1);
      double   p2 = ObjectGetDouble(0, obj, OBJPROP_PRICE, 1);
      if(t1 <= 0) return false;
      if(t2 <= 0) { t2 = t1; p2 = p1; }
      if(!ObjectCreate(0, ch, (ENUM_OBJECT)type, 0, t1, p1, t2, p2)) return false;
      ObjectSetInteger(0, ch, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, ch, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, ch, OBJPROP_FILL, true);
      ObjectSetInteger(0, ch, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, ch, OBJPROP_RAY_LEFT, false);
      ObjectSetInteger(0, ch, OBJPROP_ZORDER, Z_CHART_ZONE);
      ObjectSetString(0, ch, OBJPROP_TOOLTIP,
                      "Interior of \"" + obj + "\" — its color and tone live in the strip");
   }
   //--- P-DRAW-64 addendum 7 (2026-09-27) — THE INTERIOR IS IN ITS BOX'S OWN LAYER.
   //--- The child was hard-wired `OBJPROP_BACK = true` (behind the bars) while the box
   //--- is in front, and THAT is the whole of the lag the user kept reporting: MT4 paints
   //--- the layer the dragged object lives in as soon as the drag moves it, so an interior
   //--- parked in the other layer is painted by the NEXT pass — «فقط رنگ‌کشی یک فریم عقب‌تر
   //--- است», the data long since correct (addendum 6). Same layer, one pass, no gap. The
   //--- interior therefore MIRRORS the box's own BACK, which also makes the strip's BACK
   //--- cell one honest switch for the whole drawing instead of a hidden rule. Cost: one
   //--- guarded compare per sync, a write only when the box's layer really changed.
   int mBack = (int)ObjectGetInteger(0, obj, OBJPROP_BACK);
   if((int)ObjectGetInteger(0, ch, OBJPROP_BACK) != mBack)
      ObjectSetInteger(0, ch, OBJPROP_BACK, mBack);
   //--- geometry: the master's own anchors, verbatim (three cover rect / triangle /
   //--- ellipse / channel / fibochannel — a child that drifts is worse than none).
   //--- P-DRAW-64a: the interior follows the box as it IS, and it is no party to any of
   //--- the box's own controls: the 50 % is a level at the mid PRICE, the extend moves
   //--- the far edge, and either way the interior is the same anchors it always was.
   for(int a = 0; a < 3; a++)
   {
      datetime tt = (datetime)ObjectGetInteger(0, obj, OBJPROP_TIME, a);
      double   pp = ObjectGetDouble(0, obj, OBJPROP_PRICE, a);
      if(tt <= 0) continue;
      if((datetime)ObjectGetInteger(0, ch, OBJPROP_TIME, a) != tt)
         ObjectSetInteger(0, ch, OBJPROP_TIME, a, tt);
      if(ObjectGetDouble(0, ch, OBJPROP_PRICE, a) != pp)
         ObjectSetDouble(0, ch, OBJPROP_PRICE, a, pp);
   }
   int st = (int)ObjectGetInteger(0, obj, OBJPROP_STYLE);
   if((int)ObjectGetInteger(0, ch, OBJPROP_STYLE) != st) ObjectSetInteger(0, ch, OBJPROP_STYLE, st);
   //--- P-DRAW-64 addendum 4 (2026-09-27): THE CHILD'S OWN FRAME IS THE THINNEST
   //--- LEGAL ONE. Its frame shares its fill's ink, so in step it hides under the
   //--- master's frame; the only thing a sub-frame lag could ever show is a 1 px
   //--- sliver instead of a lip («این لبها و دور کادرها ... گاه ظاهر میشن»).
   if((int)ObjectGetInteger(0, ch, OBJPROP_WIDTH) != 1) ObjectSetInteger(0, ch, OBJPROP_WIDTH, 1);
   color ipure = clrNONE;
   if(!DrawSlotFillPure(obj, ipure)) ipure = (color)(int)DrawSlotRead(obj, DRAW_SLOT_COLOR);
   if((int)ipure < 0) ipure = (color)(int)DrawSlotRead(obj, DRAW_SLOT_COLOR);
   color ink = BlendColorTowardsBG(ipure, 100 - DrawSlotFillOpacityGet(obj),
                                   GetCachedChartBgColor());
   if((color)ObjectGetInteger(0, ch, OBJPROP_COLOR) != ink)
      ObjectSetInteger(0, ch, OBJPROP_COLOR, ink);
   return true;
}
// ══════════════════════════════════════════════════════════════════════════
// P-DRAW-64 (2026-09-27) — THE PREVIEW PAIR, AND IT WEARS THE OBJECT'S OWN TONE.
// First cut of the preview wrote `OBJPROP_COLOR = c` — the PURE colour — which is a
// second render owner, and the report proved the cost: «من این شفافیت تنظیم میکنم
// موس میره روی بقیه رنگه ناخواسته شفافیت [از دست میره]» — the moment the pointer
// crossed a cell, the tone the user had just tuned on the bar fell back to full
// strength. Both functions below go through the SAME two owners the real write
// does (`DrawSlotRenderColor` / `DrawSlotRenderFillColor`), so a previewed pixel is
// identical to the applied one. `DrawSlotRenderRestore` is the reverse: put the
// drawing back to the pixels its own tags say.
bool DrawSlotPreviewColor(const string name, const color c)
{
   if(name == "" || ObjectFind(0, name) < 0) return false;
   EDrawKind k = DrawKindOf(name);
   if(k == DK_NONE || !DrawSlotAvailable(k, DRAW_SLOT_COLOR)) return false;
   if(DrawIsHRay(name))   // P-HR-04: preview the plain ink the apply will write
   {
      if((color)ObjectGetInteger(0, name, OBJPROP_COLOR) == c) return false;
      ObjectSetInteger(0, name, OBJPROP_COLOR, c);
      return true;
   }
   // P-UI-136: the path previews on every segment — a preview that showed one
   // segment tinted would promise a write the apply fans out over the family — at
   // the path's own opacity (P-UI-137), or the hover would drop the user's fade.
   if(DrawIsPathSeg(name))
   {
      string pid = ""; PathIdOfName(name, pid);
      int pv = 0; color pp = clrNONE;
      PathInkGet(pid, pp, pv);
      color want = BlendColorTowardsBG(c, 100 - pv, GetCachedChartBgColor());
      if((color)ObjectGetInteger(0, name, OBJPROP_COLOR) == want) return false;
      PathInkApply(pid, c, pv);
      return true;
   }
   color rc = DrawSlotRenderColor(name, c);
   if((color)ObjectGetInteger(0, name, OBJPROP_COLOR) == rc) return false;
   ObjectSetInteger(0, name, OBJPROP_COLOR, rc);
   if(DrawKindHasLevels(k)) DrawLevelsSetColor(name, rc);
   FibPenSync(name, false);   // P-DRAW-74b: the preview reaches the stack too
   PenStackSync(name, false);   // P-DRAW-74c: and a line's rows ride the hover too
   return true;
}
bool DrawSlotPreviewFillColor(const string name, const color c)
{
   if(name == "" || ObjectFind(0, name) < 0) return false;
   EDrawKind k = DrawKindOf(name);
   if(k == DK_NONE || !DrawSlotAvailable(k, DRAW_SLOT_FILLCLR)) return false;
   color rc = DrawSlotRenderFillColor(name, c);
   if(DrawKindHasFillBody(k))
   {
      string ch = FillChildName(name);
      if(ObjectFind(0, ch) < 0) return false;   // no interior on the chart to preview
      if((color)ObjectGetInteger(0, ch, OBJPROP_COLOR) == rc) return false;
      ObjectSetInteger(0, ch, OBJPROP_COLOR, rc);
      return true;
   }
   if(!DrawKindHasLevels(k) || DrawLevelCount(name) <= 0) return false;
   if((color)ObjectGetInteger(0, name, OBJPROP_LEVELCOLOR, 0) == rc) return false;
   DrawLevelsSetColor(name, rc);
   FibPenSync(name, false);   // P-DRAW-74b: the preview reaches the stack too
   PenStackSync(name, false);   // P-DRAW-74c: a line's rows are its ink - re-ink them
   return true;
}
//--- the pixels the tags say, and only those: the preview's undo. One owner, so a
//--- cancelled preview, a scrub left mid-air and a chart that drifted all land on
//--- the same answer.
bool DrawSlotRenderRestore(const string name)
{
   if(name == "" || ObjectFind(0, name) < 0) return false;
   EDrawKind k = DrawKindOf(name);
   if(k == DK_NONE || k == DK_TEXT) return false;
   color pure = clrNONE;
   bool havePure = DrawSlotColorPure(name, pure);
   if(havePure) pure = DrawSlotRenderColor(name, pure);
   else pure = (color)(int)DrawSlotRead(name, DRAW_SLOT_COLOR);
   bool changed = false;
   if((color)ObjectGetInteger(0, name, OBJPROP_COLOR) != pure)
   { ObjectSetInteger(0, name, OBJPROP_COLOR, pure); changed = true; }
   if(DrawKindHasLevels(k) && DrawLevelCount(name) > 0)
   {
      color ip;
      color ir = DrawSlotFillPure(name, ip) ? DrawSlotRenderFillColor(name, ip) : pure;
      if((color)ObjectGetInteger(0, name, OBJPROP_LEVELCOLOR, 0) != ir)
      { DrawLevelsSetColor(name, ir); changed = true; }
   }
   if(DrawKindHasFillBody(k))
   {
      string ch = FillChildName(name);
      if(ObjectFind(0, ch) >= 0)
      {
         color ip2;
         if(!DrawSlotFillPure(name, ip2)) ip2 = (color)(int)DrawSlotRead(name, DRAW_SLOT_COLOR);
         if((int)ip2 >= 0)
         {
            color ink = DrawSlotRenderFillColor(name, ip2);
            if((color)ObjectGetInteger(0, ch, OBJPROP_COLOR) != ink)
            { ObjectSetInteger(0, ch, OBJPROP_COLOR, ink); changed = true; }
         }
      }
   }
   // P-DRAW-74b: restored levels re-ink the stack — a hover that previewed and
   // left would otherwise strand the children in the preview ink. Only a real
   // restore can strand ink, so a no-op restore syncs nothing.
   if(changed) FibPenSync(name, false);
   if(changed) PenStackSync(name, false);   // P-DRAW-74c: same law, the line's rows
   return changed;
}

//--- the FILL slot's follower: on means "the interior is on the chart" — the
//--- child, or the master's own fill a build before the split left behind.
//--- P-DRAW-64 (2026-09-27) — AND IT IS THE USER'S DRAWINGS' BUSINESS ONLY.
//--- Reported: «من اینو که جابجا میکنم اون یکی جا میمونه» with a screenshot of an
//--- indicator box whose interior had been turned into a stale child. The split is
//--- the STRIP's, i.e. the objects the strip serves; the indicator's OWN drawings
//--- (its boxes, zones, levels, the panels) carry `inpObjectPrefix` and are out of
//--- scope by the module's first law — every entry point here asks that first, so a
//--- drag anywhere on the chart (this call rides `CHARTEVENT_OBJECT_DRAG`, which
//--- fires for EVERY object) can never touch the product's own rendering.
bool FillChildSync(const string obj)
{
   if(obj == "" || FillIsChild(obj)) return false;
   if(DrawIsIndicatorObject(obj)) return false;   // the product's own: not ours to split
   if(BoxPreviewOwns(obj)) return false;   // P-DRAGF4: mid-gesture the master wears the interior natively
   if(ObjectFind(0, obj) < 0) return false;
   if(!DrawTypeHasFillChild(DrawObjectType(obj))) return false;   // cheapest out
   if(!DrawKindHasFillBody(DrawKindOf(obj))) return false;
   if(DrawSlotRead(obj, DRAW_SLOT_FILL) < 0.5) return FillChildDrop(obj);
   return FillChildEnsure(obj);
}
//--- P-DRAW-64 addendum 6 (2026-09-27) — THE INTERIOR RIDES THE HAND, NOT THE DRAG
//--- EVENT. The report that outlived three builds: «این باکس که جابجا میکنه این fill
//--- ازش جا میمکون بعد چند میلی ثانیه بعدش جفت میشه». Two causes, both closed here and
//--- in addendum 7, and neither of them is a missing witness — the witness already sat at
//--- the head of the router and stamped the child in the very event that moved the master.
//---   (a) THE EVENT COALESCES. MT4 merges a run of identical ids, so a dropped
//---       OBJECT_DRAG frame is a frame the interior did not move in. The MOVE STREAM does
//---       not coalesce (every pixel of travel is its own event) and the press already
//---       named the object (`s_dsPressObj`, P-UI-113i), so this costs NO hit test.
//---   (b) THE LAYER DID NOT. The child was hard-wired behind the bars while the box is in
//---       front, so the terminal painted the box's layer on the drag and the interior's in
//---       the next pass — «فقط رنگ‌کشی یک فریم عقب‌تر است», the data long since correct.
//--- Cost: a still frame pays four reads and one compare, a real move the guarded sync, an
//--- idle hand one string compare, and the arming rides the drag event too, so a gesture
//--- MT4 reports only as OBJECT_CHANGE is covered as well. One hand at a time, so the memo
//--- is one slot; it re-arms on the name and rests on the release.
static string s_fcmName = "";
static long   s_fcmT0 = 0, s_fcmT1 = 0, s_fcmT2 = 0;
static double s_fcmP0 = 0.0, s_fcmP1 = 0.0, s_fcmP2 = 0.0;
void FillChildStampArm(const string obj)
{
   s_fcmName = "";
   if(obj == "" || ObjectFind(0, obj) < 0) return;
   if(!DrawTypeHasFillChild(DrawObjectType(obj))) return;
   if(ObjectFind(0, FillChildName(obj)) < 0) return;   // no interior: nothing follows
   s_fcmName = obj;
   s_fcmT0 = (long)ObjectGetInteger(0, obj, OBJPROP_TIME, 0);
   s_fcmT1 = (long)ObjectGetInteger(0, obj, OBJPROP_TIME, 1);
   s_fcmT2 = (long)ObjectGetInteger(0, obj, OBJPROP_TIME, 2);
   s_fcmP0 = ObjectGetDouble(0, obj, OBJPROP_PRICE, 0);
   s_fcmP1 = ObjectGetDouble(0, obj, OBJPROP_PRICE, 1);
   s_fcmP2 = ObjectGetDouble(0, obj, OBJPROP_PRICE, 2);
}
void FillChildStampRelease() { s_fcmName = ""; }
bool FillChildStamp(const string obj)
{
   if(obj == "" || obj != s_fcmName) return false;
   if(ObjectFind(0, obj) < 0) { s_fcmName = ""; return false; }
   long t0 = (long)ObjectGetInteger(0, obj, OBJPROP_TIME, 0);
   long t1 = (long)ObjectGetInteger(0, obj, OBJPROP_TIME, 1);
   long t2 = (long)ObjectGetInteger(0, obj, OBJPROP_TIME, 2);
   double p0 = ObjectGetDouble(0, obj, OBJPROP_PRICE, 0);
   double p1 = ObjectGetDouble(0, obj, OBJPROP_PRICE, 1);
   double p2 = ObjectGetDouble(0, obj, OBJPROP_PRICE, 2);
   if(t0 == s_fcmT0 && t1 == s_fcmT1 && t2 == s_fcmT2 && p0 == s_fcmP0 && p1 == s_fcmP1 && p2 == s_fcmP2) return false;
   s_fcmT0 = t0; s_fcmT1 = t1; s_fcmT2 = t2; s_fcmP0 = p0; s_fcmP1 = p1; s_fcmP2 = p2;
   return FillChildSync(obj);
}

#endif // TOOLBAR_A_MQH// FibPen.mqh - P-DRAW-74b: the fibo widths the terminal cannot draw (split 2026-10-03).
// MT4 draws STYLE_* only at width 1, so a thick + non-solid fibo level is a
// state no terminal can draw («استایل ها فقط روی 1px اعمال میشه»). The pen the
// terminal cannot draw is built beside it, PER LEVEL: the level keeps its
// STYLE at visible width 1 (the dash itself), and width-1 children carry the
// SAME style in the SAME ink, centred on the level — a thick dash in full ink,
// not a faint hint. The chosen width is remembered NOWHERE but the stack:
// logical width is 1 + children, read back by FibPenLogicalWidth.
// COST (fibo family only, event paths: open/route/tap/undo/drag): children
// exist ONLY for a thick + non-solid level (solid and 1px cost zero objects);
// a still frame pays reads, writes nothing. Bounded: the first 12 levels,
// at most 4 children each, off ONE scale read.
#ifndef FIBPEN_MQH
#define FIBPEN_MQH

#define FIBPEN_SUFFIX      "_FSD"
#define FIBPEN_MAX_LEVELS  12   // MT4's own nine plus customs; levels past it still demote, thin
//--- P-DRAGF2 (2026-10-04): how close to an anchor the press has to be to mean "this
//--- anchor". The repo's own grab radius (HandLinesSelectionGuard, CustomPriceGrabAt,
//--- PATH_GRAB_PX) — one number for "the hand is ON it", not a new tolerance.
#define FIBPEN_GRAB_PX     8
#define FIBPEN_GRAB_BODY   2   // the hand took the BODY: MT4 translates BOTH anchors
#define FIBPEN_TAG         "[FW]"   // retired: widths are remembered by the stack, never by text
//--- P-LOOK (2026-10-03) — THE FIBO'S OWN LOOKS. MT4's five native styles end
//--- where chic begins: a look rides the STYLE slot as 5/6/7/8 (NEON/CAPS/WASH/3D),
//--- paints through this unit's own followers, and moves in the drag event that
//--- moved its owner — realtime, never a frame behind (contract §5). The look
//--- is a [LKn] tag beside the native pair the terminal holds; a native write
//--- from the MT4 dialog drops the stale tag instead of wearing two truths.
#define FIBPEN_LOOK_NEON   DRAW_LOOK_NEON   // P-UNIFY-4: the ids live in DrawKindProfile
#define FIBPEN_LOOK_CAPS   DRAW_LOOK_CAPS
#define FIBPEN_LOOK_WASH   DRAW_LOOK_WASH
#define FIBPEN_LK          DRAW_LOOK_TAG   // P-UNIFY-4: one tag for every look family
#define FIBPEN_CAP_SFX     "_FSC"
#define FIBPEN_WSH_SFX     "_FSW"
#define FIBPEN_SHW_SFX     "_FSH"
int FibPenLookNative(const int lk)
{
   int native = DrawLookNative(lk);
   return (native >= 0 ? native : (int)STYLE_SOLID);   // the retired id keeps the old solid fallback
}
int FibPenLookGet(const string fibo)
{
   if(fibo == "" || ObjectFind(0, fibo) < 0) return 0;
   int lk = DrawDescTagValue(ObjectGetString(0, fibo, OBJPROP_TEXT), FIBPEN_LK, 0);
   if(lk < FIBPEN_LOOK_NEON || lk > FIBPEN_LOOK_WASH) return 0;
   return lk;
}
void FibPenLookSet(const string fibo, const int lk)
{
   if(fibo == "" || ObjectFind(0, fibo) < 0) return;
   if(lk < FIBPEN_LOOK_NEON || lk > FIBPEN_LOOK_WASH) return;
   string d = ObjectGetString(0, fibo, OBJPROP_TEXT);
   string nd = DrawDescTag(d, FIBPEN_LK, IntegerToString(lk));
   if(nd != d) ObjectSetString(0, fibo, OBJPROP_TEXT, nd);
}
bool FibPenLookDrop(const string fibo)
{
   if(fibo == "" || ObjectFind(0, fibo) < 0) return false;
   string d = ObjectGetString(0, fibo, OBJPROP_TEXT);
   int at = StringFind(d, FIBPEN_LK);
   if(at < 0) return false;
   int e = StringFind(d, "]", at + StringLen(FIBPEN_LK));
   if(e <= at) return false;
   string nd = StringSubstr(d, 0, at) + StringSubstr(d, e + 1);
   if(StringLen(nd) > 0 && StringGetCharacter(nd, 0) == ' ') nd = StringSubstr(nd, 1);
   if(nd == d) return false;
   ObjectSetString(0, fibo, OBJPROP_TEXT, nd);
   return true;
}
//--- P-UNIFY-3: WHO THE PEN SERVES. The pen can state exactly the four kinds whose
//--- level geometry is known (`DrawLevelPriceAt`): fibo, fan, channel, expansion. A
//--- pitchfork's rails ARE its level family and a fibo arc is a circle, so neither can
//--- be stated without a measurement. The picker's look rows ask THIS, never the wider
//--- level test, so a row is never offered where the writer refuses to draw (C-04).
bool FibPenServesType(const int ty)
{
   return (DrawTypePenFamily(ty) == DKPEN_LEVEL);
}
bool FibPenServesName(const string name)
{
   if(name == "" || ObjectFind(0, name) < 0) return false;
   return FibPenServesType(DrawObjectType(name));
}
string FibPenCapName(const string f, const int dl) { return f + FIBPEN_CAP_SFX + IntegerToString(dl); }
string FibPenWashName(const string f, const int dl) { return f + FIBPEN_WSH_SFX + IntegerToString(dl); }
string FibPenShwName(const string f, const int dl) { return f + FIBPEN_SHW_SFX + IntegerToString(dl); }
//--- P-DRAGF (2026-10-03) — THE HAND'S OWN CADENCE. Measured DRAGSTAT: the
//--- terminal fires ~1-2 OBJECT_DRAG/s while the mouse moves ~60-100/s and the
//--- dragged master is blitted per move — followers parked on the drag event
//--- trail by whole seconds («موقع درگ فریمش عقب میمونه»). So a fibo drag ARMS
//--- the chase and every mouse move re-seats the children — geometry only
//--- (width, style, colour, demote, sweep and tags never change mid-gesture and
//--- stay on the discrete paths, which also converge on release). HOW the move
//--- question is answered is P-DRAGF2 below: the anchor by pixels at the press,
//--- the master by a snapshot resynced on every landing, the moved frame by its
//--- own flush. Cost per move: cursor + anchors + one value per level + one
//--- price read per standing child, moves only on diff. Unarmed (button up,
//--- deleted, never armed): two compares.
static string s_fibDragObj = "";
static uint s_fibMovMs = 0;   // DIAG-139 shared move-sample throttle (Sync + Follow)

//--- P-DRAGF2 (2026-10-04) — WHICH ANCHOR THE HAND TOOK, AND WHERE THE MASTER IS.
//---
//--- The first chase asked "the anchor nearest the CURSOR PRICE" and set that anchor's
//--- price to the cursor. That predicate is wrong on its own: the anchor the hand did NOT
//--- take is already a drag event old (measured DRAGSTAT 0.6-1.6 s against ~50-130
//--- moves/s), and once the hand travels that STALE side is the FARTHER one from the
//--- cursor — the price test then calls it "the hand's", and the stack rides the cursor
//--- on one side and the last landed price on the other, righting itself once per drag
//--- event.
//--- AND THE SESSION THAT REPORTED IT SAYS WORSE: the chase was not late, it never ran.
//--- Diag 2026-10-03, «Fibo 11000»: the stack came into being at 19:49:32.396 (`FIBPEN ...
//--- new=8`), the strip's dismiss click landed at :34.973, and the drag events at :34.972,
//--- :36.573, :38.236 and :39.860 — four in five seconds, `moved=14` children each, the
//--- drag event's own sync — were the ONLY re-seats between 252 left-button moves of the
//--- hand's stream. The follow sat under the shut-strip guard (see the seat note in
//--- DrawStrip_Router.mqh); four re-seats in five seconds IS «یک فریم عقب», and it is the
//--- same shape P-DRAW-64d fixed for the box's mid line one seat away.
//---
//--- So the chase answers the two questions the gesture actually asks:
//---   * WHICH anchor is under the hand — by PIXELS at the press (`ChartTimePriceToXY`
//---     against FIBPEN_GRAB_PX, the repo's own grab radius), decided ONCE and never
//---     re-guessed mid-gesture. The BODY is its own answer: MT4 translates BOTH anchors
//---     when the hand is not on one, which a single-anchor substitution cannot express;
//---   * WHERE the master is — a snapshot RESYNCED every time the terminal lands one of
//---     its own updates (live read != the probe), with the cursor origin moved with it,
//---     so the chase extrapolates between two lands and cannot accumulate an error.
static int      s_fibGrab   = -1;             // -1 undecided · 0/1 the hand's anchor · FIBPEN_GRAB_BODY
static double   s_fibP0[2]  = {0.0, 0.0};     // the master's anchors at the last resync
static datetime s_fibT0[2]  = {0, 0};
static double   s_fibProbeP[2] = {0.0, 0.0};  // ...and as read at the last look (the landing probe)
static datetime s_fibProbeT[2] = {0, 0};
static double   s_fibCurP0  = 0.0;            // the cursor that resync was taken at

void FibPenChaseReset()
{
   s_fibGrab = -1;
   s_fibP0[0] = 0.0; s_fibP0[1] = 0.0;
   s_fibT0[0] = 0; s_fibT0[1] = 0;
   s_fibProbeP[0] = 0.0; s_fibProbeP[1] = 0.0;
   s_fibProbeT[0] = 0; s_fibProbeT[1] = 0;
   s_fibCurP0 = 0.0;
}
void FibPenDragArm(const string name)
{
   //--- P-DRAGF2: the drag event fires THROUGH a gesture (measured DRAGSTAT ~1/s), and
   //--- it lands the master — a landing is not a new ask. Re-arming here would re-run
   //--- FibPenChaseReset() mid-gesture, re-asking the anchor question at a cursor that
   //--- has already travelled (an anchor grab would read as a body drag) and dropping
   //--- the snapshot behind the hand. Only a new name — or the first event after a
   //--- disarm — opens a chase; the gesture's own end is FibPenDragDisarm (button up).
   if(name != "" && name == s_fibDragObj) return;
   s_fibDragObj = "";
   FibPenPreviewEnd();   // P-DRAGF3: a missed release must not hold the previous body hostage
   FibPenChaseReset();   // a new gesture asks its own questions: no snapshot survives it
   if(name == "" || ObjectFind(0, name) < 0) return;
   if(DrawIsIndicatorObject(name)) return;
   if(!FibPenServesType(DrawObjectType(name))) return;
   s_fibDragObj = name;
   FibPenPreviewArm();   // P-DRAGF3: a patterned thick fibo drags NATIVELY - see the block below
}
void FibPenDragDisarm()
{
   if(s_fibDragObj != "") { s_fibDragObj = ""; FibPenChaseReset(); }
}
//--- P-DRAGF3 (2026-10-17) - THE GESTURE BELONGS TO THE TERMINAL.
//--- MEASURED (P-DRAGF/P-DRAGF2, the numbers this file already carries): the terminal
//--- fires OBJECT_DRAG ~1-2/s (DRAGSTAT) while the hand's own moves arrive ~60-100/s,
//--- and a patterned thick fibo is a DEMOTED master (width 1) plus moved children per
//--- level - children WE re-seat on every move, in a frame painted AFTER the frame the
//--- terminal already blitted. The trail is structural: a follower cannot be painted in
//--- the frame it follows. So the PREVIEW hands the body BACK: at the arm (the gesture's
//--- first drag event) every stacked level's width goes back to the logical number -
//--- which MT4 draws SOLID at width>1, the very law this file exists around - and the
//--- stack (rows, caps, wash) is hidden ONCE. Through the whole gesture this unit then
//--- writes NOTHING (the three gates below), the terminal's own native blit carries the
//--- body, and there is no frame to be behind. At the release the preview ends, the
//--- children come back, and ONE FibPenSync re-demotes + re-seats + re-memoizes in the
//--- release's own flushed frame (DrawStrip_Router, the click door; the button-up move
//--- is the second door - a hand can let go with no click event naming an object).
//--- Cost per gesture: one LEVELWIDTH write per stacked level + one hide per child at
//--- the arm, one un-hide + one sync at the release - against the chase's per-move
//--- re-seats at up to 100 moves/s. The visible trade, stated: while the hand moves a
//--- patterned thick fibo previews as a SOLID thick one and the pattern returns at the
//--- release. MT4 cannot draw the pattern thick - the glass is solid anyway.
//--- P-DRAGF3a (2026-10-17): the same hand-back covers a LOOK whose children stand with
//--- NO stack (CAPS/WASH ride a solid level, `want` is 0) - their halo was re-seated by
//--- the chase one frame behind while the arm refused them on width alone.
static bool   s_fibPreview    = false;   // P-DRAGF3: the preview owns the gesture
static string s_fibPreviewObj = "";

void FibPenPreviewArm()
{
   if(s_fibPreview) return;
   string fibo = s_fibDragObj;
   if(fibo == "" || ObjectFind(0, fibo) < 0) return;
   int nl = DrawLevelCount(fibo);
   int nw = (nl > FIBPEN_MAX_LEVELS) ? FIBPEN_MAX_LEVELS : nl;
   if(nw <= 0) return;
   int refLog = FibPenLogicalWidth(fibo, 0);   // the sync's OWN reference (level 0)
   //--- P-DRAGF3a (2026-10-17) — A LOOK'S CHILDREN EXIST WITH NO STACK AT ALL. CAPS and
   //--- WASH ride a SOLID level (`want` is 0 for them), so `refLog` stays the logical
   //--- width while their children stand — the old `refLog <= DRAW_WIDTH_MIN` fence and
   //--- the `nW <= 0` gate both refused exactly those looks, and the halo went back to
   //--- the chase: the one-frame lag this preview exists to end, one look over. The look
   //--- tag answers for one read; only a THIN, LOOK-LESS fibo has nothing to hand back.
   if(FibPenLookGet(fibo) == 0 && refLog <= DRAW_WIDTH_MIN) return;
   int nW = 0, nH = 0;
   for(int l = 0; l < nw; l++)
   {
      int c = FibPenChildCount(fibo, l);
      if(c > 0)   // a stacked level: the width goes back and the rows hide with it
      {
         if((int)ObjectGetInteger(0, fibo, OBJPROP_LEVELWIDTH, l) != refLog)
         { ObjectSetInteger(0, fibo, OBJPROP_LEVELWIDTH, l, refLog); nW++; }
         for(int q = 0; q < c; q++)
         {
            string nm = FibPenName(fibo, l, q);
            if(ObjectFind(0, nm) < 0) continue;
            if((int)ObjectGetInteger(0, nm, OBJPROP_TIMEFRAMES) != OBJ_NO_PERIODS)
            { ObjectSetInteger(0, nm, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS); nH++; }
         }
      }
      //--- caps and wash are the LOOK's own children, hidden whether or not
      //--- the level stacked — the chase re-seats them on every move like any row
      //--- (P-DRAGF3a).
      string cn = FibPenCapName(fibo, l);
      if(ObjectFind(0, cn) >= 0 && (int)ObjectGetInteger(0, cn, OBJPROP_TIMEFRAMES) != OBJ_NO_PERIODS)
      { ObjectSetInteger(0, cn, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS); nH++; }
      string wn = FibPenWashName(fibo, l);
      if(ObjectFind(0, wn) >= 0 && (int)ObjectGetInteger(0, wn, OBJPROP_TIMEFRAMES) != OBJ_NO_PERIODS)
      { ObjectSetInteger(0, wn, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS); nH++; }
   }
   if(nW <= 0 && nH <= 0) return;   // nothing demoted and no look child: no preview, no flag
   s_fibPreview = true;
   s_fibPreviewObj = fibo;
   // The flush is the caller's: this arm runs inside the drag branch whose own tail
   // already ends in ChartRedraw() (P-DRAW-74b-f, DrawStrip_Router).
   DrawStripDiagEmit("[drawstrip] FIBPENPRE view=on fibo=\"" + fibo + "\" lv=" + IntegerToString(nW) +
                     " hid=" + IntegerToString(nH) + " w=" + IntegerToString(refLog));
}

bool FibPenPreviewEnd()
{
   if(!s_fibPreview) return false;
   string fibo = s_fibPreviewObj;
   s_fibPreview = false;   // cleared FIRST: the sync below must not read its own gate
   s_fibPreviewObj = "";
   if(fibo == "" || ObjectFind(0, fibo) < 0) return false;
   int nl = DrawLevelCount(fibo);
   int nw = (nl > FIBPEN_MAX_LEVELS) ? FIBPEN_MAX_LEVELS : nl;
   int nU = 0;
   for(int l = 0; l < nw; l++)
   {
      int c = FibPenChildCount(fibo, l);
      if(c > 0)   // the rows the arm hid
      {
         for(int q = 0; q < c; q++)
         {
            string nm = FibPenName(fibo, l, q);
            if(ObjectFind(0, nm) < 0) continue;
            if((int)ObjectGetInteger(0, nm, OBJPROP_TIMEFRAMES) != OBJ_ALL_PERIODS)
            { ObjectSetInteger(0, nm, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS); nU++; }
         }
      }
      //--- P-DRAGF3a: and the look's own children, which the arm hid with no stack too —
      //--- an un-hide that skipped them would leave the halo invisible on every period.
      string cn = FibPenCapName(fibo, l);
      if(ObjectFind(0, cn) >= 0 && (int)ObjectGetInteger(0, cn, OBJPROP_TIMEFRAMES) != OBJ_ALL_PERIODS)
      { ObjectSetInteger(0, cn, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS); nU++; }
      string wn = FibPenWashName(fibo, l);
      if(ObjectFind(0, wn) >= 0 && (int)ObjectGetInteger(0, wn, OBJPROP_TIMEFRAMES) != OBJ_ALL_PERIODS)
      { ObjectSetInteger(0, wn, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS); nU++; }
   }
   // ONE convergence, same frame: the full-width master demotes back to 1 (the sync's
   // own guarded write), the children are re-seated at the landed anchors, the net's
   // memo re-learns the master. The caller owns the flush (the release path already
   // redraws; the button-up door flushes on this call's verdict).
   bool dirty = FibPenSync(fibo, false);
   DrawStripDiagEmit("[drawstrip] FIBPENPRE view=off fibo=\"" + fibo + "\" unhid=" + IntegerToString(nU) +
                     " sync=" + IntegerToString(dirty ? 1 : 0));
   return (nU > 0 || dirty);
}
//--- P-WARN-46 (2026-10-04): the three forward declarations that stood here went with
//--- the build's `warning 46` lines. MQL4 resolves a function defined LATER in the unit
//--- on its own; it does not for a variable, and this file reads none of those before
//--- its reader's own body (see the P-WARN-46 note in Toolbar_A.mqh for the measured
//--- precedent: EventHandlers_Router has called UIPointerOverSurface - body in a
//--- later-included file - with no prototype since P-UI-92c).
void FibPenDragFollow(const int mx, const int my)
{
   if(s_fibPreview) return;   // P-DRAGF3: the preview owns the gesture - zero writes per move
   if(s_fibDragObj == "") return;
   string fibo = s_fibDragObj;
   if(ObjectFind(0, fibo) < 0) { FibPenChaseReset(); s_fibDragObj = ""; return; }
   if(DrawObjectType(fibo) != OBJ_FIBO) return;
   datetime ct = 0; double cp = 0.0;
   int px_ = mx, py_ = my;   // ChartXYToTimePrice takes refs: never pass consts
   if(!ChartXYToTimePrice(0, 0, px_, py_, ct, cp)) return;
   if(!(cp > 0.0) || ct <= 0) return;
   double p1 = ObjectGetDouble(0, fibo, OBJPROP_PRICE, 0);
   double p2 = ObjectGetDouble(0, fibo, OBJPROP_PRICE, 1);
   if(!(p1 > 0.0) || !(p2 > 0.0)) return;
   datetime t1 = (datetime)ObjectGetInteger(0, fibo, OBJPROP_TIME, 0);
   datetime t2 = (datetime)ObjectGetInteger(0, fibo, OBJPROP_TIME, 1);
   if(t1 <= 0 || t2 <= 0) return;
   double px = FibPenPixelPrice();
   if(!(px > 0.0)) return;
   //--- (1) THE HAND'S ANCHOR, decided ONCE per gesture, by PIXELS — the question the
   //--- press can answer and a mid-gesture price compare cannot (the not-taken anchor is
   //--- the stale one, and it is the far one as soon as the hand moves).
   if(s_fibGrab < 0)
   {
      int ax = 0, ay = 0, bx = 0, by = 0;
      bool okA = ChartTimePriceToXY(0, 0, (int)t1, p1, ax, ay);
      bool okB = ChartTimePriceToXY(0, 0, (int)t2, p2, bx, by);
      if(!okA && !okB) return;
      if(okA && okB)
      {
         int dA = MathAbs(mx - ax) + MathAbs(my - ay);
         int dB = MathAbs(mx - bx) + MathAbs(my - by);
         if(dA <= FIBPEN_GRAB_PX && dA <= dB)      s_fibGrab = 0;
         else if(dB <= FIBPEN_GRAB_PX)             s_fibGrab = 1;
         else                                      s_fibGrab = FIBPEN_GRAB_BODY;
      }
      else s_fibGrab = okA ? 0 : 1;
      s_fibP0[0] = p1; s_fibP0[1] = p2;
      s_fibT0[0] = t1; s_fibT0[1] = t2;
      s_fibProbeP[0] = p1; s_fibProbeP[1] = p2;
      s_fibProbeT[0] = t1; s_fibProbeT[1] = t2;
      s_fibCurP0 = cp;
      return;   // the press frame asks; it does not move
   }
   //--- (2) A TERMINAL LANDING RESYNCS THE SNAPSHOT. The master's own truth wins and the
   //--- cursor origin moves with it, so the delta below is always "since the last time
   //--- the master agreed with itself" — never a growing error.
   if(p1 != s_fibProbeP[0] || p2 != s_fibProbeP[1] || t1 != s_fibProbeT[0] || t2 != s_fibProbeT[1])
   {
      s_fibP0[0] = p1; s_fibP0[1] = p2;
      s_fibT0[0] = t1; s_fibT0[1] = t2;
      s_fibProbeP[0] = p1; s_fibProbeP[1] = p2;
      s_fibProbeT[0] = t1; s_fibProbeT[1] = t2;
      s_fibCurP0 = cp;
   }
   //--- (3) THE GEOMETRY: the snapshot plus the hand's own delta since it. A body drag
   //--- translates the WHOLE pair (the only shape that can keep a translated drawing a
   //--- drawing); an anchor drag is a single side riding the cursor.
   //--- (3) THE GEOMETRY: the snapshot plus the hand's own delta since it. A body drag
   //--- translates the WHOLE pair (the only shape that can keep a translated drawing a
   //--- drawing); an anchor drag is a single side riding the cursor.
   //--- AND THE SPAN IS THE MASTER'S OWN (P-LOOK-RAY2). The children's TIMES are the two
   //--- anchors the master has RIGHT NOW - never an estimate: the pen must cover the span
   //--- the line covers (a level line that stops at its anchors, `levels_ray` off, would
   //--- otherwise get a pen that stops somewhere else - the very defect the mirror rule
   //--- exists to end). The PRICES ride ahead (that is the drag event's own lag, and the
   //--- reason the chase exists); the span never does.
   double dp = cp - s_fibCurP0;
   double pa = 0.0, pb = 0.0;
   if(s_fibGrab == FIBPEN_GRAB_BODY)
   {
      pa = s_fibP0[0] + dp; pb = s_fibP0[1] + dp;
   }
   else if(s_fibGrab == 0)
   {
      pa = cp;            pb = s_fibP0[1];
   }
   else
   {
      pa = s_fibP0[0];    pb = cp;
   }
   if(!(pa > 0.0) || !(pb > 0.0)) return;
    datetime ta = t1, tb = t2;
    datetime ts0 = (ta < tb ? ta : tb);   // P-LOOK-RAY5b: rows ride ordered time, even mid-gesture
    datetime ts1 = (ta < tb ? tb : ta);
   int nl = DrawLevelCount(fibo);
   if(nl <= 0) return;
   int nw = (nl > FIBPEN_MAX_LEVELS) ? FIBPEN_MAX_LEVELS : nl;
   int nMov = 0;
   for(int l = 0; l < nw; l++)
   {
      string c0 = FibPenName(fibo, l, 0);
      string cpnm = FibPenCapName(fibo, l);
      string wsnm = FibPenWashName(fibo, l);
      if(ObjectFind(0, c0) < 0 && ObjectFind(0, cpnm) < 0 &&
         ObjectFind(0, wsnm) < 0) continue;
      double v = ObjectGetDouble(0, fibo, OBJPROP_LEVELVALUE, l);
      if(!MathIsValidNumber(v)) continue;
      double lva = pb + (pa - pb) * v;   // P-LOOK-ANCHOR: 0 % at the SECOND anchor (the terminal's law)
      if(!(lva > 0.0)) continue;
      int logical = FibPenLogicalWidth(fibo, l);
      for(int q = 0; q < logical && q <= DRAW_WIDTH_MAX; q++)
      {
         string nm = FibPenName(fibo, l, q);
         if(ObjectFind(0, nm) < 0) break;
          double rowP = lva + FibPenOffPx(logical, q) * px;
          if(ObjectGetDouble(0, nm, OBJPROP_PRICE, 0) != rowP)
          { ObjectMove(0, nm, 0, ts0, rowP); nMov++; }
          if(ObjectGetDouble(0, nm, OBJPROP_PRICE, 1) != rowP)
          { ObjectMove(0, nm, 1, ts1, rowP); nMov++; }
      }
       if(ObjectFind(0, cpnm) >= 0)
       {
          datetime tc = tb - (tb - ta) / 8;
          if(!(tc > ta)) tc = ta;
          if(ObjectGetDouble(0, cpnm, OBJPROP_PRICE, 0) != lva)
          { ObjectMove(0, cpnm, 0, tc, lva); nMov++; }
          if(ObjectGetDouble(0, cpnm, OBJPROP_PRICE, 1) != lva)
          { ObjectMove(0, cpnm, 1, tb, lva); nMov++; }
       }
        if(ObjectFind(0, wsnm) >= 0)
        {
           double hp = lva + 2.0 * px;
           if(ObjectGetDouble(0, wsnm, OBJPROP_PRICE, 0) != hp)
           { ObjectMove(0, wsnm, 0, ts0, hp); nMov++; }
           if(ObjectGetDouble(0, wsnm, OBJPROP_PRICE, 1) != hp)
           { ObjectMove(0, wsnm, 1, ts1, hp); nMov++; }
        }
     }
   //--- (4) THE FRAME THE CHASE MOVED IS THE FRAME IT PAINTS. The DRAG channel flushes
   //--- its own frame (P-DRAW-74b-f); the MOVE channel is this one's only painter, and
   //--- without a flush the children wait for the terminal's own next repaint — the
   //--- "one frame behind" the flush law exists to end. A still frame moves nothing and
   //--- therefore repaints nothing.
   if(nMov > 0) ChartRedraw();
   //--- DIAG-139/141: same sampled witness as the sync — one line per second max, and it
   //--- now names the CHANNEL's own answer: which anchor the hand took and the delta it is
   //--- being carried by, so the next drag reports its case instead of asking for one.
   if(nMov > 0)
   {
      uint nowMs = GetTickCount();
      if(nowMs - s_fibMovMs > 1000 || nowMs < s_fibMovMs)
      {
         s_fibMovMs = nowMs;
         DrawStripDiagEmit("[drawstrip] FIBPENMOV fibo=\"" + fibo + "\" moved=" + IntegerToString(nMov) +
                           " ta=" + IntegerToString((long)ta) + " tb=" + IntegerToString((long)tb) +
                           " p1=" + DoubleToString(pa, _Digits) + " p2=" + DoubleToString(pb, _Digits) +
                           " g=" + IntegerToString(s_fibGrab) + " dp=" + DoubleToString(dp, _Digits) +
                           " s=" + IntegerToString((int)GetTickCount()));
      }
   }
}
//--- the second family test: caps, wash and shadow strays are served never, like the stack's.
bool FibPenFamIsChild(const string name)
{
   int pos = 0;
   while(true)
   {
      int at = StringFind(name, "_FS", pos);
      if(at < 0) return false;
      string rest = StringSubstr(name, at + 3);
      bool ok = (StringLen(rest) > 1);
      if(ok)
      {
         ushort fc = StringGetCharacter(rest, 0);
         if(fc != 'C' && fc != 'W' && fc != 'H') ok = false;
         else
         {
            for(int i = 1; i < StringLen(rest); i++)
            {
               ushort ch = StringGetCharacter(rest, i);
               if(ch < '0' || ch > '9') { ok = false; break; }
            }
         }
      }
      if(ok) return true;
      pos = at + 1;
   }
   return false;
}

int FibPenCount(const int w) { return (w < 2 ? 0 : (w > DRAW_WIDTH_MAX ? DRAW_WIDTH_MAX - 1 : w - 1)); }
string FibPenName(const string f, const int dl, const int dq)
{ return f + FIBPEN_SUFFIX + IntegerToString(dl) + "." + IntegerToString(dq); }

//--- the leftover test: the suffix sits BEFORE the "<level>.<q>" tail, never
//--- at the end (the old test matched the last chars, so no child was ever
//--- one: each stacked line was served, hit and learned as a drawing of its
//--- own). `DrawKindOf` answers DK_NONE for one, so nothing serves, hits or
//--- learns a child.
bool FibPenIsChild(const string name)
{
   int s = StringLen(FIBPEN_SUFFIX);
   int pos = 0;
   while(true)
   {
      int at = StringFind(name, FIBPEN_SUFFIX, pos);
      if(at < 0) return false;
      string rest = StringSubstr(name, at + s);
      bool ok = (StringLen(rest) > 0);
      int dot = -1;
      for(int i = 0; i < StringLen(rest); i++)
      {
         ushort ch = StringGetCharacter(rest, i);
         if(ch == '.') { if(dot >= 0) { ok = false; break; } dot = i; continue; }
         if(ch < '0' || ch > '9') { ok = false; break; }
      }
      if(ok && dot > 0 && dot < StringLen(rest) - 1) return true;
      pos = at + 1;
   }
   return false;
}

//--- how many children level dl carries (contiguous from q=0).
int FibPenChildCount(const string f, const int dl)
{
   int c = 0;
   for(int q = 0; q < DRAW_WIDTH_MAX; q++)
   {
      if(ObjectFind(0, FibPenName(f, dl, q)) < 0) break;
      c++;
   }
   return c;
}

//--- the remembered width of one level: 1 + children while demoted, else the line's own.
int FibPenLogicalWidth(const string fibo, const int lvl)
{
   if(fibo == "" || ObjectFind(0, fibo) < 0) return DRAW_WIDTH_MIN;
   int w = (int)ObjectGetInteger(0, fibo, OBJPROP_LEVELWIDTH, lvl);
   if(w < DRAW_WIDTH_MIN) w = DRAW_WIDTH_MIN;
   if(w > DRAW_WIDTH_MAX) w = DRAW_WIDTH_MAX;
   if(w == DRAW_WIDTH_MIN)
   {
      int c = FibPenChildCount(fibo, lvl);
      if(c > 0)
      {
         //--- a neon core (solid) is the tube, not thickness: counting it would
         //--- grow the stack by one on every sync. Children are contiguous, so
         //--- the top one tells.
         int lg = 1 + c;
         string top = FibPenName(fibo, lvl, c - 1);
         if((int)ObjectGetInteger(0, top, OBJPROP_STYLE) == (int)STYLE_SOLID) lg = c;
         if(lg < DRAW_WIDTH_MIN) lg = DRAW_WIDTH_MIN;
         if(lg > DRAW_WIDTH_MAX) lg = DRAW_WIDTH_MAX;
         return lg;
      }
   }
   return w;
}

//--- ONE pixel's worth of price, from the chart's OWN scale.
double FibPenPixelPrice()
{
   int    h  = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   double hi = ChartGetDouble(0, CHART_PRICE_MAX);
   double lo = ChartGetDouble(0, CHART_PRICE_MIN);
   if(h <= 0 || !(hi > lo)) return 0.0;
   double px = (hi - lo) / (double)h;
   return (MathIsValidNumber(px) && px > 0.0) ? px : 0.0;
}

//--- centred offsets in px, inner first: 2:[+1] 3:[-1,+1] 4:[-1,+1,+2] 5:[-1,+1,-2,+2].
int FibPenOffPx(const int w, const int q)
{
   int half = (w - 1) / 2;
   int idx = q;
   for(int d = 1; d <= half; d++)
   {
      if(idx == 0) return -d;
      idx--;
      if(idx == 0) return d;
      idx--;
   }
   if(w % 2 == 0 && idx == 0) return half + 1;
   return 0;
}

//--- spend a v2 [FWn]: truth is explicit again since widths live in the stack,
//--- so the tag would lie. Guarded: one TEXT read, a write only when present.
bool FibPenTagDrop(const string fibo)
{
   if(fibo == "" || ObjectFind(0, fibo) < 0) return false;
   string d = ObjectGetString(0, fibo, OBJPROP_TEXT);
   int at = StringFind(d, FIBPEN_TAG);
   if(at < 0) return false;
   int e = StringFind(d, "]", at + StringLen(FIBPEN_TAG));
   if(e <= at) return false;
   string nd = StringSubstr(d, 0, at) + StringSubstr(d, e + 1);
   if(StringLen(nd) > 0 && StringGetCharacter(nd, 0) == ' ') nd = StringSubstr(nd, 1);
   if(nd == d) return false;
   ObjectSetString(0, fibo, OBJPROP_TEXT, nd);
   return true;
}

//--- P-LOOK-RAY3 (2026-10-04) — THE PEN'S SPAN IS MT4'S SPAN, AND MT4 WILL NOT TELL US.
//---
//--- P-LOOK-RAY2 believed the master's OWN ray pair (`OBJPROP_RAY_LEFT/RIGHT`) was the
//--- fibo's level ray, and mirrored it onto every row of the pen. MEASURED FALSE on the
//--- hand's own chart, 2026-10-04 12:08 (EURUSD M1, AMarkets demo): the four level lines
//--- run edge to edge — x=250..1863, one 1 px dash-dot-dot row each — while the two rows the
//--- pen stacks beside them stop dead at x=595, the second anchor, which is the report
//--- («چرا امتداد خط ها استایل اعمال نشده باید همه جا باشه دیگه»). Counted, not
//--- eyeballed: between the anchors each level occupies rows 292..294 (level + 2 pen rows);
//--- past x=580 only row 293 survives — the master ran on to the chart edge, the pen did
//--- not, so the extension wore no thickness at all.
//---
//--- WHY the mirror read false every single time: on OBJ_FIBO that pair is NOT the level
//--- ray. MT4 keeps the level ray in a field of its own — the chart's own file stores
//--- `levels_ray=0` for a fibo and writes NO `ray=` entry for it at all, while the pen's
//--- rows (type=2, OBJ_TREND) carry `ray=1` — and MQL4 exposes nothing that reads or writes
//--- it: `ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false)` does NOT stop a fibo's levels
//--- from reaching the right chart edge (mql5.com/forum/164640, MT4 build 1030+: "it always
//--- stretch the fibo retracement to right end of the chart"). A read that can only ever
//--- answer false is not a mirror, it is a trimmer: the pen was shortened to the anchors
//--- while the line it belongs to went on.
//---
//--- So the truth is not a flag we own but a SHAPE MT4 draws: a fibo's level lines run from
//--- the FIRST anchor to the RIGHT edge of the chart, and never to the left (measured on
//--- the same frame: they begin at x=250 while the chart's own left edge is x=48). The pen
//--- states that shape instead of guessing it — right on, left off, on every dash row, the
//--- neon core and the wash halo, at birth and on every heal. One shape, one law: the
//--- style is the line's style WHEREVER THE LINE GOES, which is the whole of the report.
//---
//--- P-LOOK-RAY4 (2026-10-04 14:27) — THE RAY TURNS WITH THE ANCHORS. RAY3 measured that
//--- shape on a FORWARD-drawn fibo; the hand then dragged point0 past point1 (diag:
//--- FIBPENMOV ta=1790975520 > tb=1790973360) and the run fled the wrong way («این امتداد
//--- به عقب و جلو چرا استایل و ضخامت نمیگیره»). Measured on that frame, pixel by pixel:
//--- the children sit at ±1/±2 px and NEVER on the level's own row, so the centre row IS
//--- MT4's own line — centre 0.01 left of the earlier anchor (x=648) against 0.62 from it
//--- to the right edge, while the pen's ring rows read 0.63 left of 648 (hanging in empty
//--- space) and 0.00 right of point0 (the bare extension). So MT4's law, in both orders:
//--- the level line runs from the EARLIER anchor to the right chart edge, never left of
//--- it — and MT4's OBJ_TREND rays are DIRECTIONAL (RAY_RIGHT extends past point1 ALONG
//--- point0→point1, RAY_LEFT past point0 against it), so "right on, left off" is only
//--- right while t0 <= t1. The pen states the shape in both orders: EXACTLY ONE ray is
//--- on, always the RIGHTWARD one — forward anchors carry it on RAY_RIGHT, reversed
//--- anchors on RAY_LEFT. One shape, one law, both ways: the style and the thickness the
//--- hand chose ride the line WHEREVER THE LINE GOES.
//--- P-LOOK-RAY5 (2026-10-04) — BOTH EXTENSIONS WEAR IT. The hand's own two frames
//--- (EURUSD M1: the middle thick, BOTH extensions thin — «امتداد به عقب و جلو چرا
//--- استایل و ضخامت نمیگیره») show the master spanning the FULL width both ways, so
//--- the one-ray law always left one side bare. The pen states BOTH rays on, in both
//--- anchor orders. No flag is read (RAY3 stands); no single-ray branch (RAY4 retires).
//--- P-LOOK-RAY5b (2026-10-04) — THE CHILDREN WEAR ORDERED TIME. Both rays on was
//--- not enough: MEASURED on the hand's next frame (EURUSD M1, diag `Fibo 11855`
//--- `rays=3 ta=1790979000 tb=1790978280`) the pen covered the left edge to the late
//--- anchor while the right extension stayed bare. MT4 extends a trend ray past the
//--- side its own order names — children born with the master's REVERSED order keep
//--- only one extension. So every rayed row is seated early→late (`ts0/ts1`), the one
//--- order MT4 extends both ways from; the master's own anchors are never reordered,
//--- only the rows the pen owns. First pass after load re-seats every row (fresh memo).
void FibPenRayPair(const string fibo, bool &rl, bool &rr)
{
   if(fibo == "" || ObjectFind(0, fibo) < 0) { rl = false; rr = false; return; }
   rl = true;    // P-LOOK-RAY5: the backward extension wears the style too
   rr = true;    // P-LOOK-RAY5: ...and the forward one — full width, both anchor orders
}
int FibPenRayBits(const string fibo)
{
   bool rl = false, rr = false;
   FibPenRayPair(fibo, rl, rr);
   return (rl ? 2 : 0) | (rr ? 1 : 0);
}
//--- the pen's own existence test: any of the four families it builds.
bool FibPenHasPen(const string fibo)
{
   if(fibo == "") return false;
   if(ObjectFind(0, FibPenName(fibo, 0, 0)) >= 0) return true;
   if(ObjectFind(0, FibPenCapName(fibo, 0)) >= 0) return true;
   if(ObjectFind(0, FibPenWashName(fibo, 0)) >= 0) return true;
   if(ObjectFind(0, FibPenShwName(fibo, 0)) >= 0) return true;
   return false;
}
//--- P-LOOK-RAY2 - THE PEN'S OWN NET. Every other follower in this repo has one seat that
//--- needs no event (the box's interior and its 50 % line ride the 2 s chart-side pass,
//--- P-DRAW-64 / addendum 5). The pen had only EVENT paths - open, route, tap, undo,
//--- release, OBJECT_DRAG/CHANGE - so when the terminal landed the master's final anchors
//--- AFTER the last of those events, nothing ever re-anchored the children: the stale pen
//--- measured above was hours old, not a frame (its right anchor still named the anchor
//--- the fibo had one drag earlier). The 2 s pass (`DrawStrip_Pick` - it already pays one
//--- type read per object) now asks each fibo THE question: "is the pen still the one your
//--- master would build?" - one probe, four anchor reads, one ray read and one memo
//--- compare while healthy; only a MISMATCH pays the sync (which re-anchors the rows,
//--- mirrors the rays and re-memoizes). A still chart pays reads and writes nothing.
#define FIBPEN_NET_SLOTS 8
static string s_fpNetName[FIBPEN_NET_SLOTS];
static long   s_fpNetT0[FIBPEN_NET_SLOTS], s_fpNetT1[FIBPEN_NET_SLOTS], s_fpNetT2[FIBPEN_NET_SLOTS];
static double s_fpNetP0[FIBPEN_NET_SLOTS], s_fpNetP1[FIBPEN_NET_SLOTS], s_fpNetP2[FIBPEN_NET_SLOTS];
static int    s_fpNetRay[FIBPEN_NET_SLOTS], s_fpNetPen[FIBPEN_NET_SLOTS];
static int    s_fpNetNext = 0;
int FibPenNetFind(const string fibo)
{
   if(fibo == "") return -1;
   for(int i = 0; i < FIBPEN_NET_SLOTS; i++)
      if(s_fpNetName[i] == fibo) return i;
   return -1;
}
void FibPenNetWrite(const string fibo, const long t0, const long t1, const long t2,
                    const double p0, const double p1, const double p2,
                    const int ray, const bool pen)
{
   int at = FibPenNetFind(fibo);
   if(at < 0)
   {
      at = s_fpNetNext;
      s_fpNetNext = (s_fpNetNext + 1) % FIBPEN_NET_SLOTS;
      s_fpNetName[at] = fibo;
   }
   s_fpNetT0[at] = t0; s_fpNetT1[at] = t1; s_fpNetT2[at] = t2;
   s_fpNetP0[at] = p0; s_fpNetP1[at] = p1; s_fpNetP2[at] = p2;
   s_fpNetRay[at] = ray;
   s_fpNetPen[at] = (pen ? 1 : 0);
}
bool FibPenHeal(const string fibo)
{
   if(fibo == "" || ObjectFind(0, fibo) < 0) return false;
   if(s_fibPreview && fibo == s_fibPreviewObj) return false;   // P-DRAGF3: the preview owns the gesture
   int    ty = DrawObjectType(fibo);
   if(!FibPenServesType(ty)) return false;
   long   t0 = (long)ObjectGetInteger(0, fibo, OBJPROP_TIME, 0);
   long   t1 = (long)ObjectGetInteger(0, fibo, OBJPROP_TIME, 1);
   double p0 = ObjectGetDouble(0, fibo, OBJPROP_PRICE, 0);
   double p1 = ObjectGetDouble(0, fibo, OBJPROP_PRICE, 1);
   bool   three = (ty == OBJ_FIBOCHANNEL || ty == OBJ_EXPANSION);
   long   t2 = three ? (long)ObjectGetInteger(0, fibo, OBJPROP_TIME, 2) : 0;
   double p2 = three ? ObjectGetDouble(0, fibo, OBJPROP_PRICE, 2) : 0.0;
   int    ray = FibPenRayBits(fibo);
   bool   pen = FibPenHasPen(fibo);
   int    at  = FibPenNetFind(fibo);
   if(at >= 0 && s_fpNetT0[at] == t0 && s_fpNetT1[at] == t1 && s_fpNetT2[at] == t2 &&
      s_fpNetP0[at] == p0 && s_fpNetP1[at] == p1 && s_fpNetP2[at] == p2 &&
      s_fpNetRay[at] == ray && s_fpNetPen[at] == (pen ? 1 : 0))
      return false;   // the pen is what the master's last sync built: reads only
   return FibPenSync(fibo, false);
}
//--- the pen's children answer for their own parent (the sweep's orphan rule, the same
//--- shape the interior's and the 50 % line's already have): a reload while a fibo was
//--- deleted must not leave a styled band hanging on nothing.
string FibPenChildParent(const string name)
{
   int cut = -1;
   for(int i = 0; i + 3 < StringLen(name); i++)
      if(StringGetCharacter(name, i) == '_' &&
         StringGetCharacter(name, i + 1) == 'F' &&
         StringGetCharacter(name, i + 2) == 'S') cut = i;
   if(cut <= 0) return "";
   return StringSubstr(name, 0, cut);
}
//--- the FIBPEN witness channel (PathTool.mqh:31 is the precedent): Full borrows
//--- the strip's flushed file; Lite ships no strip, so MQL4's no-body rule
//--- (error 111) needs the journal fallback defined HERE, in the caller file.
#ifndef BUILD_LITE
//--- P-WARN-46 (2026-10-04): no prototype owed - `DrawStripDiagEmit`'s body is in this
//--- unit (DrawStrip_Base.mqh) and MQL4 resolves it.
#else
// P-MT5-PARITY (2026-10-21) - PARITY (MT4 FibPen.mqh:766): the fallback is THE JOURNAL, never silence.
// MT5's P-PERF-13 made it an empty body; MT4's off-build prints.
void DrawStripDiagEmit(const string line) { Print(line); }
#endif

//--- name-keyed sweep for the delete hub (DrawStrip_Router): the object is gone,
//--- so no kind check — names this unit never built simply probe absent. The ONE
//--- sweep; the sync's delete path calls it instead of keeping a second copy.
bool FibPenStraysDrop(const string fibo)
{
   if(fibo == "") return false;
   bool dd = false;
   for(int dl = 0; dl < FIBPEN_MAX_LEVELS; dl++)
   {
      for(int q = 0; ; q++)
      {
         string nm = FibPenName(fibo, dl, q);
         if(ObjectFind(0, nm) < 0) break;
         ObjectDelete(0, nm);
         dd = true;
      }
      string cn = FibPenCapName(fibo, dl);
      if(ObjectFind(0, cn) >= 0) { ObjectDelete(0, cn); dd = true; }
      string wn = FibPenWashName(fibo, dl);
      if(ObjectFind(0, wn) >= 0) { ObjectDelete(0, wn); dd = true; }
      string sn = FibPenShwName(fibo, dl);   // P-LOOK-3D: the fourth family sweeps with the rest
      if(ObjectFind(0, sn) >= 0) { ObjectDelete(0, sn); dd = true; }
   }
   return dd;
}

//--- the ONE sync: demotes the undrawable width, builds / refreshes / drops
//--- each level's stack in the level's own style and ink. Guarded throughout:
//--- a still frame pays reads, writes nothing. dropAll is the delete path.
bool FibPenSync(const string fibo, const bool dropAll)
{
   if(fibo == "" || ObjectFind(0, fibo) < 0) return false;
   if(DrawIsIndicatorObject(fibo)) return false;   // the indicator's own levels are never served
   if(s_fibPreview && !dropAll && fibo == s_fibPreviewObj) return false;   // P-DRAGF3: gated while the preview owns the gesture; dropAll (delete) is never gated
   EDrawKind k = DrawKindOf(fibo);
   if(!FibPenServesType(DrawObjectType(fibo))) return false;
   bool dirty = FibPenTagDrop(fibo);   // transition: spend a v2 [FWn], never written again
   int nDem = 0, nNew = 0, nDrop = 0, nUni = 0;   // the flushed witness counts below
   int nMov = 0;   // DIAG-139: child moves this call (the drag question below)
   bool coreN[FIBPEN_MAX_LEVELS] = {false, false, false, false, false, false, false, false, false, false, false, false};
   color wbg = GetCachedChartBgColor();
   int lk = FibPenLookGet(fibo);
   if(lk > 0 && (int)ObjectGetInteger(0, fibo, OBJPROP_LEVELSTYLE, 0) != FibPenLookNative(lk))
   {
      FibPenLookDrop(fibo);   // the MT4 dialog wrote native: one truth, not two
      lk = 0;
   }
   int nl = DrawLevelCount(fibo);
   int nw = (nl > FIBPEN_MAX_LEVELS) ? FIBPEN_MAX_LEVELS : nl;
   if(nw <= 0 || dropAll)
   {
      // P-LOOK: every family the unit ever built dies here — a look switch strands
      // the previous look's children, and only this sweep can name them all.
      if(!dropAll && ObjectFind(0, FibPenName(fibo, 0, 0)) < 0 &&
         ObjectFind(0, FibPenCapName(fibo, 0)) < 0 &&
         ObjectFind(0, FibPenWashName(fibo, 0)) < 0 &&
         ObjectFind(0, FibPenShwName(fibo, 0)) < 0) return false;
      bool dd = FibPenStraysDrop(fibo);
      if(dd || dirty)
         DrawStripDiagEmit("[drawstrip] FIBPEN fibo=\"" + fibo + "\" dropall=1 look=" + IntegerToString(lk));
      //--- P-LOOK-RAY2: the net's memo follows the truth - no pen stands here now, so the
      //--- next pass asks the master (and only a master that asks for one is served).
      bool three = (k == DK_FIBOCHAN || k == DK_EXPANSION);
      FibPenNetWrite(fibo, (long)ObjectGetInteger(0, fibo, OBJPROP_TIME, 0),
                     (long)ObjectGetInteger(0, fibo, OBJPROP_TIME, 1),
                     three ? (long)ObjectGetInteger(0, fibo, OBJPROP_TIME, 2) : 0,
                     ObjectGetDouble(0, fibo, OBJPROP_PRICE, 0),
                     ObjectGetDouble(0, fibo, OBJPROP_PRICE, 1),
                     three ? ObjectGetDouble(0, fibo, OBJPROP_PRICE, 2) : 0.0,
                     FibPenRayBits(fibo), false);
      return (dd || dirty);
   }
   double px = FibPenPixelPrice();
   bool pxOk = (px > 0.0);
   //--- P-LOOK-ALL (2026-10-03) — ONE fibo, ONE look. MT4 lets every level wear
   //--- its own width and style (the dialog edits one level at a time), so a fibo
   //--- arrives mixed and the strip can only show — and keep — level 0's. The
   //--- reference IS level 0 (what the strip displays); every other level is
   //--- converged onto it through the same demote/stack flow. Guarded: a uniform
   //--- fibo pays reads, writes nothing.
   int refSt = (int)ObjectGetInteger(0, fibo, OBJPROP_LEVELSTYLE, 0);
   if(refSt < (int)STYLE_SOLID || refSt > (int)STYLE_DASHDOTDOT) refSt = (int)STYLE_SOLID;
   int refLog = FibPenLogicalWidth(fibo, 0);
    datetime ta = (datetime)ObjectGetInteger(0, fibo, OBJPROP_TIME, 0);
    datetime tb = (datetime)ObjectGetInteger(0, fibo, OBJPROP_TIME, 1);
    datetime ts0 = (ta < tb ? ta : tb);   // P-LOOK-RAY5b: the rows' span is ordered
    datetime ts1 = (ta < tb ? tb : ta);   // ...early to late, whatever order the hand drew
   double p1 = ObjectGetDouble(0, fibo, OBJPROP_PRICE, 0);
   double p2 = ObjectGetDouble(0, fibo, OBJPROP_PRICE, 1);
   bool three = (k == DK_FIBOCHAN || k == DK_EXPANSION);
   datetime t3 = three ? (datetime)ObjectGetInteger(0, fibo, OBJPROP_TIME, 2) : 0;
   double p3 = three ? ObjectGetDouble(0, fibo, OBJPROP_PRICE, 2) : 0.0;
   bool anchorsOk = (ta > 0 && tb > 0 && p1 > 0.0 && p2 > 0.0 &&
                     (!three || (t3 > 0 && p3 > 0.0)));
   //--- P-LOOK-ANCHOR (2026-10-18) — MT4 PUTS 0 % AT THE SECOND ANCHOR. MEASURED on the
   //--- shot chart (StripShot_fibo_3d3.png, AMarkets A1660): the band carrying the «0.0»
   //--- label sits at PRICE,1 (y=445) and «423.6» at PRICE,1 + (PRICE,0 - PRICE,1) * 4.236
   //--- = 1.11605 (y=633) — label text and pixels agree within 1 px across all nine bands,
   //--- and the FSH family dump sits exactly where its own prices say. So the terminal's
   //--- law is lv = PRICE,1 + (PRICE,0 - PRICE,1) * v, and the old p1 + (p2 - p1) * v wore
   //--- the mirror twin R(1 - v): every child (stack rows, caps, wash) sat under the
   //--- wrong level — the «3D واقعی نیست» report, whose 3D shadow measured at 305/376/420
   //--- (since retired) — and both hit tests (DrawHitLevels, DrawFiboFullHit) measured
   //--- lines MT4 never draws. Every mapping site states THIS law: this head, the chase,
   //--- caps, wash, and the two hit tests. Gate: P-LOOK-ANCHOR.
   //--- P-LOOK-RAY2: the pen mirrors the master's own level rays (one read per sync).
   bool penRL = false, penRR = false;
   FibPenRayPair(fibo, penRL, penRR);
   int backLayer = (int)ObjectGetInteger(0, fibo, OBJPROP_BACK);
   bool need[FIBPEN_MAX_LEVELS] = {false, false, false, false, false, false, false, false, false, false, false, false};
   int wantN[FIBPEN_MAX_LEVELS] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
   int logW[FIBPEN_MAX_LEVELS] = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1};
   int styA[FIBPEN_MAX_LEVELS] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
   color colA[FIBPEN_MAX_LEVELS] = {clrNONE, clrNONE, clrNONE, clrNONE, clrNONE, clrNONE, clrNONE, clrNONE, clrNONE, clrNONE, clrNONE, clrNONE};
   datetime t1a[FIBPEN_MAX_LEVELS] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
   datetime t2a[FIBPEN_MAX_LEVELS] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
   double lva[FIBPEN_MAX_LEVELS] = {0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0};
   double lvb[FIBPEN_MAX_LEVELS] = {0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0};
   for(int l = 0; l < nw; l++)
   {
      int curW = (int)ObjectGetInteger(0, fibo, OBJPROP_LEVELWIDTH, l);
      int curSt = (int)ObjectGetInteger(0, fibo, OBJPROP_LEVELSTYLE, l);
      if(curW < DRAW_WIDTH_MIN) curW = DRAW_WIDTH_MIN;
      if(curW > DRAW_WIDTH_MAX) curW = DRAW_WIDTH_MAX;
      if(curSt != refSt)
      {
         ObjectSetInteger(0, fibo, OBJPROP_LEVELSTYLE, l, refSt);
         dirty = true; nUni++;
         curSt = refSt;
      }
      bool rowOk = false;
      double lvA = 0.0, lvB = 0.0;
      if(anchorsOk)
      {
         double v = ObjectGetDouble(0, fibo, OBJPROP_LEVELVALUE, l);
         if(MathIsValidNumber(v))
         {
            lvA = DrawLevelPriceAt(k, v, ta, p1, tb, p2, t3, p3, ts0);
            lvB = DrawLevelPriceAt(k, v, ta, p1, tb, p2, t3, p3, ts1);
            if(lvA > 0.0 && lvB > 0.0) rowOk = true;
         }
      }
      int want = 0, vis = curW;
      if(rowOk && pxOk)
      {
         vis = (refSt != (int)STYLE_SOLID && refLog > DRAW_WIDTH_MIN) ? DRAW_WIDTH_MIN : refLog;
         want = (refSt != (int)STYLE_SOLID && refLog > DRAW_WIDTH_MIN) ? refLog - 1 : 0;
      }
      if(curW != vis)
      {
         ObjectSetInteger(0, fibo, OBJPROP_LEVELWIDTH, l, vis);
         dirty = true; nDem++;
      }
      need[l] = (want > 0);
      wantN[l] = want;
      logW[l] = refLog;
      styA[l] = refSt;
       colA[l] = (color)(int)ObjectGetInteger(0, fibo, OBJPROP_LEVELCOLOR, l);
       t1a[l] = ts0;
       t2a[l] = ts1;
       lva[l] = lvA;
       lvb[l] = lvB;
   }
   //--- levels past the stack cap converge the same way (thin dash), never stack.
   for(int lx = nw; lx < nl; lx++)
   {
      int wX = (int)ObjectGetInteger(0, fibo, OBJPROP_LEVELWIDTH, lx);
      int sX = (int)ObjectGetInteger(0, fibo, OBJPROP_LEVELSTYLE, lx);
      if(sX != refSt)
      {
         ObjectSetInteger(0, fibo, OBJPROP_LEVELSTYLE, lx, refSt);
         dirty = true; nUni++;
      }
      int visX = wX;
      if(pxOk) visX = (refSt != (int)STYLE_SOLID && refLog > DRAW_WIDTH_MIN) ? DRAW_WIDTH_MIN : refLog;
      if(wX != visX)
      {
         ObjectSetInteger(0, fibo, OBJPROP_LEVELWIDTH, lx, visX);
         dirty = true; nDem++;
      }
   }
   for(int l2 = 0; l2 < nw; l2++)
   {
      if(!need[l2]) continue;
      for(int q2 = 0; q2 < wantN[l2]; q2++)
      {
         string nm2 = FibPenName(fibo, l2, q2);
         double rowPa = lva[l2] + FibPenOffPx(logW[l2], q2) * px;
         double rowPb = lvb[l2] + FibPenOffPx(logW[l2], q2) * px;
         if(ObjectFind(0, nm2) < 0)
         {
            if(!pxOk) continue;
            if(!ObjectCreate(0, nm2, OBJ_TREND, 0, t1a[l2], rowPa, t2a[l2], rowPb)) continue;
            ObjectSetInteger(0, nm2, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, nm2, OBJPROP_HIDDEN, true);
            // P-LOOK-RAY2: the pen is as wide as the LINE, not wider. The fibo's own
            // level-ray pair is read once above; a level line that stops at its anchors
            // gets a pen that stops with it, one that runs edge to edge gets a pen that
            // does the same.
            ObjectSetInteger(0, nm2, OBJPROP_RAY_LEFT, penRL);
            ObjectSetInteger(0, nm2, OBJPROP_RAY_RIGHT, penRR);
            dirty = true; nNew++;
         }
         if(pxOk)
         {
            if((datetime)ObjectGetInteger(0, nm2, OBJPROP_TIME, 0) != t1a[l2] ||
               ObjectGetDouble(0, nm2, OBJPROP_PRICE, 0) != rowPa)
               { ObjectMove(0, nm2, 0, t1a[l2], rowPa); nMov++; }
            if((datetime)ObjectGetInteger(0, nm2, OBJPROP_TIME, 1) != t2a[l2] ||
               ObjectGetDouble(0, nm2, OBJPROP_PRICE, 1) != rowPb)
               { ObjectMove(0, nm2, 1, t2a[l2], rowPb); nMov++; }
         }
         if((int)ObjectGetInteger(0, nm2, OBJPROP_WIDTH) != DRAW_WIDTH_MIN)
            ObjectSetInteger(0, nm2, OBJPROP_WIDTH, DRAW_WIDTH_MIN);
         if((int)ObjectGetInteger(0, nm2, OBJPROP_STYLE) != styA[l2])
            ObjectSetInteger(0, nm2, OBJPROP_STYLE, styA[l2]);
         if((color)(int)ObjectGetInteger(0, nm2, OBJPROP_COLOR) != colA[l2])
            ObjectSetInteger(0, nm2, OBJPROP_COLOR, colA[l2]);
         if((int)ObjectGetInteger(0, nm2, OBJPROP_BACK) != backLayer)
            ObjectSetInteger(0, nm2, OBJPROP_BACK, backLayer);
         // P-LOOK-RAY2: heal the mirror - guarded, and in BOTH directions, because a
         // fibo whose levels ray was turned off must take its pen back to the anchors
         // (the case the old heal could not express: it only ever raised).
         if(((int)ObjectGetInteger(0, nm2, OBJPROP_RAY_LEFT) != 0) != penRL)
            ObjectSetInteger(0, nm2, OBJPROP_RAY_LEFT, penRL);
         if(((int)ObjectGetInteger(0, nm2, OBJPROP_RAY_RIGHT) != 0) != penRR)
            ObjectSetInteger(0, nm2, OBJPROP_RAY_RIGHT, penRR);
      }
   }
   //--- P-LOOK — NEON core: one solid light tube at the level's own price.
   //--- Only a band 3+ wide has room for a tube; the dash edges keep the level's ink.
   for(int l3 = 0; l3 < nw; l3++)
   {
      coreN[l3] = false;
      if(lk != FIBPEN_LOOK_NEON || !need[l3] || logW[l3] < 3) continue;
      string cnm = FibPenName(fibo, l3, wantN[l3]);
      color lite = BlendColorTowardsBG(colA[l3], 50, clrWhite);
      if(ObjectFind(0, cnm) < 0)
      {
            if(!ObjectCreate(0, cnm, OBJ_TREND, 0, t1a[l3], lva[l3], t2a[l3], lvb[l3])) continue;
            ObjectSetInteger(0, cnm, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, cnm, OBJPROP_HIDDEN, true);
            ObjectSetInteger(0, cnm, OBJPROP_RAY_LEFT, penRL);   // P-LOOK-RAY2: the tube rides the line's own span
            ObjectSetInteger(0, cnm, OBJPROP_RAY_RIGHT, penRR);
         dirty = true; nNew++;
      }
      if((datetime)ObjectGetInteger(0, cnm, OBJPROP_TIME, 0) != t1a[l3] ||
            ObjectGetDouble(0, cnm, OBJPROP_PRICE, 0) != lva[l3])
            { ObjectMove(0, cnm, 0, t1a[l3], lva[l3]); nMov++; }
      if((datetime)ObjectGetInteger(0, cnm, OBJPROP_TIME, 1) != t2a[l3] ||
            ObjectGetDouble(0, cnm, OBJPROP_PRICE, 1) != lvb[l3])
            { ObjectMove(0, cnm, 1, t2a[l3], lvb[l3]); nMov++; }
      if((int)ObjectGetInteger(0, cnm, OBJPROP_WIDTH) != DRAW_WIDTH_MIN)
         ObjectSetInteger(0, cnm, OBJPROP_WIDTH, DRAW_WIDTH_MIN);
      if((int)ObjectGetInteger(0, cnm, OBJPROP_STYLE) != (int)STYLE_SOLID)
         ObjectSetInteger(0, cnm, OBJPROP_STYLE, STYLE_SOLID);
      if((color)(int)ObjectGetInteger(0, cnm, OBJPROP_COLOR) != lite)
         ObjectSetInteger(0, cnm, OBJPROP_COLOR, lite);
      if((int)ObjectGetInteger(0, cnm, OBJPROP_BACK) != backLayer)
         ObjectSetInteger(0, cnm, OBJPROP_BACK, backLayer);
      if(((int)ObjectGetInteger(0, cnm, OBJPROP_RAY_LEFT) != 0) != penRL)
         ObjectSetInteger(0, cnm, OBJPROP_RAY_LEFT, penRL);
      if(((int)ObjectGetInteger(0, cnm, OBJPROP_RAY_RIGHT) != 0) != penRR)
         ObjectSetInteger(0, cnm, OBJPROP_RAY_RIGHT, penRR);
      coreN[l3] = true;
   }
   //--- P-LOOK — CAPS: one solid end block per level over the span's last eighth.
   for(int l4 = 0; l4 < nw; l4++)
   {
      string pnm = FibPenCapName(fibo, l4);
      datetime tc = tb - (tb - ta) / 8;
      if(!(tc > ta)) tc = ta;
      double lpA = 0.0, lpB = 0.0;
      bool capOk = (lk == FIBPEN_LOOK_CAPS && anchorsOk);
      if(capOk)
      {
         double vv4 = ObjectGetDouble(0, fibo, OBJPROP_LEVELVALUE, l4);
         if(!MathIsValidNumber(vv4)) capOk = false;
         else
         {
            lpA = DrawLevelPriceAt(k, vv4, ta, p1, tb, p2, t3, p3, tc);
            lpB = DrawLevelPriceAt(k, vv4, ta, p1, tb, p2, t3, p3, tb);
            if(!(lpA > 0.0) || !(lpB > 0.0)) capOk = false;
         }
      }
      if(!capOk)
      {
         if(ObjectFind(0, pnm) >= 0) { ObjectDelete(0, pnm); dirty = true; nDrop++; }
         continue;
      }
      int cw = logW[l4];
      if(cw < DRAW_WIDTH_MIN) cw = DRAW_WIDTH_MIN;
      if(cw > DRAW_WIDTH_MAX) cw = DRAW_WIDTH_MAX;
      if(ObjectFind(0, pnm) < 0)
      {
         if(!ObjectCreate(0, pnm, OBJ_TREND, 0, tc, lpA, tb, lpB)) continue;
         ObjectSetInteger(0, pnm, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, pnm, OBJPROP_HIDDEN, true);
         ObjectSetInteger(0, pnm, OBJPROP_RAY_LEFT, false);
         ObjectSetInteger(0, pnm, OBJPROP_RAY_RIGHT, false);
         dirty = true; nNew++;
      }
      if((datetime)ObjectGetInteger(0, pnm, OBJPROP_TIME, 0) != tc ||
            ObjectGetDouble(0, pnm, OBJPROP_PRICE, 0) != lpA)
            { ObjectMove(0, pnm, 0, tc, lpA); nMov++; }
      if((datetime)ObjectGetInteger(0, pnm, OBJPROP_TIME, 1) != tb ||
            ObjectGetDouble(0, pnm, OBJPROP_PRICE, 1) != lpB)
            { ObjectMove(0, pnm, 1, tb, lpB); nMov++; }
      if((int)ObjectGetInteger(0, pnm, OBJPROP_WIDTH) != cw)
         ObjectSetInteger(0, pnm, OBJPROP_WIDTH, cw);
      if((int)ObjectGetInteger(0, pnm, OBJPROP_STYLE) != (int)STYLE_SOLID)
         ObjectSetInteger(0, pnm, OBJPROP_STYLE, STYLE_SOLID);
      if((color)(int)ObjectGetInteger(0, pnm, OBJPROP_COLOR) != colA[l4])
         ObjectSetInteger(0, pnm, OBJPROP_COLOR, colA[l4]);
      if((int)ObjectGetInteger(0, pnm, OBJPROP_BACK) != backLayer)
         ObjectSetInteger(0, pnm, OBJPROP_BACK, backLayer);
   }
   //--- P-LOOK — WASH: one dotted halo hugging each level, sunk behind the bars.
   for(int l5 = 0; l5 < nw; l5++)
   {
      string wnm = FibPenWashName(fibo, l5);
      double hpA = 0.0, hpB = 0.0;
      color haze = clrNONE;
      bool washOk = (lk == FIBPEN_LOOK_WASH && pxOk && anchorsOk &&
                     lva[l5] > 0.0 && lvb[l5] > 0.0);
      if(washOk)
      {
         hpA = lva[l5] + 2.0 * px;
         hpB = lvb[l5] + 2.0 * px;
         haze = BlendColorTowardsBG(colA[l5], 65, wbg);
      }
      if(!washOk)
      {
         if(ObjectFind(0, wnm) >= 0) { ObjectDelete(0, wnm); dirty = true; nDrop++; }
         continue;
      }
       if(ObjectFind(0, wnm) < 0)
       {
             if(!ObjectCreate(0, wnm, OBJ_TREND, 0, ts0, hpA, ts1, hpB)) continue;
            ObjectSetInteger(0, wnm, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, wnm, OBJPROP_HIDDEN, true);
            ObjectSetInteger(0, wnm, OBJPROP_RAY_LEFT, penRL);   // P-LOOK-RAY2: the halo hugs the level's own span
            ObjectSetInteger(0, wnm, OBJPROP_RAY_RIGHT, penRR);
         dirty = true; nNew++;
      }
       if((datetime)ObjectGetInteger(0, wnm, OBJPROP_TIME, 0) != ts0 ||
             ObjectGetDouble(0, wnm, OBJPROP_PRICE, 0) != hpA)
             { ObjectMove(0, wnm, 0, ts0, hpA); nMov++; }
       if((datetime)ObjectGetInteger(0, wnm, OBJPROP_TIME, 1) != ts1 ||
             ObjectGetDouble(0, wnm, OBJPROP_PRICE, 1) != hpB)
             { ObjectMove(0, wnm, 1, ts1, hpB); nMov++; }
      if((int)ObjectGetInteger(0, wnm, OBJPROP_WIDTH) != DRAW_WIDTH_MIN)
         ObjectSetInteger(0, wnm, OBJPROP_WIDTH, DRAW_WIDTH_MIN);
      if((int)ObjectGetInteger(0, wnm, OBJPROP_STYLE) != (int)STYLE_DOT)
         ObjectSetInteger(0, wnm, OBJPROP_STYLE, STYLE_DOT);
      if((color)(int)ObjectGetInteger(0, wnm, OBJPROP_COLOR) != haze)
         ObjectSetInteger(0, wnm, OBJPROP_COLOR, haze);
      if((int)ObjectGetInteger(0, wnm, OBJPROP_BACK) == 0)
         ObjectSetInteger(0, wnm, OBJPROP_BACK, true);
      if(((int)ObjectGetInteger(0, wnm, OBJPROP_RAY_LEFT) != 0) != penRL)
         ObjectSetInteger(0, wnm, OBJPROP_RAY_LEFT, penRL);
       if(((int)ObjectGetInteger(0, wnm, OBJPROP_RAY_RIGHT) != 0) != penRR)
          ObjectSetInteger(0, wnm, OBJPROP_RAY_RIGHT, penRR);
   }
    //--- P-LOOK-3D RETIRED (2026-10-18, «3D کلا حذف کن») — the shadow is never born
    //--- again. The `_FSH` family this unit still knows (the name, HasPen, the
    //--- early-out probe, the delete hub's sweep) is spent HERE: the first sync after
    //--- a reload deletes whatever an older build left, so a 3D fibo degrades to the
    //--- previous look — never to a dangling shadow. Present-only: still frames pay
    //--- one probe per level and write nothing.
    for(int l6 = 0; l6 < nw; l6++)
    {
       string snm = FibPenShwName(fibo, l6);
       if(ObjectFind(0, snm) >= 0) { ObjectDelete(0, snm); dirty = true; nDrop++; }
    }
   for(int dl2 = 0; dl2 < FIBPEN_MAX_LEVELS; dl2++)
   {
      int from = (!need[dl2] ? 0 : wantN[dl2] + (coreN[dl2] ? 1 : 0));
      for(int q3 = from; ; q3++)
      {
         string nm3 = FibPenName(fibo, dl2, q3);
         if(ObjectFind(0, nm3) < 0) break;
            ObjectDelete(0, nm3);
            dirty = true; nDrop++;
      }
   }
   //--- DIAG-136 (2026-10-03) — THE SYNC WITNESSES ITS OWN WRITES. A change the
   //--- terminal never shows («هرچی ضخیم تر انتخاب میکنم تاثییری نداره») is
   //--- unprovable from a screenshot: the line below says, per fibo, how many
   //--- levels demoted, children were born and strays dropped — through the
   //--- FLUSHED channel, never Print. Dirty-only: a still frame emits nothing.
   if(dirty)
      DrawStripDiagEmit("[drawstrip] FIBPEN fibo=\"" + fibo + "\" lv=" + IntegerToString(nl) +
                        " dem=" + IntegerToString(nDem) + " new=" + IntegerToString(nNew) +
                        " drop=" + IntegerToString(nDrop) + " uni=" + IntegerToString(nUni) +
                        " look=" + IntegerToString(lk) +
                        " rays=" + IntegerToString(FibPenRayBits(fibo)));
   //--- DIAG-139 (2026-10-03) — THE DRAG QUESTION, ANSWERED BY NUMBERS. A lag
   //--- report during a gesture («موقع درگ فریمش عقب میمونه») needs to know
   //--- whether the sync ran and what anchors it saw — not a screenshot. At most
   //--- one line per second while children actually move; still frames are silent.
   if(nMov > 0)
   {
      uint nowMs = GetTickCount();
      if(nowMs - s_fibMovMs > 1000 || nowMs < s_fibMovMs)
      {
         s_fibMovMs = nowMs;
         DrawStripDiagEmit("[drawstrip] FIBPENMOV fibo=\"" + fibo + "\" moved=" + IntegerToString(nMov) +
                           " ta=" + IntegerToString((long)ta) + " tb=" + IntegerToString((long)tb) +
                           " p1=" + DoubleToString(p1, _Digits) + " p2=" + DoubleToString(p2, _Digits));
      }
   }
   //--- P-LOOK-RAY2: the pen just built IS the pen this master asks for - the net's
   //--- memo records the master it was built from, so the next 2 s pass is one compare.
   FibPenNetWrite(fibo, (long)ta, (long)tb, three ? (long)t3 : 0,
                  p1, p2, three ? p3 : 0.0, FibPenRayBits(fibo), FibPenHasPen(fibo));
   return dirty;
}
#endif // FIBPEN_MQH
#include "PenStack.mqh"   // P-DRAW-74c: the whole-object pen (HLINE/VLINE/LINE), FibPen's offset law
#include "BoxPreview.mqh"   // P-DRAGF4: the box family's interior rides the terminal mid-gesture// Toolbar_B.mqh - DrawToolbar.mqh split 2026-09-29: exact lines 1200-2053, byte-identical, zero renames.
#ifndef TOOLBAR_B_MQH
#define TOOLBAR_B_MQH

// ══════════════════════════════════════════════════════════════════════════
// P-DRAW-128 (2026-10-13) — THE NATIVE SURFACE'S COLOUR IS A COLOUR TOO.
//
// The strip's chips, the popup and the HEX field all learn through
// `DrawSlotWrite` — the one owner of the kind memory. The terminal's OWN
// surfaces (the properties dialog, the floating trend-line toolbar) write
// OBJPROP_COLOR directly and arrive as CHARTEVENT_OBJECT_CHANGE, so the
// memory never heard about them: a drawing recoloured there and then copied
// (the terminal's own Ctrl+drag duplicate) came back wearing the OLD colour
// — «برمیگرده به رنگ خودش مثلا اگر از جای غیره به جز نوار استرینگ تغییر بکنه».
//
// The one question a raw OBJECT_CHANGE cannot answer is WHETHER THE COLOUR
// MOVED: a drop after a drag fires the same event with the colour untouched,
// and learning there would teach the kind a factory colour the hand never
// picked. So each drawing's colour as the TERMINAL holds it is witnessed in
// one bounded memo — primed at attach and at the object's own create,
// re-noted by every writer that sets OBJPROP_COLOR (so our own writes read
// back as "nothing moved"), forgotten on delete. A level kind is never
// witnessed at all: its colours belong to the LEVEL family (P-DRAW-BODY), not
// to the object's own seat. Cost on a still frame: zero.
// Cost per native change: one property read and one scan of at most
// DRAW_INK_MEMO_MAX names. The write rides the memory's own owner
// (`DrawPresetsSave`) — there is never a second persistence path.
// ══════════════════════════════════════════════════════════════════════════
#define DRAW_INK_MEMO_MAX 48
static string s_inkMemoNm[DRAW_INK_MEMO_MAX];
static color  s_inkMemoClr[DRAW_INK_MEMO_MAX];
static int    s_inkMemoNext = 0;   // round-robin seat once every slot is full

//--- the colour the TERMINAL holds for a drawing the strip would serve —
//--- clrNONE for a stranger, a ray, a path, a level kind, or a kind with no
//--- colour seat of its own.
color DrawInkWitnessRead(const string name, EDrawKind &kout)
{
   kout = DK_NONE;
   if(name == "" || ObjectFind(0, name) < 0) return clrNONE;
   if(DrawIsIndicatorObject(name)) return clrNONE;
   EDrawKind k = DrawKindOf(name);
   if(k == DK_NONE) return clrNONE;
   if(DrawIsHRay(name) || DrawIsPathSeg(name)) return clrNONE;    // P-HR-04/P-UI-136: learn nothing
   if((DrawKindCaps(k) & DRAW_CAP_COLOR) == 0) return clrNONE;
   //--- P-DRAW-BODY + P-DRAW-128: a level kind carries DRAW_CAP_COLOR through
   //--- DRAW_CAP_COMMON, but ITS colours live in the LEVEL family
   //--- (`OBJPROP_LEVELCOLOR`) — reading the object's own `OBJPROP_COLOR` there
   //--- answers a property the object does not have, so such a drawing is never
   //--- witnessed and never learned from. Its `kout` stays DK_NONE.
   if(DrawKindHasLevels(k)) return clrNONE;
   kout = k;
   return (color)(int)ObjectGetInteger(0, name, OBJPROP_COLOR);
}

//--- note what the chart now wears (the blend, not the pick the user made).
void DrawInkMemoNote(const string name, const color c)
{
   if(name == "" || (int)c < 0) return;
   for(int i = 0; i < DRAW_INK_MEMO_MAX; i++)
      if(s_inkMemoNm[i] == name) { s_inkMemoClr[i] = c; return; }
   for(int i = 0; i < DRAW_INK_MEMO_MAX; i++)
      if(s_inkMemoNm[i] == "")
      {
         s_inkMemoNm[i] = name; s_inkMemoClr[i] = c; return;
      }
   s_inkMemoNm[s_inkMemoNext] = name; s_inkMemoClr[s_inkMemoNext] = c;
   s_inkMemoNext = (s_inkMemoNext + 1) % DRAW_INK_MEMO_MAX;
}

void DrawInkMemoForget(const string name)
{
   if(name == "") return;
   for(int i = 0; i < DRAW_INK_MEMO_MAX; i++)
      if(s_inkMemoNm[i] == name) { s_inkMemoNm[i] = ""; s_inkMemoClr[i] = clrNONE; }
}

//--- did the COLOUR move since we last saw this drawing? A first sight is a
//--- witness, not a change — the attach walk and the create prime make first
//--- sights rare — but it is noted, so the NEXT change on it is still seen.
bool DrawInkMemoDelta(const string name, const color c)
{
   for(int i = 0; i < DRAW_INK_MEMO_MAX; i++)
      if(s_inkMemoNm[i] == name)
      {
         if(s_inkMemoClr[i] == c) return false;
         s_inkMemoClr[i] = c;
         return true;
      }
   DrawInkMemoNote(name, c);
   return false;
}

//--- one drawing, witnessed now (used at attach and at its own create).
void DrawInkMemoPrime(const string name)
{
   EDrawKind k;
   color c = DrawInkWitnessRead(name, k);
   if((int)c < 0) return;
   DrawInkMemoNote(name, c);
}

//--- once per attach, right after the memory tables load: every drawing already
//--- on the chart is witnessed, so the first native change after a reload is
//--- recognised as a change (the reload is exactly when the user tests this).
void DrawInkMemoInit()
{
   int total = ObjectsTotal(0, -1, -1);
   for(int i = 0; i < total; i++)
   {
      string nm = ObjectName(0, i, -1, -1);
      if(nm == "") continue;
      DrawInkMemoPrime(nm);
   }
}

//--- write ONE slot onto an object, and LEARN it into the kind's memory. The
//--- two halves are one call on purpose: an edit the user made is an edit the
//--- next drawing of that kind must wear, and splitting them would let one of
//--- the two drift.
//--- the OPACITY row's write: one tag, and the object re-wears the blend of the
//--- colour it already holds. Nothing else is touched. (Defined here, after the
//--- reader it asks — a bare `f();` above its definition is an IMPORT to MQL4.)
//--- P-DRAW-48 (2026-09-27) — AND IT WRITES THE COLOUR IT READ, NEVER A NEW ONE.
//--- Reported: «شفافیت هر رنگی رو تغییر میدم فقط سیاه میشه». The bar re-reads the
//--- object's colour EVERY frame it moves, so a read that cannot answer (an
//--- unparseable `[CL…]`, or a colour MT4 answers as `clrNONE`) fed the blend its
//--- own last blend: ~20 frames at a 30 ms cadence is `0.69^20`, i.e. any colour
//--- reached black in under a second and the black was then STORED as the pure.
//--- So: the tag is written only from a colour that IS one, the tag form is the six
//--- digits the reader parses, and a drawing with no colour keeps the pixels it has
//--- (the `[OPnn]` value is still recorded, it just has nothing to blend).
//--- P-DRAW-64: AND IT IS ROLE-AWARE — one bar, two tags. `slot` names the colour
//--- the bar is tuning: the BORDER (`[OP…]`, the object's own pixels) or the
//--- INTERIOR (`[FT…]`, the child's, or the level family's levels). The strip hands
//--- it the cell whose board is open, so the bar and the colour it sits under are
//--- always the same role.
void DrawSlotOpacitySet(const string name, const int op, const int slot)
{
   if(name == "" || ObjectFind(0, name) < 0) return;
   EDrawKind k = DrawKindOf(name);
   if(k == DK_NONE || k == DK_TEXT) return;
   bool inner = (slot == DRAW_SLOT_FILLCLR);
   if(inner && !DrawSlotAvailable(k, DRAW_SLOT_FILLCLR)) return;
   int v = op;
   if(v < DRAW_OP_MIN) v = DRAW_OP_MIN;
   if(v > 100) v = 100;
   //--- P-UI-137 (2026-10-02, user: "the transparency only applies to ONE of its
   //--- lines") — THE OPACITY IS THE PATH'S, NOT A SEGMENT'S. This writer aimed at
   //--- ONE name, so the fade landed on the segment under the hand and the polyline
   //--- came out half-faded (the measured screenshot: one pale leg among solid ones).
   //--- And the `[OP…]`/`[CL…]` tags it writes are PAINTED along a trend line, so the
   //--- path's numbers live in its own store and every sibling is re-inked in ONE
   //--- pass through the path's single writer. Cost: one blend + n writes, n = the
   //--- path's segment count, on the slider's own step. No other drawing is touched.
   if(DrawIsPathSeg(name))
   {
      string pid = "";
      if(!PathIdOfName(name, pid)) return;
      if(inner) return;              // a polyline has no interior: the Fill role is N/A
      color pp = clrNONE; int pv = 100;
      PathInkGet(pid, pp, pv);
      PathInkApply(pid, pp, v);
      return;
   }
   color pure = clrNONE;
   bool havePure = inner ? DrawSlotFillPure(name, pure) : DrawSlotColorPure(name, pure);
   if(!havePure)
   {
      pure = (color)(int)DrawSlotRead(name, inner ? DRAW_SLOT_FILLCLR : DRAW_SLOT_COLOR);
      havePure = ((int)pure >= 0);
   }
   string d = ObjectGetString(0, name, OBJPROP_TEXT);
   d = DrawDescTag(d, inner ? "[FT" : "[OP", IntegerToString(v));
   //--- the border's `[CL…]` is rewritten from the colour it READ (the healer); the
   //--- interior's is NOT: an interior with no colour of its own keeps following the
   //--- border, which is the state a pre-split drawing is in.
   if(!inner && havePure) d = DrawDescTag(d, "[CL", DrawDescColorHex(pure));
   if(d != ObjectGetString(0, name, OBJPROP_TEXT))
      ObjectSetString(0, name, OBJPROP_TEXT, d);
   if(!havePure) return;   // no colour on the drawing: nothing to blend, nothing written
   if(inner)
   {
      if(DrawKindHasFillBody(k)) FillChildSync(name);
      else DrawLevelsSetColor(name, DrawSlotRenderFillColor(name, pure));
      return;
   }
   color worn = DrawSlotRenderColor(name, pure);
   ObjectSetInteger(0, name, OBJPROP_COLOR, worn);
   //--- P-DRAW-128: the blend we just set IS the witness the native learner reads
   //--- back — without this note the opacity step's own OBJECT_CHANGE would look
   //--- like the hand re-inking the drawing and would be learned as a fresh pick.
   DrawInkMemoNote(name, worn);
   if(DrawKindHasLevels(k))
   {
      color ip;
      DrawLevelsSetColor(name, DrawSlotFillPure(name, ip) ? DrawSlotRenderFillColor(name, ip)
                                                          : DrawSlotRenderColor(name, pure));
   }
}

#define DRAW_TPL_MAX 12        // the ceiling per kind — two pages of six in the lists
#define DRAW_TPL_PAGE 6        // rows one page of the more-popover / Look tab shows
#define DRAW_TPL_FILE "Biotak\\DrawTemplates.csv"    // ONE file, global, not per chart
#define DRAW_TPL_LEGACY "Biotak\\DrawPresets.csv"    // P-DRAW-02's file: read ONCE, migrated, deleted
//--- P-DRAW-135 (2026-10-18) — «با همه چیزش ذخیره بشه». For the level family (the
//--- fibos) the LEVELS ARE THE DRAWING (P-DRAW-132's own words), and the nine-value
//--- look never carried them: a save stamped a default fibo onto every chart. The
//--- level set now rides a row of its OWN, the encoded string in that row's `name`
//--- column at index 100+slot — clear of the template band (0..11) and of the two
//--- reserved seats (255/254), so neither a band guard nor a reserved row can eat
//--- it, and a file without these rows reads exactly like today's.
#define DRAW_TPL_LVL_ROW 100
//--- P-DRAW-09c / P-DRAW-INK: the two reserved rows of the template file. They
//--- sit with the other row constants because MQL's preprocessor is sequential:
//--- a #define AFTER DrawTplSave is still undeclared INSIDE it (the 2026-10-20
//--- build's ten errors). Same values, same seats - only the declaration moved.
#define DRAW_LASTLOOK_SLOT 255
#define DRAW_LASTINK_SLOT  254

//--- THE LOOK, NAMED — the nine values one template carries and the two exact
//--- doubles they pack into. The bit map is P-DRAW-09c's, kept verbatim so every
//--- row a previous build wrote is still read: word A holds colour 24 bits, width
//--- 3, style 3, fill 1, ray 2, then font 7 at 34, glyph 8 at 41, back 1 at 49,
//--- and the colour's PRESENCE BIT at 33; word B holds the interior's colour in
//--- 24 bits plus its own presence bit at 24. `clrNONE` is -1 and `-1 & 0xFFFFFF`
//--- is WHITE, so presence — never a guess — tells "no colour of its own" from a
//--- colour nobody chose (P-DRAW-75's rule, one file over).
struct DrawLook
{
   color clr;
   int   width;
   int   style;
   bool  fill;
   int   ray;
   int   font;
   int   glyph;
   bool  back;
   color fillClr;
};

double DrawLookPackA(const DrawLook &L)
{
   long v = (long)((int)L.clr & 0xFFFFFF);
   v += ((long)(L.width & 0x7) << 24);
   v += ((long)(L.style & 0x7) << 27);
   v += ((long)(L.fill ? 1 : 0) << 30);
   v += ((long)(L.ray & 0x3) << 31);
   v += ((long)(((int)L.clr >= 0) ? 1 : 0) << 33);
   v += ((long)(L.font & 0x7F) << 34);
   v += ((long)(L.glyph & 0xFF) << 41);
   v += ((long)(L.back ? 1 : 0) << 49);
   return (double)v;
}
double DrawLookPackB(const DrawLook &L)
{
   long v = (long)((int)L.fillClr & 0xFFFFFF);
   v += ((long)(((int)L.fillClr >= 0) ? 1 : 0) << 24);
   return (double)v;
}
void DrawLookUnpackA(const double raw, DrawLook &L)
{
   long a = (long)raw;
   L.clr   = ((((a >> 33) & 0x1) != 0) ? (color)(int)(a & 0xFFFFFF) : clrNONE);
   L.width = (int)((a >> 24) & 0x7);
   L.style = (int)((a >> 27) & 0x7);
   L.fill  = (((a >> 30) & 0x1) != 0);
   L.ray   = (int)((a >> 31) & 0x3);
   L.font  = (int)((a >> 34) & 0x7F);
   L.glyph = (int)((a >> 41) & 0xFF);
   L.back  = (((a >> 49) & 0x1) != 0);
}
void DrawLookUnpackB(const double raw, DrawLook &L)
{
   long b = (long)raw;
   b &= 0x1FFFFFF;   // word B is 25 bits: 24 of colour + its own presence bit
   L.fillClr = ((((b >> 24) & 0x1) != 0) ? (color)(int)(b & 0xFFFFFF) : clrNONE);
}

//--- P-DRAW-135 — THE LEVEL SET, ENCODED AND DECODED. The encoder reads the object's
//--- own truth exactly as `DrawStripLevelsCollect` does (raw ratios — MT4's real
//--- storage — and the remembered width via `FibPenLogicalWidth`, P-DRAW-74b), one
//--- record per level: `value:colour:width:style:text`, records joined by '|'. The
//--- text is the user's own word, so the two separators a split can never survive
//--- (';' breaks the CSV line, '|' breaks the record walk) are traded for safe ink;
//--- ':' MAY ride a note because the parser takes the text as the REST of a record.
string DrawTplLevelsOf(const string name)
{
   if(name == "" || ObjectFind(0, name) < 0) return "";
   if(!DrawKindHasLevels(DrawKindOf(name))) return "";
   int n = (int)ObjectGetInteger(0, name, OBJPROP_LEVELS);
   if(n <= 0) return "";
   if(n > 32) n = 32;
   string out = "";
   for(int i = 0; i < n; i++)
   {
      double v = ObjectGetDouble(0, name, OBJPROP_LEVELVALUE, i);
      if(!MathIsValidNumber(v)) continue;
      string t = ObjectGetString(0, name, OBJPROP_LEVELTEXT, i);
      StringReplace(t, ";", ",");
      StringReplace(t, "|", "/");
      StringReplace(t, "\n", " ");
      StringReplace(t, "\r", " ");
      if(out != "") out += "|";
      out += DoubleToString(v, 6) + ":" +
             IntegerToString((int)ObjectGetInteger(0, name, OBJPROP_LEVELCOLOR, i)) + ":" +
             IntegerToString(FibPenLogicalWidth(name, i)) + ":" +
             IntegerToString((int)ObjectGetInteger(0, name, OBJPROP_LEVELSTYLE, i)) + ":" + t;
   }
   return out;
}
bool DrawTplLevelsTo(const string name, const string enc)
{
   if(name == "" || enc == "" || ObjectFind(0, name) < 0) return false;
   if(!DrawKindHasLevels(DrawKindOf(name))) return false;
   double vv[32]; int cc[32], ww[32], ss[32]; string tt[32];
   ArrayInitialize(vv, 0.0); ArrayInitialize(cc, 0); ArrayInitialize(ww, 0); ArrayInitialize(ss, 0);
   int n = 0;
   int pos = 0, len = StringLen(enc);
   while(pos < len && n < 32)
   {
      int bar = StringFind(enc, "|", pos);
      string rec = (bar < 0 ? StringSubstr(enc, pos) : StringSubstr(enc, pos, bar - pos));
      int p1 = StringFind(rec, ":");
      int p2 = (p1 >= 0 ? StringFind(rec, ":", p1 + 1) : -1);
      int p3 = (p2 >= 0 ? StringFind(rec, ":", p2 + 1) : -1);
      int p4 = (p3 >= 0 ? StringFind(rec, ":", p3 + 1) : -1);
      if(p4 > 0)
      {
         double v = StringToDouble(StringSubstr(rec, 0, p1));
         if(MathIsValidNumber(v))
         {
            vv[n] = v;
            cc[n] = (int)StringToInteger(StringSubstr(rec, p1 + 1, p2 - p1 - 1));
            ww[n] = (int)StringToInteger(StringSubstr(rec, p2 + 1, p3 - p2 - 1));
            ss[n] = (int)StringToInteger(StringSubstr(rec, p3 + 1, p4 - p3 - 1));
            tt[n] = StringSubstr(rec, p4 + 1);
            n++;
         }
      }
      if(bar < 0) break;
      pos = bar + 1;
   }
   if(n <= 0) return false;
   FibPenTagDrop(name);   // P-DRAW-74b: the written set IS the truth — the memory is spent
   ObjectSetInteger(0, name, OBJPROP_LEVELS, n);
   for(int i = 0; i < n; i++)
   {
      ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, i, vv[i]);
      ObjectSetInteger(0, name, OBJPROP_LEVELCOLOR, i, cc[i]);
      ObjectSetInteger(0, name, OBJPROP_LEVELWIDTH, i, ww[i]);
      ObjectSetInteger(0, name, OBJPROP_LEVELSTYLE, i, ss[i]);
      ObjectSetString(0, name, OBJPROP_LEVELTEXT, i, tt[i]);
   }
   FibPenSync(name, false);   // P-DRAW-74b: the pair converges on the new truth
   return true;
}

//--- ONE NAMED TEMPLATE: its two packed words and the user's own word for it —
//--- the NAME is why the store is a FILE (P-DRAW-07: a GV holds a double, so a
//--- label had nowhere to go and every user slot came back "My 1").
struct DrawTpl
{
   bool   used;
   string name;
   double packA;
   double packB;
   string lvl;   // P-DRAW-135: the level set, encoded — "" = a template that never carried one
};
static DrawTpl s_dkTpl[DK_COUNT][DRAW_TPL_MAX];

//--- P-DRAW-132: WHILE THIS IS ABOVE ZERO `DrawSlotWrite` does NOT save. One
//--- APPLY writes five to nine slots and would otherwise pay one full-file pass
//--- per slot; the applier raises it, writes the whole look, lowers it and saves
//--- ONCE. Zero cost on every other path — a write outside an apply still saves.
static int s_dkTplHold = 0;

//--- rows a kind really carries (a delete COMPACTS, so they are 0..n-1 always).
int DrawTplCount(const EDrawKind k)
{
   if(k <= DK_NONE || k >= DK_COUNT) return 0;
   int n = 0;
   for(int i = 0; i < DRAW_TPL_MAX; i++) if(s_dkTpl[k][i].used) n++;
   return n;
}
string DrawTplName(const EDrawKind k, const int slot)
{
   if(k <= DK_NONE || k >= DK_COUNT) return "";
   if(slot < 0 || slot >= DRAW_TPL_MAX) return "";
   return s_dkTpl[k][slot].used ? s_dkTpl[k][slot].name : "";
}
//--- the row whose name is `nm`, case-insensitively — the saver and the remover
//--- both want the user's intent, not the bytes the keyboard produced. -1 = none.
int DrawTplIndex(const EDrawKind k, const string nm)
{
   if(k <= DK_NONE || k >= DK_COUNT || nm == "") return -1;
   int n = DrawTplCount(k);
   for(int i = 0; i < n; i++)
      if(StringCompare(s_dkTpl[k][i].name, nm, false) == 0) return i;
   return -1;
}
//--- PUT — the ONE writer of the rack. Same name (case-insensitive) REPLACES in
//--- place; a new name APPENDS; a FULL rack refuses (0) instead of silently
//--- overwriting the oldest template the user still owns. 1 = added, 2 = replaced.
int DrawTplPut(const EDrawKind k, const string nm, const DrawLook &L, const string lvls = "")
{
   if(k <= DK_NONE || k >= DK_COUNT || nm == "") return 0;
   int at = DrawTplIndex(k, nm);
   int res = 2;
   if(at < 0)
   {
      if(DrawTplCount(k) >= DRAW_TPL_MAX) return 0;
      at = DrawTplCount(k);
      s_dkTpl[k][at].used = true;
      s_dkTpl[k][at].name = nm;
      res = 1;
   }
   s_dkTpl[k][at].packA = DrawLookPackA(L);
   s_dkTpl[k][at].packB = DrawLookPackB(L);
   s_dkTpl[k][at].lvl   = lvls;   // P-DRAW-135: a re-save replaces the level set with the new one
   return res;
}

//--- THE SEEDS. Three per kind family, chosen to be the three looks a trader
//--- actually reaches for: the plain one, the loud one, and the quiet one. They
//--- are ordinary templates — written through `DrawTplPut`, so the user renames
//--- one by saving over it and deletes one like any other row. They are seeded
//--- ONLY when the file does not exist yet; after that the file is the truth, so
//--- a deleted seed stays deleted (P-DRAW-132).
void DrawTplSeedOne(const EDrawKind k, const string nm, const color c,
                    const int w, const int st, const bool fl, const int ry)
{
   DrawLook L;
   L.clr     = c;
   L.width   = w;
   L.style   = st;
   L.fill    = fl;
   L.ray     = ry;
   L.font    = DRAW_FONT_DEF;
   L.glyph   = 0;
   L.back    = false;
   L.fillClr = clrNONE;
   DrawTplPut(k, nm, L);
}
void DrawTplSeed()
{
   //--- lines and rays: the workhorses
   DrawTplSeedOne(DK_LINE, "Trend",   clrDodgerBlue, 1, (int)STYLE_SOLID,     false, 0);
   DrawTplSeedOne(DK_LINE, "Ray",     clrOrangeRed,  1, (int)STYLE_SOLID,     false, 1);
   DrawTplSeedOne(DK_LINE, "Quiet",   clrGray,       1, (int)STYLE_DOT,       false, 0);
   //--- the horizontal/vertical levels: two looks, one for marking, one for reading
   DrawTplSeedOne(DK_HLINE, "Level",  clrGold,       2, (int)STYLE_SOLID,     false, 0);
   DrawTplSeedOne(DK_HLINE, "Marker", clrRed,        1, (int)STYLE_DASH,      false, 0);
   DrawTplSeedOne(DK_HLINE, "Quiet",  clrSilver,     1, (int)STYLE_DOT,       false, 0);
   DrawTplSeedOne(DK_VLINE, "Session",clrGold,       1, (int)STYLE_DASH,      false, 0);
   DrawTplSeedOne(DK_VLINE, "Marker", clrRed,        1, (int)STYLE_SOLID,     false, 0);
   //--- the fibo family: the levels ARE the object, so the templates carry the
   //--- LEVEL look (colour/style/width) that MT4 makes the user set level by level
   DrawTplSeedOne(DK_FIBO, "Classic", clrGold,       1, (int)STYLE_SOLID,     false, 0);
   DrawTplSeedOne(DK_FIBO, "Zones",   clrOrange,     1, (int)STYLE_DASH,      false, 0);
   DrawTplSeedOne(DK_FIBO, "Quiet",   clrDimGray,    1, (int)STYLE_DOT,       false, 0);
   DrawTplSeedOne(DK_FIBOFAN, "Classic", clrGold,    1, (int)STYLE_SOLID,     false, 0);
   DrawTplSeedOne(DK_FIBOFAN, "Zones",   clrOrange,  1, (int)STYLE_DASH,      false, 0);
   DrawTplSeedOne(DK_FIBOCHAN, "Classic", clrGold,   1, (int)STYLE_SOLID,     false, 0);
   DrawTplSeedOne(DK_FIBOCHAN, "Filled",  clrGold,   1, (int)STYLE_SOLID,     true,  0);
   DrawTplSeedOne(DK_EXPANSION, "Classic", clrGold,  1, (int)STYLE_SOLID,     false, 0);
   //--- the boxes: the user's own example («چند باکس پرکاربرد»)
   DrawTplSeedOne(DK_RECT, "Box",     clrDodgerBlue, 1, (int)STYLE_SOLID,     false, 0);
   DrawTplSeedOne(DK_RECT, "Zone",    clrTeal,       1, (int)STYLE_DASH,      true,  0);
   DrawTplSeedOne(DK_RECT, "Demand",  clrCrimson,    1, (int)STYLE_SOLID,     true,  0);
   DrawTplSeedOne(DK_TRIANGLE, "Wedge", clrDodgerBlue, 1, (int)STYLE_SOLID,   true,  0);
   DrawTplSeedOne(DK_TRIANGLE, "Quiet", clrGray,     1, (int)STYLE_DASH,      false, 0);
   DrawTplSeedOne(DK_ELLIPSE, "Cycle", clrDodgerBlue, 1, (int)STYLE_SOLID,    false, 0);
   DrawTplSeedOne(DK_CHANNEL, "Channel", clrDodgerBlue, 1, (int)STYLE_SOLID,  false, 0);
   DrawTplSeedOne(DK_CHANNEL, "Quiet",   clrGray,     1, (int)STYLE_DASH,     false, 0);
   DrawTplSeedOne(DK_GANN, "Gann",    clrGold,       1, (int)STYLE_SOLID,     false, 0);
   DrawTplSeedOne(DK_PITCHFORK, "Fork", clrDodgerBlue, 1, (int)STYLE_SOLID,   false, 0);
   DrawTplSeedOne(DK_ARROW, "Mark",   clrRed,        1, (int)STYLE_SOLID,     false, 0);
   DrawTplSeedOne(DK_TEXT, "Note",    clrWhite,      1, (int)STYLE_SOLID,     false, 0);
}

//--- ONE TAP — the whole look (all nine values the kind can wear) onto the object
//--- AND into the kind's memory. The template is the FULL look; each write goes
//--- through its slot owner, guarded by the kind's caps exactly like the picker
//--- (a value the kind cannot wear is not written, never truncated), and the
//--- interior colour goes FIRST so a fill routed to a child is born with its
//--- colour already on the drawing (P-DRAW-64). `s_dkTplHold` batches the nine
//--- per-write saves into ONE file pass.
bool DrawTplApply(const string name, const int slot)
{
   if(name == "" || ObjectFind(0, name) < 0) return false;
   EDrawKind k = DrawKindOf(name);
   if(k == DK_NONE || slot < 0 || slot >= DRAW_TPL_MAX) return false;
   if(!s_dkTpl[k][slot].used) return false;
   DrawLook L;
   DrawLookUnpackA(s_dkTpl[k][slot].packA, L);
   DrawLookUnpackB(s_dkTpl[k][slot].packB, L);
   s_dkTplHold++;
   if((int)L.clr >= 0)
      DrawSlotWrite(name, DRAW_SLOT_COLOR, (double)(int)L.clr);
   DrawSlotWrite(name, DRAW_SLOT_WIDTH, (double)L.width);
   DrawSlotWrite(name, DRAW_SLOT_STYLE, (double)L.style);
   if((int)L.fillClr >= 0 && DrawSlotAvailable(k, DRAW_SLOT_FILLCLR))
      DrawSlotWrite(name, DRAW_SLOT_FILLCLR, (double)(int)L.fillClr);
   if(DrawSlotAvailable(k, DRAW_SLOT_FILL))
      DrawSlotWrite(name, DRAW_SLOT_FILL, L.fill ? 1.0 : 0.0);
   if(DrawSlotAvailable(k, DRAW_SLOT_RAY))
      DrawSlotWrite(name, DRAW_SLOT_RAY, (double)L.ray);
   if(DrawSlotAvailable(k, DRAW_SLOT_FONT))
      DrawSlotWrite(name, DRAW_SLOT_FONT, (double)L.font);
   if(DrawSlotAvailable(k, DRAW_SLOT_GLYPH))
      DrawSlotWrite(name, DRAW_SLOT_GLYPH, (double)L.glyph);
   if(DrawSlotAvailable(k, DRAW_SLOT_BACK))
      DrawSlotWrite(name, DRAW_SLOT_BACK, L.back ? 1.0 : 0.0);
   //--- P-DRAW-135: the level family's own truth rides LAST — after the slot writes
   //--- (whose colour/width/style land on ALL levels), so the template's exact
   //--- per-level rows win. A template without a level set leaves the target's alone.
   if(s_dkTpl[k][slot].lvl != "")
      DrawTplLevelsTo(name, s_dkTpl[k][slot].lvl);
   s_dkTplHold--;
   DrawTplSave();
   return true;
}

//--- «پاکش کن» — one row goes and the list COMPACTS: the rows after the hole move
//--- down, so every index the strip holds (the current-row mark) stays a row, not
//--- a slot. The seeds are ordinary rows now — deleting "Classic" is allowed and
//--- it comes back only for a user with no file at all (P-DRAW-132).
bool DrawTplDelete(const EDrawKind k, const int slot)
{
   if(k <= DK_NONE || k >= DK_COUNT) return false;
   int n = DrawTplCount(k);
   if(slot < 0 || slot >= n) return false;
   for(int i = slot; i < n - 1; i++)
   {
      s_dkTpl[k][i].used  = s_dkTpl[k][i + 1].used;
      s_dkTpl[k][i].name  = s_dkTpl[k][i + 1].name;
      s_dkTpl[k][i].packA = s_dkTpl[k][i + 1].packA;
      s_dkTpl[k][i].packB = s_dkTpl[k][i + 1].packB;
      s_dkTpl[k][i].lvl   = s_dkTpl[k][i + 1].lvl;   // P-DRAW-135: the level set moves with its row
   }
   s_dkTpl[k][n - 1].used  = false;
   s_dkTpl[k][n - 1].name  = "";
   s_dkTpl[k][n - 1].packA = 0.0;
   s_dkTpl[k][n - 1].packB = 0.0;
   s_dkTpl[k][n - 1].lvl   = "";
   DrawTplSave();
   return true;
}

//--- «ذخیره به عنوان تمپلیت» — the object's CURRENT look under the user's NAME.
//--- Same name (case-insensitively) replaces; empty name becomes "My <n>"; a full
//--- rack REFUSES (0) instead of silently eating the oldest row. Capture and
//--- persist are ONE act (P-DRAW-08b kept): a saved template that is not written
//--- is a template the user loses on the next attach. 1 = added, 2 = replaced.
int DrawTplSaveAs(const string name, const string label)
{
   if(name == "" || ObjectFind(0, name) < 0) return 0;
   EDrawKind k = DrawKindOf(name);
   if(k == DK_NONE) return 0;
   DrawStylePairCoerce(name);   // P-DRAW-74: never learn an illegal pair from the terminal dialog
   DrawLook L;
   L.clr     = (color)(int)DrawSlotRead(name, DRAW_SLOT_COLOR);
   L.width   = (int)DrawSlotRead(name, DRAW_SLOT_WIDTH);
   L.style   = (int)DrawSlotRead(name, DRAW_SLOT_STYLE);
   L.fill    = (DrawSlotRead(name, DRAW_SLOT_FILL) > 0.5);
   L.ray     = (int)DrawSlotRead(name, DRAW_SLOT_RAY);
   L.font    = (int)DrawSlotRead(name, DRAW_SLOT_FONT);
   L.glyph   = (int)DrawSlotRead(name, DRAW_SLOT_GLYPH);
   L.back    = (DrawSlotRead(name, DRAW_SLOT_BACK) > 0.5);
   L.fillClr = (color)(int)DrawSlotRead(name, DRAW_SLOT_FILLCLR);
   string nm = label;
   if(nm == "") nm = "My " + IntegerToString(DrawTplCount(k) + 1);
   //--- P-DRAW-135: the capture is the WHOLE look — the level family's own set rides
   //--- with the nine slot values («با همه چیزش ذخیره بشه»), so a template stamps a
   //--- whole fibo on any chart, on any pair. Non-level kinds encode "".
   string lv = DrawTplLevelsOf(name);
   int res = DrawTplPut(k, nm, L, lv);
   if(res > 0) DrawTplSave();
   return res;
}

//--- P-DRAW-76: `DrawPresetApplyToKind` (a chart-wide walk per apply) is DELETED. P-DRAW-03's
//--- "one look, every drawing of the kind" is live as `DrawStyleApplyToKind` (the popover's
//--- APPLY-ALL row), and a template reaches a whole GROUP through the strip's own selection loop
//--- (`DrawStripTplApplyGroup` -> `DrawTplApply` per member). Two owners of one act was
//--- the defect, and this one had no caller in any commit.

// ══════════════════════════════════════════════════════════════════════════
// P-DRAW-07 — THE TEMPLATES LIVE IN A FILE, BECAUSE A NAME IS NOT A NUMBER.
// (Kept by P-DRAW-132; the store it serves is the named rack above.)
//
// P-DRAW-05 stored one slot per GlobalVariable and hit the terminal's own wall:
// a GV holds a DOUBLE, so the user's label («My Box», «Supply 4H») had nowhere
// to go and every user slot came back as "My 1". That is the shape of limit this
// project refuses to ship: a template the user cannot NAME is a template they
// cannot find — exactly the ceiling MT4's own dialog has, where a look can only
// be "the last one" and never "my demand box".
//
// So the store is a FILE. MQL4's file API carries strings, and the project
// already keeps persistent state in files (the base-price history), so this is
// the codebase's own language, not a new one:
//
//   MQL4/Files/Biotak/DrawTemplates.csv    (ONE file, GLOBAL, not per chart)
//   kind ; row ; name ; packed-A ; packed-B
//
// WHY ONE GLOBAL FILE AND NOT ONE PER CHART: a template is the USER's look, not
// the chart's — «چند نوع فیبو که هر بار لازم نباشه از نو تنظیم بکنه» is a
// statement about the trader, and the same fibo look belongs on every chart they
// open. The chart id stays out of the name for that reason.
//
// The look is TWO exact doubles (the bit map lives with the packers above), so a
// line is five fields and the whole file is a few hundred bytes. Rows 255 and
// 254 are RESERVED inside the same file (P-DRAW-09c / P-DRAW-INK) and are read
// BEFORE any band guard — a guard read first would eat the very rows these
// features write (P-UI-133's lesson, one file over).
//
// WRITES ARE RARE AND GUARDED: a save happens when a template is saved, deleted
// or applied — never per frame — and an APPLY batches its nine slot writes into
// ONE save through `s_dkTplHold`. The file is rewritten in full, which for 17
// kinds × 12 rows is trivial and keeps ONE writer instead of an append log to
// reconcile.
// ══════════════════════════════════════════════════════════════════════════

string DrawTplPath() { return DRAW_TPL_FILE; }

//--- ONE LINE PER TEMPLATE, the user's NAME included — the whole rack, every kind.
//--- Rows are written in index order (the list is compact), so the reader takes
//--- them back in order; rows 255/254 keep their reserved seats (P-DRAW-09c /
//--- P-DRAW-INK may never fight a band guard — they ARE outside every band).
void DrawTplSave()
{
   int h = FileOpen(DrawTplPath(), FILE_WRITE | FILE_CSV | FILE_ANSI, ';');
   if(h == INVALID_HANDLE) return;
   for(int k = 1; k < DK_COUNT; k++)
   {
      int n = DrawTplCount((EDrawKind)k);
      for(int i = 0; i < n; i++)
      {
         FileWrite(h, (int)k, i, s_dkTpl[k][i].name,
                   DoubleToString(s_dkTpl[k][i].packA, 0),
                   DoubleToString(s_dkTpl[k][i].packB, 0));
         //--- P-DRAW-135: the template's level set rides its own reserved row — the
         //--- encoded string IS that row's `name` column; a template without one
         //--- writes nothing, so old files and non-level kinds are byte-identical.
         if(s_dkTpl[k][i].lvl != "")
            FileWrite(h, (int)k, DRAW_TPL_LVL_ROW + i, s_dkTpl[k][i].lvl, "0", "0");
      }
      //--- P-DRAW-09c: the kind's LAST LOOK rides the same file, in the reserved
      //--- slot. A kind the user never styled writes nothing, so the load can
      //--- leave it factory-fresh (the test's own «nobody styled» case).
      if(!s_dkValid[k]) continue;
      FileWrite(h, (int)k, DRAW_LASTLOOK_SLOT, "",
                DoubleToString(DrawStylePackA(k), 0), DoubleToString(DrawStylePackB(k), 0));
   }
   //--- P-DRAW-INK: and the ONE ink every kind shares has its own row. It is not a
   //--- kind's look, so it does not ride a kind's slot: a single reserved row answers
   //--- the next attach's first drawing.
   if((int)s_dkAnyClr >= 0)
      FileWrite(h, 1, DRAW_LASTINK_SLOT, IntegerToString((int)s_dkAnyClr), "0", "0");
   FileClose(h);
}

//--- P-DRAW-132 — ONE START, ONE TRUTH. The file is authoritative the moment it
//--- exists: a deleted seed stays deleted and a deleted template never comes back.
//--- Only a FIRST run seeds; a first run that finds P-DRAW-02's file migrates it
//--- first and retires it — after the new file is on disk, so a crash in between
//--- leaves the old rows readable. The reserved rows are answered BEFORE any band
//--- guard (P-DRAW-09c / P-DRAW-INK / P-UI-133's lesson, one file over).
void DrawTplLoad()
{
   int h = FileOpen(DrawTplPath(), FILE_READ | FILE_CSV | FILE_ANSI, ';');
   if(h == INVALID_HANDLE) return;
   while(!FileIsEnding(h))
   {
      int k = (int)StringToInteger(FileReadString(h));
      int i = (int)StringToInteger(FileReadString(h));
      string nm = FileReadString(h);
      string pa = FileReadString(h);
      string pb = FileReadString(h);
      if(FileIsEnding(h) && pb == "") break;
      if(i == DRAW_LASTLOOK_SLOT) { DrawStyleUnpack(k, StringToDouble(pa), StringToDouble(pb)); continue; }
      if(i == DRAW_LASTINK_SLOT) { int ink = (int)StringToInteger(nm); if(ink >= 0) s_dkAnyClr = (color)ink; continue; }
      if(k <= DK_NONE || k >= DK_COUNT) continue;
      //--- P-DRAW-135: the level rows are answered BEFORE the template band guard —
      //--- a guard asked first would eat the very rows this feature writes
      //--- (P-UI-133's lesson, one file over).
      if(i >= DRAW_TPL_LVL_ROW && i < DRAW_TPL_LVL_ROW + DRAW_TPL_MAX)
      { s_dkTpl[k][i - DRAW_TPL_LVL_ROW].lvl = nm; continue; }
      if(i < 0 || i >= DRAW_TPL_MAX) continue;
      s_dkTpl[k][i].used  = true;
      s_dkTpl[k][i].name  = (nm == "" ? ("My " + IntegerToString(i + 1)) : nm);
      s_dkTpl[k][i].packA = StringToDouble(pa);
      s_dkTpl[k][i].packB = StringToDouble(pb);
   }
   FileClose(h);
}

//--- P-DRAW-132 — THE ONE-TIME MIGRATION of P-DRAW-02's file (DrawPresets.csv).
//--- Old rows are `kind ; slot ; name ; packed-33-bit`, user slots 3..5 only (the
//--- 0..2 built-ins were never written), plus 255 (the last look, packed across
//--- TWO columns — B in `name`, A in `packed`) and 254 (the shared ink, a number
//--- in `name`). A user row moves whole — its colour/width/style/fill/ray exact —
//--- wearing today's fresh values for what the old pack did not carry (font,
//--- glyph, back, interior colour). The old built-ins are NOT migrated: the new
//--- seeds already carry the same three looks, and they are ordinary rows now.
void DrawTplMigrate()
{
   int h = FileOpen(DRAW_TPL_LEGACY, FILE_READ | FILE_CSV | FILE_ANSI, ';');
   if(h == INVALID_HANDLE) return;
   while(!FileIsEnding(h))
   {
      int k = (int)StringToInteger(FileReadString(h));
      int i = (int)StringToInteger(FileReadString(h));
      string nm = FileReadString(h);
      string pk = FileReadString(h);
      if(FileIsEnding(h) && pk == "") break;
      if(i == DRAW_LASTLOOK_SLOT) { DrawStyleUnpack(k, StringToDouble(pk), StringToDouble(nm)); continue; }
      if(i == DRAW_LASTINK_SLOT) { int ink = (int)StringToInteger(nm); if(ink >= 0) s_dkAnyClr = (color)ink; continue; }
      if(k <= DK_NONE || k >= DK_COUNT) continue;
      if(i < 3 || i >= 6) continue;   // the old rack: 0..2 built-ins, 3..5 the user's
      long v = (long)StringToDouble(pk);
      DrawLook L;
      L.clr     = (color)(int)(v & 0xFFFFFF);
      L.width   = (int)((v >> 24) & 0x7);
      L.style   = (int)((v >> 27) & 0x7);
      L.fill    = (((v >> 30) & 0x1) != 0);
      L.ray     = (int)((v >> 31) & 0x3);
      L.font    = DRAW_FONT_DEF;
      L.glyph   = 0;
      L.back    = false;
      L.fillClr = clrNONE;
      DrawTplPut((EDrawKind)k, (nm == "" ? ("My " + IntegerToString(i - 3 + 1)) : nm), L);
   }
   FileClose(h);
}

//--- P-DRAW-132 — ONE START: clear the rack, then let the FILE rule. First run:
//--- seed, migrate P-DRAW-02's file when it exists, write, then retire it.
void DrawTplBoot()
{
   for(int k = 0; k < DK_COUNT; k++)
      for(int i = 0; i < DRAW_TPL_MAX; i++)
      {
         s_dkTpl[k][i].used  = false;
         s_dkTpl[k][i].name  = "";
         s_dkTpl[k][i].packA = 0.0;
         s_dkTpl[k][i].packB = 0.0;
         s_dkTpl[k][i].lvl   = "";
      }
   if(FileIsExist(DRAW_TPL_FILE))
   {
      DrawTplLoad();
      if(FileIsExist(DRAW_TPL_LEGACY)) FileDelete(DRAW_TPL_LEGACY);
      return;
   }
   DrawTplSeed();
   if(FileIsExist(DRAW_TPL_LEGACY)) DrawTplMigrate();
   DrawTplSave();
   if(FileIsExist(DRAW_TPL_LEGACY)) FileDelete(DRAW_TPL_LEGACY);
}

//--- P-DRAW-130 (2026-10-13): `remember=false` is a HOVER PREVIEW — the drawing
//--- still wears the value live (P-UI-131k's requirement), but the kind's memory
//--- learns nothing and no disk write is paid for a colour the hand only passed
//--- over. Every other caller is a real pick and keeps the default.
bool DrawSlotWrite(const string name, const int slot, const double v, const bool remember=true)
{
   if(name == "" || ObjectFind(0, name) < 0) return false;
   EDrawKind k = DrawKindOf(name);
   if(k == DK_NONE) return false;
   switch(slot)
   {
      case DRAW_SLOT_COLOR:
      {
         color c = (color)(int)MathRound(v);
         // P-HR-04: plain ink on the ray — no `[CL` desc (it would paint text on
         // the line) and no kind learning (a ray must not dye the next trendline).
         if(DrawIsHRay(name)) { ObjectSetInteger(0, name, OBJPROP_COLOR, c); break; }
         // P-UI-136: a path segment is one drawing of N objects — the plain ink
         // (no `[CL` desc: it would paint text on the line) on EVERY sibling, at the
         // path's OWN opacity (P-UI-137: the pick and the TR step share one writer, so
         // choosing a colour can never drop the fade the user just set).
         if(DrawIsPathSeg(name)) { string pid = ""; PathIdOfName(name, pid); PathInkApply(pid, c, PathInkOpacityGet(pid)); break; }
         color rc = DrawSlotColorStore(name, c);   // P-DRAW-48: pure on the desc, blend on the chart
         //--- P-DRAW-BODY: for a LEVEL kind this cell is the LEVELS' — the body has its own
         //--- seat (`DRAW_SLOT_BODYCOLOR`) and the two may never write each other's half.
         if(!DrawKindHasLevels(k)) ObjectSetInteger(0, name, OBJPROP_COLOR, rc);
         //--- P-DRAW-128: the writer that owns the value owns its witness — the blend
         //--- it just put on the chart is noted, so the OBJECT_CHANGE our own write
         //--- fires reads back to the native learner as "nothing moved" (a level kind
         //--- owns no colour seat on the object — the witness refuses it, look above).
         if(!DrawKindHasLevels(k)) DrawInkMemoNote(name, rc);
         //--- P-DRAW-64: an interior the user has NOT coloured follows the border,
         //--- so a border write re-inks it too — the child, or the levels.
         color ip;
         if(DrawKindHasLevels(k))
            DrawLevelsSetColor(name, DrawSlotFillPure(name, ip) ? DrawSlotRenderFillColor(name, ip) : rc);
         if(DrawKindHasFillBody(k)) FillChildSync(name);
         //--- P-DRAW-74c: and a line's rows wear the same ink - one write reaches the stack.
         PenStackSync(name, false);
         //--- P-DRAW-130: a preview writes the drawing and learns nothing; only the
         //--- hand's own pick teaches the kind what it last wore.
         if(remember)
         {
            s_dkColor[k] = c;
            //--- P-DRAW-INK (2026-10-04): the ONE ink every kind shares is noted HERE,
            //--- where every pick arrives. The kind's own memory records what IT wore; this
            //--- records the last colour the HAND chose anywhere, so a kind with no colour
            //--- of its own can wear it at birth.
            if((int)c >= 0) s_dkAnyClr = c;
         }
         break;
      }
      case DRAW_SLOT_WIDTH:
      {
         int w = (int)MathRound(v);
         if(w < DRAW_WIDTH_MIN) w = DRAW_WIDTH_MIN;
         if(w > DRAW_WIDTH_MAX) w = DRAW_WIDTH_MAX;
         //--- P-DRAW-74c (2026-10-17): the pick IS the logical width; the stack is only
         //--- the visible half. A pick of 1 is the one write the stack cannot express on
         //--- its own (children outrank a width-1 read - the fibo's accepted ambiguity),
         //--- so it is resolved HERE, where the user's intent is known: the rows die
         //--- first and the sync then keeps the plain 1 px.
         bool penKind = PenStackServes(name);
         // P-UI-136: the path is one drawing — the pen lands on every segment.
         if(DrawIsPathSeg(name)) PathFamilySet(name, OBJPROP_WIDTH, w);
         else if(!DrawKindHasLevels(k)) ObjectSetInteger(0, name, OBJPROP_WIDTH, w);
         //--- P-DRAW-BODY: the LEVELS' width for a level kind; the body keeps its own
         //--- (`DRAW_SLOT_BODYWIDTH`), so neither choice restyles the other.
         if(DrawKindHasLevels(k)) DrawLevelsSetWidth(name, w);
         if(!DrawIsHRay(name) && !DrawIsPathSeg(name)) s_dkWidth[k] = w;   // P-HR-04/P-UI-136: rays and paths learn nothing
         if(penKind)
         {
            if(w <= DRAW_WIDTH_MIN) PenStackStraysDrop(name);
            PenStackSync(name, false);
         }
         //--- P-DRAW-74: a thick pen paints solid, so the pair resolves here - the
         //--- one owner, asked on the way every chip, preset and undo already takes.
         DrawStylePairCoerce(name);
         break;
      }
      case DRAW_SLOT_STYLE:
      {
         int st = (int)MathRound(v);
         //--- P-DRAW-74b (2026-10-03) — THE FIBO'S LOOKS LIVE ABOVE THE NATIVE FIVE.
         //--- MT4's five styles end where chic begins: STYLE 5/6/7 means the pen's own
         //--- looks (FIBPEN_LOOK_NEON/CAPS/WASH), each a `[LKn]` tag beside the NATIVE
         //--- pair the terminal holds and painted by the pen's own followers. This is the
         //--- ONE writer that translates the pick: the tag first, then the native style
         //--- the look really draws with.
         int lk = 0;
         if(st > (int)STYLE_DASHDOTDOT && FibPenServesName(name))
         {
            lk = DrawLookFromSlot(st);   // P-UNIFY-4: 5 -> 1, 6 -> 2, 7 -> 3; 8 and above -> 0
            if(lk > 0) FibPenLookSet(name, lk);
         }
         if(st < 0) st = 0;
         if(st > (int)STYLE_DASHDOTDOT) st = (int)STYLE_DASHDOTDOT;
         //--- the look's native half is what the terminal can actually draw; and a
         //--- NATIVE pick (0..4) means the look is off — one truth, never two.
         if(lk > 0) st = FibPenLookNative(lk);
         else if(DrawKindHasLevels(k)) FibPenLookDrop(name);
         if(st != (int)STYLE_SOLID)
         {
            //--- P-DRAW-74c (2026-10-17) — AND THE FOLD IS THE FIBO'S LAW TOO: on a pen
            //--- kind the OBJECT's own width is the LOGICAL memory until the first
            //--- demotion, so folding it here - one write before the style lands and two
            //--- before the sync reads - erases the thickness the pick means to apply.
            //--- The sync below writes the visible 1 itself.
            bool penKind = FibPenServesName(name) || PenStackServes(name);
            if(!penKind && (int)ObjectGetInteger(0, name, OBJPROP_WIDTH) != DRAW_WIDTH_MIN)
               ObjectSetInteger(0, name, OBJPROP_WIDTH, DRAW_WIDTH_MIN);
            //--- P-DRAW-74b (2026-10-04) — ON A PEN KIND THE WIDTH LIVES IN THE STACK.
            //--- While no stack exists, the LEVEL widths ARE the logical width
            //--- (`FibPenLogicalWidth` reads them), and `FibPenSync` demotes them to the
            //--- visible 1 itself — AFTER it has read the logical one. Folding them here,
            //--- before the style is even set, erased that memory one write early: the
            //--- pen then read 1, built nothing and the level came out a plain 1 px dash,
            //--- i.e. «استایل‌ها روی ضخامت‌های بزرگ اعمال نمی‌شد». Only the OBJECT's own
            //--- width is folded for these kinds; their levels are the pen's business.
            if(!penKind) DrawLevelsSetWidth(name, DRAW_WIDTH_MIN);
            //--- ...and the kind's remembered WIDTH is the LOGICAL one on a pen kind, so
            //--- a dash pick must not fold it to 1 either (the next fibo would be born
            //--- thin, losing the thickness the user chose). Other kinds keep the law:
            //--- a dash is a one-pixel pen.
            if(!DrawIsHRay(name) && !DrawIsPathSeg(name) && !penKind) s_dkWidth[k] = DRAW_WIDTH_MIN;
         }
         // P-UI-136: the dash lands on every segment of the path.
         if(DrawIsPathSeg(name)) PathFamilySet(name, OBJPROP_STYLE, st);
         //--- P-DRAW-BODY: the LEVELS' style for a level kind — the body answers to its own
         //--- seat, and the pair law (a dash is a one-pixel pen) is asked there, not here.
         else if(!DrawKindHasLevels(k)) ObjectSetInteger(0, name, OBJPROP_STYLE, st);
         if(DrawKindHasLevels(k)) DrawLevelsSetStyle(name, st);
         //--- P-UNIFY-4b: the KIND's memory keeps the LOOK's slot, not its native
         //--- half - otherwise the next drawing of this kind is born with the right
         //--- dash and no `[LKn]` tag (Caps/Wash silently gone).
         int memSt = (lk > 0 ? DrawLookToSlot(lk) : st);
         if(!DrawIsHRay(name) && !DrawIsPathSeg(name)) s_dkStyle[k] = memSt;   // P-HR-04/P-UI-136
         //--- P-DRAW-74c: a line's rows wear the master's pattern - demote the undrawable
         //--- pair and re-dress the stack in ONE pass (a solid pick above the rows already
         //--- dissolved them back into the master's width). Refuses non-pen kinds itself.
         PenStackSync(name, false);
         DrawStylePairCoerce(name);                  // P-DRAW-74: a dash is a 1 px pen
         break;
      }
      //--- P-DRAW-BODY — THE BODY'S OWN THREE SEATS. They write `OBJPROP_COLOR/WIDTH/
      //--- STYLE` and stop there: no `DrawLevelsSet*` (the levels are another picture),
      //--- no `[LK…]` look tag (the looks are the levels' — `FibPenSync` reads the LEVEL
      //--- style), and no kind memory (the levels' memory must not learn a body choice).
      //--- What MT4 cannot draw is still MT4's law: a body thicker than one pixel paints
      //--- solid, so the body's pair is coerced HERE, where the body is written.
      case DRAW_SLOT_BODYCOLOR:
      {
         color bc = (color)(int)MathRound(v);
         if((int)bc < 0) return false;              // no colour, no write (P-DRAW-48)
         ObjectSetInteger(0, name, OBJPROP_COLOR, bc);
         break;
      }
      case DRAW_SLOT_BODYWIDTH:
      {
         int bw = (int)MathRound(v);
         if(bw < DRAW_WIDTH_MIN) bw = DRAW_WIDTH_MIN;
         if(bw > DRAW_WIDTH_MAX) bw = DRAW_WIDTH_MAX;
         ObjectSetInteger(0, name, OBJPROP_WIDTH, bw);
         DrawStylePairCoerce(name);
         break;
      }
      case DRAW_SLOT_BODYSTYLE:
      {
         int bs = (int)MathRound(v);
         if(bs < 0) bs = 0;
         if(bs > (int)STYLE_DASHDOTDOT) bs = (int)STYLE_DASHDOTDOT;
         ObjectSetInteger(0, name, OBJPROP_STYLE, bs);
         if(bs != (int)STYLE_SOLID)
            ObjectSetInteger(0, name, OBJPROP_WIDTH, DRAW_WIDTH_MIN);
         DrawStylePairCoerce(name);
         break;
      }
      case DRAW_SLOT_FILL:
      {
         bool f = (v > 0.5);
         s_dkFill[k] = f;
         if(DrawTypeHasFillChild(DrawObjectType(name)))
         {
            //--- P-DRAW-64: the interior is the CHILD — on makes it (and takes the
            //--- master's own MT4 fill away, so two colours can coexist), off drops it.
            if(f) FillChildEnsure(name);
            else
            {
               //--- ...and OFF means off even for a drawing a build before the split
               //--- left with its OWN fill on: the child may not exist yet.
               if((int)ObjectGetInteger(0, name, OBJPROP_FILL) != 0)
                  ObjectSetInteger(0, name, OBJPROP_FILL, false);
               FillChildDrop(name);
            }
            //--- P-PEN-ALL: THE INTERIOR IS A LATER PIXEL THAN THE OUTLINE'S ROWS. MT4
            //--- paints in CREATION order (P-LOG-10), so a fill child that appeared after
            //--- a shape's pen rows covers the half of the thickness that lies inside the
            //--- outline. The sync re-states the pen in this same frame; it sees the
            //--- transition in its own net and rebuilds the rows above the interior. One
            //--- transition, then silence - a still frame pays two memo reads.
            PenStackSync(name, false);
            break;
         }
         ObjectSetInteger(0, name, OBJPROP_FILL, f);
         break;
      }
      case DRAW_SLOT_FILLCLR:
      {
         // P-UI-137: A PATH HAS NO INTERIOR. The FILL role's whole vocabulary is the
         // `[FL…]` desc tag, and on a segment that tag is not metadata — MT4 PAINTS
         // it as text along the line (the same reason the colour slot takes the plain
         // ink above). So the write is refused here, not silently turned into a
         // caption on the chart: a click on the popup's `Fill` chip changes nothing
         // and draws nothing, which is the truth for a polyline.
         if(DrawIsPathSeg(name)) break;
         //--- P-DRAW-64: the interior's own colour (`[FL…]`). It is recorded even
         //--- while the interior is OFF, so choosing a colour and switching the fill
         //--- on are two acts in either order.
         color ic = (color)(int)MathRound(v);
         if((int)ic < 0) return false;   // no colour, no write (P-DRAW-48's lesson)
         string dd = ObjectGetString(0, name, OBJPROP_TEXT);
         dd = DrawDescTag(dd, "[FL", DrawDescColorHex(ic));
         if(dd != ObjectGetString(0, name, OBJPROP_TEXT))
            ObjectSetString(0, name, OBJPROP_TEXT, dd);
         if(remember) s_dkFillClr[k] = ic;   // P-DRAW-130: a preview's fill is not a remembered fill
         if(DrawKindHasFillBody(k)) FillChildSync(name);
         PenStackSync(name, false);
         if(DrawKindHasLevels(k)) DrawLevelsSetColor(name, DrawSlotRenderFillColor(name, ic));
         break;
      }
      case DRAW_SLOT_RAY:
      {
         int r = (int)MathRound(v);
         if(r < 0) r = 0;
         if(r > 3) r = 3;
         if(DrawIsHRay(name)) r = 1;   // P-HR-04: a ray stays a right-ray — the law, not a choice
         // P-UI-136: a path's ends are VERTICES, so the ray cell is a no-op on it —
         // a stretched segment would no longer meet the handle that owns its end.
         if(DrawIsPathSeg(name)) { PathFamilySet(name, OBJPROP_RAY_RIGHT, false); PathFamilySet(name, OBJPROP_RAY_LEFT, false); break; }
         ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, (r & 1) != 0);
         ObjectSetInteger(0, name, OBJPROP_RAY_LEFT,  (r & 2) != 0);
         if(!DrawIsHRay(name)) s_dkRay[k] = r;   // P-HR-04: rays learn nothing
         break;
      }
      case DRAW_SLOT_LOCK:
      {
         // P-HR-04: the ray is born unselectable and stays that way — the dot
         // carry is its lock's replacement, so the cell is a no-op on rays.
         if(DrawIsHRay(name)) break;
         // P-UI-138: A PATH'S LOCK IS ITS OWN FLAG. `OBJPROP_SELECTABLE` would hand
         // MT4 an anchor on ONE segment while the handles carry the whole drawing —
         // two owners for one drawing, and a locked path that still tears in half.
         // So the cell asks the path, and the path's press branch answers it.
         if(DrawIsPathSeg(name))
         {
            string pid = "";
            if(PathIdOfName(name, pid)) PathLockSet(pid, (v > 0.5));
            break;
         }
         bool locked = (v > 0.5);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, !locked);
         if(locked) ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
         // the lock is NOT a style: it must not travel to the next drawing, or
         // every new object would be born unmovable. Learned nowhere on purpose.
         break;
      }
      //--- P-DRAW-09a: the three appended slots. FONT and GLYPH are LOOKS (learned
      //--- like colour and width); BACK is a placement-like arrangement and is
      //--- learned too — «my zones go behind the candles» is a statement about the
      //--- user's zones, and one tap puts a stray one back in front.
      case DRAW_SLOT_FONT:
      {
         int fs = (int)MathRound(v);
         if(fs < DRAW_FONT_MIN) fs = DRAW_FONT_MIN;
         if(fs > DRAW_FONT_MAX) fs = DRAW_FONT_MAX;
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fs);
         s_dkFont[k] = fs;
         break;
      }
      case DRAW_SLOT_GLYPH:
      {
         int g = (int)MathRound(v);
         if(g < DRAW_GLYPH_MIN) g = DRAW_GLYPH_MIN;
         if(g > DRAW_GLYPH_MAX) g = DRAW_GLYPH_MAX;
         ObjectSetInteger(0, name, OBJPROP_ARROWCODE, g);
         s_dkGlyph[k] = g;
         break;
      }
      case DRAW_SLOT_BACK:
      {
         bool b = (v > 0.5);
         ObjectSetInteger(0, name, OBJPROP_BACK, b);
         //--- P-DRAW-64 addendum 7: the interior is in the box's own LAYER, so the switch
         //--- that moves the box behind the bars moves the interior with it — one honest
         //--- control for the whole drawing, and the frame that separates the two.
         if(DrawKindHasFillBody(k)) FillChildSync(name);
         s_dkBack[k] = b;
         break;
      }
      //--- P-DRAW-64a: NEITHER OF THE TWO IS A LOOK. The 50 % LEVEL and whether the far
      //--- edge travels are the drawing's own arrangement, so they are learned NOWHERE
      //--- (`s_dkValid` may not claim the kind has a style memory because of one tap, or
      //--- a fresh drawing would be born wearing a look the user never set) and they do
      //--- not ride the undo (P-DRAW-21's own rule: an extend moves TIME, not the look).
      //--- The 50 % is the box's own MID PRICE, drawn by `BoxMidSync` as the `[BX50]`
      //--- mark: a level like the fib's, and NOT a length — the third cut, the user's
      //--- own correction «خود باکس رو از وسط طول نصف میکنه که نباید باشه … فقط 50 درصد
      //--- مثل فیبو». So this writes the MARK and nothing else: no anchor of the drawing
      //--- moves, the box keeps the length the hand gave it, and the interior is not a
      //--- party to it («۵۰ درصد باکس فقط میخوام، fill بهکارم نمیاد»).
      case DRAW_SLOT_BOXHALF:
      {
         //--- P-UI-139: on a PATH the same cell is its 50 % MARKERS — one small
         //--- circle at each leg's middle, painted by the path's own owner. The
         //--- rectangle's own answer (the mid PRICE line) is untouched below.
         if(DrawIsPathSeg(name))
         {
            string pid = "";
            if(PathIdOfName(name, pid)) PathMidSet(pid, (v > 0.5));
            break;
         }
         if(DrawObjectType(name) != OBJ_RECTANGLE) return false;
         bool mid = false; int ext = BOXEXT_OFF, exn = 0;
         BoxMarkRead(name, mid, ext, exn);
         bool on = (v > 0.5);
         if(on == mid) return true;
         //--- the mid line and the travelling edge are two marks on one group and one
         //--- group has one writer — and they COEXIST now (the level is a horizontal line,
         //--- the extend is a time), so switching the level on PRESERVES the edge's mode
         //--- instead of killing it: a box whose edge travels and wears its level does both.
         BoxMarkWrite(name, on, ext, exn);
         return true;
      }
      case DRAW_SLOT_EXTEND:
      {
         if(DrawObjectType(name) != OBJ_RECTANGLE) return false;
         bool mid = false; int ext = BOXEXT_OFF, exn = 0;
         BoxMarkRead(name, mid, ext, exn);
         //--- the far edge travels with the newest bar. It and the 50 % LEVEL no longer
         //--- fight over one edge: the level is a horizontal line at the box's mid
         //--- PRICE, so the two can be on together (the line simply rides the edge).
         BoxMarkWrite(name, mid, (v > 0.5) ? BOXEXT_END : BOXEXT_OFF, 0);
         return true;
      }
      default: return false;
   }
   //--- P-DRAW-130: a preview marks nothing and pays no disk write; the hand's own
   //--- pick does both, exactly as it did before the preview existed.
   if(remember)
   {
      s_dkValid[k] = true;
      //--- P-DRAW-09c (2026-10-04): the ONE slot writer persists what it just learned —
      //--- «همیشه آخرین تغییرات روی ابجکت پیش‌فرض بشه» is true only if the last change
      //--- survives the session. One write per user act; a still frame never reaches here.
      //--- P-DRAW-132: EXCEPT while an apply holds the pen — a template apply writes the
      //--- whole look (5..9 slots) and pays the file write ONCE, after its last slot.
      if(s_dkTplHold <= 0) DrawTplSave();
   }
   return true;
}

//--- THE STYLE THE USER LAST USED FOR THIS KIND, WRITTEN ONTO A FRESH OBJECT.
//--- Called the moment the terminal reports the creation (see the entry's
//--- OBJECT_CREATE branch): a drawing the user made is adjusted to their own
//--- last look before they can even see it in the old style.
// ══════════════════════════════════════════════════════════════════════════
// P-DRAW-74 — THE PAIR IS ONE PICTURE. MT4 paints a line wider than 1 px SOLID:
// the terminal's own reference puts it plainly - a `STYLE_*` line style is used
// "only if the line width is equal to 0 or 1" (book.mql4.com, *Styles of drawing
// indicator lines*). So (3, Dash) is not a look, it is a state no terminal can
// draw, and every owner of a look has to refuse it rather than store it.
// ONE owner, two rules, and it is asked of an object NOT only when a chip fires
// but on the strip's own open, because the terminal's properties dialog writes
// the pair directly and never passes here.
//   width  > 1  =>  STYLE_SOLID   (a thick pen has no dash pattern)
//   style  != SOLID  =>  width 1   (a dash is a one-pixel pen)
// Both writes are guarded (one read, zero writes on a legal pair) and the KIND
// memory and the level family move with them, so the next drawing of the kind
// is born wearing what the last one really showed.
// ══════════════════════════════════════════════════════════════════════════
bool DrawStylePairCoerce(const string name)
{
   if(name == "" || ObjectFind(0, name) < 0) return false;
   EDrawKind k = DrawKindOf(name);
   if(k == DK_NONE) return false;
   //--- P-DRAW-74b (2026-10-04) — A PEN KIND IS NOT THIS FUNCTION'S OBJECT. Its drawn
   //--- pair lives on the LEVELS (`OBJPROP_LEVELWIDTH`/`LEVELSTYLE`), and the object's
   //--- own pair is only a MEMORY. Reading that memory here meant a thick styled fibo
   //--- was forced back to STYLE_SOLID — every level with it — the moment the strip
   //--- opened or the chart repainted (`DrawStrip_Paint` calls this on every open), so
   //--- the stack died and the style vanished: the same report as (A), one seat over.
   //--- `FibPenSync` owns the visible pair for these kinds — a styled level is drawn at
   //--- width 1 with the thickness carried by the stack — so the pair is legal by
   //--- construction and this coercion has nothing true to say about it.
   if(FibPenServesName(name)) return false;
   //--- P-DRAW-74c (2026-10-17) — A LINE PEN KIND IS NOT THIS FUNCTION'S OBJECT EITHER,
   //--- the same law one family over. Its LOGICAL width lives on the master (before the
   //--- first demotion) or in the rows (after it), and this function can only see - or
   //--- produce - the demoted 1. The fold it would write erases the memory one write
   //--- before `PenStackSync` reads it: the dash would come out a plain 1 px and the
   //--- thickness would vanish - P-DRAW-74b's defect, one family over. The sync owns
   //--- the visible pair for these kinds; the pair is legal by construction.
   if(PenStackServes(name)) return false;
   int w = (int)ObjectGetInteger(0, name, OBJPROP_WIDTH);
   int st = (int)ObjectGetInteger(0, name, OBJPROP_STYLE);
   if(w < DRAW_WIDTH_MIN) w = DRAW_WIDTH_MIN;
   if(w > DRAW_WIDTH_MAX) w = DRAW_WIDTH_MAX;
   if(st < 0) st = 0;
   if(st > (int)STYLE_DASHDOTDOT) st = (int)STYLE_DASHDOTDOT;
   bool changed = false;
   if(w > DRAW_WIDTH_MIN)
   {
      if(st != (int)STYLE_SOLID)
      {
         st = (int)STYLE_SOLID;
         ObjectSetInteger(0, name, OBJPROP_STYLE, st);
         //--- P-DRAW-BODY: this is the BODY's pair law now. It must not reach for the
         //--- levels: a styled level the terminal cannot draw is exactly what the pen
         //--- exists to draw, and coercing it back to solid IS the reported defect.
         changed = true;
      }
   }
   else if(st != (int)STYLE_SOLID)
   {
      w = DRAW_WIDTH_MIN;
      ObjectSetInteger(0, name, OBJPROP_WIDTH, w);
      changed = true;
   }
   if(!DrawIsHRay(name) && !DrawIsPathSeg(name))
   {
      if(s_dkWidth[k] != w) { s_dkWidth[k] = w; changed = changed || true; }
      if(s_dkStyle[k] != st) { s_dkStyle[k] = st; changed = changed || true; }
   }
   return changed;
}

bool DrawStyleApplyOnCreate(const string name)
{
   if(name == "" || DrawIsIndicatorObject(name)) return false;
   EDrawKind k = DrawKindOf(name);
   if(k == DK_NONE) return false;   // a stranger: the terminal's own look, untouched
   if(ObjectFind(0, name) < 0) return false;
   //--- P-DRAW-INK (2026-10-04) — THE INK THE KIND HAS NO MEMORY OF. Reported on a
   //--- chart whose fibos had been given a width and a look but never a colour:
   //--- «چرا رنگش پیش‌فرض که میکشم سفید هستش؟ آخرین تغییرات آبی بود». The kind's own
   //--- colour is asked FIRST (P-DRAW-48/75); only a kind that has none takes the last
   //--- ink the hand picked ANYWHERE — so a fresh drawing wears the blue the last pick
   //--- painted, never the terminal's factory white.
   color want = s_dkColor[k];
    if((int)want < 0) want = s_dkAnyClr;
    if((DrawKindCaps(k) & DRAW_CAP_COLOR) != 0 && (int)want >= 0)
   {
      ObjectSetInteger(0, name, OBJPROP_COLOR, want);
      if(DrawKindHasLevels(k)) DrawLevelsSetColor(name, want);
   }
   //--- P-DRAW-INK: a kind the user has NEVER styled has exactly one thing of its own
   //--- to wear — the ink above. Its width, style, fill and ray were never chosen, so
   //--- they are left exactly as the terminal would have drawn them (P-DRAW-75).
   if(!s_dkValid[k]) return true;
   if((DrawKindCaps(k) & DRAW_CAP_WIDTH) != 0)
   {
      ObjectSetInteger(0, name, OBJPROP_WIDTH, s_dkWidth[k]);
      if(DrawKindHasLevels(k)) DrawLevelsSetWidth(name, s_dkWidth[k]);
   }
   if((DrawKindCaps(k) & DRAW_CAP_STYLE) != 0)
   {
      int memSt = s_dkStyle[k];
      int mlk = (memSt > (int)STYLE_DASHDOTDOT ? DrawLookFromSlot(memSt) : 0);
      int native = (mlk > 0 ? FibPenLookNative(mlk) : memSt);
      if(native < 0 || native > (int)STYLE_DASHDOTDOT) native = (int)STYLE_SOLID;
      ObjectSetInteger(0, name, OBJPROP_STYLE, native);
      if(DrawKindHasLevels(k)) DrawLevelsSetStyle(name, native);
      if(mlk > 0 && FibPenServesName(name)) { FibPenLookSet(name, mlk); FibPenSync(name, false); }
      else if(DrawKindHasLevels(k)) FibPenLookDrop(name);
   }
   DrawStylePairCoerce(name);   // P-DRAW-74: the remembered pair is coerced, not trusted
   //--- P-DRAW-74c: a fresh line born with a remembered THICK + DASH pair is stacked
   //--- here, at birth - otherwise it would flash a solid thick line until the next
   //--- heal pass. The sync reads the remembered width off the master and demotes it.
   PenStackSync(name, false);
   //--- P-DRAW-64: the interior first (the look it was born with), then the fill
   //--- that shows it — the child is made with the colour already on the drawing.
   if((DrawKindCaps(k) & DRAW_CAP_FILLCLR) != 0 && (int)s_dkFillClr[k] >= 0)
      DrawSlotWrite(name, DRAW_SLOT_FILLCLR, (double)(int)s_dkFillClr[k]);
   if((DrawKindCaps(k) & DRAW_CAP_FILL) != 0)
      DrawSlotWrite(name, DRAW_SLOT_FILL, s_dkFill[k] ? 1.0 : 0.0);   // P-DRAW-64: routes by TYPE
   if((DrawKindCaps(k) & DRAW_CAP_RAY) != 0)
   {
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, (s_dkRay[k] & 1) != 0);
      ObjectSetInteger(0, name, OBJPROP_RAY_LEFT,  (s_dkRay[k] & 2) != 0);
   }
   //--- P-DRAW-09a: and the three appended slots, on the same "last change saved"
   //--- rule — a fresh caption keeps the size the user last used for one.
   if((DrawKindCaps(k) & DRAW_CAP_FONT) != 0)
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, s_dkFont[k]);
   if((DrawKindCaps(k) & DRAW_CAP_GLYPH) != 0)
      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, s_dkGlyph[k]);
   if((DrawKindCaps(k) & DRAW_CAP_BACK) != 0)
      ObjectSetInteger(0, name, OBJPROP_BACK, s_dkBack[k]);
   return true;
}

//--- P-DRAW-09c (2026-10-04) — THE LOOK OUTLIVES THE SESSION. «همیشه آخرین تغییرات
//--- روی ابجکت پیش‌فرض بشه و هر سری نیاز نباشه تنظیم بکن» — the kind memory already
//--- made the last look the default of the NEXT drawing of that kind; what it did not
//--- do was survive an attach, so the first fibo of every session was born factory
//--- fresh. The nine values pack into TWO exact doubles and ride the presets' own file
//--- in this reserved slot, which is OUTSIDE every preset band on purpose (so the
//--- band's own guard can never eat the row).
//--- (DRAW_LASTLOOK_SLOT is #defined with the other template row constants above.)
//--- P-DRAW-INK (2026-10-04) — THE ONE INK EVERY KIND SHARES. The kind's own colour
//--- answers «what did THIS kind last wear»; this answers the question the hand's own
//--- report asks («چرا رنگش پیش‌فرض که میکشم سفید هستش؟ آخرین تغییرات آبی بود»): which
//--- colour the LAST pick painted, whichever kind it painted. A kind that has no
//--- colour of its own takes it at birth (a first-ever fibo wears the blue the last
//--- trendline was). Its own reserved row, one below the look's.
//--- (DRAW_LASTINK_SLOT is #defined with the other template row constants above.)


// ══════════════════════════════════════════════════════════════════════════
// P-DRAW-04 — THE PERFORMANCE CONTRACT OF THIS MODULE. «کاربر اندیکاتور کند قبول
// نداره» — so the rules are written down where they are obeyed, not discovered
// later in a profile.
//
// WHAT COSTS, AND WHAT DOES NOT.
//   * The CLASSIFIER, the CAPABILITY TABLE and the STYLE MEMORY are array
//     lookups and switch tables: a handful of instructions, no terminal call.
//   * The HIT TEST is the only expensive thing in the file: it walks the chart's
//     object list (one `ObjectName` + one `OBJPROP_TYPE` per object) and projects
//     anchors (`ChartTimePriceToXY`) only for the objects that pass the type and
//     the prefix filter. On a chart with 1500 objects that is 1500 string
//     compares — cheap, but not free, and NOT something a mouse-move may do.
//   * Therefore the hit test is PRESS-EDGE ONLY, and this module enforces it
//     itself instead of trusting its callers: `DrawObjectAtCached` is the only
//     entry point a gesture may use, it memoises its answer for
//     `DRAW_HIT_CACHE_MS`, and a second caller inside that window pays ONE tick
//     read instead of a walk.
//   * The steady state — no press, no hold, nothing held — costs NOTHING: no
//     call into this module happens at all until a gesture asks for one, and
//     every entry point starts with a bool read (is there anything to do?).
//
// THE MOUSE STREAM IS NEVER WALKED. `DrawSlotRead/Write` touch ONE named object
// (3-4 terminal calls); `DrawPresetApply` touches one object; the create hook
// runs once per object the user draws. A per-move repaint of the strip is the
// renderer's own business and re-reads the slots of the ONE held object — never
// the chart.
// ══════════════════════════════════════════════════════════════════════════
#define DRAW_HIT_CACHE_MS 400     // one walk per press, whatever asks twice

static string s_dkAtName = "";
static int    s_dkAtX = -1;
static int    s_dkAtY = -1;
static uint   s_dkAtMs = 0;

// THE entry point for every gesture: the hit test with its own press-edge memo.
// A move that asks again for the SAME pixel inside the window pays a tick read;
// a move that asks for a DIFFERENT pixel (the hand moved) pays one walk — which
// is the honest answer, because the object under the cursor really changed.
string DrawObjectAtCached(const int px, const int py)
{
   uint now = GetTickCount();
   if(s_dkAtX == px && s_dkAtY == py && (now - s_dkAtMs) < DRAW_HIT_CACHE_MS)
      return s_dkAtName;
   s_dkAtX = px; s_dkAtY = py; s_dkAtMs = now;
   s_dkAtName = DrawObjectAt(px, py);
   return s_dkAtName;
}

//--- the memo is a GESTURE's, never a session's: the next press must not inherit
//--- the previous answer (the chart may have changed under it).
void DrawHitCacheClear()
{
   s_dkAtName = "";
   s_dkAtX = -1; s_dkAtY = -1;
   s_dkAtMs = 0;
}

//--- P-DRAGF3d (2026-10-17) — THE PEN'S THIRD ANSWER: THE SELECTED LEVEL FAMILY'S
//--- FULL SHAPE, THE DIAGONAL INCLUDED. MEASURED (the 20:51 frame,
//--- biotak_diag_EURUSD_134362571361933137: FIBPENPRE view=on 25 against FIBPENARM 22 —
//--- 4 of the 25 real drags armed only at the release door, the user's own
//--- «بعضی وقتا که سریع»): a fast flick grabs the fibo by a line the press pick never
//--- measures. The press naming spans the LEVEL LINES (DrawHitLevels, t1..t2 at each
//--- level's own price) and the anchor handles (DrawHitSelectedHandle), but the
//--- anchor-to-anchor DIAGONAL — with the object's own RAY_LEFT/RIGHT, the part of a
//--- fibo a hand is on most — is tested by neither, so the press named nothing, the
//--- P-DRAGF3c trip never fired, and the stack stood frozen until the release door.
//--- The terminal's own pick DOES grab there, and a grab is a selection: this asks
//--- THAT, fenced by the cursor still resting on the full grabbable shape. The fence
//--- is exact because a pan holds a selected fibo at the cursor's own paper offset —
//--- cursor on the shape at the first traveled move is a terminal DRAG, cursor off it
//--- can only be a pan. One walk per press (the trip's own memo spends it, miss or
//--- hit); the cost note above stands — this is press-edge work merely DECIDED at the
//--- first traveled move.
bool DrawFiboFullHit(const string name, const int px, const int py)
{
   if(DrawHitSelectedHandle(name, px, py)) return true;   // the visible anchor controls
   int x1 = 0, y1 = 0, x2 = 0, y2 = 0;
   if(!DrawAnchorXY(name, 0, x1, y1) || !DrawAnchorXY(name, 1, x2, y2)) return false;
   bool oA = ((int)ObjectGetInteger(0, name, OBJPROP_RAY_LEFT) != 0);
   bool oB = ((int)ObjectGetInteger(0, name, OBJPROP_RAY_RIGHT) != 0);
   if(DrawSegDist(px, py, x1, y1, x2, y2, oA, oB) <= (double)DRAW_HIT_PX) return true;   // the diagonal
   // the level lines, measured the way the terminal DRAWS them - P-LOOK-ANCHOR's law on
   // a plain fibo, and P-UNIFY-3's per-kind geometry on the fan, the channel and the
   // expansion (two ends, the kind's own) - extended by the same ray pair, so a fibo
   // that runs edge to edge is grabbed along its whole run.
   int n = DrawLevelCount(name);
   if(n <= 0) return false;
   datetime t1 = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 0);
   datetime t2 = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 1);
   double   p1 = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);
   double   p2 = ObjectGetDouble(0, name, OBJPROP_PRICE, 1);
   if(t1 <= 0 || !(p1 > 0.0) || !(p2 > 0.0)) return false;
   EDrawKind k = DrawKindOf(name);
   bool three = (k == DK_FIBOCHAN || k == DK_EXPANSION);
   datetime t3 = three ? (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 2) : 0;
   double   p3 = three ? ObjectGetDouble(0, name, OBJPROP_PRICE, 2) : 0.0;
   if(three && (t3 <= 0 || !(p3 > 0.0))) return false;
   int xa = 0, ya = 0, xb = 0, yb = 0;
   for(int k2 = 0; k2 < n; k2++)
   {
      double v = DrawLevelValue(name, k2);
      if(!MathIsValidNumber(v)) continue;
      double la = DrawLevelPriceAt(k, v, t1, p1, t2, p2, t3, p3, t1);
      double lb = DrawLevelPriceAt(k, v, t1, p1, t2, p2, t3, p3, t2);
      if(!(la > 0.0) || !(lb > 0.0)) continue;
      if(!ChartTimePriceToXY(0, 0, t1, la, xa, ya)) continue;
      if(!ChartTimePriceToXY(0, 0, t2, lb, xb, yb)) continue;
      if(DrawSegDist(px, py, xa, ya, xb, yb, oA, oB) <= (double)DRAW_HIT_PX) return true;
   }
   return false;
}
string DrawSelectedFiboAt(const int px, const int py)
{
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string nm = ObjectName(0, i, -1, -1);
      if(nm == "" || DrawIsIndicatorObject(nm)) continue;
      if(!FibPenServesName(nm)) continue;   // P-UNIFY-3: the pen's own four - no pitchfork, no arc
      if(!(bool)ObjectGetInteger(0, nm, OBJPROP_SELECTED)) continue;
      if(DrawFiboFullHit(nm, px, py)) return nm;
   }
   return "";
}

//--- P-DRAW-09c (2026-10-04) — THE LAST LOOK, PACKED EXACTLY. Two doubles carry the
//--- nine values of one kind's memory: word A holds the border's pair (colour 24 bits,
//--- width 3, style 3, fill 1, ray 2) plus the three appended looks (font 7, glyph 8,
//--- back 1) and a PRESENCE BIT at 33; word B holds the interior's colour (24 bits)
//--- and its own presence bit at 24. Nothing is ever a guess: `clrNONE` is -1 and
//--- `-1 & 0xFFFFFF` is WHITE, so the presence bit is what tells "no colour of its own"
//--- from a colour nobody chose (P-DRAW-75's rule, one file over).
double DrawStylePackA(const int k)
{
   if(k <= DK_NONE || k >= DK_COUNT) return 0.0;
   long v = (long)((int)s_dkColor[k] & 0xFFFFFF);
   v += ((long)(s_dkWidth[k] & 0x7) << 24);
   v += ((long)(s_dkStyle[k] & 0x7) << 27);
   v += ((long)((s_dkFill[k] ? 1 : 0)) << 30);
   v += ((long)(s_dkRay[k] & 0x3) << 31);
   v += ((long)(((int)s_dkColor[k] >= 0) ? 1 : 0) << 33);
   v += ((long)(s_dkFont[k] & 0x7F) << 34);
   v += ((long)(s_dkGlyph[k] & 0xFF) << 41);
   v += ((long)((s_dkBack[k] ? 1 : 0)) << 49);
   return (double)v;
}
double DrawStylePackB(const int k)
{
   if(k <= DK_NONE || k >= DK_COUNT) return 0.0;
   long v = (long)((int)s_dkFillClr[k] & 0xFFFFFF);
   v += ((long)(((int)s_dkFillClr[k] >= 0) ? 1 : 0) << 24);
   return (double)v;
}
//--- THE UNPACK — the other half of the SAME contract. Word B is 25 bits by design, so
//--- its own mask (`0x1FFFFFF`) is what keeps the presence bit and the colour in one
//--- read; word A's fields are read with the shifts its pack wrote, and a colour is
//--- returned only when the presence bit says there was one.
void DrawStyleUnpack(const int k, const double rawA, const double rawB)
{
   if(k <= DK_NONE || k >= DK_COUNT) return;
   long a = (long)rawA;
   s_dkColor[k] = (((((a >> 33) & 0x1) != 0)) ? (color)(int)(a & 0xFFFFFF) : clrNONE);
   s_dkWidth[k] = (int)((a >> 24) & 0x7);
   s_dkStyle[k] = (int)((a >> 27) & 0x7);
   s_dkFill[k]  = (((a >> 30) & 0x1) != 0);
   s_dkRay[k]   = (int)((a >> 31) & 0x3);
   s_dkFont[k]  = (int)((a >> 34) & 0x7F);
   s_dkGlyph[k] = (int)((a >> 41) & 0xFF);
   s_dkBack[k]  = (((a >> 49) & 0x1) != 0);
   long b = (long)rawB;
   b &= 0x1FFFFFF;   // word B is 25 bits: 24 of colour + its own presence bit
   s_dkFillClr[k] = ((((b >> 24) & 0x1) != 0) ? (color)(int)(b & 0xFFFFFF) : clrNONE);
   s_dkValid[k] = true;
}


// ══════════════════════════════════════════════════════════════════════════
// P-DRAW-128 — THE NATIVE SURFACE'S PICK IS A PICK TOO.
// Called from the CHARTEVENT_OBJECT_CHANGE branch (DrawStrip_Router.mqh's sync
// block), which is where the terminal reports its own dialog and toolbar: the
// hand recoloured a drawing OUTSIDE every surface we own. The witness above
// says whether the COLOUR is what moved (a move-drop fires the same event and
// must teach nothing); the memory below is asked compare-first, so a colour
// the kind already wears — or the ink it merely BORROWED at birth (P-DRAW-INK)
// — is not news. What survives is one write through the memory's own owner.
// Cost on a still frame: zero (no event, no call). Cost per native change: one
// property read, one bounded scan, and — only when the colour truly moved —
// the same single file write every other pick already pays.
// ══════════════════════════════════════════════════════════════════════════
void DrawInkLearnNative(const string name)
{
   EDrawKind k;
   color c = DrawInkWitnessRead(name, k);
   if((int)c < 0) return;                    // a stranger, a ray, a path, a level kind, or a colour nobody can hold
   if(!DrawInkMemoDelta(name, c)) return;    // nothing moved: our own write, or a drop
   if(c == s_dkColor[k]) return;             // the kind already wears it
   if((int)s_dkColor[k] < 0 && c == s_dkAnyClr) return;   // a borrowed ink is not this kind's own
   s_dkColor[k] = c;
   s_dkAnyClr   = c;
   s_dkValid[k] = true;
   DrawTplSave();
}


//--- P-DRAW-08f: "ALL" MEANS **THIS** LOOK, not "the preset the strip happens to
//--- be cycling". The cycle index is the strip's own state and the user cannot see
//--- it, so applying it to every drawing of the kind applies something they never
//--- chose — the look on the chart in front of them is the one they mean. One walk,
//--- the kind's own slots, the object itself skipped.
int DrawStyleApplyToKind(const string fromName)
{
   EDrawKind k = DrawKindOf(fromName);
   if(k == DK_NONE || ObjectFind(0, fromName) < 0) return 0;
   color  c  = (color)(int)DrawSlotRead(fromName, DRAW_SLOT_COLOR);
   int    w  = (int)DrawSlotRead(fromName, DRAW_SLOT_WIDTH);
   int    st = (int)DrawSlotRead(fromName, DRAW_SLOT_STYLE);
   double f  = DrawSlotRead(fromName, DRAW_SLOT_FILL);
   double r  = DrawSlotRead(fromName, DRAW_SLOT_RAY);
   //--- P-DRAW-64: the interior is part of the look this group wears.
   double fc = DrawSlotRead(fromName, DRAW_SLOT_FILLCLR);
   double fo = DrawSlotAlphaGet(fromName, DRAW_SLOT_FILLCLR);
   int done = 0;
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string nm = ObjectName(0, i, -1, -1);
      if(nm == "" || nm == fromName || DrawIsIndicatorObject(nm)) continue;
      if(DrawKindOf(nm) != k) continue;
      DrawSlotWrite(nm, DRAW_SLOT_COLOR, (double)(int)c);
      DrawSlotWrite(nm, DRAW_SLOT_WIDTH, (double)w);
      DrawSlotWrite(nm, DRAW_SLOT_STYLE, (double)st);
      if(DrawSlotAvailable(k, DRAW_SLOT_FILL)) DrawSlotWrite(nm, DRAW_SLOT_FILL, f);
      if(DrawSlotAvailable(k, DRAW_SLOT_RAY))  DrawSlotWrite(nm, DRAW_SLOT_RAY, r);
      if(DrawSlotAvailable(k, DRAW_SLOT_FILLCLR))
      {
         DrawSlotWrite(nm, DRAW_SLOT_FILLCLR, fc);
         DrawSlotOpacitySet(nm, (int)fo, DRAW_SLOT_FILLCLR);
      }
      done++;
   }
   return done;
}

//--- P-DRAW-09b-RETIRED (2026-10-03): HOW MANY DRAWINGS «Apply to all <Kind>» WILL
//--- REALLY TOUCH. The row's label used to print the SELECTION's size, so it promised
//--- «all 2 selected» while the act underneath reached every drawing of the kind. This is
//--- the walk `DrawStyleApplyToKind` performs, so the number and the act are one fact.
int DrawStyleKindCount(const string fromName)
{
   EDrawKind k = DrawKindOf(fromName);
   if(k == DK_NONE) return 0;
   int n = 0;
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string nm = ObjectName(0, i, -1, -1);
      if(nm == "" || nm == fromName || DrawIsIndicatorObject(nm)) continue;
      if(DrawKindOf(nm) != k) continue;
      n++;
   }
   return n;
}

// ══════════════════════════════════════════════════════════════════════════
// P-DRAW-09b (2026-09-23) — THE GROUP: ONE TOOLBAR, MANY DRAWINGS.
//
// User order: «همه نیازهای کاربر رو پوشش بده» + «سریع و راحت ولی پر امکانات».
// MT4's own properties dialog is strictly ONE object at a time, and
// `DrawStyleApplyToKind` (P-DRAW-03) was the blunt answer — every drawing of the
// kind, whether the user meant them or not. The honest middle, «these five boxes
// and not the two on the other side of the chart», has no MT4 control at all,
// and it is the one a trader reaches for every session: point at what you mean,
// then edit it once.
//
// THE MODEL. The terminal's OWN selection IS the group. MT4 already has a
// multi-select (Ctrl+click), and a selected object is exactly "the user pointed
// at this one" — so nothing new has to be taught, and no second selection state
// can drift from the one on the chart. The group is a SNAPSHOT taken when the
// strip opens, and it is HOMOGENEOUS BY KIND: a slot means the same thing on
// every member or it is not a group at all (a fibo has no fill, a box has no
// ray). A mixed selection therefore falls back to the ONE drawing the user
// actually held — the behaviour that cannot surprise anybody.
//
// WHY A SNAPSHOT, NOT A LIVE READ. A walk of the object list is a session cost
// (P-DRAW-04's rule), the selection emits no event to subscribe to, and a group
// that changed under the user's hand mid-edit is worse than a stale one. The
// strip re-reads on every open, which is the moment the group can legitimately
// change.
// ══════════════════════════════════════════════════════════════════════════
// P-DRAW-09b-RETIRED (2026-10-03): THE STRIP SERVES ONE OBJECT. Reported: «مثلا من
// اگر دوتا فيبو داشته باشم بخوام رنگ يک شو عوض کنم روي ديگر هم اعمال ميشه» — two fibos,
// one colour tap, the second changed too. The writer was not the colour writer: this
// store walked the chart for every drawing of the held kind whose OBJPROP_SELECTED was
// true, and MT4 keeps that flag long after the gesture, so a Ctrl+click made hours
// earlier became a standing instruction. The store holds the held name and nothing else
// now, so every fan-out loop in the strip is gone by ARITHMETIC; «Apply to all <Kind>»
// stays the ONE explicit multi-object command (`DrawStyleApplyToKind`).
#define DRAW_SEL_MAX 1

static string s_dkSel[DRAW_SEL_MAX];
static int    s_dkSelN = 0;

int DrawSelCount() { return s_dkSelN; }
string DrawSelAt(const int i)
{
   if(i < 0 || i >= s_dkSelN) return "";
   return s_dkSel[i];
}
void DrawSelClear() { s_dkSelN = 0; }

//--- the members the chart still has (a delete, a legacy object) are dropped; the
//--- group never holds a name that would make a write a no-op.
void DrawSelPrune()
{
   int w = 0;
   for(int i = 0; i < s_dkSelN; i++)
   {
      if(s_dkSel[i] == "" || ObjectFind(0, s_dkSel[i]) < 0) continue;
      s_dkSel[w] = s_dkSel[i];
      w++;
   }
   for(int j = w; j < s_dkSelN; j++) s_dkSel[j] = "";
   s_dkSelN = w;
}

//--- SNAPSHOT: THE SERVED NAME, and never a walk (P-DRAW-09b-RETIRED). The terminal's
//--- own selection was once the group, but `OBJPROP_SELECTED` outlives the gesture that
//--- set it, so «these drawings» was a statement from an hour ago. The served drawing is
//--- the one the hand opened, and the callers' loops keep their shape (`DrawSelCount` is
//--- 0 or 1), so no fan-out can run without a caller first writing a second name.
int DrawSelSnapshot(const string hold)
{
   DrawSelClear();
   if(hold == "" || (DrawIsIndicatorObject(hold) && !DrawIsHRay(hold) && !DrawIsPathSeg(hold))) return 0;   // P-HR-04/P-UI-136
   EDrawKind k = DrawKindOf(hold);
   if(k <= DK_NONE || k >= DK_COUNT) return 0;
   s_dkSel[0] = hold;
   s_dkSelN = 1;
   return s_dkSelN;
}

//--- THE KIND'S OWN NAME, for the strip's header («Fibo», «Box»). One owner, so
//--- no two surfaces can call the same drawing two different things.
string DrawKindName(const EDrawKind k)
{
   switch(k)
   {
      case DK_LINE:      return "Trend Line";
      case DK_HLINE:     return "Horizontal Line";
      case DK_VLINE:     return "Vertical Line";
      case DK_CHANNEL:   return "Channel";
      case DK_FIBO:      return "Fibo";
      case DK_FIBOFAN:   return "Fibo Fan";
      case DK_FIBOCHAN:  return "Fibo Channel";
      case DK_EXPANSION: return "Expansion";
      case DK_GANN:      return "Gann";
      case DK_PITCHFORK: return "Pitchfork";
      case DK_RECT:      return "Box";
      case DK_TRIANGLE:  return "Triangle";
      case DK_ELLIPSE:   return "Ellipse";
      case DK_ARROW:     return "Arrow";
      case DK_TEXT:      return "Text";
      case DK_TANGLE:    return "Trend by Angle";
      case DK_CYCLES:    return "Cycles";
      default:           return "Drawing";
   }
}

#endif // TOOLBAR_B_MQH

#endif // DRAW_TOOLBAR_MQH
