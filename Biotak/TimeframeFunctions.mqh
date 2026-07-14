  #property strict

int GetCurrentTimeframePeriodForTH()
{
    return (g_timeframeLocked && g_lockedPeriod > 0) ? g_lockedPeriod : Period();
}

int GetCurrentTimeframeMinutesForTH()
{
    int timeframe = GetCurrentTimeframePeriodForTH();
    int minutes = PeriodMinutes((ENUM_TIMEFRAMES)timeframe);
    if(minutes <= 0 && timeframe > 0 && timeframe <= 10080) minutes = timeframe;
    if(minutes <= 0 && timeframe == PERIOD_MN1) minutes = 43200;
    return minutes;
}

// PERF: Per-frame cached current timeframe string. GetCurrentTimeframe() is called
// multiple times per redraw (ExecutePipeline, objectPrefix building, label placement)
// and each call rebuilds the string via switch + minute math. Cache it per-frame.
static string g_cachedTFStr = "";
static datetime g_cachedTFStrFrame = 0;

string GetCurrentTimeframe() {
    // Invalidate cache if the cached period differs from the live one.
    static int s_cachedTFPeriod = -1;
    int livePeriod = GetCurrentTimeframePeriodForTH();
    if(g_cachedTFStrFrame != CacheGetFrameTime() || s_cachedTFPeriod != livePeriod) {
        s_cachedTFPeriod = livePeriod;
        g_cachedTFStrFrame = CacheGetFrameTime();
        g_cachedTFStr = GetCurrentTimeframeUncached();
    }
    return g_cachedTFStr;
}

string GetCurrentTimeframeUncached() {
    int timeframe = GetCurrentTimeframePeriodForTH();
    switch(timeframe) {
        case PERIOD_M1:return "M1";
        case PERIOD_M5:return "M5";
        case PERIOD_M15:return "M15";
        case PERIOD_M30:return "M30";
        case PERIOD_H1:return "H1";
        case PERIOD_H4:return "H4";
        case PERIOD_D1:return "D1";
        case PERIOD_W1:return "W1";
        case PERIOD_MN1:return "MN1";
        default:
        {
            int minutes = GetCurrentTimeframeMinutesForTH();
            if(minutes > 0) return GetTimeframeStringFromMinutes(minutes);
            return "UNKNOWN";
        }
    }
}

//+------------------------------------------------------------------+
//| Get higher pattern timeframe (one fractal level up = 4x duration)|
//| For any timeframe, the higher pattern is exactly 4  the current |
//| For example: M15 -> H1 (60 minutes), M5 -> M20, H1 -> H4        |
//|                              (                      = 4      )  |
//+------------------------------------------------------------------+
string GetHigherPatternTimeframeString() {
    int currentMinutes = GetCurrentTimeframeMinutesForTH();
    if(currentMinutes <= 0) currentMinutes = 1;
    int higherMinutes = currentMinutes * 4;
    return GetTimeframeStringFromMinutes(higherMinutes);
}

//+------------------------------------------------------------------+
//| Convert minutes to timeframe string                             |
//|                                                                  |
//+------------------------------------------------------------------+
string GetTimeframeStringFromMinutes(int minutes) {
    // Map to standard timeframes
    if(minutes == 4) return "M4";
    if(minutes == 20) return "M20";
    if(minutes == 60) return "H1";
    if(minutes == 120) return "H2";
    if(minutes == 240) return "H4";
    if(minutes == 1440) return "D1";
    if(minutes == 10080) return "W1";
    if(minutes == 43200) return "MN1";
    
    // For non-standard timeframes, return formatted string
    if(minutes < 60) {
        return "M" + IntegerToString(minutes);
    } else if(minutes < 1440) {
        int hours = minutes / 60;
        int remainingMinutes = minutes % 60;
        if(remainingMinutes == 0) {
            return "H" + IntegerToString(hours);
        } else {
            return "H" + IntegerToString(hours) + "+M" + IntegerToString(remainingMinutes);
        }
    } else if(minutes < 10080) {
        int days = minutes / 1440;
        int remainingHours = (minutes % 1440) / 60;
        if(remainingHours == 0) {
            return "D" + IntegerToString(days);
        } else {
            return "D" + IntegerToString(days) + "+H" + IntegerToString(remainingHours);
        }
    } else {
        int weeks = minutes / 10080;
        return "W" + IntegerToString(weeks);
    }
}

//+------------------------------------------------------------------+
//| Get higher pattern timeframe period (one fractal level up)      |
//| Returns ENUM_TIMEFRAMES value for the higher pattern timeframe  |
//+------------------------------------------------------------------+
int GetHigherPatternTimeframePeriod() {
    int currentMinutes = GetCurrentTimeframeMinutesForTH();
    if(currentMinutes <= 0) currentMinutes = 1;
    int higherMinutes = currentMinutes * 4;
    
    // Map to ENUM_TIMEFRAMES
    if(higherMinutes == 1) return PERIOD_M1;
    if(higherMinutes == 5) return PERIOD_M5;
    if(higherMinutes == 15) return PERIOD_M15;
    if(higherMinutes == 30) return PERIOD_M30;
    if(higherMinutes == 60) return PERIOD_H1;
    if(higherMinutes == 240) return PERIOD_H4;
    if(higherMinutes == 1440) return PERIOD_D1;
    if(higherMinutes == 10080) return PERIOD_W1;
    if(higherMinutes >= 43200) return PERIOD_MN1;
    
    // For non-standard timeframes, return closest standard timeframe
    if(higherMinutes < 5) return PERIOD_M1;
    if(higherMinutes < 15) return PERIOD_M5;
    if(higherMinutes < 30) return PERIOD_M15;
    if(higherMinutes < 60) return PERIOD_M30;
    if(higherMinutes < 240) return PERIOD_H1;
    if(higherMinutes < 1440) return PERIOD_H4;
    if(higherMinutes < 10080) return PERIOD_D1;
    return PERIOD_W1;
}
