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

    func testValidateRejectsBinaryWithoutProfdata() {
        XCTAssertThrowsError(try parseCommand(["--binary", "/usr/bin/something"]))
    }

    func testValidateRejectsXcresultWithProfdata() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let xcresult = tempDir.appendingPathComponent("test.xcresult")
        let profdata = tempDir.appendingPathComponent("default.profdata")
        let binary = tempDir.appendingPathComponent("MyApp")
        try FileManager.default.createDirectory(at: xcresult, withIntermediateDirectories: true)
        try Data().write(to: profdata)
        try Data().write(to: binary)

        XCTAssertThrowsError(try parseCommand([
            "--xcresult", xcresult.path,
            "--profdata", profdata.path,
            "--binary", binary.path,
        ]))
    }

    func testValidateRejectsNegativeThreshold() {
        XCTAssertThrowsError(try parseCommand(["--threshold", "-0.1"]))
    }

    func testValidateRejectsEmptyExcludePath() {
        XCTAssertThrowsError(try parseCommand(["--exclude-path", ""]))
    }

    func testValidateRejectsNonExistentDirectory() {
        XCTAssertThrowsError(try parseCommand(["/nonexistent/path/to/nowhere"]))
    }

    func testValidateRejectsFileAsDirectory() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let file = tempDir.appendingPathComponent("notadir.swift")
        try "func x() {}".write(to: file, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try parseCommand([file.path]))
    }

    func testValidateRejectsNonExistentXcresultPath() throws {
        XCTAssertThrowsError(try parseCommand(["--xcresult", "/nonexistent/test.xcresult"]))
    }

    func testValidateRejectsNonExistentProfdataPath() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let binary = tempDir.appendingPathComponent("MyApp")
        try Data().write(to: binary)

        XCTAssertThrowsError(try parseCommand([
            "--profdata", "/nonexistent/default.profdata",
            "--binary", binary.path,
        ]))
    }

    func testValidateRejectsNonExistentBinaryPath() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let profdata = tempDir.appendingPathComponent("default.profdata")
        try Data().write(to: profdata)

        XCTAssertThrowsError(try parseCommand([
            "--profdata", profdata.path,
            "--binary", "/nonexistent/MyApp",
        ]))
    }

    // MARK: - Short Flag Parsing

    func testShortFlagXcresult() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let xcresult = tempDir.appendingPathComponent("test.xcresult")
        try FileManager.default.createDirectory(at: xcresult, withIntermediateDirectories: true)

        let command = try parseCommand(["-x", xcresult.path])
        XCTAssertEqual(command.xcresult, xcresult.path)
    }

    func testShortFlagThreshold() throws {
        let command = try parseCommand(["-t", "25.5"])
        XCTAssertEqual(command.threshold, 25.5)
    }

    func testShortFlagFilter() throws {
        let command = try parseCommand(["-f", "viewDidLoad"])
        XCTAssertEqual(command.filter, ["viewDidLoad"])
    }

    func testShortFlagExcludePath() throws {
        let command = try parseCommand(["-e", "/Vendor/"])
        XCTAssertEqual(command.excludePath, ["/Vendor/"])
    }

    func testShortFlagExcludeGenerated() throws {
        let command = try parseCommand(["-g"])
        XCTAssertTrue(command.excludeGenerated)
    }

    func testShortFlagJson() throws {
        let command = try parseCommand(["-j"])
        XCTAssertTrue(command.json)
    }

    // MARK: - Long Flag Parsing

    func testLongFlagFilter() throws {
        let command = try parseCommand(["--filter", "init"])
        XCTAssertEqual(command.filter, ["init"])
    }

    func testLongFlagFilterRepeatable() throws {
        let command = try parseCommand(["--filter", "foo", "--filter", "bar"])
        XCTAssertEqual(command.filter, ["foo", "bar"])
    }

    func testLongFlagExcludeGenerated() throws {
        let command = try parseCommand(["--exclude-generated"])
        XCTAssertTrue(command.excludeGenerated)
    }

    func testLongFlagJson() throws {
        let command = try parseCommand(["--json"])
        XCTAssertTrue(command.json)
    }

    func testLongFlagExcludePathRepeatable() throws {
        let command = try parseCommand(["--exclude-path", "/Vendor/", "--exclude-path", "/Generated/"])
        XCTAssertEqual(command.excludePath, ["/Vendor/", "/Generated/"])
    }

    func testLongFlagThreshold() throws {
        let command = try parseCommand(["--threshold", "42.0"])
        XCTAssertEqual(command.threshold, 42.0)
    }

    // MARK: - File Discovery

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

    func testFindSwiftFilesExcludesMatchingPaths() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let kept = tempDir.appendingPathComponent("Sources/App.swift")
        let excluded = tempDir.appendingPathComponent("Vendor/Lib.swift")
        try FileManager.default.createDirectory(
            at: tempDir.appendingPathComponent("Sources"), withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: tempDir.appendingPathComponent("Vendor"), withIntermediateDirectories: true
        )
        try "func app() {}".write(to: kept, atomically: true, encoding: .utf8)
        try "func lib() {}".write(to: excluded, atomically: true, encoding: .utf8)

        let command = try parseCommand([])
        let files = command.findSwiftFiles(in: tempDir.path, excluding: ["/vendor/"])
        let resolved = files.map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().path }

        XCTAssertTrue(resolved.contains(kept.resolvingSymlinksInPath().path))
        XCTAssertFalse(resolved.contains(excluded.resolvingSymlinksInPath().path))
    }

    func testFindSwiftFilesExcludeGeneratedPatterns() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let kept = tempDir.appendingPathComponent("Sources/App.swift")
        let genSources = tempDir.appendingPathComponent("GeneratedSources/Types.swift")
        let generated = tempDir.appendingPathComponent("Generated/Models.swift")
        let genFile = tempDir.appendingPathComponent("Sources/GeneratedTypes.swift")

        for dir in ["Sources", "GeneratedSources", "Generated"] {
            try FileManager.default.createDirectory(
                at: tempDir.appendingPathComponent(dir), withIntermediateDirectories: true
            )
        }
        try "func app() {}".write(to: kept, atomically: true, encoding: .utf8)
        try "func types() {}".write(to: genSources, atomically: true, encoding: .utf8)
        try "func models() {}".write(to: generated, atomically: true, encoding: .utf8)
        try "func gen() {}".write(to: genFile, atomically: true, encoding: .utf8)

        let command = try parseCommand(["--exclude-generated"])
        let patterns = [
            "/.build/", "/generatedsources/", "/generated/",
            "/derivedsources/", "/sourcery/", ".generated.swift", "generatedtypes.swift",
        ]
        let files = command.findSwiftFiles(in: tempDir.path, excluding: patterns)
        let resolved = Set(files.map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().path })

        XCTAssertTrue(resolved.contains(kept.resolvingSymlinksInPath().path))
        XCTAssertFalse(resolved.contains(genSources.resolvingSymlinksInPath().path))
        XCTAssertFalse(resolved.contains(generated.resolvingSymlinksInPath().path))
        XCTAssertFalse(resolved.contains(genFile.resolvingSymlinksInPath().path))
    }

    func testDuplicatePathsAreDeduplicated() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let command = try parseCommand([tempDir.path, tempDir.path])
        let dirs = command.sourceDirectories()
        XCTAssertEqual(dirs.count, 1)
    }

    // MARK: - Coverage Resolution

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
