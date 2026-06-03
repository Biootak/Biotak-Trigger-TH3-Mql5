#property copyright "© Formula by Professor Saeed Khakestar, Indicator by Biotak."
#property link "@biotak"
#property version "3.10"
#property indicator_chart_window
#property description "Version 3.10 - GOLD: Post-Audit - All Critical Issues Fixed"

#include "ConstantsAndEnums.mqh"

//==============================================================================
input group "01) DISPLAY - VISIBILITY"
input string inp01Guide = "[01] DISPLAY / VISIBILITY";
input bool inpShowLines = true;                 // Show Lines
input bool inpShowTHLevels = true;              // Show TH Levels
input bool inpShowTHLabels = true;              // Show TH Labels
input bool inpShowTHTargets = true;             // Show TH Targets
input bool inpShowPipDistanceLabels = true;     // Show Pip Labels
input bool inpShowMidpointLine = true;          // Show Midpoint
input bool inpShowTimeframeInLabels = true;     // Show TF in Labels
input bool inpShowFractalTHs = false;           // Show Fractal THs
input bool inpShowStandardTHs = false;          // Show Standard THs
input bool inpShowATRLabels = true;             // Show ATR Labels
input bool inpShowATRTargets = true;            // Show ATR Targets

input group "02) DISPLAY - TEXT & FONT"
input string inp02Guide = "[02] DISPLAY / TEXT & FONT";
input string inpFontName = "Arial Bold";       // Font Name
input int inpFontSize = 8;                      // Font Size

input group "03) CALCULATION - CORE"
input string inp03Guide = "[03] CALCULATION / CORE";
input int inpMaxLevels = 144;                                   // Max Levels
input ENUM_STEP_CALCULATION_MODE inpStepCalculationMode = M_STEP; // Step Mode
input ENUM_TH_START_POINT_TYPE inpTHStartPointType = TH_START_POINT_CUSTOM_PRICE; // Start Point Type
input ENUM_APPLIED_PRICE inpTHPriceType = PRICE_CLOSE;          // Price Type
input ENUM_LINE_STYLE inpTHLineStyle = STYLE_DOT;               // Default TH Line Style
input bool inpUseDynamicTradingDay = true;                      // Dynamic Trading Day
input bool inpBasePriceThresholdEnabled = true;                 // Enable Base Threshold
input double inpBasePriceThresholdPercent = 0.066;              // Base Threshold %
input ENUM_ADAPTIVE_MODE inpAdaptiveMode = ADAPTIVE_FIXED;      // Adaptive Mode
input double inpAdaptiveBlendRatio = 0.5;                       // Adaptive Blend Ratio
input int inpAdaptiveSmoothingPeriod = 20;                      // Adaptive Smoothing

input group "04) CALCULATION - CUSTOM START"
input string inp04Guide = "[04] CALCULATION / CUSTOM START";
input double inpCustomTHStartPrice = 0.0;          // Custom Start Price
input color inpCustomPriceLevelColor = clrDodgerBlue; // Custom Line Color
input int inpCustomPriceLevelWidth = 1;            // Custom Line Width
input bool inpEnableMagnet = true;                 // Enable Magnet
input int inpMagnetSensitivityPips = 10;           // Magnet Sensitivity (pips)

input group "05) STYLE - M STEP"
input string inp05StyleGuide = "[05] STYLE / M STEP";   // Visual guide row
input ENUM_MSTEP_BASIS_TYPE inpMStepBasisType = MSTEP_BASIS_C_BASED;
input color inpCLevelColor = clrDodgerBlue;
input color inpMLevelColor = clrGold;
input ENUM_LINE_STYLE inpCLevelStyle = STYLE_DOT;
input ENUM_LINE_STYLE inpMLevelStyle = STYLE_DOT;
input int inpCLevelWidth = 1;
input int inpMLevelWidth = 1;

input group "06) STYLE - SS/LS STEP"
input string inp06StyleGuide = "[06] STYLE / SS-LS STEP";  // Visual guide row
input bool inpLSFirst = true;
input color inpSSLevelColor = clrGoldenrod;
input color inpLSLevelColor = clrOrange;
input ENUM_LINE_STYLE inpSSLevelStyle = STYLE_DOT;
input ENUM_LINE_STYLE inpLSLevelStyle = STYLE_DOT;
input int inpSSLevelWidth = 1;
input int inpLSLevelWidth = 1;

