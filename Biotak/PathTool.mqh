// ============================================================================
// OWNED MT5 module - forked from the MetaTrader 4 source on 2026-10-12.
//   MT4 source : Biotak/Biotak/PathTool.mqh
//
// MT4 remains the LOGIC reference and tools/parity/module-report.py flags
// any drift, but nothing regenerates this file: MT5-only changes live here
// directly, marked MT5-ONLY / P-MT5-* / P-PERF-*.
//
// MT5-only changes this file already carries:
//   * the Lite witness prints nothing unless DSTRIP_DIAG is set  (1 substitution)
// ============================================================================
//+------------------------------------------------------------------+
//| PathTool.mqh — Path (TradingView Path parity).                    |
//+------------------------------------------------------------------+
//| LAYER: drawing/domain (no UI deps - compiles in Full AND Lite).   |
//| Arm → click adds a vertex, segments join consecutive vertices →   |
//| double-click (a still click within 400 ms/6 px of the last)       |
//| commits the path and disarms. IDLE: a click on a segment SELECTS |
//| the path (its dot lands on the free end) and a press near a       |
//| segment carries the WHOLE path. The DELETE lives on that dot      |
//| alone (P-UI-136: one pixel cannot host two gestures). ESC cancels |
//| the session (or restores a live drag), right-click cancels the arm.|
//+------------------------------------------------------------------+
#ifndef PATH_TOOL_MQH
#define PATH_TOOL_MQH

#define PATH_TAG "_PATH_"
#define PATH_COLOR clrRoyalBlue
#define PATH_WIDTH 2
#define PATH_STYLE STYLE_SOLID
#define PATH_GRAB_PX 8
#define PATH_DBL_MS 400
#define PATH_DBL_PX 6
#define PATH_DOT_PX 14    // the SELECT dot's grab radius (HRay's dot reads GRAB+4)
#define PATH_PREVIEW_TAG "PREVIEW"
// P-PERF-168 (2026-10-29) — THE HAND'S FRAME IS 16 ms, NOT EVERY EVENT.
//
// The user's report («ابزار path ما هنوز لگ شدید داره») is not arithmetic: the
// mouse-move handler is a handful of scalars. It is the TERMINAL's bill. Every
// `ObjectMove`/`ObjectSet*` on a chart object invalidates the chart, and the
// terminal then repaints it — with this product's 226..637 objects and their
// indicators that is a whole-chart frame, paid once PER EVENT. A hand at
// 100..125 events/s therefore asks for 100..125 whole-chart paints a second for
// a rubber band that only has to follow the cursor.
//
// The reference implementation (MQL5 "Chart Drawing Toolkit", the smooth one)
// pays the same bill and answers it the same way: its `RedrawAllObjectsThrottled`
// repaints at most once per 16 ms (`if(now - m_lastDragRedrawMs < 16) return;`)
// and the geometry it stores in between is just numbers. 16 ms ≈ 60 fps is the
// rate the eye reads as "attached to the hand", and it is the budget adopted
// here — one frame per 16 ms, the LAST sample always wins.
//
// What is throttled is the WRITE to the terminal, never the truth: every event
// still records its (time, price), and the release/commit paths flush the final
// sample so a stopped hand never leaves the preview one event behind.
#define PATH_FRAME_MS 16

// P-LOG-3 (AGENTS law 3): a witness is the FLUSHED file, never `Print` — MT4
// buffers the journal in RAM and a Print witness reads "nothing happened" long
// after the tap (P-DRAW-126). `DrawStripDiagEmit` is the channel's ONE owner
// (DrawStrip_Base.mqh), and it is BORROWED by name here: the path opens no
// second file and writes no second format.
#ifndef BUILD_LITE
// P-WARN-46 (2026-10-04): the prototype that stood here was the build's last warning 46
// in this file. A prototype is the IMPORT MQL4 needs for an #import-ed library, not for a
// body later in the same unit - MQL4 resolves that on its own (see the note in Toolbar_A).
void PathWitness(const string line) { DrawStripDiagEmit("[Path] " + line); }
#else
// Lite ships no draw strip, so it ships no diag channel — MQL4 rejects a
// prototype with no body anywhere in the unit (error 111), so the Lite witness
// is the journal. Same bytes, one owner per build.
// P-PERF-13 - silent by default, like the DrawStrip channel.
void PathWitness(const string line) { }
#endif

static bool   s_pathArmed       = false;
static bool   s_pathDeleting    = false;   // P-DEL-ATOMIC: our own sweep must not re-enter the watcher
static bool   s_pathLeft        = false;
static string s_pathDrag        = "";      // path id under the hand ("" = no drag)
static int    s_pathDragV       = -1;      // P-PERF-166: the VERTEX the hand holds (-1 = whole path)
static bool   s_pathMoved       = false;
static datetime s_pathSnapT     = 0;       // cursor time under the press (drag origin)
static double s_pathSnapP       = 0.0;     // ... and price
static int    s_pathPressX      = 0;
static int    s_pathPressY      = 0;
static string s_pathSnapNames[];           // drag: segment names
static int    s_pathSnapIx[];             // ... and WHICH anchor each one moves:
                                           // 0 = point0 · 1 = point1 · 2 = both (the whole path)
static datetime s_pathSnapT0[];
static double s_pathSnapP0[];
static datetime s_pathSnapT1[];
static double s_pathSnapP1[];
static string s_pathIds[];                 // registry of committed path ids
static string s_pathSel      = "";        // the SELECTED path (the dot's owner)
static string s_pathClick     = "";        // P-UI-146: nothing arms a delete on the chart any more
static uint   s_pathEndMs     = 0;         // the last carry that MOVED (its trailing click reads it)
static datetime s_pathAnchorT = 0;         // last committed vertex (session live)
static double s_pathAnchorP   = 0.0;
static int    s_pathSegCount  = 0;         // committed segments of the live session
static string s_pathSessionId = "";        // live session's id
static uint   s_pathLastVerMs = 0;         // last committed-vertex click stamp
static int    s_pathLastVerX  = 0;
static int    s_pathLastVerY  = 0;
static uint   s_pathNoGrabMs  = 0;       // P-UI-142: the terminal's own motion forbids our grab
static bool   s_pathPrimed    = false;   // ...and the carry writes NOTHING until it knows
static datetime s_pathPrimT   = 0;       // the gesture is ours (the first move is buffered)
static double s_pathPrimP     = 0.0;
// P-UI-142: is OUR grab allowed to start at all? The terminal's own motion is
// answered by the SHARED arbiter (GlobalVariables.mqh — the project-wide owner, so
// the ray, Base/Knot, TH3 and the leg measure ask the same question and cannot drift
// from this copy). What is left is the OTHER half of P-HR-06's «one gesture at a
// time»: another session of ours that is ARMED owns the press. Cost: one deadline
// read and, in Full, up to three bools — per PRESS, never per tick.
bool PathGrabBlocked()
{
   if(GestureGrabBlocked()) return true;
   if(BaseKnotSessionActive() || HRaySessionActive()) return true;
#ifndef BUILD_LITE
   if(TH3SessionActive() || LegMeasureSessionActive()) return true;
#endif
   return false;
}

