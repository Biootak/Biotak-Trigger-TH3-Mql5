//+------------------------------------------------------------------+
//|                                                       ComboAudit.mq5 |
//|                          Combo calculation self-contained audit    |
//|                                                                    |
//| PURPOSE: Standalone script that re-implements the pure math from  |
//|          Biotak/ExtendedDrawingFunctions.mqh (CalculateComboStepSize,|
//|          ApplyComboOperation, GetTimeframeByType, GetStepMultiplier,|
//|          GetStepSizeForBasisType, GetComboConfiguration) WITHOUT   |
//|          depending on chart/indicator state, so we can verify the  |
//|          math with concrete numbers against expected values.      |
//|                                                                    |
//| HOW TO RUN:                                                        |
//|   1. Place this file in MT5 MQL5/Scripts/                         |
//|   2. Open MetaEditor, compile                                      |
//|   3. Attach to any chart -> it prints results to Experts log      |
//|                                                                    |
//| EXPECTED OUTPUT: See "EXPECTED RESULTS" at the bottom of this file |
//+------------------------------------------------------------------+
#property copyright "Audit"
#property script_show_inputs
#property strict

//+------------------------------------------------------------------+
//| Enums (copied verbatim from ConstantsAndEnums.mqh)               |
//+------------------------------------------------------------------+
enum ENUM_COMBO_OPERATION {
    COMBO_OP_AVERAGE    = 0,
    COMBO_OP_ADD        = 1,
    COMBO_OP_SUBTRACT   = 2,
    COMBO_OP_MULTIPLY   = 3,
    COMBO_OP_MIN        = 4,
    COMBO_OP_MAX        = 5,
    COMBO_OP_WEIGHTED   = 6,
    COMBO_OP_GEO_MEAN   = 7   // Audit fix #2: real geometric mean
};

enum ENUM_COMBO_TIMEFRAME_TYPE {
    COMBO_TF_SUB       = 0,
    COMBO_TF_TRIGGER   = 1,
    COMBO_TF_PATTERN   = 2,
    COMBO_TF_STRUCTURE = 3
};

enum ENUM_COMBO_STEP_TYPE {
    COMBO_STEP_TH = 0,
    COMBO_STEP_SS = 1,
    COMBO_STEP_LS = 2,
    COMBO_STEP_CONTROL = 3  // CONTROL/MID: TH * 1.75
};

enum ENUM_COMBO_PRESET {
    COMBO_PRESET_LEGACY_ADD              = 0,
    COMBO_PRESET_BALANCED_MEDIUM         = 1,
    COMBO_PRESET_BALANCED_LONG           = 2,
    COMBO_PRESET_BALANCED_TRIPLE         = 3,
    COMBO_PRESET_BALANCED_MIN            = 4,
    COMBO_PRESET_CONSERVATIVE             = 5,
    COMBO_PRESET_ULTRA_CONSERVATIVE       = 6,
    COMBO_PRESET_TRIPLE_CONSERVATIVE      = 7,
    COMBO_PRESET_AGGRESSIVE               = 8,
    COMBO_PRESET_ULTRA_AGGRESSIVE         = 9,
    COMBO_PRESET_TRIPLE_AGGRESSIVE        = 10,
    COMBO_PRESET_TREND_FILTER            = 11,
    COMBO_PRESET_VOLATILITY_ADAPTIVE     = 12,
    COMBO_PRESET_MANUAL_DUAL             = 13,
    COMBO_PRESET_MANUAL_TRIPLE           = 14,
    COMBO_PRESET_QT_TRIGGER_PATTERN      = 15,
    COMBO_PRESET_QT_ALL_4TF              = 16,
    COMBO_PRESET_QT_TRIGGER_PATTERN_STRUCTURE = 17,
    COMBO_PRESET_QT_PATTERN_STRUCTURE    = 18,
    COMBO_PRESET_QT_TRIGGER_ONLY         = 19
};

struct SComboConfig {
    int                    tf1;
    int                    step1;
    int                    tf2;
    int                    step2;
    int                    tf3;
    int                    step3;
    int                    operation;
    int                    activeComponents;
    bool                   isTriple;
    int                    weight1Percent;
    int                    weight2Percent;
};

//+------------------------------------------------------------------+
//| Step multiplier (copied from GetStepMultiplier)                  |
//+------------------------------------------------------------------+
double GetStepMultiplier(const int stepType) {
    if(stepType < 0 || stepType > 3) return 1.0;
    if(stepType == 0) return 1.0;  // TH
    if(stepType == 1) return 1.5;  // SS
    if(stepType == 2) return 2.0;  // LS
    return 1.75;                   // CONTROL/MID
}