input group "07) STYLE - TP STEP"
input string inp07StyleGuide = "[07] STYLE / TP STEP";   // Visual guide row
input color inpTPLevelColor = clrCrimson;
input ENUM_LINE_STYLE inpTPLevelStyle = STYLE_DOT;
input int inpTPLevelWidth = 1;

input group "08) STYLE - COMBO STEP"
input string inp08StyleGuide = "[08] STYLE / COMBO STEP";   // Visual guide row
input color inpComboLevelColor = clrMagenta;
input ENUM_LINE_STYLE inpComboLevelStyle = STYLE_DOT;
input int inpComboLevelWidth = 1;
input ENUM_COMBO_MODE inpComboMode = COMBO_MODE_PRESET;
input ENUM_COMBO_PRESET inpComboPreset = COMBO_PRESET_BALANCED_MEDIUM;
input ENUM_QUICK_TEST_PRESET inpQuickTestPreset = QUICK_PRESET_TRIGGER_PATTERN; // DEPRECATED: Use inpComboPreset (Quick Test merged into Preset)
input ENUM_COMBO_STEP_TYPE inpQuickTestStepType = COMBO_STEP_TH;                 // DEPRECATED: Legacy support only
input ENUM_MEAN_TYPE inpQuickTestMeanType = MEAN_GEOMETRIC;                       // DEPRECATED: Legacy support only
input ENUM_CALCULATOR_TOPOLOGY inpComboTopology = TOPOLOGY_DUAL_GROUP;
input ENUM_COMBO_COMPONENT_ITEM inpComboComp1 = COMP_TRIGGER_SS;
input ENUM_COMBO_OPERATOR inpComboOp1 = OP_PLUS;
input ENUM_COMBO_COMPONENT_ITEM inpComboComp2 = COMP_PATTERN_TH;
input ENUM_COMBO_OPERATOR inpComboOp2 = OP_AVERAGE;
input ENUM_COMBO_COMPONENT_ITEM inpComboComp3 = COMP_STRUCTURE_TH;
input ENUM_COMBO_OPERATOR inpComboOp3 = OP_NONE;
input ENUM_COMBO_COMPONENT_ITEM inpComboComp4 = COMP_IGNORE;
input ENUM_MEAN_TYPE inpAggregateMeanType = MEAN_ARITHMETIC;

input group "09) STYLE - FACTOR STEP"
input string inp09StyleGuide = "[09] STYLE / FACTOR STEP";  // Visual guide row
input ENUM_FACTOR_MODE inpFactorMode = FACTOR_MODE_AUTO;
input ENUM_FACTOR_AUTO_BASIS inpFactorAutoBasis = FACTOR_BASIS_CONTROL;
input double inpFactorValue = 50.0;
input double inpFactorAdjustStep = 0.1;
input color inpFactorLevelColor = C'0,100,0';
input ENUM_LINE_STYLE inpFactorLevelStyle = STYLE_DOT;
input int inpFactorLevelWidth = 1;

input group "10) ZONES - MID"
input string inp10Guide = "[10] ZONES / MID";
input group "10.1) ZONES - ENABLE & TYPE"
input string inp101Guide = "[10.1] ZONES / ENABLE & TYPE";
input bool inpShowMidZones = true;
input ENUM_ZONE_STYLE inpMidZoneStyle = ZONE_STYLE_BOX_FILLED;

input group "10.2) ZONES - VISUAL DENSITY"
input string inp102Guide = "[10.2] ZONES / VISUAL DENSITY";
input int inpMidZoneTransparency = 60;
input double inpMidZoneHeightPercent = 12.5;

input group "11) STYLE - HARMONIC"
input string inp11Guide = "[11] STYLE / HARMONIC";
input bool inpEnableHarmonicPattern = false;
input double inpHarmonicRatio = 1.333;
input color inpHarmonicBaseColor = C'0,0,128';
input color inpHarmonicLargeColor = C'220,20,60';
input int inpHarmonicBaseWidth = 1;
input int inpHarmonicLargeWidth = 2;

