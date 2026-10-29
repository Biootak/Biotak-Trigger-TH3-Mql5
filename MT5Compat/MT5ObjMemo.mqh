//+------------------------------------------------------------------+
//| MT5ObjMemo.mqh - MT5-ONLY object memo (P-PERF-156, 2026-10-28)    |
//|                                                                  |
//| THE CAUSE, straight from the official MQL5 reference              |
//|                                                                  |
//| The docs draw a line the shared source cannot see, because on MT4 |
//| that line does not exist:                                        |
//|                                                                  |
//|  * ObjectSetInteger / ObjectSetDouble / ObjectCreate / ObjectMove |
//|    are ASYNCHRONOUS - "the function does not wait for the         |
//|    execution of the command that has been added to the queue of   |
//|    the specified chart". A write costs an ENQUEUE.               |
//|  * every function that REQUESTS a property - ObjectGetInteger,    |
//|    ObjectGetDouble, ObjectGetString, ObjectFind, ObjectName,       |
//|    ObjectsTotal, ObjectsDeleteAll - "uses a synchronous call,     |
//|    which means that the function waits for the execution of all   |
//|    commands that have been enqueued for this chart prior to its   |
//|    call, that is why this function can be time consuming", and    |
//|    the docs add that this must be taken into account "when        |
//|    working with a large number of objects on a chart".            |
//|  * ChartRedraw() is the documented way to make the chart execute  |
//|    the queue and paint - once per frame (R-POINTER-FRAME already   |
//|    coalesces ours into one).                                      |
//|                                                                  |
//| So the guard pattern the whole product is written in -            |
//|                                                                  |
//|     if(ObjectGetInteger(0, nm, PROP) != v)                        |
//|        ObjectSetInteger(0, nm, PROP, v);                          |
//|                                                                  |
//| is not a cheap read on MT5: it is a FULL QUEUE DRAIN, priced by   |
//| the number of writes the pass has already enqueued. On MT4 the    |
//| same line reads local memory and costs nothing - which is exactly |
//| why one source is smooth there and laggy here, and why the        |
//| delete-sweeping of the previous round could not fix it: a sweep   |
//| is ONE sync call, the guard pattern is hundreds per frame.        |
//|                                                                  |
//| Two costs fall out of that, and this file removes both:          |
//|                                                                  |
//|   READS  - a program-owned property answer comes from memory      |
//|            after its first touch, so a pass stops paying a drain  |
//|            per guard.                                             |
//|   WRITES - a value the terminal already holds is never enqueued   |
//|            again, so the drains that DO happen - and the one      |
//|            ChartRedraw - find far less in the queue.              |
//|                                                                  |
//| WHY IT IS SAFE                                                    |
//|                                                                  |
//|  1. ALLOWLIST, not a blocklist. Only properties the indicator     |
//|     EXCLUSIVELY owns are remembered. Anything the terminal or the |
//|     user can move behind our back is never answered from memory:  |
//|       * OBJPROP_STATE    - the terminal flips a button on a click |
//|       * OBJPROP_SELECTED - the user's selection, which IS this    |
//|                            product's own selection face (P-LM-18) |
//|       * OBJPROP_TIME*/PRICE* - the user DRAGS these, and the ride  |
//|                            loop reads them PRECISELY to find out  |
//|       * OBJPROP_BMPFILE  - re-pointing it is how the code forces a |
//|                            texture refresh (P-PERF-01), so a      |
//|                            "redundant" set is load-bearing        |
//|       * OBJPROP_TYPE/NAME/CREATETIME - read-only or identity      |
//|     A property outside the allowlist behaves exactly as before:   |
//|     one live call, no cache, no skip.                             |
//|                                                                  |
//|  2. PER-NAME IDENTITY ("life"). Every name owns a control record  |
//|     holding its existence and a life counter. A property answer   |
//|     is believed only while its record carries the name's CURRENT  |
//|     life, so the moment an object's identity changes - our own    |
//|     delete, our own create, a foreign create - every remembered   |
//|     property of that name is distrusted in one step, with no walk.|
//|                                                                  |
//|  3. HOOKS. ObjectCreate / ObjectDelete / ObjectsDeleteAll are     |
//|     already wrapped here and update the table. User actions reach |
//|     the memo through the entry's OnChartEvent seam, the same line |
//|     that already filters our own CREATE/DELETE events:            |
//|     OBJECT_DELETE marks the name absent, OBJECT_CREATE gives it a |
//|     new life with existence UNKNOWN (one live find, then memoised)|
//|     and OBJECT_CLICK / OBJECT_CHANGE / OBJECT_DRAG /              |
//|     OBJECT_ENDEDIT drop that name's property answers - so a       |
//|     Properties-dialog edit of a colour can never sit on the memo. |
//|  4. A TTL as the backstop (2 s). A forgotten invalidation costs    |
//|     one stale frame at most, never a permanently wrong picture.    |
//|  5. The memo only ever holds values WE wrote or read. Skipping a   |
//|     write of an identical value is a no-op by definition, and      |
//|     answering a read with the last value the terminal was GIVEN    |
//|     is what MT4's own object store does. No observable behaviour   |
//|     changes - only the terminal crossing disappears.               |
//|                                                                  |
//| WHAT IT DOES NOT DO                                               |
//|                                                                  |
//| Strings are not remembered (ObjectGetString stays live) - about   |
//| 60 call sites against ~600 integer reads, and a string column     |
//| would be the table's whole footprint. ObjectsTotal/ObjectName     |
//| scans stay live too: they are chart walks, not property guards.   |
//|                                                                  |
//| MT5-ONLY by construction: this folder is never included by the    |
//| MT4 tree, so no shared line moves and parity cannot drift.        |
//+------------------------------------------------------------------+
#ifndef MT5_OBJ_MEMO_MQH
#define MT5_OBJ_MEMO_MQH

