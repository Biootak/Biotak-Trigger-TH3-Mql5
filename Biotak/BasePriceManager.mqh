
#include "BasePriceHistoryManager.mqh"
#include "MarketHoursDetector.mqh"
#include "DynamicTradingDayDetector.mqh"
#define BLOCK_MINUTES 30
#define SANITY_CHECK_THRESHOLD_PERCENT 10.0
#define HISTORY_FORMAT_VERSION 4
#ifdef ENABLE_DEBUG_LOGS
void PrintRecentM30Bars(int count = 5)
{
    Print("[BasePriceManager] ╔═══════════════════════════════════════════════════════════════╗");
    Print("[BasePriceManager] ║  RECENT M30 BARS (Last ", count, " completed bars)                    ║");
    Print("[BasePriceManager] ╠═══════════════════════════════════════════════════════════════╣");
    for(int i = 1; i <= count; i++)    {
        datetime barTime = iTime(_Symbol, PERIOD_M30, i);
    double barClose = iClose(_Symbol, PERIOD_M30, i);
    if(barTime == 0) continue;
    datetime barTimeGMT = ConvertServerToGMT(barTime);
        Print("[BasePriceManager] ║  Bar ", i, ":");
    Print("[BasePriceManager] ║    Server Time: ", TimeToString(barTime, TIME_DATE|TIME_MINUTES));
    Print("[BasePriceManager] ║    GMT Time:    ", TimeToString(barTimeGMT, TIME_DATE|TIME_MINUTES));
    Print("[BasePriceManager] ║    Close:       ", DoubleToString(barClose, Digits));
    }
    Print("[BasePriceManager] ╚═══════════════════════════════════════════════════════════════╝");
    }
    #else
#define PrintRecentM30Bars(count)
#endif
    struct BasePriceState
{
        string symbol;
    double basePriceCached;
    datetime lastProcessedBlockTimestamp;
    double referenceM1Power;
    string basePriceHistory[];
    int historyCount;
    int lastHistoryDay;
    int lastHistoryYear;
    bool systemInitialized;
    datetime lastAccessTime;};

    static BasePriceState g_symbolStates[];
    static int g_symbolStateCount = 0;
    static int _g_cachedStateIdx = -1;
    static string _g_cachedStateSymbol = "";
    #define MAX_SYMBOL_STATES 100
#define LOCK_TIMEOUT_SECONDS 2
#define LOCK_MAX_ATTEMPTS 5
#define LOCK_RETRY_DELAY_MS 20
#define SYMBOL_STATE_LRU_THRESHOLD 50
#define SYMBOL_STATE_INACTIVE_HOURS 24
//+------------------------------------------------------------------+
//| [OK] LRU Eviction: Remove least recently used symbol states        |

//+------------------------------------------------------------------+
void EvictLeastRecentlyUsedSymbolState() {
        if(g_symbolStateCount <= 1) return;
    datetime currentTime = TimeCurrent();
    int oldestIndex = -1;
    datetime oldestTime = currentTime;
    for(int i = 0; i < g_symbolStateCount; i++) {
        if(g_symbolStates[i].lastAccessTime < oldestTime) {
            oldestTime = g_symbolStates[i].lastAccessTime;
    oldestIndex = i;
        }
    }
    if(oldestIndex < 0) return;
    if((currentTime - oldestTime) < SYMBOL_STATE_INACTIVE_HOURS * 3600) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("[WARN] EvictLRU: Oldest state only ", 
              (currentTime - oldestTime) / 3600, "h old - not evicting yet");
    #endif
    return;
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("[DEL] EvictLRU: Removing symbol '", g_symbolStates[oldestIndex].symbol, 
          "' (inactive for ", (currentTime - oldestTime) / 3600, "h)");
    #endif
    ArrayFree(g_symbolStates[oldestIndex].basePriceHistory);
    for(int i = oldestIndex; i < g_symbolStateCount - 1; i++) {
        g_symbolStates[i] = g_symbolStates[i + 1];
    }
    g_symbolStateCount--;
    ArrayResize(g_symbolStates, g_symbolStateCount);
    _g_cachedStateIdx = -1;
    _g_cachedStateSymbol = "";
}
    int GetSymbolStateIndex()
{
        string currentSymbol = _Symbol;
    if(g_symbolStateCount < 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("[ERR] CRITICAL: Corrupted symbol state count (", g_symbolStateCount, ")");
    #endif
    g_symbolStateCount = 0;
    ArrayResize(g_symbolStates, 0);
    return -1;
    }
    if(g_symbolStateCount >= MAX_SYMBOL_STATES) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("[ERR] CRITICAL: Symbol state limit reached (", MAX_SYMBOL_STATES, ")");
    #endif
    return -1;
    }
    int arraySize = ArraySize(g_symbolStates);
    if(arraySize != g_symbolStateCount) {
        g_symbolStateCount = arraySize;
    }
    
    for(int i = 0; i < g_symbolStateCount && i < arraySize; i++)
    {
        if(g_symbolStates[i].symbol == currentSymbol)
        {            g_symbolStates[i].lastAccessTime = TimeCurrent();
    return i;
        }
    }
    if(g_symbolStateCount >= SYMBOL_STATE_LRU_THRESHOLD) {
        EvictLeastRecentlyUsedSymbolState();
    }
    if(g_symbolStateCount >= MAX_SYMBOL_STATES) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("[ERR] CRITICAL: Symbol state limit reached even after eviction");
    #endif
    return -1;
    }
    int newIndex = g_symbolStateCount;
    if(ArrayResize(g_symbolStates, newIndex + 1, 8) != newIndex + 1) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("[ERR] CRITICAL: Failed to resize symbol states array");
    #endif
    return -1;
    }
    g_symbolStates[newIndex].symbol = currentSymbol;
    g_symbolStates[newIndex].basePriceCached = 0.0;
    g_symbolStates[newIndex].lastProcessedBlockTimestamp = 0;
    g_symbolStates[newIndex].referenceM1Power = 0.0;
    g_symbolStates[newIndex].lastAccessTime = TimeCurrent();
    ArrayResize(g_symbolStates[newIndex].basePriceHistory, 0);
    g_symbolStates[newIndex].historyCount = 0;
    g_symbolStates[newIndex].lastHistoryDay = 0;
    g_symbolStates[newIndex].lastHistoryYear = 0;
    g_symbolStates[newIndex].systemInitialized = false;
    g_symbolStateCount++;
    #ifdef ENABLE_DEBUG_LOGS
    Print("[OK] Created new state for symbol: ", currentSymbol, " (Index: ", newIndex, ")");
    #endif
    return newIndex;
}string GetHistoryEntry(int index)
{
        int stateIdx = GetCachedSymbolStateIndex();
    if(stateIdx < 0) return "";
    if(index >= 0 && index < g_symbolStates[stateIdx].historyCount)
    {
        return g_symbolStates[stateIdx].basePriceHistory[index];
    }
    return "";
}
    void SetHistoryEntry(int index, string value)
{
        int stateIdx = GetCachedSymbolStateIndex();
    if(stateIdx < 0) return;
    if(index >= 0 && index < ArraySize(g_symbolStates[stateIdx].basePriceHistory))
    {
        g_symbolStates[stateIdx].basePriceHistory[index] = value;
    }
}
    void ResizeHistory(int newSize)
{
        int stateIdx = GetCachedSymbolStateIndex();
    if(stateIdx < 0) return;
    ArrayResize(g_symbolStates[stateIdx].basePriceHistory, newSize);
}
    void GetHistoryArray(string &output[])
{
        int stateIdx = GetCachedSymbolStateIndex();
    if(stateIdx < 0) { ArrayResize(output, 0); return; }
    int count = g_symbolStates[stateIdx].historyCount;
    ArrayResize(output, count);
    for(int i = 0; i < count; i++)
    {
        output[i] = g_symbolStates[stateIdx].basePriceHistory[i];
    }
}
    void SetHistoryArray(string &inputArray[], int count)
{
        int stateIdx = GetCachedSymbolStateIndex();
    if(stateIdx < 0) return;
    ArrayResize(g_symbolStates[stateIdx].basePriceHistory, count);
    for(int i = 0; i < count; i++)
    {
        g_symbolStates[stateIdx].basePriceHistory[i] = inputArray[i];
    }
    g_symbolStates[stateIdx].historyCount = count;
}//+------------------------------------------------------------------+
//| PERFORMANCE: Get Cached Symbol State Index                       |