bool PathSessionActive() { return s_pathArmed; }
bool PathViewOwned() { return (s_pathArmed || s_pathDrag != ""); }
// P-PATH-END: the SHIFT bit of the move stream, remembered for the click that
// follows it. MQL5 reports the modifiers on MOUSE_MOVE (1 left, 2 right, 4 SHIFT,
// 8 CTRL, 16 ALT) and NOT on CLICK, so the click has to read the last move.
// Bits (MQL5 reference, CHARTEVENT_MOUSE_MOVE sparam): bit0 left, bit1 right,
// bit2 SHIFT, bit3 CTRL, bit4 middle. So SHIFT is `& 4`.
static bool   s_pathShift       = false;
static bool   s_pathSwallowClick = false;   // the release click of a shift-end is not a gesture
//--- P-PERF-168: the frame budget's own state (see PATH_FRAME_MS above).
static uint   s_pathPrevMs      = 0;      // the last rubber-band frame painted
static uint   s_pathDragMs      = 0;      // ...and the last dot-carry frame
static bool   s_pathPend        = false;  // a preview sample is owed its frame
static bool   s_pathDragPend    = false;  // ...and a carry sample
static datetime s_pathPendT     = 0;
static double s_pathPendP       = 0.0;
static bool   s_pathPrevLive    = false;  // the rubber band's object exists (birth memo)
//--- P-PATH-CANVAS (2026-10-29): the band's tip, in the engine's own units. The
//--- painter reads these instead of an object's OBJPROP_TIME/PRICE.
static bool   s_pathCursorOk    = false;
static datetime s_pathCursorT   = 0;
static double s_pathCursorP     = 0.0;
static bool   s_pathHookMounted = false;
//--- P-PATH-CANVAS-2 (2026-10-29): WHERE THE BAND LIVES — DECIDED ONCE PER ARM.
//---
//--- The first version asked the engine on EVERY move and fell back to the object
//--- whenever it answered "no". That answer is NOT stable frame to frame:
//--- REnginePaint() returns false while the buffers are being rebuilt (a resize, a
//--- chart change, the first frame after an attach), so one "no" in the middle of a
//--- gesture built the OBJ_TREND preview while the canvas still held the previous
//--- frame's band — the hand sees BOTH, which is the user's «بعضی وقتا دوتا خط
//--- میشه». The choice is a property of the session, not of the frame: decide it
//--- on the first move of each arm and never draw the losing surface again.
static int    s_pathBandMode    = 0;   // 0 = undecided, 1 = canvas, 2 = object
//--- P-PERF-168b: the segment-count memo (see PathSegCount). One row per id;
//--- the epoch is the chart's object TOTAL, so any birth or death anywhere on
//--- the chart re-opens the question once instead of once per call.
static int    s_segEpoch        = -1;
static string s_segMemoId[];
static int    s_segMemoN[];
void PathArm()
{
   if(s_pathArmed) return;
   if(IsIndicatorHidden()) return;   // P-UI-160b: the F mute owns the chart — no new path under it
   GestureTakeRelease();   // P-UI-144: a NEW drawing is never gated by the last one — the
                           // arbiter's ONE question is per drawing, so arming clears it
   s_pathArmed = true; ChartViewLockAcquire(); ChartRedraw();
   //--- P-PERF-168: a new arm owes its first frame at once (the budget's stamp is
   //--- a leftover of the previous session otherwise, and the rubber band would
   //--- wait up to 16 ms for a frame it can already afford).
   s_pathPrevMs = 0;
   s_pathPend = false;
   //--- P-PATH-CANVAS: a fresh arm has no tip yet, and the FRONT slot must know a
   //--- horizontal pan moves this family too (only while armed — the band is the
   //--- only time-anchored pixel this tool owns).
   s_pathCursorOk = false;
   s_pathBandMode = 0;      // P-PATH-CANVAS-2: a new arm asks the engine again
   s_pathSwallowClick = false;   // P-PATH-BUG-4: a swallow that outlived its click
                                 // would eat the FIRST vertex of this new path
#ifdef BIOTAK_RENDER_ENGINE
   REngineExtTimeContent(true);
#endif
}
void PathCancel()
{
   if(!s_pathArmed) return;
   s_pathArmed = false;
   s_pathPend = false;   // P-PERF-168: a deferred sample never outlives the arm
   s_pathCursorOk = false;   // P-PATH-CANVAS: and neither does the band's tip
#ifdef BIOTAK_RENDER_ENGINE
   REngineExtTimeContent(false);
   REngineDirtyFront();      // wipe the band's last pixels off the FRONT layer
   REnginePaint();
#endif
   ChartViewLockRelease();
   ChartRedraw();
}
string PathPrefix()
{
   if(StringLen(inpObjectPrefix) == 0) return "";
   return inpObjectPrefix + PATH_TAG;
}
string PathSegName(const string id, const int i) { return PathPrefix() + id + "_" + IntegerToString(i); }
string PathPreviewName() { return PathPrefix() + PATH_PREVIEW_TAG; }
// P-PERF-167 (2026-10-29) — THE RUBBER BAND IS NOT A DRAWING.
//
// The preview is the OBJ_TREND the armed tool drags from the last committed
// vertex to the cursor, and its END IS THE CURSOR — so while a path is being
// drawn, the click that PLACES a vertex lands on this object almost every time.
// `DrawKindOf` reads it by type (OBJ_TREND -> DK_LINE), so the strip's
// click-toggle served it like one of the user's own trend lines: the whole
// settings plate (~40 objects) was painted on the vertex click and dismissed by
// the next one. MEASURED on the live chart today (XAUUSDb,M5 10:33:32 and
// 10:33:41): `[drawstrip] click opened on "THLevels_PATH_PREVIEW"
// selected=false` next to `chart event OBJ_CLICK(id=1) [ui=47 strip=47] took
// 47ms` — one 31..47 ms panel paint per vertex, i.e. on the one channel the hand
// is using at that moment, for a plate that has nothing to say about a drawing
// that does not exist yet. MT4 never had this: its strip has no click-toggle at
// all, so the divergence is ours alone.
//
// The exclusion is the tool's OWN rule, not a new one: `PathIdOfName` already
// refuses this very name as a segment id (`id != PATH_PREVIEW_TAG`, above), so
// the segment family has never served it — the kind table simply never asked.
bool PathIsPreviewName(const string nm)
{
   if(nm == "") return false;
   string pn = PathPreviewName();
   return (pn != "" && nm == pn);
}
// P-PATH-END (2026-10-29) — WHILE THE TOOL IS DRAWING, ITS OWN OBJECTS ARE NOT
// DRAWINGS, AND THE STRIP MAY NOT TOUCH THEM.
//
// MEASURED on the live chart today (XAUUSDb,M5 10:47:32, 10:47:33, 10:47:36,
// 10:47:50 — one line per vertex):
//   [drawstrip] interior-click relHit="THLevels_PATH_668721825041_0"
//   [dsopen]    nm="THLevels_PATH_668721825041_0" ...
//   [drawstrip] click opened on "THLevels_PATH_668721825041_0"
//   [drawstrip] press-away dismissed at ...
// Every vertex click lands on the segment that ENDS at the cursor (the one the
// click before it drew), the strip serves that segment like one of the user's
// drawings, paints its whole plate (~40 objects, the 31..47 ms `strip=` bucket),
// and `UIPointerOverSurface` then eats the NEXT click because the plate now sits
// on the cursor. That second half is why the path could not be FINISHED: the
// double-click needs two clicks at one pixel, and the second one is swallowed by
// the panel the first one opened. The P-PERF-167 exclusion above covers the
// preview only; the session's SEGMENTS are the ones that grow under the hand.
//
// So the whole live session — preview AND segments — is DK_NONE while the tool is
// armed. Once PathFinish commits it, `s_pathArmed` is false and the same names
// are an ordinary path again (selectable, servable, draggable).
// P-PATH-END b (2026-10-29, user: «درست نشده باز هم هم لگ داره و هم درست قطع
// نمیشه» — SECOND REPORT): THE QUESTION WAS TOO NARROW.
//
// The first spelling asked `s_pathArmed && name starts with THIS session id`,
// and the terminal log of the second attempt (AUDUSDb,H1 11:11:57) answered it:
//   [dsclick] DEDUPE dropped CHART_CLICK (obj="BiotakMenuV2_..._ToolsIcon4")  <- the tool was just pressed
//   [drawstrip] interior-click relHit="THLevels_PATH_81527182532_0"
//   [dsopen] nm="THLevels_PATH_81527182532_0" ... [PERF] CLICK took 78ms strip=62
// `_0` existed BEFORE the first vertex of this attempt (there is no commit
// between the icon press and this click): it is the segment of an EARLIER,
// unfinished session that survived a reload/TF switch and was then adopted and
// REGISTERED by PathAdoptOrphans — so the id test said "not my session" and the
// strip served it, painting its 62 ms plate under the hand on the one click that
// was meant to place a vertex. That is both symptoms at once: the plate's paint
// (62..78 ms per click, 46 ms per mouse-move while it sits open) is the lag, and
// the plate sitting on the cursor is what swallows the next click, so the
// double-click that FINISHES the path can never complete.
//
// So the question is not "is this the current session's id" but "is a session
// LIVE at all": while the hand is drawing, the whole path FAMILY — segments,
// vertex handles, 50 % markers and the rubber band, whatever id they carry —
// answers DK_NONE, and every consumer (strip, hit test, selection, delete) gets
// that one answer. A REGISTERED path is the exception and keeps behaving like
// any other drawing, because that is what it is: a drawing the user already
// committed, and the strip is the only place its colour/width can be edited.
bool PathSessionLive()
{
   return (s_pathArmed || s_pathSegCount > 0 || s_pathSessionId != "");
}
bool PathIsSessionName(const string nm)
{
   if(nm == "") return false;
   string pfx = PathPrefix();
   if(pfx == "" || StringFind(nm, pfx) != 0) return false;   // not the path family
   if(nm == PathPreviewName()) return true;                  // the rubber band is never a drawing
   if(!PathSessionLive()) return false;                      // no hand drawing: ordinary drawings
   //--- ARMED IS THE WHOLE FAMILY, registered or not: a leftover path the user
   //--- abandoned mid-draw is still "under the hand" the moment the tool is
   //--- pressed again, and that is exactly the click the log caught (an OLD id's
   //--- `_0` opening a 62 ms plate on the first vertex of a NEW attempt).
   if(s_pathArmed) return true;
   //--- the family's id, read the same way PathIdOfName reads it (`<id>_<digits>`)
   string rest = StringSubstr(nm, StringLen(pfx));
   int us = -1;
   for(int i = 0; i < StringLen(rest); i++)
      if(StringGetChar(rest, i) == 95) us = i;
   string id = (us > 0 ? StringSubstr(rest, 0, us) : "");
   if(id != "")
      for(int i = 0; i < ArraySize(s_pathIds); i++)
         if(s_pathIds[i] == id) return false;                // a committed path: served as before
   return true;
}
// P-PERF-168b (2026-10-29) — THE SEGMENT COUNT IS A STRUCTURAL FACT, NOT A
// PER-MOVE SCAN.
//
// `PathSegCount` is the tool's most-called function: a vertex projection asks it
// (PathVertex), the carry asks it (PathDragApply), every handle pass asks it
// (PathHandleAt -> PathVertex), the orphan walk and the delete watcher ask it.
// Each call was a walk of `ObjectFind` from index 0 to the first hole — n+1
// terminal round-trips AND n+1 string builds, on every mouse move. A six-leg
// path paid ~28 of them per move (read off the call graph; MQL5Compat's ledger
// counts each one as `obj find live`).
//
// The count is a fact about the OBJECT SET, and that set only changes when
// something is born or dies. `ObjectsTotal` states that fact in one call, and
// PathAdoptOrphans already leans on it for the same reason (P-PERF-157b). So the
// memo is keyed by the chart's total: unchanged total -> the answer is still
// true; changed total -> every row is dropped and the next ask walks once.
// `PathSegMemoDrop` is the explicit half, for the one case a total cannot see
// (a segment deleted while an unrelated object is born in the same instant).
void PathSegMemoDrop(const string id)
{
   for(int i = 0; i < ArraySize(s_segMemoId); i++)
      if(s_segMemoId[i] == id)
      {
         int n = ArraySize(s_segMemoId);
         for(int j = i; j < n - 1; j++)
         {
            s_segMemoId[j] = s_segMemoId[j + 1];
            s_segMemoN[j]  = s_segMemoN[j + 1];
         }
         ArrayResize(s_segMemoId, n - 1);
         ArrayResize(s_segMemoN,  n - 1);
         return;
      }
}
// The whole memo, dropped. The chart-change channel calls it: that is the one
// moment the object set can have moved without a total this tool watched (a
// birth and a death in the same instant net to the same count), and it is also
// the moment PathAdoptOrphans re-establishes the truth anyway.
void PathSegMemoReset()
{
   ArrayResize(s_segMemoId, 0);
   ArrayResize(s_segMemoN, 0);
   s_segEpoch = -1;
}
int PathSegCount(const string id)
{
   int total = ObjectsTotal(0, 0, -1);   if(total != s_segEpoch)
   {
      s_segEpoch = total;
      ArrayResize(s_segMemoId, 0);
      ArrayResize(s_segMemoN, 0);
   }
   int m = ArraySize(s_segMemoId);
   for(int i = 0; i < m; i++) if(s_segMemoId[i] == id) return s_segMemoN[i];
   int n = 0;
   for(int i = 0; i < 256; i++)
   {
      if(ObjectFind(0, PathSegName(id, i)) < 0) break;
      n++;
   }
   ArrayResize(s_segMemoId, m + 1);
   ArrayResize(s_segMemoN, m + 1);
   s_segMemoId[m] = id;
   s_segMemoN[m]  = n;
   return n;
}
void PathRegAdd(const string id)
{
   for(int i = 0; i < ArraySize(s_pathIds); i++)
      if(s_pathIds[i] == id) return;
   int n = ArraySize(s_pathIds);
   ArrayResize(s_pathIds, n + 1);
   s_pathIds[n] = id;
}
// P-UI-136 — THE VERTEX HANDLES. HRay parity, one shape: the drawing carries the
// handle, the handle owns the delete, and the drawing's own pixels mean only
// "take me" (HRayHandleName/HRayIsHandle/HRaySelect). A path wears one handle per
// VERTEX (n segments = n+1 points, the free end included), so a press on a
// handle edits that point — and a press on a segment only SELECTS (P-UI-145).
// The `H` in the name keeps `PathIdOfName` from reading a handle as a SEGMENT (its
// tail is not digits), so the orphan walk and the delete watcher skip it without
// a second test.
string PathHandleName(const string id, const int k) { return PathPrefix() + id + "_H" + IntegerToString(k); }
bool PathIsHandle(const string nm)
{
   string pfx = PathPrefix();
   if(pfx == "" || StringFind(nm, pfx) != 0) return false;
   string rest = StringSubstr(nm, StringLen(pfx));
   int ulast = -1;
   for(int i = 0; i < StringLen(rest); i++)
      if(StringGetChar(rest, i) == 95) ulast = i;
   return (ulast > 0 && ulast + 1 < StringLen(rest) && StringGetChar(rest, ulast + 1) == 72);   // 'H'
}
// P-PATH-BUG-6 (2026-10-29) — A CHILD IS SWEPT BY NAME, NOT BY ITS PARENT'S COUNT.
// Both child families were dropped by walking 0..PathSegCount(id), which is only
// correct while the parent is still whole. Every route that matters runs AFTER the
// segments are gone — the delete watcher (a native delete of the last segment) and
// PathRegDel itself — and PathSegCount then answers 0, so the sweep deleted `_H0`
// and left `_H1.._Hn` on the chart. That is the exact «dots with no lines» the
// P-UI-146 note set out to end, still reachable two years later by a different door.
// One walk of the object list answers for any state of the parent.
void PathChildrenDrop(const string id, const string tail)
{
   if(id == "") return;
   const string pre = PathPrefix() + id + tail;
   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--)   // backwards: a delete shifts the tail
   {
      string nm = ObjectName(0, i, 0, -1);
      if(StringFind(nm, pre) == 0) ObjectDelete(0, nm);
   }
}
// The handles go with the path, always as one family (P-LOG-10 law 4). It sits ABOVE
// PathRegDel on purpose: P-UI-146 makes the registrar the one sweep, and MQL4 has no
// prototype that is not a warning (warning 46), so the order carries the dependency.
void PathHandlesDrop(const string id)
{
   int m = PathSegCount(id);
   if(m > 0)   // the parent is whole: the count is exact and this is the cheap pass
   {
      for(int k = 0; k <= m; k++) ObjectDelete(0, PathHandleName(id, k));
      return;
   }
   PathChildrenDrop(id, "_H");   // the parent is gone: nothing to count, sweep by name
}
void PathRegDel(const string id)
{
   //--- P-UI-146 (2026-10-02, user: «ابزار path که حذف میشه وابتگی‌هاهم حذف بشه» — the
   //--- screenshot showed five blue dots and no lines): the sweep lives HERE, in the one
   //--- function that means «this path no longer exists», so no route can forget it. Three
   //--- routes ended a path and only two took the dots with them: PathDelete dropped the
   //--- handles of whatever was SELECTED (PathSelect("")), not of the path it was deleting,
   //--- and the cascade at the OBJECT_DELETE watcher deregistered with no sweep at all. A
   //--- child outliving its parent is the orphan class this closes.
   PathHandlesDrop(id);
   if(s_pathSel == id) s_pathSel = "";
   int n = ArraySize(s_pathIds);
   for(int i = 0; i < n; i++)
      if(s_pathIds[i] == id)
      {
         for(int j = i; j < n - 1; j++) s_pathIds[j] = s_pathIds[j + 1];
         ArrayResize(s_pathIds, n - 1);
         return;
      }
}
// The handles go with the path, always as one family (P-LOG-10 law 4).
void PathSelect(const string id)
{
   if(s_pathSel != "" && s_pathSel != id) PathHandlesDrop(s_pathSel);
   s_pathSel = id;
   s_pathClick = "";   // a selection is not a delete witness — HRaySelect's rule
}
// Vertex k of the path: k=0 is the first segment's anchor, k=n the free end, and
// every k in between is the shared point of segments k-1 and k.
bool PathVertex(const string id, const int k, datetime &t, double &p)
{
   t = 0; p = 0.0;
   int n = PathSegCount(id);
   if(n <= 0 || k < 0 || k > n) return false;
   int si = (k == n ? n - 1 : k);
   int pt = (k == n ? 1 : 0);
   string nm = PathSegName(id, si);
   if(ObjectFind(0, nm) < 0) return false;
   t = (datetime)ObjectGetInteger(0, nm, OBJPROP_TIME, pt);
   p = ObjectGetDouble(0, nm, OBJPROP_PRICE, pt);
   return (t > 0 && p > 0);
}
// One handle, placed. Off-path or unselected -> the handle does not exist (an
// unselected chart wears no circles, P-HR-03's rule).
void PathHandleAt(const string id, const int k)
{
   string hn = PathHandleName(id, k);
   if(id == "" || id != s_pathSel) { ObjectDelete(0, hn); return; }
   // P-UI-160b (2026-10-16): the F mute parks the vertex circles. They are
   // BITMAP_LABELs — no TF mask reaches them — so the pan stream, the
   // chart-change follower and the hide pass all land HERE, and this one
   // branch keeps every channel from re-placing them while hidden.
   if(IsIndicatorHidden())
   {
      HandsetHandleAtXY(hn, HANDSET_HANDLE_PARK, HANDSET_HANDLE_PARK, CP_HANDLE_HALF, CP_HANDLE_RES);
      return;
   }
   datetime t = 0; double p = 0.0;
   if(!PathVertex(id, k, t, p)) { ObjectDelete(0, hn); return; }
   int x = 0, y = 0;
   if(!(p > 0) || !ChartTimePriceToXY(0, 0, t, p, x, y))
      HandsetHandleAtXY(hn, HANDSET_HANDLE_PARK, HANDSET_HANDLE_PARK, CP_HANDLE_HALF, CP_HANDLE_RES);
   else
      HandsetHandleAtXY(hn, x, y, CP_HANDLE_HALF, CP_HANDLE_RES);
}
// The whole set, in one pass — the seat every gesture re-reads. Cost: one
// ChartTimePriceToXY per vertex, on gesture events only (never on a tick). ONE
// name for the job, so no caller can re-place only the free end.
void PathHandleFollow(const string id)
{
   if(id == "" || id != s_pathSel) return;
   if(PathSegCount(id) <= 0) { PathSelect(""); return; }   // the path died: the handles go with it
   PathHandlesFollowAll(id);
}
void PathHandlesFollowAll(const string id)
{
   int n = PathSegCount(id);
   for(int k = 0; k <= n; k++) PathHandleAt(id, k);
}
// The handle's own hit test — the ONLY surface that can answer "remove", and the
// only surface that can answer "move this point".
bool PathDotHit(const int mx, const int my, string &id, int &k)
{
   id = ""; k = -1;
   if(IsIndicatorHidden()) return false;   // P-UI-160b: no grabbing a hidden path's dot
   if(s_pathSel == "") return false;
   int n = PathSegCount(s_pathSel);
   int best = 0x7fff;
   for(int i = 0; i <= n; i++)
   {
      if(ObjectFind(0, PathHandleName(s_pathSel, i)) < 0) continue;
      datetime t = 0; double p = 0.0;
      if(!PathVertex(s_pathSel, i, t, p)) continue;
      int x = 0, y = 0;
      if(!ChartTimePriceToXY(0, 0, t, p, x, y)) continue;
      int d = (int)MathSqrt((double)((mx - x) * (mx - x) + (my - y) * (my - y)));
      if(d <= PATH_DOT_PX && d < best) { best = d; k = i; }
   }
   if(k < 0) return false;
   id = s_pathSel;
   return true;
}
bool PathIdOfName(const string nm, string &id)
{
   string pfx = PathPrefix();
   if(pfx == "" || StringFind(nm, pfx) != 0) return false;
   string rest = StringSubstr(nm, StringLen(pfx));
   // last underscore splits the segment index; the id itself must be all digits
   int ulast = -1;
   for(int i = 0; i < StringLen(rest); i++)
      if(StringGetChar(rest, i) == 95) ulast = i;
   if(ulast <= 0) return false;
   string maybeIdx = StringSubstr(rest, ulast + 1);
   for(int i = 0; i < StringLen(maybeIdx); i++)
      if(StringGetChar(maybeIdx, i) < 48 || StringGetChar(maybeIdx, i) > 57) return false;
   id = StringSubstr(rest, 0, ulast);
   return (id != "" && id != PATH_PREVIEW_TAG);
}
string PathTooltip(const int segs)
{
   // P-MT5-PARITY (2026-10-21) - PARITY (MT4 PathTool.mqh:276-279): the tooltip is MT4's string, word for
   // word. The two builds must show the same label on the same object.
   return "Path · " + IntegerToString(segs + 1) + " points — click to select, drag to move — double-click the dot to remove";
}
void PathDelete(const string id, const string why)
{
   if(s_pathDeleting) return;
   s_pathDeleting = true;
   PathWitness("delete id=" + id + " segs=" + IntegerToString(PathSegCount(id)) + " why=" + why);
   if(s_pathDrag == id) PathDragRelease();
   PathSelect("");                       // every handle is the path's CHILD (P-HR-07's rule, one way)
   int n = PathSegCount(id);
   for(int i = 0; i < n; i++) ObjectDelete(0, PathSegName(id, i));
   PathSegMemoDrop(id);   // P-PERF-168b: the count died with the family
   PathRegDel(id);
   PathInkForget(id);            // P-UI-137: the ink row dies with its path (no leak)
   PathMidDrop(id);              // P-UI-139: ...and its 50 % markers with it (one sweep)
   if(s_pathDrag == id) { s_pathDrag = ""; s_pathDragV = -1; }
   if(s_pathClick == id) s_pathClick = "";
   // P-DEL-ATOMIC: the terminal queues one event per deleted segment; the family is
   // already gone, so the rest of those events must not re-enter and redraw.
   g_suppressDeleteEventsUntilMs = GetTickCount() + 250;
   s_pathDeleting = false;
   ChartRedraw();
}
void PathSessionClear()
{
   bool deleting = s_pathDeleting;
   s_pathDeleting = true;
   string pfx = PathPrefix();
   if(pfx != "" && s_pathSessionId != "")
      for(int i = 0; i < s_pathSegCount; i++) ObjectDelete(0, PathSegName(s_pathSessionId, i));
   ObjectDelete(0, PathPreviewName());
   s_pathPrevLive = false;   // P-PERF-168: the memo dies with the object
   s_pathPend = false;
   s_pathCursorOk = false;   // P-PATH-CANVAS: no anchor, no band to paint
   g_suppressDeleteEventsUntilMs = GetTickCount() + 250;
   s_pathDeleting = deleting;
   s_pathAnchorT = 0; s_pathAnchorP = 0;
   s_pathSegCount = 0;
   s_pathSessionId = "";
   s_pathLastVerMs = 0;
}
int PathPointToSegPx(const int mx, const int my, const datetime t1, const double p1, const datetime t2, const double p2)
{
   int x1 = 0, y1 = 0, x2 = 0, y2 = 0;
   if(!ChartTimePriceToXY(0, 0, t1, p1, x1, y1)) return 0x7fff;
   if(!ChartTimePriceToXY(0, 0, t2, p2, x2, y2)) return 0x7fff;
   double dx = (double)(x2 - x1), dy = (double)(y2 - y1);
   double len2 = dx * dx + dy * dy;
   double u = 0;
   if(len2 > 0) u = ((mx - x1) * dx + (my - y1) * dy) / len2;
   if(u < 0) u = 0; if(u > 1) u = 1;
   double px = x1 + u * dx, py = y1 + u * dy;
   return (int)MathSqrt((px - mx) * (px - mx) + (py - my) * (py - my));
}
bool PathPressHit(const int mx, const int my, string &id)
{
   id = "";   // P-PATH-BUG-2: the out-parameter is CLEARED, not inherited. The two
              // callers happen to pass a fresh local today; the day one passes a
              // reused variable the old id would answer "hit" with no hit at all.
   if(IsIndicatorHidden()) return false;   // P-UI-160b: no grabbing a hidden path
   int best = 0x7fff;
   for(int i = 0; i < ArraySize(s_pathIds); i++)
   {
      int n = PathSegCount(s_pathIds[i]);
      for(int s = 0; s < n; s++)
      {
         string nm = PathSegName(s_pathIds[i], s);
         if(ObjectFind(0, nm) < 0) continue;
         datetime t1 = (datetime)ObjectGetInteger(0, nm, OBJPROP_TIME, 0);
         double   p1 = ObjectGetDouble(0, nm, OBJPROP_PRICE, 0);
         datetime t2 = (datetime)ObjectGetInteger(0, nm, OBJPROP_TIME, 1);
         double   p2 = ObjectGetDouble(0, nm, OBJPROP_PRICE, 1);
         int d = PathPointToSegPx(mx, my, t1, p1, t2, p2);
         if(d <= PATH_GRAB_PX && d < best) { best = d; id = s_pathIds[i]; }
      }
   }
   return (id != "");
}
#ifdef BIOTAK_RENDER_ENGINE
//+------------------------------------------------------------------+
//| P-PATH-CANVAS — the rubber band, rasterized into the FRONT layer  |
//+------------------------------------------------------------------+
// The band is the one part of this tool that MOVES: it follows the cursor on
// every MOUSE_MOVE. As an OBJ_TREND it cost two ObjectMove calls per event and
// one whole-chart invalidation per event — at 100..125 events/s the terminal
// was asked to repaint a 226..637-object chart a hundred times a second for a
// dashed line. As pixels it costs a buffer write and rides the engine's own
// 16 ms frame budget (PATH_FRAME_MS), exactly like the reference toolkit's
// `RedrawAllObjectsThrottled`.
//
// Style 2 is the engine's DOT pattern (RLinePixelOn: x%3==0), the same dashed
// read the object carried (STYLE_DOT), and the tip gets a 3 px dot so the next
// click's landing point is visible at the resolution of the hand.
void PathPaintRubber(uint &fg[], const int w, const int h)
{
   if(!s_pathArmed || !s_pathCursorOk) return;
   if(s_pathAnchorT <= 0 || !(s_pathAnchorP > 0)) return;
   int x1 = 0, y1 = 0, x2 = 0, y2 = 0;
   if(!RPlatTimePriceToXY((long)s_pathAnchorT, s_pathAnchorP, x1, y1)) return;
   if(!RPlatTimePriceToXY((long)s_pathCursorT, s_pathCursorP, x2, y2)) return;
   //--- RPlotSeg/RPlotDot write into the engine's FRONT buffer, which IS `fg` here
   const uint ink = RCol(PATH_COLOR, 255);
   RPlotSeg(x1, y1, x2, y2, ink, PATH_WIDTH, 2);
   RPlotDot(x2, y2, 3, ink);
}
class CPathRubberHook : public IRPaintHook
{
public:
   virtual void RPaintExt(uint &fg[], int w, int h) { PathPaintRubber(fg, w, h); }
};
CPathRubberHook s_pathRubberHook;
#endif

