#ifndef DYNAMIC_TRADING_DAY_DETECTOR_MQH
#define DYNAMIC_TRADING_DAY_DETECTOR_MQH

#property copyright "Biotak"

datetime FindCurrentSessionStart(ENUM_TIMEFRAMES timeframe = PERIOD_M1) {
        datetime currentTime = TimeGMT();
    int barsToCheck = 7 * 24 * 60;
    int gapThresholdMinutes = 120;
    for(int i = 1; i < barsToCheck && i < iBars(_Symbol, timeframe); i++) {
        datetime currentBarTime = iTime(_Symbol, timeframe, i);
    datetime previousBarTime = iTime(_Symbol, timeframe, i - 1);
    if(currentTime - currentBarTime > 7 * 86400) break;
    int gapMinutes = (int)((previousBarTime - currentBarTime) / 60);
    if(gapMinutes > gapThresholdMinutes) return currentBarTime;
    }
    datetime twentyFourHoursAgo = currentTime - 86400;
    for(int i = iBars(_Symbol, timeframe) - 1; i >= 0; i--) {
        datetime barTime = iTime(_Symbol, timeframe, i);
    if(barTime >= twentyFourHoursAgo) return barTime;
    }
    return GetStartOfTradingDay(Symbol(), currentTime);
}
    bool IsMarketOpen() {
        datetime currentTime = TimeGMT();
    datetime lastBarTime = iTime(_Symbol, PERIOD_M1, 0);
    return ((int)(currentTime - lastBarTime) < 300);
}
    string GetSessionStatistics() {
        datetime currentTime = TimeGMT();
    datetime sessionStart = FindCurrentSessionStart();
    int totalBars = iBars(_Symbol, PERIOD_M1);
    if(totalBars <= 0) return "No M1 bar data available";
    datetime firstBarTime = iTime(_Symbol, PERIOD_M1, totalBars - 1);
    datetime lastBarTime = iTime(_Symbol, PERIOD_M1, 0);
    int totalMinutes = (int)((currentTime - sessionStart) / 60);
    int totalBlocks = totalMinutes / 30;
    return StringFormat("Session: %s | Blocks: %d | Bars: %d | %s",
        TimeToString(sessionStart, TIME_DATE|TIME_SECONDS),
        totalBlocks, totalBars,
        IsMarketOpen() ? "OPEN" : "CLOSED");
}
    void GetAllBlocksForCurrentSession(datetime &blocks[], datetime currentTime) {
        datetime sessionStart = FindCurrentSessionStart();
    MqlDateTime dt;
    TimeToStruct(sessionStart, dt);
    dt.min = (dt.min / 30) * 30;
    dt.sec = 0;
    datetime blockTime = StructToTime(dt);
    int estimatedBlocks = (int)((currentTime - blockTime) / 1800) + 2;
    ArrayResize(blocks, 0);
    ArrayResize(blocks, estimatedBlocks);
    int blockCount = 0;
    while(blockTime <= currentTime) {
        if(blockCount >= ArraySize(blocks))
            ArrayResize(blocks, blockCount + 1, 16);
    blocks[blockCount] = blockTime;
    blockCount++;
    blockTime += 1800;
    }
    ArrayResize(blocks, blockCount);
}
    #endif
    // DYNAMIC_TRADING_DAY_DETECTOR_MQH