import XCTest
@testable import crap4swift

final class CrapScoreTests: XCTestCase {

    func testFullCoverageEqualsCc() {
        // CRAP(cc, 100%) = cc² × (1 - 1.0)³ + cc = 0 + cc = cc
        XCTAssertEqual(crapScore(complexity: 1, coveragePercent: 100.0), 1.0, accuracy: 0.001)
        XCTAssertEqual(crapScore(complexity: 5, coveragePercent: 100.0), 5.0, accuracy: 0.001)
        XCTAssertEqual(crapScore(complexity: 10, coveragePercent: 100.0), 10.0, accuracy: 0.001)
    }

    func testZeroCoverage() {
        // CRAP(cc, 0%) = cc² × 1³ + cc = cc² + cc
        XCTAssertEqual(crapScore(complexity: 1, coveragePercent: 0.0), 2.0, accuracy: 0.001)
        XCTAssertEqual(crapScore(complexity: 5, coveragePercent: 0.0), 30.0, accuracy: 0.001)
        XCTAssertEqual(crapScore(complexity: 10, coveragePercent: 0.0), 110.0, accuracy: 0.001)
    }

    func testPartialCoverage() {
        // CRAP(8, 45%) = 64 × (0.55)³ + 8 = 64 × 0.166375 + 8 = 10.648 + 8 = 18.648
        XCTAssertEqual(crapScore(complexity: 8, coveragePercent: 45.0), 18.648, accuracy: 0.01)
    }

    func testComplexity1FullCoverage() {
        // Simplest possible: CC=1, 100% coverage → CRAP = 1
        XCTAssertEqual(crapScore(complexity: 1, coveragePercent: 100.0), 1.0, accuracy: 0.001)
    }

    func testHighComplexityLowCoverage() {
        // CC=20, 10% coverage → CRAP = 400 × 0.729 + 20 = 291.6 + 20 = 311.6
        XCTAssertEqual(crapScore(complexity: 20, coveragePercent: 10.0), 311.6, accuracy: 0.1)
    }

    func testFormulaVerification() {
        // CC=5, 100% → 5.0
        XCTAssertEqual(crapScore(complexity: 5, coveragePercent: 100.0), 5.0, accuracy: 0.001)
        // CC=5, 0% → 30.0
        XCTAssertEqual(crapScore(complexity: 5, coveragePercent: 0.0), 30.0, accuracy: 0.001)
    }
}
