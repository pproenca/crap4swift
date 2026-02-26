import XCTest
@testable import crap4swift

final class CrapScoreTests: XCTestCase {

    func testFullCoverageEqualsCc() {
        // CRAP(cc, 100%) = cc² × (1 - 1.0)³ + cc = 0 + cc = cc
        assertCrapEquals(complexity: 1, coverage: 100.0, expected: 1.0)
        assertCrapEquals(complexity: 5, coverage: 100.0, expected: 5.0)
        assertCrapEquals(complexity: 10, coverage: 100.0, expected: 10.0)
    }

    func testZeroCoverage() {
        // CRAP(cc, 0%) = cc² × 1³ + cc = cc² + cc
        assertCrapEquals(complexity: 1, coverage: 0.0, expected: 2.0)
        assertCrapEquals(complexity: 5, coverage: 0.0, expected: 30.0)
        assertCrapEquals(complexity: 10, coverage: 0.0, expected: 110.0)
    }

    func testPartialCoverage() {
        // CRAP(8, 45%) = 64 × (0.55)³ + 8 = 64 × 0.166375 + 8 = 10.648 + 8 = 18.648
        assertCrapEquals(complexity: 8, coverage: 45.0, expected: 18.648, accuracy: 0.01)
    }

    func testComplexity1FullCoverage() {
        // Simplest possible: CC=1, 100% coverage → CRAP = 1
        assertCrapEquals(complexity: 1, coverage: 100.0, expected: 1.0)
    }

    func testHighComplexityLowCoverage() {
        // CC=20, 10% coverage → CRAP = 400 × 0.729 + 20 = 291.6 + 20 = 311.6
        assertCrapEquals(complexity: 20, coverage: 10.0, expected: 311.6, accuracy: 0.1)
    }

    func testFormulaVerification() {
        // CC=5, 100% → 5.0
        assertCrapEquals(complexity: 5, coverage: 100.0, expected: 5.0)
        // CC=5, 0% → 30.0
        assertCrapEquals(complexity: 5, coverage: 0.0, expected: 30.0)
    }

    private func assertCrapEquals(complexity: Int, coverage: Double, expected: Double, accuracy: Double = 0.001) {
        XCTAssertEqual(crapScore(complexity: complexity, coveragePercent: coverage), expected, accuracy: accuracy)
    }
}
