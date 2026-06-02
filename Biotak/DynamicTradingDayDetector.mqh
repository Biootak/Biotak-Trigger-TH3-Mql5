#ifndef DYNAMIC_TRADING_DAY_DETECTOR_MQH
#define DYNAMIC_TRADING_DAY_DETECTOR_MQH

#property copyright "Biotak"

#define MAX_LOOKBACK_BARS_M1       (7 * 24 * 60)  // 7 days of M1 bars
#define SESSION_GAP_THRESHOLD_MIN  120             // Gap minutes to detect session boundary
#define MAX_LOOKBACK_SECONDS       (7 * 86400)    // 7 days in seconds
#define MARKET_OPEN_FRESHNESS_SEC  300             // 5 minutes
#define SESSION_BLOCK_MINUTES      30
#define SESSION_BLOCK_SECONDS      1800

// PERF: Reusable 1-element buffer for single-bar CopyTime lookups, replacing
// the legacy iTime() calls below. File-scope so IsMarketOpen() and
// GetSessionStatistics() share the same allocation.
static datetime s_sessBarBuf[];
static bool     s_sessBarBufInit = false;

datetime CopySingleBarTime(int shift)
{
    if(!s_sessBarBufInit) {
        ArrayResize(s_sessBarBuf, 1);
        s_sessBarBufInit = true;
    }
    if(CopyTime(_Symbol, PERIOD_M1, shift, 1, s_sessBarBuf) <= 0)
        return 0;
    return s_sessBarBuf[0];
}

datetime FindCurrentSessionStart(ENUM_TIMEFRAMES timeframe = PERIOD_M1) {
        datetime currentTime = TimeGMT();
    int barsToCheck = MAX_LOOKBACK_BARS_M1;
    int gapThresholdMinutes = SESSION_GAP_THRESHOLD_MIN;
    int totalBars = Bars(_Symbol, timeframe);
    if(totalBars <= 0) return GetStartOfTradingDay(Symbol(), currentTime);
    
    // PERF: Batch-fetch bar times with CopyTime instead of individual iTime calls
    int barsToCopy = MathMin(barsToCheck, totalBars);
    datetime barTimes[];
    int copied = CopyTime(_Symbol, timeframe, 0, barsToCopy, barTimes);
    if(copied <= 1) return GetStartOfTradingDay(Symbol(), currentTime);
    
    // CopyTime returns ascending: barTimes[0]=oldest, barTimes[copied-1]=newest
    // Scan from most recent backward looking for session gap.
    // Session start is the first bar AFTER a detected gap.
    for(int j = copied - 2; j >= 0; j--) {
        if(currentTime - barTimes[j] > MAX_LOOKBACK_SECONDS) break;
    int gapMinutes = (int)((barTimes[j + 1] - barTimes[j]) / 60);
    if(gapMinutes > gapThresholdMinutes) return barTimes[j + 1];
    }
    // Fallback: first bar >= 24h ago
    datetime twentyFourHoursAgo = currentTime - SECONDS_PER_DAY;
    for(int j = 0; j < copied; j++) {
        if(barTimes[j] >= twentyFourHoursAgo) return barTimes[j];
    }
    return GetStartOfTradingDay(Symbol(), currentTime);
}
    bool IsMarketOpen() {
        datetime currentTime = TimeGMT();
    datetime lastBarTime = CopySingleBarTime(0);
    return ((int)(currentTime - lastBarTime) < MARKET_OPEN_FRESHNESS_SEC);
}
    string GetSessionStatistics() {
        datetime currentTime = TimeGMT();
    datetime sessionStart = FindCurrentSessionStart();
    int totalBars = Bars(_Symbol, PERIOD_M1);
    if(totalBars <= 0) return "No M1 bar data available";
    datetime firstBarTime = CopySingleBarTime(totalBars - 1);
    datetime lastBarTime  = CopySingleBarTime(0);
    int totalMinutes = (int)((currentTime - sessionStart) / 60);
    int totalBlocks = totalMinutes / SESSION_BLOCK_MINUTES;
    return StringFormat("Session: %s | Blocks: %d | Bars: %d | %s",
        TimeToString(sessionStart, TIME_DATE|TIME_SECONDS),
        totalBlocks, totalBars,
        IsMarketOpen() ? "OPEN" : "CLOSED");
}
    void GetAllBlocksForCurrentSession(datetime &blocks[], datetime currentTime) {
        datetime sessionStart = FindCurrentSessionStart();
    MqlDateTime dt;
    TimeToStruct(sessionStart, dt);
    dt.min = (dt.min / SESSION_BLOCK_MINUTES) * SESSION_BLOCK_MINUTES;
    dt.sec = 0;
    datetime blockTime = StructToTime(dt);
    int estimatedBlocks = (int)((currentTime - blockTime) / SESSION_BLOCK_SECONDS) + 2;
    ArrayResize(blocks, estimatedBlocks);
    int blockCount = 0;
    while(blockTime <= currentTime) {
        if(blockCount >= ArraySize(blocks))
            ArrayResize(blocks, blockCount + 1, 16);
    blocks[blockCount] = blockTime;
    blockCount++;
    blockTime += SESSION_BLOCK_SECONDS;
    }
    ArrayResize(blocks, blockCount);
}
    #endif
    // DYNAMIC_TRADING_DAY_DETECTOR_MQH