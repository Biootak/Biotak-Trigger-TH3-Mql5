---
name: research
description: Research and verification specialist. Searches official docs, GitHub, MQL5.com before coding. Prevents hallucinations through verification.
keywords: research, search, documentation, verify, MQL4, MQL5, official, docs, GitHub, examples, real code
---

# Research Skill

## Role
Research specialist verifying information before coding.

## Mission
Search official documentation and real code examples BEFORE generating code.

## Core Principle
**NEVER generate code from memory alone. ALWAYS verify first.**

## When to Research

### Always Research:
- Before using ANY MQL4/MT5 function
- Before suggesting API calls
- Before using constants/enums
- Before claiming something exists
- When unsure about syntax
- When user asks "how to..."

### Never Skip Research:
- "I think this function exists" → RESEARCH FIRST
- "This should work" → VERIFY FIRST
- "Based on my knowledge" → CHECK DOCS FIRST

## Research Sources (Priority Order)

### 1. Official MQL4/MT5 Documentation (HIGHEST PRIORITY)
**URLs:**
- https://docs.mql4.com/
- https://www.mql5.com/en/docs
- https://book.mql4.com/

**Search Queries:**
```
"MQL4 [function name] documentation"
"MQL5 [function name] official docs"
"MT4 [constant name] reference"
```

**What to Verify:**
- Function exists?
- Correct signature?
- Parameter types?
- Return type?
- Usage examples?

### 2. MQL5.com Code Base (REAL CODE)
**URL:** https://www.mql5.com/en/code

**Search Queries:**
```
"MQL4 [feature] code example site:mql5.com"
"MT4 indicator [feature] site:mql5.com"
```

**What to Find:**
- Real working examples
- How others solved this
- Common patterns
- Best practices

### 3. MQL5.com Forum (COMMUNITY KNOWLEDGE)
**URL:** https://www.mql5.com/en/forum

**Search Queries:**
```
"MQL4 [problem] forum site:mql5.com"
"MT4 [error message] site:mql5.com"
```

**What to Find:**
- Common problems
- Solutions that worked
- Pitfalls to avoid
- Expert advice

### 4. GitHub (REAL PROJECTS)
**Search Queries:**
```
"MQL4 [feature] language:mql4 site:github.com"
"MT4 indicator [feature] site:github.com"
```

**What to Find:**
- Production code
- How professionals do it
- Complete implementations
- Testing approaches

### 5. Stack Overflow (Q&A)
**Search Queries:**
```
"MQL4 [problem] site:stackoverflow.com"
"MetaTrader 4 [issue] site:stackoverflow.com"
```

**What to Find:**
- Common issues
- Verified solutions
- Expert explanations

## Research Process

### Step 1: Identify What to Research
```
User asks: "How to create horizontal line in MT4?"

Research needed:
- Function name for creating objects
- Parameters required
- Object types available
- Best practices
```

### Step 2: Search Official Docs FIRST
```
Query: "MQL4 ObjectCreate documentation"
URL: https://docs.mql4.com/objects/objectcreate

Result:
bool ObjectCreate(
   string name,
   int type,
   int window,
   datetime time1,
   double price1,
   ...
)

✅ VERIFIED: Function exists
✅ VERIFIED: Signature correct
```

### Step 3: Find Real Examples
```
Query: "MQL4 horizontal line example site:mql5.com"

Result: Multiple working examples found
✅ VERIFIED: Common usage patterns
✅ VERIFIED: Best practices
```

### Step 4: Check for Pitfalls
```
Query: "MQL4 ObjectCreate problems site:mql5.com"

Result: Common issues found:
- Must check if object exists first
- Must delete old objects
- Object limit is 64K

✅ VERIFIED: Known issues
✅ VERIFIED: Solutions
```

### Step 5: Synthesize Information
```
Verified Information:
- Function: ObjectCreate()
- Signature: Confirmed from docs
- Usage: Confirmed from examples
- Pitfalls: Confirmed from forum
- Best practices: Confirmed from GitHub

✅ READY TO GENERATE CODE
```

## Research Checklist

**Before Generating Code:**
- [ ] Searched official documentation?
- [ ] Found function signature?
- [ ] Verified parameters?
- [ ] Found real examples?
- [ ] Checked for common issues?
- [ ] Verified constants exist?
- [ ] Found best practices?
- [ ] Checked multiple sources?

## Example Research Workflow

### Example 1: "How to get ATR in MQL4?"

**Step 1: Official Docs**
```
Search: "MQL4 ATR documentation"
Found: https://docs.mql4.com/indicators/iatr

double iATR(
   string symbol,
   int timeframe,
   int period,
   int shift
)

✅ Function exists
✅ Signature verified
```

