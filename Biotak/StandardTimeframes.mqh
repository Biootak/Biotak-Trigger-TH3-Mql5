// ============================================================================
// GENERATED MIRROR of the MetaTrader 4 source - MT4 is the single source of
// truth.  Do not add anything here that MT4 does not have: with MT4 there is
// "nothing less, nothing more".
//
//   MT4 source : Biotak/Biotak/StandardTimeframes.mqh
//   regenerate : python tools/parity/resync-module.py --write StandardTimeframes.mqh
//
// The MT4 part files are inlined (MT5 has no such parts), includes of modules
// both trees own are kept, and only these platform patches are applied:
//   * none
// ============================================================================
  #property strict

#ifndef STANDARD_TIMEFRAMES_MQH
#define STANDARD_TIMEFRAMES_MQH
double CalculateStandardPercentage(const int timeInMinutes) {
    if(timeInMinutes <= 0) return 0.0;
    // PERF: Cache results   input is one of 8 fixed values (1, 5, 15, 60, 240, 1440, 10080, 43200)
    // MathLog/MathPow are expensive, result is purely a function of timeInMinutes and never changes
    static int    s_cachedMinutes[8] = {0, 0, 0, 0, 0, 0, 0, 0};
    static double s_cachedResults[8] = {0, 0, 0, 0, 0, 0, 0, 0};
    static int    s_cachedCount = 0;
    for(int c = 0; c < s_cachedCount; c++) {
        if(s_cachedMinutes[c] == timeInMinutes) return s_cachedResults[c];
    }
    int baseTimeMinutes = 1;
    double basePercentage = 2.083;  // Adjusted so 1024min = 66.66%
    double result;
    if(timeInMinutes <= baseTimeMinutes) {
        result = basePercentage / 100.0;
    } else {
        double timeRatio = (double)timeInMinutes / baseTimeMinutes;
        double doublingFactor = MathLog(timeRatio) / MathLog(4.0);
        result = (basePercentage * MathPow(2.0, doublingFactor)) / 100.0;
    }
    // Store in cache if space available
    if(s_cachedCount < 8) {
        s_cachedMinutes[s_cachedCount] = timeInMinutes;
        s_cachedResults[s_cachedCount] = result;
        s_cachedCount++;
    }
    return result;
}

#endif // STANDARD_TIMEFRAMES_MQH
