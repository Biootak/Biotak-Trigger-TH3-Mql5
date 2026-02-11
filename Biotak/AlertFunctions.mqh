#ifndef ALERT_FUNCTIONS_MQH
#define ALERT_FUNCTIONS_MQH

bool ShouldTriggerAlert(const string levelName) {
    if(!inpAlertOnce) return true;
    datetime currentBarTime = iTime(_Symbol, Period(), 0);
    if(currentBarTime > g_lastAlertTime || g_lastAlertLevel != levelName) {
        g_lastAlertTime = currentBarTime;
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

    // High/Low alerts (skip in Custom Price mode)
    if(inpEnableHighLowAlerts && g_thStartPointType != TH_START_POINT_CUSTOM_PRICE) {
        if(currentPrice >= g_highestHigh && ShouldTriggerAlert("HistoricalHigh"))
            TriggerAlert("Price reached Historical High: " + DoubleToString(g_highestHigh, Digits));
    if(currentPrice <= g_lowestLow && ShouldTriggerAlert("HistoricalLow"))
            TriggerAlert("Price reached Historical Low: " + DoubleToString(g_lowestLow, Digits));
    }

    // TH Level alerts
    if(inpEnableTHAlerts && IsTriggerLevelsEnabled()) {
        string prefix = objectPrefix + "TH_Level_";
    string lineNameMid = prefix + "Mid";
    double midpointLevel = ObjectGetDouble(0, lineNameMid, OBJPROP_PRICE, 0);
    if(midpointLevel != EMPTY_VALUE && MathAbs(currentPrice - midpointLevel) < Point) {
        if(ShouldTriggerAlert("MidpointLevel"))
                TriggerAlert("Price reached Midpoint: " + DoubleToString(midpointLevel, Digits));
        }
    int maxLevels = MathMin(inpMaxLevels, 256);
    for(int step = 1; step <= maxLevels; step++) {
        if(step <= inpMaxLevels) {
        string nameAbove = prefix + "TriggerTH_Up_" + IntegerToString(step);
    if(CacheObjectExists(nameAbove)) {
        double lvl = ObjectGetDouble(0, nameAbove, OBJPROP_PRICE, 0);
    if(lvl != EMPTY_VALUE && currentPrice >= lvl) {
        string key = "TriggerTH_Up_" + IntegerToString(step);
    if(ShouldTriggerAlert(key))
                            TriggerAlert("Price reached TH Up " + IntegerToString(step) + ": " + DoubleToString(lvl, Digits));
                    }
                }
            }
    if(step <= inpMaxLevels) {
        string nameBelow = prefix + "TriggerTH_Down_" + IntegerToString(step);
    if(CacheObjectExists(nameBelow)) {
        double lvl = ObjectGetDouble(0, nameBelow, OBJPROP_PRICE, 0);
    if(lvl != EMPTY_VALUE && currentPrice <= lvl) {
        string key = "TriggerTH_Down_" + IntegerToString(step);
    if(ShouldTriggerAlert(key))
                            TriggerAlert("Price reached TH Down " + IntegerToString(step) + ": " + DoubleToString(lvl, Digits));
                    }
                }
            }
        }
    }
}
    #endif
    // ALERT_FUNCTIONS_MQH