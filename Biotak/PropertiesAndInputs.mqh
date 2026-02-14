#property copyright "© Formula by Professor Saeed Khakestar, Indicator by Biotak."
#property link "@biotak"
#property version "3.10"
#property indicator_chart_window
#property description "Version 3.10 - GOLD: Post-Audit - All Critical Issues Fixed"

#include "ConstantsAndEnums.mqh"

//==============================================================================
input string S1 = "---------- DISPLAY ----------";
input bool inpShowLines = true;
input bool inpShowTHLevels = true;
input bool inpShowTHLabels = true;
input bool inpShowTHTargets = true;
input bool inpShowPipDistanceLabels = true;
input bool inpShowMidpointLine = true;
input bool inpShowTimeframeInLabels = true;
input bool inpShowFractalTHs = false;
input bool inpShowStandardTHs = false;
input int inpMaxLevels = 144;                 // Max levels above & below (unified)
input string inpFontName = "Arial Bold";
input int inpFontSize = 8;
    input string S_ATR = "---------- ATR LABELS ----------";
input bool inpShowATRLabels = true;            // Show ATR info labels on chart
input bool inpShowATRTargets = true;           // Show ATR 3x/5x/15x targets
    input string S2 = "---------- CALCULATION ----------";

input ENUM_STEP_CALCULATION_MODE inpStepCalculationMode = M_STEP;
input ENUM_TH_START_POINT_TYPE inpTHStartPointType = TH_START_POINT_CUSTOM_PRICE;
input ENUM_APPLIED_PRICE inpTHPriceType = PRICE_CLOSE;
input ENUM_LINE_STYLE inpTHLineStyle = STYLE_DOT;

// ═══════════════════════════════════════════════════════════════════
// [CFG] BASE PRICE THRESHOLD CONTROL
// ═══════════════════════════════════════════════════════════════════
// When ENABLED: Base price updates only if market moves >0.066% (default)
//               This prevents minor noise from triggering level recalculations
// When DISABLED: Base price updates at every 30-minute block boundary
//                regardless of price movement (more responsive but noisier)
// [TIP] TIP: Keep ENABLED for stable trading. Disable only for testing.
input bool inpBasePriceThresholdEnabled = true;

// ═══════════════════════════════════════════════════════════════════
// [DATA] THRESHOLD SENSITIVITY (Default: 0.066%)
// ═══════════════════════════════════════════════════════════════════
// Minimum price change required to trigger base price update.
// * Lower values (0.01-0.05%): More responsive, more frequent updates
// * Higher values (0.1-0.5%): More stable, fewer updates
// * Default (0.066%): Balanced (matches Java implementation)
// [TIP] TIP: For volatile assets (crypto), consider 0.1-0.2%
//         For stable forex pairs, 0.05-0.066% is optimal
input double inpBasePriceThresholdPercent = 0.066;
    input bool inpUseDynamicTradingDay = true;
input double inpCustomTHStartPrice = 0.0;
input color inpCustomPriceLevelColor = clrDodgerBlue;
input int inpCustomPriceLevelWidth = 1;
input bool inpEnableMagnet = true;
input int inpMagnetSensitivityPips = 10;
    input string S3 = "---------- M STEP ----------";
input ENUM_MSTEP_BASIS_TYPE inpMStepBasisType = MSTEP_BASIS_C_BASED;
input color inpCLevelColor = clrDodgerBlue;
input color inpMLevelColor = clrGold;
input ENUM_LINE_STYLE inpCLevelStyle = STYLE_DOT;
input ENUM_LINE_STYLE inpMLevelStyle = STYLE_DOT;
input int inpCLevelWidth = 1;
input int inpMLevelWidth = 1;
    input string S4 = "---------- SS/LS STEP ----------";
input bool inpLSFirst = true;
input color inpSSLevelColor = clrGoldenrod;
input color inpLSLevelColor = clrOrange;
input ENUM_LINE_STYLE inpSSLevelStyle = STYLE_DOT;
input ENUM_LINE_STYLE inpLSLevelStyle = STYLE_DOT;
input int inpSSLevelWidth = 1;
input int inpLSLevelWidth = 1;
    input string S5 = "---------- TP STEP ----------";