#define OM_SLOTS     8192        // power of two: ~2-4k live names x a few props
#define OM_PROBE     8
#define OM_TTL_MS    2000
#define OM_OWN_WRITE_MS 500     // our own write answers the terminal's event first
#define OM_KEY_PROP  0x7E00      // synthetic property id of a name's control record
#define OM_WIN_NONE  (-1)        // known ABSENT
#define OM_WIN_UNK   (-2)        // identity changed; nobody has asked the chart yet

#define OM_K_FREE  0
#define OM_K_INT   1
#define OM_K_DBL   2
#define OM_K_EXIST 3

static ulong  g_omKey[OM_SLOTS];      // 0 = free; live keys carry bit 63
static uchar  g_omKind[OM_SLOTS];
static uint   g_omGen[OM_SLOTS];      // the generation the entry was written under
static uint   g_omLife[OM_SLOTS];     // the name's life at that moment
static uint   g_omStamp[OM_SLOTS];    // GetTickCount() of the write
static long   g_omIval[OM_SLOTS];
static double g_omDval[OM_SLOTS];
static uint   g_omGenStamp = 1;
static bool   g_omReady = false;

void MT5ObjMemoInit()
{
   for(int i = 0; i < OM_SLOTS; i++)
   {
      g_omKey[i] = 0;   g_omKind[i] = OM_K_FREE;
      g_omGen[i] = 0;   g_omLife[i] = 0;  g_omStamp[i] = 0;
      g_omIval[i] = 0;  g_omDval[i] = 0.0;
   }
   g_omGenStamp = 1;
   g_omReady = true;
}