//+------------------------------------------------------------------+
//| MOCK TH% per timeframe (real values come from indicator)         |
//| Using a deterministic lookup so tests are reproducible.           |
//+------------------------------------------------------------------+
double GetMockTHPercentage(const int tfMinutes) {
    // Realistic-ish values for a 2000-price instrument.
    // M1  -> 0.05
    // M5  -> 0.10
    // M15 -> 0.20
    // M30 -> 0.30
    // H1  -> 0.50
    // H4  -> 1.00
    // D1  -> 2.00
    // W1  -> 4.00
    // MN1 -> 8.00
    if(tfMinutes <= 1)   return 0.05;
    if(tfMinutes <= 5)   return 0.10;
    if(tfMinutes <= 15)  return 0.20;
    if(tfMinutes <= 30)  return 0.30;
    if(tfMinutes <= 60)  return 0.50;
    if(tfMinutes <= 240) return 1.00;
    if(tfMinutes <= 1440) return 2.00;
    if(tfMinutes <= 10080) return 4.00;
    return 8.00;
}

//+------------------------------------------------------------------+
//| GetTimeframeByType re-implementation (copied verbatim logic)      |
//+------------------------------------------------------------------+
int GetTimeframeByType(const int tfType, const int currentMinutes) {
    if(tfType < 0 || tfType > 3) return currentMinutes;

    if(tfType == 0) { // SUB: Current/16
        int subMin = currentMinutes / 16;
        if(subMin < 1) subMin = 1;
        return subMin;
    }
    if(tfType == 1) { // TRIGGER: Current/4
        int t = currentMinutes / 4;
        if(t < 1) t = 1;
        return t;
    }
    if(tfType == 2) { // PATTERN: Current
        return currentMinutes;
    }
    // STRUCTURE: Current*4
    return currentMinutes * 4;
}

//+------------------------------------------------------------------+
//| GetStepSizeForBasisType (copied verbatim)                        |
//+------------------------------------------------------------------+
double GetStepSizeForBasisType(const double basePrice, const double multiplier,
                                const int tfMinutes) {
    if(basePrice <= 0) return 0;
    if(multiplier <= 0 || multiplier > 10.0) return 0;
    double thPct = GetMockTHPercentage(tfMinutes);
    if(thPct <= 0) return 0;
    double thPriceUnits = (basePrice * thPct) / 100.0;
    if(thPriceUnits <= 0) return 0;
    return thPriceUnits * multiplier;
}

//+------------------------------------------------------------------+
//| ApplyComboOperation (copied verbatim logic from ExtendedDrawing) |
//+------------------------------------------------------------------+
double ApplyComboOperation(const double v1, const double v2, const int op,
                             const double w1 = 0.5, const double w2 = 0.5) {
    if(v1 <= 0 || v2 <= 0) return 0;
    double result = 0;
    switch(op) {
        case 0: // AVERAGE
            result = (v1 + v2) / 2.0;
            break;
        case 1: // ADD
            result = v1 + v2;
            break;
        case 2: { // SUBTRACT
            result = MathAbs(v1 - v2);
            double avg = (v1 + v2) / 2.0;
            double minTh = avg * 0.01;
            if(result < minTh) result = avg;
            break;
        }
        case 3: { // MULTIPLY
            result = v1 * v2;
            double maxIn = MathMax(v1, v2);
            if(result > maxIn * 100.0) result = maxIn;
            break;
        }
        case 4: // MIN
            result = MathMin(v1, v2);
            break;
        case 5: // MAX
            result = MathMax(v1, v2);
            break;
        case 6: { // WEIGHTED (normalized)
            if(w1 < 0 || w2 < 0) { result = (v1 + v2) / 2.0; break; }
            double sum = w1 + w2;
            if(sum <= 0) { result = (v1 + v2) / 2.0; break; }
            result = (v1 * w1 + v2 * w2) / sum;
            break;
        }
        case 7: { // GEO_MEAN (dual: sqrt(a*b))
            if(v1 <= 0 || v2 <= 0) { result = 0; break; }
            result = MathSqrt(v1 * v2);
            break;
        }
        default:
            result = (v1 + v2) / 2.0;
    }

    // Suspicious-result safety (copied from production code)
    double maxIn = MathMax(v1, v2);
    double minIn = MathMin(v1, v2);
    bool bad = false;
    if(op == 1 && result > maxIn * 2.5) bad = true;       // ADD
    if(op == 3 && result > maxIn * 100.0) bad = true;     // MULTIPLY
    if((op == 0 || op == 6) && (result < minIn*0.5 || result > maxIn*1.5)) bad = true;
    if(op == 2 && result > maxIn) bad = true;             // SUBTRACT
    if(op == 4 && result != minIn) bad = true;            // MIN
    if(op == 5 && result != maxIn) bad = true;            // MAX
    if(bad) result = (v1 + v2) / 2.0;

    return result;
}