input group "12) TH3 TOOL"
input string inp12Guide = "[12] TH3 TOOL";
input bool inpEnableTH3Tool = true;
input ENUM_TH3_DRAWING_MODE inpTH3DrawingMode = TH3_MODE_ABCD;
input double inpTH3BaseStepPercent = 28.125;
// input double inpTH3FreqAdjustStep = 1.0;   // DEPRECATED: Keys 3/4 now cycle through TH3_TEST_FREQUENCIES[] array
    input color inpTH3Color = clrDarkBlue;
input color inpTH3PipTextColor = clrDarkBlue;
input ENUM_LINE_STYLE inpTH3Style = STYLE_SOLID;
input int inpTH3Width = 1;
input bool inpShowTH3Labels = true;
input ENUM_TH3_LABEL_POSITION inpTH3LabelPosition = TH3_LABEL_END;
input ENUM_ZONE_STYLE inpTH3ZoneStyle = ZONE_STYLE_LINES;
input color inpTH3ZoneColor = clrNONE;
input int inpTH3ZoneTransparency = 60;
input double inpTH3ZoneHeightPercent = 12.5;
input ENUM_LINE_STYLE inpTH3ZoneBorderStyle = STYLE_DOT;
input int inpTH3ZoneBorderWidth = 1;

input group "13) AB=CD"
input string inp13Guide = "[13] AB=CD";
input bool inpABCDShowLabels = false;
input color inpABCDPointColor = clrDarkBlue;
input double inpABCDLabelOffsetPercent = 20.0;
input color inpABCDLineColor = clrDarkBlue;
input int inpABCDWidth = 2;
input bool inpABCDExtendCD = true;
input ENUM_BASE_CORNER inpABCDInfoCorner = CORNER_LEFT_UPPER;
input int inpABCDInfoXDistance = 10;
input int inpABCDInfoYDistance = 20;
input int inpABCDInfoFontSize = 9;
input color inpABCDInfoColor = clrDarkBlue;

input group "14) STYLE - HIGH/LOW"
input string inp14Guide = "[14] STYLE / HIGH-LOW";
input group "14.1) HIGH/LOW - COLORS"
input string inp141Guide = "[14.1] HIGH-LOW / COLORS";
input color inpHighColor = C'220,20,60';  // High Color
input color inpLowColor = C'0,0,128';     // Low Color

input group "14.2) HIGH/LOW - LINE STYLE"
input string inp142Guide = "[14.2] HIGH-LOW / LINE STYLE";
input ENUM_LINE_STYLE inpHighStyle = STYLE_DASHDOT; // High Style
input ENUM_LINE_STYLE inpLowStyle = STYLE_DASHDOT;  // Low Style
input int inpHighWidth = 1;                         // High Width
input int inpLowWidth = 1;                          // Low Width

input group "14.3) HIGH/LOW - TOOLTIPS"
input string inp143Guide = "[14.3] HIGH-LOW / TOOLTIPS";
input string inpHighLineTooltip = "Historical High"; // High Tooltip
input string inpLowLineTooltip = "Historical Low";   // Low Tooltip

input group "15) STYLE - TRIGGER"
input string inp15Guide = "[15] STYLE / TRIGGER";
input group "15.1) TRIGGER - ENABLE & VISIBILITY"
input string inp151Guide = "[15.1] TRIGGER / ENABLE & VISIBILITY";
input bool inpShowTrigger = false;       // Show Trigger Levels
input int inpTriggerTransparency = 30;   // Trigger Transparency

input group "15.2) TRIGGER - LINE"
input string inp152Guide = "[15.2] TRIGGER / LINE";
input color inpTriggerColor = clrDimGray;        // Trigger Line Color
input ENUM_LINE_STYLE inpTriggerStyle = STYLE_DOT; // Trigger Line Style
input int inpTriggerWidth = 1;                   // Trigger Line Width

input group "15.3) TRIGGER - LABEL"
input string inp153Guide = "[15.3] TRIGGER / LABEL";
input color inpTriggerLabelColor = clrDimGray;   // Trigger Label Color

