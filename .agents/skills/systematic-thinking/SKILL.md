---
name: systematic-thinking
description: Structured problem-solving. 4-phase deep thinking before coding. Prevents rushed solutions and architectural mistakes.
keywords: thinking, analysis, design, planning, problem-solving, root cause, systematic, structured, architecture
---

# Systematic Thinking

## Role
Senior engineer enforcing deep thinking before action.

## Mission
Force structured analysis before any code changes.

## Core Principle
**NEVER code immediately. ALWAYS think first.**

## 4-Phase Framework (MANDATORY)

### Phase 1: Deep Understanding (5 min)

**Questions:**
- ACTUAL problem? (not symptoms)
- ROOT CAUSES? (not surface)
- MT4/MT5 constraints?
- Performance implications?
- Edge case failures?
- Assumptions?

**Output:** Clear problem statement with root causes.

### Phase 2: System Analysis (5 min)

**Questions:**
- Which .mqh files affected?
- Component interactions?
- Data flow?
- Include order matters? (Config→Core→UI→Events)
- Bottlenecks?
- Memory patterns?
- Hidden/circular dependencies?
- Similar logic exists? (DRY)
- Dead code to remove?

**Output:** System impact analysis with dependency map.

### Phase 3: Solution Design (10 min)

**Process:**
1. Generate 3 approaches (not just first)
2. Evaluate each:
   - Performance?
   - Memory?
   - Maintainability?
   - Risk?
   - Dependencies?
   - Simplicity?
3. Choose optimal (not first)
4. Validate:
   - Weakens architecture? → Alternatives
   - Tight coupling? → Manager pattern
   - Duplication? → Utility
   - Performant? → Caching
   - Can simplify? → Remove code

**Output:** Chosen solution with rationale.

### Phase 4: Implementation Plan (5 min)

**Questions:**
- Files to modify? (list all .mqh)
- Include order correct?
- Breaks other modules?
- Minimal changes?
- Test strategy?
- Failure scenarios?

**Output:** Implementation plan with tests.

## Total Time: 25 minutes

**Prevents:**
- Wrong solutions
- Breaking changes
- Performance issues
- Architectural degradation
- Wasted time

## Root Cause Analysis (5 Whys)

**Example:**
1. Why crash? → Object count > 64K
2. Why > 64K? → Objects not deleted
3. Why not deleted? → OnDeinit not called
4. Why not called? → Removed during OnCalculate
5. Why matters? → MT4 doesn't call OnDeinit during OnCalculate

**Root Cause:** Need cleanup in OnCalculate, not just OnDeinit.

## Decision Framework

**Criteria (priority order):**
1. Correctness - Solves problem?
2. Simplicity - Simplest solution?
3. Performance - Fast enough?
4. Maintainability - Others understand?
5. Testability - Can test?
6. Flexibility - Adapts to future?

**Red Flags:**
- "This is clever" → Too complex
- "This might work" → Not confident
- "I'll fix later" → Technical debt
- "Works on my machine" → Not tested

## Problem-Solving (When Stuck)

### 1. Pause
- Step back
- Re-read problem
- Question assumptions

### 2. Break Down
- Smaller pieces
- Solve independently
- Integrate

### 3. Research
- Similar problems
- MT4/MT5 docs
- MQL5.com forums
- Benchmarks

### 4. Experiment
- Test cases
- Different approaches
- Measure results
- Learn from failures

### 5. Validate
- Test thoroughly
- Verify assumptions
- Edge cases
- Measure performance

## Output Format

### 1. Problem Analysis
- Actual problem
- Root causes
- Constraints
- Edge cases

### 2. System Impact
- Files affected
- Dependencies
- Data flow
- Performance

### 3. Solution Design
- 3 approaches
- Evaluation
- Chosen solution
- Rationale

### 4. Implementation Plan
- Files to modify
- Change sequence
- Test strategy
- Rollback plan

### 5. Risk Assessment
- What could fail?
- Mitigation
- Validation

## Guardrails
❌ Never code without thinking
❌ Never choose first solution
❌ Never skip analysis
✅ Always understand root cause
✅ Always consider alternatives
✅ Always plan before implementing
