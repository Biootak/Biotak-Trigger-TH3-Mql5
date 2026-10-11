//+------------------------------------------------------------------+
//| MT5ObjWriteFilter.mqh - MT5-ONLY redundant-property-write filter  |
//|                                                                  |
//| STATUS: BUILT AND GATED OFF. Read the "WHY IT IS NOT ENABLED YET"  |
//| block at the bottom before turning the switch on.                 |
//|                                                                  |
//| THE PROBLEM THIS TARGETS                                          |
//|                                                                  |
//| MT4 and MT5 run ONE shared source, yet the MT5 build is visibly    |
//| heavier. The interaction ledger (15.6 ms Windows tick) hides the   |
//| size of the gap, but the measurement with real resolution is       |
//| decisive - the full-frame repaint (`coop job=heavy-frame`):        |
//|                                                                  |
//|     MT4 : 47 / 62 / 78 ms   (95x / 33x / 15x over four days)       |
//|     MT5 : 47 / 79 / 156 ms  (reaches 2x MT4's worst case)          |
//|                                                                  |
//| and `OnDeinit` runs 266-328 ms on MT4 against 485 ms on MT5.       |
//|                                                                  |
//| The frame is object-bound: ObjectCache.mqh documents the same      |
//| chart issuing "~2,600 terminal object probes per frame, every      |
//| frame, forever", and the frame's other half is object PROPERTY     |
//| WRITES (ObjectSetInteger 941 call sites, ObjectSetString 211,      |
//| ObjectSetDouble 63 in the shared modules). MQL5's object API is    |
//| not MQL4's: every write is marshalled, validated and can          |
//| invalidate the chart's object cache, which is why identical code   |
//| costs ~2x here.                                                    |
//|                                                                  |
//| We cannot make MQL5's call cheaper. We CAN stop making calls that  |
//| provably change nothing - and that is safe to do in the MT5 shim   |
//| ALONE, so the MT4 build is untouched by construction and parity    |
//| cannot drift.                                                     |
//|                                                                  |
//| HOW IT IS SAFE                                                    |
//|                                                                  |
//|  1. ALLOWLIST, not blocklist. Only properties the indicator        |
//|     EXCLUSIVELY owns are memoised. Anything the terminal or the    |
//|     user can change behind our back is never filtered:             |
//|       * OBJPROP_STATE      - the terminal flips it on a click      |
//|                              (the pager latch clear exists for     |
//|                              exactly this reason)                  |
//|       * OBJPROP_SELECTED   - the user's selection                  |
//|       * OBJPROP_TIME*/PRICE* - the user DRAGS these; the BaseKnot  |
//|                              box and the custom price line live on |
//|                              them                                  |
//|       * OBJPROP_BMPFILE    - re-pointing it is how the code forces |
//|                              a texture refresh (P-PERF-01), so a   |
//|                              "redundant" set may be load-bearing   |
//|       * OBJPROP_TYPE/CREATETIME/CHART_ID - read-only anyway        |
//|                                                                  |
//|  2. INVALIDATION IS O(1) AND TOTAL. `g_owGenStamp` is bumped by    |
//|     every SUCCESSFUL ObjectDelete / ObjectsDeleteAll, and a slot   |
//|     is only believed while its stamp equals the current            |
//|     generation. This is the same generation-scoping P-PERF-07      |
//|     already uses for its absent table, and it is why no sweep can  |
//|     be forgotten.                                                 |
//|                                                                  |
//|     DELETION IS THE ONLY HOOK NEEDED, and that is not an omission  |
//|     - it is the safety argument. The memo can only be WRONG for an |
//|     object that was RE-CREATED, and re-creating requires a prior   |
//|     deletion. Hook every deletion and no stale entry can survive   |
//|     into the new object's life.                                    |
//|                                                                  |
//|  3. THE MEMO ONLY REMEMBERS WRITES THAT SUCCEEDED. A failed write  |
//|     is retried on the next frame exactly as before.                |
//|                                                                  |
//|  4. IT IS ONLY A CACHE OF WHAT WE LAST WROTE. Skipping a write of  |
//|     an identical value is a no-op by definition, so no observable  |
//|     behaviour can change - only the terminal call disappears.      |
//|                                                                  |
//| WHAT IT CANNOT DO                                                 |
//|                                                                  |
//| A frame that deletes objects (a menu rebuild, a wipe, a TF switch) |
//| bumps the generation and gets no filtering - which is correct,     |
//| because such a frame has nothing redundant to skip. The win lands  |
//| on the steady-state frame, and that is the frame the user feels as |
//| lag.                                                              |
//|                                                                  |
//| WHY IT IS NOT ENABLED YET                                         |
//|                                                                  |
//| Two things must be true before the switch goes on, and neither is  |
//| proven on this machine yet:                                        |
//|                                                                  |
//|   (a) MEASUREMENT. The primitive probe (MT5PrimitiveProbe.mqh) has |
//|       to show that a property WRITE costs materially more than a   |
//|       property READ and that the frame issues enough redundant     |
//|       writes for the skip to matter. The project's own rule is     |
//|       "a number without a cause is what this project refuses to    |
//|       act on" - and the cause here is still a hypothesis.          |
//|                                                                  |
//|   (b) THE RESIDUAL IS NOT ALREADY FIXED. The shared source already |
//|       dirty-tracks its biggest offenders at the call site (P-PERF-02|
//|       "skips ~800 ObjectSetInteger calls when unchanged";          |
//|       LevelPipeline "hundreds of writes per frame for masks that   |
//|       had not changed"). If the residual redundancy is small, this |
//|       filter buys little and should stay off.                      |
//|                                                                  |
//| The infrastructure costs nothing while off: every hook compiles to |
//| an empty function and both predicates to an inlined `false`.       |
//+------------------------------------------------------------------+
#ifndef MT5_OBJ_WRITE_FILTER_MQH
#define MT5_OBJ_WRITE_FILTER_MQH

