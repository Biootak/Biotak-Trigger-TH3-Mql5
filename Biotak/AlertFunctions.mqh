#ifndef ALERT_FUNCTIONS_MQH
#define ALERT_FUNCTIONS_MQH

// PERF: Pre-allocated static buffer to avoid per-tick dynamic allocation in
// the CopyTime calls below (replaces 2 iTime() syscalls in this file).
static datetime s_alertBarTimeBuf[];
static bool     s_alertBarTimeBufInit = false;

// PERF: Cached name prefixes — objectPrefix is constant per chart, so 4 string
// concatenations are reduced to 1 string compare per CheckAlerts call.
static string s_cachedObjPrefix   = "";
static string s_cachedPrefix      = "";
static string s_cachedLineNameMid = "";
static string s_cachedPrefixUp    = "";
static string s_cachedPrefixDown  = "";

datetime GetCurrentBarTime()
{
    if(!s_alertBarTimeBufInit) {
        ArrayResize(s_alertBarTimeBuf, 1);
        s_alertBarTimeBufInit = true;
    }
    if(CopyTime(_Symbol, (ENUM_TIMEFRAMES)GetCachedPeriod(), 0, 1, s_alertBarTimeBuf) <= 0)
        return 0;
    return s_alertBarTimeBuf[0];
}

bool ShouldTriggerAlert(const string levelName, const datetime currentBarTime = 0) {
    if(!inpAlertOnce) return true;
    datetime barTime = currentBarTime;
    if(barTime <= 0) barTime = GetCurrentBarTime();
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
    datetime currentBarTime = inpAlertOnce ? GetCurrentBarTime() : 0;

    // High/Low alerts (skip in Custom Price mode)
    if(inpEnableHighLowAlerts && g_thStartPointType != TH_START_POINT_CUSTOM_PRICE) {
        if(currentPrice >= g_highestHigh && ShouldTriggerAlert("HistoricalHigh", currentBarTime))
            TriggerAlert("Price reached Historical High: " + DoubleToString(g_highestHigh, GetCachedDigits()));
    if(currentPrice <= g_lowestLow && ShouldTriggerAlert("HistoricalLow", currentBarTime))
            TriggerAlert("Price reached Historical Low: " + DoubleToString(g_lowestLow, GetCachedDigits()));
    }

    // TH Level alerts
    if(inpEnableTHAlerts && IsTriggerLevelsEnabled()) {
        if(objectPrefix != s_cachedObjPrefix) {
            s_cachedObjPrefix   = objectPrefix;
            s_cachedPrefix      = objectPrefix + "TH_Level_";
            s_cachedLineNameMid = s_cachedPrefix + "Mid";
            s_cachedPrefixUp    = s_cachedPrefix + "TriggerTH_Up_";
            s_cachedPrefixDown  = s_cachedPrefix + "TriggerTH_Down_";
        }
        string prefix = s_cachedPrefix;
    string lineNameMid = s_cachedLineNameMid;
    double midpointLevel = ObjectGetDouble(0, lineNameMid, OBJPROP_PRICE, 0);
    if(IsValidPrice(midpointLevel) && MathAbs(currentPrice - midpointLevel) < GetCachedPoint()) {
        if(ShouldTriggerAlert("MidpointLevel", currentBarTime))
                TriggerAlert("Price reached Midpoint: " + DoubleToString(midpointLevel, GetCachedDigits()));
        }
    int maxLevels = MathMin(inpMaxLevels, MAX_SAFE_LEVELS);
    if(maxLevels < inpMaxLevels)
        _LOG_GATE_W Print("[W][ALERT] Alert loop capped at MAX_SAFE_LEVELS=", MAX_SAFE_LEVELS, " (requested=", inpMaxLevels, ")");
    // PERF: Cache prefix substring + step strings outside conditionals
    string prefixUp = s_cachedPrefixUp;
    string prefixDown = s_cachedPrefixDown;
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
    if(IsValidPrice(lvl) && currentPrice >= lvl) {
        string key = "TriggerTH_Up_" + stepStr;
    if(ShouldTriggerAlert(key, currentBarTime))
                            TriggerAlert("Price reached TH Up " + stepStr + ": " + DoubleToString(lvl, GetCachedDigits()));
                    }
                }
        string nameBelow = prefixDown + stepStr;
    if(CacheObjectExists(nameBelow)) {
        foundBelow = true;
        double lvl = ObjectGetDouble(0, nameBelow, OBJPROP_PRICE, 0);
    if(IsValidPrice(lvl) && currentPrice <= lvl) {
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