//| Called 50+ times/tick -> now ONE call per tick via caching.      |
//+------------------------------------------------------------------+
int GetCachedSymbolStateIndex() {
        string sym = _Symbol;
    if(_g_cachedStateIdx >= 0 && _g_cachedStateSymbol == sym &&
       _g_cachedStateIdx < g_symbolStateCount) {
        return _g_cachedStateIdx;
    }
    _g_cachedStateIdx = GetSymbolStateIndex();
    _g_cachedStateSymbol = sym;
    return _g_cachedStateIdx;
}
    #define g_basePriceCached (g_symbolStates[GetCachedSymbolStateIndex()].basePriceCached)
#define g_lastProcessedBlockTimestamp (g_symbolStates[GetCachedSymbolStateIndex()].lastProcessedBlockTimestamp)
#define g_referenceM1Power (g_symbolStates[GetCachedSymbolStateIndex()].referenceM1Power)
#define g_historyCount (g_symbolStates[GetCachedSymbolStateIndex()].historyCount)
#define g_lastHistoryDay (g_symbolStates[GetCachedSymbolStateIndex()].lastHistoryDay)
#define g_lastHistoryYear (g_symbolStates[GetCachedSymbolStateIndex()].lastHistoryYear)
#define g_systemInitialized (g_symbolStates[GetCachedSymbolStateIndex()].systemInitialized)

