import ArgumentParser
import Foundation
import SwiftParser
import SwiftSyntax

@main
struct Crap4Swift: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Compute CRAP (Change Risk Anti-Pattern) scores for Swift code"
    )

    @Option(name: .long, help: "Source directory to analyze")
    var sourceDir: String = "Sources"

    @Option(name: .long, help: "Path to .xcresult bundle for coverage data")
    var xcresult: String?

    @Option(name: .long, help: "Path to .profdata file for LLVM coverage")
    var profdata: String?

    @Option(name: .long, help: "Path to binary for LLVM coverage")
    var binary: String?

    @Option(name: .long, help: "Only show functions with CRAP score above threshold")
    var threshold: Double?

    @Option(name: .long, help: "Filter by function name pattern (repeatable)")
    var filter: [String] = []

    @Option(name: .long, help: "Exclude files whose path contains this substring (repeatable)")
    var excludePath: [String] = []

    @Flag(name: .long, help: "Exclude common generated file paths (.build, GeneratedSources, Generated, Sourcery)")
    var excludeGenerated: Bool = false

    @Flag(name: .long, help: "Output as JSON")
    var json: Bool = false

    mutating func run() throws {
        let swiftFiles = findSwiftFiles(in: sourceDir, excluding: exclusionPatterns())
        guard !swiftFiles.isEmpty else {
            print("No .swift files found in '\(sourceDir)'")
            return
        }

        // Set up coverage provider
        let coverageProvider: CoverageProvider?
        if let xcresultPath = xcresult {
            coverageProvider = try XCResultProvider(path: xcresultPath)
        } else if let profdataPath = profdata, let binaryPath = binary {
            coverageProvider = try LLVMCovProvider(profdata: profdataPath, binary: binaryPath)
        } else {
            coverageProvider = nil
        }

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
                let cov = coverageProvider?.coverage(
                    forFile: absolutePath,
                    startLine: funcInfo.startLine,
                    endLine: funcInfo.endLine
                ) ?? 100.0

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

    private func findSwiftFiles(in directory: String, excluding patterns: [String]) -> [String] {
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
