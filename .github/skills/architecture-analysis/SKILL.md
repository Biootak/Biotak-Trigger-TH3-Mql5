---
name: architecture-analysis
description: Deep architectural analysis. Analyzes dependencies, coupling, cohesion, data flow. Detects tight coupling and dead code.
keywords: architecture, dependencies, coupling, cohesion, modular, data flow, include order, circular, DRY, dead code
---

# Architecture Analysis

## Role
System architect analyzing codebase structure and dependencies.

## Mission
Understand architecture, detect coupling issues, identify dead code.

## Activate When
- Understanding system
- Detecting tight coupling
- Finding circular dependencies
- Analyzing data flow
- Checking module layering
- Finding dead code
- Ensuring DRY principle

## 5-Level Analysis

### L1: Surface
- Syntax errors
- Logic errors
- Code smells
- Dead code

### L2: Structural
- .mqh dependencies
- Include order
- Function calls
- Data flow
- Coupling
- Circular deps
- Unused functions

### L3: Performance
- Hot paths (OnCalculate, OnTimer)
- Expensive operations
- Memory allocations
- Unnecessary computations
- Redundant calculations

### L4: Edge Cases
- Zero bars
- Market open/close
- Missing data
- Extreme values
- Timeframe changes
- Multiple instances

### L5: Integration
- Module interactions
- Cross-file dependencies
- Include hierarchy
- Manager patterns
- Failure modes
- Stress behavior

## Biotak TH3 Architecture

### Module Layers (Include Order)
1. **Config**: PropertiesAndInputs, ConstantsAndEnums, GlobalVariables
2. **Core**: THCalculations, BasePriceManager, TimeframeFunctions, FractalTimeframes
3. **UI**: ObjectFunctions, ObjectManager, LabelFunctions, ExtendedDrawingFunctions
4. **Events**: EventHandlers (MUST BE LAST)

### Key Managers & WHY
- **BasePriceManager**: 30-min updates (WHY: Avoid tick recalc)
- **ObjectManager**: 64K limit monitor (WHY: Prevent MT4 overflow crash)
- **BasePriceHistoryManager**: Historical persistence (WHY: Multi-chart without recalc)
- **PerformanceMonitor**: CPU/memory tracking (WHY: Detect degradation early)

### Dependency Rules
- Each .mqh = single responsibility (WHY: Easier testing)
- Clear include hierarchy (WHY: Avoid circular deps)
- Minimal circular deps (WHY: Reduce coupling)
- Core separated from MT4-specific (WHY: Easier MT5 migration)
- Manager pattern for cross-module (WHY: Loose coupling)

### Data Flow
1. OnInit → Load config → Initialize managers
2. OnCalculate → Check base price → Calculate TH → Draw objects
3. OnDeinit → Cleanup objects → Free memory
4. OnChartEvent → Handle user → Update display

## Cohesion & Coupling

### High Cohesion (Good)
- Functions work together on related tasks
- LCOM4 = 1 (single responsibility)
- Methods use shared variables
- Example: THCalculations.mqh only TH math

### Low Coupling (Good)
- Well-defined interfaces
- Changes don't break others
- Manager pattern for communication
- Example: UI doesn't access Core directly

### Warning Signs
- Function uses multiple unrelated modules (high coupling)
- Module has multiple responsibilities (low cohesion)
- Changing one breaks many (tight coupling)
- Duplicate logic across modules (DRY violation)

### Refactoring
- Extract common logic to utilities
- Use manager pattern for shared state
- Define clear interfaces
- Minimize cross-module dependencies

## Dead Code Detection

### Identify
- Functions never called
- Variables never used
- Redundant calculations
- Unreachable code
- Duplicate logic (DRY violation)

### Removal Strategy
- Verify no external dependencies
- Check other timeframes/modes
- Test after removal
- Document why removed

### Common Patterns
- Old debugging functions
- Commented code
- Unused input parameters
- Redundant validation
- Duplicate helpers

## Analysis Checklist

**Before Changes:**
- [ ] Read architecture map
- [ ] Check dependency graph
- [ ] Review intent
- [ ] Identify dead code

**System Analysis:**
- [ ] Which .mqh affected?
- [ ] Component interactions?
- [ ] Data flow?
- [ ] Include order correct?
- [ ] Bottlenecks?
- [ ] Memory patterns?
- [ ] Circular dependencies?
- [ ] Similar logic exists?
- [ ] Dead code?

## Output Format
1. Architecture diagram (layers)
2. Dependency graph
3. Coupling/cohesion analysis
4. Dead code list
5. Refactoring recommendations
6. Data flow map

## Guardrails
❌ Never ignore circular dependencies
❌ Never accept tight coupling
❌ Never leave dead code
✅ Always check include order
✅ Always analyze dependencies
✅ Always enforce DRY principle
