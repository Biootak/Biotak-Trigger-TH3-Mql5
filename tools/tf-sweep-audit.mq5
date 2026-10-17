//+------------------------------------------------------------------+
//|                                       Biotak TF Sweep Audit.mq5  |
//| P-PERF-109 HARNESS (2026-10-17) — the TF-switch verdict collector.|
//|                                                                   |
//| Purpose. Three reported symptoms needed a REPEATED, MACHINE-      |
//| READABLE reproduction, not a static read:                          |
//|   1. some timeframes do not draw the ladder at all,               |
//|   2. a drawn family stops being visible after a TF switch,        |
//|   3. the switch itself lags even with the levels switched off.    |
//|                                                                   |
//| Design. An EA attached ONCE on the chart that carries             |
//| Biotak Trigger TH3. A TF switch reloads both programs on that     |
//| chart - which is exactly the user action - so the EA rides its    |
//| own reloads and drives the cycle through TERMINAL GlobalVariables |
//| (statics die with each reload; the GVs survive the switch).       |
//| Each leg:                                                         |
//|   t+0                the reload re-inits the EA: audit #1 (what   |
//|                       SURVIVED the switch, at handoff moment)     |
//|   t+InLateAuditMs    audit #2 (did the late frame land?)          |
//|   t+InSwitchAfterMs  ChartSetSymbolPeriod -> next TF              |
//| until the 9-TF cycle is done; then it restores the original TF,   |
//| audits the way back, repeats InCycles rounds and removes itself.  |
//| Changing InRunId (an input edit) restarts the sweep from zero.    |
//|                                                                   |
//| Output. One `[SWITCH-AUDIT]` line per audit: counts of the ladder |
//| families on THIS chart split into visible / masked (OBJ_NO_PERIODS|
//| objects), which is the machine answer for "drawn?", "after a      |
//| switch?" and "drawn but invisible". The indicator's own witnesses |
//| (f1 / WIPE / P-VIEW census / P-LEVEL-FOREIGN) land in the same    |
//| Experts log, so one parse reads both halves.                      |
//|                                                                   |
//| This is a tool, not a product module: it reads and drives chart   |
//| objects only, shares nothing with the indicator, and is never     |
//| included by the entries.                                          |
//+------------------------------------------------------------------+
#property copyright "Biotak Project"
#property link      "@biotak"
#property version   "1.00"
#property strict
#property description "Rides the Biotak Trigger TH3 chart through every TF and audits the ladder families."

input int    InCycles         = 2;      // full 9-TF sweep rounds (0 = just restore & exit)
input string InRunId          = "run1"; // change to restart the sweep
input int    InLateAuditMs    = 2500;   // audit #2 delay after a switch
input int    InSwitchAfterMs  = 5500;   // time to next TF
input string InFamilyPrefix   = "THLevels_"; // the level namespace to audit

ENUM_TIMEFRAMES SweepTFs[9] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30,
                               PERIOD_H1, PERIOD_H4, PERIOD_D1,
                               PERIOD_W1, PERIOD_MN1};
// phase 0 = wait audit #2, phase 1 = wait the switch, phase 2 = wait the restore audit
int      s_cycle      = 0;
int      s_step       = 0;
int      s_phase      = 0;
long     s_deadlineMs = 0;
long     s_origTf     = 0;

string GvCycle()    { return "Biotak_TFSweep_cycle_"    + _Symbol; }
string GvStep()     { return "Biotak_TFSweep_step_"     + _Symbol; }
string GvPhase()    { return "Biotak_TFSweep_phase_"    + _Symbol; }
string GvDeadline() { return "Biotak_TFSweep_deadline_" + _Symbol; }
string GvOrigTf()   { return "Biotak_TFSweep_origtf_"   + _Symbol; }
string GvRunId()    { return "Biotak_TFSweep_runid_"    + _Symbol; }

