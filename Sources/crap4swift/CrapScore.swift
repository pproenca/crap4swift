import Foundation

struct CrapEntry: Codable {
    let name: String
    let file: String
    let line: Int
    let complexity: Int
    let coverage: Double   // 0.0 - 100.0
    let crap: Double
}

func crapScore(complexity: Int, coveragePercent: Double) -> Double {
    let cc = Double(complexity)
    let uncov = 1.0 - (coveragePercent / 100.0)
    return cc * cc * uncov * uncov * uncov + cc
}
