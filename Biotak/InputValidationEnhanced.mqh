//+------------------------------------------------------------------+
//|                                   InputValidationEnhanced.mqh     |
//|                                  GOLD FIX: Input Security Layer   |
//|                                  Filename Sanitization            |
//+------------------------------------------------------------------+
#property copyright "© Biotak - Security Enhanced"

//+------------------------------------------------------------------+
//| Sanitize filename for safe file operations                       |
//+------------------------------------------------------------------+
string SanitizeFilename(const string filename) {
    string safe = filename;
    
    // Remove path traversal
    StringReplace(safe, "..", "");
    StringReplace(safe, "/", "_");
    StringReplace(safe, "\\", "_");
    
    // Remove dangerous characters
    StringReplace(safe, ":", "");
    StringReplace(safe, "*", "");
    StringReplace(safe, "?", "");
    StringReplace(safe, "\"", "");
    StringReplace(safe, "<", "");
    StringReplace(safe, ">", "");
    StringReplace(safe, "|", "");
    StringReplace(safe, "\0", "");
    StringReplace(safe, "\n", "");
    StringReplace(safe, "\r", "");
    
    // Ensure not empty
    if(StringLen(safe) == 0) {
        safe = "default";
    }
    
    // ✅ SECURITY FIX: Limit length to prevent buffer overflow
    // Reserve space for path (BiotakReports\\ + Pattern_ + timestamp)
    #ifdef MAX_PATTERN_NAME_LENGTH
    if(StringLen(safe) > MAX_PATTERN_NAME_LENGTH) {
        safe = StringSubstr(safe, 0, MAX_PATTERN_NAME_LENGTH);
    }
    #else
    // Fallback: use 100 chars if constant not defined
    if(StringLen(safe) > 100) {
        safe = StringSubstr(safe, 0, 100);
    }
    #endif
    
    return safe;
}