int TfToMinutes(ENUM_TIMEFRAMES tf)
{
    switch(tf)
    {
        case PERIOD_M1:  return 1;
        case PERIOD_M5:  return 5;
        case PERIOD_M15: return 15;
        case PERIOD_M30: return 30;
        case PERIOD_H1:  return 60;
        case PERIOD_H4:  return 240;
        case PERIOD_D1:  return 1440;
        case PERIOD_W1:  return 10080;
        case PERIOD_MN1: return 43200;
    }
    return Period();
}
ENUM_TIMEFRAMES MinutesToTf(const int minutes)
{
    switch(minutes)
    {
        case 1:     return PERIOD_M1;
        case 5:     return PERIOD_M5;
        case 15:    return PERIOD_M15;
        case 30:    return PERIOD_M30;
        case 60:    return PERIOD_H1;
        case 240:   return PERIOD_H4;
        case 1440:  return PERIOD_D1;
        case 10080: return PERIOD_W1;
        case 43200: return PERIOD_MN1;
    }
    return (ENUM_TIMEFRAMES)Period();
}

long RunIdStamp(const string s)
{
    long h = 0;
    for(int i = 0; i < StringLen(s); i++) h = h * 131 + (int)StringGetCharacter(s, i);
    return h;
}

void StateSave()
{
    GlobalVariableSet(GvCycle(),    (double)s_cycle);
    GlobalVariableSet(GvStep(),     (double)s_step);
    GlobalVariableSet(GvPhase(),    (double)s_phase);
    GlobalVariableSet(GvDeadline(), (double)s_deadlineMs);
}

// false = no previous state (fresh run); true = riding a reload
bool StateLoad()
{
    if(!GlobalVariableCheck(GvRunId())) return false;
    s_cycle      = (int)GlobalVariableGet(GvCycle());
    s_step       = (int)GlobalVariableGet(GvStep());
    s_phase      = (int)GlobalVariableGet(GvPhase());
    s_deadlineMs = (long)GlobalVariableGet(GvDeadline());
    s_origTf     = (long)GlobalVariableGet(GvOrigTf());
    if(s_origTf <= 0) s_origTf = TfToMinutes(Period());
    return true;
}

void StateClear()
{
    GlobalVariableDel(GvCycle());    GlobalVariableDel(GvStep());
    GlobalVariableDel(GvPhase());    GlobalVariableDel(GvDeadline());
    GlobalVariableDel(GvOrigTf());   GlobalVariableDel(GvRunId());
}

//+------------------------------------------------------------------+
//| THE AUDIT: one line, every bucket, visible-vs-masked split.      |
//+------------------------------------------------------------------+
void Audit(const string tag)
{
    int total = ObjectsTotal(0, -1, -1);
    int linesV = 0, linesM = 0;
    int zonesV = 0, zonesM = 0;
    int labelsV = 0, labelsM = 0;
    int other = 0;
    for(int i = 0; i < total; i++)
    {
        string nm = ObjectName(0, i, -1, -1);
        if(StringLen(nm) <= 0) continue;
        bool family = (StringFind(nm, InFamilyPrefix) == 0);
        if(!family) { other++; continue; }
        long mask = (long)ObjectGetInteger(0, nm, OBJPROP_TIMEFRAMES);
        bool masked = (mask == (long)OBJ_NO_PERIODS);
        if(StringFind(nm, "_Label") >= 0)
        { if(masked) labelsM++; else labelsV++; }
        else if(StringFind(nm, "_Zone_") >= 0)
        { if(masked) zonesM++; else zonesV++; }
        else
        { if(masked) linesM++; else linesV++; }
    }
    const int lines  = linesV + linesM;
    const int zones  = zonesV + zonesM;
    const int labels = labelsV + labelsM;
    string verdict;
    if(lines == 0 && zones == 0)       verdict = "BLANK";
    else if(lines > 0 && linesV == 0)  verdict = "MASKED";
    else if(linesV < 4)                verdict = "THIN";
    else                               verdict = "OK";
    Print("[SWITCH-AUDIT] tf=", TfToMinutes((ENUM_TIMEFRAMES)Period()),
          " tag=", tag,
          " lines=", linesV, "/", lines, " zones=", zonesV, "/", zones,
          " labels=", labelsV, "/", labels,
          " misc=", other, " total=", total, " verdict=", verdict);
}