//--- 64-bit fingerprint of (chart, name, property, modifier). The chart id is
//--- part of the key, so a write to another chart can never be believed here.
ulong OmKey(const long chart_id, const string name, const int prop, const int mod)
{
   ulong h = 1469598103934665603;
   const int len = StringLen(name);
   for(int i = 0; i < len; i++)
   {
      h ^= (ulong)StringGetCharacter(name, i);
      h *= 1099511628211;
   }
   h ^= (ulong)((uint)chart_id * 2246822519); h *= 1099511628211;
   h ^= (ulong)((uint)prop * 2654435761);      h *= 1099511628211;
   h ^= (ulong)((uint)mod * 40503);             h *= 1099511628211;
   return h | 0x8000000000000000;               // never 0
}

int OmHome(const ulong key) { return (int)((key ^ (key >> 29)) % OM_SLOTS); }

//--- The slot holding `key`, or -1. A record is believed only while it carries
//--- the current generation and is younger than the TTL.
int OmLookup(const ulong key)
{
   if(!g_omReady) return -1;
   const int home = OmHome(key);
   const uint now = GetTickCount();
   for(int p = 0; p < OM_PROBE; p++)
   {
      const int idx = (home + p) % OM_SLOTS;
      if(g_omKey[idx] == 0) return -1;
      if(g_omKey[idx] != key) continue;
      if(g_omGen[idx] != g_omGenStamp) return -1;
      if((now - g_omStamp[idx]) >= OM_TTL_MS) return -1;
      return idx;
   }
   return -1;
}

void OmPut(const ulong key, const int kind, const long ival, const double dval, const uint life)
{
   if(!g_omReady) MT5ObjMemoInit();
   const int home = OmHome(key);
   int reuse = -1;
   for(int p = 0; p < OM_PROBE; p++)
   {
      const int idx = (home + p) % OM_SLOTS;
      if(g_omKey[idx] == 0) { reuse = idx; break; }
      if(g_omKey[idx] == key)
      {
         g_omKind[idx]  = (uchar)kind;
         g_omIval[idx]  = ival;
         g_omDval[idx]  = dval;
         g_omLife[idx]  = life;
         g_omGen[idx]   = g_omGenStamp;
         g_omStamp[idx] = GetTickCount();
         return;
      }
      if(reuse < 0 && g_omGen[idx] != g_omGenStamp) reuse = idx;   // stale: reclaim
   }
   if(reuse < 0) reuse = home;   // window full: reuse the head. A lost entry can
                                 // only cost one extra live call later, never a
                                 // wrong answer - which is the safe direction.
   g_omKey[reuse]   = key;
   g_omKind[reuse]  = (uchar)kind;
   g_omIval[reuse]  = ival;
   g_omDval[reuse]  = dval;
   g_omLife[reuse]  = life;
   g_omGen[reuse]   = g_omGenStamp;
   g_omStamp[reuse] = GetTickCount();
}

//+------------------------------------------------------------------+
//| The allowlist - the properties the indicator exclusively owns.    |
//+------------------------------------------------------------------+
bool OmMemoInt(const int prop)
{
   switch(prop)
   {
      case OBJPROP_XDISTANCE:      case OBJPROP_YDISTANCE:
      case OBJPROP_XSIZE:          case OBJPROP_YSIZE:
      case OBJPROP_CORNER:         case OBJPROP_ANCHOR:
      case OBJPROP_ALIGN:
      case OBJPROP_COLOR:          case OBJPROP_BGCOLOR:
      case OBJPROP_BORDER_COLOR:   case OBJPROP_BORDER_TYPE:
      case OBJPROP_STYLE:          case OBJPROP_WIDTH:
      case OBJPROP_FONTSIZE:       case OBJPROP_ARROWCODE:
      case OBJPROP_ZORDER:         case OBJPROP_BACK:
      case OBJPROP_FILL:           case OBJPROP_HIDDEN:
      case OBJPROP_SELECTABLE:     case OBJPROP_READONLY:
      case OBJPROP_TIMEFRAMES:
      case OBJPROP_RAY_LEFT:       case OBJPROP_RAY_RIGHT:
      case OBJPROP_LEVELS:         case OBJPROP_LEVELCOLOR:
      case OBJPROP_LEVELSTYLE:     case OBJPROP_LEVELWIDTH:
      case OBJPROP_YOFFSET:        case OBJPROP_XOFFSET:
         return true;
      default:
         return false;
   }
}

