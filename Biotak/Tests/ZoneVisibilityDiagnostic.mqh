//+------------------------------------------------------------------+
//|                                   ZoneVisibilityDiagnostic.mqh   |
//|                                  Zone Visibility Diagnostic Tool |
//|                                  Helps diagnose zone display issues|
//+------------------------------------------------------------------+
#property copyright "Biotak Project"
#property link      "https://www.mql5.com"

//+------------------------------------------------------------------+
//| Run Complete Zone Visibility Diagnostic                          |
//| تشخیص کامل مشکلات نمایش زون                                      |
//+------------------------------------------------------------------+
void RunZoneVisibilityDiagnostic()
{
    Print("═══════════════════════════════════════════════════════════");
    Print("ZONE VISIBILITY DIAGNOSTIC");
    Print("═══════════════════════════════════════════════════════════");
    
    // 1. Check current timeframe
    Print("1. TIMEFRAME CHECK:");
    Print("   Current Period: ", Period());
    Print("   Period Minutes: ", PeriodMinutes());
    Print("   Period Seconds: ", PeriodSeconds());
    
    // 2. Check zone configuration
    Print("");
    Print("2. ZONE CONFIGURATION:");
    Print("   inpShowMidZones: ", (inpShowMidZones ? "TRUE" : "FALSE"));
    Print("   inpMidZoneStyle: ", EnumToString(inpMidZoneStyle));
    Print("   inpMidZoneTransparency: ", inpMidZoneTransparency);
    Print("   inpMidZoneHeightPercent: ", inpMidZoneHeightPercent);
    
    // 3. Check visibility states
    Print("");
    Print("3. VISIBILITY STATES:");
    Print("   IsIndicatorHidden(): ", (IsIndicatorHidden() ? "TRUE (F key pressed)" : "FALSE"));
    Print("   g_linesVisible: ", (g_linesVisible ? "TRUE" : "FALSE (L key pressed)"));
    
    // 4. Check unified zone config
    SUnifiedZoneConfig config = GetUnifiedZoneConfig();
    Print("");
    Print("4. UNIFIED ZONE CONFIG:");
    Print("   enabled: ", (config.enabled ? "TRUE" : "FALSE"));
    Print("   transparency: ", config.transparency);
    Print("   heightPercent: ", config.heightPercent);
    Print("   style: ", EnumToString(config.style));
    
    // 5. Count existing zone objects
    Print("");
    Print("5. EXISTING ZONE OBJECTS:");
    int totalObjects = ObjectsTotal(0, -1, -1);
    int zoneCount = 0;
    int visibleZoneCount = 0;
    
    for(int i = 0; i < totalObjects; i++) {
        string objName = ObjectName(0, i, -1, -1);
        if(StringFind(objName, "Zone") >= 0) {
            zoneCount++;
            long timeframes = ObjectGetInteger(0, objName, OBJPROP_TIMEFRAMES);
            if(timeframes == OBJ_ALL_PERIODS) {
                visibleZoneCount++;
            }
        }
    }
    
    Print("   Total Objects: ", totalObjects);
    Print("   Zone Objects: ", zoneCount);
    Print("   Visible Zones: ", visibleZoneCount);
    Print("   Hidden Zones: ", (zoneCount - visibleZoneCount));
    
    // 6. Check bars availability
    Print("");
    Print("6. CHART DATA:");
    Print("   Bars Available: ", Bars(_Symbol, _Period));
    Print("   Current Time: ", TimeToString(TimeCurrent()));
    
    // 7. Recommendations
    Print("");
    Print("7. DIAGNOSTIC RESULTS:");
    
    if(!inpShowMidZones) {
        Print("   ❌ PROBLEM: inpShowMidZones is FALSE");
        Print("   → SOLUTION: Enable 'Show Mid Zones' in indicator settings");
    }
    
    if(config.style == ZONE_STYLE_HIDDEN) {
        Print("   ❌ PROBLEM: Zone style is set to HIDDEN");
        Print("   → SOLUTION: Change 'Mid Zone Style' to BOX_FILLED or LINES");
    }
    
    if(IsIndicatorHidden()) {
        Print("   ❌ PROBLEM: Indicator is hidden (F key pressed)");
        Print("   → SOLUTION: Press F key to show indicator");
    }
    
    if(zoneCount == 0) {
        Print("   ❌ PROBLEM: No zone objects found on chart");
        Print("   → SOLUTION: Zones are not being created. Check if levels are being drawn.");
    }
    else if(visibleZoneCount == 0 && zoneCount > 0) {
        Print("   ❌ PROBLEM: Zones exist but all are hidden");
        Print("   → SOLUTION: Check OBJPROP_TIMEFRAMES property");
    }
    else if(visibleZoneCount > 0) {
        Print("   ✅ SUCCESS: ", visibleZoneCount, " zones are visible");
    }
    
    if(Bars(_Symbol, _Period) < 10) {
        Print("   ⚠️ WARNING: Very few bars available (", Bars(_Symbol, _Period), ")");
        Print("   → Wait for more historical data to load");
    }
    
    Print("═══════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| List All Zone Objects with Details                               |
//| لیست تمام اشیاء زون با جزئیات                                    |
//+------------------------------------------------------------------+
void ListAllZoneObjects()
{
    Print("═══════════════════════════════════════════════════════════");
    Print("ALL ZONE OBJECTS:");
    Print("═══════════════════════════════════════════════════════════");
    
    int totalObjects = ObjectsTotal(0, -1, -1);
    int zoneCount = 0;
    
    for(int i = 0; i < totalObjects; i++) {
        string objName = ObjectName(0, i, -1, -1);
        if(StringFind(objName, "Zone") >= 0) {
            zoneCount++;
            
            long timeframes = ObjectGetInteger(0, objName, OBJPROP_TIMEFRAMES);
            datetime time1 = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME, 0);
            datetime time2 = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME, 1);
            double price1 = ObjectGetDouble(0, objName, OBJPROP_PRICE, 0);
            double price2 = ObjectGetDouble(0, objName, OBJPROP_PRICE, 1);
            color clr = (color)ObjectGetInteger(0, objName, OBJPROP_COLOR);
            
            string visibility = "UNKNOWN";
            if(timeframes == OBJ_ALL_PERIODS) visibility = "VISIBLE";
            else if(timeframes == OBJ_NO_PERIODS) visibility = "HIDDEN";
            else visibility = "CUSTOM";
            
            Print(zoneCount, ". ", objName);
            Print("   Visibility: ", visibility, " (", timeframes, ")");
            Print("   Time: ", TimeToString(time1), " - ", TimeToString(time2));
            Print("   Price: ", DoubleToString(price1, _Digits), " - ", DoubleToString(price2, _Digits));
            Print("   Color: ", ColorToString(clr));
        }
    }
    
    if(zoneCount == 0) {
        Print("No zone objects found.");
    }
    
    Print("═══════════════════════════════════════════════════════════");
}
