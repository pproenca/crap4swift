import Foundation

protocol CoverageProvider {
    func coverage(forFile absolutePath: String, startLine: Int, endLine: Int) -> Double?
}

// MARK: - XCResult Coverage

class XCResultProvider: CoverageProvider {
    struct XCCovReport: Decodable {
        let targets: [Target]

        struct Target: Decodable {
            let files: [File]
        }

        struct File: Decodable {
            let path: String
            let lineCoverage: Double
            let functions: [Function]?
        }

        struct Function: Decodable {
            let name: String
            let lineCoverage: Double
            let lineNumber: Int
            let executionCount: Int
        }
    }

    private let report: XCCovReport

    init(path: String) throws {
        let data = try Self.runXccov(path: path)
        self.report = try JSONDecoder().decode(XCCovReport.self, from: data)
    }

    // Test-friendly initializer
    init(report: XCCovReport) {
        self.report = report
    }

    func coverage(forFile absolutePath: String, startLine: Int, endLine: Int) -> Double? {
        let normalizedPath = (absolutePath as NSString).standardizingPath

        for target in report.targets {
            for file in target.files {
                let filePath = (file.path as NSString).standardizingPath
                guard filePath == normalizedPath || normalizedPath.hasSuffix(file.path) || file.path.hasSuffix(normalizedPath) else {
                    continue
                }

                // Try function-level match first
                if let functions = file.functions {
                    for fn in functions {
                        if fn.lineNumber >= startLine && fn.lineNumber <= endLine {
                            return fn.lineCoverage * 100.0
                        }
                    }
                }

                // Fall back to file-level coverage
                return file.lineCoverage * 100.0
            }
        }
        return nil
    }

    private static func runXccov(path: String) throws -> Data {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["xccov", "view", "--report", "--json", path]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw CoverageError.xccovFailed(status: process.terminationStatus)
        }
        return pipe.fileHandleForReading.readDataToEndOfFile()
    }
}

// MARK: - LLVM-cov Coverage

class LLVMCovProvider: CoverageProvider {
    struct LLVMCovExport: Decodable {
        let data: [DataEntry]

        struct DataEntry: Decodable {
            let files: [File]
        }

        struct File: Decodable {
            let filename: String
            let segments: [[SegmentValue]]
        }
    }

    // Segments are heterogeneous arrays: [Int, Int, Int, Bool, Bool]
    enum SegmentValue: Decodable {
        case int(Int)
        case bool(Bool)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let intVal = try? container.decode(Int.self) {
                self = .int(intVal)
            } else if let boolVal = try? container.decode(Bool.self) {
                self = .bool(boolVal)
            } else {
                self = .int(0)
            }
        }

        var intValue: Int {
            switch self {
            case .int(let v): return v
            case .bool(let v): return v ? 1 : 0
            }
        }
    }

    struct Segment {
        let line: Int
        let column: Int
        let count: Int
        let hasCount: Bool
        let isRegionEntry: Bool
    }

    private let fileSegments: [String: [Segment]]

    init(profdata: String, binary: String) throws {
        let data = try Self.runLLVMCov(profdata: profdata, binary: binary)
        let export = try JSONDecoder().decode(LLVMCovExport.self, from: data)
        var mapping: [String: [Segment]] = [:]
        for entry in export.data {
            for file in entry.files {
                let segments = file.segments.compactMap { raw -> Segment? in
                    guard raw.count >= 5 else { return nil }
                    return Segment(
                        line: raw[0].intValue,
                        column: raw[1].intValue,
                        count: raw[2].intValue,
                        hasCount: raw[3].intValue != 0,
                        isRegionEntry: raw[4].intValue != 0
                    )
                }
                mapping[file.filename] = segments
            }
        }
        self.fileSegments = mapping
    }

    // Test-friendly initializer
    init(fileSegments: [String: [Segment]]) {
        self.fileSegments = fileSegments
    }

    func coverage(forFile absolutePath: String, startLine: Int, endLine: Int) -> Double? {
        let normalizedPath = (absolutePath as NSString).standardizingPath

        // Find matching file
        let segments: [Segment]
        if let exact = fileSegments[normalizedPath] {
            segments = exact
        } else if let match = fileSegments.first(where: { normalizedPath.hasSuffix($0.key) || $0.key.hasSuffix(normalizedPath) }) {
            segments = match.value
        } else {
            return nil
        }

        // Build line-level coverage from segments
        var lineCounts: [Int: Int] = [:]
        var lineInstrumented: Set<Int> = []
        let sorted = segments.sorted { ($0.line, $0.column) < ($1.line, $1.column) }

        for i in 0..<sorted.count {
            let seg = sorted[i]
            guard seg.hasCount else { continue }
            let nextLine = (i + 1 < sorted.count) ? sorted[i + 1].line : endLine + 1
            let regionEnd = min(nextLine, endLine + 1)
            for line in seg.line..<regionEnd {
                if line >= startLine && line <= endLine {
                    lineInstrumented.insert(line)
                    lineCounts[line] = max(lineCounts[line] ?? 0, seg.count)
                }
            }
        }

        guard !lineInstrumented.isEmpty else { return nil }

        let coveredLines = lineInstrumented.filter { (lineCounts[$0] ?? 0) > 0 }.count
        return Double(coveredLines) / Double(lineInstrumented.count) * 100.0
    }

    private static func runLLVMCov(profdata: String, binary: String) throws -> Data {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["llvm-cov", "export", "-instr-profile=\(profdata)", binary, "--format=text"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw CoverageError.llvmCovFailed(status: process.terminationStatus)
        }
        return pipe.fileHandleForReading.readDataToEndOfFile()
    }
}

// MARK: - Errors

enum CoverageError: Error, CustomStringConvertible {
    case xccovFailed(status: Int32)
    case llvmCovFailed(status: Int32)

    var description: String {
        switch self {
        case .xccovFailed(let status):
            return "xcrun xccov failed with exit code \(status)"
        case .llvmCovFailed(let status):
            return "xcrun llvm-cov failed with exit code \(status)"
        }
    }
}