bool OmMemoDbl(const int prop)
{
   return (prop == OBJPROP_SCALE || prop == OBJPROP_ANGLE ||
           prop == OBJPROP_DEVIATION);
}

//--- The name's control record: existence (ObjectFind's own answer) and life.
uint OmLifeOf(const long chart_id, const string name)
{
   const int idx = OmLookup(OmKey(chart_id, name, OM_KEY_PROP, 0));
   return (idx < 0) ? 0 : g_omLife[idx];
}

//--- "WE touched this name a moment ago". The terminal can answer a
//--- programmatic property write with a CHARTEVENT_OBJECT_CHANGE of its own,
//--- and MT4 never does - so an event landing inside this window is ours and
//--- must not throw away what we just wrote. A Properties-dialog edit always
//--- lags a human click by more than this, so rule 3's safety is not paid for.
void OmStampName(const long chart_id, const string name)
{
   const int idx = OmLookup(OmKey(chart_id, name, OM_KEY_PROP, 0));
   if(idx >= 0) g_omStamp[idx] = GetTickCount();
}

bool OmNameIsOurs(const long chart_id, const string name)
{
   const int idx = OmLookup(OmKey(chart_id, name, OM_KEY_PROP, 0));
   if(idx < 0) return false;
   return ((GetTickCount() - g_omStamp[idx]) < OM_OWN_WRITE_MS);
}

//--- Forget this name's property answers, keep its existence. Levels are the
//--- one allowlisted property whose WRITE changes what other properties mean:
//--- OBJPROP_LEVELS = n throws away level n+1 in the terminal, so a remembered
//--- LEVELcolor/VALUE of a dropped level must never survive a resize.
void OmPropsInvalidate(const long chart_id, const string name)
{
   const int idx = OmLookup(OmKey(chart_id, name, OM_KEY_PROP, 0));
   if(idx < 0) return;
   g_omLife[idx]++;
   g_omStamp[idx] = GetTickCount();
}

//+------------------------------------------------------------------+
//| The table's two answers, uncounted. `Held` = the terminal was     |
//| last GIVEN this value for this name+property and nothing has      |
//| touched that object since.                                        |
//+------------------------------------------------------------------+
bool OmHeldInt(const long chart_id, const string name, const int prop, const int mod, long &out)
{
   if(!g_omReady || !OmMemoInt(prop)) return false;
   const int idx = OmLookup(OmKey(chart_id, name, prop, mod));
   if(idx < 0 || g_omKind[idx] != OM_K_INT) return false;
   if(g_omLife[idx] != OmLifeOf(chart_id, name)) return false;
   out = g_omIval[idx];
   return true;
}

bool OmHeldDbl(const long chart_id, const string name, const int prop, const int mod, double &out)
{
   if(!g_omReady || !OmMemoDbl(prop)) return false;
   const int idx = OmLookup(OmKey(chart_id, name, prop, mod));
   if(idx < 0 || g_omKind[idx] != OM_K_DBL) return false;
   if(g_omLife[idx] != OmLifeOf(chart_id, name)) return false;
   out = g_omDval[idx];
   return true;
}

//+------------------------------------------------------------------+
//| Read side. True = the answer came from memory: NO synchronous     |
//| call, so no queue drain.                                          |
//+------------------------------------------------------------------+
bool OmKnownInt(const long chart_id, const string name, const int prop, const int mod, long &out)
{
   if(!OmHeldInt(chart_id, name, prop, mod, out)) return false;
#ifdef COMPAT_LEDGER
   g_cl.omGetHit++;
#endif
   return true;
}

