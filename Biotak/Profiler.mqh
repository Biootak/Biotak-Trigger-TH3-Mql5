#ifndef TH3_PROFILER_MQH
#define TH3_PROFILER_MQH

// Compile-time lightweight profiler (no inputs, no behavior change when disabled).
// Enable by defining ENABLE_TH3_PROFILER (no numeric expression needed).

#ifdef ENABLE_TH3_PROFILER

#define TH3_PROF_MAX_TAGS 64

struct STH3ProfTag {
    string name;
    long totalMs;
    int count;
    int maxMs;
    datetime lastPrint;
    uint startMs;
    bool running;
    bool used;
};

static STH3ProfTag g_th3ProfTags[TH3_PROF_MAX_TAGS];
static bool g_th3ProfInit = false;

void TH3ProfInitOnce() {
    if(g_th3ProfInit) return;
    for(int i = 0; i < TH3_PROF_MAX_TAGS; i++) {
        g_th3ProfTags[i].name = "";
        g_th3ProfTags[i].totalMs = 0;
        g_th3ProfTags[i].count = 0;
        g_th3ProfTags[i].maxMs = 0;
        g_th3ProfTags[i].lastPrint = 0;
        g_th3ProfTags[i].startMs = 0;
        g_th3ProfTags[i].running = false;
        g_th3ProfTags[i].used = false;
    }
    g_th3ProfInit = true;
}

int TH3ProfFindOrAddTag(const string name) {
    TH3ProfInitOnce();

    // Find existing
    for(int i = 0; i < TH3_PROF_MAX_TAGS; i++) {
        if(g_th3ProfTags[i].used && g_th3ProfTags[i].name == name) return i;
    }

    // Add new
    for(int i = 0; i < TH3_PROF_MAX_TAGS; i++) {
        if(!g_th3ProfTags[i].used) {
            g_th3ProfTags[i].used = true;
            g_th3ProfTags[i].name = name;
            g_th3ProfTags[i].totalMs = 0;
            g_th3ProfTags[i].count = 0;
            g_th3ProfTags[i].maxMs = 0;
            g_th3ProfTags[i].lastPrint = 0;
            return i;
        }
    }

    // No space: reuse slot 0 (deterministic, avoids allocations)
    return 0;
}

uint TH3ProfNowMs() {
    return GetTickCount();
}

// Start/Stop by tag name (no local variables, avoids macro token-pasting).
void TH3ProfStartTag(const string tag) {
    int idx = TH3ProfFindOrAddTag(tag);
    g_th3ProfTags[idx].startMs = TH3ProfNowMs();
    g_th3ProfTags[idx].running = true;
}

void TH3ProfEndTag(const string tag) {
    int idx = TH3ProfFindOrAddTag(tag);
    if(!g_th3ProfTags[idx].running) return;

    uint endMs = TH3ProfNowMs();
    int elapsed = (int)(endMs - g_th3ProfTags[idx].startMs);
    g_th3ProfTags[idx].running = false;

    g_th3ProfTags[idx].totalMs += elapsed;
    g_th3ProfTags[idx].count += 1;
    if(elapsed > g_th3ProfTags[idx].maxMs) g_th3ProfTags[idx].maxMs = elapsed;

    // Print at most once per 5 seconds per tag to avoid log spam
    datetime now = TimeCurrent();
    if(g_th3ProfTags[idx].lastPrint == 0 || (now - g_th3ProfTags[idx].lastPrint) >= 5) {
        double avg = (g_th3ProfTags[idx].count > 0) ? ((double)g_th3ProfTags[idx].totalMs / (double)g_th3ProfTags[idx].count) : 0.0;
        Print("[PROF] ", tag,
              " | count=", g_th3ProfTags[idx].count,
              " avg=", DoubleToString(avg, 2), "ms",
              " max=", g_th3ProfTags[idx].maxMs, "ms");
        g_th3ProfTags[idx].lastPrint = now;
    }
}

// Convenience macros (MQL-safe)
#define TH3_PROF_START(tag) TH3ProfStartTag(#tag)
#define TH3_PROF_END(tag)   TH3ProfEndTag(#tag)

#else

#define TH3_PROF_START(tag)
#define TH3_PROF_END(tag)

#endif // ENABLE_TH3_PROFILER

#endif // TH3_PROFILER_MQH
