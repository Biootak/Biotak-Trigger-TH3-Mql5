//+------------------------------------------------------------------+
//|                                           Biotak Trigger TH3.mq5 |
//+------------------------------------------------------------------+
#property copyright "© Formula by Professor Saeed Khakestar, Indicator by Biotak."
#property link      "@biotak"
#property version   "3.10"
#property indicator_chart_window
#property indicator_plots 0
#property description "Version 3.10 - GOLD: Post-Audit - All Critical Issues Fixed"
#property description "Race conditions fixed | Memory leaks eliminated | Buffer overflow prevented"
#property description "MQL5 Compatible Version"

// ═══════════════════════════════════════════════════════════════════
// BUILD CONFIG - Must be FIRST include!
// برای تغییر مود، فایل BuildConfig.mqh را ویرایش کنید
// ═══════════════════════════════════════════════════════════════════
#include "Biotak\BuildConfig.mqh"

// ═══════════════════════════════════════════════════════════════════
// MQL5 COMPATIBILITY LAYER - Must be included AFTER BuildConfig
// لایه سازگاری MQL5 - باید بعد از BuildConfig include شود
// ═══════════════════════════════════════════════════════════════════
#include "Biotak\MQL5Compat.mqh"

#include "Biotak\PropertiesAndInputs.mqh"
#include "Biotak\ConstantsAndEnums.mqh"
#include "Biotak\ProjectConstants.mqh"
#include "Biotak\InputValidator.mqh"

// ═══════════════════════════════════════════════════════════════════
// GOLD FIX: Security & Performance Enhancements
// ═══════════════════════════════════════════════════════════════════
#include "Biotak\FloatingPointHelper.mqh"
#include "Biotak\ObjectCountManager.mqh"
#include "Biotak\PerformanceOptimizations.mqh"
#include "Biotak\InputValidationEnhanced.mqh"

// GlobalVariables.mqh requires HIDDEN_CACHE_TTL_MS from PerformanceOptimizations.mqh
#include "Biotak\GlobalVariables.mqh"

#ifdef DEBUG_BUILD
#include "Biotak\Tests\SecurityAuditTests.mqh"
#endif

#include "Biotak\UtilityFunctions.mqh"

// ═══════════════════════════════════════════════════════════════════
// ZONE SYSTEM: Factory and Validation
// ═══════════════════════════════════════════════════════════════════
#include "Biotak\ZoneFactory.mqh"
#include "Biotak\ZoneValidator.mqh"
#include "Biotak\ZoneConstants.mqh"

// ═══════════════════════════════════════════════════════════════════
// FLICKERING FIX: Object Cache and Optimization Modules
// ═══════════════════════════════════════════════════════════════════
#include "Biotak\ObjectCache.mqh"
#include "Biotak\PropertyChangeDetector.mqh"
#include "Biotak\VisibilityManager.mqh"
#include "Biotak\RedrawFlagManager.mqh"

#include "Biotak\TimeframeFunctions.mqh"
#include "Biotak\FractalTimeframes.mqh"
#include "Biotak\StandardTimeframes.mqh"
#include "Biotak\THCalculations.mqh"
#include "Biotak\ATRCalculations.mqh"
#include "Biotak\BasePriceManager.mqh"
#include "Biotak\TH3Tool.mqh"
#include "Biotak\FrequencyLearning.mqh"
#include "Biotak\ObjectFunctions.mqh"
#include "Biotak\ExtendedDrawingFunctions.mqh"
#include "Biotak\UnifiedZoneSystem.mqh"
#include "Biotak\ZoneTrackingHelpers.mqh"
#include "Biotak\DrawingPipeline.mqh"
#include "Biotak\ZoneCalculator.mqh"
#include "Biotak\ZoneRenderer.mqh"
#include "Biotak\LabelFunctions.mqh"
#include "Biotak\AlertFunctions.mqh"
#include "Biotak\HistoricalDataFunctions.mqh"
#include "Biotak\EventHandlers.mqh"

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    return OnInitHandler();
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    OnDeinitHandler(reason);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &real_volume[],
                const int &spread[])
{
    return OnCalculateHandler(rates_total, prev_calculated, time, open, high, low, close, tick_volume, real_volume, spread);
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
  OnChartEventHandler(id,lparam,dparam,sparam);
}

//+------------------------------------------------------------------+
//| Timer function - clears temporary messages                       |
//+------------------------------------------------------------------+
void OnTimer()
{
    // Clear the step mode label after timer fires
    if(ObjectFind(0, g_stepModeLabelName) >= 0) {
        ObjectDelete(0, g_stepModeLabelName);
    }
    // Clear the basis mode label after timer fires
    if(ObjectFind(0, g_basisModeLabelName) >= 0) {
        ObjectDelete(0, g_basisModeLabelName);
    }
    // Clear the factor label after timer fires
    if(ObjectFind(0, g_factorLabelName) >= 0) {
        ObjectDelete(0, g_factorLabelName);
    }
    // Also clear any comment (for backward compatibility)
    Comment("");
    // Kill the timer
    EventKillTimer();
}