// GATED OFF. Uncomment to enable - and read the status block above first.
//#define MT5_OBJ_WRITE_FILTER

#ifdef MT5_OBJ_WRITE_FILTER

#define OW_BUCKETS 8192   // live population is ~2-4k names x a handful of props
#define OW_PROBE   4      // 4 probes keep the load factor's miss rate negligible

static ulong  g_owKey[OW_BUCKETS];    // 0 = free; real keys carry bit 63
static long   g_owIval[OW_BUCKETS];   // last long we wrote (int properties)
static double g_owDval[OW_BUCKETS];   // last double we wrote (double properties)
static uchar  g_owKind[OW_BUCKETS];   // 1 = int slot, 2 = double slot
static uint   g_owGen[OW_BUCKETS];    // g_owGenStamp the entry was written under
static uint   g_owGenStamp = 1;       // bumped by every existence change
static long   g_owSkips    = 0;       // terminal writes we did NOT make
static long   g_owWrites   = 0;       // writes we did make

//--- 64-bit fingerprint of (chart, name, property, modifier). Two independent
//    djb2-style mixes so an accidental collision is not a practical risk;
//    bit 63 marks a live key so 0 can mean "free". The chart id is part of the
//    key (not assumed to be 0) so a cross-chart write can never be confused
//    with a write to this instance's own chart.
ulong OwMix64(const long chart_id, const string name, const int prop, const int mod)
{
   ulong h = 1469598103934665603;          // FNV-1a 64 offset basis
   const int len = StringLen(name);
   for(int i = 0; i < len; i++)
   {
      h ^= (ulong)StringGetCharacter(name, i);
      h *= 1099511628211;                  // FNV-1a 64 prime
   }
   h ^= (ulong)((uint)chart_id * 2246822519);
   h *= 1099511628211;
   h ^= (ulong)((uint)prop * 2654435761);  // Knuth multiplicative mix
   h *= 1099511628211;
   h ^= (ulong)((uint)mod * 40503);
   h *= 1099511628211;
   return h | 0x8000000000000000;          // never 0
}

int OwFind(const ulong key)
{
   const int slot = (int)((key ^ (key >> 29)) % (ulong)OW_BUCKETS);
   for(int p = 0; p < OW_PROBE; p++)
   {
      const int idx = (slot + p) % OW_BUCKETS;
      if(g_owKey[idx] == 0) return -1;      // empty slot ends the chain
      if(g_owKey[idx] == key && g_owGen[idx] == g_owGenStamp) return idx;
   }
   return -1;
}