//+------------------------------------------------------------------+
//| GetComboConfiguration (copied verbatim from production)          |
//+------------------------------------------------------------------+
void GetComboConfiguration(const int preset, SComboConfig &cfg) {
    // Defaults
    cfg.tf1 = 1; cfg.step1 = 0; // COMBO_TF_TRIGGER, COMBO_STEP_TH
    cfg.tf2 = 1; cfg.step2 = 0; cfg.tf2Active = false;
    cfg.tf3 = 1; cfg.step3 = 0; cfg.tf3Active = false;
    cfg.operation = 0; // AVERAGE
    cfg.activeComponents = 1;
    cfg.isTriple = false;

    switch(preset) {
        case 0: // LEGACY_ADD: Trigger SS + Pattern SS, ADD
            cfg.tf1 = 1; cfg.step1 = 1;
            cfg.tf2 = 2; cfg.step2 = 1; cfg.tf2Active = true;
            cfg.operation = 1; cfg.activeComponents = 2;
            break;
        case 1: // BALANCED_MEDIUM: Pattern TH + Trigger TH, AVERAGE
            cfg.tf1 = 2; cfg.step1 = 0;
            cfg.tf2 = 1; cfg.step2 = 0; cfg.tf2Active = true;
            cfg.operation = 0; cfg.activeComponents = 2;
            break;
        case 2: // BALANCED_LONG: Structure TH + Pattern TH, AVERAGE
            cfg.tf1 = 3; cfg.step1 = 0;
            cfg.tf2 = 2; cfg.step2 = 0; cfg.tf2Active = true;
            cfg.operation = 0; cfg.activeComponents = 2;
            break;
        case 3: // BALANCED_TRIPLE: Trigger+Pattern+Structure all TH, AVERAGE
            cfg.tf1 = 1; cfg.step1 = 0;
            cfg.tf2 = 2; cfg.step2 = 0; cfg.tf2Active = true;
            cfg.tf3 = 3; cfg.step3 = 0; cfg.tf3Active = true;
            cfg.operation = 0; cfg.activeComponents = 3; cfg.isTriple = true;
            break;
        case 4: // BALANCED_MIN: min(Pattern, Trigger) TH
            cfg.tf1 = 2; cfg.step1 = 0;
            cfg.tf2 = 1; cfg.step2 = 0; cfg.tf2Active = true;
            cfg.operation = 4; cfg.activeComponents = 2;
            break;
        case 5: // CONSERVATIVE: max(Structure, Pattern) TH
            cfg.tf1 = 3; cfg.step1 = 0;
            cfg.tf2 = 2; cfg.step2 = 0; cfg.tf2Active = true;
            cfg.operation = 5; cfg.activeComponents = 2;
            break;
        case 6: // ULTRA_CONSERVATIVE: Structure TH only
            cfg.tf1 = 3; cfg.step1 = 0;
            cfg.activeComponents = 1;
            break;
        case 7: // TRIPLE_CONSERVATIVE: max(Trigger,Pattern,Structure) TH
            cfg.tf1 = 1; cfg.step1 = 0;
            cfg.tf2 = 2; cfg.step2 = 0; cfg.tf2Active = true;
            cfg.tf3 = 3; cfg.step3 = 0; cfg.tf3Active = true;
            cfg.operation = 5; cfg.activeComponents = 3; cfg.isTriple = true;
            break;
        case 8: // AGGRESSIVE: Audit fix #7 -> triple min(P, T, Sub) TH
            cfg.tf1 = 2; cfg.step1 = 0;
            cfg.tf2 = 1; cfg.step2 = 0; cfg.tf2Active = true;
            cfg.tf3 = 0; cfg.step3 = 0; cfg.tf3Active = true;
            cfg.operation = 4; cfg.activeComponents = 3; cfg.isTriple = true;
            break;
        case 9: // ULTRA_AGGRESSIVE: min(Trigger, Sub) TH
            cfg.tf1 = 1; cfg.step1 = 0;
            cfg.tf2 = 0; cfg.step2 = 0; cfg.tf2Active = true;
            cfg.operation = 4; cfg.activeComponents = 2;
            break;
        case 10: // TRIPLE_AGGRESSIVE: min(Trigger,Pattern,Structure) TH
            cfg.tf1 = 1; cfg.step1 = 0;
            cfg.tf2 = 2; cfg.step2 = 0; cfg.tf2Active = true;
            cfg.tf3 = 3; cfg.step3 = 0; cfg.tf3Active = true;
            cfg.operation = 4; cfg.activeComponents = 3; cfg.isTriple = true;
            break;
        case 11: // TREND_FILTER: Structure - Sub, SUBTRACT (both TH)
            cfg.tf1 = 3; cfg.step1 = 0;
            cfg.tf2 = 0; cfg.step2 = 0; cfg.tf2Active = true;
            cfg.operation = 2; cfg.activeComponents = 2;
            break;
        case 12: // VOLATILITY_ADAPTIVE: (Structure + Sub)/2, AVERAGE
            cfg.tf1 = 3; cfg.step1 = 0;
            cfg.tf2 = 0; cfg.step2 = 0; cfg.tf2Active = true;
            cfg.operation = 0; cfg.activeComponents = 2;
            break;
        case 13: // MANUAL_DUAL: BUG - falls to default!
        case 14: // MANUAL_TRIPLE: BUG - falls to default!
        default:
            cfg.tf1 = 2; cfg.step1 = 0;
            cfg.tf2 = 1; cfg.step2 = 0; cfg.tf2Active = true;
            cfg.operation = 0; cfg.activeComponents = 2;
            break;
        case 15: // QT_TRIGGER_PATTERN: Trigger+Pattern, GEO_MEAN (audit fix #2)
            cfg.tf1 = 1; cfg.step1 = 0;
            cfg.tf2 = 2; cfg.step2 = 0; cfg.tf2Active = true;
            cfg.operation = 7; cfg.activeComponents = 2;
            break;
        case 16: // QT_ALL_4TF: Sub+Trigger+Pattern, GEO_MEAN (3 TFs, audit fix #2)
            cfg.tf1 = 0; cfg.step1 = 0;
            cfg.tf2 = 1; cfg.step2 = 0; cfg.tf2Active = true;
            cfg.tf3 = 2; cfg.step3 = 0; cfg.tf3Active = true;
            cfg.operation = 7; cfg.activeComponents = 3; cfg.isTriple = true;
            break;
        case 17: // QT_TRIGGER_PATTERN_STRUCTURE, GEO_MEAN (audit fix #2)
            cfg.tf1 = 1; cfg.step1 = 0;
            cfg.tf2 = 2; cfg.step2 = 0; cfg.tf2Active = true;
            cfg.tf3 = 3; cfg.step3 = 0; cfg.tf3Active = true;
            cfg.operation = 7; cfg.activeComponents = 3; cfg.isTriple = true;
            break;
        case 18: // QT_PATTERN_STRUCTURE, GEO_MEAN (audit fix #2)
            cfg.tf1 = 2; cfg.step1 = 0;
            cfg.tf2 = 3; cfg.step2 = 0; cfg.tf2Active = true;
            cfg.operation = 7; cfg.activeComponents = 2;
            break;
        case 19: // QT_TRIGGER_ONLY
            cfg.tf1 = 1; cfg.step1 = 0;
            cfg.activeComponents = 1;
            break;
    }
}