bool ValidateRestoredBasePrice(const double restoredPrice, const double currentBid, double &validatedPrice)
{
        if(restoredPrice <= 0.0)
    {
        DEBUG_PRINT("[BasePriceManager] ValidateRestoredBasePrice() - ERROR: Invalid restored price, using bid");
    validatedPrice = currentBid;
    return false;
    }
    if(currentBid <= 0.0)
    {
        DEBUG_PRINT("[BasePriceManager] ValidateRestoredBasePrice() - ERROR: Invalid bid, using restored price");
    validatedPrice = restoredPrice;
    return true;
    }
    double percentDiff = MathAbs((restoredPrice - currentBid) / currentBid) * 100.0;
    if(percentDiff <= SANITY_CHECK_THRESHOLD_PERCENT)
    {        validatedPrice = restoredPrice;
    DEBUG_PRINTF2("[BasePriceManager] ValidateRestoredBasePrice() - [OK] ACCEPTED (diff=", DoubleToString(percentDiff, 2), "%)");
    return true;
    }
    else
    {        validatedPrice = currentBid;
    DEBUG_PRINTF5("[BasePriceManager] ValidateRestoredBasePrice() - [WARN] REJECTED (diff=", DoubleToString(percentDiff, 2), "% > ", DoubleToString(SANITY_CHECK_THRESHOLD_PERCENT, 1), "%), using bid", "");
    return false;
    }
}
    void InitializeBasePriceSystem()
{    if(!CheckHistoryFormatVersion(HISTORY_FORMAT_VERSION))
    {
        #ifdef ENABLE_DEBUG_LOGS
        Print("╔═══════════════════════════════════════════════════════════════╗");
    Print("║  HISTORY FORMAT UPGRADE DETECTED                              ║");
    Print("║  Cleaning up old history files with incorrect timestamps...  ║");
        Print("╚═══════════════════════════════════════════════════════════════╝");
    #endif
        
        DeleteAllHistoryFiles();
    UpdateHistoryFormatVersion(HISTORY_FORMAT_VERSION);
    #ifdef ENABLE_DEBUG_LOGS
        Print("╔═══════════════════════════════════════════════════════════════╗");
    Print("║  [OK] History cleanup complete. Will rebuild from M30 data.    ║");
    Print("╚═══════════════════════════════════════════════════════════════╝");
    #endif
    }
    datetime gmtTime = TimeGMT();
    datetime serverTime = TimeCurrent();
    MqlDateTime dtGMT, dtServer;
    TimeToStruct(gmtTime, dtGMT);
    TimeToStruct(serverTime, dtServer);
    int timezoneOffsetSeconds = (int)(serverTime - gmtTime);
    int timezoneOffsetHours = timezoneOffsetSeconds / 3600;
    #ifdef ENABLE_DEBUG_LOGS
    Print("[BasePriceManager] ╔═══════════════════════════════════════════════════════════════╗");
    Print("[BasePriceManager] ║  TIMEZONE INFORMATION                                         ║");
    Print("[BasePriceManager] ╠═══════════════════════════════════════════════════════════════╣");
    Print("[BasePriceManager] ║  Server Time: ", TimeToString(serverTime, TIME_DATE|TIME_MINUTES));
    Print("[BasePriceManager] ║  GMT Time:    ", TimeToString(gmtTime, TIME_DATE|TIME_MINUTES));
    Print("[BasePriceManager] ║  Offset:      Server = GMT", (timezoneOffsetHours >= 0 ? "+" : ""), timezoneOffsetHours, " hours");
    Print("[BasePriceManager] ║  Day (Server): ", dtServer.day_of_year + 1);
    Print("[BasePriceManager] ║  Day (GMT):    ", dtGMT.day_of_year + 1);
    Print("[BasePriceManager] ╚═══════════════════════════════════════════════════════════════╝");
    #endif
    PrintRecentM30Bars(5);
    int year = dtGMT.year;
    int dayOfYear = dtGMT.day_of_year + 1;
    if(!VerifyHistoryFileIntegrity(year, dayOfYear))
    {
        #ifdef ENABLE_DEBUG_LOGS
        Print("[BasePriceManager] InitializeBasePriceSystem() - File integrity check failed, attempting repair...");
    #endif
    int repairedCount = RepairHistoryFile(year, dayOfYear);
    if(repairedCount < 0)
        {
        #ifdef ENABLE_DEBUG_LOGS
            Print("[BasePriceManager] InitializeBasePriceSystem() - Repair failed, starting fresh");
    #endif
    }
    }
    DEBUG_PRINTF2("[BasePriceManager] InitializeBasePriceSystem() - Loading history for year=", IntegerToString(year), ", dayOfYear=" + IntegerToString(dayOfYear));
    string tempHistory[];
    int loadedCount = LoadBasePriceHistory(year, dayOfYear, tempHistory);
    bool needsMigration = false;
    if(loadedCount > 0)
    {
        #ifdef ENABLE_DEBUG_LOGS
        Print("[BasePriceManager] Checking ", loadedCount, " entries for migration...");
    #endif
    for(int i = 0; i < loadedCount; i++)
        {
        string entry = tempHistory[i];
    string parts[];
    int partCount = StringSplit(entry, '|', parts);
    if(partCount >= 1)
            {
        string timeStr = parts[0];
    string hourStr = StringSubstr(timeStr, 0, 2);
    int hour = (int)StringToInteger(hourStr);
    if(hour >= 22)
                {
                    needsMigration = true;
    #ifdef ENABLE_DEBUG_LOGS
                    Print("[BasePriceManager] [OK] Migration needed: Found entry at ", timeStr, " (yesterday's data)");
    #endif
    break;                }
            }
        }
    #ifdef ENABLE_DEBUG_LOGS
        if(!needsMigration)
        {
            Print("[BasePriceManager] [OK] No migration needed: All entries are from today");
        }
    #endif
    }
    if(needsMigration && loadedCount > 0)
    {
        #ifdef ENABLE_DEBUG_LOGS
        Print("╔═══════════════════════════════════════════════════════════════╗");
    Print("║  MIGRATION DETECTED - OLD FORMAT WITH SERVER TIME             ║");
    Print("║  Deleting old file and rebuilding with GMT format...         ║");
        Print("╚═══════════════════════════════════════════════════════════════╝");
    #endif
    string filePath = GetHistoryFilePath(year, dayOfYear);
    if(FileDelete(filePath))
        {
        #ifdef ENABLE_DEBUG_LOGS
            Print("[BasePriceManager] [OK] Old history file deleted successfully");
    #endif
    }
        else
        {
        #ifdef ENABLE_DEBUG_LOGS
            Print("[BasePriceManager] [WARN] Could not delete old file (error: ", GetLastError(), ")");
    #endif
    }
    loadedCount = 0;
    ArrayResize(tempHistory, 0);
    }
    
    SetHistoryArray(tempHistory, loadedCount);
    g_historyCount = loadedCount;
    g_lastHistoryDay = dayOfYear;
    g_lastHistoryYear = year;
    DEBUG_PRINTF("[BasePriceManager] InitializeBasePriceSystem() - Loaded ", IntegerToString(loadedCount) + " entries");
    if(loadedCount > 0)
    {
        string workingHistory[];
    GetHistoryArray(workingHistory);
    int newCount = DeduplicateHistory(workingHistory, g_historyCount);
    bool needsSave = (newCount != g_historyCount);
    g_historyCount = newCount;
    int migratedCount = MigrateToNewFormat(workingHistory, g_historyCount);
    if(migratedCount > 0)
        {
            needsSave = true;
        }
    SetHistoryArray(workingHistory, g_historyCount);
    if(needsSave)
        {
            SaveBasePriceHistory(year, dayOfYear, workingHistory, g_historyCount);
        }
    if(g_historyCount > 0)
        {
        string lastEntry = GetHistoryEntry(g_historyCount - 1);
    string parts[];
    int partCount = StringSplit(lastEntry, '|', parts);
    if(partCount >= 3)
            {
        string refPriceStr = parts[2];
    int spacePos = StringFind(refPriceStr, " ");
    if(spacePos > 0)
                {
                    refPriceStr = StringSubstr(refPriceStr, 0, spacePos);
                }
    double restoredPrice = StringToDouble(refPriceStr);
    double currentBid = Bid;
    double validatedPrice = 0.0;
    bool isValid = ValidateRestoredBasePrice(restoredPrice, currentBid, validatedPrice);
    g_basePriceCached = validatedPrice;
    g_referenceM1Power = CalculateM1PowerForBasePrice(g_basePriceCached);
    #ifdef ENABLE_DEBUG_LOGS
                if(!g_systemInitialized)
                {
                    Print("╔═══════════════════════════════════════════════════════════════╗");
    if(isValid)
                    {
                        Print("║  [OK] BASE PRICE RESTORED: ", DoubleToString(g_basePriceCached, Digits), " | M1: ", DoubleToString(g_referenceM1Power, 5));
    }
                    else
                    {
                        Print("║  [WARN] STALE PRICE REJECTED: ", DoubleToString(restoredPrice, Digits), " -> ", DoubleToString(g_basePriceCached, Digits));
    }
                    Print("╚═══════════════════════════════════════════════════════════════╝");
    }
    #endif
    }
        }
        else
        {
        double currentBid = Bid;
    if(currentBid > 0.0)
            {
                g_basePriceCached = currentBid;
    g_referenceM1Power = CalculateM1PowerForBasePrice(g_basePriceCached);
    #ifdef ENABLE_DEBUG_LOGS
                if(!g_systemInitialized)
                {
                    Print("╔═══════════════════════════════════════════════════════════════╗");
                    Print("║  [NEW] BASE PRICE INIT: ", DoubleToString(g_basePriceCached, Digits), " | M1: ", DoubleToString(g_referenceM1Power, 5));
    Print("╚═══════════════════════════════════════════════════════════════╝");
    }
    #endif
    }
        }
    }
    else
    {
        double currentBid = Bid;
    if(currentBid > 0.0)
        {
            g_basePriceCached = currentBid;
    g_referenceM1Power = CalculateM1PowerForBasePrice(g_basePriceCached);
    #ifdef ENABLE_DEBUG_LOGS
            if(!g_systemInitialized)
            {
                Print("╔═══════════════════════════════════════════════════════════════╗");
                Print("║  [NEW] BASE PRICE INIT (First Run): ", DoubleToString(g_basePriceCached, Digits), " | M1: ", DoubleToString(g_referenceM1Power, 5));
    Print("╚═══════════════════════════════════════════════════════════════╝");
    }
    #endif
    }
    }
    if(!g_systemInitialized)
    {
        CleanupTemporaryFiles();
    CleanupOldHistory(DEFAULT_DAYS_TO_KEEP);
    #ifdef ENABLE_DEBUG_LOGS
        if(g_historyCount > 0)
        {
            Print("╔═══════════════════════════════════════════════════════════════╗");
            Print("║  CHART REOPENED - RESTORING TODAY'S BASE PRICE               ║");
    Print("║  Date: Day ", dayOfYear, " of Year ", year);
    Print("║  Base Price: ", DoubleToString(g_basePriceCached, Digits));
    Print("║  Total Entries: ", g_historyCount);
    Print("╚═══════════════════════════════════════════════════════════════╝");
    PrintBasePriceHistory();
    SaveBasePriceHistoryToFile();
        }
        else
        {
            Print("╔═══════════════════════════════════════════════════════════════╗");
    Print("║  [NEW] FIRST RUN TODAY - REBUILDING HISTORY FROM START OF DAY   ║");
    Print("║  Current time: ", TimeToString(gmtTime, TIME_DATE|TIME_MINUTES));
    Print("╚═══════════════════════════════════════════════════════════════╝");
    }
    #endif
    if(g_historyCount == 0)
        {
            RebuildHistoryFromStartOfDay();
    #ifdef ENABLE_DEBUG_LOGS
            if(g_historyCount > 0)
            {
                Print("╔═══════════════════════════════════════════════════════════════╗");
                Print("║  [OK] HISTORY REBUILT SUCCESSFULLY                             ║");
    Print("║  Total Entries: ", g_historyCount);
    Print("║  Base Price: ", DoubleToString(g_basePriceCached, Digits));
    Print("╚═══════════════════════════════════════════════════════════════╝");
    PrintBasePriceHistory();
    SaveBasePriceHistoryToFile();
            }
    #endif
    }
    }
    
    g_systemInitialized = true;
}
    datetime ConvertServerToGMT(const datetime serverTime)
{
        datetime gmtNow = TimeGMT();
    datetime serverNow = TimeCurrent();
    int timezoneOffsetSeconds = (int)(serverNow - gmtNow);
    datetime gmtTime = serverTime - timezoneOffsetSeconds;
    MqlDateTime dt;
    TimeToStruct(gmtTime, dt);
    dt.sec = 0;
    gmtTime = StructToTime(dt);
    return gmtTime;
}
    datetime ConvertGMTToServer(const datetime gmtTime)
{
        datetime gmtNow = TimeGMT();
    datetime serverNow = TimeCurrent();
    int timezoneOffsetSeconds = (int)(serverNow - gmtNow);
    datetime serverTime = gmtTime + timezoneOffsetSeconds;
    MqlDateTime dt;
    TimeToStruct(serverTime, dt);
    dt.sec = 0;
    serverTime = StructToTime(dt);
    return serverTime;
}
    double CalculateM1PowerForBasePrice(const double basePrice)
{
        if(basePrice <= 0) return 0.0;
    double m1Percent = 0.0208;
    double powerM1 = basePrice * m1Percent;
    return powerM1;
}
    int FindLastM1CandleInBlock(const datetime blockStart, const datetime blockEnd)
{
        int totalM1Bars = iBars(_Symbol, PERIOD_M1);
    if(totalM1Bars <= 0)
    {
        #ifdef ENABLE_DEBUG_LOGS
        Print("[BasePriceManager] FindLastM1CandleInBlock() - No M1 bars available");
    #endif
    return -1;
    }
    int searchLimit = MathMin(totalM1Bars, 1000);
    int lastBarIdx = -1;
    datetime lastBarTime = 0;
    for(int i = 0; i < searchLimit; i++)
    {
        datetime barTime = iTime(_Symbol, PERIOD_M1, i);
    if(barTime >= blockStart && barTime < blockEnd)
        {
        if(lastBarIdx == -1 || barTime > lastBarTime)
            {
                lastBarIdx = i;
    lastBarTime = barTime;
            }
        }
    if(barTime < blockStart)
        {
            break;
        }
    }
    #ifdef ENABLE_DEBUG_LOGS
    if(lastBarIdx != -1)
    {
        Print("[BasePriceManager] FindLastM1CandleInBlock() - Found M1 bar #", lastBarIdx, 
              " at ", TimeToString(lastBarTime, TIME_DATE|TIME_MINUTES),
              " in block [", TimeToString(blockStart, TIME_MINUTES), "-",
              TimeToString(blockEnd, TIME_MINUTES), "]");
    }
    else
    {
        Print("[BasePriceManager] FindLastM1CandleInBlock() - No M1 bar found in block [",
    TimeToString(blockStart, TIME_MINUTES), "-",
              TimeToString(blockEnd, TIME_MINUTES), "]");
    }
    #endif
    return lastBarIdx;
}