input group "16) STYLE - STRUCTURE"
input string inp16Guide = "[16] STYLE / STRUCTURE";
input group "16.1) STRUCTURE - MASTER"
input string inp161Guide = "[16.1] STRUCTURE / MASTER";
input bool inpShowStructure = true;                               // Show Structure
input ENUM_STRUCTURE_BASE_MULTIPLIER inpStructureBase = BASE_MULTIPLIER_2; // Structure Base

input group "16.2) STRUCTURE - L1"
input string inp162Guide = "[16.2] STRUCTURE / L1";
input bool inpShowStructureL1 = true;                 // L1 Show
input color inpStructureL1Color = C'100,149,237';     // L1 Line Color
input ENUM_LINE_STYLE inpStructureL1Style = STYLE_DOT; // L1 Line Style
input int inpStructureL1Width = 1;                    // L1 Line Width
input color inpStructureL1LabelColor = C'100,149,237'; // L1 Label Color

input group "16.3) STRUCTURE - L2"
input string inp163Guide = "[16.3] STRUCTURE / L2";
input bool inpShowStructureL2 = true;                 // L2 Show
input color inpStructureL2Color = C'60,179,113';      // L2 Line Color
input ENUM_LINE_STYLE inpStructureL2Style = STYLE_DOT; // L2 Line Style
input int inpStructureL2Width = 1;                    // L2 Line Width
input color inpStructureL2LabelColor = C'60,179,113'; // L2 Label Color

input group "16.4) STRUCTURE - L3"
input string inp164Guide = "[16.4] STRUCTURE / L3";
input bool inpShowStructureL3 = true;                 // L3 Show
input color inpStructureL3Color = C'138,43,226';      // L3 Line Color
input ENUM_LINE_STYLE inpStructureL3Style = STYLE_DOT; // L3 Line Style
input int inpStructureL3Width = 1;                    // L3 Line Width
input color inpStructureL3LabelColor = C'138,43,226'; // L3 Label Color

input group "16.5) STRUCTURE - L4"
input string inp165Guide = "[16.5] STRUCTURE / L4";
input bool inpShowStructureL4 = true;                 // L4 Show
input color inpStructureL4Color = C'255,140,0';       // L4 Line Color
input ENUM_LINE_STYLE inpStructureL4Style = STYLE_DOT; // L4 Line Style
input int inpStructureL4Width = 1;                    // L4 Line Width
input color inpStructureL4LabelColor = C'255,140,0';  // L4 Label Color

input group "16.6) STRUCTURE - L5"
input string inp166Guide = "[16.6] STRUCTURE / L5";
input bool inpShowStructureL5 = true;                 // L5 Show
input color inpStructureL5Color = C'205,92,92';       // L5 Line Color
input ENUM_LINE_STYLE inpStructureL5Style = STYLE_DOT; // L5 Line Style
input int inpStructureL5Width = 1;                    // L5 Line Width
input color inpStructureL5LabelColor = C'205,92,92';  // L5 Label Color

input group "17) ALERTS"
input string inp17Guide = "[17] ALERTS";
input bool inpEnableHighLowAlerts = false;        // High/Low Alerts
input bool inpEnableTHAlerts = false;             // TH Alerts
input bool inpEnableStructureTHAlerts = false;    // Structure Alerts
input bool inpAlertOnce = true;                   // Once Per Bar
input bool inpPlaySound = true;                   // Play Sound
input string inpAlertSoundFile = "alert.wav";    // Sound File
input bool inpSendNotification = false;           // Push Notification
input bool inpSendEmail = false;                  // Send Email

input group "18) MODE LABEL"
input string inp18Guide = "[18] MODE LABEL";
input bool inpShowModeChangeLabel = true;
input ENUM_MODE_LABEL_DURATION inpModeLabelDuration = MODE_LABEL_2_SEC;
input ENUM_BASE_CORNER inpModeLabelCorner = CORNER_LEFT_UPPER;
input int inpModeLabelXDistance = 15;
input int inpModeLabelYDistance = 25;
input int inpModeLabelFontSize = 11;
input color inpModeLabelColor = clrNavy;