//+------------------------------------------------------------------+
//| CalculateComboStepSize (copied verbatim logic)                   |
//+------------------------------------------------------------------+
double CalculateComboStepSize(const double basePrice, const int preset,
                               const int currentMinutes) {
    if(basePrice <= 0) return 0;
    SComboConfig cfg;
    GetComboConfiguration(preset, cfg);

    int tf1m = GetTimeframeByType(cfg.tf1, currentMinutes);
    double step1 = GetStepSizeForBasisType(basePrice, GetStepMultiplier(cfg.step1), tf1m);
    if(cfg.activeComponents == 1) return step1;

    int tf2m = GetTimeframeByType(cfg.tf2, currentMinutes);
    double step2 = GetStepSizeForBasisType(basePrice, GetStepMultiplier(cfg.step2), tf2m);

    double result = 0;
    if(cfg.isTriple) {
        int tf3m = GetTimeframeByType(cfg.tf3, currentMinutes);
        double step3 = GetStepSizeForBasisType(basePrice, GetStepMultiplier(cfg.step3), tf3m);
        if(cfg.operation == 4) result = MathMin(step1, MathMin(step2, step3));
        else if(cfg.operation == 5) result = MathMax(step1, MathMax(step2, step3));
        else if(cfg.operation == 7) { // GEO_MEAN (audit fix #2)
            if(step1 > 0 && step2 > 0 && step3 > 0)
                result = MathPow(step1 * step2 * step3, 1.0 / 3.0);
            else
                result = (step1 + step2 + step3) / 3.0;
        }
        else result = (step1 + step2 + step3) / 3.0;
    } else {
        result = ApplyComboOperation(step1, step2, cfg.operation, 0.5, 0.5);
    }
    return result;
}

