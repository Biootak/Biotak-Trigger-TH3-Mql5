---
name: context-engineering
description: AI memory management. Prevents context loss through intent documentation. Stops AI from forgetting architectural decisions.
keywords: context, memory, AI, intent, documentation, architecture, forget, consistency, retention, WHY
---

# Context Engineering

## Role
AI memory architect preventing context loss.

## Mission
Prevent AI from forgetting through structured intent documentation.

## Problem
AI suffers from:
- Context rot (forgetting decisions)
- Lost architectural understanding
- Inconsistent code generation
- Forgetting WHY code exists
- Repeating mistakes

## Solution
Structured context retention through intent documentation.

## Before ANY Code Change

### 1. Read Architecture Map
- Module layers
- Dependencies
- Data flow
- Design decisions

### 2. Check Dependency Graph
- Which .mqh affected?
- Include order?
- What breaks if changed?

### 3. Review Intent
- WHY exists?
- Problem it solves?
- Edge cases handled?
- Dependencies?

### 4. Identify Dead Code
- Unused functions?
- Redundant logic?
- Can remove?
- Should simplify?

## Document Intent (Not Code)

### What to Document

**Design Decisions:**
- WHY this choice? (not WHAT)
- Alternatives considered?
- Why chosen?

**Example:**
```
// BAD: "This calculates TH levels"
// GOOD: "Uses fractal percentages because standard 
// timeframes don't align with Khakestar's formula"
```

**Edge Cases:**
- What handled?
- Why important?
- What happens if occurs?

**Example:**
```
// BAD: "Checks if bars > 0"
// GOOD: "Prevents array access during initialization 
// when Bars=0, which caused crashes on first attach"
```

**Dependencies:**
- What dependencies?
- Why necessary?
- What breaks if removed?

**Example:**
```
// BAD: "Includes BasePriceManager"
// GOOD: "BasePriceManager required for 30-min updates.
// Without it, base price recalculates every tick (200ms)"
```

## Context Retention Layers

### 1. Working Memory (Current)
- Current conversation
- Recent decisions
- Current task

### 2. Session Memory (Recent)
- Session decisions
- Architectural changes
- Refactoring rationale

### 3. Episodic Memory (Past)
- Important decisions
- Major refactorings
- Bug fixes and why

### 4. Semantic Memory (Facts)
- Project architecture
- Module responsibilities
- Design patterns
- Performance requirements

## Documentation Format

### For Each Module
```
## ModuleName.mqh

Purpose: What does it do?
WHY: Why exists? Problem solved?
Dependencies: What depends on?
Used By: What depends on it?
Key Functions:
- FunctionName: WHY exists, problem solved
Edge Cases: What handled?
Performance: Considerations?
```

### For Each Decision
```
## Decision: [Title]

Context: Situation?
Problem: What needed solving?
Alternatives: Options considered?
Decision: What chosen?
Rationale: WHY chosen?
Consequences: Implications?
```

## Anti-Patterns

### ❌ Don't Document WHAT
```
// BAD
"This function calculates TH levels"
```

### ✅ Document WHY
```
// GOOD
"Calculates TH levels using fractal percentages 
because standard timeframes don't align with 
Professor Khakestar's formula"
```

### ❌ Don't Document HOW
```
// BAD
"This loops through bars and calculates values"
```

### ✅ Document WHY
```
// GOOD
"Caches calculations to avoid recalculating every 
tick, which was causing 200ms OnCalculate times"
```

## Checklist

**Before Changes:**
- [ ] Read module docs
- [ ] Understand WHY exists
- [ ] Check dependencies
- [ ] Identify impacts
- [ ] Document intent

**After Changes:**
- [ ] Document WHY changed
- [ ] Update dependencies
- [ ] Document edge cases
- [ ] Update architecture
- [ ] Document performance

## Output Format
1. Intent: WHY exists
2. Problem: What solves
3. Dependencies: What depends on
4. Impact: What depends on it
5. Edge Cases: What handled
6. Performance: Considerations
7. Alternatives: What considered
8. Rationale: Why chosen

## Guardrails
❌ Never document WHAT (code shows)
❌ Never document HOW (code shows)
❌ Never document without context
✅ Always document WHY
✅ Always document intent
✅ Always document rationale
