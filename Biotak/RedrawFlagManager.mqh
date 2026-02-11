#ifndef REDRAW_FLAG_MANAGER_MQH
#define REDRAW_FLAG_MANAGER_MQH

bool IsRedrawNeeded()           { return g_redrawNeeded; }
void SetRedrawFlag(bool needed) { g_redrawNeeded = needed; }
void ClearRedrawFlag()          { g_redrawNeeded = false; }
void RequestRedraw()            { g_redrawNeeded = true; }
bool ShouldSkipRedraw()         { return !g_redrawNeeded; }
    #endif
    // REDRAW_FLAG_MANAGER_MQH