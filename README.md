# crap4swift

Compute **CRAP (Change Risk Anti-Pattern)** scores for Swift code. Inspired by Uncle Bob's [crap4clj](https://github.com/unclebob/crap4clj).

```
CRAP(fn) = CC² × (1 - coverage)³ + CC
```

Uses **SwiftSyntax** for accurate AST-based cyclomatic complexity analysis — no regex, no string matching, no false positives from keywords in strings or comments.

## Install

```bash
git clone https://github.com/pproenca/crap4swift.git
cd crap4swift
swift build -c release
```

## Usage

```bash
# Analyze source directory (defaults to "Sources")
crap4swift --source-dir Sources/MyApp

# With xcresult coverage
crap4swift --source-dir Sources --xcresult .build/tests.xcresult

# With llvm-cov coverage
crap4swift --source-dir Sources --profdata default.profdata --binary .build/debug/MyApp

# JSON output
crap4swift --source-dir Sources --json

# Filter by threshold
crap4swift --source-dir Sources --threshold 30

# Filter by function name
crap4swift --source-dir Sources --filter "viewDidLoad"
```

## Example Output

```
CRAP Report
===========

Function                       File                          CC   Cov%     CRAP
--------------------------------------------------------------------------------
complexFunction(_:)            Sources/Logic.swift:42        12   45.0%    130.2
init(value:)                   Sources/Model.swift:8          5    0.0%     30.0
simpleFunction()               Sources/Utils.swift:10         1  100.0%      1.0
```

## What It Counts

**Cyclomatic complexity** (decision points):

| Construct | Example |
|-----------|---------|
| `if` / `else if` | `if condition { }` |
| `guard` | `guard x else { }` |
| `for` | `for x in y { }` |
| `while` | `while condition { }` |
| `repeat-while` | `repeat { } while condition` |
| `switch case` | Each `case` in a switch |
| `catch` | `catch Pattern { }` |
| `??` | `x ?? default` |
| `&&` | `a && b` |
| `\|\|` | `a \|\| b` |
| Ternary | `condition ? a : b` |

**Functions extracted**: `func`, `init`, `deinit`, computed property accessors (`get`/`set`/`willSet`/`didSet`), `subscript`.

## Formula Verification

| CC | Coverage | CRAP |
|----|----------|------|
| 1 | 100% | 1.0 |
| 5 | 100% | 5.0 |
| 5 | 0% | 30.0 |
| 8 | 45% | ~18.65 |

## Credits

Based on the CRAP metric concept by [Alberto Savoia](http://www.artima.com/weblogs/viewpost.jsp?thread=210575) and directly inspired by [Robert C. Martin](https://github.com/unclebob) (Uncle Bob)'s [crap4clj](https://github.com/unclebob/crap4clj) — a Clojure implementation of the same metric.

## License

MIT
