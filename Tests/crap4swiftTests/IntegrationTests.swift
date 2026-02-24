import SwiftParser
import SwiftSyntax
import XCTest
@testable import crap4swift

final class IntegrationTests: XCTestCase {

    /// Runs the full pipeline on inline source: parse → find functions → compute complexity → compute CRAP score.
    private func analyze(source: String) -> [CrapEntry] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: "test.swift", tree: tree)

        let finder = FunctionFinder(converter: converter)
        finder.walk(tree)

        return finder.functions.map { funcInfo in
            let visitor = ComplexityVisitor(viewMode: .sourceAccurate)
            visitor.walk(funcInfo.node)
            let cc = visitor.complexity
            let cov = 100.0 // no coverage provider → assume covered
            let score = crapScore(complexity: cc, coveragePercent: cov)
            return CrapEntry(
                name: funcInfo.name,
                file: "test.swift",
                line: funcInfo.startLine,
                complexity: cc,
                coverage: cov,
                crap: score
            )
        }
    }

    func testFullPipelineSimpleFunction() {
        let source = """
        func greet(name: String) -> String {
            return "Hello, \\(name)"
        }
        """
        let entries = analyze(source: source)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].name, "greet(name:)")
        XCTAssertEqual(entries[0].complexity, 1)
        XCTAssertEqual(entries[0].coverage, 100.0)
        XCTAssertEqual(entries[0].crap, 1.0, accuracy: 0.001)
    }

    func testFullPipelineBranchyFunction() {
        let source = """
        func process(x: Int?, flag: Bool) -> Int {
            guard let x = x else { return -1 }
            if flag && x > 0 {
                return x
            } else {
                return 0
            }
        }
        """
        let entries = analyze(source: source)
        XCTAssertEqual(entries.count, 1)
        // guard(+1) if(+1) &&(+1) = base 1 + 3 = 4
        XCTAssertEqual(entries[0].complexity, 4)
        // 100% coverage → CRAP = CC
        XCTAssertEqual(entries[0].crap, 4.0, accuracy: 0.001)
    }

    func testFullPipelineMultipleFunctions() {
        let source = """
        func simple() {
            print("hi")
        }

        func branchy(a: Bool, b: Bool) -> Int {
            if a {
                if b {
                    return 1
                }
                return 2
            }
            return 0
        }

        class Foo {
            init(value: Int) {
                self.value = value
            }
            var value: Int
        }
        """
        let entries = analyze(source: source)
        XCTAssertEqual(entries.count, 3)

        let names = entries.map { $0.name }
        XCTAssertTrue(names.contains("simple()"))
        XCTAssertTrue(names.contains("branchy(a:b:)"))
        XCTAssertTrue(names.contains("init(value:)"))

        for entry in entries {
            XCTAssertGreaterThan(entry.complexity, 0)
            XCTAssertGreaterThan(entry.crap, 0)
            XCTAssertEqual(entry.coverage, 100.0)
        }
    }

    func testFullPipelineZeroCoverageInflatesScore() {
        let source = """
        func complex(x: Int) -> Int {
            if x > 0 {
                for i in 0..<x {
                    if i % 2 == 0 {
                        print(i)
                    }
                }
            }
            return x
        }
        """
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: "test.swift", tree: tree)
        let finder = FunctionFinder(converter: converter)
        finder.walk(tree)

        let funcInfo = finder.functions[0]
        let visitor = ComplexityVisitor(viewMode: .sourceAccurate)
        visitor.walk(funcInfo.node)
        let cc = visitor.complexity

        let scoreCovered = crapScore(complexity: cc, coveragePercent: 100.0)
        let scoreUncovered = crapScore(complexity: cc, coveragePercent: 0.0)

        // With full coverage, CRAP = CC
        XCTAssertEqual(scoreCovered, Double(cc), accuracy: 0.001)
        // With zero coverage, CRAP = CC² + CC (much higher)
        XCTAssertEqual(scoreUncovered, Double(cc * cc + cc), accuracy: 0.001)
        XCTAssertGreaterThan(scoreUncovered, scoreCovered)
    }

    func testReportOutputFromPipeline() {
        let source = """
        func foo() {
            if true { print("yes") }
        }
        """
        let entries = analyze(source: source)
        let table = formatTable(entries)

        XCTAssertTrue(table.contains("CRAP Report"))
        XCTAssertTrue(table.contains("foo()"))
        XCTAssertTrue(table.contains("test.swift:1"))

        let json = formatJSON(entries)
        XCTAssertTrue(json.contains("foo()"))
        XCTAssertTrue(json.contains("\"crap\""))
    }
}
