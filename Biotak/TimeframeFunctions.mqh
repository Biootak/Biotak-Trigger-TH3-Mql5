#ifndef TIMEFRAME_FUNCTIONS_MQH
#define TIMEFRAME_FUNCTIONS_MQH

string GetCurrentTimeframe() {
        int timeframe = (g_timeframeLocked && g_lockedPeriod > 0) ? g_lockedPeriod : GetCachedPeriod();
    switch(timeframe) {
        case PERIOD_M1:  return "M1";   case PERIOD_M2:  return "M2";
    case PERIOD_M3:  return "M3";   case PERIOD_M4:  return "M4";
    case PERIOD_M5:  return "M5";   case PERIOD_M6:  return "M6";
    case PERIOD_M10: return "M10";  case PERIOD_M12: return "M12";
    case PERIOD_M15: return "M15";  case PERIOD_M20: return "M20";
    case PERIOD_M30: return "M30";  case PERIOD_H1:  return "H1";
    case PERIOD_H2:  return "H2";   case PERIOD_H3:  return "H3";
    case PERIOD_H4:  return "H4";   case PERIOD_H6:  return "H6";
    case PERIOD_H8:  return "H8";   case PERIOD_H12: return "H12";
    case PERIOD_D1:  return "D1";   case PERIOD_W1:  return "W1";
    case PERIOD_MN1: return "MN1";
    default: return "UNKNOWN";
    }
}
    string GetHigherPatternTimeframeString() {
        int currentMinutes = (g_timeframeLocked && g_lockedPeriod > 0) ? PeriodMinutes((ENUM_TIMEFRAMES)g_lockedPeriod) : PeriodMinutes();
    return GetTimeframeStringFromMinutes(currentMinutes * 4);
}
    string GetTimeframeStringFromMinutes(int minutes) {
        if(minutes == 4) return "M4";
    if(minutes == 20) return "M20";
    if(minutes == 60) return "H1";
    if(minutes == 120) return "H2";
    if(minutes == 240) return "H4";
    if(minutes == 1440) return "D1";
    if(minutes == 10080) return "W1";
    if(minutes == 43200) return "MN1";
    if(minutes < 60) return "M" + IntegerToString(minutes);
    if(minutes < 1440) {
        int hours = minutes / 60;
    int rem = minutes % 60;
    return rem == 0 ? "H" + IntegerToString(hours) : "H" + IntegerToString(hours) + "+M" + IntegerToString(rem);
    }
    if(minutes < 10080) {
        int days = minutes / 1440;
    int remH = (minutes % 1440) / 60;
    return remH == 0 ? "D" + IntegerToString(days) : "D" + IntegerToString(days) + "+H" + IntegerToString(remH);
    }
    return "W" + IntegerToString(minutes / 10080);
}

//+------------------------------------------------------------------+
//| Convert minutes to nearest ENUM_TIMEFRAMES (DRY helper)          |
//| Replaces 6+ duplicate if/else chains across the codebase        |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES MinutesToTimeframe(int minutes) {
    if(minutes <= 1)      return PERIOD_M1;
    if(minutes <= 5)      return PERIOD_M5;
    if(minutes <= 15)     return PERIOD_M15;
    if(minutes <= 30)     return PERIOD_M30;
    if(minutes <= 60)     return PERIOD_H1;
    if(minutes <= 240)    return PERIOD_H4;
    if(minutes <= 1440)   return PERIOD_D1;
    if(minutes <= 10080)  return PERIOD_W1;
    return PERIOD_MN1;
}

//+------------------------------------------------------------------+
//| Convert minutes to fractal timeframe string (DRY helper)         |
//| Maps chart period minutes to TH fractal names                   |
//+------------------------------------------------------------------+
string MinutesToFractalString(int minutes) {
    if(minutes <= 1)      return "M1";
    if(minutes <= 5)      return "M4";
    if(minutes <= 15)     return "M16";
    if(minutes <= 30)     return "M16";
    if(minutes <= 60)     return "H1+M4";
    if(minutes <= 240)    return "H4+M16";
    if(minutes <= 1440)   return "D2+H20+M16";
    if(minutes <= 10080)  return "D11+H9+M4";
    return "D45+H12+M16";
}

    int GetHigherPatternTimeframePeriod() {
        int currentMinutes = (g_timeframeLocked && g_lockedPeriod > 0) ? PeriodMinutes((ENUM_TIMEFRAMES)g_lockedPeriod) : PeriodMinutes();
    int higherMinutes = currentMinutes * 4;
    return (int)MinutesToTimeframe(higherMinutes);
}
    #endif
    // TIMEFRAME_FUNCTIONS_MQH