//+------------------------------------------------------------------+
//| PERF: Extract timeBlock key from a history entry (text before |) |
//+------------------------------------------------------------------+
string ExtractTimeBlock(const string &entry)
{
    int pipePos = StringFind(entry, "|");
    if(pipePos <= 0) return "";
    return StringSubstr(entry, 0, pipePos);
}

    void MergeHistoryLists(const string &existingHistory[], const int existingCount,
                       const string &rebuiltHistory[], const int rebuiltCount,
                       string &mergedHistory[], int &mergedCount)
{
    #ifdef ENABLE_DEBUG_LOGS
    Print("[BasePriceManager] MergeHistoryLists() - Merging ", existingCount, " existing + ", rebuiltCount, " rebuilt entries");
    #endif

    int maxSize = existingCount + rebuiltCount;
    if(maxSize <= 0 || maxSize > 10000) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("MergeHistoryLists: Invalid total size: ", maxSize);
        #endif
        ArrayResize(mergedHistory, 0);
        mergedCount = 0;
        return;
    }

    // Collect all valid entries and their timeBlock keys
    string timeBlocks[];
    string entries[];
    ArrayResize(timeBlocks, maxSize);
    ArrayResize(entries, maxSize);
    int totalEntries = 0;

    // Phase 1: Gather all entries from both sources (no dedup yet — O(n))
    for(int i = 0; i < existingCount; i++) {
        if(StringLen(existingHistory[i]) == 0) continue;
        string tb = ExtractTimeBlock(existingHistory[i]);
        if(StringLen(tb) == 0) continue;
        timeBlocks[totalEntries] = tb;
        entries[totalEntries] = existingHistory[i];
        totalEntries++;
    }
    for(int i = 0; i < rebuiltCount; i++) {
        if(StringLen(rebuiltHistory[i]) == 0) continue;
        string tb = ExtractTimeBlock(rebuiltHistory[i]);
        if(StringLen(tb) == 0) continue;
        timeBlocks[totalEntries] = tb;
        entries[totalEntries] = rebuiltHistory[i];
        totalEntries++;
    }

    // Phase 2: Comb sort by timeBlock — O(n log n) average
    int gap = totalEntries;
    double shrink = 1.3;
    bool sorted = false;
    while(!sorted) {
        gap = (int)(gap / shrink);
        if(gap <= 1) { gap = 1; sorted = true; }
        for(int i = 0; i + gap < totalEntries; i++) {
            if(timeBlocks[i] > timeBlocks[i + gap]) {
                string tempTime = timeBlocks[i];
                string tempEntry = entries[i];
                timeBlocks[i] = timeBlocks[i + gap];
                entries[i] = entries[i + gap];
                timeBlocks[i + gap] = tempTime;
                entries[i + gap] = tempEntry;
                sorted = false;
            }
        }
    }

    // Phase 3: Deduplicate consecutive identical timeBlocks — O(n)
    // First entry from each duplicate group wins (existing entries were added first)
    int uniqueCount = 0;
    ArrayResize(mergedHistory, totalEntries);
    for(int i = 0; i < totalEntries; i++) {
        if(i == 0 || timeBlocks[i] != timeBlocks[i - 1]) {
            mergedHistory[uniqueCount] = entries[i];
            uniqueCount++;
        }
        #ifdef ENABLE_DEBUG_LOGS
        else {
            Print("[BasePriceManager] MergeHistoryLists() - Skipping duplicate time block: ", timeBlocks[i]);
        }
        #endif
    }
    ArrayResize(mergedHistory, uniqueCount);
    mergedCount = uniqueCount;

    #ifdef ENABLE_DEBUG_LOGS
    Print("[BasePriceManager] MergeHistoryLists() - Merged result: ", mergedCount, " total entries");
    #endif
    }
    bool HistoryEntryExists(const string blockTimeStr)
{
        if(StringLen(blockTimeStr) == 0) return false;
    for(int i = 0; i < g_historyCount; i++)
    {
        string entry = GetHistoryEntry(i);
    if(StringLen(entry) == 0) continue;
    int pipePos = StringFind(entry, "|");
    if(pipePos <= 0) continue;
    string entryTime = StringSubstr(entry, 0, pipePos);
    if(entryTime == blockTimeStr)
        {
        return true;
        }
    }
    return false;
}
    void AddBasePriceHistoryEntry(const datetime blockTime, const double thirtyMinPrice, 
                               const double refPrice, const string status, 
                               const double deltaPct, const double oldM1, const double newM1)
{
        datetime blockTimeGMT = ConvertServerToGMT(blockTime);
    string timeStr = TimeToString(blockTimeGMT, TIME_MINUTES);
    string refPriceStr;
    if(status == "-")
    {        refPriceStr = StringFormat("%.5f (INITIAL)", refPrice);
    }
    else
    {
        double priceChange = refPrice - g_basePriceCached;
    refPriceStr = StringFormat("%.5f (%+.5f)", refPrice, priceChange);
    }
    string entry = StringFormat("%s|%.5f|%s|%s|%.5f|%.5f|%.5f",
                                 timeStr, thirtyMinPrice, refPriceStr,
                                 status, g_referenceM1Power, oldM1, newM1);
    if(!HistoryEntryExists(timeStr))
    {
        ResizeHistory(g_historyCount + 1);
    SetHistoryEntry(g_historyCount, entry);
    g_historyCount++;
    #ifdef ENABLE_DEBUG_LOGS
        Print("[LOG] History: ", entry);
    #endif
    MqlDateTime dt;
    TimeToStruct(blockTime, dt);
    int dayOfYear = dt.day_of_year + 1;
    if(!AppendBasePriceHistoryEntry(dt.year, dayOfYear, entry))
        {
        #ifdef ENABLE_DEBUG_LOGS
            Print("[WARN] WARNING: Failed to persist history entry to file");
    #endif
    }
    }
    else
    {
        #ifdef ENABLE_DEBUG_LOGS
        Print("[WARN] Skipping duplicate history entry for block ", timeStr);
    #endif
    }
}
    bool UpdateBasePrice()
{
        datetime currentTime = TimeCurrent();
    int currentMinute = TimeMinute(currentTime);
    if(currentMinute != 0 && currentMinute != 30)
    {
        return false;
    }
    int totalMinutes = TimeMinute(currentTime) + TimeHour(currentTime) * 60;
    int blockNumber = totalMinutes / BLOCK_MINUTES;
    int blockStartMinutes = blockNumber * BLOCK_MINUTES;
    int blockStartHour = blockStartMinutes / 60;
    int blockStartMinute = blockStartMinutes % 60;
    MqlDateTime dt;
    TimeToStruct(currentTime, dt);
    dt.hour = blockStartHour;
    dt.min = blockStartMinute;
    dt.sec = 0;
    datetime currentBlockStart = StructToTime(dt);
    datetime previousBlockStart = currentBlockStart - BLOCK_MINUTES * 60;
    datetime previousBlockStartGMT = ConvertServerToGMT(previousBlockStart);
    string blockTimeStr = TimeToString(previousBlockStartGMT, TIME_MINUTES);
    if(HistoryEntryExists(blockTimeStr))
    {
        if(g_lastProcessedBlockTimestamp != previousBlockStart)
        {
        #ifdef ENABLE_DEBUG_LOGS
            Print("[BasePriceManager] UpdateBasePrice() - Entry already exists for block ", blockTimeStr, " (GMT), skipping");
    #endif
    g_lastProcessedBlockTimestamp = previousBlockStart;
        }
    return false;
    }
    TimeToStruct(currentTime, dt);
    int currentDayOfYear = dt.day_of_year + 1;
    if(currentDayOfYear != g_lastHistoryDay || dt.year != g_lastHistoryYear)
    {
        #ifdef ENABLE_DEBUG_LOGS
        Print("╔═══════════════════════════════════════════════════════════════╗");
    #endif
    #ifdef ENABLE_DEBUG_LOGS
        Print("║  [NEW] NEW DAY DETECTED - RESETTING BASE PRICE HISTORY           ║");
    #endif
    #ifdef ENABLE_DEBUG_LOGS
        Print("╠═══════════════════════════════════════════════════════════════╣");
    #endif
    #ifdef ENABLE_DEBUG_LOGS
        Print("║  Old Date: ", g_lastHistoryYear, "/", g_lastHistoryDay);
    #endif
    #ifdef ENABLE_DEBUG_LOGS
        Print("║  New Date: ", dt.year, "/", currentDayOfYear);
    #endif
    #ifdef ENABLE_DEBUG_LOGS
        Print("║  Action: Clearing all history and resetting base price");
    #endif
    #ifdef ENABLE_DEBUG_LOGS
        Print("╚═══════════════════════════════════════════════════════════════╝");
    #endif
    ResizeHistory(0);
    g_historyCount = 0;
    g_lastHistoryDay = currentDayOfYear;
    g_lastHistoryYear = dt.year;
    g_basePriceCached = EMPTY_VALUE;
    g_referenceM1Power = 0.0;
    }
    int m30BarIdx = 1;
    datetime m30BarTime = iTime(_Symbol, PERIOD_M30, m30BarIdx);
    double newBasePrice = iClose(_Symbol, PERIOD_M30, m30BarIdx);
    if(m30BarTime == 0)
    {
        #ifdef ENABLE_DEBUG_LOGS
        Print("[BasePriceManager] UpdateBasePrice() - ERROR: No M30 bar available");
    #endif
    return false;
    }
    if(newBasePrice <= 0.0)
    {
        #ifdef ENABLE_DEBUG_LOGS
        Print("[BasePriceManager] UpdateBasePrice() - ERROR: Invalid M30 close price: ", newBasePrice);
    #endif
    return false;
    }
    datetime m30BarTimeGMT = ConvertServerToGMT(m30BarTime);
    datetime gmtNow = TimeGMT();
    datetime serverNow = TimeCurrent();
    int timezoneOffsetHours = (int)((serverNow - gmtNow) / 3600);
    #ifdef ENABLE_DEBUG_LOGS
    Print("[BasePriceManager] ╔═══════════════════════════════════════════════════════════════╗");
    #endif
    #ifdef ENABLE_DEBUG_LOGS
    Print("[BasePriceManager] ║  M30 BAR DETAILS                                              ║");
    #endif
    #ifdef ENABLE_DEBUG_LOGS
    Print("[BasePriceManager] ╠═══════════════════════════════════════════════════════════════╣");
    #endif
    #ifdef ENABLE_DEBUG_LOGS
    Print("[BasePriceManager] ║  Bar Index:        ", m30BarIdx);
    #endif
    #ifdef ENABLE_DEBUG_LOGS
    Print("[BasePriceManager] ║  Server Time:      ", TimeToString(m30BarTime, TIME_DATE|TIME_MINUTES));
    #endif
    #ifdef ENABLE_DEBUG_LOGS
    Print("[BasePriceManager] ║  GMT Time:         ", TimeToString(m30BarTimeGMT, TIME_DATE|TIME_MINUTES));
    #endif
    #ifdef ENABLE_DEBUG_LOGS
    Print("[BasePriceManager] ║  Expected Block:   ", TimeToString(previousBlockStartGMT, TIME_DATE|TIME_MINUTES), " (GMT)");
    #endif
    #ifdef ENABLE_DEBUG_LOGS
    Print("[BasePriceManager] ║  Close Price:      ", DoubleToString(newBasePrice, Digits));
    #endif
    #ifdef ENABLE_DEBUG_LOGS
    Print("[BasePriceManager] ║  Timezone Offset:  GMT", (timezoneOffsetHours >= 0 ? "+" : ""), timezoneOffsetHours, " hours");
    #endif
    #ifdef ENABLE_DEBUG_LOGS
    Print("[BasePriceManager] ╚═══════════════════════════════════════════════════════════════╝");
    #endif
    if(g_basePriceCached == EMPTY_VALUE || g_basePriceCached == 0.0)
    {        g_basePriceCached = newBasePrice;
    g_referenceM1Power = CalculateM1PowerForBasePrice(newBasePrice);
    AddBasePriceHistoryEntry(m30BarTime, newBasePrice, newBasePrice, 
                                 "-", 0.0, 0.0, g_referenceM1Power);
    #ifdef ENABLE_DEBUG_LOGS
        Print("INIT: Base price ", DoubleToString(newBasePrice, Digits), " | M1: ", DoubleToString(g_referenceM1Power, 5));
    #endif
    return true;
    }
    double oldPowerM1 = g_referenceM1Power;
    double newPowerM1 = CalculateM1PowerForBasePrice(newBasePrice);
    double deltaAbsPct = 0.0;
    if(oldPowerM1 != 0.0 && MathAbs(oldPowerM1) > 0.0000001)
    {
        deltaAbsPct = MathAbs(newPowerM1 - oldPowerM1) / MathAbs(oldPowerM1) * 100.0;
    }
    else
    {
        deltaAbsPct = 999.99;
    }
    double thresholdPercent = inpBasePriceThresholdEnabled ? inpBasePriceThresholdPercent : 0.0;
    datetime timeSinceLastUpdate = m30BarTime - g_lastProcessedBlockTimestamp;
    bool forceUpdateDueToAge = (timeSinceLastUpdate > 86400);
    if(deltaAbsPct >= thresholdPercent || forceUpdateDueToAge)
    {
        double oldBasePrice = g_basePriceCached;
    g_basePriceCached = newBasePrice;
    g_referenceM1Power = newPowerM1;
    #ifdef ENABLE_DEBUG_LOGS
        if(forceUpdateDueToAge) {
            Print("[TIME] FORCED UPDATE: Base price too old (", timeSinceLastUpdate/3600, "h) - delta=", DoubleToString(deltaAbsPct, 3), "%");
        }
    #endif
    string okStatus = StringFormat("OK D=%.3f%%", deltaAbsPct);
    AddBasePriceHistoryEntry(m30BarTime, newBasePrice, newBasePrice, 
                                 okStatus, deltaAbsPct, oldPowerM1, newPowerM1);
    #ifdef ENABLE_DEBUG_LOGS
        Print("OK: Base price updated to ", DoubleToString(newBasePrice, Digits), 
              " (D=", DoubleToString(deltaAbsPct, 3), "%)");
    #endif
    SaveBasePriceHistoryToFile();
    return true;
    }
    else
    {
        string skipStatus = StringFormat("SKIP D=%.3f%%", deltaAbsPct);
    AddBasePriceHistoryEntry(m30BarTime, newBasePrice, g_basePriceCached, 
                                 skipStatus, deltaAbsPct, oldPowerM1, newPowerM1);
    #ifdef ENABLE_DEBUG_LOGS
        Print("SKIP: Base price unchanged at ", DoubleToString(g_basePriceCached, Digits),
              " (D=", DoubleToString(deltaAbsPct, 3), "%)");
    #endif
    SaveBasePriceHistoryToFile();
    return false;
    }
}
    void RebuildHistoryFromStartOfDay()
{
        #ifdef ENABLE_DEBUG_LOGS
    Print("╔═══════════════════════════════════════════════════════════════╗");
    #endif
    #ifdef ENABLE_DEBUG_LOGS
    Print("║  REBUILD HISTORY FROM START OF DAY                           ║");
    #endif
    #ifdef ENABLE_DEBUG_LOGS
    Print("╚═══════════════════════════════════════════════════════════════╝");
    #endif
    datetime gmtTime = TimeGMT();
    datetime serverTime = TimeCurrent();
    datetime startOfDayGMT;
    bool useDynamic = inpUseDynamicTradingDay;
    if(useDynamic)
    {        startOfDayGMT = FindCurrentSessionStart(PERIOD_M1);
    #ifdef ENABLE_DEBUG_LOGS
        Print("[BasePriceManager] Using DYNAMIC detection: Trading day starts at ", 
              TimeToString(startOfDayGMT, TIME_DATE|TIME_MINUTES));
    #endif
    }
    else
    {
        int startHour = GetTradingDayStartHour(Symbol());
    ENUM_MARKET_TYPE marketType = DetectMarketType(Symbol());
    #ifdef ENABLE_DEBUG_LOGS
        Print("[BasePriceManager] Symbol: ", Symbol(), " | Market Type: ", GetMarketTypeName(marketType), 
              " | Trading day starts at: ", startHour, ":00 GMT");
    #endif
    MqlDateTime dtGMT;
    TimeToStruct(gmtTime, dtGMT);
    dtGMT.hour = startHour;
    dtGMT.min = 0;
    dtGMT.sec = 0;
    startOfDayGMT = StructToTime(dtGMT);
    if(startHour == 22 && gmtTime < startOfDayGMT)
        {
            startOfDayGMT -= 24 * 60 * 60;
    #ifdef ENABLE_DEBUG_LOGS
            Print("[BasePriceManager] Adjusted start time to previous day (before 22:00)");
    #endif
    }
    #ifdef ENABLE_DEBUG_LOGS
        Print("[BasePriceManager] Using MARKET TYPE default: Trading day starts at ", 
              TimeToString(startOfDayGMT, TIME_DATE|TIME_MINUTES));
    #endif
    }
    datetime startOfDayServer = ConvertGMTToServer(startOfDayGMT);
    MqlDateTime dtGMT;
    TimeToStruct(gmtTime, dtGMT);
    int blockMinute = (dtGMT.min / 30) * 30;
    dtGMT.min = blockMinute;
    dtGMT.sec = 0;
    datetime currentBlockStartGMT = StructToTime(dtGMT);
    datetime currentBlockStartServer = ConvertGMTToServer(currentBlockStartGMT);
    #ifdef ENABLE_DEBUG_LOGS
    Print("[BasePriceManager] Start of day (Server): ", TimeToString(startOfDayServer, TIME_DATE|TIME_MINUTES));
    #endif
    #ifdef ENABLE_DEBUG_LOGS
    Print("[BasePriceManager] Start of day (GMT): ", TimeToString(startOfDayGMT, TIME_DATE|TIME_MINUTES));
    #endif
    #ifdef ENABLE_DEBUG_LOGS
    Print("[BasePriceManager] Current block (Server): ", TimeToString(currentBlockStartServer, TIME_DATE|TIME_MINUTES));
    #endif
    #ifdef ENABLE_DEBUG_LOGS
    Print("[BasePriceManager] Current block (GMT): ", TimeToString(currentBlockStartGMT, TIME_DATE|TIME_MINUTES));
    #endif
    int totalMinutes = (int)((currentBlockStartServer - startOfDayServer) / 60);
    int totalBlocks = totalMinutes / 30;
    #ifdef ENABLE_DEBUG_LOGS
    Print("[BasePriceManager] Total completed blocks to rebuild: ", totalBlocks);
    #endif
    string existingHistory[];
    int existingCount = g_historyCount;
    GetHistoryArray(existingHistory);
    string rebuiltHistory[];
    int rebuiltCount = 0;
    ArrayResize(rebuiltHistory, totalBlocks);
    int successCount = 0;
    int skipCount = 0;
    int missingDataCount = 0;
    double rebuildReferencePrice = 0.0;
    double rebuildReferenceM1 = 0.0;
    bool isFirstEntry = true;
    for(int blockNum = 0; blockNum < totalBlocks; blockNum++)
    {
        datetime blockStartServer = startOfDayServer + (blockNum * 30 * 60);
    datetime blockEndServer = blockStartServer + (30 * 60);
    datetime blockStartGMT = ConvertServerToGMT(blockStartServer);
    string blockTimeStr = TimeToString(blockStartGMT, TIME_MINUTES);
    if(HistoryEntryExists(blockTimeStr))
        {
        #ifdef ENABLE_DEBUG_LOGS
            Print("[BasePriceManager] Block ", blockTimeStr, " already exists, skipping");
    #endif
    continue;
        }
    int m30BarIdx = iBarShift(_Symbol, PERIOD_M30, blockStartServer, false);
    if(m30BarIdx == -1)
        {
        #ifdef ENABLE_DEBUG_LOGS
            Print("[BasePriceManager] [WARN] No M30 data for block ", blockTimeStr, 
                  " (GMT), Server: ", TimeToString(blockStartServer, TIME_MINUTES));
    #endif
    missingDataCount++;
    continue;
        }
    double closePrice = iClose(_Symbol, PERIOD_M30, m30BarIdx);
    if(closePrice <= 0.0)
        {
        #ifdef ENABLE_DEBUG_LOGS
            Print("[BasePriceManager] [WARN] Invalid M30 candle price for block ", blockTimeStr, ": ", closePrice);
    #endif
    missingDataCount++;
    continue;
        }
    datetime m30BarTime = iTime(_Symbol, PERIOD_M30, m30BarIdx);
    #ifdef ENABLE_DEBUG_LOGS
        Print("[BasePriceManager] Block ", blockTimeStr, 
              " | M30 Bar: ", TimeToString(m30BarTime, TIME_MINUTES),
              " | Close: ", DoubleToString(closePrice, Digits));
    #endif
    double newM1Power = CalculateM1PowerForBasePrice(closePrice);
    if(isFirstEntry)
        {
            rebuildReferencePrice = closePrice;
    rebuildReferenceM1 = newM1Power;
    string entry = StringFormat("%s|%.5f|%.5f (INITIAL)|-|-|%.5f|-",
                                       blockTimeStr, closePrice, closePrice, newM1Power);
    rebuiltHistory[rebuiltCount] = entry;
    rebuiltCount++;
    successCount++;
    isFirstEntry = false;
    #ifdef ENABLE_DEBUG_LOGS
            Print("[BasePriceManager] INIT: ", blockTimeStr, " | Price: ", DoubleToString(closePrice, Digits));
    #endif
    continue;
        }
    double deltaAbsPct = 0.0;
    if(rebuildReferenceM1 != 0.0 && MathAbs(rebuildReferenceM1) > 0.0000001)
        {
            deltaAbsPct = MathAbs(newM1Power - rebuildReferenceM1) / MathAbs(rebuildReferenceM1) * 100.0;
        }
        else
        {
            deltaAbsPct = 999.99;
        }
    double validatedPrice = 0.0;
    bool isValid = ValidateRestoredBasePrice(closePrice, rebuildReferencePrice, validatedPrice);
    string status;
    double refPrice;
    double oldM1 = rebuildReferenceM1;
    double thresholdPercent = inpBasePriceThresholdEnabled ? inpBasePriceThresholdPercent : 0.0;
    if(isValid && deltaAbsPct >= thresholdPercent)
        {            status = StringFormat("OK D=%.3f%%", deltaAbsPct);
    refPrice = closePrice;
    rebuildReferencePrice = closePrice;
    rebuildReferenceM1 = newM1Power;
    successCount++;
        }
        else
        {            if(!isValid)
            {
                status = StringFormat("SKIP ?=%.3f%%", deltaAbsPct);
            }
            else
            {
                status = StringFormat("SKIP D=%.3f%%", deltaAbsPct);
            }
            refPrice = rebuildReferencePrice;
    skipCount++;
        }
    double priceChange = refPrice - rebuildReferencePrice;
    string entry = StringFormat("%s|%.5f|%.5f (%+.5f)|%s|%.5f|%.5f|%.5f",
                                   blockTimeStr, closePrice, refPrice, priceChange,
                                   status, rebuildReferenceM1, oldM1, newM1Power);
    rebuiltHistory[rebuiltCount] = entry;
    rebuiltCount++;
    #ifdef ENABLE_DEBUG_LOGS
        Print("[BasePriceManager] ", status, ": ", blockTimeStr, " | Price: ", DoubleToString(closePrice, Digits));
    #endif
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("╔═══════════════════════════════════════════════════════════════╗");
    #endif
    #ifdef ENABLE_DEBUG_LOGS
    Print("║  REBUILD STATISTICS                                           ║");
    #endif
    #ifdef ENABLE_DEBUG_LOGS
    Print("╠═══════════════════════════════════════════════════════════════╣");
    #endif
    #ifdef ENABLE_DEBUG_LOGS
    Print("║  Total Blocks: ", totalBlocks);
    #endif
    #ifdef ENABLE_DEBUG_LOGS
    Print("║  Success: ", successCount);
    #endif
    #ifdef ENABLE_DEBUG_LOGS
    Print("║  Skipped: ", skipCount);
    #endif
    #ifdef ENABLE_DEBUG_LOGS
    Print("║  Missing Data: ", missingDataCount);
    #endif
    #ifdef ENABLE_DEBUG_LOGS
    Print("║  Rebuilt Entries: ", rebuiltCount);
    #endif
    #ifdef ENABLE_DEBUG_LOGS
    Print("║  Existing Entries: ", existingCount);
    #endif
    #ifdef ENABLE_DEBUG_LOGS
    Print("╚═══════════════════════════════════════════════════════════════╝");
    #endif
    string mergedHistory[];
    int mergedCount = 0;
    MergeHistoryLists(existingHistory, existingCount, rebuiltHistory, rebuiltCount, mergedHistory, mergedCount);
    SetHistoryArray(mergedHistory, mergedCount);
    g_historyCount = mergedCount;
    if(g_historyCount > 0)
    {
        g_basePriceCached = rebuildReferencePrice;
    g_referenceM1Power = rebuildReferenceM1;
    }
    MqlDateTime dtSave;
    TimeToStruct(TimeGMT(), dtSave);
    SaveBasePriceHistory(dtSave.year, dtSave.day_of_year + 1, mergedHistory, g_historyCount);
    #ifdef ENABLE_DEBUG_LOGS
    Print("╔═══════════════════════════════════════════════════════════════╗");
    #endif
    #ifdef ENABLE_DEBUG_LOGS
    Print("║  [OK] REBUILD COMPLETE                                          ║");
    #endif
    #ifdef ENABLE_DEBUG_LOGS
    Print("║  Total Entries: ", g_historyCount);
    #endif
    #ifdef ENABLE_DEBUG_LOGS
    Print("║  Base Price: ", DoubleToString(g_basePriceCached, Digits));
    #endif
    #ifdef ENABLE_DEBUG_LOGS
    Print("║  M1 Power: ", DoubleToString(g_referenceM1Power, 5));
    #endif
    #ifdef ENABLE_DEBUG_LOGS
    Print("╚═══════════════════════════════════════════════════════════════╝");
    #endif
    }
    double GetBasePriceForTH()
{
        if(g_basePriceCached == EMPTY_VALUE || g_basePriceCached == 0.0)
    {
        return g_dailyClosePriceForTH;
    }
    return g_basePriceCached;
}
    #ifdef ENABLE_DEBUG_LOGS
void PrintBasePriceHistory()
{
        if(g_historyCount == 0)
    {
        Print("[DATA] Base Price History: No entries yet");
    return;
    }
    
    MqlDateTime dt;
    TimeToStruct(TimeGMT(), dt);
    Print("+---------------------------------------------------------------------------------------------------------------------+");
    Print("|  [DATA] BASE PRICE HISTORY TODAY (All 30-min updates) - ", g_historyCount, " entries                                                    |");
    Print("+---------------------------------------------------------------------------------------------------------------------+");
    Print("|  Time  | 30-Min Price    | Ref Price (Used)      | Status/D%           | Ref M1     | M1 Old     | M1 New     |");
    Print("|        |                 |                       |                     |            |            |            |");
    Print("|  ----- | --------------- | --------------------- | ------------------- | ---------- | ---------- | ---------- |");
    for(int i = 0; i < g_historyCount; i++)
    {
        string entry = GetHistoryEntry(i);
    string parts[];
    int partCount = StringSplit(entry, '|', parts);
    if(partCount >= 6)
        {
        string time = parts[0];
    string price30min = parts[1];
    string refPrice = parts[2];
    string status = parts[3];
    string m1Old = parts[4];
    string m1New = parts[5];
    StringReplace(m1Old, "M1:", "");
    StringReplace(m1New, "M1:", "");
    string refM1 = m1Old;
    if(i == 0)
            {
                refM1 = "-";
            }
    string line = StringFormat("|  %s | %15s | %21s | %19s | %10s | %10s | %10s |",
                                      time,
                                      price30min,
                                      refPrice,
                                      status,
                                      refM1,
                                      m1Old,
                                      m1New);
    Print(line);
        }
    }
    Print("+---------------------------------------------------------------------------------------------------------------------+");
    }
    #else
#define PrintBasePriceHistory()
#endif
    #ifdef ENABLE_DEBUG_LOGS
void SaveBasePriceHistoryToFile()
{
        if(g_historyCount == 0) return;
    MqlDateTime dt;
    TimeToStruct(TimeGMT(), dt);
    string symbol = Symbol();
    StringReplace(symbol, "/", "");
    StringReplace(symbol, "\\", "");
    StringReplace(symbol, ":", "");
    string filename = StringFormat("base_price_history_log_%s_%d_%03d.txt", symbol, dt.year, dt.day_of_year + 1);
    int fileHandle = FileOpen(filename, FILE_WRITE | FILE_TXT | FILE_ANSI);
    if(fileHandle == INVALID_HANDLE)
    {
        Print("[BasePriceManager] SaveHistoryToFile: ERROR - Failed to create log file");
    return;
    }
    FileWriteString(fileHandle, "+---------------------------------------------------------------------------------------------------------------------+\n");
    FileWriteString(fileHandle, StringFormat("|  BASE PRICE HISTORY TODAY - %s (Day %d of %d) - %d entries                                          |\n", 
                                             TimeToString(TimeGMT(), TIME_DATE), dt.day_of_year + 1, dt.year, g_historyCount));
    FileWriteString(fileHandle, "+---------------------------------------------------------------------------------------------------------------------+\n");
    FileWriteString(fileHandle, "|  Time  | 30-Min Price    | Ref Price (Used)      | Status/D%           | Ref M1     | M1 Old     | M1 New     |\n");
    FileWriteString(fileHandle, "|        |                 |                       |                     |            |            |            |\n");
    FileWriteString(fileHandle, "|  ----- | --------------- | --------------------- | ------------------- | ---------- | ---------- | ---------- |\n");
    for(int i = 0; i < g_historyCount; i++)
    {
        string entry = GetHistoryEntry(i);
    string parts[];
    int partCount = StringSplit(entry, '|', parts);
    if(partCount >= 6)
        {
        string time = parts[0];
    string price30min = parts[1];
    string refPrice = parts[2];
    string status = parts[3];
    string m1Old = parts[4];
    string m1New = parts[5];
    StringReplace(m1Old, "M1:", "");
    StringReplace(m1New, "M1:", "");
    string refM1 = m1Old;
    if(i == 0)
            {
                refM1 = "-";            }
    string line = StringFormat("|  %s | %15s | %21s | %19s | %10s | %10s | %10s |\n",
                                      time,
                                      price30min,
                                      refPrice,
                                      status,
                                      refM1,
                                      m1Old,
                                      m1New);
    FileWriteString(fileHandle, line);
        }
    }
    FileWriteString(fileHandle, "+---------------------------------------------------------------------------------------------------------------------+\n");
    FileWriteString(fileHandle, "\n");
    FileWriteString(fileHandle, "=== CURRENT STATE ===\n");
    FileWriteString(fileHandle, StringFormat("Current Base Price: %s\n", DoubleToString(g_basePriceCached, Digits)));
    FileWriteString(fileHandle, StringFormat("Current M1 Power: %s\n", DoubleToString(g_referenceM1Power, 5)));
    FileWriteString(fileHandle, StringFormat("Total Entries Today: %d\n", g_historyCount));
    FileWriteString(fileHandle, "\n");
    datetime gmtNow = TimeGMT();
    datetime serverNow = TimeCurrent();
    int timezoneOffsetSeconds = (int)(serverNow - gmtNow);
    int timezoneOffsetHours = timezoneOffsetSeconds / 3600;
    FileWriteString(fileHandle, "=== TIMEZONE INFORMATION ===\n");
    FileWriteString(fileHandle, StringFormat("Server Time: %s\n", TimeToString(serverNow, TIME_DATE|TIME_MINUTES)));
    FileWriteString(fileHandle, StringFormat("GMT Time: %s\n", TimeToString(gmtNow, TIME_DATE|TIME_MINUTES)));
    FileWriteString(fileHandle, StringFormat("Timezone Offset: GMT %s%d hours\n", (timezoneOffsetHours >= 0 ? "+" : ""), timezoneOffsetHours));
    FileWriteString(fileHandle, "\n");
    FileWriteString(fileHandle, "=== RECENT M30 BARS (Last 5 completed bars) ===\n");
    for(int i = 1; i <= 5; i++)
    {
        datetime barTime = iTime(_Symbol, PERIOD_M30, i);
    double barClose = iClose(_Symbol, PERIOD_M30, i);
    datetime barTimeGMT = ConvertServerToGMT(barTime);
    if(barTime > 0)
        {
            FileWriteString(fileHandle, StringFormat("Bar %d:\n", i));
    FileWriteString(fileHandle, StringFormat("  Server Time: %s\n", TimeToString(barTime, TIME_DATE|TIME_MINUTES)));
    FileWriteString(fileHandle, StringFormat("  GMT Time: %s\n", TimeToString(barTimeGMT, TIME_DATE|TIME_MINUTES)));
    FileWriteString(fileHandle, StringFormat("  Close: %s\n", DoubleToString(barClose, Digits)));
        }
    }
    
    FileClose(fileHandle);
    Print("[BasePriceManager] SaveHistoryToFile: Saved ", g_historyCount, " entries to ", filename);
    }
#elsevoid SaveBasePriceHistoryToFile()
{    return;
}
    #endif
    void CleanupBasePriceManager()
{
    DEBUG_PRINTF("[BasePriceManager] CleanupBasePriceManager() - Freeing ", IntegerToString(g_symbolStateCount) + " symbol states");
    for(int i = 0; i < g_symbolStateCount; i++)
    {
        if(ArraySize(g_symbolStates[i].basePriceHistory) > 0)
        {
            ArrayFree(g_symbolStates[i].basePriceHistory);
        }
    }
    if(g_symbolStateCount > 0)
    {
        ArrayFree(g_symbolStates);
    g_symbolStateCount = 0;
    }
    
    DEBUG_PRINT("[BasePriceManager] CleanupBasePriceManager() - Cleanup complete (memory leak fixed)");
}