bool OmKnownDbl(const long chart_id, const string name, const int prop, const int mod, double &out)
{
   if(!OmHeldDbl(chart_id, name, prop, mod, out)) return false;
#ifdef COMPAT_LEDGER
   g_cl.omGetHit++;
#endif
   return true;
}

void OmLearnInt(const long chart_id, const string name, const int prop, const int mod, const long v)
{
   if(!OmMemoInt(prop)) return;
   OmPut(OmKey(chart_id, name, prop, mod), OM_K_INT, v, 0.0, OmLifeOf(chart_id, name));
   OmStampName(chart_id, name);
}

void OmLearnDbl(const long chart_id, const string name, const int prop, const int mod, const double v)
{
   if(!OmMemoDbl(prop)) return;
   OmPut(OmKey(chart_id, name, prop, mod), OM_K_DBL, 0, v, OmLifeOf(chart_id, name));
   OmStampName(chart_id, name);
}

//+------------------------------------------------------------------+
//| Write side. True = the terminal already holds this value, so the  |
//| caller must NOT enqueue the command.                              |
//+------------------------------------------------------------------+
bool OmSkipInt(const long chart_id, const string name, const int prop, const int mod, const long v)
{
   long held;
   if(!OmHeldInt(chart_id, name, prop, mod, held)) return false;
   if(held != v) return false;
#ifdef COMPAT_LEDGER
   g_cl.omSetSkip++;
#endif
   return true;
}

void OmNoteInt(const long chart_id, const string name, const int prop, const int mod, const long v)
{
   if(!OmMemoInt(prop)) return;
   OmLearnInt(chart_id, name, prop, mod, v);
   // A level-count write throws levels away IN THE TERMINAL; their remembered
   // colours/values must throw away with them.
   if(prop == OBJPROP_LEVELS) OmPropsInvalidate(chart_id, name);
#ifdef COMPAT_LEDGER
   g_cl.omSetWrite++;
#endif
}

bool OmSkipDbl(const long chart_id, const string name, const int prop, const int mod, const double v)
{
   double held;
   if(!OmHeldDbl(chart_id, name, prop, mod, held)) return false;
   if(held != v) return false;
#ifdef COMPAT_LEDGER
   g_cl.omSetSkip++;
#endif
   return true;
}

void OmNoteDbl(const long chart_id, const string name, const int prop, const int mod, const double v)
{
   if(!OmMemoDbl(prop)) return;
   OmLearnDbl(chart_id, name, prop, mod, v);
#ifdef COMPAT_LEDGER
   g_cl.omSetWrite++;
#endif
}

//+------------------------------------------------------------------+
//| Existence. ObjectFind gates almost every path in the product, and |
//| on MT5 it is a synchronous call the docs price "when working with |
//| a large number of objects on a chart".                            |
//+------------------------------------------------------------------+
bool OmKnownFind(const long chart_id, const string name, int &win)
{
   if(!g_omReady) return false;
   const int idx = OmLookup(OmKey(chart_id, name, OM_KEY_PROP, 0));
   if(idx < 0 || g_omKind[idx] != OM_K_EXIST) return false;
   if(g_omIval[idx] == OM_WIN_UNK) return false;      // identity changed: ask the chart
   win = (int)g_omIval[idx];
#ifdef COMPAT_LEDGER
   g_cl.omFindHit++;
#endif
   return true;
}

void OmLearnFind(const long chart_id, const string name, const int win)
{
   const ulong key = OmKey(chart_id, name, OM_KEY_PROP, 0);
   const int idx = OmLookup(key);
   OmPut(key, OM_K_EXIST, win, 0.0, (idx < 0) ? 1 : g_omLife[idx]);
}

//--- The object's identity changed: a fresh life makes every property the memo
//--- holds for the OLD object distrusted, in one step and with no walk.
void OmRebirth(const long chart_id, const string name, const int win)
{
   if(!g_omReady) MT5ObjMemoInit();
   const ulong key = OmKey(chart_id, name, OM_KEY_PROP, 0);
   const int idx = OmLookup(key);
   const uint life = (idx < 0) ? 1 : g_omLife[idx] + 1;
   OmPut(key, OM_K_EXIST, win, 0.0, life);
#ifdef COMPAT_LEDGER
   g_cl.omRebirth++;
#endif
}

