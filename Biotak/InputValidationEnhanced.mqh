#ifndef INPUT_VALIDATION_ENHANCED_MQH
#define INPUT_VALIDATION_ENHANCED_MQH

string SanitizeFilename(const string filename) {
        string safe = filename;
    StringReplace(safe, "..", "");
    StringReplace(safe, "/", "_");   StringReplace(safe, "\\", "_");
    StringReplace(safe, ":", "");
    StringReplace(safe, "*", "");
    StringReplace(safe, "?", "");
    StringReplace(safe, "\"", "");
    StringReplace(safe, "<", "");
    StringReplace(safe, ">", "");
    StringReplace(safe, "|", "");
    StringReplace(safe, "\0", "");
    StringReplace(safe, "\n", "");   StringReplace(safe, "\r", "");
    if(StringLen(safe) == 0) safe = "default";
    #ifdef MAX_PATTERN_NAME_LENGTH
    if(StringLen(safe) > MAX_PATTERN_NAME_LENGTH) safe = StringSubstr(safe, 0, MAX_PATTERN_NAME_LENGTH);
    #else
    if(StringLen(safe) > 100) safe = StringSubstr(safe, 0, 100);
    #endif
    return safe;
}
    #endif
    // INPUT_VALIDATION_ENHANCED_MQH