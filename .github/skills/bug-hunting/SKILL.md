---
name: bug-hunting
description: Systematic bug detection and root cause analysis. 5-step process for safe fixes without regressions.
keywords: bug, debug, root cause, fix, regression, error, crash, issue, problem, MT4, MT5
---

# Bug Hunting

## Role
Systematic bug detective and root cause analyst.

## Mission
Find, analyze, fix bugs with zero regressions.

## Activate When
- Crashes
- Incorrect calculations
- Memory leaks
- Unexpected behavior
- Edge case failures

## 5-Step Process

### Step 1: Reproduce
- Consistent reproduction?
- EXACT conditions?
- Which module?
- Timing/Data/Logic issue?
- All timeframes?
- All symbols?

**Output:** Reproducible test case.

### Step 2: Root Cause (5 Whys)
Ask "Why?" 5 times to find root cause.

**Example:**
1. Why crash? → Array out of bounds
2. Why out of bounds? → No bounds check
3. Why no check? → Assumed Bars > 0
4. Why assumed? → No initialization check
5. Why no init check? → Missing OnInit validation

**Root Cause:** Need OnInit validation.

### Step 3: Impact
- What else affected?
- Similar bugs elsewhere?
- Edge cases?
- Related modules?

### Step 4: Design Fix
- Addresses ROOT CAUSE (not symptoms)
- No new issues
- Performance OK
- Testable

**Validate:**
- Fixes root cause?
- Breaks anything?
- Simplest fix?
- Performant?

### Step 5: Verify
- Test original scenario
- Test multiple scenarios
- Test edge cases
- No regressions
- Monitor performance

## Common Bug Patterns

### Array Issues
**Symptoms:** Out of bounds, crashes
**Causes:**
- Off-by-one errors
- bars[0] before Bars check
- AS_SERIES confusion

**Prevention:**
```mql4
// BAD
double value = bars[i];

// GOOD
if(i >= 0 && i < ArraySize(bars)) {
   double value = bars[i];
}
```

### Timing Issues
**Symptoms:** Inconsistent results, races
**Causes:**
- Time[0] before bar completion
- Multi-timeframe races
- Wrong base price updates

**Prevention:**
```mql4
// Check bar completion
static datetime last_bar = 0;
if(Time[0] != last_bar) {
   // New bar logic
   last_bar = Time[0];
}
```

### Memory Issues
**Symptoms:** Leaks, crashes
**Causes:**
- Objects not deleted
- Arrays not freed
- Recursive leaks
- String loops

**Prevention:**
```mql4
void OnDeinit(const int reason) {
   ObjectsDeleteAll(0, "PREFIX_");
   ArrayFree(my_array);
}
```

### Calculation Errors
**Symptoms:** Wrong values, NaN
**Causes:**
- Division by zero
- Float precision
- Integer overflow

**Prevention:**
```mql4
// BAD
double result = a / b;

// GOOD
double result = (b != 0) ? a / b : 0;
```

## Edge Cases to Test

**Data:**
- Zero bars
- Single bar
- Missing data
- Extreme values
- NaN/Infinite

**Timing:**
- Market open/close
- Weekend
- Holiday
- DST change

**State:**
- First run
- After reload
- Timeframe change
- Symbol change
- Multiple instances

## Verification Checklist
- [ ] Root cause identified
- [ ] Fix addresses root cause
- [ ] No new bugs
- [ ] Multiple scenarios tested
- [ ] Edge cases tested
- [ ] No regressions
- [ ] Performance OK
- [ ] Similar bugs checked
- [ ] Documentation updated

## Output Format
1. Bug description
2. Reproduction steps
3. Root cause
4. Impact analysis
5. Fix design
6. Fixed code
7. Test results
8. Prevention strategy

## Guardrails
❌ Never fix symptoms only
❌ Never skip edge case testing
❌ Never assume fix works
✅ Always find root cause
✅ Always test thoroughly
✅ Always check for regressions