void PathPreviewMove(const datetime t, const double p)
{
   if(s_pathAnchorT <= 0 || !(s_pathAnchorP > 0)) return;
#ifdef BIOTAK_RENDER_ENGINE
   //--- P-PATH-CANVAS (2026-10-29) — THE BAND IS PIXELS, NOT AN OBJECT.
   //---
   //--- The reference implementation (MQL5 "Chart Drawing Toolkit", 37 126 lines)
   //--- owns exactly ONE ObjectCreate in the whole product — an OBJ_LABEL for the
   //--- measure readout — and paints every drawing as a pixel run on a full-chart
   //--- CCanvas. Its rubber band cannot lag because a mouse move costs buffer
   //--- writes: no terminal round-trip, no chart invalidation, no object to move.
   //--- Our engine is the same idea with layers, and IRPaintHook has been declared
   //--- in RenderCore since R-RENDER-ENGINE with no owner. The band takes it: the
   //--- FRONT slot already has the bitmap, the frame key and the paint timer, so
   //--- the move below writes two numbers and asks for one frame.
   s_pathCursorT = t; s_pathCursorP = p; s_pathCursorOk = true;
   //--- the session's surface, chosen once (see s_pathBandMode). The decision's own
   //--- paint IS the band's first frame, so it is never paid twice.
   if(s_pathBandMode == 0)
   {
      REngineDirtyFront();
      s_pathBandMode = (REnginePaint() ? 1 : 2);
      if(s_pathBandMode == 1)
      {
         if(s_pathPrevLive) { ObjectDelete(0, PathPreviewName()); s_pathPrevLive = false; }
         return;
      }
   }
   else if(s_pathBandMode == 1)
   {
      //--- from here on the answer is IGNORED. A frame the engine skips (a resize
      //--- rebuilding the buffers) leaves the band one frame stale, which the eye
      //--- cannot see; building the object for it is what put two lines on the
      //--- chart. A stale pixel is always better than a second surface.
      REngineDirtyFront();
      REnginePaint();
      return;
   }
   s_pathCursorOk = false;   // the object path paints its own tip; the hook must not
#endif
   string nm = PathPreviewName();
   //--- P-PERF-166 (2026-10-29) — THE PREVIEW WEARS ITS DRESS ONCE, NOT EVERY MOVE.
   //--- This call runs on EVERY mouse move while the tool is armed (PathOnChartEvent's
   //--- MOUSE_MOVE branch), and it used to write ten OBJPROP_* values per move to say
   //--- what the object already said: ten terminal calls that change nothing, on the
   //--- one channel the hand feels as «the Path tool lags». The dress is a constant of
   //--- the tool (PATH_COLOR / STYLE_DOT / PATH_WIDTH), so it belongs to the object's
   //--- BIRTH; the move below carries the two anchors and nothing else. A preview that
   //--- was deleted (commit / cancel) is a birth again — the find decides it.
   //--- P-PERF-168 (2026-10-29): the BIRTH is a one-time question, not a
   //--- per-move one. The `ObjectFind` below used to run on every mouse move to
   //--- answer "does the rubber band exist" — a terminal round-trip per event for
   //--- a fact this file already owns (it creates the object and deletes it in
   //--- PathFinish / PathSessionClear). The memo is self-healing: if either move
   //--- comes back false the object died under us (a reload, a wipe) and the next
   //--- sample is a birth again.
   if(!s_pathPrevLive)
   {
      if(ObjectFind(0, nm) < 0)
      {
         ObjectCreate(0, nm, OBJ_TREND, 0, s_pathAnchorT, s_pathAnchorP, t, p);
         ObjectSetInteger(0, nm, OBJPROP_COLOR, PATH_COLOR);
         ObjectSetInteger(0, nm, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, nm, OBJPROP_WIDTH, PATH_WIDTH);
         ObjectSetInteger(0, nm, OBJPROP_RAY_LEFT, false);
         ObjectSetInteger(0, nm, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, nm, OBJPROP_SELECTED, false);
         ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
         ObjectSetInteger(0, nm, OBJPROP_BACK, false);
         ObjectSetInteger(0, nm, OBJPROP_ZORDER, Z_BOX_RAY);
      }
      s_pathPrevLive = true;
   }
   bool okA = ObjectMove(0, nm, 0, s_pathAnchorT, s_pathAnchorP);
   bool okB = ObjectMove(0, nm, 1, t, p);
   if(!okA || !okB) s_pathPrevLive = false;
}
// P-PERF-168 — ONE FRAME PER 16 ms, AND THE LAST SAMPLE ALWAYS WINS.
// The armed branch calls this on every MOUSE_MOVE; the sample is recorded either
// way, so the next event inside the same frame carries the newest coordinates and
// a stopped hand is at most one frame behind (the commit click reads its own
// pixel, so the committed geometry is never the buffered one).
void PathPreviewFrame(const datetime t, const double p)
{
   if(s_pathAnchorT <= 0 || !(s_pathAnchorP > 0)) return;
   s_pathPendT = t; s_pathPendP = p; s_pathPend = true;
   uint now = GetTickCount();
   if(s_pathPrevMs != 0 && (uint)(now - s_pathPrevMs) < PATH_FRAME_MS) return;
   s_pathPrevMs = now;
   s_pathPend = false;
   PathPreviewMove(s_pathPendT, s_pathPendP);
}
void PathPreviewFlush()
{
   if(!s_pathPend) return;
   s_pathPend = false;
   PathPreviewMove(s_pathPendT, s_pathPendP);
}
void PathNormalise(const string id)
{
   int n = PathSegCount(id);
   for(int i = 0; i < n; i++)
   {
      string nm = PathSegName(id, i);
      if(ObjectFind(0, nm) < 0) continue;
      if((bool)ObjectGetInteger(0, nm, OBJPROP_SELECTABLE))
         ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
      if((bool)ObjectGetInteger(0, nm, OBJPROP_SELECTED))
         ObjectSetInteger(0, nm, OBJPROP_SELECTED, false);
   }
}
// P-PERF-157b (2026-10-29) — THE ADOPT WALK IS AN ATTACH NET, NOT A PAN TAX.
// The twin of HRayAdoptOrphans (see the measurement there: a 703 ms
// CHART_CHANGE with 156 ms accounted; both walks are the O(chart) work in the
// other 547 ms). An unchanged object TOTAL means nothing was born or died since
// the last walk, so nothing new can be an orphan — one terminal read, no walk.
// `force` is the attach caller's (PathOnInit), which must always walk.
//--- P-PATH-END c (2026-10-29): A HALF-DRAWN SESSION NEVER BECOMES A DRAWING.
//--- A HARD restart (`tools/mt5-reload.ps1` closes the terminal) never runs
//--- PathOnDeinit, so the segments of the path the hand was in the middle of
//--- drawing stayed on the chart - and the adopt walk below then REGISTERED them
//--- as a finished path. MEASURED 2026-10-29 (AUDUSDb,H1 11:11:57, the first
//--- click after a reload): `relHit="THLevels_PATH_81527182532_0"` was a segment
//--- of exactly such a leftover, and the plate it opened is both the lag and the
//--- click that gets eaten.
//--- The mark an unfinished session leaves is its TOOLTIPS: PathMakeSegment
//--- writes PathTooltip(idx+1) per segment (2 points, 3 points, ...) while
//--- PathFinish rewrites every segment to PathTooltip(segs) (ONE label for the
//--- whole drawing). So a family whose first and last segment disagree was never
//--- committed, and it dies here - before the adopt walk can register it. A
//--- one-segment family cannot tell the two apart and is left alone (a one-leg
//--- path is a legal drawing).
void PathSweepUnfinished()
{
   string pfx = PathPrefix();
   if(pfx == "") return;
   int n = ObjectsTotal(0, 0, -1);
   string dead[];
   for(int i = 0; i < n; i++)
   {
      string nm = ObjectName(0, i, 0, -1);
      if(StringFind(nm, pfx) != 0) continue;
      string id;
      if(!PathIdOfName(nm, id) || id == "") continue;
      bool seen = false;
      for(int k = 0; k < ArraySize(dead); k++) if(dead[k] == id) seen = true;
      if(seen) continue;
      int m = PathSegCount(id);
      if(m < 2) continue;
      string t0 = ObjectGetString(0, PathSegName(id, 0), OBJPROP_TOOLTIP);
      string t1 = ObjectGetString(0, PathSegName(id, m - 1), OBJPROP_TOOLTIP);
      if(t0 == t1) continue;   // committed: one label on every segment
      int d = ArraySize(dead); ArrayResize(dead, d + 1); dead[d] = id;
   }
   for(int k = 0; k < ArraySize(dead); k++)
   {
      int m = PathSegCount(dead[k]);
      for(int s = 0; s < m; s++) ObjectDelete(0, PathSegName(dead[k], s));
      PathHandlesDrop(dead[k]);
      PathWitness("unfinished session swept id=" + dead[k] + " segs=" + IntegerToString(m));
   }
}
void PathAdoptOrphans(const bool force = false)
{
   string pfx = PathPrefix();
   if(pfx == "") return;
   int n = ObjectsTotal(0, 0, -1);
   static int s_adoptTotal = -1;
   if(!force && n == s_adoptTotal) return;
   s_adoptTotal = n;
   for(int i = 0; i < n; i++)
   {
      string nm = ObjectName(0, i, 0, -1);
      if(StringFind(nm, pfx) != 0) continue;
      string id;
      if(!PathIdOfName(nm, id))
      {
         //--- P-UI-146 (2026-10-02, user: «ابزار path که حذف میشه وابتگی‌هاهم حذف بشه» —
         //--- the screenshot was five blue dots and no lines): a VERTEX DOT whose path has no
         //--- segments left is an orphan. Two older builds wrote them: their delete routes
         //--- swept only the selection, not the path being deleted, and this walk could never
         //--- see them again because `PathIdOfName` rightly refuses to read a handle as a
         //--- segment. So the sweep lives here, where the family is already being walked, and
         //--- it costs one string scan per prefixed object ONCE per attach.
         if(PathIsHandle(nm))
         {
            string rest = StringSubstr(nm, StringLen(pfx));
            int us = -1;
            for(int c = 0; c < StringLen(rest); c++)
               if(StringGetChar(rest, c) == 95) us = c;
            if(us > 0 && PathSegCount(StringSubstr(rest, 0, us)) == 0) ObjectDelete(0, nm);
         }
         continue;
      }
      PathRegAdd(id);
      PathNormalise(id);
   }
   // The sweep above can DELETE an orphan dot, so the total it entered with is
   // no longer the chart's — re-read it or the next event pays one walk for our
   // own cleanup.
   s_adoptTotal = ObjectsTotal(0, 0, -1);
}
// P-UI-136 — THE STRIP WRITES THE WHOLE PATH, NEVER ONE SEGMENT. The strip's slot
// writer aims at ONE name (`DrawSlotWrite(name, …)`), and a path is N segments: a
// colour or a width that reached only the segment under the hand would leave the
// drawing two-toned. So this is the ONE fan-out the path owns — the strip calls
// it instead of ObjectSetInteger, and every sibling inherits the write in the
// same pass. Cost: one ObjectSetInteger per sibling, on a user action.
void PathFamilySet(const string segName, const int prop, const long value)
{
   ObjectSetInteger(0, segName, (ENUM_OBJECT_PROPERTY_INTEGER)prop, value);
   string id;
   if(!PathIdOfName(segName, id)) return;
   int n = PathSegCount(id);
   for(int i = 0; i < n; i++)
   {
      string sib = PathSegName(id, i);
      if(sib == segName) continue;
      ObjectSetInteger(0, sib, (ENUM_OBJECT_PROPERTY_INTEGER)prop, value);
   }
}
// P-UI-137 — THE PATH'S OWN INK + OPACITY STORE. Every OTHER drawing keeps its pure
// colour and its `[OP…]` alpha in a DESCRIPTION TAG on the object; a path segment
// is an OBJ_TREND and MT4 PAINTS OBJPROP_TEXT along the line, so a tag would draw
// "#RRGGBB" on the chart (the same law that gives the colour slot its plain ink).
// So the path keeps the two numbers in a file-scope store, one row per path id:
//   PURE colour (what the user chose - the HEX field and the readout read THIS)
//   opacity 0..100 (100 = full, the same direction as `[OP…]`)
// and every SEGMENT wears the blend. Cost: a scan over a handful of store rows (no
// object reads) plus ONE blend, then n ObjectSetInteger for n segments - a 3-point
// path is 2 writes - on the slider's own step, never on a tick.
static string s_pathInkId[];
static color  s_pathInkPure[];
static int    s_pathInkOp[];
static int    s_pathLock[];   // P-UI-138: the lock rides the SAME row (one store, one id)
static int    s_pathMid[];    // P-UI-139: ...and so does the 50 % marker switch
// P-UI-137: `DRAW_OP_MIN` (Toolbar_A, included AFTER this file) is 1 — "0 would be
// the chart's own background: invisible is a lie" — and the floor is stated HERE for
// the same reason, so the path's slider can never rest on 0 while the strip's rests on 1.
#define PATH_OP_MIN 1
int PathInkFind(const string id)
{
   for(int i = 0; i < ArraySize(s_pathInkId); i++)
      if(s_pathInkId[i] == id) return i;
   return -1;
}
int PathInkRow(const string id)
{
   int k = PathInkFind(id);
   if(k >= 0) return k;
   int n = ArraySize(s_pathInkId);
   ArrayResize(s_pathInkId, n + 1);
   ArrayResize(s_pathInkPure, n + 1);
   ArrayResize(s_pathInkOp, n + 1);
   ArrayResize(s_pathLock, n + 1);      // P-UI-138: same length BY CONSTRUCTION
   ArrayResize(s_pathMid, n + 1);       // P-UI-139: ...and so is this one
   s_pathInkId[n] = id;
   s_pathInkPure[n] = clrNONE;
   s_pathInkOp[n] = 100;      // a fresh row is FULL: the birth ink, unblended
   s_pathLock[n] = 0;         // ...and UNLOCKED
   s_pathMid[n] = 0;          // ...and with no midpoint markers
   return n;
}
void PathInkForget(const string id)
{
   int k = PathInkFind(id);
   if(k < 0) return;
   int n = ArraySize(s_pathInkId);
   for(int i = k; i < n - 1; i++)
   {
      s_pathInkId[i] = s_pathInkId[i + 1];
      s_pathInkPure[i] = s_pathInkPure[i + 1];
      s_pathInkOp[i] = s_pathInkOp[i + 1];
      s_pathLock[i] = s_pathLock[i + 1];
      s_pathMid[i] = s_pathMid[i + 1];
   }
   ArrayResize(s_pathInkId, n - 1);
   ArrayResize(s_pathInkPure, n - 1);
   ArrayResize(s_pathInkOp, n - 1);
   ArrayResize(s_pathLock, n - 1);
   ArrayResize(s_pathMid, n - 1);
}
// What the user chose (false = never picked: the segments keep their birth ink).
bool PathInkGet(const string id, color &pure, int &op)
{
   int k = PathInkFind(id);
   if(k < 0) { pure = clrNONE; op = 100; return false; }
   pure = s_pathInkPure[k];
   op = s_pathInkOp[k];
   return ((int)pure >= 0);
}
int PathInkOpacityGet(const string id)
{
   int k = PathInkFind(id);
   return (k < 0 ? 100 : s_pathInkOp[k]);
}
// P-UI-138 (2026-10-02, user: "the strip's lock does not work for the path") — THE
// LOCK IS THE PATH'S, NOT MT4'S. Every other drawing arms `OBJPROP_SELECTABLE`, and
// MT4 then owns its anchors. A path's segments are born NON-selectable on purpose
// (the handles are its own edit surface, and a native anchor would drag ONE segment
// and leave the rest of the polyline behind — two owners for one drawing), so the
// same property flip could only hand MT4 a second drag owner. So the strip's LOCK
// cell arms the path's own flag, and the path's press branch asks it before ANY
// carry starts: locked = the drawing stays, nothing about it moves.
bool PathLockGet(const string id)
{
   int k = PathInkFind(id);
   return (k >= 0 && s_pathLock[k] != 0);
}
void PathLockSet(const string id, const bool on)
{
   int k = PathInkRow(id);
   s_pathLock[k] = (on ? 1 : 0);
   PathWitness("lock id=" + id + " on=" + IntegerToString(s_pathLock[k]));
}
//--- P-UI-139 (2026-10-02, user: "a strip option that shows these 50 %s with a
//--- smaller circle") — THE MIDPOINT MARKERS. The strip's 50 % cell (DRAW_SLOT_BOXHALF,
//--- the box's own mid PRICE line) is the seat that already means "the middle" for
//--- this product, so the path WEARS that cell and answers it in its own terms: one
//--- small circle at each SEGMENT's own middle, in the path's own ink, so the
//--- polyline can be read at a glance where its legs turn.
//--- WHY AN OBJ_OVAL AND NOT A HANDLE: the vertices ride pixels (`HandsetHandleAtXY`),
//--- because a vertex is something the hand GRABS. A midpoint is not grabbable, and
//--- anchoring it in time/price means the terminal re-projects it on every pan and
//--- zoom for free — zero work per tick, which is the whole cost argument.
//--- Naming: `<pfx>_PATH_<id>_M<k>` — the `M` tail is not digits, so `PathIdOfName`
//--- (the orphan walk, the delete watcher) never reads a marker as a segment.
// P-UI-140: the mid marker's disc is declared HERE, beside the code that paints it —
// a `#resource` is a compile-time bind of the unit that paints the raster (P-UI-131's
// two-tree law), and this file is in BOTH builds while DrawStrip_Head is in neither Lite.
#resource "\\Files\\Icons\\path_mid_dot.bmp"
#define PATH_MID_HALF 5     // the disc's CENTRE offset on its 11px canvas (P-LM-19's rule:
                            // the canvas is 11px, so half = outSize/2, not the grab radius)
