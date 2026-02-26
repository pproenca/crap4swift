import XCTest
@testable import crap4swift

final class CoverageTests: XCTestCase {

    // MARK: - XCResult Provider Tests

    func testXCResultFunctionLevelCoverage() {
        let report = XCResultProvider.XCCovReport(
            targets: [
                .init(files: [
                    .init(
                        path: "/project/Sources/MyApp/Logic.swift",
                        lineCoverage: 0.5,
                        functions: [
                            .init(name: "doSomething()", lineCoverage: 0.8, lineNumber: 10, executionCount: 5),
                            .init(name: "doOther()", lineCoverage: 0.3, lineNumber: 25, executionCount: 2),
                        ]
                    )
                ])
            ]
        )
        let provider = XCResultProvider(report: report)

        // Function-level match (line 10 is within 10-20 range)
        let cov = provider.coverage(forFile: "/project/Sources/MyApp/Logic.swift", startLine: 10, endLine: 20)
        XCTAssertEqual(cov, 80.0)
    }

    func testXCResultFileLevelFallback() {
        let report = XCResultProvider.XCCovReport(
            targets: [
                .init(files: [
                    .init(
                        path: "/project/Sources/MyApp/Logic.swift",
                        lineCoverage: 0.65,
                        functions: nil
                    )
                ])
            ]
        )
        let provider = XCResultProvider(report: report)

        let cov = provider.coverage(forFile: "/project/Sources/MyApp/Logic.swift", startLine: 1, endLine: 50)
        XCTAssertEqual(cov, 65.0)
    }

    func testXCResultMissingFunctionEntryInFunctionIndexedFileDefaultsToZero() {
        let report = XCResultProvider.XCCovReport(
            targets: [
                .init(files: [
                    .init(
                        path: "/project/Sources/MyApp/Logic.swift",
                        lineCoverage: 0.65,
                        functions: [
                            .init(name: "covered()", lineCoverage: 1.0, lineNumber: 10, executionCount: 3),
                        ]
                    )
                ])
            ]
        )
        let provider = XCResultProvider(report: report)

        let cov = provider.coverage(forFile: "/project/Sources/MyApp/Logic.swift", startLine: 30, endLine: 40)
        XCTAssertEqual(cov, 0.0)
    }

    func testXCResultFileWithNoCoverageReturnsZero() {
        let report = XCResultProvider.XCCovReport(
            targets: [
                .init(files: [
                    .init(
                        path: "/project/Sources/MyApp/Untested.swift",
                        lineCoverage: 0.0,
                        functions: nil
                    )
                ])
            ]
        )
        let provider = XCResultProvider(report: report)

        let cov = provider.coverage(forFile: "/project/Sources/MyApp/Untested.swift", startLine: 1, endLine: 50)
        XCTAssertEqual(cov, 0.0)
    }

    func testXCResultNoMatch() {
        let report = XCResultProvider.XCCovReport(
            targets: [
                .init(files: [
                    .init(path: "/project/Other.swift", lineCoverage: 1.0, functions: nil)
                ])
            ]
        )
        let provider = XCResultProvider(report: report)

        let cov = provider.coverage(forFile: "/project/Sources/MyApp/Logic.swift", startLine: 1, endLine: 10)
        XCTAssertNil(cov)
    }

    func testXCResultAmbiguousSuffixMatchPrefersMostSpecificPath() {
        let report = XCResultProvider.XCCovReport(
            targets: [
                .init(files: [
                    .init(path: "/var/folders/x/File.swift", lineCoverage: 0.10, functions: nil),
                    .init(path: "/private/var/folders/x/File.swift", lineCoverage: 0.90, functions: nil),
                ])
            ]
        )
        let provider = XCResultProvider(report: report)

        let cov = provider.coverage(
            forFile: "/worktree/symlink/private/var/folders/x/File.swift",
            startLine: 1,
            endLine: 10
        )
        XCTAssertEqual(cov, 90.0)
    }

    // MARK: - LLVM-cov Provider Tests

    func testLLVMCovSegmentCoverage() {
        // Segments: [line, col, count, hasCount, isRegionEntry]
        let segments: [LLVMCovProvider.Segment] = [
            .init(line: 1, column: 1, count: 5, hasCount: true, isRegionEntry: true),
            .init(line: 3, column: 1, count: 0, hasCount: true, isRegionEntry: true),
            .init(line: 5, column: 1, count: 3, hasCount: true, isRegionEntry: true),
            .init(line: 7, column: 1, count: 0, hasCount: false, isRegionEntry: false),
        ]
        let provider = LLVMCovProvider(fileSegments: ["/project/File.swift": segments])

        // Lines 1-6: lines 1,2 covered (count=5), lines 3,4 uncovered (count=0), lines 5,6 covered (count=3)
        // 4 covered out of 6 instrumented = 66.67%
        let cov = provider.coverage(forFile: "/project/File.swift", startLine: 1, endLine: 6)
        XCTAssertNotNil(cov)
        XCTAssertEqual(cov!, 66.666, accuracy: 0.01)
    }

    func testLLVMCovFullCoverage() {
        let segments: [LLVMCovProvider.Segment] = [
            .init(line: 1, column: 1, count: 10, hasCount: true, isRegionEntry: true),
            .init(line: 10, column: 1, count: 0, hasCount: false, isRegionEntry: false),
        ]
        let provider = LLVMCovProvider(fileSegments: ["/project/File.swift": segments])

        let cov = provider.coverage(forFile: "/project/File.swift", startLine: 1, endLine: 5)
        XCTAssertEqual(cov, 100.0)
    }

    func testLLVMCovNoMatch() {
        let provider = LLVMCovProvider(fileSegments: [:])
        let cov = provider.coverage(forFile: "/project/File.swift", startLine: 1, endLine: 10)
        XCTAssertNil(cov)
    }

    func testLLVMCovRangeCoverage() {
        // Only check lines 3-4 in a file with varied coverage
        let segments: [LLVMCovProvider.Segment] = [
            .init(line: 1, column: 1, count: 5, hasCount: true, isRegionEntry: true),
            .init(line: 3, column: 1, count: 0, hasCount: true, isRegionEntry: true),
            .init(line: 5, column: 1, count: 3, hasCount: true, isRegionEntry: true),
        ]
        let provider = LLVMCovProvider(fileSegments: ["/project/File.swift": segments])

        // Lines 3-4: both have count=0 → 0% coverage
        let cov = provider.coverage(forFile: "/project/File.swift", startLine: 3, endLine: 4)
        XCTAssertEqual(cov, 0.0)
    }

    func testLLVMCovAmbiguousSuffixMatchPrefersMostSpecificPath() {
        let lowCoverageSegments: [LLVMCovProvider.Segment] = [
            .init(line: 1, column: 1, count: 0, hasCount: true, isRegionEntry: true),
            .init(line: 3, column: 1, count: 0, hasCount: false, isRegionEntry: false),
        ]
        let highCoverageSegments: [LLVMCovProvider.Segment] = [
            .init(line: 1, column: 1, count: 3, hasCount: true, isRegionEntry: true),
            .init(line: 3, column: 1, count: 0, hasCount: false, isRegionEntry: false),
        ]
        let provider = LLVMCovProvider(fileSegments: [
            "/var/folders/x/File.swift": lowCoverageSegments,
            "/private/var/folders/x/File.swift": highCoverageSegments,
        ])

        let cov = provider.coverage(
            forFile: "/worktree/symlink/private/var/folders/x/File.swift",
            startLine: 1,
            endLine: 2
        )
        XCTAssertEqual(cov, 100.0)
    }
}