void OmNoteCreate(const long chart_id, const string name, const int sub_window)
{
   OmRebirth(chart_id, name, (sub_window < 0 ? OM_WIN_UNK : sub_window));
}

void OmNoteDelete(const long chart_id, const string name)
{
   OmRebirth(chart_id, name, OM_WIN_NONE);
}

//--- The user touched this object (click, drag, Properties dialog, text edit):
//--- its property answers are no longer ours to give. Existence is untouched.
//--- An event inside our own-write window (OM_OWN_WRITE_MS) is the terminal
//--- echoing a command WE sent, so the memo stays.
void OmTouchName(const long chart_id, const string name)
{
   if(OmNameIsOurs(chart_id, name)) return;
   const ulong key = OmKey(chart_id, name, OM_KEY_PROP, 0);
   const int idx = OmLookup(key);
   if(idx < 0) return;
   g_omLife[idx]++;
   g_omStamp[idx] = GetTickCount();
#ifdef COMPAT_LEDGER
   g_cl.omTouch++;
#endif
}

//--- ObjectsDeleteAll removes a set this file cannot enumerate, so the whole
//--- generation goes stale at once. O(1), and correct by construction: the
//--- frame that swept has nothing left to remember.
void OmFlushAll()
{
   if(!g_omReady) { MT5ObjMemoInit(); return; }
   g_omGenStamp++;
   if(g_omGenStamp == 0) MT5ObjMemoInit();
#ifdef COMPAT_LEDGER
   g_cl.omFlush++;
#endif
}

//--- The clock the wrappers use to price the synchronous calls they still make.
uint OmMark()
{
#ifdef COMPAT_LEDGER
   return (uint)GetMicrosecondCount();
#else
   return (0);
#endif
}

void OmSpend(const uint t0, const int isFind)
{
#ifdef COMPAT_LEDGER
   const uint d = (uint)GetMicrosecondCount() - t0;
   if(isFind != 0) { g_cl.omFindLive++; g_cl.omSyncUs += d; }
   else            { g_cl.omGetLive++;  g_cl.omSyncUs += d; }
#endif
}

//+------------------------------------------------------------------+
//| The event seam. Called from CompatConsumeObjEvent, which the      |
//| entry's OnChartEvent already runs for EVERY event before any      |
//| dispatch - so no new subscription and no shared line moves.       |
//|                                                                  |
//| A CREATE/DELETE that our own wrapper already tokenised arrives    |
//| here too: the wrapper gave the name its real window and its fresh |
//| life, so the event only has to say "the command executed". A      |
//| FOREIGN one - the user drew or deleted something - is the case    |
//| that changes a name's identity without us, and it gets the same   |
//| rebirth with existence UNKNOWN until the chart is asked once.     |
//+------------------------------------------------------------------+
void OmEventHook(const int id, const long chart_id, const string name, const bool ours)
{
   if(name == "" || !g_omReady) return;
   if(id == CHARTEVENT_OBJECT_CREATE)
   {
      if(ours) { OmStampName(chart_id, name); return; }
      OmRebirth(chart_id, name, OM_WIN_UNK);
      return;
   }
   if(id == CHARTEVENT_OBJECT_DELETE)
   {
      if(ours) return;                 // OmNoteDelete already ran
      OmRebirth(chart_id, name, OM_WIN_NONE);   // the chart just said: gone
      return;
   }
   if(id == CHARTEVENT_OBJECT_CLICK  || id == CHARTEVENT_OBJECT_CHANGE ||
      id == CHARTEVENT_OBJECT_DRAG   || id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      OmTouchName(chart_id, name);
   }
}

#endif // MT5_OBJ_MEMO_MQH
