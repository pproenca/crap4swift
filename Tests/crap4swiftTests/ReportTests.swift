import CustomDump
import Testing
@testable import crap4swift

@Suite("Report")
struct ReportTests {
    @Test("Table format contains header columns")
    func tableFormatContainsHeader() {
        let entries = [
            makeEntry(name: "foo()", file: "Sources/A.swift", line: 1, complexity: 1, coverage: 100.0, crap: 1.0)
        ]
        let table = formatTable(entries)
        #expect(table.contains("CRAP Report"))
        #expect(table.contains("Function"))
        #expect(table.contains("CC"))
        #expect(table.contains("Cov%"))
        #expect(table.contains("CRAP"))
    }

    @Test("Table format contains function values")
    func tableFormatContainsFunctions() {
        let entries = [
            makeEntry(name: "foo()", file: "Sources/A.swift", line: 1, complexity: 5, coverage: 80.0, crap: 5.04)
        ]
        let table = formatTable(entries)
        #expect(table.contains("foo()"))
        #expect(table.contains("Sources/A.swift:1"))
        #expect(table.contains("80.0%"))
    }

    @Test("Sort order is descending by CRAP")
    func descendingSort() {
        var entries = [
            makeEntry(name: "low()", file: "A.swift", line: 1, complexity: 1, coverage: 100.0, crap: 1.0),
            makeEntry(name: "high()", file: "B.swift", line: 1, complexity: 10, coverage: 0.0, crap: 110.0),
            makeEntry(name: "mid()", file: "C.swift", line: 1, complexity: 5, coverage: 50.0, crap: 20.625),
        ]
        entries.sort { $0.crap > $1.crap }

        expectNoDifference(entries.map(\.name), ["high()", "mid()", "low()"])
    }

    @Test("Threshold filtering keeps only entries at or above threshold")
    func thresholdFiltering() {
        let entries = [
            makeEntry(name: "low()", file: "A.swift", line: 1, complexity: 1, coverage: 100.0, crap: 1.0),
            makeEntry(name: "high()", file: "B.swift", line: 1, complexity: 10, coverage: 0.0, crap: 110.0),
            makeEntry(name: "mid()", file: "C.swift", line: 1, complexity: 5, coverage: 50.0, crap: 20.625),
        ]
        let threshold = 10.0
        let filtered = entries.filter { $0.crap >= threshold }
        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.crap >= threshold })
    }

    @Test("JSON output contains expected keys and values")
    func jsonOutput() {
        let entries = [
            makeEntry(name: "foo()", file: "A.swift", line: 1, complexity: 3, coverage: 50.0, crap: 4.125),
        ]
        let json = formatJSON(entries)
        #expect(json.contains("\"name\""))
        #expect(json.contains("foo()"))
        #expect(json.contains("\"complexity\""))
        #expect(json.contains("\"crap\""))
    }

    @Test("Empty entries format to no-functions message")
    func emptyEntries() {
        let table = formatTable([])
        expectNoDifference(table, "No functions found.")
    }

    private func makeEntry(
        name: String,
        file: String,
        line: Int,
        complexity: Int,
        coverage: Double,
        crap: Double
    ) -> CrapEntry {
        CrapEntry(
            name: name,
            file: file,
            line: line,
            complexity: complexity,
            coverage: coverage,
            crap: crap
        )
    }
}
