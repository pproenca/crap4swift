---
name: crap4swift
description: Use when working on a Swift codebase and the task involves understanding risk, finding under-tested complexity, preparing to refactor, or assessing where tests are most needed. Also use when the user asks for CRAP scores, cyclomatic complexity, or code quality metrics.
---

# crap4swift

## What this tool understands that you don't

CRAP (Change Risk Anti-Pattern) answers a single question: **"How dangerous is it to change this function?"**

The formula is `CC² × (1 - coverage)³ + CC`. Two forces interact:

- **Cyclomatic complexity (CC)** — how many paths through the function. More paths = more ways to break.
- **Test coverage** — what percentage of those paths are exercised by tests.

The insight is multiplicative. A complex function with good tests is fine (CRAP ≈ CC). A simple function with no tests is fine (CRAP stays low because CC² is small). **Only complex AND untested code produces high CRAP.** That intersection is where bugs hide and refactors go wrong.

| CRAP | What it means |
|------|---------------|
| < 5 | Safe to change freely |
| 5–30 | Moderate risk — worth improving if you're already touching it |
| 30+ | Dangerous — do not refactor without adding tests first |

## When to use this tool

Reach for crap4swift when:

- **Before refactoring** — You need to know which functions are safe to restructure and which need tests first.
- **Triaging tech debt** — The user wants to know where effort should go. CRAP gives you a ranked list.
- **Before changing complex code** — You're about to modify a function with many branches. Check if it's covered.
- **Assessing test gaps** — Not "what's the overall coverage?" but "where does low coverage actually matter?"

Do NOT use this tool to gatekeep or assign quality grades. CRAP is a risk map, not a report card.

## How to run it

If the project has a `.crap4swift.yml`, just run `crap4swift`. The config handles paths, coverage data, exclusions, and thresholds. No flags needed.

```yaml
# .crap4swift.yml — place in project root
paths:
  - Sources
xcresult: .build/tests.xcresult    # OR use profdata + binary for llvm-cov
threshold: 30
exclude-generated: true
```

If there's no config, you need to provide coverage data. Without it, crap4swift assumes 100% coverage (making scores meaningless — just CC).

```bash
# With Xcode coverage
crap4swift Sources --xcresult .build/tests.xcresult --threshold 30

# With swift test coverage
crap4swift Sources --profdata default.profdata --binary .build/debug/MyAppPackageTests.xctest --threshold 30
```

Use `--json` when you need to process results programmatically. Use `--filter "functionName"` to zoom in on specific functions.

## How to act on results

This is the part that matters. Running crap4swift is easy. Knowing what to do next requires judgment.

### The cardinal rule: tests before refactoring

A function with CRAP 85 (CC=8, coverage=12%) is telling you: "I have 8 paths through me and almost none are tested." If you refactor this function without tests, you are *exactly the person CRAP was designed to warn about*. You'll change the structure, break an untested path, and ship a regression.

### The workflow

1. **Run crap4swift.** Look at functions with CRAP >= 30.

2. **For each high-CRAP function, check coverage first.**
   - If coverage < 80%: write characterization tests before doing anything else. These tests capture *current behavior* — they don't assert correctness, they assert "this is what the function does today."
   - If coverage >= 80%: you have enough safety net. Proceed to refactoring.

3. **Write characterization tests.**
   - Call the function with representative inputs for each branch.
   - Assert on actual outputs, even if the outputs seem wrong. You're locking in behavior, not judging it.
   - Cover the edge cases the branches imply (nil paths, empty collections, error conditions).
   - Re-run crap4swift to confirm coverage improved.

4. **Now refactor.**
   - Extract helper methods to reduce nesting.
   - Replace complex conditionals with guard clauses.
   - Break switch statements into lookup tables or strategy patterns.
   - Each change: run tests. Green means your refactoring preserved behavior.

5. **Re-run crap4swift.** The score should drop. If it didn't, your refactoring didn't actually reduce complexity — you just moved it around.

### What "done" looks like

You're done when the functions you touched have CRAP < 10. That means either complexity went down, coverage went up, or both. The function is now safe to change in the future.

## Reference

**Config file:** `.crap4swift.yml` in project root. Auto-detected. CLI flags override config values.

**Config keys:** `paths`, `xcresult`, `profdata`, `binary`, `threshold`, `filter`, `exclude-path`, `exclude-generated`, `json`

**Coverage data sources:**
- `--xcresult <path>` — From `xcodebuild test -resultBundlePath`
- `--profdata <path> --binary <path>` — From `swift test --enable-code-coverage`

**What gets analyzed:** `func`, `init`, `deinit`, computed property accessors, `subscript`.

**Complexity counts:** `if`, `guard`, `for`, `while`, `repeat`, each `case`, each `catch`, ternary `?:`, `??`, `&&`, `||`.
