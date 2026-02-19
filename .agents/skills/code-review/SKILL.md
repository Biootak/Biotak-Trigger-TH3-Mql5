---
name: code-review
description: Comprehensive code review. Checks quality, security, performance, maintainability. Use before merging or after AI-generated code.
keywords: review, audit, quality, security, standards, best practices, code smell, maintainability
---

# Code Review

## Role
Senior code reviewer ensuring production-ready quality.

## Mission
Review code for quality, security, performance, maintainability.

## Activate When
- Before merging code
- After AI-generated code
- Before production deployment
- Periodic code audits
- After major changes

## Review Checklist

### 1. Correctness
- [ ] Logic correct?
- [ ] Edge cases handled?
- [ ] Calculations accurate?
- [ ] No off-by-one errors?
- [ ] Array bounds checked?

**Example:**
```mql4
// BAD
double value = bars[i];

// GOOD
if(i >= 0 && i < ArraySize(bars)) {
   double value = bars[i];
}
```

### 2. Security
- [ ] No buffer overflows?
- [ ] No division by zero?
- [ ] No integer overflow?
- [ ] Input validation?
- [ ] No SQL injection (if applicable)?

**Example:**
```mql4
// BAD
double result = a / b;

// GOOD
double result = (b != 0) ? a / b : 0;
```

### 3. Performance
- [ ] No redundant calculations?
- [ ] Expensive ops cached?
- [ ] OnCalculate < 50ms?
- [ ] Memory efficient?
- [ ] No memory leaks?

**Example:**
```mql4
// BAD: Recalculates every tick
double atr = iATR(NULL, 0, 14, 0);

// GOOD: Cached
static double cached_atr = 0;
static datetime last = 0;
if(Time[0] != last) {
   cached_atr = iATR(NULL, 0, 14, 0);
   last = Time[0];
}
```

### 4. Maintainability
- [ ] Code readable?
- [ ] Functions < 50 lines?
- [ ] Clear naming?
- [ ] No magic numbers?
- [ ] Comments explain WHY?
- [ ] No code duplication?

**Example:**
```mql4
// BAD
if(x > 100) { ... }

// GOOD
const int MAX_OBJECTS = 100;
if(object_count > MAX_OBJECTS) { ... }
```

### 5. Architecture
- [ ] Proper module layer?
- [ ] Low coupling?
- [ ] High cohesion?
- [ ] No circular dependencies?
- [ ] Follows DRY principle?

### 6. Error Handling
- [ ] Errors handled gracefully?
- [ ] No silent failures?
- [ ] Meaningful error messages?
- [ ] Cleanup on error?

**Example:**
```mql4
// BAD
ObjectCreate(name, ...);

// GOOD
if(!ObjectCreate(name, ...)) {
   Print("ERROR: Failed to create object ", name);
   return false;
}
```

### 7. Testing
- [ ] Edge cases tested?
- [ ] Zero bars tested?
- [ ] Multiple instances tested?
- [ ] Timeframe changes tested?
- [ ] Memory leak tested?

### 8. Documentation
- [ ] WHY documented?
- [ ] Complex logic explained?
- [ ] Edge cases documented?
- [ ] Dependencies documented?

## Code Smells

### Smell 1: Long Function
**Problem:** Function > 50 lines
**Fix:** Break into smaller functions

### Smell 2: Magic Numbers
**Problem:** Hardcoded numbers
**Fix:** Use named constants

### Smell 3: Duplicate Code
**Problem:** Same logic repeated
**Fix:** Extract to utility function

### Smell 4: Deep Nesting
**Problem:** > 3 levels of nesting
**Fix:** Use early returns

**Example:**
```mql4
// BAD: Deep nesting
if(condition1) {
   if(condition2) {
      if(condition3) {
         // logic
      }
   }
}

// GOOD: Early returns
if(!condition1) return;
if(!condition2) return;
if(!condition3) return;
// logic
```

### Smell 5: God Object
**Problem:** Class/module does too much
**Fix:** Split responsibilities

### Smell 6: Tight Coupling
**Problem:** Modules depend on each other
**Fix:** Use manager pattern

## Review Severity Levels

### Critical (Must Fix)
- Security vulnerabilities
- Memory leaks
- Crashes
- Data corruption
- Logic errors

### High (Should Fix)
- Performance issues
- Poor error handling
- Tight coupling
- Code duplication

### Medium (Consider Fixing)
- Code smells
- Poor naming
- Missing comments
- Long functions

### Low (Nice to Have)
- Style inconsistencies
- Minor optimizations
- Better naming

## Output Format

Provide:
1. **Overall Assessment** - Pass/Fail with summary
2. **Critical Issues** - Must fix before merge
3. **High Priority Issues** - Should fix soon
4. **Medium Priority Issues** - Consider fixing
5. **Low Priority Issues** - Nice to have
6. **Positive Observations** - What's done well
7. **Recommendations** - Specific improvements

**Example:**
```
Overall: FAIL - 2 critical issues found

Critical Issues:
1. Memory leak in OnDeinit - objects not deleted
2. Division by zero in CalculateTH (line 45)

High Priority:
1. OnCalculate takes 150ms (should be < 50ms)
2. No error handling in ObjectCreate calls

Medium Priority:
1. Magic number 100 should be named constant
2. Function CalculateLevels is 85 lines (too long)

Positive:
1. Good use of caching for ATR calculations
2. Clear module separation

Recommendations:
1. Add explicit cleanup in OnDeinit
2. Add zero-check before division
3. Optimize OnCalculate loop
4. Extract constants
5. Break long functions
```

## Guardrails

❌ Never approve code with critical issues
❌ Never skip security checks
❌ Never ignore memory leaks
✅ Always check edge cases
✅ Always verify error handling
✅ Always ensure maintainability
