  #ifndef TIMEFRAME_FUNCTIONS_MQH
#define TIMEFRAME_FUNCTIONS_MQH

#property strict

string GetCurrentTimeframe() {
    // R-TF-UNIT: `timeframe` is MINUTES on both platforms (MT5's Period() is
    // shimmed to minutes in MT5Compat). The case labels must therefore be
    // minute literals, not PERIOD_* constants: on MT4 the two are identical
    // (PERIOD_H1==60) so this changes nothing there, but on MT5 PERIOD_W1 is
    // 32769 while a weekly chart reports 10080 - the old labels missed every
    // TF above M30 and the function returned "UNKNOWN", which collapsed the
    // whole fractal ladder to M1-sized steps on H1+ charts.
    int timeframe = (g_timeframeLocked && g_lockedPeriod > 0) ? g_lockedPeriod : Period();
    switch(timeframe) {
        case 1:return "M1";
        case 5:return "M5";
        case 15:return "M15";
        case 30:return "M30";
        case 60:return "H1";
        case 240:return "H4";
        case 1440:return "D1";
        case 10080:return "W1";
        case 43200:return "MN1";
        default:return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| Get higher pattern timeframe (one fractal level up = 4x duration)|
//| For any timeframe, the higher pattern is exactly 4  the current |
//| For example: M15 -> H1 (60 minutes), M5 -> M20, H1 -> H4        |
//|                              (                      = 4      )  |
//+------------------------------------------------------------------+
string GetHigherPatternTimeframeString() {
    int currentPeriod = (g_timeframeLocked && g_lockedPeriod > 0) ? g_lockedPeriod : Period();
    int higherMinutes = currentPeriod * 4;
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
//| HIGHERPATTERN-OFF: retired 2026-09-16 (R-TF-UNIT sweep).          |
//|                                                                  |
//| Uncalled. `grep -rn GetHigherPatternTimeframePeriod` matches this  |
//| definition and nothing else, in either repository. It was also the |
//| one place left in the tree that returned a PERIOD_* constant from  |
//| a function whose own inputs and outputs are minutes - which reads |
//| as a live API to the next person and is a coin-flip to "fix".      |
//| The live path for "one fractal step up" is ResolvePatternHTFPeriod |
//| (HTFCandles.mqh), which is built on the minutes ladder.            |
//|                                                                  |
//| int GetHigherPatternTimeframePeriod() {                           |
//|     int currentPeriod = (g_timeframeLocked && g_lockedPeriod > 0)  |
//|                         ? g_lockedPeriod : Period();               |
//|     int higherMinutes = currentPeriod * 4;                         |
//|     if(higherMinutes == 1) return PERIOD_M1;                       |
//|     if(higherMinutes == 5) return PERIOD_M5;                       |
//|     if(higherMinutes == 15) return PERIOD_M15;                     |
//|     if(higherMinutes == 30) return PERIOD_M30;                     |
//|     if(higherMinutes == 60) return PERIOD_H1;                      |
//|     if(higherMinutes == 240) return PERIOD_H4;                     |
//|     if(higherMinutes == 1440) return PERIOD_D1;                    |
//|     if(higherMinutes == 10080) return PERIOD_W1;                   |
//|     if(higherMinutes >= 43200) return PERIOD_MN1;                  |
//|     if(higherMinutes < 5) return PERIOD_M1;                        |
//|     if(higherMinutes < 15) return PERIOD_M5;                       |
//|     if(higherMinutes < 30) return PERIOD_M15;                      |
//|     if(higherMinutes < 60) return PERIOD_M30;                      |
//|     if(higherMinutes < 240) return PERIOD_H1;                      |
//|     if(higherMinutes < 1440) return PERIOD_H4;                     |
//|     if(higherMinutes < 10080) return PERIOD_D1;                    |
//|     return PERIOD_W1;                                              |
//| }                                                                  |
//+------------------------------------------------------------------+

#endif // TIMEFRAME_FUNCTIONS_MQH
