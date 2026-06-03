#ifndef ALERT_FUNCTIONS_MQH
#define ALERT_FUNCTIONS_MQH

bool ShouldTriggerAlert(const string levelName, const datetime currentBarTime = 0) {
    if(!inpAlertOnce) return true;
    datetime barTime = currentBarTime;
    if(barTime <= 0) barTime = iTime(_Symbol, (ENUM_TIMEFRAMES)GetCachedPeriod(), 0);
    if(barTime > g_lastAlertTime || g_lastAlertLevel != levelName) {
        g_lastAlertTime = barTime;
    g_lastAlertLevel = levelName;
    return true;
    }
    return false;
}
    void TriggerAlert(const string message) {
        if(inpPlaySound) PlaySound(inpAlertSoundFile);
    if(inpSendNotification) SendNotification(message);
    if(inpSendEmail) SendMail("TH Indicator Alert", message);
    Alert(message);
}
    void CheckAlerts(const string objectPrefix, double currentPrice) {
        if(objectPrefix == "" || currentPrice <= 0) return;
    // PERF: Skip alert loop when price hasn't changed since last check
    static double s_lastAlertPrice = 0;
    if(MathAbs(currentPrice - s_lastAlertPrice) < GetCachedPoint() * 0.5) return;
    s_lastAlertPrice = currentPrice;
    datetime currentBarTime = inpAlertOnce ? iTime(_Symbol, (ENUM_TIMEFRAMES)GetCachedPeriod(), 0) : 0;

    // High/Low alerts (skip in Custom Price mode)
    if(inpEnableHighLowAlerts && g_thStartPointType != TH_START_POINT_CUSTOM_PRICE) {
        if(currentPrice >= g_highestHigh && ShouldTriggerAlert("HistoricalHigh", currentBarTime))
            TriggerAlert("Price reached Historical High: " + DoubleToString(g_highestHigh, GetCachedDigits()));
    if(currentPrice <= g_lowestLow && ShouldTriggerAlert("HistoricalLow", currentBarTime))
            TriggerAlert("Price reached Historical Low: " + DoubleToString(g_lowestLow, GetCachedDigits()));
    }

    // TH Level alerts
    if(inpEnableTHAlerts && IsTriggerLevelsEnabled()) {
        string prefix = objectPrefix + "TH_Level_";
    string lineNameMid = prefix + "Mid";
    double midpointLevel = ObjectGetDouble(0, lineNameMid, OBJPROP_PRICE, 0);
    if(midpointLevel != EMPTY_VALUE && MathAbs(currentPrice - midpointLevel) < GetCachedPoint()) {
        if(ShouldTriggerAlert("MidpointLevel", currentBarTime))
                TriggerAlert("Price reached Midpoint: " + DoubleToString(midpointLevel, GetCachedDigits()));
        }
    int maxLevels = MathMin(inpMaxLevels, 256);
    // PERF: Cache prefix substring + step strings outside conditionals
    string prefixUp = prefix + "TriggerTH_Up_";
    string prefixDown = prefix + "TriggerTH_Down_";
    // PERF: Track consecutive misses — if both Up and Down don't exist for
    // 2 consecutive steps, all higher steps won't exist either (levels are sequential).
    // This turns worst-case 512 hash lookups into ~2× actual_level_count.
    int consecutiveMisses = 0;
    for(int step = 1; step <= maxLevels; step++) {
        string stepStr = IntegerToString(step);
        string nameAbove = prefixUp + stepStr;
        bool foundAbove = false;
        bool foundBelow = false;
    if(CacheObjectExists(nameAbove)) {
        foundAbove = true;
        double lvl = ObjectGetDouble(0, nameAbove, OBJPROP_PRICE, 0);
    if(lvl != EMPTY_VALUE && currentPrice >= lvl) {
        string key = "TriggerTH_Up_" + stepStr;
    if(ShouldTriggerAlert(key, currentBarTime))
                            TriggerAlert("Price reached TH Up " + stepStr + ": " + DoubleToString(lvl, GetCachedDigits()));
                    }
                }
        string nameBelow = prefixDown + stepStr;
    if(CacheObjectExists(nameBelow)) {
        foundBelow = true;
        double lvl = ObjectGetDouble(0, nameBelow, OBJPROP_PRICE, 0);
    if(lvl != EMPTY_VALUE && currentPrice <= lvl) {
        string key = "TriggerTH_Down_" + stepStr;
    if(ShouldTriggerAlert(key, currentBarTime))
                            TriggerAlert("Price reached TH Down " + stepStr + ": " + DoubleToString(lvl, GetCachedDigits()));
                    }
                }
        // PERF: Early exit — levels are sequential, so if neither Up nor Down exists
        // for 2 consecutive steps, no higher levels exist
        if(!foundAbove && !foundBelow) {
            consecutiveMisses++;
            if(consecutiveMisses >= 2) break;
        } else {
            consecutiveMisses = 0;
        }
        }
    }
}
    #endif
    // ALERT_FUNCTIONS_MQH