//+------------------------------------------------------------------+
//| Audit entry point                                                 |
//+------------------------------------------------------------------+
void OnStart() {
    const double basePrice = 2000.0;
    const int    currentMinutes = 15; // M15 chart

    Print("=== Combo Calculation Audit ===");
    Print("Base price: ", basePrice, " | Current TF: M", currentMinutes);
    Print("");
    Print("Mock TH% table (minutes -> TH%):");
    Print("  M1=0.05, M5=0.10, M15=0.20, M30=0.30, H1=0.50, H4=1.00, D1=2.00, W1=4.00");
    Print("");
    Print("Timeframe resolution on M15 chart:");
    PrintFormat("  COMBO_TF_SUB       (Current/16) -> %d min -> TH%%=%.3f -> TH price=%.4f",
                GetTimeframeByType(0, currentMinutes),
                GetMockTHPercentage(GetTimeframeByType(0, currentMinutes)),
                basePrice * GetMockTHPercentage(GetTimeframeByType(0, currentMinutes)) / 100.0);
    PrintFormat("  COMBO_TF_TRIGGER   (Current/4)  -> %d min -> TH%%=%.3f -> TH price=%.4f",
                GetTimeframeByType(1, currentMinutes),
                GetMockTHPercentage(GetTimeframeByType(1, currentMinutes)),
                basePrice * GetMockTHPercentage(GetTimeframeByType(1, currentMinutes)) / 100.0);
    PrintFormat("  COMBO_TF_PATTERN   (Current)    -> %d min -> TH%%=%.3f -> TH price=%.4f",
                GetTimeframeByType(2, currentMinutes),
                GetMockTHPercentage(GetTimeframeByType(2, currentMinutes)),
                basePrice * GetMockTHPercentage(GetTimeframeByType(2, currentMinutes)) / 100.0);
    PrintFormat("  COMBO_TF_STRUCTURE (Current*4)  -> %d min -> TH%%=%.3f -> TH price=%.4f",
                GetTimeframeByType(3, currentMinutes),
                GetMockTHPercentage(GetTimeframeByType(3, currentMinutes)),
                basePrice * GetMockTHPercentage(GetTimeframeByType(3, currentMinutes)) / 100.0);
    Print("");
    Print("--- 19 Presets ---");
    string presetNames[20] = {
        "LEGACY_ADD","BALANCED_MEDIUM","BALANCED_LONG","BALANCED_TRIPLE",
        "BALANCED_MIN","CONSERVATIVE","ULTRA_CONSERVATIVE","TRIPLE_CONSERVATIVE",
        "AGGRESSIVE","ULTRA_AGGRESSIVE","TRIPLE_AGGRESSIVE","TREND_FILTER",
        "VOLATILITY_ADAPTIVE","MANUAL_DUAL","MANUAL_TRIPLE",
        "QT_TRIGGER_PATTERN","QT_ALL_4TF","QT_TRIGGER_PATTERN_STRUCTURE",
        "QT_PATTERN_STRUCTURE","QT_TRIGGER_ONLY"
    };

    for(int i = 0; i < 20; i++) {
        double result = CalculateComboStepSize(basePrice, i, currentMinutes);
        PrintFormat("Preset %2d (%s) -> Step = %.4f", i, presetNames[i], result);
    }

    Print("");
    Print("--- Operation spot-check (dual case: step1=3.0, step2=5.0) ---");
    double v1 = 3.0, v2 = 5.0;
    PrintFormat("AVERAGE   (3,5) -> %.4f (expected 4.0000)", ApplyComboOperation(v1, v2, 0));
    PrintFormat("ADD       (3,5) -> %.4f (expected 8.0000)", ApplyComboOperation(v1, v2, 1));
    PrintFormat("SUBTRACT  (3,5) -> %.4f (expected 2.0000)", ApplyComboOperation(v1, v2, 2));
    PrintFormat("MULTIPLY  (3,5) -> %.4f (expected 15.0000)", ApplyComboOperation(v1, v2, 3));
    PrintFormat("MIN       (3,5) -> %.4f (expected 3.0000)", ApplyComboOperation(v1, v2, 4));
    PrintFormat("MAX       (3,5) -> %.4f (expected 5.0000)", ApplyComboOperation(v1, v2, 5));
    PrintFormat("WEIGHTED  (3,5) -> %.4f (expected 4.0000, w=0.5/0.5)", ApplyComboOperation(v1, v2, 6));

    Print("");
    Print("--- SUBTRACT edge case (small diff vs avg) ---");
    PrintFormat("SUBTRACT (10,10.05) -> %.4f (10.025 if raw, but should snap to 10.025? check)", ApplyComboOperation(10.0, 10.05, 2));
    PrintFormat("  avg=10.025, diff=0.05, 1%% of avg=0.10025 -> diff<threshold => should snap to avg=10.025");
    PrintFormat("SUBTRACT (10,9.0)   -> %.4f (expected 1.0000)", ApplyComboOperation(10.0, 9.0, 2));

    Print("");
    Print("--- MULTIPLY overflow case (large numbers) ---");
    PrintFormat("MULTIPLY (1000,1000) -> %.4f (expected 1000000)", ApplyComboOperation(1000.0, 1000.0, 3));
    PrintFormat("  threshold = 1000*100 = 100000, result 1M > 100K -> should clamp to 1000");
    PrintFormat("MULTIPLY (5,10) -> %.4f (expected 50)", ApplyComboOperation(5.0, 10.0, 3));

    Print("");
    Print("=== Audit complete ===");
}

