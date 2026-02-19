---
name: performance-optimization
description: MT4/MT5 performance optimization. Fixes slow OnCalculate, memory leaks, high CPU usage.
keywords: performance, optimization, memory, speed, cache, profiling, OnCalculate, leak, slow, MT4, MT5
---

# Performance Optimization

## Role
Elite MT4/MT5 performance engineer for real-time trading systems.

## Mission
Optimize indicators/EAs: max performance, min resources, maintain accuracy.

## Activate When
- OnCalculate > 50ms
- Memory leaks
- High CPU usage
- Object count near 64K
- Performance degradation

## Core Process

### 1. Measure Baseline
```mql4
uint start = GetTickCount();
// calculations
uint elapsed = GetTickCount() - start;
if(elapsed > 50) Print("SLOW: ", elapsed, "ms");
```

### 2. Find Bottlenecks
- Longest operations?
- Most frequent calls?
- Memory allocations?
- Unnecessary recalculations?

### 3. Optimize (80/20 rule)
Focus on most expensive operations first.

### 4. Verify
Compare metrics. Ensure accuracy maintained.

## Critical Rules

### Calculations
✅ Cache expensive ops (ATR, fractals)
✅ Use prev_calculated (new bars only)
✅ Pre-calc constants (outside loops)
❌ Never recalc every tick

**Example:**
```mql4
// BAD
double atr = iATR(NULL, 0, 14, 0);

// GOOD
static double cached_atr = 0;
static datetime last = 0;
if(Time[0] != last) {
   cached_atr = iATR(NULL, 0, 14, 0);
   last = Time[0];
}
```

### Memory
✅ Track allocations
✅ OnDeinit() cleanup
✅ Monitor 64K limit
❌ Never leak memory

**Example:**
```mql4
void OnDeinit(const int reason) {
   ObjectsDeleteAll(0, "TH_");
   ArrayFree(cached_levels);
}
```

### Objects
✅ Batch operations
✅ ObjectsDeleteAll(prefix)
✅ Cache names
❌ Never create every tick

**Example:**
```mql4
// BAD
ObjectCreate("line", OBJ_HLINE, 0, 0, price);

// GOOD
if(ObjectFind("line") < 0) {
   ObjectCreate("line", OBJ_HLINE, 0, 0, price);
} else {
   ObjectSet("line", OBJPROP_PRICE1, price);
}
```

## OnCalculate Pattern
```mql4
int OnCalculate(const int rates_total,
                const int prev_calculated,
                ...) {
   int start = prev_calculated > 0 ? prev_calculated - 1 : 0;
   for(int i = start; i < rates_total; i++) {
      // calculations
   }
   return rates_total;
}
```

## Verification Checklist
- [ ] OnCalculate < 50ms
- [ ] Memory stable 24h
- [ ] Objects < 60K
- [ ] No redundant calcs
- [ ] Expensive ops cached
- [ ] No leaks (attach/detach test)
- [ ] Accuracy maintained

## Common Issues

**Slow OnCalculate**
- Use prev_calculated
- Cache calculations
- Minimize loops
- Batch object updates

**Memory Leak**
- OnDeinit cleanup
- Free arrays
- Avoid deep recursion
- Pre-allocate strings

**Too Many Objects**
- Object pooling
- Batch deletion
- Monitor count

## Output Format
1. Baseline metrics
2. Bottleneck analysis
3. Optimization plan
4. Optimized code
5. Before/after comparison
6. Verification results

## Guardrails
❌ Never sacrifice accuracy
❌ Never skip verification
❌ Never optimize without measuring
✅ Always maintain correctness
✅ Always test edge cases
