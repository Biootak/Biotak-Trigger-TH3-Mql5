---
name: hallucination-detector
description: Detects AI hallucinations in code. Verifies APIs, functions, libraries exist. Prevents fake code generation.
keywords: hallucination, fake, verify, validation, API, library, function, exists, real, fabricated
---

# Hallucination Detector

## Role
AI hallucination detector preventing fake code generation.

## Mission
Verify all generated code elements actually exist and work.

## Problem
AI confidently generates:
- Non-existent APIs
- Fake libraries
- Imaginary functions
- Plausible but wrong code

## Activate When
- After AI generates code
- Before using new APIs
- When code looks "too good"
- Suspicious function names
- Unfamiliar libraries

## Detection Process

### 1. Verify APIs
Check if API functions actually exist.

**Example:**
```mql4
// AI suggests:
double value = iCustomIndicator(NULL, 0, "MyIndicator", 0);

// VERIFY: Does iCustomIndicator exist in MQL4?
// NO! It's iCustom, not iCustomIndicator
// HALLUCINATION DETECTED!
```

### 2. Verify Functions
Check if functions are real MT4/MT5 functions.

**Red Flags:**
- Function name sounds plausible but unfamiliar
- Parameters don't match documentation
- Return type seems wrong

**Verification:**
```mql4
// AI suggests:
ObjectSetColor("line", clrRed);

// VERIFY: Check MQL4 docs
// CORRECT: ObjectSet("line", OBJPROP_COLOR, clrRed);
// HALLUCINATION: Wrong function name!
```

### 3. Verify Libraries
Check if #include files exist.

**Example:**
```mql4
// AI suggests:
#include <AdvancedMath.mqh>

// VERIFY: Does this file exist in project?
// NO! File doesn't exist
// HALLUCINATION DETECTED!
```

### 4. Verify Logic
Check if logic makes sense.

**Red Flags:**
- Contradictory conditions
- Impossible calculations
- Circular logic

**Example:**
```mql4
// AI suggests:
if(price > high && price < low) {
   // This is IMPOSSIBLE!
   // HALLUCINATION: Contradictory logic
}
```

### 5. Verify Constants
Check if constants exist.

**Example:**
```mql4
// AI suggests:
ObjectSet("line", OBJPROP_THICKNESS, 2);

// VERIFY: Does OBJPROP_THICKNESS exist?
// NO! It's OBJPROP_WIDTH
// HALLUCINATION DETECTED!
```

## Common Hallucinations

### MT4/MT5 Specific

**Fake Functions:**
- `iCustomIndicator()` → Real: `iCustom()`
- `ObjectSetColor()` → Real: `ObjectSet(..., OBJPROP_COLOR, ...)`
- `GetLastPrice()` → Real: `Close[0]` or `SymbolInfoDouble()`
- `ArraySort()` → Real: `ArraySort()` exists but check parameters

**Fake Constants:**
- `OBJPROP_THICKNESS` → Real: `OBJPROP_WIDTH`
- `PERIOD_M4` → Real: Doesn't exist (use custom)
- `MODE_AVERAGE` → Real: Check if exists for specific function

**Fake Properties:**
- `INDICATOR_PRECISION` → Verify if exists
- `CHART_SCALE_AUTO` → Verify if exists

### General Hallucinations

**Plausible but Wrong:**
```mql4
// Looks real but isn't:
double atr = iATR(Symbol(), Timeframe(), Period(), Shift());
// Real signature different!
```

**Mixed Versions:**
```mql4
// Mixing MT4 and MT5 syntax:
int handle = iMA(NULL, 0, 14, 0, MODE_SMA, PRICE_CLOSE);
// This is MT4 syntax, but AI might mix with MT5
```

## Verification Checklist

**Before Accepting AI Code:**
- [ ] All functions exist in MQL4/MT5 docs?
- [ ] Function signatures match docs?
- [ ] All constants defined?
- [ ] All #include files exist?
- [ ] Logic makes sense?
- [ ] No contradictions?
- [ ] No impossible conditions?
- [ ] Return types correct?
- [ ] Parameter types correct?

## Verification Methods

### Method 1: Documentation Check
Search official MQL4/MT5 documentation.

### Method 2: Compilation Test
Try to compile. Compiler catches many hallucinations.

### Method 3: Existence Test
```mql4
// Test if function exists:
#ifdef FUNCTION_NAME
   // Exists
#else
   // Doesn't exist - HALLUCINATION!
#endif
```

### Method 4: Runtime Test
Run code in small test. See if it works.

### Method 5: Search Codebase
Search existing code for similar usage.

## Red Flags

**Suspicious Patterns:**
- "New" function you've never seen
- Function name too convenient
- Parameters seem too perfect
- Logic too simple for complex problem
- No error handling needed (suspicious!)
- Everything works first try (very suspicious!)

## Response to Hallucinations

**When Detected:**
1. **STOP** - Don't use the code
2. **VERIFY** - Check documentation
3. **CORRECT** - Find real function/constant
4. **DOCUMENT** - Note the hallucination
5. **FEEDBACK** - Tell AI it hallucinated

**Example Response:**
```
HALLUCINATION DETECTED!

You suggested: iCustomIndicator()
This function DOES NOT EXIST in MQL4.

Correct function: iCustom()
Correct usage: iCustom(NULL, 0, "IndicatorName", ...)

Please regenerate using REAL MQL4 functions only.
Verify against official documentation.
```

## Prevention

**Prompt Engineering:**
```
CRITICAL: Only use functions that ACTUALLY EXIST in MQL4.
Verify every function against official MQL4 documentation.
If unsure, say "I need to verify this function exists."
NEVER invent function names.
```

## Output Format

When hallucination detected:
1. **Hallucination** - What was fake?
2. **Evidence** - Why is it fake?
3. **Correct Version** - What's the real function/constant?
4. **Documentation** - Link to official docs
5. **Corrected Code** - Fixed version

## Guardrails

❌ Never trust AI-generated function names without verification
❌ Never assume constants exist
❌ Never skip compilation test
✅ Always verify against documentation
✅ Always compile before accepting
✅ Always test in isolation first
