import Foundation

protocol CoverageProvider {
    func coverage(forFile absolutePath: String, startLine: Int, endLine: Int) -> Double?
}

// MARK: - XCResult Coverage

final class XCResultProvider: CoverageProvider {
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

    private struct IndexedFunction {
        let lineNumber: Int
        let coveragePercent: Double
    }

    private struct IndexedFile {
        let fileCoveragePercent: Double
        let functions: [IndexedFunction]
    }

    private let filesByPath: [String: IndexedFile]
    private let candidatePaths: [String]

    init(path: String) throws {
        let data = try Self.runXccov(path: path)
        let report = try JSONDecoder().decode(XCCovReport.self, from: data)
        let indexed = Self.buildIndex(from: report)
        self.filesByPath = indexed
        self.candidatePaths = Array(indexed.keys)
    }

    // Test-friendly initializer
    init(report: XCCovReport) {
        let indexed = Self.buildIndex(from: report)
        self.filesByPath = indexed
        self.candidatePaths = Array(indexed.keys)
    }

    func coverage(forFile absolutePath: String, startLine: Int, endLine: Int) -> Double? {
        let normalizedPath = (absolutePath as NSString).standardizingPath

        guard let indexedFile = indexedFile(for: normalizedPath) else {
            return nil
        }

        if let functionCoverage = functionCoverage(
            in: indexedFile.functions,
            startLine: startLine,
            endLine: endLine
        ) {
            return functionCoverage
        }

        return indexedFile.fileCoveragePercent
    }

    private func indexedFile(for normalizedPath: String) -> IndexedFile? {
        if let exact = filesByPath[normalizedPath] {
            return exact
        }

        if let match = candidatePaths.first(
            where: { normalizedPath.hasSuffix($0) || $0.hasSuffix(normalizedPath) }
        ) {
            return filesByPath[match]
        }

        return nil
    }

    private func functionCoverage(in functions: [IndexedFunction], startLine: Int, endLine: Int) -> Double? {
        guard !functions.isEmpty else {
            return nil
        }

        let startIndex = Self.lowerBound(functions, startLine)
        guard startIndex < functions.count else {
            return nil
        }

        let candidate = functions[startIndex]
        guard candidate.lineNumber <= endLine else {
            return nil
        }

        return candidate.coveragePercent
    }

    private static func lowerBound(_ functions: [IndexedFunction], _ line: Int) -> Int {
        var low = 0
        var high = functions.count

        while low < high {
            let mid = low + (high - low) / 2
            if functions[mid].lineNumber < line {
                low = mid + 1
            } else {
                high = mid
            }
        }

        return low
    }

    private static func buildIndex(from report: XCCovReport) -> [String: IndexedFile] {
        struct MutableIndexedFile {
            var fileCoveragePercent: Double
            var functionCoverageByLine: [Int: Double]
        }

        var mutable: [String: MutableIndexedFile] = [:]

        for target in report.targets {
            for file in target.files {
                let normalizedPath = (file.path as NSString).standardizingPath
                var entry = mutable[normalizedPath] ?? MutableIndexedFile(
                    fileCoveragePercent: file.lineCoverage * 100.0,
                    functionCoverageByLine: [:]
                )

                entry.fileCoveragePercent = max(entry.fileCoveragePercent, file.lineCoverage * 100.0)

                if let functions = file.functions {
                    for function in functions {
                        let coveragePercent = function.lineCoverage * 100.0
                        entry.functionCoverageByLine[function.lineNumber] = max(
                            entry.functionCoverageByLine[function.lineNumber] ?? coveragePercent,
                            coveragePercent
                        )
                    }
                }

                mutable[normalizedPath] = entry
            }
        }

        return mutable.mapValues { entry in
            let functions = entry.functionCoverageByLine
                .map { IndexedFunction(lineNumber: $0.key, coveragePercent: $0.value) }
                .sorted { $0.lineNumber < $1.lineNumber }

            return IndexedFile(
                fileCoveragePercent: entry.fileCoveragePercent,
                functions: functions
            )
        }
    }

    private static func runXccov(path: String) throws -> Data {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["xccov", "view", "--report", "--json", path]
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let outputText = String(data: output, encoding: .utf8) ?? "<non-UTF8 xccov output>"
            throw CoverageError.xccovFailed(status: process.terminationStatus, output: outputText)
        }
        return output
    }
}

// MARK: - LLVM-cov Coverage

final class LLVMCovProvider: CoverageProvider {
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

    private struct FileCoverageIndex {
        let maxLine: Int
        let instrumentedPrefix: [Int]
        let coveredPrefix: [Int]
    }

    private let fileIndexes: [String: FileCoverageIndex]
    private let candidatePaths: [String]