void OwStore(const ulong key, const int kind, const long ival, const double dval)
{
   const int slot = (int)((key ^ (key >> 29)) % (ulong)OW_BUCKETS);
   int free = -1;
   for(int p = 0; p < OW_PROBE; p++)
   {
      const int idx = (slot + p) % OW_BUCKETS;
      if(g_owKey[idx] == 0) { free = idx; break; }
      if(g_owKey[idx] == key && g_owGen[idx] == g_owGenStamp)
      {
         g_owKind[idx] = (uchar)kind;
         g_owIval[idx] = ival;
         g_owDval[idx] = dval;
         return;
      }
      if(g_owGen[idx] != g_owGenStamp && free < 0) free = idx;   // reclaim stale
   }
   if(free < 0) free = slot;   // window full: reuse the head (a lost entry
                               // can only cost one extra write later)
   g_owKey[free]  = key;
   g_owKind[free] = (uchar)kind;
   g_owIval[free] = ival;
   g_owDval[free] = dval;
   g_owGen[free]  = g_owGenStamp;
}

//--- O(1) total invalidation: every slot becomes stale at once, no sweep.
void MT5ObjWriteFilterInvalidate() { g_owGenStamp++; }

void MT5ObjWriteFilterReset()
{
   for(int i = 0; i < OW_BUCKETS; i++) { g_owKey[i] = 0; g_owGen[i] = 0; }
   g_owGenStamp = 1;
   g_owSkips = 0;
   g_owWrites = 0;
}

long MT5ObjWriteFilterSkips()  { return g_owSkips; }
long MT5ObjWriteFilterWrites() { return g_owWrites; }

//+------------------------------------------------------------------+
//| The allowlist. Named constants (not magic numbers) so the compiler |
//| proves each one exists; a property absent here is never filtered.  |
//+------------------------------------------------------------------+
bool OwPropMemoizableInt(const int prop)
{
   switch(prop)
   {
      // position / size / anchor
      case OBJPROP_XDISTANCE:      case OBJPROP_YDISTANCE:
      case OBJPROP_XSIZE:          case OBJPROP_YSIZE:
      case OBJPROP_CORNER:         case OBJPROP_ANCHOR:
      case OBJPROP_ALIGN:
      // paint
      case OBJPROP_COLOR:          case OBJPROP_BGCOLOR:
      case OBJPROP_BORDER_COLOR:   case OBJPROP_BORDER_TYPE:
      case OBJPROP_STYLE:          case OBJPROP_WIDTH:
      case OBJPROP_FONTSIZE:       case OBJPROP_ARROWCODE:
      // layering / interaction
      case OBJPROP_ZORDER:         case OBJPROP_BACK:
      case OBJPROP_FILL:           case OBJPROP_HIDDEN:
      case OBJPROP_SELECTABLE:     case OBJPROP_READONLY:
      case OBJPROP_TIMEFRAMES:
      // trend-line rays
      case OBJPROP_RAY_LEFT:       case OBJPROP_RAY_RIGHT:
      // levels
      case OBJPROP_LEVELS:         case OBJPROP_LEVELCOLOR:
      case OBJPROP_LEVELSTYLE:     case OBJPROP_LEVELWIDTH:
         return true;
      default:
         return false;
   }
}

bool OwPropMemoizableDbl(const int prop)
{
   switch(prop)
   {
      case OBJPROP_SCALE:
      case OBJPROP_ANGLE:
      case OBJPROP_DEVIATION:
      case OBJPROP_LEVELVALUE:
         return true;
      default:
         return false;
   }
}

//--- Returns true when the write would be redundant (caller must SKIP it).
bool OwSkipInt(const long chart_id, const string name, const int prop, const int mod, const long value)
{
   if(!OwPropMemoizableInt(prop)) return false;
   const ulong key = OwMix64(chart_id, name, prop, mod);
   const int idx = OwFind(key);
   if(idx < 0) return false;
   if(g_owKind[idx] != 1) return false;
   if(g_owIval[idx] != value) return false;
   g_owSkips++;
   return true;
}

bool OwSkipDbl(const long chart_id, const string name, const int prop, const int mod, const double value)
{
   if(!OwPropMemoizableDbl(prop)) return false;
   const ulong key = OwMix64(chart_id, name, prop, mod);
   const int idx = OwFind(key);
   if(idx < 0) return false;
   if(g_owKind[idx] != 2) return false;
   if(g_owDval[idx] != value) return false;
   g_owSkips++;
   return true;
}