#define PATH_MID_RES  "::Files\\Icons\\path_mid_dot.bmp"
//--- P-UI-142: the terminal's own drag HEARTBEAT — the window a foreign motion keeps
//--- the path's hands off for. P-UI-130 already measured it: MT4 re-reports a native
//--- drag about every 400 ms, and that heartbeat is the only honest length for "the
//--- hand is busy with the terminal's own drawing".
#define PATH_NO_GRAB_MS 400
string PathMidName(const string id, const int k) { return PathPrefix() + id + "_M" + IntegerToString(k); }
void PathMidDrop(const string id)
{
   int m = PathSegCount(id);
   if(m > 0)   // the parent is whole: the count is exact and this is the cheap pass
   {
      for(int k = 0; k < m; k++) ObjectDelete(0, PathMidName(id, k));
      ObjectDelete(0, PathMidName(id, m));
      return;
   }
   PathChildrenDrop(id, "_M");   // P-PATH-BUG-6: the parent is gone — sweep by name
}
bool PathMidGet(const string id)
{
   int k = PathInkFind(id);
   return (k >= 0 && ArraySize(s_pathMid) > k && s_pathMid[k] != 0);
}
// One marker per segment, at that segment's own (t,p) middle. Bounded by the path's
// segment count and it runs only on a cell press, a drag step and a chart change —
// never on a tick.
// P-PATH-BUG-8 (2026-10-29) — THE DRAG STEP MAY NOT PAY FOR THE WHOLE ROW, AND MAY
// NOT WRITE A FILE. Two things rode every frame of a vertex carry when this toggle
// was on: the loop re-projected EVERY segment's marker (O(n) lookups per frame for
// the two legs that can actually move), and the witness block below — a Print plus
// FileWrite plus FileFlush, in Full — ran once per frame as well. A hand at 60 fps
// was flushing 60 journal lines a second for a diagnostic that is read once.
//   quiet  : the caller is a frame, not a press. No witness.
//   onlyK  : re-seat that ONE marker (-1 = the whole row, the press/chart-change pass).
void PathMidApply(const string id, const bool quiet = false, const int onlyK = -1)
{
   bool on = PathMidGet(id);
   int made = 0;
   int wAx1 = 0, wAy1 = 0, wAx2 = 0, wAy2 = 0, wMx = 0, wMy = 0;   // the first leg, for the witness
   int n = PathSegCount(id);
   for(int k = 0; k < n; k++)
   {
      if(onlyK >= 0 && k != onlyK) continue;   // a carry owns one leg, not the row
      string nm = PathMidName(id, k);
      string seg = PathSegName(id, k);
      if(!on || ObjectFind(0, seg) < 0) { ObjectDelete(0, nm); continue; }
      datetime t1 = (datetime)ObjectGetInteger(0, seg, OBJPROP_TIME, 0);
      double   p1 = ObjectGetDouble(0, seg, OBJPROP_PRICE, 0);
      datetime t2 = (datetime)ObjectGetInteger(0, seg, OBJPROP_TIME, 1);
      double   p2 = ObjectGetDouble(0, seg, OBJPROP_PRICE, 1);
      if(t1 <= 0 || t2 <= 0 || !(p1 > 0) || !(p2 > 0)) { ObjectDelete(0, nm); continue; }
      // P-UI-160b (2026-10-16): the F mute parks the 50% discs. They are
      // BITMAP_LABELs — no TF mask reaches them — so the hide pass and the
      // chart-change channel both come through here; the validity check above
      // still runs (a dead segment still takes its marker with it), a live one
      // parks instead of projecting.
      if(IsIndicatorHidden())
      {
         HandsetHandleAtXY(nm, HANDSET_HANDLE_PARK, HANDSET_HANDLE_PARK, PATH_MID_HALF, PATH_MID_RES);
         continue;
      }
      //--- P-UI-141 (2026-10-02, user: "it came, but it is not in the middle of the
      //--- line") — THE MIDDLE IS A PIXEL FACT, NOT A PRICE ONE. The marker used the
      //--- arithmetic mean of TIME and PRICE and handed it back to the terminal, which
      //--- is only the middle of the drawn line when the terminal's own mapping is
      //--- linear in both; the hand reads the middle of what it SEES, and that is the
      //--- middle of the two projected pixels. So both anchors are projected and the
      //--- marker sits on their average — a projection the product already does for
      //--- every vertex handle, and the same arithmetic the vertex hit test uses.
      //--- Cost: TWO ChartTimePriceToXY per marker (was one), on a press / a drag step /
      //--- a chart change — never on a tick.
      int ax1 = 0, ay1 = 0, ax2 = 0, ay2 = 0;
      if(!ChartTimePriceToXY(0, 0, t1, p1, ax1, ay1) || !ChartTimePriceToXY(0, 0, t2, p2, ax2, ay2))
      {
         HandsetHandleAtXY(nm, HANDSET_HANDLE_PARK, HANDSET_HANDLE_PARK, PATH_MID_HALF, PATH_MID_RES);
         continue;
      }
      int mx = (ax1 + ax2) / 2, my = (ay1 + ay2) / 2;
      if(k == 0) { wAx1 = ax1; wAy1 = ay1; wAx2 = ax2; wAy2 = ay2; wMx = mx; wMy = my; }
      // P-UI-140 (MEASURED `made=6 … sz=0x0 … tf=0`): MT4 gives an OBJ_ELLIPSE its size
      // from its SECOND ANCHOR, so a fixed-PIXEL round marker cannot be a time/price
      // shape — six objects existed and drew nothing. It is a baked 11px disc on a pixel
      // seat instead, placed through the ONE owner of "this raster on this pixel"
      // (`HandsetHandleAtXY`) — the same call the vertex handles use, so a marker and a
      // handle can never disagree about what a seat is.
      HandsetHandleAtXY(nm, mx, my, PATH_MID_HALF, PATH_MID_RES);
      made++;
   }
   //--- P-UI-140 (2026-10-02): THE PASS ANSWERS WITH ITS OWN NUMBERS. The store said
   //--- ON and the chart showed nothing, and the only way to tell "the create was
   //--- refused" from "it exists and the terminal will not draw it" is to read the
   //--- object back in the same breath: how many markers exist, and the FIRST one's
   //--- seat, ink, size and period mask. Cost: one flushed line per PRESS.
   //--- P-PATH-BUG-8: ...per PRESS, and that is now enforced by the caller, not by
   //--- hope — a drag frame passes quiet and writes nothing.
   if(on && !quiet)
   {
      string f = PathMidName(id, 0);
      PathWitness("mid PASS id=" + id + " made=" + IntegerToString(made) +
                  " leg0=" + IntegerToString(wAx1) + "," + IntegerToString(wAy1) +
                  "->" + IntegerToString(wAx2) + "," + IntegerToString(wAy2) +
                  " mid=" + IntegerToString(wMx) + "," + IntegerToString(wMy) +
                  " first=\"" + f + "\" find=" + IntegerToString(ObjectFind(0, f)) +
                  " type=" + IntegerToString((int)ObjectGetInteger(0, f, OBJPROP_TYPE)) +
                  " xy=" + IntegerToString((int)ObjectGetInteger(0, f, OBJPROP_XDISTANCE)) + "," +
                       IntegerToString((int)ObjectGetInteger(0, f, OBJPROP_YDISTANCE)) +
                  " sz=" + IntegerToString((int)ObjectGetInteger(0, f, OBJPROP_XSIZE)) + "x" +
                        IntegerToString((int)ObjectGetInteger(0, f, OBJPROP_YSIZE)) +
                  " bmp=\"" + ObjectGetString(0, f, OBJPROP_BMPFILE, 0) + "\"" +
                  " z=" + IntegerToString((int)ObjectGetInteger(0, f, OBJPROP_ZORDER)) +
                  " tf=" + IntegerToString((int)ObjectGetInteger(0, f, OBJPROP_TIMEFRAMES)));
   }
}
void PathMidSet(const string id, const bool on)
{
   int k = PathInkRow(id);
   s_pathMid[k] = (on ? 1 : 0);
   PathMidApply(id);
   PathWitness("mid id=" + id + " on=" + IntegerToString(s_pathMid[k]));
}
// THE ONE WRITE. A pick and an opacity step both end here, so the two can never
// disagree: the store is updated first, then every sibling wears the blend of the
// ONE blend owner (`BlendColorTowardsBG`, the product's own - a path's fade looks
// exactly like every other drawing's fade).
void PathInkApply(const string id, const color pure, const int op)
{
   int k = PathInkRow(id);
   if((int)pure >= 0) s_pathInkPure[k] = pure;
   int v = op;                          // the same clamp `DrawSlotOpacitySet` does, spelled
   if(v < PATH_OP_MIN) v = PATH_OP_MIN;   // here: Lite compiles this file without `ClampInt`.
   if(v > 100) v = 100;
   s_pathInkOp[k] = v;
   int n = PathSegCount(id);
   if((int)s_pathInkPure[k] >= 0 && n > 0)
   {
      color ink = BlendColorTowardsBG(s_pathInkPure[k], 100 - v, GetCachedChartBgColor());
      for(int i = 0; i < n; i++)
      {
         string sib = PathSegName(id, i);
         if(ObjectFind(0, sib) < 0) continue;
         ObjectSetInteger(0, sib, OBJPROP_COLOR, ink);
      }
   }
   PathWitness("ink id=" + id + " pure=" + IntegerToString((int)s_pathInkPure[k]) +
               " op=" + IntegerToString(v) + " segs=" + IntegerToString(n));
}
// The handles ride every channel the chart moves in (pan/zoom stream included) and
// die with their path — one sweep, HRayFollowAll's shape.
void PathFollowAll()
{
   if(s_pathSel != "") { PathHandleFollow(s_pathSel); if(s_pathSel != "") return; }
   for(int i = ArraySize(s_pathIds) - 1; i >= 0; i--)
   {
      string id = s_pathIds[i];
      if(PathSegCount(id) == 0)
      {
         PathRegDel(id);   // P-UI-146: the sweep is inside — its handles die with it
      }
   }
}

