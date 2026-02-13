#define HISTORY_DIR ".biotak\\history\\"
#define HISTORY_FILE_PREFIX "base_price_history_"
#define HISTORY_FILE_EXT ".txt"
#define HISTORY_VERSION_FILE ".biotak\\history\\.version"
#define DEFAULT_DAYS_TO_KEEP 30
#define MAX_FILE_SIZE_KB 1024
#ifdef ENABLE_DEBUG_LOGS
#define HISTORY_PRINT Print
#else
#define HISTORY_PRINT if(0) Print
#endif
    string SanitizeSymbolForFilename(const string symbol) {
        string safe = symbol;
    StringReplace(safe, "..", "");
    StringReplace(safe, "/", "");
    StringReplace(safe, "\\", "");
    StringReplace(safe, ":", "");
    StringReplace(safe, "\0", "");
    StringReplace(safe, "\n", "");
    StringReplace(safe, "\r", "");
    StringReplace(safe, "\t", "");
    StringReplace(safe, "|", "");
    StringReplace(safe, "<", "");
    StringReplace(safe, ">", "");
    StringReplace(safe, "\"", "");
    StringReplace(safe, "*", "");
    StringReplace(safe, "?", "");
    if(StringLen(safe) == 0) {
        safe = "UNKNOWN";
    }
    return safe;
}
    string GetHistoryFilePath(int year, int dayOfYear)
{
        string symbol = SanitizeSymbolForFilename(Symbol());
    string filename = StringFormat("%s%s_%d_%03d%s", 
                                    HISTORY_FILE_PREFIX,
                                    symbol,
                                    year, 
                                    dayOfYear, 
                                    HISTORY_FILE_EXT);
    string fullPath = HISTORY_DIR + filename;
    return fullPath;
}
    int LoadBasePriceHistory(int year, int dayOfYear, string &history[])
{
        string filePath = GetHistoryFilePath(year, dayOfYear);
    int maxRetries = 3;
    int retryDelay = 100;
    int fileHandle = INVALID_HANDLE;
    bool fileOpened = false;
    for(int attempt = 0; attempt < maxRetries; attempt++)
    {        fileHandle = FileOpen(filePath, FILE_READ | FILE_TXT | FILE_ANSI);
    fileOpened = (fileHandle != INVALID_HANDLE);
    if(!fileOpened)
        {
        int errorCode = GetLastError();
    if(errorCode == 4103 || errorCode == 5019)            {
        if(attempt == 0)
                {
                    HISTORY_PRINT("[BasePriceHistoryManager] LoadHistory: No history file found for ", year, "/", dayOfYear);
                }
                ArrayResize(history, 0);
    return 0;
            }
    if(attempt < maxRetries - 1)
            {
                HISTORY_PRINT("[BasePriceHistoryManager] LoadHistory: File locked (error ", errorCode, "), retrying...");
    continue;
            }
            else
            {
                HISTORY_PRINT("[BasePriceHistoryManager] LoadHistory: ERROR - Failed to open file after ", maxRetries, " attempts");
    ArrayResize(history, 0);
    return 0;
            }
        }
    int count = 0;
    ArrayResize(history, 0);
    int emptyLines = 0;
    int invalidLines = 0;
    while(!FileIsEnding(fileHandle))
        {
        string line = FileReadString(fileHandle);
    StringTrimLeft(line);
    StringTrimRight(line);
    if(StringLen(line) == 0)
            {
                emptyLines++;
    continue;
            }
    if(StringFind(line, "|") == -1)
            {
                invalidLines++;
    HISTORY_PRINT("[BasePriceHistoryManager] LoadHistory: WARNING - Invalid line format: ", line);
    continue;
            }
            
            ArrayResize(history, count + 1, 64);
    history[count] = line;
    count++;
        }
    if(fileHandle != INVALID_HANDLE) {
            FileClose(fileHandle);
    fileHandle = INVALID_HANDLE;
        }
    if(attempt > 0)
        {
            HISTORY_PRINT("[BasePriceHistoryManager] LoadHistory: Success after ", attempt + 1, " attempts");
        }
        
        HISTORY_PRINT("[BasePriceHistoryManager] LoadHistory: Loaded ", count, " valid entries from ", filePath);
    if(emptyLines > 0 || invalidLines > 0)
        {
            HISTORY_PRINT("[BasePriceHistoryManager] LoadHistory: Skipped ", emptyLines, " empty lines and ", invalidLines, " invalid lines");
        }
    return count;
    }
    if(fileHandle != INVALID_HANDLE) {
        FileClose(fileHandle);
    }
    
    ArrayResize(history, 0);
    return 0;
}
    bool SaveBasePriceHistory(int year, int dayOfYear, const string &history[], int count)
{
        string filePath = GetHistoryFilePath(year, dayOfYear);
    string tempPath = filePath + ".tmp";
    int maxRetries = 3;
    int retryDelay = 100;
    for(int attempt = 0; attempt < maxRetries; attempt++)
    {
        int fileHandle = FileOpen(tempPath, FILE_WRITE | FILE_TXT | FILE_ANSI);
    if(fileHandle == INVALID_HANDLE)
        {
        int errorCode = GetLastError();
    if(attempt < maxRetries - 1)
            {
                HISTORY_PRINT("[BasePriceHistoryManager] SaveHistory: Temp file locked (error ", errorCode, "), retrying...");
    continue;
            }
            else
            {
                HISTORY_PRINT("[BasePriceHistoryManager] SaveHistory: ERROR - Failed to create temp file after ", maxRetries, " attempts");
    return false;
            }
        }
    bool writeSuccess = true;
    for(int i = 0; i < count; i++)
        {            if(!FileWriteString(fileHandle, history[i] + "\n"))
            {
        int writeError = GetLastError();
    HISTORY_PRINT("[BasePriceHistoryManager] SaveHistory: ERROR - Write failed at entry ", i, ", error=", writeError);
    writeSuccess = false;
    break;
            }
        }
        
        FileClose(fileHandle);
    if(!writeSuccess)
        {
            FileDelete(tempPath);
    if(attempt < maxRetries - 1)
            {
                HISTORY_PRINT("[BasePriceHistoryManager] SaveHistory: Write failed, retrying...");
    continue;
            }
            else
            {
                HISTORY_PRINT("[BasePriceHistoryManager] SaveHistory: ERROR - Write failed after ", maxRetries, " attempts");
    return false;
            }
        }
    if(FileIsExist(filePath))
        {
            if(!FileDelete(filePath))
            {
        int deleteError = GetLastError();
    if(attempt < maxRetries - 1)
                {
                    HISTORY_PRINT("[BasePriceHistoryManager] SaveHistory: Failed to delete old file (error ", deleteError, "), retrying...");
    FileDelete(tempPath);
    continue;
                }
                else
                {
                    HISTORY_PRINT("[BasePriceHistoryManager] SaveHistory: WARNING - Could not delete old file, keeping temp file");                }
            }
        }
    if(!FileMove(tempPath, 0, filePath, FILE_REWRITE))
        {
        int moveError = GetLastError();
    if(attempt < maxRetries - 1)
            {
                HISTORY_PRINT("[BasePriceHistoryManager] SaveHistory: Failed to rename temp file (error ", moveError, "), retrying...");
    continue;
            }
            else
            {
                HISTORY_PRINT("[BasePriceHistoryManager] SaveHistory: ERROR - Failed to rename temp file after ", maxRetries, " attempts");
    return false;
            }
        }
    if(attempt > 0)
        {
            HISTORY_PRINT("[BasePriceHistoryManager] SaveHistory: Success after ", attempt + 1, " attempts");
        }
        
        HISTORY_PRINT("[BasePriceHistoryManager] SaveHistory: Saved ", count, " history entries to ", filePath);
    return true;
    }
    return false;
}
    bool AppendBasePriceHistoryEntry(int year, int dayOfYear, const string entry)
{
        string filePath = GetHistoryFilePath(year, dayOfYear);
    int maxRetries = 3;
    int retryDelay = 100;
    for(int attempt = 0; attempt < maxRetries; attempt++)
    {
        int fileHandle = FileOpen(filePath, FILE_WRITE | FILE_READ | FILE_TXT | FILE_ANSI);
    if(fileHandle != INVALID_HANDLE)
        {            FileSeek(fileHandle, 0, SEEK_END);
    FileWriteString(fileHandle, entry + "\n");
    FileClose(fileHandle);
    if(attempt > 0)
            {
                HISTORY_PRINT("[BasePriceHistoryManager] AppendEntry: Success after ", attempt + 1, " attempts");
            }
    return true;
        }
    int errorCode = GetLastError();
    if(attempt < maxRetries - 1)
        {
            HISTORY_PRINT("[BasePriceHistoryManager] AppendEntry: File locked (error ", errorCode, "), retrying in ", retryDelay, "ms...");        }
        else
        {
            HISTORY_PRINT("[BasePriceHistoryManager] AppendEntry: ERROR - Failed after ", maxRetries, " attempts. Error: ", errorCode);
        }
    }
    return false;
}
    int DeduplicateHistory(string &history[], int count)
{
        if(count <= 1) return count;
    string uniqueTimeBlocks[];
    string uniqueEntries[];
    int uniqueCount = 0;
    // PERF: Pre-allocate to count (worst case = no duplicates) instead of grow-by-1
    ArrayResize(uniqueTimeBlocks, count);
    ArrayResize(uniqueEntries, count);
    for(int i = 0; i < count; i++)
    {
        int pipePos = StringFind(history[i], "|");
    if(pipePos == -1) continue;
    string timeBlock = StringSubstr(history[i], 0, pipePos);
    bool found = false;
    int foundIndex = -1;
    // PERF: Reverse search — duplicates are typically adjacent/near-end
    for(int j = uniqueCount - 1; j >= 0; j--)
        {
        if(uniqueTimeBlocks[j] == timeBlock)
            {
                found = true;
    foundIndex = j;
    break;
            }
        }
    if(found)
        {            uniqueEntries[foundIndex] = history[i];
        }
        else
        {            uniqueTimeBlocks[uniqueCount] = timeBlock;
    uniqueEntries[uniqueCount] = history[i];
    uniqueCount++;
        }
    }
    int duplicatesRemoved = count - uniqueCount;
    if(duplicatesRemoved > 0)
    {
        HISTORY_PRINT("[BasePriceHistoryManager] DeduplicateHistory: WARNING - Removed ", duplicatesRemoved, " duplicate entries");
    }
    ArrayResize(history, uniqueCount);
    for(int i = 0; i < uniqueCount; i++)
    {
        history[i] = uniqueEntries[i];
    }
    return uniqueCount;
}
    bool VerifyHistoryFileIntegrity(int year, int dayOfYear)
{
        string filePath = GetHistoryFilePath(year, dayOfYear);
    if(!FileIsExist(filePath))
    {
        return true;    }
    int fileHandle = FileOpen(filePath, FILE_READ | FILE_BIN);
    if(fileHandle == INVALID_HANDLE)
    {
        HISTORY_PRINT("[BasePriceHistoryManager] VerifyIntegrity: Cannot open file for size check");
    return false;
    }
    int fileSize = (int)FileSize(fileHandle);
    FileClose(fileHandle);
    if(fileSize > MAX_FILE_SIZE_KB * 1024)
    {
        HISTORY_PRINT("[BasePriceHistoryManager] VerifyIntegrity: WARNING - File too large (", fileSize, " bytes), possible corruption");
    return false;
    }
    if(fileSize == 0)
    {
        HISTORY_PRINT("[BasePriceHistoryManager] VerifyIntegrity: WARNING - File is empty");
    return false;
    }
    return true;
}
    int RepairHistoryFile(int year, int dayOfYear)
{
    HISTORY_PRINT("[BasePriceHistoryManager] RepairHistoryFile: Attempting to repair file for ", year, "/", dayOfYear);
    string filePath = GetHistoryFilePath(year, dayOfYear);
    string backupPath = filePath + ".backup";
    if(FileIsExist(filePath))
    {
        if(FileIsExist(backupPath))
        {
            FileDelete(backupPath);
        }
        
        if(!FileMove(filePath, 0, backupPath, 0))
        {
            HISTORY_PRINT("[BasePriceHistoryManager] RepairHistoryFile: ERROR - Cannot create backup");
    return -1;
        }
    }
    string history[];
    int count = 0;
    int fileHandle = FileOpen(backupPath, FILE_READ | FILE_TXT | FILE_ANSI);
    if(fileHandle == INVALID_HANDLE)
    {
        HISTORY_PRINT("[BasePriceHistoryManager] RepairHistoryFile: ERROR - Cannot open backup file");
    return -1;
    }
    while(!FileIsEnding(fileHandle))
    {
        string line = FileReadString(fileHandle);
    StringTrimLeft(line);
    StringTrimRight(line);
    if(StringLen(line) > 0 && StringFind(line, "|") > 0)
        {
            ArrayResize(history, count + 1, 64);
    history[count] = line;
    count++;
        }
    }
    
    FileClose(fileHandle);
    if(count > 0)
    {
        bool saved = SaveBasePriceHistory(year, dayOfYear, history, count);
    if(saved)
        {
            HISTORY_PRINT("[BasePriceHistoryManager] RepairHistoryFile: Successfully recovered ", count, " entries");
    return count;
        }
    }
    
    HISTORY_PRINT("[BasePriceHistoryManager] RepairHistoryFile: ERROR - Could not recover any entries");
    return -1;
}
    int MigrateToNewFormat(string &history[], int count)
{
        int migratedCount = 0;
    for(int i = 0; i < count; i++)
    {
        int fieldCount = 1;
    for(int j = 0; j < StringLen(history[i]); j++)
        {
        if(StringGetCharacter(history[i], j) == '|')
            {
                fieldCount++;
            }
        }
    if(fieldCount >= 6)
        {
            continue;        }
    if(fieldCount == 5)
        {
        string parts[];
    int partCount = StringSplit(history[i], '|', parts);
    if(partCount >= 5)
            {
        string time = parts[0];
    string price = parts[1];
    string status = parts[2];
    string oldM1 = parts[3];
    string newM1 = parts[4];
    string newEntry = time + "|" + price + "|" + price + "|" + status + "|" + oldM1 + "|" + newM1;
    history[i] = newEntry;
    migratedCount++;
            }
        }
    }
    if(migratedCount > 0)
    {
        HISTORY_PRINT("[BasePriceHistoryManager] MigrateToNewFormat: Migrated ", migratedCount, " entries from old format to new format");
    }
    return migratedCount;
}
    datetime ConvertYearDayToDateTime(int year, int dayOfYear)
{    MqlDateTime dt;
    dt.year = year;
    dt.mon = 1;
    dt.day = 1;
    dt.hour = 0;
    dt.min = 0;
    dt.sec = 0;
    datetime jan1 = StructToTime(dt);
    datetime result = jan1 + ((dayOfYear - 1) * 24 * 60 * 60);
    return result;
}
    void CleanupOldHistory(int daysToKeep = DEFAULT_DAYS_TO_KEEP)
{
        datetime cutoffTime = TimeGMT() - (daysToKeep * 24 * 60 * 60);
    string currentSymbol = SanitizeSymbolForFilename(Symbol());
    string searchPattern = HISTORY_DIR + HISTORY_FILE_PREFIX + currentSymbol + "_*" + HISTORY_FILE_EXT;
    string filename;
    int deletedCount = 0;
    int skippedCount = 0;
    int errorCount = 0;
    HISTORY_PRINT("[BasePriceHistoryManager] CleanupOldHistory: Searching for files older than ", daysToKeep, " days...");
    HISTORY_PRINT("[BasePriceHistoryManager] CleanupOldHistory: Pattern: ", searchPattern);
    long searchHandle = FileFindFirst(searchPattern, filename);
    if(searchHandle == INVALID_HANDLE)
    {        HISTORY_PRINT("[BasePriceHistoryManager] CleanupOldHistory: No history files found for ", currentSymbol);
    return;
    }
    do
    {
        string fullPath = HISTORY_DIR + filename;
    int lastUnderscore = StringFind(filename, "_", StringLen(filename) - 8);
    int secondLastUnderscore = StringFind(filename, "_", lastUnderscore - 5);
    if(lastUnderscore > 0 && secondLastUnderscore > 0)
        {
        string yearStr = StringSubstr(filename, secondLastUnderscore + 1, lastUnderscore - secondLastUnderscore - 1);
    string dayStr = StringSubstr(filename, lastUnderscore + 1, 3);
    int fileYear = (int)StringToInteger(yearStr);
    int fileDay = (int)StringToInteger(dayStr);
    if(fileYear < 2020 || fileYear > 2100 || fileDay < 1 || fileDay > 366)
            {
                HISTORY_PRINT("[BasePriceHistoryManager] CleanupOldHistory: WARNING - Invalid date in filename: ", filename);
    errorCount++;
    continue;
            }
    datetime fileTime = ConvertYearDayToDateTime(fileYear, fileDay);
    if(fileTime < cutoffTime)
            {
                HISTORY_PRINT("[BasePriceHistoryManager] CleanupOldHistory: Deleting old file: ", filename, 
                      " (", TimeToString(fileTime, TIME_DATE), ")");
    bool deleted = false;
    for(int retry = 0; retry < 3; retry++)
                {
        if(FileDelete(fullPath))
                    {
                        deleted = true;
    deletedCount++;
    break;
                    }
                    else
                    {
        int errorCode = GetLastError();
    if(retry < 2)
                        {
                            HISTORY_PRINT("[BasePriceHistoryManager] CleanupOldHistory: Delete failed (error ", errorCode, "), retrying...");                        }
                        else
                        {
                            HISTORY_PRINT("[BasePriceHistoryManager] CleanupOldHistory: WARNING - Failed to delete: ", fullPath, " (error ", errorCode, ")");
    errorCount++;
                        }
                    }
                }
            }
            else
            {
                skippedCount++;
            }
        }
        else
        {
            HISTORY_PRINT("[BasePriceHistoryManager] CleanupOldHistory: WARNING - Could not parse filename: ", filename);
    errorCount++;
        }
    }
    while(FileFindNext(searchHandle, filename));
    FileFindClose(searchHandle);
    HISTORY_PRINT("[BasePriceHistoryManager] CleanupOldHistory: Complete - Deleted: ", deletedCount, 
          ", Kept: ", skippedCount, ", Errors: ", errorCount);
}
    void CleanupTemporaryFiles()
{
        string currentSymbol = SanitizeSymbolForFilename(Symbol());
    string searchPattern = HISTORY_DIR + HISTORY_FILE_PREFIX + currentSymbol + "_*.tmp";
    string filename;
    int deletedCount = 0;
    long searchHandle = FileFindFirst(searchPattern, filename);
    if(searchHandle != INVALID_HANDLE)
    {
        do
        {
        string fullPath = HISTORY_DIR + filename;
    if(FileDelete(fullPath))
            {
                deletedCount++;
    HISTORY_PRINT("[BasePriceHistoryManager] CleanupTemporaryFiles: Deleted temp file: ", filename);
            }
        }
        while(FileFindNext(searchHandle, filename));
    FileFindClose(searchHandle);
    }
    searchPattern = HISTORY_DIR + HISTORY_FILE_PREFIX + currentSymbol + "_*.backup";
    searchHandle = FileFindFirst(searchPattern, filename);
    if(searchHandle != INVALID_HANDLE)
    {
        do
        {
        string fullPath = HISTORY_DIR + filename;
    if(FileDelete(fullPath))
            {
                deletedCount++;
    HISTORY_PRINT("[BasePriceHistoryManager] CleanupTemporaryFiles: Deleted backup file: ", filename);
            }
        }
        while(FileFindNext(searchHandle, filename));
    FileFindClose(searchHandle);
    }
    if(deletedCount > 0)
    {
        HISTORY_PRINT("[BasePriceHistoryManager] CleanupTemporaryFiles: Cleaned up ", deletedCount, " temporary files");
    }
}
    bool CheckHistoryFormatVersion(int currentVersion)
{
        int fileHandle = FileOpen(HISTORY_VERSION_FILE, FILE_READ | FILE_TXT | FILE_ANSI);
    int storedVersion = 0;
    if(fileHandle != INVALID_HANDLE)
    {
        if(!FileIsEnding(fileHandle))
        {
        string versionStr = FileReadString(fileHandle);
    storedVersion = (int)StringToInteger(versionStr);
        }
        FileClose(fileHandle);
    }
    if(storedVersion != currentVersion)
    {
        HISTORY_PRINT("[BasePriceHistoryManager] History format version mismatch: stored=", storedVersion, ", current=", currentVersion);
    return false;
    }
    return true;
}
    void UpdateHistoryFormatVersion(int currentVersion)
{
        int fileHandle = FileOpen(HISTORY_VERSION_FILE, FILE_WRITE | FILE_TXT | FILE_ANSI);
    if(fileHandle != INVALID_HANDLE)
    {
        FileWriteString(fileHandle, IntegerToString(currentVersion));
    FileClose(fileHandle);
    HISTORY_PRINT("[BasePriceHistoryManager] Updated history format version to: ", currentVersion);
    }
    else
    {
        HISTORY_PRINT("[BasePriceHistoryManager] ERROR: Failed to write version file");
    }
}
    void DeleteAllHistoryFiles()
{
        string currentSymbol = SanitizeSymbolForFilename(Symbol());
    string searchPattern = HISTORY_DIR + HISTORY_FILE_PREFIX + currentSymbol + "_*" + HISTORY_FILE_EXT;
    string filename;
    int deletedCount = 0;
    HISTORY_PRINT("[BasePriceHistoryManager] Deleting all history files due to format version change...");
    long searchHandle = FileFindFirst(searchPattern, filename);
    if(searchHandle != INVALID_HANDLE)
    {
        do
        {
        string fullPath = HISTORY_DIR + filename;
    if(FileDelete(fullPath))
            {
                deletedCount++;
    HISTORY_PRINT("[BasePriceHistoryManager] Deleted: ", filename);
            }
        }
        while(FileFindNext(searchHandle, filename));
    FileFindClose(searchHandle);
    }
    
    HISTORY_PRINT("[BasePriceHistoryManager] Deleted ", deletedCount, " history files");
}
