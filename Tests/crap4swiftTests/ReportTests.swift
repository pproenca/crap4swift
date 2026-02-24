import XCTest
@testable import crap4swift

final class ReportTests: XCTestCase {

    func testTableFormatContainsHeader() {
        let entries = [
            CrapEntry(name: "foo()", file: "Sources/A.swift", line: 1, complexity: 1, coverage: 100.0, crap: 1.0),
        ]
        let table = formatTable(entries)
        XCTAssertTrue(table.contains("CRAP Report"))
        XCTAssertTrue(table.contains("Function"))
        XCTAssertTrue(table.contains("CC"))
        XCTAssertTrue(table.contains("Cov%"))
        XCTAssertTrue(table.contains("CRAP"))
    }

    func testTableFormatContainsFunctions() {
        let entries = [
            CrapEntry(name: "foo()", file: "Sources/A.swift", line: 1, complexity: 5, coverage: 80.0, crap: 5.04),
        ]
        let table = formatTable(entries)
        XCTAssertTrue(table.contains("foo()"))
        XCTAssertTrue(table.contains("Sources/A.swift:1"))
        XCTAssertTrue(table.contains("80.0%"))
    }

    func testDescendingSort() {
        var entries = [
            CrapEntry(name: "low()", file: "A.swift", line: 1, complexity: 1, coverage: 100.0, crap: 1.0),
            CrapEntry(name: "high()", file: "B.swift", line: 1, complexity: 10, coverage: 0.0, crap: 110.0),
            CrapEntry(name: "mid()", file: "C.swift", line: 1, complexity: 5, coverage: 50.0, crap: 20.625),
        ]
        entries.sort { $0.crap > $1.crap }

        XCTAssertEqual(entries[0].name, "high()")
        XCTAssertEqual(entries[1].name, "mid()")
        XCTAssertEqual(entries[2].name, "low()")
    }

    func testThresholdFiltering() {
        let entries = [
            CrapEntry(name: "low()", file: "A.swift", line: 1, complexity: 1, coverage: 100.0, crap: 1.0),
            CrapEntry(name: "high()", file: "B.swift", line: 1, complexity: 10, coverage: 0.0, crap: 110.0),
            CrapEntry(name: "mid()", file: "C.swift", line: 1, complexity: 5, coverage: 50.0, crap: 20.625),
        ]
        let threshold = 10.0
        let filtered = entries.filter { $0.crap >= threshold }
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.allSatisfy { $0.crap >= threshold })
    }

    func testJSONOutput() {
        let entries = [
            CrapEntry(name: "foo()", file: "A.swift", line: 1, complexity: 3, coverage: 50.0, crap: 4.125),
        ]
        let json = formatJSON(entries)
        XCTAssertTrue(json.contains("\"name\""))
        XCTAssertTrue(json.contains("foo()"))
        XCTAssertTrue(json.contains("\"complexity\""))
        XCTAssertTrue(json.contains("\"crap\""))
    }

    func testEmptyEntries() {
        let table = formatTable([])
        XCTAssertEqual(table, "No functions found.")
    }
}
