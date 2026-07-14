  #ifndef ALERT_FUNCTIONS_MQH
#define ALERT_FUNCTIONS_MQH

#property strict

// Helper function to check if alert should be triggered (prevents spam)
bool ShouldTriggerAlert(const string levelName) {
    if(!inpAlertOnce) return true; // Always trigger if AlertOnce is disabled
    
    datetime currentTime = TimeCurrent();
    datetime currentBarTime = iTime(Symbol(), Period(), 0);
    
    // Check if this is a new bar and different level than last alert
    if(currentBarTime > g_lastAlertTime || g_lastAlertLevel != levelName) {
        g_lastAlertTime = currentBarTime;
        g_lastAlertLevel = levelName;
        return true;
    }
    
    return false; // Same bar and same level, don't trigger
}

//                                       
void CheckAlerts(const string objectPrefix, double currentPrice) {
    //
    if(objectPrefix == "" || currentPrice <= 0) {
        Print("CheckAlerts: Invalid parameters - objectPrefix: ", objectPrefix, ", currentPrice: ", currentPrice);
        return;
    }

    //                   /
    // Skip High/Low alerts when Custom Price mode is active
    if(inpEnableHighLowAlerts && g_thStartPointType != TH_START_POINT_CUSTOM_PRICE) {
        if(currentPrice >= g_highestHigh && ShouldTriggerAlert("HistoricalHigh")) {
            if(inpPlaySound) PlaySound(inpAlertSoundFile);
            if(inpSendNotification) SendNotification("Price reached Historical High Level: " + DoubleToString(g_highestHigh, Digits));
            if(inpSendEmail) SendMail("TH Indicator Alert", "Price reached Historical High Level: " + DoubleToString(g_highestHigh, Digits));
            Alert("Price reached Historical High Level: ", g_highestHigh);
        }
        if(currentPrice <= g_lowestLow && ShouldTriggerAlert("HistoricalLow")) {
            if(inpPlaySound) PlaySound(inpAlertSoundFile);
            if(inpSendNotification) SendNotification("Price reached Historical Low Level: " + DoubleToString(g_lowestLow, Digits));
            if(inpSendEmail) SendMail("TH Indicator Alert", "Price reached Historical Low Level: " + DoubleToString(g_lowestLow, Digits));
            Alert("Price reached Historical Low Level: ", g_lowestLow);
        }
    }

    //               TH
    if(!inpEnableTHAlerts || !IsTriggerLevelsEnabled()) return;

    // PERF (2026): prefer the in-memory trigger level cache populated by
    // DrawTHLevels / RenderTriggerLines. Falls back to the legacy
    // ObjectFind+ObjectGetDouble loop only when the cache is empty
    // (e.g. before the first redraw completes, or in Custom-Price modes
    // that do not draw standard trigger lines).
    bool usedCache = false;

    // Midpoint check (from cache when available)
    if(HasMidpointLevel()) {
        usedCache = true;
        double midpointLevel = GetMidpointLevel();
        if(MathAbs(currentPrice - midpointLevel) < Point) {
            if(ShouldTriggerAlert("MidpointLevel")) {
                if(inpPlaySound) PlaySound(inpAlertSoundFile);
                if(inpSendNotification) SendNotification("Price reached Trigger TH Midpoint Level: " + DoubleToString(midpointLevel, Digits));
                if(inpSendEmail) SendMail("TH Indicator Alert", "Price reached Trigger TH Midpoint Level: " + DoubleToString(midpointLevel, Digits));
                Alert("Price reached Trigger TH Midpoint Level: ", midpointLevel);
            }
        }
    } else {
        // Legacy fallback for midpoint
        string prefix = objectPrefix + "TH_Level_";
        string lineNameMid = prefix + "Mid";
        double midpointLevel = ObjectGetDouble(0, lineNameMid, OBJPROP_PRICE, 0);
        if(midpointLevel != EMPTY_VALUE && MathAbs(currentPrice - midpointLevel) < Point) {
            if(ShouldTriggerAlert("MidpointLevel")) {
                if(inpPlaySound) PlaySound(inpAlertSoundFile);
                if(inpSendNotification) SendNotification("Price reached Trigger TH Midpoint Level: " + DoubleToString(midpointLevel, Digits));
                if(inpSendEmail) SendMail("TH Indicator Alert", "Price reached Trigger TH Midpoint Level: " + DoubleToString(midpointLevel, Digits));
                Alert("Price reached Trigger TH Midpoint Level: ", midpointLevel);
            }
        }
    }

    // Above triggers (from cache when available)
    int upCount = GetTriggerUpCount();
    int downCount = GetTriggerDownCount();
    if(upCount > 0 || downCount > 0) usedCache = true;

    if(usedCache) {
        int limitUp = MathMin(upCount, inpMaxTHLevelsAbove);
        for(int i = 0; i < limitUp; i++) {
            double levelAbove = GetTriggerUpPrice(i);
            if(levelAbove > 0 && currentPrice >= levelAbove) {
                string alertKey = "TriggerTH_Up_" + IntegerToString(i + 1);
                if(ShouldTriggerAlert(alertKey)) {
                    if(inpPlaySound) PlaySound(inpAlertSoundFile);
                    if(inpSendNotification) SendNotification("Price reached Trigger TH Level Above " + IntegerToString(i + 1) + ": " + DoubleToString(levelAbove, Digits));
                    if(inpSendEmail) SendMail("TH Indicator Alert", "Price reached Trigger TH Level Above " + IntegerToString(i + 1) + ": " + DoubleToString(levelAbove, Digits));
                    Alert("Price reached Trigger TH Level Above: ", levelAbove);
                }
            }
        }

        int limitDown = MathMin(downCount, inpMaxTHLevelsBelow);
        for(int i = 0; i < limitDown; i++) {
            double levelBelow = GetTriggerDownPrice(i);
            if(levelBelow > 0 && currentPrice <= levelBelow) {
                string alertKey = "TriggerTH_Down_" + IntegerToString(i + 1);
                if(ShouldTriggerAlert(alertKey)) {
                    if(inpPlaySound) PlaySound(inpAlertSoundFile);
                    if(inpSendNotification) SendNotification("Price reached Trigger TH Level Below " + IntegerToString(i + 1) + ": " + DoubleToString(levelBelow, Digits));
                    if(inpSendEmail) SendMail("TH Indicator Alert", "Price reached Trigger TH Level Below " + IntegerToString(i + 1) + ": " + DoubleToString(levelBelow, Digits));
                    Alert("Price reached Trigger TH Level Below: ", levelBelow);
                }
            }
        }
        return;
    }

    // Legacy fallback: per-step ObjectFind + ObjectGetDouble loop.
    // Kept for any path that has not been migrated to populate the
    // in-memory cache yet.
    string prefix = objectPrefix + "TH_Level_";
    int maxLevelsToCheck = MathMin(inpMaxTHLevelsAbove, inpMaxTHLevelsBelow);
    maxLevelsToCheck = MathMin(maxLevelsToCheck, 256);

    for(int stepCount = 1; stepCount <= maxLevelsToCheck; stepCount++) {
        if(stepCount <= inpMaxTHLevelsAbove) {
            string lineNameAbove = prefix + "TriggerTH_Up_" + IntegerToString(stepCount);
            if(ObjectFind(0, lineNameAbove) >= 0) {
                double levelAbove = ObjectGetDouble(0, lineNameAbove, OBJPROP_PRICE, 0);
                if(levelAbove != EMPTY_VALUE && currentPrice >= levelAbove) {
                    string alertKey = "TriggerTH_Up_" + IntegerToString(stepCount);
                    if(ShouldTriggerAlert(alertKey)) {
                        if(inpPlaySound) PlaySound(inpAlertSoundFile);
                        if(inpSendNotification) SendNotification("Price reached Trigger TH Level Above " + IntegerToString(stepCount) + ": " + DoubleToString(levelAbove, Digits));
                        if(inpSendEmail) SendMail("TH Indicator Alert", "Price reached Trigger TH Level Above " + IntegerToString(stepCount) + ": " + DoubleToString(levelAbove, Digits));
                        Alert("Price reached Trigger TH Level Above: ", levelAbove);
                    }
                }
            }
        }

        if(stepCount <= inpMaxTHLevelsBelow) {
            string lineNameBelow = prefix + "TriggerTH_Down_" + IntegerToString(stepCount);
            if(ObjectFind(0, lineNameBelow) >= 0) {
                double levelBelow = ObjectGetDouble(0, lineNameBelow, OBJPROP_PRICE, 0);
                if(levelBelow != EMPTY_VALUE && currentPrice <= levelBelow) {
                    string alertKey = "TriggerTH_Down_" + IntegerToString(stepCount);
                    if(ShouldTriggerAlert(alertKey)) {
                        if(inpPlaySound) PlaySound(inpAlertSoundFile);
                        if(inpSendNotification) SendNotification("Price reached Trigger TH Level Below " + IntegerToString(stepCount) + ": " + DoubleToString(levelBelow, Digits));
                        if(inpSendEmail) SendMail("TH Indicator Alert", "Price reached Trigger TH Level Below " + IntegerToString(stepCount) + ": " + DoubleToString(levelBelow, Digits));
                        Alert("Price reached Trigger TH Level Below: ", levelBelow);
                    }
                }
            }
        }
    }
}
#endif // ALERT_FUNCTIONS_MQH
