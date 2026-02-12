#ifndef ALERT_FUNCTIONS_MQH
#define ALERT_FUNCTIONS_MQH

bool ShouldTriggerAlert(const string levelName, const datetime currentBarTime = 0) {
    if(!inpAlertOnce) return true;
    datetime barTime = currentBarTime;
    if(barTime <= 0) barTime = iTime(_Symbol, Period(), 0);
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
    datetime currentBarTime = inpAlertOnce ? iTime(_Symbol, Period(), 0) : 0;

    // High/Low alerts (skip in Custom Price mode)
    if(inpEnableHighLowAlerts && g_thStartPointType != TH_START_POINT_CUSTOM_PRICE) {
        if(currentPrice >= g_highestHigh && ShouldTriggerAlert("HistoricalHigh", currentBarTime))
            TriggerAlert("Price reached Historical High: " + DoubleToString(g_highestHigh, Digits));
    if(currentPrice <= g_lowestLow && ShouldTriggerAlert("HistoricalLow", currentBarTime))
            TriggerAlert("Price reached Historical Low: " + DoubleToString(g_lowestLow, Digits));
    }

    // TH Level alerts
    if(inpEnableTHAlerts && IsTriggerLevelsEnabled()) {
        string prefix = objectPrefix + "TH_Level_";
    string lineNameMid = prefix + "Mid";
    double midpointLevel = ObjectGetDouble(0, lineNameMid, OBJPROP_PRICE, 0);
    if(midpointLevel != EMPTY_VALUE && MathAbs(currentPrice - midpointLevel) < Point) {
        if(ShouldTriggerAlert("MidpointLevel", currentBarTime))
                TriggerAlert("Price reached Midpoint: " + DoubleToString(midpointLevel, Digits));
        }
    int maxLevels = MathMin(inpMaxLevels, 256);
    // PERF: Cache prefix substring + step strings outside conditionals
    string prefixUp = prefix + "TriggerTH_Up_";
    string prefixDown = prefix + "TriggerTH_Down_";
    for(int step = 1; step <= maxLevels; step++) {
        string stepStr = IntegerToString(step);
        string nameAbove = prefixUp + stepStr;
    if(CacheObjectExists(nameAbove)) {
        double lvl = ObjectGetDouble(0, nameAbove, OBJPROP_PRICE, 0);
    if(lvl != EMPTY_VALUE && currentPrice >= lvl) {
        string key = "TriggerTH_Up_" + stepStr;
    if(ShouldTriggerAlert(key, currentBarTime))
                            TriggerAlert("Price reached TH Up " + stepStr + ": " + DoubleToString(lvl, Digits));
                    }
                }
        string nameBelow = prefixDown + stepStr;
    if(CacheObjectExists(nameBelow)) {
        double lvl = ObjectGetDouble(0, nameBelow, OBJPROP_PRICE, 0);
    if(lvl != EMPTY_VALUE && currentPrice <= lvl) {
        string key = "TriggerTH_Down_" + stepStr;
    if(ShouldTriggerAlert(key, currentBarTime))
                            TriggerAlert("Price reached TH Down " + stepStr + ": " + DoubleToString(lvl, Digits));
                    }
                }
        }
    }
}
    #endif
    // ALERT_FUNCTIONS_MQH