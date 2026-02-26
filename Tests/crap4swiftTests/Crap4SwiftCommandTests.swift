import Foundation
import XCTest
@testable import crap4swift

final class Crap4SwiftCommandTests: XCTestCase {
    func testFindSwiftFilesRecursively() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let rootSwiftFile = tempDir.appendingPathComponent("Root.swift")
        let nestedDirectory = tempDir.appendingPathComponent("Nested/Deeper", isDirectory: true)
        let nestedSwiftFile = nestedDirectory.appendingPathComponent("Feature.swift")
        let ignoredFile = nestedDirectory.appendingPathComponent("README.md")

        try FileManager.default.createDirectory(at: nestedDirectory, withIntermediateDirectories: true)
        try "func root() {}".write(to: rootSwiftFile, atomically: true, encoding: .utf8)
        try "func nested() {}".write(to: nestedSwiftFile, atomically: true, encoding: .utf8)
        try "# ignore".write(to: ignoredFile, atomically: true, encoding: .utf8)

        let command = Crap4Swift()
        let swiftFiles = command.findSwiftFiles(in: tempDir.path, excluding: [])
        let normalizedFiles = swiftFiles
            .map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().path }
            .sorted()
        let expectedFiles = [nestedSwiftFile, rootSwiftFile]
            .map { $0.resolvingSymlinksInPath().path }
            .sorted()

        XCTAssertEqual(normalizedFiles, expectedFiles)
    }

    func testResolvedCoverageDefaultsToHundredWithoutCoverageProvider() {
        let command = Crap4Swift()

        let coverage = command.resolvedCoverage(
            forFile: "/tmp/File.swift",
            startLine: 1,
            endLine: 10,
            using: nil
        )

        XCTAssertEqual(coverage, 100.0)
    }

    func testResolvedCoverageDefaultsToZeroWhenProviderHasNoDataForFile() {
        let command = Crap4Swift()
        let provider = StubCoverageProvider(coverage: nil)

        let coverage = command.resolvedCoverage(
            forFile: "/tmp/File.swift",
            startLine: 10,
            endLine: 20,
            using: provider
        )

        XCTAssertEqual(coverage, 0.0)
    }

    func testResolvedCoverageUsesProviderValueWhenAvailable() {
        let command = Crap4Swift()
        let provider = StubCoverageProvider(coverage: 37.5)

        let coverage = command.resolvedCoverage(
            forFile: "/tmp/File.swift",
            startLine: 10,
            endLine: 20,
            using: provider
        )

        XCTAssertEqual(coverage, 37.5)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("crap4swift-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
}

private final class StubCoverageProvider: CoverageProvider {
    private let coverage: Double?

    init(coverage: Double?) {
        self.coverage = coverage
    }

    func coverage(forFile absolutePath: String, startLine: Int, endLine: Int) -> Double? {
        coverage
    }
}
