string GetFractalTimeframeForCurrent() {
        string currentTimeframe=GetCurrentTimeframe();
    
    // Minute timeframes
    if(currentTimeframe=="M1" || currentTimeframe=="M2" || currentTimeframe=="M3") return "M1";
    if(currentTimeframe=="M4" || currentTimeframe=="M5" || currentTimeframe=="M6") return "M4";
    if(currentTimeframe=="M10" || currentTimeframe=="M12" || currentTimeframe=="M15" || 
       currentTimeframe=="M20" || currentTimeframe=="M30") return "M16";
       
    // Hour timeframes
    if(currentTimeframe=="H1" || currentTimeframe=="H2") return "H1+M4";
    if(currentTimeframe=="H3" || currentTimeframe=="H4" || currentTimeframe=="H6" || currentTimeframe=="H8") return "H4+M16";
    if(currentTimeframe=="H12" || currentTimeframe=="D1") return "H17+M4";
    
    // Higher timeframes
    if(currentTimeframe=="W1") return "D11+H9+M4";
    if(currentTimeframe=="MN1") return "D45+H12+M16";
    return "UNKNOWN";
}
    string GetStructureTimeframeForCurrent() {
    // OPTIMIZATION: Cache GetFractalTimeframeForCurrent() result before loop
    string currentFractalTF = GetFractalTimeframeForCurrent();
    int currentIndex = -1;
    int arraySize = ArraySize(FRACTAL_TIMEFRAMES);
    for(int i = 0; i < arraySize; i++) {
        if(FRACTAL_TIMEFRAMES[i] == currentFractalTF) {
            currentIndex = i;
    break;
        }
    }
    if(currentIndex != -1 && currentIndex + 2 < arraySize) {
        return FRACTAL_TIMEFRAMES[currentIndex + 2];
    }
    return "UNKNOWN";
}
    string GetCorrespondingFractalTimeframe(const string standardTimeframe) {
        if(standardTimeframe=="D1") return "H17+M4";
    if(standardTimeframe=="W1") return "D11+H9+M4";
    if(standardTimeframe=="MN1") return "D45+H12+M16";
    return "";
}
    double GetLowerTimeframeTH(const string currentTimeframe, int offset) {
        if(StringLen(currentTimeframe) == 0) {
        DEBUG_PRINT("GetLowerTimeframeTH - Error: Empty timeframe string");
    return EMPTY_VALUE;
    }
    if(offset < 0) {
        DEBUG_PRINTF("GetLowerTimeframeTH - Error: Invalid offset value: ", offset);
    return EMPTY_VALUE;
    }
    int arraySize = ArraySize(FRACTAL_TIMEFRAMES);
    int percentageArraySize = ArraySize(MODIFIED_FRACTAL_PERCENTAGES);
    if(arraySize <= 0 || percentageArraySize <= 0) {
        DEBUG_PRINTF2("GetLowerTimeframeTH - Error: Empty arrays - FRACTAL_TIMEFRAMES: ", IntegerToString(arraySize),
              ", MODIFIED_FRACTAL_PERCENTAGES: " + IntegerToString(percentageArraySize));
    return EMPTY_VALUE;
    }
    if(arraySize != percentageArraySize) {
        DEBUG_PRINTF2("GetLowerTimeframeTH - Error: Array size mismatch - FRACTAL_TIMEFRAMES: ", IntegerToString(arraySize),
              ", MODIFIED_FRACTAL_PERCENTAGES: " + IntegerToString(percentageArraySize));
    return EMPTY_VALUE;
    }
    // Debug: Print("GetLowerTimeframeTH - Looking for timeframe: ", currentTimeframe, " with offset: ", offset);
    int matchIndex = -1;
    for(int i=0; i<arraySize; i++) {
        if(FRACTAL_TIMEFRAMES[i] == currentTimeframe) {
            matchIndex = i;
    break;
        }
    }
    if(matchIndex == -1) {
        DEBUG_PRINTF("GetLowerTimeframeTH - Error: No matching timeframe found for: ", currentTimeframe);
    return EMPTY_VALUE;
    }
    int targetIndex = matchIndex - offset;
    if(targetIndex < 0 || targetIndex >= arraySize) {
        DEBUG_PRINTF3("GetLowerTimeframeTH - Error: Invalid target index. Index: ", IntegerToString(targetIndex),
              ", TF: " + currentTimeframe, ", Offset: " + IntegerToString(offset));
    return EMPTY_VALUE;
    }
    double result = MODIFIED_FRACTAL_PERCENTAGES[targetIndex];
    if(result <= 0.0) {
        DEBUG_PRINTF("GetLowerTimeframeTH - Warning: Zero or negative percentage at index ", targetIndex);
    }
    // Debug: Print("GetLowerTimeframeTH - Found at index ", matchIndex, " returning value: ", result);
    return result;
}
    double GetPatternTH() {
        string currentTF = GetFractalTimeframeForCurrent();
    return GetLowerTimeframeTH(currentTF, 1);
}
    double GetTriggerTH() {
        string currentTF = GetFractalTimeframeForCurrent();
    return GetLowerTimeframeTH(currentTF, 2);
}