//+------------------------------------------------------------------+
//| EXPECTED RESULTS (manual computation, basePrice=2000, M15 chart):|
//|                                                                   |
//| TF map on M15:                                                   |
//|   SUB -> 1 min (clamped) -> TH%=0.05 -> THprice = 1.0            |
//|   TRIGGER -> 3 min -> M5 -> TH%=0.10 -> THprice = 2.0            |
//|   PATTERN -> 15 min -> M15 -> TH%=0.20 -> THprice = 4.0          |
//|   STRUCTURE -> 60 min -> H1 -> TH%=0.50 -> THprice = 10.0        |
//|                                                                   |
//| Preset results (basePrice=2000, M15):                            |
//|   0 LEGACY_ADD:         (TRIGGER_SS + PATTERN_SS) = 3+6 = 9      |
//|   1 BALANCED_MEDIUM:    (PATTERN_TH + TRIGGER_TH)/2 = 3.0        |
//|   2 BALANCED_LONG:      (STRUCT_TH + PATTERN_TH)/2 = 7.0         |
//|   3 BALANCED_TRIPLE:    (2+4+10)/3 = 5.3333                      |
//|   4 BALANCED_MIN:       min(4,2) = 2.0                           |
//|   5 CONSERVATIVE:       max(10,4) = 10.0                         |
//|   6 ULTRA_CONSERVATIVE: 10.0                                     |
//|   7 TRIPLE_CONSERVATIVE: max(2,4,10) = 10.0                      |
//|   8 AGGRESSIVE:         min(4,2) = 2.0  *** same as BALANCED_MIN |
//|   9 ULTRA_AGGRESSIVE:   min(2,1) = 1.0                           |
//|  10 TRIPLE_AGGRESSIVE:  min(2,4,10) = 2.0                        |
//|  11 TREND_FILTER:       |10-1| = 9.0                             |
//|  12 VOLATILITY_ADAPTIVE:(10+1)/2 = 5.5                           |
//|  13 MANUAL_DUAL:        ***BUG*** defaults to (Pattern+Trigger)/2|
//|  14 MANUAL_TRIPLE:      ***BUG*** defaults to (Pattern+Trigger)/2|
//|  15 QT_TRIGGER_PATTERN: (2+4)/2 = 3.0  (says GeoMean but is Arith)|
//|  16 QT_ALL_4TF:         (1+2+4)/3 = 2.333  (says 4 TFs but is 3) |
//|  17 QT_T_P_S:           (2+4+10)/3 = 5.333                      |
//|  18 QT_PATTERN_STRUCT:  (4+10)/2 = 7.0                          |
//|  19 QT_TRIGGER_ONLY:    2.0                                      |
//|                                                                   |
//| Any deviation from these = bug                                   |
//+------------------------------------------------------------------+