    init(profdata: String, binary: String) throws {
        let data = try Self.runLLVMCov(profdata: profdata, binary: binary)
        let export = try JSONDecoder().decode(LLVMCovExport.self, from: data)
        var indexes: [String: FileCoverageIndex] = [:]

        for entry in export.data {
            for file in entry.files {
                let normalizedPath = (file.filename as NSString).standardizingPath
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
                indexes[normalizedPath] = Self.buildFileIndex(from: segments)
            }
        }

        self.fileIndexes = indexes
        self.candidatePaths = Array(indexes.keys)
    }

    // Test-friendly initializer
    init(fileSegments: [String: [Segment]]) {
        var indexes: [String: FileCoverageIndex] = [:]
        for (fileName, segments) in fileSegments {
            let normalizedPath = (fileName as NSString).standardizingPath
            indexes[normalizedPath] = Self.buildFileIndex(from: segments)
        }
        self.fileIndexes = indexes
        self.candidatePaths = Array(indexes.keys)
    }

    func coverage(forFile absolutePath: String, startLine: Int, endLine: Int) -> Double? {
        let normalizedPath = (absolutePath as NSString).standardizingPath

        guard let fileIndex = fileIndex(for: normalizedPath) else {
            return nil
        }

        guard startLine <= endLine else {
            return nil
        }

        let clampedStartLine = max(startLine, 1)
        let clampedEndLine = min(endLine, fileIndex.maxLine)
        guard clampedStartLine <= clampedEndLine else {
            return nil
        }

        let instrumentedLines = fileIndex.instrumentedPrefix[clampedEndLine]
            - fileIndex.instrumentedPrefix[clampedStartLine - 1]
        guard instrumentedLines > 0 else {
            return nil
        }

        let coveredLines = fileIndex.coveredPrefix[clampedEndLine]
            - fileIndex.coveredPrefix[clampedStartLine - 1]
        return Double(coveredLines) / Double(instrumentedLines) * 100.0
    }

    private func fileIndex(for normalizedPath: String) -> FileCoverageIndex? {
        if let exact = fileIndexes[normalizedPath] {
            return exact
        }

        if let match = candidatePaths.first(
            where: { normalizedPath.hasSuffix($0) || $0.hasSuffix(normalizedPath) }
        ) {
            return fileIndexes[match]
        }

        return nil
    }

    private static func buildFileIndex(from segments: [Segment]) -> FileCoverageIndex {
        guard !segments.isEmpty else {
            return FileCoverageIndex(maxLine: 0, instrumentedPrefix: [0], coveredPrefix: [0])
        }

        let sorted = segments.sorted { ($0.line, $0.column) < ($1.line, $1.column) }

        var instrumentedLines: Set<Int> = []
        var coveredLines: Set<Int> = []

        for index in sorted.indices {
            let segment = sorted[index]
            guard segment.hasCount else {
                continue
            }

            let nextLine = (index + 1 < sorted.count) ? sorted[index + 1].line : (segment.line + 1)
            let startLine = max(segment.line, 1)
            let endLine = max(nextLine, startLine + 1)

            for line in startLine..<endLine {
                instrumentedLines.insert(line)
                if segment.count > 0 {
                    coveredLines.insert(line)
                }
            }
        }

        guard let maxLine = instrumentedLines.max() else {
            return FileCoverageIndex(maxLine: 0, instrumentedPrefix: [0], coveredPrefix: [0])
        }

        var instrumentedPrefix = Array(repeating: 0, count: maxLine + 1)
        var coveredPrefix = Array(repeating: 0, count: maxLine + 1)

        for line in 1...maxLine {
            instrumentedPrefix[line] = instrumentedPrefix[line - 1] + (instrumentedLines.contains(line) ? 1 : 0)
            coveredPrefix[line] = coveredPrefix[line - 1] + (coveredLines.contains(line) ? 1 : 0)
        }

        return FileCoverageIndex(
            maxLine: maxLine,
            instrumentedPrefix: instrumentedPrefix,
            coveredPrefix: coveredPrefix
        )
    }

    private static func runLLVMCov(profdata: String, binary: String) throws -> Data {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["llvm-cov", "export", "-instr-profile=\(profdata)", binary, "--format=text"]
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let outputText = String(data: output, encoding: .utf8) ?? "<non-UTF8 llvm-cov output>"
            throw CoverageError.llvmCovFailed(status: process.terminationStatus, output: outputText)
        }
        return output
    }
}

// MARK: - Errors

enum CoverageError: Error, CustomStringConvertible {
    case xccovFailed(status: Int32, output: String)
    case llvmCovFailed(status: Int32, output: String)

    var description: String {
        switch self {
        case .xccovFailed(let status, let output):
            if output.isEmpty {
                return "xcrun xccov failed with exit code \(status)"
            }
            return "xcrun xccov failed with exit code \(status): \(output)"
        case .llvmCovFailed(let status, let output):
            if output.isEmpty {
                return "xcrun llvm-cov failed with exit code \(status)"
            }
            return "xcrun llvm-cov failed with exit code \(status): \(output)"
        }
    }
}