// Get percentage for a specific timeframe (matching MotiveWave implementation)
double GetTimeframePercentage(const string timeframe) {
        int arraySize = ArraySize(FRACTAL_TIMEFRAMES);
    for(int i = 0; i < arraySize; i++) {
        if(FRACTAL_TIMEFRAMES[i] == timeframe) {
        return MODIFIED_FRACTAL_PERCENTAGES[i];
        }
    }
    // Default fallback
    return 1.0;
}

// Convert long timeframe name to short format
// e.g., "H1+M4" -> "H1.4", "D2+H20+M16" -> "D2.20.16"
string GetShortTimeframeName(const string longTimeframeName) {
    // Simple timeframes - return as is
    if (longTimeframeName == "M1" || longTimeframeName == "M4" || longTimeframeName == "M16") {
        return longTimeframeName;
    }
    
    // Composite timeframes - convert to short format
    if (longTimeframeName == "H1+M4") return "H1.4";
    if (longTimeframeName == "H4+M16") return "H4.16";
    if (longTimeframeName == "H17+M4") return "H17.4";
    if (longTimeframeName == "D2+H20+M16") return "D2.20.16";
    if (longTimeframeName == "D11+H9+M4") return "D11.9.4";
    if (longTimeframeName == "D45+H12+M16") return "D45.12.16";
    
    // No match found - return original
    return longTimeframeName;
}

// Get timeframe name for a structure level (L1-L5)
// L1 = current fractal TF, L2 = one higher, etc.
string GetTimeframeForStructureLevel(int level) {
        if(level < 1 || level > 5) return "";
    string currentTF = GetFractalTimeframeForCurrent();
    int arraySize = ArraySize(FRACTAL_TIMEFRAMES);
    
    // Validate array is not empty
    if(arraySize <= 0) return currentTF;
    
    // Find current TF index
    int currentIndex = -1;
    for(int i = 0; i < arraySize; i++) {
        if(FRACTAL_TIMEFRAMES[i] == currentTF) {
            currentIndex = i;
    break;
        }
    }
    if(currentIndex < 0) return currentTF;
    
    // L1 = current TF, L2 = current + 1, etc.
    int targetIndex = currentIndex + (level - 1);
    
    // Clamp to valid range [0, arraySize-1]
    if(targetIndex < 0) targetIndex = 0;
    if(targetIndex >= arraySize) targetIndex = arraySize - 1;
    return FRACTAL_TIMEFRAMES[targetIndex];
}

// Helper function to build overlap info string for a step
// Returns string like "L2" for highest level only (FIXED: No more overlaps)
// Now uses GetHighestStructureLevel for proper hierarchy
string GetOverlapLevelsInfo(int step, const int &intervals[]) {
    // SECURITY: Validate inputs
    if(step == 0) return "Mid"; // Midpoint
    
    int arraySize = ArraySize(intervals);
    if(arraySize != 5) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ GetOverlapLevelsInfo: Invalid intervals array size=", arraySize);
    #endif
    return "";
    }
    
    // Get highest structure level (1-5) or 0 if trigger
    int highestLevel = GetHighestStructureLevel(step, intervals);
    if(highestLevel == 0) {
        return ""; // Trigger level - no structure info
    }
    
    // Return only the highest level (e.g., "L2" not "L1+L2")
    return "L" + IntegerToString(highestLevel);
}

// Helper function to build timeframe info for overlapping levels
// Now returns only the highest level's timeframe
string GetOverlapTimeframesInfo(int step, const int &intervals[]) {
    // SECURITY: Validate inputs
    if(step == 0) return GetShortTimeframeName(GetFractalTimeframeForCurrent()); // Midpoint
    
    int arraySize = ArraySize(intervals);
    if(arraySize != 5) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ GetOverlapTimeframesInfo: Invalid intervals array size=", arraySize);
    #endif
    return "";
    }
    
    // Get highest structure level (1-5) or 0 if trigger
    int highestLevel = GetHighestStructureLevel(step, intervals);
    if(highestLevel == 0) {
        // Trigger level - return current timeframe
        return GetShortTimeframeName(GetFractalTimeframeForCurrent());
    }
    
    // Return timeframe for the highest level only
    string tf = GetShortTimeframeName(GetTimeframeForStructureLevel(highestLevel));
    return tf;
}

// Fractal timeframe durations in minutes (powers of 4)
// M1=1, M4=4, M16=16, H1+M4=64, H4+M16=256, H17+M4=1024,
// D2+H20+M16=4096, D11+H9+M4=16384, D45+H12+M16=65536
const int FRACTAL_TIMEFRAME_MINUTES[] = {
    1, 4, 16, 64, 256, 1024, 4096, 16384, 65536
};

// Get minutes for a fractal timeframe name
int GetFractalTimeframeMinutes(const string timeframe) {
    int arraySize = ArraySize(FRACTAL_TIMEFRAMES);
    int minutesArraySize = ArraySize(FRACTAL_TIMEFRAME_MINUTES);
    for(int i = 0; i < arraySize && i < minutesArraySize; i++) {
        if(FRACTAL_TIMEFRAMES[i] == timeframe) {
            return FRACTAL_TIMEFRAME_MINUTES[i];
        }
    }
    // Fallback: use chart period minutes
    return GetCurrentTimeframeMinutes();
}

// Get structure timeframe minutes for current chart
int GetStructureTimeframeMinutes() {
    string structTF = GetStructureTimeframeForCurrent();
    return GetFractalTimeframeMinutes(structTF);
}