input color inpTPLevelColor = clrCrimson;
input ENUM_LINE_STYLE inpTPLevelStyle = STYLE_DOT;
input int inpTPLevelWidth = 1;
    input string S6 = "---------- COMBO STEP ----------";
input color inpComboLevelColor = clrMagenta;
input ENUM_LINE_STYLE inpComboLevelStyle = STYLE_DOT;
input int inpComboLevelWidth = 1;
input ENUM_COMBO_MODE inpComboMode = COMBO_MODE_PRESET;
input ENUM_COMBO_PRESET inpComboPreset = COMBO_PRESET_BALANCED_MEDIUM;
input ENUM_QUICK_TEST_PRESET inpQuickTestPreset = QUICK_PRESET_TRIGGER_PATTERN;
input ENUM_COMBO_STEP_TYPE inpQuickTestStepType = COMBO_STEP_TH;
input ENUM_MEAN_TYPE inpQuickTestMeanType = MEAN_GEOMETRIC;
input ENUM_CALCULATOR_TOPOLOGY inpComboTopology = TOPOLOGY_DUAL_GROUP;
input ENUM_COMBO_COMPONENT_ITEM inpComboComp1 = COMP_TRIGGER_SS;
input ENUM_COMBO_OPERATOR inpComboOp1 = OP_PLUS;
input ENUM_COMBO_COMPONENT_ITEM inpComboComp2 = COMP_PATTERN_TH;
input ENUM_COMBO_OPERATOR inpComboOp2 = OP_AVERAGE;
input ENUM_COMBO_COMPONENT_ITEM inpComboComp3 = COMP_STRUCTURE_TH;
input ENUM_COMBO_OPERATOR inpComboOp3 = OP_NONE;
input ENUM_COMBO_COMPONENT_ITEM inpComboComp4 = COMP_IGNORE;
input ENUM_MEAN_TYPE inpAggregateMeanType = MEAN_ARITHMETIC;
    input string S7 = "---------- FACTOR STEP ----------";
input ENUM_FACTOR_MODE inpFactorMode = FACTOR_MODE_AUTO;
input ENUM_FACTOR_AUTO_BASIS inpFactorAutoBasis = FACTOR_BASIS_CONTROL;
input double inpFactorValue = 50.0;
input double inpFactorAdjustStep = 0.1;
input color inpFactorLevelColor = C'0,100,0';
input ENUM_LINE_STYLE inpFactorLevelStyle = STYLE_DOT;
input int inpFactorLevelWidth = 1;
    input string S8 = "---------- MID ZONES ----------";
input bool inpShowMidZones = true;
input ENUM_ZONE_STYLE inpMidZoneStyle = ZONE_STYLE_BOX_FILLED;
input int inpMidZoneTransparency = 60;
input double inpMidZoneHeightPercent = 12.5;
    input string S9 = "---------- HARMONIC ----------";
input bool inpEnableHarmonicPattern = false;
input double inpHarmonicRatio = 1.333;
input color inpHarmonicBaseColor = C'0,0,128';
input color inpHarmonicLargeColor = C'220,20,60';
input int inpHarmonicBaseWidth = 1;
input int inpHarmonicLargeWidth = 2;
    input string S10 = "---------- TH3 TOOL ----------";
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
    input string S11 = "---------- AB=CD ----------";
input bool inpABCDShowLabels = true;
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
    input string S12 = "---------- HIGH/LOW ----------";
input color inpHighColor = C'220,20,60';
input color inpLowColor = C'0,0,128';
input ENUM_LINE_STYLE inpHighStyle = STYLE_DASHDOT;
input ENUM_LINE_STYLE inpLowStyle = STYLE_DASHDOT;
input int inpHighWidth = 1;
input int inpLowWidth = 1;
input string inpHighLineTooltip = "Historical High";
input string inpLowLineTooltip = "Historical Low";
    input string S13 = "---------- TRIGGER ----------";
input bool inpShowTrigger = false;
input color inpTriggerColor = C'192,192,192';
input ENUM_LINE_STYLE inpTriggerStyle = STYLE_DOT;
input int inpTriggerWidth = 1;
input color inpTriggerLabelColor = C'192,192,192';
    input string S14 = "---------- STRUCTURE ----------";
