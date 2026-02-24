import SwiftParser
import SwiftSyntax
import XCTest
@testable import crap4swift

final class ComplexityTests: XCTestCase {

    private func computeComplexity(of source: String) -> Int {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: "test.swift", tree: tree)
        let finder = FunctionFinder(converter: converter)
        finder.walk(tree)
        guard let funcInfo = finder.functions.first else {
            XCTFail("No function found in source")
            return 0
        }
        let visitor = ComplexityVisitor(viewMode: .sourceAccurate)
        visitor.walk(funcInfo.node)
        return visitor.complexity
    }

    func testEmptyFunction() {
        let source = """
        func empty() {
        }
        """
        XCTAssertEqual(computeComplexity(of: source), 1)
    }

    func testSingleIf() {
        let source = """
        func foo() {
            if true {
                print("yes")
            }
        }
        """
        XCTAssertEqual(computeComplexity(of: source), 2)
    }

    func testGuard() {
        let source = """
        func foo(x: Int?) {
            guard let x = x else { return }
            print(x)
        }
        """
        XCTAssertEqual(computeComplexity(of: source), 2)
    }

    func testSwitchWithThreeCases() {
        let source = """
        func foo(x: Int) {
            switch x {
            case 1: break
            case 2: break
            default: break
            }
        }
        """
        XCTAssertEqual(computeComplexity(of: source), 4)
    }

    func testLogicalAnd() {
        let source = """
        func foo(a: Bool, b: Bool) {
            if a && b {
                print("both")
            }
        }
        """
        // if (+1) + && (+1) = base 1 + 2 = 3
        XCTAssertEqual(computeComplexity(of: source), 3)
    }

    func testLogicalOr() {
        let source = """
        func foo(a: Bool, b: Bool) {
            if a || b {
                print("either")
            }
        }
        """
        XCTAssertEqual(computeComplexity(of: source), 3)
    }

    func testNilCoalescing() {
        let source = """
        func foo(x: Int?) -> Int {
            return x ?? 0
        }
        """
        XCTAssertEqual(computeComplexity(of: source), 2)
    }

    func testTernary() {
        let source = """
        func foo(x: Bool) -> Int {
            return x ? 1 : 0
        }
        """
        XCTAssertEqual(computeComplexity(of: source), 2)
    }

    func testNestedIfs() {
        let source = """
        func foo(a: Bool, b: Bool) {
            if a {
                if b {
                    print("nested")
                }
            }
        }
        """
        XCTAssertEqual(computeComplexity(of: source), 3)
    }

    func testForLoop() {
        let source = """
        func foo(items: [Int]) {
            for item in items {
                print(item)
            }
        }
        """
        XCTAssertEqual(computeComplexity(of: source), 2)
    }

    func testWhileLoop() {
        let source = """
        func foo() {
            var i = 0
            while i < 10 {
                i += 1
            }
        }
        """
        XCTAssertEqual(computeComplexity(of: source), 2)
    }

    func testRepeatWhile() {
        let source = """
        func foo() {
            var i = 0
            repeat {
                i += 1
            } while i < 10
        }
        """
        XCTAssertEqual(computeComplexity(of: source), 2)
    }

    func testCatchClause() {
        let source = """
        func foo() {
            do {
                try something()
            } catch {
                print("error")
            }
        }
        func something() throws {}
        """
        XCTAssertEqual(computeComplexity(of: source), 2)
    }

    func testForAndWhileCombined() {
        let source = """
        func foo(items: [Int]) {
            for item in items {
                var x = item
                while x > 0 {
                    x -= 1
                }
            }
        }
        """
        XCTAssertEqual(computeComplexity(of: source), 3)
    }

    func testComplexFunction() {
        let source = """
        func complex(a: Bool, b: Bool, items: [Int]) -> Int {
            if a && b {
                for item in items {
                    switch item {
                    case 0: return 0
                    case 1: return 1
                    default: break
                    }
                }
            } else if !a {
                return items.first ?? -1
            }
            return a ? 1 : 0
        }
        """
        // if(+1) && (+1) for(+1) case0(+1) case1(+1) default(+1) else-if(+1) ??(+1) ternary(+1) = base 1 + 9 = 10
        XCTAssertEqual(computeComplexity(of: source), 10)
    }

    func testKeywordsInStringsDontCount() {
        let source = """
        func foo() {
            let s = "if else while for guard switch"
            print(s)
        }
        """
        XCTAssertEqual(computeComplexity(of: source), 1)
    }
}