// ── P-UI-160b (2026-10-16) — THE PATH FAMILY ANSWERS THE F MUTE ──────
// Segments are chart-space (mask); vertex handles and the 50% discs are
// BITMAP_LABELs (park, through their own seats' hidden branches). Once per
// transition; the riders (PathHandleAt / PathMidApply) carry the hidden term,
// so the pan stream and the chart-change follower cannot re-place a disc while
// hidden and the show path re-places them through the same seats.
int PathHideAll()
{
   int n = 0;
   for(int i = 0; i < ArraySize(s_pathIds); i++)
   {
      string id = s_pathIds[i];
      int m = PathSegCount(id);
      if(m <= 0) continue;
      for(int k = 0; k < m; k++)
      {
         string nm = PathSegName(id, k);
         if(ObjectFind(0, nm) < 0) continue;
         if((int)ObjectGetInteger(0, nm, OBJPROP_TIMEFRAMES) != OBJ_NO_PERIODS)
            ObjectSetInteger(0, nm, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
      }
      PathMidApply(id);                              // parks (its own hidden branch)
      if(id == s_pathSel) PathHandlesFollowAll(id);  // parks (its own hidden branch)
      n++;
   }
   return n;
}

int PathShowAll()
{
   int n = 0;
   for(int i = 0; i < ArraySize(s_pathIds); i++)
   {
      string id = s_pathIds[i];
      int m = PathSegCount(id);
      if(m <= 0) continue;
      for(int k = 0; k < m; k++)
      {
         string nm = PathSegName(id, k);
         if(ObjectFind(0, nm) < 0) continue;
         if((int)ObjectGetInteger(0, nm, OBJPROP_TIMEFRAMES) != OBJ_ALL_PERIODS)
            ObjectSetInteger(0, nm, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      }
      PathMidApply(id);   // re-places the discs (visible branch)
      n++;
   }
   PathFollowAll();   // re-place the selected path's vertex handles
   return n;
}
// P-PATH-BUG-3 (2026-10-29): RETURNS WHETHER THE SEGMENT REALLY EXISTS. The caller
// used to advance s_pathSegCount unconditionally, so a refused ObjectCreate (a name
// collision after a hard restart) left the session believing in a leg that is not on
// the chart: the commit then registers a path whose last index has no object, the
// tooltip pass writes into nothing, and PathSegCount — which WALKS the objects —
// disagrees with the session for the rest of its life.
bool PathMakeSegment(const string id, const int idx, const datetime t1, const double p1, const datetime t2, const double p2)
{
   string nm = PathSegName(id, idx);
   if(ObjectCreate(0, nm, OBJ_TREND, 0, t1, p1, t2, p2))
   {
      ObjectSetInteger(0, nm, OBJPROP_COLOR, PATH_COLOR);
      ObjectSetInteger(0, nm, OBJPROP_STYLE, PATH_STYLE);
      ObjectSetInteger(0, nm, OBJPROP_WIDTH, PATH_WIDTH);
      ObjectSetInteger(0, nm, OBJPROP_RAY_LEFT, false);
      ObjectSetInteger(0, nm, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nm, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, nm, OBJPROP_BACK, false);
      ObjectSetInteger(0, nm, OBJPROP_ZORDER, Z_BOX_RAY);
      ObjectSetString(0, nm, OBJPROP_TOOLTIP, PathTooltip(idx + 1));
      return true;
   }
   return false;
}
void PathCommitVertex(const datetime t, const double p)
{
   if(s_pathSessionId == "")
   {
      for(int a = 0; a < 5; a++)
      {
         s_pathSessionId = IntegerToString((long)GetTickCount()) + IntegerToString(MathRand());
         if(ObjectFind(0, PathSegName(s_pathSessionId, 0)) < 0) break;
         s_pathSessionId = "";
      }
      if(s_pathSessionId == "") return;
   }
   if(s_pathAnchorT > 0 && s_pathAnchorP > 0)
   {
      //--- the count is the OBJECT SET's, not the click's (see PathMakeSegment)
      if(PathMakeSegment(s_pathSessionId, s_pathSegCount, s_pathAnchorT, s_pathAnchorP, t, p))
         s_pathSegCount++;
   }
   s_pathAnchorT = t;
   s_pathAnchorP = p;
   s_pathPrevMs = 0;   // P-PERF-168: the rubber band re-anchors on the very next move
}
void PathFinish()
{
   string id = s_pathSessionId;
   int segs = s_pathSegCount;
   ObjectDelete(0, PathPreviewName());
   s_pathPrevLive = false;   // P-PERF-168: the memo dies with the object
   s_pathPend = false;
   //--- P-PATH-CANVAS: the commit ends the arm, so the band's pixels must go too.
   //--- P-PATH-CANVAS-3 (2026-10-29): AND THEY MUST GO NOW, NOT ON THE NEXT FRAME.
   //--- This pair used to be DirtyFront() alone — a version bump with no paint — so
   //--- the dotted band's last frame stayed on the FRONT layer until some unrelated
   //--- event happened to repaint it. On the finished drawing that is a dotted line
   //--- lying exactly on top of the solid one the commit just made: «بعضی وقتا دوتا
   //--- خط میشه». PathCancel already painted here; the commit did not.
   s_pathCursorOk = false;
#ifdef BIOTAK_RENDER_ENGINE
   REngineExtTimeContent(false);
   REngineDirtyFront();
   REnginePaint();   // wipe the band off the layer the commit is about to share
#endif
   if(id != "" && segs >= 1)
   {
      PathRegAdd(id);
      PathWitness("commit segs=" + IntegerToString(segs) + " id=" + id);
      for(int i = 0; i < segs; i++)
         ObjectSetString(0, PathSegName(id, i), OBJPROP_TOOLTIP, PathTooltip(segs));
   }
   else if(id != "")
   {
      for(int i = 0; i < segs; i++) ObjectDelete(0, PathSegName(id, i));
   }
   s_pathAnchorT = 0; s_pathAnchorP = 0;
   s_pathSegCount = 0;
   s_pathSessionId = "";
   s_pathLastVerMs = 0;
   s_pathArmed = false;
   ChartViewLockRelease();   // the arm's acquire ends with the commit
   ChartRedraw();
}
void PathDragRelease()
{
   if(s_pathDrag == "") return;
   s_pathDrag = "";
   s_pathDragV = -1;
   ChartViewLockRelease();
}
// ONE snap store, three gestures. `ix` says which anchor each snapshotted segment
// moves, so the whole-path carry (ix=2 everywhere) and a single-vertex edit (one
// or two segments, ix=0/1) share the same apply, the same restore and the same
// press bookkeeping — a second drag path would be a second geometry.
void PathSnapAdd(const string nm, const int ix)
{
   if(ObjectFind(0, nm) < 0) return;
   int k = ArraySize(s_pathSnapNames);
   ArrayResize(s_pathSnapNames, k + 1);
   ArrayResize(s_pathSnapIx, k + 1);
   ArrayResize(s_pathSnapT0, k + 1);
   ArrayResize(s_pathSnapP0, k + 1);
   ArrayResize(s_pathSnapT1, k + 1);
   ArrayResize(s_pathSnapP1, k + 1);
   s_pathSnapNames[k] = nm;
   s_pathSnapIx[k] = ix;
   s_pathSnapT0[k] = (datetime)ObjectGetInteger(0, nm, OBJPROP_TIME, 0);
   s_pathSnapP0[k] = ObjectGetDouble(0, nm, OBJPROP_PRICE, 0);
   s_pathSnapT1[k] = (datetime)ObjectGetInteger(0, nm, OBJPROP_TIME, 1);
   s_pathSnapP1[k] = ObjectGetDouble(0, nm, OBJPROP_PRICE, 1);
}
// P-UI-145: the whole-path carry is RETIRED with the body press that used to start it
// (a body press selects and nothing more). Its snap store is still the one a vertex carry
// uses — PathVertDragStart below — so the geometry half of this code lives on; only the
// entry point is gone, and the whole-path DRAG was never reachable from the strip.
// P-UI-136: A HANDLE DRAG EDITS ONE POINT. Vertex k lives in segment k's anchor 0
// (and in segment k-1's point 1 when it is a shared vertex) — so the snap store
// holds one segment at the ends and two in the middle, and nothing else on the
// path can move.
void PathVertDragStart(const string id, const int k)
{
   s_pathDrag = id;
   s_pathDragV = k;         // P-PERF-166: a dot carry owns three dots, not the whole row
   s_pathMoved = false;
   s_pathPrimed = false;    // P-UI-142: same rule for a single-point edit
   PathSelect(id);
   PathHandleFollow(id);
   ArrayResize(s_pathSnapNames, 0);
   int n = PathSegCount(id);
   if(k > 0) PathSnapAdd(PathSegName(id, k - 1), 1);
   if(k < n) PathSnapAdd(PathSegName(id, k), 0);
   ChartViewLockAcquire();
   s_pathDragMs = 0;    // P-PERF-168: the first move of a carry is never deferred
   s_pathDragPend = false;
   PathWitness("drag start id=" + id + " vertex=" + IntegerToString(k));
}
// P-PERF-169 (2026-10-29) — THE CARRY MOVES A HANDLE, IT DOES NOT INTERROGATE IT.
// HandsetHandleAtXY is written for every caller in the product, so it re-asks three
// questions a vertex carry already knows the answers to: "is this the right bitmap"
// (a BMPFILE read), "is it at X", "is it at Y" (two more reads, only to avoid a
// write that a MOVING handle always needs). Two of those three reads are round-trips
// into the terminal, and ObjectFind/ObjectGet cost grows with the object count — on
// this chart (hundreds of objects) the ride measured `[mvus] hs=9..62 ms`.
// A carry knows the bitmap (it never changes mid-gesture) and the position (it is
// about to be written), so it writes the two distances and asks nothing.
void PathHandleCarry(const string id, const int k)
{
   string hn = PathHandleName(id, k);
   if(ObjectFind(0, hn) < 0) { PathHandleAt(id, k); return; }   // a birth keeps the full dress
   //--- the F mute can land mid-carry; a parked row is the answer then too
   if(IsIndicatorHidden()) { ObjectSetInteger(0, hn, OBJPROP_XDISTANCE, HANDSET_HANDLE_PARK); return; }
   datetime t = 0; double p = 0.0;
   if(!PathVertex(id, k, t, p)) return;
   int x = 0, y = 0;
   if(!(p > 0) || !ChartTimePriceToXY(0, 0, t, p, x, y))
   {
      ObjectSetInteger(0, hn, OBJPROP_XDISTANCE, HANDSET_HANDLE_PARK);
      return;
   }
   ObjectSetInteger(0, hn, OBJPROP_XDISTANCE, x - CP_HANDLE_HALF);
   ObjectSetInteger(0, hn, OBJPROP_YDISTANCE, y - CP_HANDLE_HALF);
}
void PathDragApply(const datetime curT, const double curP)
{
   long dt = (long)(curT - s_pathSnapT);
   double dp = curP - s_pathSnapP;
   for(int i = 0; i < ArraySize(s_pathSnapNames); i++)
   {
      if(ObjectFind(0, s_pathSnapNames[i]) < 0) continue;
      int ix = s_pathSnapIx[i];
      if(ix != 1) ObjectMove(0, s_pathSnapNames[i], 0, s_pathSnapT0[i] + dt, s_pathSnapP0[i] + dp);
      if(ix != 0) ObjectMove(0, s_pathSnapNames[i], 1, s_pathSnapT1[i] + dt, s_pathSnapP1[i] + dp);
   }
   //--- P-PERF-166 (2026-10-29) — A DOT CARRY MOVES THREE DOTS, NOT THE WHOLE ROW.
   //--- P-PERF-169: AND OF THOSE THREE, ONLY ONE ACTUALLY MOVES. Vertex V lives in
   //--- segment V-1's point 1 and segment V's point 0; vertices V-1 and V+1 are the
   //--- far ends of those same two segments and are not touched by the carry. The
   //--- ±1 window re-seated two dots that were already exactly where they belong —
   //--- and PathVertDragStart's own PathHandleFollow had just placed them. One dot
   //--- per frame now, on the fast writer.
   if(s_pathDragV >= 0) PathHandleCarry(s_pathDrag, s_pathDragV);
   else PathHandleFollow(s_pathDrag);   // a whole-path carry still moves the row
   // P-UI-139: the 50 % markers ride it too — and only when the switch is on, so the
   // default path pays ONE array read per drag step and not one object write.
   // P-PATH-BUG-8: and when the switch IS on, a carry re-seats the two legs its vertex
   // owns and writes no witness — a frame is not a press.
   if(PathMidGet(s_pathDrag))
   {
      if(s_pathDragV >= 0)
      {
         //--- vertex V owns segment V-1's point 1 and segment V's point 0. V=0 has no
         //--- V-1 — and onlyK=-1 means "the whole row", so the guard is not optional.
         if(s_pathDragV > 0) PathMidApply(s_pathDrag, true, s_pathDragV - 1);
         PathMidApply(s_pathDrag, true, s_pathDragV);
      }
      else PathMidApply(s_pathDrag, true);
   }
}
// P-PERF-168 — THE CARRY PAYS THE SAME 16 ms BUDGET. A dot carry writes up to
// four anchors plus three handle seats per move; at 100..125 events/s that is the
// same whole-chart bill the rubber band was paying, and the hand cannot read more
// than 60 of those frames anyway.
void PathDragApplyFrame(const datetime curT, const double curP)
{
   s_pathPendT = curT; s_pathPendP = curP; s_pathDragPend = true;
   uint now = GetTickCount();
   if(s_pathDragMs != 0 && (uint)(now - s_pathDragMs) < PATH_FRAME_MS) return;
   s_pathDragMs = now;
   s_pathDragPend = false;
   PathDragApply(s_pathPendT, s_pathPendP);
}
void PathDragFlush()
{
   if(!s_pathDragPend) return;
   s_pathDragPend = false;
   PathDragApply(s_pathPendT, s_pathPendP);
}
void PathDragRestore()
{
   //--- P-PERF-168: a restore means the hand's buffered sample is void — it must
   //--- not be flushed after the geometry has been put back where the press found it.
   s_pathDragPend = false;
   for(int i = 0; i < ArraySize(s_pathSnapNames); i++)
   {
      if(ObjectFind(0, s_pathSnapNames[i]) < 0) continue;
      int ix = s_pathSnapIx[i];
      if(ix != 1) ObjectMove(0, s_pathSnapNames[i], 0, s_pathSnapT0[i], s_pathSnapP0[i]);
      if(ix != 0) ObjectMove(0, s_pathSnapNames[i], 1, s_pathSnapT1[i], s_pathSnapP1[i]);
   }
   PathHandleFollow(s_pathDrag);
}
void PathDragEnd()
{
   if(s_pathDrag == "") return;
   //--- P-PERF-168: THE RELEASE OWNS THE LAST SAMPLE. A frame the budget dropped
   //--- is written here before the carry closes, so the committed geometry is the
   //--- cursor's last position and never the one before it.
   PathDragFlush();
   //--- P-PERF-169: THE RELEASE REPAIRS THE ROW. The carry seats ONE dot per frame
   //--- (the only one that moves), so this is the pass that re-seats the rest and
   //--- makes the finished geometry pixel-true — the job the older comment credited
   //--- to "PathDragEnd -> PathDragRestore -> PathHandleFollow", which only runs on a
   //--- FOREIGN drag. One whole row per gesture, never per frame.
   PathHandleFollow(s_pathDrag);
   PathWitness("drag end id=" + s_pathDrag + " moved=" + (s_pathMoved ? "yes" : "no"));
   if(s_pathMoved) s_pathEndMs = GetTickCount();
   s_pathPrimed = false;
   PathDragRelease();
   ChartRedraw();
}
bool PathOnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   string pfx = PathPrefix();
   //--- P-PERF-168: a sample the frame budget deferred is painted by the NEXT
   //--- event of any kind (a click, a key, a chart change) — so the rubber band is
   //--- never more than one frame behind the cursor when the hand comes to rest.
   if(id != CHARTEVENT_MOUSE_MOVE && s_pathPend) PathPreviewFlush();
   //--- P-UI-142 (2026-10-02, user: "from that same point I want to draw a trend line
   //--- and THIS one moves too") — THE TERMINAL'S OWN MOTION IS NOT OURS. A press that
   //--- lands on a path is ambiguous: it may be the hand taking the path, or the hand
   //--- STARTING a native drawing (a trend line, a ray, a fib) from that very pixel. The
   //--- indicator cannot ask which — but MT4 answers the second one a moment later, in
   //--- its own voice: `CHARTEVENT_OBJECT_DRAG` on an object that is NOT ours. That is
   //--- P-UI-130 law 3 applied one level up (the hold's own rule: a gesture IN MOTION is
   //--- never ours), so a foreign drag (a) puts a live carry back exactly where the
   //--- press found it, and (b) FORBIDS the next grab for the heartbeat that follows
   //--- (400 ms, the terminal's own drag rate) so the path cannot be re-grabbed out
   //--- from under the stroke still in progress. Two comparisons per drag event and one
   //--- deadline read per press; our own segments never emit this event (they are born
   //--- non-selectable), so the path cannot forbid itself.
   if(id == CHARTEVENT_OBJECT_DRAG)
   {
      if(pfx != "" && StringFind(sparam, pfx) == 0) return false;   // our own geometry is never dragged
      //--- P-UI-142: the terminal's voice, answered by the SHARED arbiter (its one
      //--- writer is the router) — and the path's own two lines: a live carry goes
      //--- back exactly where the press found it, and the next grab is the arbiter's
      //--- to refuse. Geometry is ours; the DECISION is the project's.
      if(s_pathDrag != "")
      {
         PathWitness("foreign drag \"" + sparam + "\" put the path back");
         PathDragRestore();
         PathDragEnd();
      }
      return false;
   }
   if(id == CHARTEVENT_OBJECT_DELETE && pfx != "" && StringFind(sparam, pfx) == 0)
   {
      if(s_pathDeleting) return false;
      if(g_suppressDeleteEvents || TickDeadlinePending(g_suppressDeleteEventsUntilMs)) return false;
      string pid;
      if(PathIdOfName(sparam, pid))
      {
         // P-PERF-168b: a segment just died — this path's count is re-walked once
         // (the chart TOTAL may not have moved if something else was born in the
         // same instant, and the "is the path gone" question below must be exact).
         PathSegMemoDrop(pid);
         // P-MT5-PARITY (2026-10-21) - PARITY (MT4 PathTool.mqh:907-924): A NATIVE DELETE OF ONE SEGMENT
         // TAKES THAT SEGMENT, NOT THE WHOLE PATH. MT5's P-DEL-ATOMIC swept the
         // entire path (segments + vertex handles + the ink row + the 50 %
         // markers) instead, so deleting one leg from the terminal's own object
         // list destroyed a drawing the user had not touched. The strip bin is
         // the door that takes a whole path (P-UI-136) and it still does.
         if(PathSegCount(pid) == 0)
         {
            PathRegDel(pid);      // the handle family (P-UI-146's one sweep)
            //--- P-PATH-BUG-7 (2026-10-29): AND THE STATE THAT OUTLIVED IT. A path
            //--- that dies through the terminal's own object list never passes through
            //--- PathDelete, so its ink row and its 50 % discs were left behind — the
            //--- discs as OBJECTS ON THE CHART (a dot with no line under it), the ink
            //--- row as a leak that a later path with the same id would inherit.
            PathInkForget(pid);
            PathMidDrop(pid);
         }
         if(s_pathDrag == pid) PathDragRelease();
         // The handles follow their path: a segment gone RE-PLACES the vertex set,
         // and the last one gone takes the whole family with it (one sweep).
         if(s_pathSel == pid)
         {
            if(PathSegCount(pid) <= 0) { PathHandlesDrop(pid); s_pathSel = ""; }
            else PathHandleFollow(pid);
         }
      }
      return false;
   }
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      PathSegMemoReset();   // P-PERF-168b: the one channel that can hide a net-zero swap
      PathAdoptOrphans();
      PathFollowAll();
      // P-UI-139: a chart change re-projects the 50 % markers for free (they are
      // time/price objects) — but only the paths that ASKED for them are walked.
      for(int i = 0; i < ArraySize(s_pathIds); i++)
         if(PathMidGet(s_pathIds[i])) PathMidApply(s_pathIds[i]);
      return false;
   }
   if(id == CHARTEVENT_KEYDOWN && lparam == 27)
   {
      if(s_pathDrag != "") { PathDragRestore(); PathDragEnd(); return true; }
      if(s_pathArmed) { PathSessionClear(); PathCancel(); return true; }
      return false;
   }
   if(id == CHARTEVENT_MOUSE_MOVE)
   {
      int st = (int)StringToInteger(sparam);
      bool leftDown = ((st & 1) != 0);
      bool rightDown = ((st & 2) != 0);
      bool pressed = (leftDown && !s_pathLeft);
      s_pathLeft = leftDown;
      s_pathShift = ((st & 4) != 0);   // P-PATH-END: the click reads this, not sparam
      //--- P-UI-145: there is no lock state in this file. The arbiter owns ONE stamp that expires
      //--- by itself (GlobalVariables.mqh), and the structural half is right here: a press on
      //--- the BODY selects and never carries, so a native stroke's press can start nothing;
      //--- the DOTS are the only carry in this tool, and they are painted only for the
      //--- selected path (PathHandleAt), so a visible dot means the hand chose this drawing.
      if(s_pathDrag != "")
      {
         if(rightDown) { PathDragRestore(); PathDragEnd(); return true; }
         //--- P-UI-143 (2026-10-02, MEASURED AND RETIRED IN THE SAME BREATH): a rule was
         //--- written here that read the button bit as «whose hand is this» — it looked
         //--- proven, and it was not. The census shows the bit FLAPPING mid-press, at one
         //--- and the same pixel: `nm="1"` then `nm="0"` then `nm="1"`, the cursor never
         //--- moving. That is the terminal's own object machinery reporting its button
         //--- state unreliably (P-LM-13 measured it years ago on the leg carry), so the
         //--- bit is NOT an owner — and a rule built on it killed our OWN carry. What the
         //--- same run measured is the finding that matters: MT4 is silent for the whole
         //--- of a native stroke and speaks ONCE at its end, so nothing can be decided
         //--- in flight. The owner has to be the terminal itself — which means the
         //--- segments become SELECTABLE and its anchors move the geometry (P-UI-144).
         if(!leftDown) { PathDragEnd(); return true; }
         ChartViewLockAssert();
         int sw = 0; datetime ct = 0; double cp = 0;
         if(ChartXYToTimePrice(0, (int)lparam, (int)dparam, sw, ct, cp) && sw == 0 && ct > 0 && cp > 0)
         {
            if(!s_pathMoved &&
               (MathAbs((int)lparam - s_pathPressX) > 2 || MathAbs((int)dparam - s_pathPressY) > 2))
               s_pathMoved = true;
            //--- P-UI-142: THE FIRST MOVE IS BUFFERED, NEVER WRITTEN. A press on a path
            //--- pixel cannot be told apart from the START of a native drawing, and the
            //--- terminal's own answer (OBJECT_DRAG on a foreign object) arrives with
            //--- that first move. Holding the first sample back means a native stroke
            //--- kills the carry BEFORE this drawing has written a single anchor — the
            //--- path never moves at all, not even for one frame. A real carry pays one
            //--- move of latency (~16 ms) and nothing else. Cost: two scalars.
            if(!s_pathMoved) { s_pathPrimed = false; return true; }
            if(!s_pathPrimed)
            {
               s_pathPrimed = true;
               s_pathPrimT = ct; s_pathPrimP = cp;
               return true;
            }
            PathDragApplyFrame(ct, cp);   // P-PERF-168: the carry rides the same budget
         }
         return true;
      }
      if(s_pathArmed)
      {
         if(rightDown) { PathSessionClear(); PathCancel(); return true; }
         //--- P-PATH-END: SHIFT+PRESS IS THE END, ON THE CHANNEL THAT ALWAYS ARRIVES.
         //--- The move stream is the one place the modifier is reported (CLICK's sparam
         //--- carries coordinates only), and a press edge is a real down transition, so
         //--- this cannot fire on a hover: one deliberate press ends the session. The
         //--- double-click finish below stays as the MT4 gesture.
         if(s_pathShift && pressed)
         {
            if(s_pathSegCount >= 1) PathFinish();
            else { PathSessionClear(); PathCancel(); }
            s_pathSwallowClick = true;
            return true;
         }
         int sw = 0; datetime ct = 0; double cp = 0;
         if(ChartXYToTimePrice(0, (int)lparam, (int)dparam, sw, ct, cp) && sw == 0 && ct > 0 && cp > 0)
            PathPreviewFrame(ct, cp);   // P-PERF-168: 60 fps, not one frame per event
         return false;
      }
      //--- P-UI-144 (2026-10-02): THE HAND IS OURS TO GIVE. Three measurements closed the
//--- detection road (no "native tool armed" flag; the terminal is silent for the whole
//--- of a native stroke and speaks once at its end; its button bit flaps mid-press), so
//--- the owner is DECIDED by one shared question instead of guessed at: a drawing that
//--- is not already TAKEN cannot be taken. The press that takes it for the first time
//--- SELECTS it and writes no anchor, so a trend line started on a path point leaves the
//--- path exactly where it was. The question lives in the arbiter (GlobalVariables.mqh)
//--- so this file and the ray cannot drift into two different rules.
if(pressed && pfx != "")
      {
         if(UIPointerOverSurface((int)lparam, (int)dparam)) return false;
         //--- P-UI-145: THE ORDER IS THE RULE. The DOT is asked FIRST and it carries on one
         //--- press; the foreign-drag lock is asked after it, so a terminal that is still
         //--- finishing its own stroke cannot eat the one gesture a visible handle owes the
         //--- user (that ordering is why a painted dot could not be dragged: the lock was
         //--- asked first and the 400 ms window after every native stroke swallowed it).
         int sw = 0; datetime ct = 0; double cp = 0;
         bool tp = ChartXYToTimePrice(0, (int)lparam, (int)dparam, sw, ct, cp);
         s_pathPressX = (int)lparam; s_pathPressY = (int)dparam;
         if(tp) { s_pathSnapT = ct; s_pathSnapP = cp; }
         // A HANDLE FIRST: the handles sit ON the path, so without this the whole
         // -path carry would swallow the press and a point could never be edited.
         string hid = ""; int hk = -1;
         if(PathDotHit((int)lparam, (int)dparam, hid, hk))
         {
            // P-UI-144: THE LOCK AND THE TAKE ARE TWO QUESTIONS. Folding them into one
            // branch let a press on a LOCKED path write the take, so the locked path was
            // silently "given" to the next gesture and never answered with its own witness.
            if(PathLockGet(hid))
            {
               PathWitness("press refused: locked id=" + hid);
               return true;
            }
            //--- P-UI-145 (2026-10-02, user: «نقاطشو نمیشه جابجا کرد، باید ترکیبی بشه»):
            //--- THE DOT IS THE HANDLE, and a handle needs no second gesture. The dot is
            //--- painted ONLY for the selected path (PathHandleAt: an unselected chart wears
            //--- no circles), so a visible dot already means the hand chose this drawing —
            //--- the take gate that guarded the BODY is not repeated here, because the one
            //--- press a native tool makes on a line can never reach this branch: a line
            //--- press selects and stops (below), and only a DOT carries.
            PathVertDragStart(hid, hk);
            PathWitness("carry the dot of id=" + hid + " v=" + IntegerToString(hk) + " why=" + GestureTakeWhy());
            return true;
         }
         //--- …and only now the lock, which is the terminal's own voice and guards the BODY:
         //--- a foreign drag that is still finishing must not start a new grab either.
         if(PathGrabBlocked())
         {
            PathWitness("press refused: the terminal is still dragging one of ours, why=" + GestureTakeWhy());
            return false;
         }
         string pid = "";
         if(PathPressHit((int)lparam, (int)dparam, pid))
         {
            //--- P-UI-145 (2026-10-02, user: «فقط رأس‌ها، بدنه آزاد»): THE BODY IS FREE.
            //--- A press on a segment SELECTS and nothing else — it never latches a carry.
            //--- This is the structural answer, not a detection: MEASURED, a native stroke
            //--- reports button=0 on all ~40 of its moves and speaks once at its end, so NO
            //--- press-time question can tell it from a carry of ours, and every lock built
            //--- on that question left the drawing free to walk away (four `drag start … why=carry:
            //--- it was taken` in a row, then `moved=yes`). A body that cannot carry cannot be
            //--- carried away by anything: the chart is free for the terminal's own tools.
            //--- A path is moved by its VERTICES (the branch above), which answer only while
            //--- the path is selected — so the hand is on a dot, not on a line.
            if(PathLockGet(pid)) { PathWitness("press refused: locked id=" + pid); return true; }
            PathWitness("press on the BODY of id=" + pid + " — select only, never a carry");
            PathSelect(pid); PathHandleFollow(pid); GestureTakeNote(pid);
            return true;
         }
         //--- P-UI-145: THE PRESS THAT FOUND NEITHER A DOT NOR A BODY is the one silence a
         //--- hit test must never keep: the log used to read «select … select …» and a user
         //--- pressing a visible dot learned nothing from it. It names the selection, the
         //--- dots it owns and the lock, on the press edge only.
         //--- P-PERF-57 (2026-10-23) - AND IT IS ONLY A PATH'S QUESTION. This handler runs
         //--- on EVERY press anywhere on the chart (it is first in the chain), so on a chart
         //--- with no path at all the line can only report the one thing that is already
         //--- known: there was nothing to hit. MEASURED 2026-10-23: 1121 of these in a day,
         //--- nearly all of them from presses that were meant for a box or the chart - and
         //--- each one is a Print + FileWrite + FileFlush ON THE PRESS EDGE, i.e. at the
         //--- start of every drag. With no path in the registry the witness is silent, and
         //--- the first path ever drawn brings it back - the same income, none of the cost
         //--- (`sel=`/`dots=0` is what a chart with no path would have printed anyway).
         if(ArraySize(s_pathIds) > 0)
            PathWitness("press found neither dot nor body: sel=" + s_pathSel
                        + " dots=" + IntegerToString(PathSegCount(s_pathSel))
                        + " at " + IntegerToString((int)lparam) + "," + IntegerToString((int)dparam)
                        + " why=" + GestureTakeWhy());
      }
      return false;
   }
   //--- MT5-ONLY P-MT5-TWIN (2026-10-29): ONE CLICK, TWO CHANNELS, AND THE PLATE
   //--- SAT ON THE FIRST ONE. MT4 delivers a click on one of our objects as the
   //--- chart click alone; MT5 reports it TWICE, OBJECT_CLICK first and then
   //--- CHART_CLICK (the `[dsclick] DEDUPE dropped CHART_CLICK` line is that
   //--- duplicate being spent). The strip's OBJECT_CLICK door runs before the
   //--- CHART_CLICK branch below, so a vertex click opened the settings plate and
   //--- painted 62..78 ms of objects UNDER the cursor — the lag the user reports
   //--- AND the reason the drawing cannot be finished (the plate swallows the
   //--- next click, so the finishing double-click never lands). While the tool is
   //--- armed it owns every gesture (the BaseKnot law), so this duplicate of its
   //--- own family is spent here, before any other module reads it.
   if(id == CHARTEVENT_OBJECT_CLICK && s_pathArmed && pfx != "" && StringFind(sparam, pfx) == 0)
      return true;
   //--- P-PATH-BUG-5 (2026-10-29): the branch that stood here tested
   //--- `StringFind(sparam,"r") >= 0` — a "right click" that MT5 never reports on
   //--- CHARTEVENT_CLICK (its sparam is empty; the button bits arrive on MOUSE_MOVE).
   //--- It was dead, and it was one string away from being lethal: any sparam that
   //--- happened to contain an 'r' would have CANCELED an armed path mid-draw.
   //--- Right-click is already handled where the button really is, in the move
   //--- stream above. Removed rather than kept "just in case".
   if(id == CHARTEVENT_CLICK)
   {
      if(s_pathDrag != "") PathDragEnd();
      if(s_pathSwallowClick) { s_pathSwallowClick = false; return true; }   // P-PATH-END: the shift-end's own release
      if(s_pathArmed)
      {
         if(UIPointerOverSurface((int)lparam, (int)dparam)) return true;
         //--- P-PATH-END (2026-10-29, user: «چی هم شیفت کلیک میکنم تمام نمیشه و
         //--- قطع نمیشه ابزار path»): SHIFT+CLICK IS THE DELIBERATE END. The
         //--- double-click below stays (it is the MT4 gesture and it works again now
         //--- that the strip no longer paints over the cursor), but a hand that has
         //--- finished a shape should not have to aim a double-click at one pixel to
         //--- stop the tool: shift is a modifier the terminal already reports, it can
         //--- never be a stray chart click, and one press ends the session either way
         //--- (a shape commits, an empty session just cancels).
         if(s_pathShift)
         {
            if(s_pathSegCount >= 1) PathFinish();
            else { PathSessionClear(); PathCancel(); }
            return true;
         }
         int sw = 0; datetime ct = 0; double cp = 0;
         if(ChartXYToTimePrice(0, (int)lparam, (int)dparam, sw, ct, cp) && sw == 0 && ct > 0 && cp > 0)
         {
            uint now = GetTickCount();
            if(s_pathLastVerMs != 0 && now - s_pathLastVerMs <= PATH_DBL_MS &&
               MathAbs((int)lparam - s_pathLastVerX) <= PATH_DBL_PX &&
               MathAbs((int)dparam - s_pathLastVerY) <= PATH_DBL_PX &&
               s_pathSegCount >= 1)
            {
               PathFinish();
               return true;
            }
            PathCommitVertex(ct, cp);
            s_pathLastVerMs = now;
            s_pathLastVerX = (int)lparam;
            s_pathLastVerY = (int)dparam;
         }
         return true;
      }
      // P-UI-136 (2026-10-02, user: "after the double-click that finishes the draw,
      // I select and move it and every point of it is deleted") — ONE PIXEL, TWO
      // GESTURES. The segment used to host BOTH the carry and the double-click
      // delete, so the finishing double-click's OWN release click armed the delete
      // witness (the arm is disarmed by then, so the arm-less branch answers it),
      // and the hand's very next press — the "select it" tap — was the witness's
      // second half: the path died instead of moving. An armed flag outliving its
      // own gesture is P-UI-130 law 1, and no timing rule fixes it: two still
      // presses in 400 ms are a double-click AND a select-then-move.
      // So the delete moved to the VERTEX HANDLES (HRay parity: HRayDotHit/
      // HRaySelect): a segment press can now only ever mean "select + carry", a
      // handle press "edit this point", and no release click arms anything.
      string did = ""; int hk = -1;
      if(pfx != "" && PathDotHit((int)lparam, (int)dparam, did, hk))
      {
         //--- P-UI-142: a release that trails the terminal's own motion selects and
         //--- arms NOTHING — the hand was busy drawing something else, and a witness
         //--- armed here is the second half of a delete the user never asked for.
         if(PathGrabBlocked()) return true;
         //--- P-UI-146 (2026-10-02, user: «بعضی وقتا خودکار ابزار path حذف میشه چرا»): THE
         //--- DOUBLE-CLICK DELETE IS RETIRED. It was the only route that could delete a path
         //--- with no intent behind it, and the terminal's own button bit FLAPS at a still
         //--- pixel — MEASURED by the census (`nm="1"` → `"0"` → `"1"`, cursor fixed, ~100 ms
         //--- apart), all of it inside PATH_DBL_MS=400 and PATH_DBL_PX=6 of the first click.
         //--- So ONE press could arm and fire the delete and the path vanished «خودکار», with
         //--- no line in the log to explain it. No timing rule separates the two: a real
         //--- double-click is also two still presses. So the delete is not a gesture here at
         //--- all — the strip's bin is its one owner (`why=strip bin`, DrawStrip_Tap.mqh),
         //--- which is the only place a deletion is a CHOICE rather than an accident.
         PathSelect(did); PathHandleFollow(did);
         PathWitness("handle click id=" + did + " v=" + IntegerToString(hk)
                     + " — select only; delete lives in the strip's bin");
         s_pathClick = "";   // P-UI-146: nothing arms a delete on the chart any more
         return true;
      }
      // A segment release: the press already selected and started the carry, or a
      // still press only got here — either way the dot is the answer, and the click
      // ARMS NOTHING.
      string pid = "";
      if(pfx != "" && PathPressHit((int)lparam, (int)dparam, pid))
      {
         // P-UI-138: locked = no handles, no witness, nothing to arm. A still press on
         // a locked path is a no-op that the strip's own hold still owns (the hold is
         // polled from the cursor, not from this event).
         if(PathLockGet(pid)) { PathWitness("click refused: locked id=" + pid); s_pathClick = ""; return true; }
         PathSelect(pid); PathHandleFollow(pid);
         PathWitness("select id=" + pid + " segs=" + IntegerToString(PathSegCount(pid)));
         s_pathClick = "";
         return true;
      }
      // P-UI-140 (2026-10-02, measured: a tap on the strip's own cell emitted
      // `[Path] dismiss id=…` right after `[drawstrip] SLOT slot=9 …`) — A CLICK ON
      // A UI SURFACE IS THE UI'S. The terminal reports every press as a chart click
      // with coordinates, so a tap on a strip cell landed here, hit no path (the strip
      // is over the chart), and DROPPED the selection the user had just made — the
      // «میزنم هم سلکت میپره» report. The armed branch already asks
      // `UIPointerOverSurface`; the dismiss branch did not, and a selection is worth
      // more than the dismiss gesture it was protecting.
      if(UIPointerOverSurface((int)lparam, (int)dparam)) return true;
      if(s_pathSel != "")
      {
         PathWitness("dismiss id=" + s_pathSel);
         PathSelect("");
      }
      s_pathClick = "";
      return false;
   }
   return false;
}
void PathHandlesWipe()
{
   for(int i = 0; i < ArraySize(s_pathIds); i++)
      PathHandlesDrop(s_pathIds[i]);
}
void PathOnInit()
{
   s_pathArmed = false;
   s_pathDrag = "";
   s_pathClick = "";
   s_pathPrevLive = false;   // P-PERF-168: a new attach owns no rubber band yet
   s_pathPend = false;
   s_pathDragPend = false;
   s_pathSel = "";      // a fresh attach owns no selection: the dot is drawn, not adopted
   PathSegMemoReset();  // P-PERF-168b: a new attach inherits no count from the last one
   PathSweepUnfinished();    // P-PATH-END c: a hard restart's half-drawn session is not a path
   PathAdoptOrphans(true);   // P-PERF-157b: the attach moment always walks
   PathHandlesWipe();
   //--- P-PATH-CANVAS (2026-10-29): the rubber band's painter joins the engine's
   //--- FRONT layer. Mounted once per attach; the flag below lets the deinit
   //--- unmount only what it mounted (the pointer has exactly one owner at a time).
#ifdef BIOTAK_RENDER_ENGINE
   g_rPaintHook = &s_pathRubberHook;
   s_pathHookMounted = true;
   REngineExtTimeContent(false);
#endif
   s_pathCursorOk = false;
}
void PathOnDeinit(const int reason)
{
   if(s_pathDrag != "") PathDragRelease();
   if(s_pathArmed)
   {
      s_pathArmed = false;
      ChartViewLockRelease();
   }
   if(reason != REASON_REMOVE) PathHandlesWipe();
   s_pathDrag = "";
   s_pathSel = "";
   //--- P-UI-180 (2026-10-20): the PREVIEW and the half-drawn session die with
   //--- EVERY reason, not only with the indicator's removal: a timeframe switch
   //--- leaves the preview line and the session's segments on the chart forever.
   PathSessionClear();
#ifdef BIOTAK_RENDER_ENGINE
   //--- P-PATH-CANVAS: give the FRONT layer back. A hook left mounted here would
   //--- paint a dead tool's band on the next attach's first frame.
   if(s_pathHookMounted) { g_rPaintHook = NULL; s_pathHookMounted = false; }
   REngineExtTimeContent(false);
#endif
   if(reason == REASON_REMOVE)
   {
      string pfx = PathPrefix();
      if(pfx != "") ObjectsDeleteAll(0, pfx);   // one sweep: segments AND dot (P-LOG-10 law 4)
      ArrayResize(s_pathIds, 0);
   }
}

#endif // PATH_TOOL_MQH