input bool inpShowStructure = true;
input ENUM_STRUCTURE_BASE_MULTIPLIER inpStructureBase = BASE_MULTIPLIER_2;
input bool inpShowStructureL1 = true;
input color inpStructureL1Color = C'100,149,237';
input ENUM_LINE_STYLE inpStructureL1Style = STYLE_DOT;
input int inpStructureL1Width = 1;
input color inpStructureL1LabelColor = C'100,149,237';
input bool inpShowStructureL2 = true;
input color inpStructureL2Color = C'60,179,113';
input ENUM_LINE_STYLE inpStructureL2Style = STYLE_DOT;
input int inpStructureL2Width = 1;
input color inpStructureL2LabelColor = C'60,179,113';
input bool inpShowStructureL3 = true;
input color inpStructureL3Color = C'138,43,226';
input ENUM_LINE_STYLE inpStructureL3Style = STYLE_DOT;
input int inpStructureL3Width = 1;
input color inpStructureL3LabelColor = C'138,43,226';
input bool inpShowStructureL4 = true;
input color inpStructureL4Color = C'255,140,0';
input ENUM_LINE_STYLE inpStructureL4Style = STYLE_DOT;
input int inpStructureL4Width = 1;
input color inpStructureL4LabelColor = C'255,140,0';
input bool inpShowStructureL5 = true;
input color inpStructureL5Color = C'205,92,92';
input ENUM_LINE_STYLE inpStructureL5Style = STYLE_DOT;
input int inpStructureL5Width = 1;
input color inpStructureL5LabelColor = C'205,92,92';
    input string S15 = "---------- ALERTS ----------";
input bool inpEnableHighLowAlerts = false;
input bool inpEnableTHAlerts = false;
input bool inpEnableStructureTHAlerts = false;
input bool inpAlertOnce = true;
input bool inpPlaySound = true;
input string inpAlertSoundFile = "alert.wav";
input bool inpSendNotification = false;
input bool inpSendEmail = false;
    input string S16 = "---------- MODE LABEL ----------";
input bool inpShowModeChangeLabel = true;
input ENUM_MODE_LABEL_DURATION inpModeLabelDuration = MODE_LABEL_2_SEC;
input ENUM_BASE_CORNER inpModeLabelCorner = CORNER_LEFT_UPPER;
input int inpModeLabelXDistance = 15;
input int inpModeLabelYDistance = 25;
input int inpModeLabelFontSize = 11;
input color inpModeLabelColor = clrNavy;

//==============================================================================
input string S17 = "---------- HOTKEYS ----------";
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

//==============================================================================
input string S18 = "---------- ADVANCED ----------";
input string inpObjectPrefix = "THLevels";
input ENUM_LINE_OBJECT_TYPE inpTHLineObjectType = LINE_OBJECT_HORIZONTAL_LINE;
input ENUM_LABEL_CORNER_POSITION inpLabelCornerPosition = LABEL_CORNER_LEFT_TOP;
input ENUM_LABEL_ARRANGEMENT inpLabelArrangement = LABEL_ARRANGEMENT_HORIZONTAL;

// === Label Position ===
input int inpLabelsMarginTop = 25;        // Distance from top of chart
input int inpLabelsMarginLeft = 20;       // Distance from left edge
input int inpLabelsMarginBottom = 5;      // Distance from bottom of chart
input int inpTHLabelsMarginBottom = 15;   // TH labels distance from bottom (bottom-left)

// === Label Spacing ===
input int inpLabelRowGap = 16;            // Vertical gap between rows
input int inpLabelColumnGap = 45;         // Horizontal gap between columns
input int inpSectionGap = 23;             // Gap between ATR and TH sections

input int inpMaxLabelWidth = 250;
input ENUM_TIMEFRAMES inpHistoricalTimeframe = PERIOD_CURRENT;
input int inpHistoricalPeriods = 0;

// === Logging ===
input ENUM_LOG_LEVEL inpLogLevel = LOG_LEVEL_WARN;   // Minimum log level (TRACE=all, OFF=none)
