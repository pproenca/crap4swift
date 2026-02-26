import Foundation
import XCTest
@testable import crap4swift

final class Crap4SwiftCommandTests: XCTestCase {
    func testSourceDirectoriesDefaultsToCurrentDirectory() throws {
        let command = try parseCommand([])
        let expected = URL(fileURLWithPath: ".").standardizedFileURL.path

        XCTAssertEqual(command.sourceDirectories(), [expected])
    }

    func testSourceDirectoriesUsesPositionalPaths() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let first = tempDir.appendingPathComponent("src-a", isDirectory: true)
        let second = tempDir.appendingPathComponent("src-b", isDirectory: true)
        try FileManager.default.createDirectory(at: first, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: second, withIntermediateDirectories: true)

        let command = try parseCommand([first.path, second.path])

        XCTAssertEqual(command.sourceDirectories(), [first.path, second.path])
    }

    func testSourceDirectoriesUsesLegacySourceDirOption() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let legacyPathURL = tempDir.appendingPathComponent("legacy-src", isDirectory: true)
        try FileManager.default.createDirectory(at: legacyPathURL, withIntermediateDirectories: true)
        let legacyPath = legacyPathURL.path
        let command = try parseCommand(["--source-dir", legacyPath])

        XCTAssertEqual(command.sourceDirectories(), [legacyPath])
    }

    func testValidateRejectsMixedSourceDirAndPositionalPaths() {
        XCTAssertThrowsError(try parseCommand(["--source-dir", ".", "Sources"]))
    }

    func testValidateRejectsProfdataWithoutBinary() {
        XCTAssertThrowsError(try parseCommand(["--profdata", "coverage.profdata"]))
    }

    func testValidateRejectsNegativeThreshold() {
        XCTAssertThrowsError(try parseCommand(["--threshold", "-0.1"]))
    }

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

        let command = try parseCommand([])
        let swiftFiles = command.findSwiftFiles(in: tempDir.path, excluding: [])
        let normalizedFiles = swiftFiles
            .map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().path }
            .sorted()
        let expectedFiles = [nestedSwiftFile, rootSwiftFile]
            .map { $0.resolvingSymlinksInPath().path }
            .sorted()

        XCTAssertEqual(normalizedFiles, expectedFiles)
    }

    func testResolvedCoverageDefaultsToHundredWithoutCoverageProvider() throws {
        try assertResolvedCoverage(using: nil, expected: 100.0, startLine: 1, endLine: 10)
    }

    func testResolvedCoverageDefaultsToZeroWhenProviderHasNoDataForFile() throws {
        let provider = StubCoverageProvider(coverage: nil)
        try assertResolvedCoverage(using: provider, expected: 0.0, startLine: 10, endLine: 20)
    }

    func testResolvedCoverageUsesProviderValueWhenAvailable() throws {
        let provider = StubCoverageProvider(coverage: 37.5)
        try assertResolvedCoverage(using: provider, expected: 37.5, startLine: 10, endLine: 20)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("crap4swift-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    private func assertResolvedCoverage(
        using provider: CoverageProvider?,
        expected: Double,
        startLine: Int,
        endLine: Int
    ) throws {
        let command = try parseCommand([])
        let coverage = command.resolvedCoverage(
            forFile: "/tmp/File.swift",
            startLine: startLine,
            endLine: endLine,
            using: provider
        )
        XCTAssertEqual(coverage, expected)
    }

    private func parseCommand(_ arguments: [String]) throws -> Crap4Swift {
        let parsed = try Crap4Swift.parseAsRoot(arguments)
        guard let command = parsed as? Crap4Swift else {
            throw TestError.unexpectedCommandType
        }
        return command
    }
}

private enum TestError: Error {
    case unexpectedCommandType
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
