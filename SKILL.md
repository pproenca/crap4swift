---
name: crap4swift
description: Use when the user asks for a CRAP report, cyclomatic complexity analysis, or code quality metrics on a Swift project
---

# crap4swift — CRAP Metric for Swift

Computes the **CRAP** (Change Risk Anti-Pattern) score for every function in a Swift project. CRAP combines cyclomatic complexity with test coverage to identify functions that are both complex and under-tested.

## Setup

Clone and build:

```bash
git clone https://github.com/pproenca/crap4swift.git
cd crap4swift
swift build -c release
```

The binary will be at `.build/release/crap4swift`.

## Usage

### Generate coverage data first

```bash
# Using xcodebuild (produces .xcresult)
xcodebuild test -scheme MyApp -resultBundlePath tests.xcresult

# Or using swift test with coverage
swift test --enable-code-coverage
```

### Run CRAP analysis

```bash
# Analyze source directory (defaults to "Sources")
crap4swift --source-dir Sources/MyApp

# With xcresult coverage
crap4swift --source-dir Sources --xcresult tests.xcresult

# With llvm-cov coverage (from swift test --enable-code-coverage)
crap4swift --source-dir Sources --profdata default.profdata --binary .build/debug/MyAppPackageTests.xctest

# JSON output
crap4swift --source-dir Sources --json

# Filter by CRAP score threshold
crap4swift --source-dir Sources --threshold 30

# Filter by function name
crap4swift --source-dir Sources --filter "viewDidLoad"
```

### Output

A table sorted by CRAP score (worst first):

```
CRAP Report
===========

Function                       File                          CC   Cov%     CRAP
--------------------------------------------------------------------------------
complexFunction(_:)            Sources/Logic.swift:42        12   45.0%    130.2
init(value:)                   Sources/Model.swift:8          5    0.0%     30.0
simpleFunction()               Sources/Utils.swift:10         1  100.0%      1.0
```

## Interpreting Scores

| CRAP Score | Meaning |
|-----------|---------|
| 1-5       | Clean — low complexity, well tested |
| 5-30      | Moderate — consider refactoring or adding tests |
| 30+       | Crappy — high complexity with poor coverage |

## How It Works

1. Finds all `.swift` files under the source directory
2. Parses each file using SwiftSyntax AST
3. Extracts functions (`func`, `init`, `deinit`, computed properties, `subscript`)
4. Computes cyclomatic complexity (if/guard/for/while/repeat/switch-case/catch/ternary/&&/||/??)
5. Reads coverage from xcresult or llvm-cov data
6. Applies CRAP formula: `CC² x (1 - cov)³ + CC`
7. Sorts by CRAP score descending and prints report