//--- Remember a write that SUCCEEDED (a failed one must be retried).
void OwNoteInt(const long chart_id, const string name, const int prop, const int mod, const long value)
{
   if(!OwPropMemoizableInt(prop)) return;
   OwStore(OwMix64(chart_id, name, prop, mod), 1, value, 0.0);
   g_owWrites++;
}

void OwNoteDbl(const long chart_id, const string name, const int prop, const int mod, const double value)
{
   if(!OwPropMemoizableDbl(prop)) return;
   OwStore(OwMix64(chart_id, name, prop, mod), 2, 0, value);
   g_owWrites++;
}

//+------------------------------------------------------------------+
//| Existence-change hooks.                                          |
//|                                                                  |
//| DELETION is the only hook this filter needs, and that is not an    |
//| omission - it is the whole safety argument:                        |
//|                                                                  |
//|   The memo can only be WRONG for an object that was RE-CREATED,    |
//|   and re-creating requires a prior deletion. Hook every deletion   |
//|   and no stale entry can survive into the new object's life.       |
//|                                                                  |
//| `ObjectCreate` is deliberately NOT wrapped. MQL5 resolves           |
//|   ObjectCreate(chart_id,name,type,win,time1,price1, ...)           |
//|   ObjectCreate(chart_id,name,type,win,x,y)                         |
//| by preferring the XY form for a (datetime, int) argument pair, so a |
//| wrapper pair silently creates time-anchored objects with pixel      |
//| coordinates (the compiler proves it: warning 43 "possible loss of   |
//| data due to type conversion from 'datetime' to 'int'"). The delete  |
//| hook makes the create hook unnecessary, so the hazard is removed    |
//| rather than worked around.                                          |
//+------------------------------------------------------------------+
bool ObjectDeleteReal(const long chart_id, const string name)
{
   return ObjectDelete(chart_id, name);
}

int ObjectsDeleteAllReal(const long chart_id, const int sub_window, const int type)
{
   return ObjectsDeleteAll(chart_id, sub_window, type);
}

int ObjectsDeleteAllRealPrefix(const long chart_id, const string prefix, const int sub_window, const int type)
{
   return ObjectsDeleteAll(chart_id, prefix, sub_window, type);
}

#define ObjectDelete      ObjectDeleteFiltered
#define ObjectsDeleteAll  ObjectsDeleteAllFiltered

bool ObjectDeleteFiltered(const long chart_id, const string name)
{
   const bool ok = ObjectDeleteReal(chart_id, name);
   if(ok) MT5ObjWriteFilterInvalidate();   // its memo entries die with it
   return ok;
}

// The two ObjectsDeleteAll forms are kept apart by the 2nd parameter's TYPE
// (int sub_window vs string prefix), and the int form deliberately has NO
// default arguments: a string literal cannot reach it, and -1 cannot reach the
// prefix form, so no call site can silently land in the wrong one. The
// codebase uses only the 2-, 3- and 4-argument forms (verified), so the missing
// 1-argument form is a compile error rather than a silent mis-resolution.
int ObjectsDeleteAllFiltered(const long chart_id, const int sub_window, const int type)
{
   const int n = ObjectsDeleteAllReal(chart_id, sub_window, type);
   if(n > 0) MT5ObjWriteFilterInvalidate();
   return n;
}

int ObjectsDeleteAllFiltered(const long chart_id, const string prefix,
                             const int sub_window = -1, const int type = -1)
{
   const int n = ObjectsDeleteAllRealPrefix(chart_id, prefix, sub_window, type);
   if(n > 0) MT5ObjWriteFilterInvalidate();
   return n;
}

#else

//--- Disabled: the hooks and the two predicates must still exist, so every
//    call site in the shim compiles unchanged and costs one inlined `false`.
void MT5ObjWriteFilterInvalidate() {}
void MT5ObjWriteFilterReset()      {}
long MT5ObjWriteFilterSkips()      { return 0; }
long MT5ObjWriteFilterWrites()     { return 0; }

bool OwSkipInt(const long chart_id, const string name, const int prop, const int mod, const long value) { return false; }
bool OwSkipDbl(const long chart_id, const string name, const int prop, const int mod, const double value) { return false; }
void OwNoteInt(const long chart_id, const string name, const int prop, const int mod, const long value) {}
void OwNoteDbl(const long chart_id, const string name, const int prop, const int mod, const double value) {}

#endif // MT5_OBJ_WRITE_FILTER

#endif // MT5_OBJ_WRITE_FILTER_MQH