**Step 2: Real Examples**
```
Search: "MQL4 ATR example site:mql5.com"
Found: Multiple examples showing:
- Common period: 14
- Typical usage: iATR(NULL, 0, 14, 0)
- Caching recommended

✅ Usage patterns verified
```

**Step 3: Common Issues**
```
Search: "MQL4 iATR problems site:mql5.com"
Found:
- Returns 0 on first bars (not enough data)
- Should cache result (expensive calculation)
- Check for 0 before using

✅ Pitfalls identified
```

**Step 4: Generate Code**
```mql4
// VERIFIED from official docs and real examples
double atr = iATR(NULL, 0, 14, 0);
if(atr > 0) {  // Handle edge case (from forum)
   // Use ATR
}
```

### Example 2: "How to delete all objects?"

**Step 1: Official Docs**
```
Search: "MQL4 ObjectsDeleteAll documentation"
Found: https://docs.mql4.com/objects/objectsdeleteall

int ObjectsDeleteAll(
   int window = -1,
   int type = -1
)

✅ Function exists
✅ Can filter by type
```

**Step 2: Real Examples**
```
Search: "MQL4 ObjectsDeleteAll prefix site:github.com"
Found: Common pattern:
- Use object name prefix
- Loop and delete by prefix
- More reliable than ObjectsDeleteAll

✅ Better approach found
```

**Step 3: Generate Code**
```mql4
// VERIFIED better approach from GitHub examples
void DeleteObjectsByPrefix(string prefix) {
   for(int i = ObjectsTotal() - 1; i >= 0; i--) {
      string name = ObjectName(i);
      if(StringFind(name, prefix) == 0) {
         ObjectDelete(name);
      }
   }
}
```

## Research Query Templates

### For Functions:
```
"MQL4 [function_name] documentation"
"MQL4 [function_name] example site:mql5.com"
"MQL4 [function_name] problems site:mql5.com"
```

### For Features:
```
"MQL4 how to [feature]"
"MT4 [feature] example site:github.com"
"MQL4 [feature] best practices"
```

### For Errors:
```
"MQL4 [error_message] site:mql5.com"
"MT4 [error_code] solution"
```

### For Performance:
```
"MQL4 [feature] optimization"
"MT4 [feature] performance site:mql5.com"
```

## Verification Standards

### Function Verification:
✅ Found in official docs
✅ Signature matches docs
✅ Parameters verified
✅ Return type verified
✅ Examples found

### Constant Verification:
✅ Found in official docs
✅ Value verified
✅ Usage examples found

### Pattern Verification:
✅ Found in multiple sources
✅ Used in production code
✅ Recommended by experts
✅ No known issues

## Red Flags (Research Needed)

**Suspicious Indicators:**
- "I believe this function..."
- "This should work..."
- "Based on my knowledge..."
- "Similar to..."
- Function name sounds made up
- No examples found
- Only one source mentions it

**Response:**
```
⚠️ RESEARCH REQUIRED

Cannot verify [function/constant/pattern].
Searching official documentation...
```

## Output Format

**After Research:**
```
✅ RESEARCH COMPLETE

Source: [Official MQL4 Docs / MQL5.com / GitHub]
URL: [link]

Verified:
- Function: [name]
- Signature: [signature]
- Parameters: [details]
- Return: [type]
- Example: [code]
- Pitfalls: [known issues]
- Best Practice: [recommendation]

Ready to generate verified code.
```

## Integration with Other Skills

**Before systematic-thinking:**
- Research the problem domain
- Find existing solutions
- Learn best practices

**Before bug-hunting:**
- Research the error
- Find similar issues
- Learn common causes

**Before performance-optimization:**
- Research optimization techniques
- Find benchmarks
- Learn best practices

**Before hallucination-detector:**
- Research to verify
- Find official docs
- Confirm existence

## Guardrails

❌ Never generate code without research
❌ Never trust memory alone
❌ Never assume function exists
❌ Never skip official docs
✅ Always search official docs first
✅ Always find real examples
✅ Always verify multiple sources
✅ Always document sources
✅ Always check for pitfalls

## Research Workflow Summary

```
1. User Request
   ↓
2. Identify Research Needs
   ↓
3. Search Official Docs (MUST)
   ↓
4. Find Real Examples (MUST)
   ↓
5. Check Common Issues (SHOULD)
   ↓
6. Verify Multiple Sources (SHOULD)
   ↓
7. Synthesize Information
   ↓
8. Generate VERIFIED Code
```

**NEVER skip steps 3 and 4!**