input group "19) HOTKEYS"
input string inp19Guide = "[19] HOTKEYS";
input string inpHideKey = "F";
input string inpLinesToggleKey = "L";
input string inpLockKey = "G";
input string inpCustomPriceKey = "C";
input string inpTriggerLevelsKey = "T";
input string inpStepModeKey = "E";
input string inpTH3ToolKey = "V";
input string inpATRLabelsKey = "A";        // Toggle ATR labels on/off
input string inpTHLabelsKey = "S";          // Toggle TH labels on/off
input string inpResetKey = "Q";

input group "20) ADVANCED - OBJECTS"
input string inp20Guide = "[20] ADVANCED / OBJECTS";
input string inpObjectPrefix = "THLevels";
input ENUM_LINE_OBJECT_TYPE inpTHLineObjectType = LINE_OBJECT_HORIZONTAL_LINE;
input ENUM_LABEL_CORNER_POSITION inpLabelCornerPosition = LABEL_CORNER_LEFT_TOP;
input ENUM_LABEL_ARRANGEMENT inpLabelArrangement = LABEL_ARRANGEMENT_HORIZONTAL;

input group "21) ADVANCED - LABEL LAYOUT"
input string inp21Guide = "[21] ADVANCED / LABEL LAYOUT";
input int inpLabelsMarginTop = 25;        // Distance from top of chart
input int inpLabelsMarginLeft = 20;       // Distance from left edge
input int inpLabelsMarginBottom = 5;      // Distance from bottom of chart
input int inpTHLabelsMarginBottom = 15;   // TH labels distance from bottom (bottom-left)
input int inpLabelRowGap = 16;            // Vertical gap between rows
input int inpLabelColumnGap = 45;         // Horizontal gap between columns
input int inpSectionGap = 23;             // Gap between ATR and TH sections
input int inpMaxLabelWidth = 250;

input group "22) ADVANCED - HISTORY & LOG"
input string inp22Guide = "[22] ADVANCED / HISTORY & LOG";
input ENUM_TIMEFRAMES inpHistoricalTimeframe = PERIOD_CURRENT;
input int inpHistoricalPeriods = 0;
input ENUM_LOG_LEVEL inpLogLevel = LOG_LEVEL_WARN;   // Minimum log level (TRACE=all, OFF=none)

// Effective trigger line color with configurable transparency (0..100)
color GetTriggerRenderColor()
{
    static color s_cachedBase = clrNONE;
    static int s_cachedTransparency = -1;
    static color s_cachedBackground = clrNONE;
    static color s_cachedRenderColor = clrNONE;

    int t = (int)MathMax(0, MathMin(100, inpTriggerTransparency));
    // Stronger visual fade for line objects:
    // 60 -> 84, 50 -> 75, 30 -> 51
    // (MT5 line objects do not honor ARGB alpha natively)
    int tVis = 100 - ((100 - t) * (100 - t)) / 100;
    color bg = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);

    if(s_cachedBase == inpTriggerColor && s_cachedTransparency == tVis && s_cachedBackground == bg) {
        return s_cachedRenderColor;
    }

    s_cachedBase = inpTriggerColor;
    s_cachedTransparency = tVis;
    s_cachedBackground = bg;

    if(tVis <= 0) {
        s_cachedRenderColor = inpTriggerColor;
        return s_cachedRenderColor;
    }

    if(tVis >= 100) {
        s_cachedRenderColor = bg;
        return s_cachedRenderColor;
    }

    int fr = ((int)inpTriggerColor) & 0xFF;
    int fg = (((int)inpTriggerColor) >> 8) & 0xFF;
    int fb = (((int)inpTriggerColor) >> 16) & 0xFF;

    int br = ((int)bg) & 0xFF;
    int bgc = (((int)bg) >> 8) & 0xFF;
    int bb = (((int)bg) >> 16) & 0xFF;

    int outR = (fr * (100 - tVis) + br * tVis) / 100;
    int outG = (fg * (100 - tVis) + bgc * tVis) / 100;
    int outB = (fb * (100 - tVis) + bb * tVis) / 100;

    s_cachedRenderColor = (color)(outR | (outG << 8) | (outB << 16));
    return s_cachedRenderColor;
}
