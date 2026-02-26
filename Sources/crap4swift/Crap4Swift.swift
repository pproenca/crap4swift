import ArgumentParser
import Foundation
import SwiftParser
import SwiftSyntax

@main
struct Crap4Swift: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "crap4swift",
        abstract: "Compute CRAP (Change Risk Anti-Pattern) scores for Swift code"
    )

    @Argument(
        help: ArgumentHelp(
            "Directories to analyze. Defaults to the current directory.",
            valueName: "path"
        ),
        completion: .directory
    )
    var paths: [String] = []

    // Backward-compatible alias for previous CLI versions.
    @Option(name: .customLong("source-dir"), help: .hidden)
    var sourceDir: String? = nil

    @Option(name: [.customShort("x"), .long], help: "Path to .xcresult bundle for coverage data")
    var xcresult: String? = nil

    @Option(name: [.customShort("p"), .long], help: "Path to .profdata file for LLVM coverage")
    var profdata: String? = nil

    @Option(name: [.customShort("b"), .long], help: "Path to binary for LLVM coverage")
    var binary: String? = nil

    @Option(name: [.customShort("t"), .long], help: "Only show functions with CRAP score above threshold")
    var threshold: Double? = nil

    @Option(name: [.customShort("f"), .long], help: "Filter by function name pattern (repeatable)")
    var filter: [String] = []

    @Option(name: [.customShort("e"), .long], help: "Exclude files whose path contains this substring (repeatable)")
    var excludePath: [String] = []

    @Flag(name: [.customShort("g"), .long], help: "Exclude common generated file paths (.build, GeneratedSources, Generated, Sourcery)")
    var excludeGenerated: Bool = false

    @Flag(name: [.customShort("j"), .long], help: "Output as JSON")
    var json: Bool = false

    mutating func validate() throws {
        if sourceDir != nil && !paths.isEmpty {
            throw ValidationError("Use either path operands or --source-dir, not both.")
        }

        if xcresult != nil && (profdata != nil || binary != nil) {
            throw ValidationError("Use either --xcresult or --profdata/--binary, not both.")
        }
        if (profdata == nil) != (binary == nil) {
            throw ValidationError("--profdata and --binary must be provided together.")
        }

        if let threshold {
            if !threshold.isFinite {
                throw ValidationError("--threshold must be a finite number.")
            }
            if threshold < 0 {
                throw ValidationError("--threshold must be greater than or equal to 0.")
            }
        }

        if excludePath.contains(where: \.isEmpty) {
            throw ValidationError("--exclude-path cannot be empty.")
        }

        try validateDirectories(sourceDirectories())
        try validateCoveragePaths()
    }

    mutating func run() throws {
        var swiftFileSet: Set<String> = []
        for directory in sourceDirectories() {
            swiftFileSet.formUnion(findSwiftFiles(in: directory, excluding: exclusionPatterns()))
        }
        let swiftFiles = swiftFileSet.sorted()

        guard !swiftFiles.isEmpty else {
            throw ValidationError("No .swift files found in the selected path(s).")
        }

        let coverageProvider = try makeCoverageProvider()

        var entries: [CrapEntry] = []

        for file in swiftFiles {
            let source = try String(contentsOfFile: file, encoding: .utf8)
            let tree = Parser.parse(source: source)
            let converter = SourceLocationConverter(fileName: file, tree: tree)

            let finder = FunctionFinder(converter: converter)
            finder.walk(tree)

            for funcInfo in finder.functions {
                let complexityVisitor = ComplexityVisitor(viewMode: .sourceAccurate)
                complexityVisitor.walk(funcInfo.node)
                let cc = complexityVisitor.complexity

                let absolutePath = URL(fileURLWithPath: file).standardizedFileURL.path
                let cov = resolvedCoverage(
                    forFile: absolutePath,
                    startLine: funcInfo.startLine,
                    endLine: funcInfo.endLine,
                    using: coverageProvider
                )

                let score = crapScore(complexity: cc, coveragePercent: cov)
                entries.append(CrapEntry(
                    name: funcInfo.name,
                    file: file,
                    line: funcInfo.startLine,
                    complexity: cc,
                    coverage: cov,
                    crap: score
                ))
            }
        }

        // Apply filters
        if !filter.isEmpty {
            entries = entries.filter { entry in
                filter.contains { entry.name.contains($0) }
            }
        }
        if let threshold = threshold {
            entries = entries.filter { $0.crap >= threshold }
        }

        // Sort by CRAP score descending
        entries.sort { $0.crap > $1.crap }

        // Output
        if json {
            print(formatJSON(entries))
        } else {
            print(formatTable(entries))
        }
    }

    func sourceDirectories() -> [String] {
        let candidates: [String]
        if let sourceDir {
            candidates = [sourceDir]
        } else if !paths.isEmpty {
            candidates = paths
        } else {
            candidates = ["."]
        }
        return uniqueNormalizedPaths(candidates)
    }

    private func exclusionPatterns() -> [String] {
        var patterns = excludePath
        if excludeGenerated {
            patterns.append(contentsOf: [
                "/.build/",
                "/GeneratedSources/",
                "/Generated/",
                "/DerivedSources/",
                "/Sourcery/",
                ".generated.swift",
                "GeneratedTypes.swift",
            ])
        }
        return patterns.map { $0.lowercased() }
    }

    private func validateDirectories(_ directories: [String]) throws {
        let fileManager = FileManager.default
        for directory in directories {
            var isDirectory: ObjCBool = false
            let exists = fileManager.fileExists(atPath: directory, isDirectory: &isDirectory)
            if !exists || !isDirectory.boolValue {
                throw ValidationError("Path is not a directory: \(directory)")
            }
        }
    }

    private func validateCoveragePaths() throws {
        if let xcresult {
            try validatePathExists(xcresult, optionName: "--xcresult")
        }
        if let profdata {
            try validatePathExists(profdata, optionName: "--profdata")
        }
        if let binary {
            try validatePathExists(binary, optionName: "--binary")
        }
    }

    private func validatePathExists(_ path: String, optionName: String) throws {
        if !FileManager.default.fileExists(atPath: path) {
            throw ValidationError("Path for \(optionName) does not exist: \(path)")
        }
    }

    private func uniqueNormalizedPaths(_ paths: [String]) -> [String] {
        var seen: Set<String> = []
        var unique: [String] = []
        for path in paths {
            let normalized = URL(fileURLWithPath: path).standardizedFileURL.path
            if seen.insert(normalized).inserted {
                unique.append(normalized)
            }
        }
        return unique
    }

    private func makeCoverageProvider() throws -> CoverageProvider? {
        if let xcresultPath = xcresult {
            return try XCResultProvider(path: xcresultPath)
        }

        if let profdataPath = profdata, let binaryPath = binary {
            return try LLVMCovProvider(profdata: profdataPath, binary: binaryPath)
        }

        return nil
    }

    func resolvedCoverage(
        forFile absolutePath: String,
        startLine: Int,
        endLine: Int,
        using coverageProvider: CoverageProvider?
    ) -> Double {
        guard let coverageProvider else {
            return 100.0
        }

        return coverageProvider.coverage(
            forFile: absolutePath,
            startLine: startLine,
            endLine: endLine
        ) ?? 0.0
    }

    func findSwiftFiles(in directory: String, excluding patterns: [String]) -> [String] {
        let fm = FileManager.default
        let url = URL(fileURLWithPath: directory).standardizedFileURL
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsPackageDescendants, .skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [String] = []
        for case let fileURL as URL in enumerator {
            let path = fileURL.path
            let lowercasedPath = path.lowercased()

            if shouldExclude(lowercasedPath: lowercasedPath, patterns: patterns) {
                let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
                if isDirectory {
                    enumerator.skipDescendants()
                }
                continue
            }

            if fileURL.pathExtension == "swift" {
                files.append(path)
            }
        }
        return files.sorted()
    }

    private func shouldExclude(lowercasedPath: String, patterns: [String]) -> Bool {
        patterns.contains { lowercasedPath.contains($0) }
    }
}