int OnInit()
{
    const long stampNow = RunIdStamp(InRunId);
    const bool prevExists = GlobalVariableCheck(GvRunId());
    const bool runIdChanged = prevExists && (long)GlobalVariableGet(GvRunId()) != stampNow;
    // A removed-then-reattached EA (REASON_REMOVE removed the state) and a
    // changed run id both start fresh; a TF switch / terminal restart rides.
    bool riding = !runIdChanged && StateLoad();
    if(runIdChanged || !prevExists)
    {
        StateClear();
        Print("[HARNESS] fresh run id=", InRunId, " cycles=", InCycles,
              " origTf=", TfToMinutes(Period()), " chart=", _Symbol, " init=", TfToMinutes(Period()));
    }
    if(riding)
        Print("[HARNESS] riding cycle=", s_cycle, " step=", s_step, " phase=", s_phase,
              " tf=", TfToMinutes(Period()));
    else
    {
        s_cycle = 0; s_step = 0; s_phase = 0; s_deadlineMs = 0;
        s_origTf = TfToMinutes(Period());
        GlobalVariableSet(GvOrigTf(), (double)s_origTf);
        GlobalVariableSet(GvRunId(), (double)stampNow);
    }

    // Audit #1: the "what survived the switch" sample — the terminal hands
    // control to the EA at the same reload the indicator lives through, so
    // this line and the indicator's own f1/census lines share the clock.
    Audit("init");

    s_deadlineMs = (long)GetTickCount() + InLateAuditMs;
    if(s_phase < 0 || s_phase > 2) s_phase = 0;
    StateSave();
    EventSetTimer(1);
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    EventKillTimer();
    string why = IntegerToString(reason);
    switch(reason)
    {
        case REASON_PROGRAM:     why = "program";     break;
        case REASON_REMOVE:      why = "remove";      break;
        case REASON_RECOMPILE:   why = "recompile";   break;
        case REASON_CHARTCHANGE: why = "tfswitch";    break;
        case REASON_CHARTCLOSE:  why = "chartclose";  break;
        case REASON_PARAMETERS:  why = "parameters";  break;
        case REASON_ACCOUNT:     why = "account";     break;
        case REASON_TEMPLATE:    why = "template";    break;
        case REASON_CLOSE:       why = "close";       break;
    }
    Print("[HARNESS] deinit reason=", why, " cycle=", s_cycle, " step=", s_step, " phase=", s_phase);
    // The state survives the reload reasons by design (the next instance
    // rides it). REASON_REMOVE (the EA detached) ends the sweep honestly.
    if(reason == REASON_REMOVE)
        StateClear();
}

void OnTimer()
{
    long now = (long)GetTickCount();
    if(now < s_deadlineMs) { StateSave(); return; }

    if(s_phase == 0)
    {
        Audit("late");
        s_phase = 1;
        s_deadlineMs = now + MathMax(250, InSwitchAfterMs - InLateAuditMs);
        StateSave();
        return;
    }
    if(s_phase == 1)
    {
        int nextStep = s_step + 1;
        if(s_step == -1 || s_step + 1 < 0) nextStep = 0;
        if(nextStep >= ArraySize(SweepTFs))
        {
            // Restore, audit the way BACK (symptom 2's exact shape), then
            // either loop another cycle or retire.
            Print("[HARNESS] cycle=", s_cycle, " complete - restoring tf=", s_origTf);
            ChartSetSymbolPeriod(0, _Symbol, MinutesToTf((int)s_origTf));
            s_step = nextStep;              // == 9: marks "restore pending"
            s_phase = 2;
            s_deadlineMs = (long)GetTickCount() + InLateAuditMs + 500;
            StateSave();
            return;
        }
        int nextTf = TfToMinutes(SweepTFs[nextStep]);
        Print("[HARNESS] switch cycle=", s_cycle, " step=", nextStep, " -> ", nextTf, "min");
        ChartSetSymbolPeriod(0, _Symbol, MinutesToTf(nextTf));
        s_step = nextStep;
        s_phase = 0;
        s_deadlineMs = (long)GetTickCount() + 150;   // the reload re-arms the real clock in OnInit
        StateSave();
        return;
    }
    if(s_phase == 2)
    {
        Audit("restore");
        if(s_cycle >= InCycles)
        {
            Print("[SWITCH-AUDIT-SUMMARY] waves=", s_cycle + 1, " origTf=", s_origTf, " DONE");
            StateClear();
            ExpertRemove();
            return;
        }
        s_cycle++;
        s_step = -1;                     // the next advance lands on step 0
        s_phase = 1;
        s_deadlineMs = (long)GetTickCount() + 500;
        StateSave();
        return;
    }
    StateSave();
}
